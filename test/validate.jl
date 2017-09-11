using ImagineInterface
using Base.Test, IntervalSets

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

#check_pulse_changetime
#function check_pulse_changetime(start_is::Vector{Int}, stop_is::Vector{Int}, nsamps_on_tol::Int, nsamps_off_tol::Int)

#check_pulse_interval
#function check_pulse_interval(start_is::Vector{Int}, nsamps_interval_tol::Int)

#check_pulses
#function check_pulses(sig::ImagineSignal, on_time::HasTimeUnits, off_time::HasTimeUnits, pulse_rate::HasInverseTimeUnits)

#check_camera

#check_cameras

#check_laser

#check_lasers
