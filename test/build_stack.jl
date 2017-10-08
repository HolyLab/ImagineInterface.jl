using ImagineInterface, Unitful, IntervalSets
import ImagineInterface: find_circular
import Unitful: s, μm
using Base.Test

##################################BIDIRECTIONAL STACK########################################3
sample_rate = 50000*Unitful.s^-1
pmin = 0.0*Unitful.μm
pmax = 200.0*Unitful.μm
stack_time = 1.0*Unitful.s
posfwd, posback = gen_bidi_pos(pmin, pmax, stack_time, sample_rate)
exp_time = 0.011*Unitful.s
flash_frac = 0.1 #fraction of time to keep laser on during exposure
z_spacing = 3.1*Unitful.μm
z_pad = 5.0*Unitful.μm
nsamps_stack = ceil(Int, stack_time*sample_rate)

#offset by one sample going forward so that we don't use the end points of the triangle
delay1samp = 1/sample_rate
exp_dist = exp_time * abs(pmax - pmin) / stack_time

exp_intervals_fwd = spaced_intervals(posfwd, z_spacing, exp_time, sample_rate; delay=delay1samp, z_pad = max(z_pad, exp_dist), alignment=:start, rig="ocpi-2")
exp_nsamps = width(exp_intervals_fwd[1]) + 1
flash_nsamps = ImagineInterface.calc_num_samps(flash_frac * exp_time, sample_rate)
offset_nsamps = exp_nsamps - flash_nsamps
exp_intervals_back = map(x-> ClosedInterval(length(posfwd)-(maximum(x)+offset_nsamps-2), length(posfwd)-(maximum(x)-flash_nsamps-1)), exp_intervals_fwd)
las_intervals_fwd = map(x-> ClosedInterval(maximum(x)-flash_nsamps+1, maximum(x)), exp_intervals_fwd)
las_intervals_back = map(x-> ClosedInterval(maximum(x)-flash_nsamps+1, maximum(x)), exp_intervals_back)

samps_las_fwd = gen_pulses(nsamps_stack, las_intervals_fwd)
samps_las_back = gen_pulses(nsamps_stack, las_intervals_back)
samps_cam_fwd = gen_pulses(nsamps_stack, exp_intervals_fwd)
samps_cam_back = gen_pulses(nsamps_stack, exp_intervals_back)

@test all(map(IntervalSets.width, exp_intervals_fwd) .== 549)
@test all(map(IntervalSets.width, exp_intervals_back) .== 549)
#exposure duration
@test IntervalSets.width(exp_intervals_fwd[1]) / sample_rate ≈ exp_time atol=1 / sample_rate
#laser duration
@test IntervalSets.width(las_intervals_fwd[1]) / sample_rate ≈ flash_frac * exp_time atol=1 / sample_rate
@test posfwd[1] == pmin
@test posfwd[end] < pmax
@test posback[1] == pmax
@test posback[end] > pmin
@test length(samps_cam_fwd) == nsamps_stack
#count pulses
nexp = length(exp_intervals_fwd)
@test nexp == length(exp_intervals_back) == 61
@test length(find_pulse_starts(samps_cam_fwd)) == nexp
@test length(find_pulse_stops(samps_cam_fwd)) == nexp 
@test length(find_pulse_starts(samps_cam_back)) == nexp 
@test length(find_pulse_stops(samps_cam_back)) == nexp 
#TODO: test padding

d = gen_bidirectional_stack(pmin, pmax, z_spacing, stack_time, exp_time, sample_rate, flash_frac; z_pad = z_pad)
@test d["positioner"] == vcat(posfwd, posback)
@test d["camera"] == vcat(samps_cam_fwd, samps_cam_back)
@test d["laser"] == vcat(samps_las_fwd, samps_las_back)
@test all(find_pulse_stops(d["camera"]) .== find_pulse_stops(d["laser"]))
@test d["nframes"] == length(exp_intervals_fwd) * 2

cam = d["camera"]
las = d["laser"]
cam1 = cam[1:div(length(cam),2)]
cam2 = cam[div(length(cam),2)+1:end]
las1 = las[1:div(length(las),2)]
las2 = las[div(length(las),2)+1:end]
lexp1 = cam1.&las1 #overlap of laser with exposure
lexp2= reverse(cam2.&las2) #reversed to align with lexp1
@test all(lexp1[2:end].==lexp2[1:end-1]) #exclude endpoints of the triangle


#write it
ocpi2 = rigtemplate("ocpi-2"; sample_rate = sample_rate)
nstacks = 5
pos = first(getpositioners(ocpi2))
cam = first(getcameras(ocpi2))
las = getname(ocpi2, "488nm laser")
append!(pos, "pos", d["positioner"])
append!(cam, "cam", d["camera"])
append!(las, "las", d["laser"])
nframes = d["nframes"]
replicate!(pos, nstacks-1)
replicate!(cam, nstacks-1)
replicate!(las, nstacks-1)
outname = splitext(tempname())[1] *".json"
write_commands(outname, [cam;las;pos], nstacks, nframes, exp_time; isbidi = true)
#should throw an error when passed the wrong number of stacks/frames
@test_throws Exception write_commands(outname, [cam;las;pos], nstacks+1, nframes, exp_time; isbidi = true)
@test_throws Exception write_commands(outname, [cam;las;pos], nstacks, nframes+1, exp_time; isbidi = true)

#read it back in
_ocpi2 = parse_commands(outname)
lasers = getlasers(_ocpi2)
@test length(lasers) == 2
las_all = getname(lasers, "all lasers") #should have been added automatically
@test all(get_samples(las_all) .= true)

##################################UNIDIRECTIONAL STACK########################################
#set reset time equal to stack time, so the piezo waveform should be the same as in the bidi test, with half of the frames
posuni, posreset = gen_sawtooth(pmin, pmax, stack_time, stack_time, sample_rate)
@test posuni == posfwd
@test posreset == posback
flash_frac_ocpi1 = 1.1 #flashing per-exposure doesn't work well on ocpi1
d2 = gen_unidirectional_stack(pmin, pmax, z_spacing, stack_time, stack_time, exp_time, sample_rate, flash_frac_ocpi1; z_pad = z_pad)
@test length(posreset) == length(posback)
@test length(find(x->x==1, diff(d2["camera"]))) == length(exp_intervals_fwd) #count pulses
@test d2["nframes"] == length(exp_intervals_fwd)

#write it
ocpi1 = rigtemplate("ocpi-1"; sample_rate = sample_rate)
nstacks = 5
pos = first(getpositioners(ocpi1))
cam = first(getcameras(ocpi1))
las = getname(ocpi1, "488nm laser shutter")
append!(pos, "pos", d2["positioner"])
append!(cam, "cam", d2["camera"])
append!(las, "las", d2["laser"])
nframes = d2["nframes"]
replicate!(pos, nstacks-1)
replicate!(cam, nstacks-1)
replicate!(las, nstacks-1)
outname = splitext(tempname())[1] *".json"
write_commands(outname, [cam;las;pos], nstacks, nframes, exp_time; isbidi = false)

#read it back in
_ocpi1 = parse_commands(outname)

##################################STEPPED UNIDIRECTIONAL STACK########################################
#set reset time equal to stack time, so the piezo waveform should be the same as in the bidi test, with half of the frames
pause_time = exp_time + 0.1 * Unitful.s
flash_frac_ocpi1 = 1.1 #flashing per-exposure doesn't work well on ocpi1
d2 = gen_stepped_stack(pmin, pmax, z_spacing, pause_time, stack_time, exp_time, sample_rate, flash_frac_ocpi1)

#write it
ocpi1 = rigtemplate("ocpi-1"; sample_rate = sample_rate)
nstacks = 5
pos = first(getpositioners(ocpi1))
cam = first(getcameras(ocpi1))
las = getname(ocpi1, "488nm laser shutter")
append!(pos, "pos", d2["positioner"])
append!(cam, "cam", d2["camera"])
append!(las, "las", d2["laser"])
nframes = d2["nframes"]
replicate!(pos, nstacks-1)
replicate!(cam, nstacks-1)
replicate!(las, nstacks-1)
outname = splitext(tempname())[1] *".json"
write_commands(outname, [cam;las;pos], nstacks, nframes, exp_time; isbidi = false)
#read it back in
_ocpi1 = parse_commands(outname)

########################### NO PIEZO MOTION ########################
pset = 0.0 * Unitful.μm
inter_exp_time = 0.0001 * Unitful.s #The time between exposure pulses
d3 = gen_2d_timeseries(pset, 10, exp_time, inter_exp_time, sample_rate, flash_frac)
@test all(d3["positioner"] .== pset)
@test length(find(x->x==1, diff(d3["camera"]))) == 10
@test length(find(x->x==1, diff(d3["laser"]))) == 10
@test (exp_time + inter_exp_time) * 10 * sample_rate ≈ length(d3["camera"])

#find_circular
samps = repmat([1:9...; 10:-1:2...], 3)
circ_list = [2; 4]
pad_nsamps = 0
i_s = find_circular(samps, circ_list, pad_nsamps)
@test i_s[1] == find(x->x==circ_list[1], samps)
@test i_s[2] == find(x->x==circ_list[2], samps)
@test all(find_circular(samps, circ_list, 1) .== i_s)
@test_throws Exception find_circular(samps, circ_list, 2)
circ_list = [4; 2]
@test_throws Exception find_circular(samps, circ_list, pad_nsamps) #because it doesn't begin decreasing
samps = repmat([10:-1:2...; 1:9...], 3) #begins decreasing
i_s = find_circular(samps, circ_list, pad_nsamps)
@test i_s[1] == find(x->x==circ_list[1], samps)
@test i_s[2] == find(x->x==circ_list[2], samps)

samps = repmat([1:9...; 10:-1:2...], 3)
circ_list = [2.5; 4.0] #fractional
i_s = find_circular(samps, circ_list, pad_nsamps)
@test i_s[1][1:2:end] == find(x->x==3, samps)[1:2:end] #on increasing sweep
@test i_s[1][2:2:end] == find(x->x==2, samps)[2:2:end] #on decreasing sweep
@test i_s[2] == find(x->x==circ_list[2], samps) #unaffected

#again with units
samps *= Unitful.μm
circ_list *= Unitful.μm
i_s = find_circular(samps, circ_list, pad_nsamps)
@test i_s[1][1:2:end] == find(x->x==3μm, samps)[1:2:end] #on increasing sweep
@test i_s[1][2:2:end] == find(x->x==2μm, samps)[2:2:end] #on decreasing sweep
@test i_s[2] == find(x->x==circ_list[2], samps) #unaffected
