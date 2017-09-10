#check the following:
#    -piezo isn't moving too fast
#    -sufficient time interval between camera exposure starts
#        -also emit warning if frame rate exceeds full chip max (100fps)
#    -sufficient time interval between exposure stop and next exposure start (based on jitter time, see MINIMUM_EXPOSURE_SEPARATION variable
#    -sufficient time between laser state changes

function check_piezos(sigs::Vector{ImagineSignal}; window_sz = 100)
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
    try
        window_validate!(val_state, val_func, window_sz, pos)
    catch
        error("The command exceeds the maximum speed of $max_sp permitted for this piezo / rig")
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

#check framerate and interval between exposure start and stop
function check_camera(cam::ImagineSignal; vs::ValidationState = ValidationState())

end

#check laser pulse duration and frequency
#Imagine checks every transition points(0->1) and calculate frequency between two consecutive transition points, we do the same here
function check_laser(las::ImagineSignal; vs::ValidationState = ValidationState())

end
