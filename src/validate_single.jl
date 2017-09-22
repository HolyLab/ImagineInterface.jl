#check the following:
#    -piezo isn't moving too fast
#    -sufficient time interval between camera exposure starts
#        -also emit warning if frame rate exceeds full chip max (100fps)
#    -sufficient time interval between exposure stop and next exposure start (based on jitter time, see MINIMUM_EXPOSURE_SEPARATION variable
#    -sufficient time between laser state changes

function check_piezos{TS<:ImagineSignal}(sigs::AbstractVector{TS}; window_sz = 100)
    ps = getpositioners(getoutputs(sigs))
    vs = check_piezo(ps[1]; window_sz = window_sz)
    for i = 2:length(ps)
        check_piezo(ps[i]; window_sz = window_sz, val_state = vs)
    end
    return vs
end

#check piezo speed
#window_sz is the size of the sliding window (in samples) over which to measure cumulative distance moved
#If the piezo is commanded to move faster than the speed set by PIEZO_MAX_SPEED within the window, then the test fails
#current method used by Imagine(?):  integer value can never change by more than +/-1, and cumulative change in a 10-sample window stays below some max speed
#by contrast here we are using a simple cumulative change over 100 samples
#with 1M sample rate this equates to a max change of 8 raw bits per 100 samps
#TODO: make this more robust to oscillations that occur faster than a 100-sample period.  Currently we're just hoping that those don't happen.  The strict way to fix this
#would be to check all window sizes less than 100 (or at least a couple more) but that is expensive
function check_piezo(pos::ImagineSignal; window_sz = 100, val_state::ValidationState = ValidationState()) #val_state is for bootstrapping with already-checked sequences
    max_sp = PIEZO_MAX_SPEED[rig_name(pos)]
    window_dur = window_sz / samprate(pos)
    max_dist = max_sp * window_dur #length units
    max_dist_raw = ceil(Int, (max_dist/width(interval_world(pos))) * width(interval_raw(pos)))
    val_func = (samps, win_sz) -> check_max_speed(samps, max_dist_raw, win_sz)
    if length(pos) < window_sz #should this throw an error?
        warn("Insufficient samples to check this signal with a window size setting of $window_sz")
    else
        try
            window_validate!(val_state, val_func, window_sz, pos)
        catch
            error("The command $(name(pos)) exceeds the maximum speed of $max_sp permitted for this piezo / rig")
        end
    end
    return val_state
end

function check_max_speed(raw_samps::Vector, raw_change::Int, in_n_samps::Int)
    @assert length(raw_samps) >= in_n_samps
    niter = length(raw_samps) - in_n_samps + 1
    first_window = raw_samps[1:in_n_samps]
    last_samp = first_window[end]
    diff_vec = diff(first_window)
    #abs_vec will be a circular buffer for efficiency
    abs_vec = abs.(diff_vec)
    circ_i = 1
    tot = sum(abs_vec)
    for i = 2:niter
        if tot > raw_change
            return false
        end
        next_samp = raw_samps[i+in_n_samps-1]
        #update diff_vec, abs_vec, tot, and circ_i
        tot -= abs_vec[circ_i]
        next_abs = abs(next_samp - last_samp)
        abs_vec[circ_i] = next_abs
        tot += next_abs
        circ_i = circ_i % (in_n_samps-1) + 1
        last_samp = next_samp
    end
    #check last sample
    if tot > raw_change
        return false
    end
    return true
end

function check_pulse_padding(sig::ImagineSignal)
    if get_samples(sig, 1, 1)[1] == true
        error("Pulse sequence must begin with a LOW sample")
    end
    if get_samples(sig, length(sig), length(sig))[1] == true
        error("Pulse sequence must end with a LOW sample")
    end
end

function check_pulse_changetime(start_is::Vector{Int}, stop_is::Vector{Int}, nsamps_on_tol::Int, nsamps_off_tol::Int)
    if nsamps_on_tol > 0
        for i = 1:length(start_is)
            if stop_is[i] - start_is[i] + 1 < nsamps_on_tol
                error("Pulse #$i has insufficient duration")
            end
        end
    end
    if nsamps_off_tol > 0
        for i = 1:(length(start_is) - 1)
            if start_is[i+1] - stop_is[i] - 1 < nsamps_off_tol
                error("The interval between pulse #$i end and pulse #$(i+1) start is too small")
            end
        end
    end
    return true
end

#checks that the start-to-start time is within tolerance
#also keeps track of the shortest start-to-start time
function check_pulse_interval(start_is::Vector{Int}, nsamps_interval_tol::Int)
    shortest_width = typemax(Int)
    for i = 1:(length(start_is)-1)
        cur_width = start_is[i+1] - start_is[i]
        shortest_width = min(cur_width, shortest_width)
        if cur_width < nsamps_interval_tol
            error("The interval between pulse #$i start and pulse #$(i+1) start is too small")
        end
    end
    return shortest_width
end

function check_pulses(sig::ImagineSignal, on_time::HasTimeUnits, off_time::HasTimeUnits, pulse_rate::HasInverseTimeUnits)
    check_pulse_padding(sig)
    rig = rig_name(sig)
    strts = find_pulse_starts(sig)
    stps = find_pulse_stops(sig)
    min_on_samps = ceil(Int, on_time * uconvert(inv(unit(on_time)), samprate(sig)))
    min_off_samps = ceil(Int, off_time * uconvert(inv(unit(off_time)), samprate(sig)))
    check_pulse_changetime(strts, stps, min_on_samps, min_off_samps)
    nsamps_start_to_start = ceil(Int, (1/pulse_rate) * uconvert(unit(pulse_rate), samprate(sig)))
    if !isinf(pulse_rate)
        min_interval_width = check_pulse_interval(strts, nsamps_start_to_start)
    end
    return true 
end

check_cameras{TS<:ImagineSignal}(sigs::AbstractVector{TS}) = map(check_camera, getcameras(getoutputs(sigs)))

#check framerate, interpulse, intrapulse
#   the 0->1->0 interval is greater than or equal to CAMERA_ON_TIME
#   the 1->0->1 interval is greater than or equal to CAMERA_OFF_TIME
#   the 0->1->0->1 interval is greater than or equal to 1 / the max framerate
#   max_framerate = max_framerate(rig, chip_size(rig)...)
function check_camera(cam::ImagineSignal; chip_sz = chip_size(rig_name(cam)))    
    if isempty(cam)
        warn("Signal $(name(cam)) is empty.  Skipping validation.")
        return true
    end
    rig = rig_name(cam)
    min_on_dur = CAMERA_ON_TIME[rig]
    min_off_dur = CAMERA_OFF_TIME[rig]
    max_fr = max_framerate(rig, chip_sz...)
    check_pulses(cam, min_on_dur, min_off_dur, max_fr)
end

check_lasers{TS<:ImagineSignal}(sigs::AbstractVector{TS}) = map(check_laser, getlasers(getoutputs(sigs)))
#check laser pulse duration and frequency
#Imagine currently checks every transition points(0->1) and calculate frequency between two consecutive transition points
#We check that:
#   the 0->1->0 interval is greater than or equal to LASER_ON_TIME
#   the 1->0->1 interval is greater than or equal to LASER_OFF_TIME
#   the 0->1->0->1 interval is unconstrained
function check_laser(las::ImagineSignal)
    if isempty(las)
        warn("Signal $(name(las)) is empty.  Skipping validation.")
        return true
    end
    rig = rig_name(las)
    min_on_dur = LASER_ON_TIME[rig]
    min_on_samps = min_on_dur * samprate(las)
    min_off_dur = LASER_OFF_TIME[rig]
    check_pulses(las, min_on_dur, min_off_dur, Inf*inv(Unitful.s))
end

function validate_singles{TS<:ImagineSignal}(sigs::AbstractVector{TS})
    check_piezos(sigs)
    check_cameras(sigs)
    check_lasers(sigs)
end

function validate_all{TS<:ImagineSignal}(sigs::AbstractVector{TS}; check_is_sufficient = true)
    validate_group(sigs; check_is_sufficient = check_is_sufficient)
    validate_singles(sigs)
end
