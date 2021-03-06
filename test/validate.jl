using ImagineInterface
using Test, IntervalSets, Unitful

import ImagineInterface: check_max_speed, ValidationState, check_piezo, check_piezos
import ImagineInterface: check_pulse_duration, check_interpulse_duration, check_pulse_interval
import ImagineInterface: check_camera, check_cameras, check_laser, check_lasers

#check_max_speed
a = ones(Int16, 10)
a[3] = 3
@test check_max_speed(a, 5, 5) == true
@test check_max_speed(a, 4, 5) == true
@test check_max_speed(a, 3, 5) == false
a[3] = 4
@test check_max_speed(a, 5, 5) == false
a[3] = 1
a[5] = 4
@test check_max_speed(a, 5, 5) == false
a[5] = 1
a[10] = 4
@test check_max_speed(a, 5, 5) == true
a[10] = 1
a[9] = 4
@test check_max_speed(a, 5, 5) == false

#check_piezo
rig = "ocpi-2"
ocpi2 = rigtemplate(rig; sample_rate = 1000*inv(Unitful.s))
pos = getpositioners(ocpi2)[1]
b = zeros(rawtype(pos), 2000)
append!(pos, "b", b)

speed_lim = ImagineInterface.PIEZO_MAX_SPEED[rig]
win_sz = 10
thresh_um = (win_sz/samprate(pos)) * speed_lim
#thresh_raw is the allowable cumulative raw change in piezo signal within the sliding window
thresh_raw = ceil(Int, (thresh_um/width(interval_world(pos))) * width(interval_raw(pos)))

@test isa(check_piezo(pos; window_sz = win_sz), ValidationState)

b[1] = round(eltype(b), thresh_raw + 1)
replace!(pos, "b", b)
@test_throws Exception check_piezo(pos; window_sz = win_sz)

b[1] = 0
b[end] = round(eltype(b), thresh_raw + 1)
replace!(pos, "b", b)
@test_throws Exception check_piezo(pos; window_sz = win_sz)

b[end] = 0
b[1001] = round(eltype(b), ceil(Int, thresh_raw/2) + 1)
replace!(pos, "b", b)
@test_throws Exception check_piezo(pos; window_sz = win_sz)

b[1001] = round(eltype(b), ceil(Int, thresh_raw/2) -2)
replace!(pos, "b", b)
@test isa(check_piezo(pos; window_sz = win_sz), ValidationState)

#check_piezos
@test isa(check_piezos(getpositioners(ocpi2); window_sz = win_sz), ValidationState)

#test pulse validation code camera
srate = 1000000*inv(Unitful.s)
rig = "ocpi-2"
ocpirig = rigtemplate(rig; sample_rate = srate)
function test_seq1(first_i, samps_on, start2start)
    start_is = Int[first_i; first_i+start2start; first_i + start2start*2; first_i + start2start*3]
    stop_is = Int[first_i + samps_on-1; first_i+start2start+samps_on-1; first_i+start2start*2+samps_on-1; first_i+start2start*3+samps_on-1]
    return start_is, stop_is
end

function test_seq2(first_i, samps_off, start2start)
    samps_on = start2start - samps_off
    test_seq1(first_i, samps_on, start2start)
end

function gen_samp_seq(start_is, stop_is, tot_length)
    @assert length(start_is) == length(stop_is)
    seq = falses(tot_length)
    for i = 1:length(start_is)
        @assert start_is[i] <= stop_is[i]
        seq[start_is[i]:stop_is[i]] .= true
    end
    return seq
end

sigs = getcameras(ocpirig)
ton = ImagineInterface.CAMERA_ON_TIME[rig]
toff = ImagineInterface.CAMERA_OFF_TIME[rig]
samps_on_tol = ceil(Int, uconvert(inv(unit(srate)), ton) * srate)
samps_off_tol = ceil(Int, uconvert(inv(unit(srate)), toff) * srate)
frate = max_framerate(rig, chip_size(rig)...)
start2start_tol = ceil(Int, uconvert(inv(unit(srate)), 1/frate) * srate)
first_i = 2

start_is, stop_is = test_seq1(first_i, samps_on_tol, start2start_tol)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_pulse_interval(start_is, start2start_tol) == 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
append!(sigs[1], "test", samps)
check_camera(sigs[1])
check_cameras(sigs)
append!(sigs[2], "test2", samps)
check_cameras(sigs)

#check_pulse_duration fails because on time is too short
start_is, stop_is = test_seq1(first_i, samps_on_tol-1, start2start_tol)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) > 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0

samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
@test_throws Exception check_camera(sigs[1])


#check_pulse_interval fails because start2start is to short
start_is, stop_is = test_seq1(first_i, samps_on_tol, start2start_tol-1)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0

@test check_pulse_interval(start_is, start2start_tol) > 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
@test_throws Exception check_camera(sigs[1])

start_is, stop_is = test_seq2(first_i, samps_off_tol, start2start_tol)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0

@test check_pulse_interval(start_is, start2start_tol) == 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
check_camera(sigs[1])

#check_interpulse_duration fails because off time is too short
start_is, stop_is = test_seq2(first_i, samps_off_tol-1, start2start_tol)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) > 0

@test check_pulse_interval(start_is, start2start_tol) == 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
@test_throws Exception check_camera(sigs[1])

#check_pulse_interval fails because start2start is to short
start_is, stop_is = test_seq2(first_i, samps_off_tol, start2start_tol-1)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0

@test check_pulse_interval(start_is, start2start_tol) > 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
@test_throws Exception check_camera(sigs[1])



############################ Similar tests for lasers (should think about simplifying this)
sigs = getlasers(ocpirig)
ton = ImagineInterface.LASER_ON_TIME[rig]
toff = ImagineInterface.LASER_OFF_TIME[rig]
samps_on_tol = ceil(Int, uconvert(inv(unit(srate)), ton) * srate)
samps_off_tol = ceil(Int, uconvert(inv(unit(srate)), toff) * srate)
start2start_tol = samps_on_tol+samps_on_tol+2 #currently we don't limit laser pulse rate (except indirectly through ton and toff) so just setting this to something safe
first_i = 2

start_is, stop_is = test_seq1(first_i, samps_on_tol, start2start_tol)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0

@test check_pulse_interval(start_is, start2start_tol) == 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
append!(sigs[1], "test3", samps)
check_laser(sigs[1])
check_lasers(sigs)
append!(sigs[2], "test4", samps)
check_lasers(sigs)
append!(sigs[3], "test5", trues(length(samps))) #laser always on

#check_pulse_duration fails because on time is too short
start_is, stop_is = test_seq1(first_i, samps_on_tol-1, start2start_tol)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) > 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0

@test check_pulse_interval(start_is, start2start_tol) == 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test3", samps)
@test_throws Exception check_laser(sigs[1])


start_is, stop_is = test_seq2(first_i, samps_off_tol, start2start_tol)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0

@test check_pulse_interval(start_is, start2start_tol) == 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test3", samps)
check_laser(sigs[1])

#check_interpulse_duration fails because off time is too short
start_is, stop_is = test_seq2(first_i, samps_off_tol-1, start2start_tol)
@test check_pulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) == 0
@test check_interpulse_duration(start_is, stop_is, samps_on_tol, samps_off_tol) > 0

@test check_pulse_interval(start_is, start2start_tol) == 0
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test3", samps)
@test_throws Exception check_laser(sigs[1])

@testset "Reduced frame size" begin
    μm, s = Unitful.μm, Unitful.s
    sample_rate = 50000s^-1 #analog output samples per second
    rig = "realm"
    realm = rigtemplate(rig; sample_rate = sample_rate)
    positioners = getpositioners(realm)
    pos = positioners[1]
    ############STACK PARAMETERS#################
    pmin = 0.0*μm #Piezo start position in microns
    pmax = 200.0*μm #Piezo stop position in microns
    stack_img_time = 0.26s #Time to complete the imaging sweep with the piezo (remember we also need to reset it to its starting position)
    reset_time = 0.001s #Time to reset piezo to starting position.  This time plus "stack_img_time" determines how long it takes to complete an entire stack and be ready to start a new stack
    z_spacing = 3.1μm #The space between slices in the z-stack.
    z_pad = 1.0μm #Set this greater than 0 if you want to ignore the edges of the positioner sweep (only take slices in a central region)

    hmax, vmax = chip_size(rig)
    h = 1000 #doesn't matter with current cameras
    v = 400
    mx_f = max_framerate(rig, h,v)
    mn_exp = 1/mx_f #This is the minimum possible exposure time
    mx_f = max_framerate(rig, hmax, vmax)
    mx_exp = 1/mx_f
    exp_time = 0.002s  #Exposure time of the camera. Make sure this is greater than mn_exp and less than mx_exp above
    flash_frac = 1.1 #fraction of time to keep laser on during exposure.  If you set this greater than 1 then the laser will stay on constantly during the imaging sweep

    d = gen_bidirectional_stack(pmin, pmax, z_spacing, stack_img_time, exp_time, sample_rate, flash_frac; z_pad = z_pad, rig = rig)
    nframes = d["nframes"] #note that there are twice as many frames as in the unidirectional example because one cycle of the positioner includes two stacks

    #Let's append our newly-created sample vectors to their respective commands in the template
    append!(pos, "bi_stack_pos", d["positioner"])
    lasers = getlasers(realm)
    las1 = lasers[1] #You could also append to any of the other lasers
    append!(las1, "bi_stack_las1", d["laser"])
    cams = getcameras(realm)
    cam1 = cams[1] #You could also append to the other camera
    append!(cam1, "bi_stack_cam1", d["camera"])

    nstacks = 1
    fn = tempname() * ".json"
    write_commands(fn, realm, nstacks, nframes, exp_time; isbidi = true, vertical_lines=v)
    rm(fn)
end
