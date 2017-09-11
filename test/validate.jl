using ImagineInterface
using Base.Test, IntervalSets, Unitful

import ImagineInterface: check_max_speed, ValidationState, check_piezo, check_piezos
import ImagineInterface: check_pulse_padding, check_pulse_changetime, check_pulse_interval
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

#check_pulse_padding
cam = getcameras(ocpi2)[1]
c = trues(10)
append!(cam, "c", c)
@test_throws Exception check_pulse_padding(cam)
c[1] = false
c[end] = false
replace!(cam, "c", c)
check_pulse_padding(cam)

#test pulse validation code camera
srate = 100000*inv(Unitful.s)
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
        seq[start_is[i]:stop_is[i]] = true
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
check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
append!(sigs[1], "test", samps)
check_camera(sigs[1])
check_cameras(sigs)
append!(sigs[2], "test2", samps)
check_cameras(sigs)

#check_pluse_changetime fails because on time is too short
start_is, stop_is = test_seq1(first_i, samps_on_tol-1, start2start_tol)
@test_throws Exception check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
@test_throws Exception check_camera(sigs[1])


#check_pulse_interval fails because start2start is to short
start_is, stop_is = test_seq1(first_i, samps_on_tol, start2start_tol-1)
check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
@test_throws Exception check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
@test_throws Exception check_camera(sigs[1])

start_is, stop_is = test_seq2(first_i, samps_off_tol, start2start_tol)
check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
check_camera(sigs[1])

#check_pluse_changetime fails because off time is too short
start_is, stop_is = test_seq2(first_i, samps_off_tol-1, start2start_tol)
@test_throws Exception check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test", samps)
@test_throws Exception check_camera(sigs[1])

#check_pulse_interval fails because start2start is to short
start_is, stop_is = test_seq2(first_i, samps_off_tol, start2start_tol-1)
check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
@test_throws Exception check_pulse_interval(start_is, start2start_tol)
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
check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
append!(sigs[1], "test3", samps)
check_laser(sigs[1])
check_lasers(sigs)
append!(sigs[2], "test4", samps)
check_lasers(sigs)

#check_pluse_changetime fails because on time is too short
start_is, stop_is = test_seq1(first_i, samps_on_tol-1, start2start_tol)
@test_throws Exception check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test3", samps)
@test_throws Exception check_laser(sigs[1])


start_is, stop_is = test_seq2(first_i, samps_off_tol, start2start_tol)
check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test3", samps)
check_laser(sigs[1])

#check_pluse_changetime fails because off time is too short
start_is, stop_is = test_seq2(first_i, samps_off_tol-1, start2start_tol)
@test_throws Exception check_pulse_changetime(start_is, stop_is, samps_on_tol, samps_off_tol)
check_pulse_interval(start_is, start2start_tol)
samps = gen_samp_seq(start_is, stop_is, stop_is[end]+1)
replace!(sigs[1], "test3", samps)
@test_throws Exception check_laser(sigs[1])
