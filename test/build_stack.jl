using ImagineInterface, Unitful

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

exp_intervals_fwd = spaced_intervals(posfwd, z_spacing, exp_time, 1/sample_rate; delay=delay1samp, z_pad = z_pad, alignment=:start)
exp_intervals_back = spaced_intervals(posback, z_spacing, exp_time, 1/sample_rate; delay=0.0*Unitful.s, z_pad = z_pad, alignment=:stop)

las_intervals_fwd = map(x->ImagineInterface.scale(x, flash_frac), exp_intervals_fwd)
#las_intervals_back = map(x->scale(x, flash_frac), exp_intervals_back)

samps_las_fwd = gen_pulses(nsamps_stack, las_intervals_fwd)
#samps_las_back = gen_pulses(nsamps_stack, las_intervals_back) #this can be off-by-one sample due to rounding in the scale function
samps_las_back = reverse(circshift(samps_las_fwd,-1)) 
samps_cam_fwd = gen_pulses(nsamps_stack, exp_intervals_fwd)
samps_cam_back = gen_pulses(nsamps_stack, exp_intervals_back)

@test all(map(IntervalSets.width, exp_intervals_fwd) .== 550)
@test all(map(IntervalSets.width, exp_intervals_back) .== 550)
#exposure duration
@test IntervalSets.width(exp_intervals_fwd[1]) / sample_rate ≈ exp_time atol=1 / sample_rate
#laser duration
@test IntervalSets.width(las_intervals_fwd[1]) / sample_rate ≈ flash_frac * exp_time atol=1 / sample_rate
@test posfwd[1] == pmin
@test posfwd[end] < pmax
@test posback[1] == pmax
@test posback[end] > pmin
@test length(samps_cam_fwd) == nsamps_stack
@test samps_cam_fwd == reverse(circshift(samps_cam_back,-1))
@test samps_las_fwd == reverse(circshift(samps_las_back,-1)) 
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
@test d["nframes"] == length(exp_intervals_fwd) * 2


##################################UNIDIRECTIONAL STACK########################################
#set reset time equal to stack time, so the piezo waveform should be the same as in the bidi test, with half of the frames
posuni, posreset = gen_sawtooth(pmin, pmax, stack_time, stack_time, sample_rate)
@test posuni == posfwd
@test posreset == posback
d2 = gen_unidirectional_stack(pmin, pmax, z_spacing, stack_time, stack_time, exp_time, sample_rate, flash_frac; z_pad = z_pad)
@test length(posreset) == length(posback)
@test length(find(x->x==1, diff(d2["camera"]))) == length(exp_intervals_fwd) #count pulses
@test length(find(x->x==1, diff(d2["laser"]))) == length(exp_intervals_fwd) #count pulses
@test d2["nframes"] == length(exp_intervals_fwd)

#no piezo motion
pset = 0.0 * Unitful.μm
inter_exp_time = 0.0001 * Unitful.s #The time between exposure pulses
d3 = gen_2d_timeseries(pset, 10, exp_time, inter_exp_time, sample_rate, flash_frac)
@test all(d3["positioner"] .== pset)
@test length(find(x->x==1, diff(d3["camera"]))) == 10
@test length(find(x->x==1, diff(d3["laser"]))) == 10
@test (exp_time + inter_exp_time) * 10 * sample_rate ≈ length(d3["camera"])

