using Ranges #delete this when we drop 0.5 support

#lowpass filter a command vector
function apply_lp(mod_samps::AbstractVector, sampr::HasInverseTimeUnits, cutoff::HasInverseTimeUnits)
    if isinf(cutoff)
        return mod_samps
    end
    mod_samps3 = repmat(mod_samps, 3)
    fs = ustrip(uconvert(Unitful.Hz, sampr))
    cutoff = ustrip(uconvert(Unitful.Hz, cutoff))
    responsetype = Lowpass(cutoff; fs=fs)
    designmethod = Butterworth(4)
    filtd = filtfilt(digitalfilter(responsetype, designmethod), ustrip.(mod_samps3)).*unit(mod_samps[1])
    return filtd[length(mod_samps)+1:(2*length(mod_samps))]
end

#Use this whenever we need to calculate sample counts so that we are consistent with rounding
function calc_num_samps(duration::HasTimeUnits, sample_rate::HasInverseTimeUnits; should_warn = true)
    unrounded = duration * sample_rate
    rounded = round(Int, unrounded)
    rounding_err = abs(rounded - unrounded)/unrounded
    if rounding_err > 0.01
        warn("The requested duration cannot be achieved to within 1% accuracy with the current sampling rate.  Consider increasing the sampling rate.")
    end
    return rounded
end

#Returns a set of positions _centered_ within the span of pman and pmax and spaced by slice_spacing
#TODO: use this wherever such calculations are done
function slice_positions(pstart::HasLengthUnits, pstop::HasLengthUnits, slice_spacing::HasLengthUnits)
    pstart = uconvert(Unitful.μm, pstart)
    pstop = uconvert(Unitful.μm, pstop)
    slice_spacing = uconvert(Unitful.μm, slice_spacing)
    prng = abs(pstop - pstart)
    nslices = floor(Int, ustrip(prng/slice_spacing)) + 1
    leftover = (prng - ((nslices-1) * slice_spacing))/2
    if pstart > pstop
        leftover = -leftover
    end
    return [linspace(pstart + leftover, pstop - leftover, nslices)...]
end

#This version first adjusts pmin and pmax to respect padding
function slice_positions(pmin::HasLengthUnits, pmax::HasLengthUnits, slice_spacing::HasLengthUnits, slice_pad::HasLengthUnits)
    @assert pmin <= pmax
    pstart = uconvert(Unitful.μm, pmin+slice_pad)
    pstop = uconvert(Unitful.μm, pmax-slice_pad)
    return slice_positions(pstart, pstop, slice_spacing)
end

#The sweep covers an interval that is closed on the left and open on the right.
#i.e. a sweep from 0 to 10 will include a sample at 0 but not at 10
function gen_sweep(pmin::HasLengthUnits, pmax::HasLengthUnits, tsweep::HasTimeUnits, sample_rate::HasInverseTimeUnits)
    tsweeps = uconvert(Unitful.s, tsweep)
    pminum = uconvert(Unitful.μm, pmin)
    pmaxum = uconvert(Unitful.μm, pmax)
    nsamps = calc_num_samps(tsweep, sample_rate)
    increment = (pmaxum - pminum) / nsamps
    return Ranges.linspace(pminum, pmaxum-increment, nsamps)
end

#moves at 90% of maximum safe speed from pmin to pmax
function gen_safe_sweep(pmin::HasLengthUnits, pmax::HasLengthUnits, sample_rate::HasInverseTimeUnits, rig::AbstractString)
    safe_tsweep = abs(pmax - pmin) / (.90 * PIEZO_MAX_SPEED[rig])
    return gen_sweep(pmin, pmax, safe_tsweep, sample_rate)
end

#Generate sets of samples describing the motion of the positioner during one stack
function gen_sawtooth(pmin::HasLengthUnits, pmax::HasLengthUnits, tfwd::HasTimeUnits, treset::HasTimeUnits, sample_rate::HasInverseTimeUnits)
    fwd_linspace = gen_sweep(pmin, pmax, tfwd, sample_rate)
    reset_linspace = gen_sweep(pmax, pmin, treset, sample_rate)
    return fwd_linspace, reset_linspace
end

gen_bidi_pos(pmin::HasLengthUnits, pmax::HasLengthUnits, tsweep::HasTimeUnits, sample_rate::HasInverseTimeUnits; lp_cutoff = Inf*Hz) = fit_smoothed_bidi(pmin, pmax, upreferred(1/(2*tsweep)), sample_rate; cutoff=lp_cutoff)

#start with triangle and smooth it:
#iteratively adjust limits of a waveform until the filtered version matches the desired pmin and pmax
function fit_smoothed_bidi(pmin, pmax, f, sr; cutoff = 150.0Hz)
	if cutoff == Inf*Hz
		fwd, bck =  ImagineInterface.gen_sawtooth(pmin, pmax, upreferred(1/(2*f)), upreferred(1/(2*f)), sr)
		return fwd,bck
	end
	thresh = 0.001μm
	v = 100.0μm
	wvform = fwd = bck = -1
	dxtra = 0.0μm
	while v > thresh
		fwd, bck =  ImagineInterface.gen_sawtooth(pmin-dxtra, pmax+dxtra, upreferred(1/(2*f)), upreferred(1/(2*f)), sr)
		wvform = apply_lp(vcat(fwd,bck), sr, cutoff)
		mx = maximum(wvform)
		mn = minimum(wvform)
		v = max(abs(pmin - mn), abs(pmax - mx))
		dxtra += v/2
	end
	if isnan(dxtra)
		error("Smoothing seems to have failed")
	end
    return wvform[1:div(length(wvform),2)], wvform[div(length(wvform),2)+1:end]
end

#returns a vector of sample-index intervals with starts separated by `interval_spacing`.
#The first interval is offset from the first sample of the sampled region by the `offset` keyword arg
#The `z_pad` kwarg, specified in non-temporal units, will prevent placement of intervals at the extremes of the sample space
#The `alignment` kwarg determines whether the first interval begins at the first valid sample (:start) or the last interval ends at the last valid sample (:stop)
#Thus :start and :stop will produce equal results for certain well-dividing sample counts, but most of the time they are different
function spaced_intervals{TS<:HasLengthUnits, TT<:HasTimeUnits, TTI<:HasInverseTimeUnits}(samples_space::Ranges.LinSpace{TS}, interval_spacing::TS, interval_duration::TT, sample_rate::TTI;
                                delay::TT=uconvert(unit(TT), 0.0*Unitful.s), z_pad::TS = uconvert(unit(TS), 1.0*Unitful.μm), alignment=:start, rig="ocpi-2")
    if !in(alignment, (:start, :stop))
        error("Only :start and :stop alignment is supported")
    end
    samp_length = abs(step(samples_space))
    pad_samps = round(Int, z_pad/samp_length)
    delay_samps = calc_num_samps(delay, sample_rate)
    offset = pad_samps + delay_samps
    nsamps = length(samples_space) - offset - pad_samps
    dur_samps = calc_num_samps(interval_duration, sample_rate)
    spacing_samps = interval_spacing/samp_length
    if abs(spacing_samps-round(Int, spacing_samps))/spacing_samps > 0.01
        warn("The requested spacing cannot be achieved to within 1% accuracy with the current sampling rate.  Consider increasing the sampling rate.")
    end
    spacing_samps = round(Int, spacing_samps)
    if spacing_samps <= dur_samps
        error("The requested stack spacing results in overlapping camera exposure and/or laser pulse intervals.  Increase z-slice spacing, decrease exposure time, or change sampling rate.")
    end
    inter_samps = spacing_samps - dur_samps #number of samples between end of one interval and start of the next
    if inter_samps < ceil(Int, CAMERA_OFF_TIME[rig] * sample_rate)
        error("The requested spacing results in intervals which are too close in time for the jitter specification of the camera.  Increase interval_spacing, decrease interval_duration, or change sampling rate")
    end
    cycle_samps = inter_samps + dur_samps #number of samples in one whole cycle
    nintervals = div(nsamps, cycle_samps)
    extra = mod(nsamps-dur_samps, cycle_samps) #first cycle is partial
    if extra >= dur_samps
        nintervals+=1
        extra-=dur_samps
    end
    if nintervals == 0
        error("The requested interval_duration is longer than the sampled region.")
    end
    output = Array{ClosedInterval{Int}}(nintervals)
    if alignment == :stop
        offset+=extra
    end
    output[1] = ClosedInterval(offset+1, offset+dur_samps)
    for i = 2:nintervals
        curstart = offset + (i-1)*cycle_samps+1
        output[i] = ClosedInterval(curstart, curstart+dur_samps-1) #offset+(i-1)*cycle_samps+1, offset+i*cycle_samps)
    end
    return output
end

function gen_pulses!(output::Vector{Bool}, pulsevec::Vector{ClosedInterval{Int}}; fillval=true)
    for p in pulsevec
        output[minimum(p):maximum(p)] = fillval
    end
    return output
end
gen_pulses(nsamps::Int, pulsevec::Vector{ClosedInterval{Int}}; fillval=true) = gen_pulses!(fill(!fillval, nsamps), pulsevec; fillval=fillval)

function center(input::ClosedInterval{Int})
    w = width(input)
    halfw = div(w,2)
    return minimum(input) + halfw
end

#Return a new "scaled" interval centered on the center of the input and with width equal to frac * width(input) 
function scale(input::ClosedInterval{Int}, frac::Float64)
    halfw = div(width(input),2)
    ctr = center(input)
    halfw_new = round(Int, frac*halfw)
    return ClosedInterval(ctr - halfw_new, ctr + halfw_new)
end

function gen_bidirectional_stack{TL<:HasLengthUnits, TT<:HasTimeUnits, TTI<:HasInverseTimeUnits}(pmin::TL, pmax::TL, z_spacing::TL, stack_time::TT, exp_time::TT, sample_rate::TTI, flash_frac::Real; z_pad::TL = 1.0*Unitful.μm, alternate_cameras = false, rig="ocpi-2")
    if pmin == pmax
        error("Use the gen_2d_timeseries function instead of setting pmin and pmax to the same value")
    end
    flash = true
    if flash_frac >= 1.0
        warn("las_frac was set greater than 1.0, so keeping laser on throughout the stack")
        flash = false
    elseif flash_frac <= 0
        error("las_frac must be positive")
    end

    pmin = uconvert(Unitful.μm, pmin)
    pmax = uconvert(Unitful.μm, pmax)
    z_spacing = uconvert(Unitful.μm, z_spacing)
    z_pad = uconvert(Unitful.μm, z_pad)

    stack_time = uconvert(Unitful.s, stack_time)
    exp_time = uconvert(Unitful.s, exp_time)
    sample_rate = uconvert(inv(Unitful.s), sample_rate)

    nsamps_stack = calc_num_samps(stack_time, sample_rate)
    posfwd, posback = gen_bidi_pos(pmin, pmax, stack_time, sample_rate)
    #offset by one sample going forward so that we don't use the end points of the triangle
    delay1samp = 1/sample_rate

    #We want the cameras to reach the global exposure state at the same time for each pulse in forward and reverse stacks, so we
    #don't line up the pulses exactly.  Assuming that the exposure is one las_frac's duration longer than the minimum exposure time for the given
    #should really put some more work into making this modular and adaptable to different exposure times / ROI sizes / line times /cameras
    #For now we deliver the flash at the end of the exposure pulse, and we align the forward and reverse stacks to the flash (not to the exposure)
    #Therefor it's up to the user to make sure the exposure time and ROI size combination is long enough that the flash fits within the global
    #exposure period (see PCO.Edge manual for more details)

    #distance traveled in one exposure time.  We need to adjust padding by that much to make sure that exposures can fit.
    exp_dist = exp_time * abs(pmax - pmin) / stack_time
    if exp_dist > z_pad
        warn("Increasing z padding by $(exp_dist-z_pad) to leave space for bidirectional exposures\n")
    end
    exp_intervals_fwd = spaced_intervals(posfwd, z_spacing, exp_time, sample_rate; delay=delay1samp, z_pad = max(z_pad,exp_dist), alignment=:start, rig=rig)
    flash_nsamps = calc_num_samps(min(flash_frac,1.0) * exp_time, sample_rate)
    exp_nsamps = width(exp_intervals_fwd[1]) + 1
    offset_nsamps = exp_nsamps - flash_nsamps
    #The extra -1 is needed since the forward direction does not sample the last point (the first index in the reverse direction)
    exp_intervals_back = map(x-> ClosedInterval(length(posfwd)-(maximum(x)+offset_nsamps-2), length(posfwd)-(maximum(x)-flash_nsamps-1)), exp_intervals_fwd)
#    exp_intervals_back = spaced_intervals(posback, z_spacing, exp_time, sample_rate; delay=0.0*Unitful.s, z_pad = z_pad, alignment=:stop, rig=rig)
    
    if flash
        las_intervals_fwd = map(x-> ClosedInterval(maximum(x)-flash_nsamps+1, maximum(x)), exp_intervals_fwd)
        lasfwd = gen_pulses(nsamps_stack, las_intervals_fwd)
        las_intervals_back = map(x-> ClosedInterval(maximum(x)-flash_nsamps+1, maximum(x)), exp_intervals_back)
        lasback = gen_pulses(nsamps_stack, las_intervals_back)
    else
        lasfwd = fill(true, length(posfwd))
        lasback = fill(true, length(posback))
    end

    camfwd = gen_pulses(nsamps_stack, exp_intervals_fwd)
    camback = gen_pulses(nsamps_stack, exp_intervals_back)
    if alternate_cameras
        output = Dict("positioner" => vcat(posfwd, posback),
                    "camera_fwd" => vcat(camfwd, fill(false, length(camback))),
                    "camera_back" => vcat(fill(false, length(camfwd)), camback),
                    "laser_fwd" => vcat(lasfwd, fill(false, length(lasback))),
                    "laser_back" => vcat(fill(false, length(lasfwd)), lasback),
                    "nframes_per_cam" => length(exp_intervals_fwd))
        return output
    else
        output = Dict("positioner" => vcat(posfwd, posback), "camera" => vcat(camfwd, camback), "laser" => vcat(lasfwd, lasback), "nframes" => length(exp_intervals_fwd)*2)
        return output
    end
end

function gen_stepped_stack{TL<:HasLengthUnits, TT<:HasTimeUnits, TTI<:HasInverseTimeUnits}(pmin::TL, pmax::TL, z_spacing::TL, pause_time::TT, reset_time::TT, exp_time::TT, sample_rate::TTI, flash_frac::Real; rig="ocpi-2")
    if exp_time > pause_time
        error("Pause duration must be greater than or equal to exposure duration")
    end
    if pmin == pmax
        error("Use the gen_2d_timeseries function instead of setting pmin and pmax to the same value")
    end
    flash = true
    if flash_frac > 1
        warn("las_frac was set greater than 1, so defaulting to keeping laser on throughout the stack")
        flash = false
    elseif flash_frac <= 0
        error("las_frac must be positive")
    end

    pmin = uconvert(Unitful.μm, pmin)
    pmax = uconvert(Unitful.μm, pmax)
    z_spacing = uconvert(Unitful.μm, z_spacing)

    pause_time = uconvert(Unitful.s, pause_time)
    exp_time = uconvert(Unitful.s, exp_time)
    sample_rate = uconvert(inv(Unitful.s), sample_rate)

    curmin = curmax = pmin
    prng = pmax - pmin
    nslices = floor(Int, prng / z_spacing)+1
    pause_starts = Int[]
    pause_stops = Int[]
    posfwd = typeof(curmin)[]
    for i = 1:(nslices-1)
        push!(pause_starts, length(posfwd)+1)
        cur_pause = gen_sweep(curmax, curmax, pause_time, sample_rate)
        append!(posfwd, cur_pause)
        curmin = curmax
        curmax = curmax + z_spacing
        push!(pause_stops, length(posfwd))
        cur_sweep = gen_safe_sweep(curmin, curmax, sample_rate,rig)
        append!(posfwd, cur_sweep)
    end
    #final pause
    push!(pause_starts, length(posfwd)+1)
    append!(posfwd, gen_sweep(curmax, curmax, pause_time, sample_rate))
    nsamps_stack = length(posfwd)
    push!(pause_stops, nsamps_stack)
    #camera pulse intervals
    exp_intervals = Array{ClosedInterval{Int}}(nslices)
    pause_nsamps = pause_stops[1] - pause_starts[1]
    exp_nsamps = calc_num_samps(exp_time, sample_rate)
    samp_offset = floor(Int, (pause_nsamps - exp_nsamps) / 2) #center the exposure within the positioner pause
    for i = 1:nslices
        exp_start = pause_starts[i] + samp_offset
        exp_intervals[i] = ClosedInterval(exp_start, exp_start+exp_nsamps-1)
    end
    camfwd = gen_pulses(nsamps_stack, exp_intervals)
    #laser pulse intervals
    if flash
        pulse_nsamps = calc_num_samps(flash_frac * exp_time, sample_rate)
        las_intervals = map(x-> ClosedInterval(maximum(x)-pulse_nsamps+1, maximum(x)), exp_intervals)
        lasfwd = gen_pulses(nsamps_stack, las_intervals)
    else
        lasfwd = fill(true, nsamps_stack)
    end
    #reset
    posreset = gen_sweep(curmax, pmin, reset_time, sample_rate)
    reset_digi = fill(false, length(posreset))
    output = Dict("positioner" => vcat(posfwd, posreset), "camera" => vcat(camfwd, reset_digi), "laser" => vcat(lasfwd, reset_digi), "nframes" => length(exp_intervals))
    return output
end


function gen_unidirectional_stack{TL<:HasLengthUnits, TT<:HasTimeUnits, TTI<:HasInverseTimeUnits}(pmin::TL, pmax::TL, z_spacing::TL, stack_time::TT, reset_time::TT, exp_time::TT, sample_rate::TTI, flash_frac::Real; z_pad::TL = 1.0*Unitful.μm, rig="ocpi-2")
    if pmin == pmax
        error("Use the gen_2d_timeseries function instead of setting pmin and pmax to the same value")
    end
    flash = true
    if flash_frac > 1
        warn("las_frac was set greater than 1, so defaulting to keeping laser on throughout the stack")
        flash = false
    elseif flash_frac <= 0
        error("las_frac must be positive")
    end

    pmin = uconvert(Unitful.μm, pmin)
    pmax = uconvert(Unitful.μm, pmax)
    z_spacing = uconvert(Unitful.μm, z_spacing)
    z_pad = uconvert(Unitful.μm, z_pad)

    stack_time = uconvert(Unitful.s, stack_time)
    exp_time = uconvert(Unitful.s, exp_time)
    sample_rate = uconvert(inv(Unitful.s), sample_rate)

    nsamps_stack = calc_num_samps(stack_time, sample_rate)
    posfwd, posreset = gen_sawtooth(pmin, pmax, stack_time, reset_time, sample_rate)

    exp_intervals = spaced_intervals(posfwd, z_spacing, exp_time, sample_rate; z_pad = z_pad, alignment=:start, rig=rig)
    
    if flash
        pulse_nsamps = calc_num_samps(flash_frac * exp_time, sample_rate)
        las_intervals = map(x-> ClosedInterval(maximum(x)-pulse_nsamps+1, maximum(x)), exp_intervals)
        lasfwd = gen_pulses(nsamps_stack, las_intervals)
    else
        lasfwd = fill(true, length(posfwd))
    end

    camfwd = gen_pulses(nsamps_stack, exp_intervals)
    reset_digi = fill(false, length(posreset))

    output = Dict("positioner" => vcat(posfwd, posreset), "camera" => vcat(camfwd, reset_digi), "laser" => vcat(lasfwd, reset_digi), "nframes" => length(exp_intervals))

    return output
end

function gen_2d_timeseries{TL<:HasLengthUnits, TT<:HasTimeUnits, TTI<:HasInverseTimeUnits}(position::TL, nframes::Int, exp_time::TT, inter_exp_time::TT, sample_rate::TTI, flash_frac::Real)
    cycle_time = exp_time + inter_exp_time
    exp_samps = round(Int, exp_time * sample_rate)
    cycle_samps = round(Int, cycle_time * sample_rate)
    inter_exp_samps = round(Int, inter_exp_time * sample_rate)
    nsamps = round(Int, nframes * cycle_time * sample_rate)
    pos = fill(position, nsamps)
    exp_intervals = Array{ClosedInterval{Int}}(nframes)
    curstart = div(inter_exp_samps,2) #offset by half the interframe time
    for i = 1:nframes
        exp_intervals[i] = ClosedInterval(curstart, curstart+exp_samps-1)
        curstart += cycle_samps
    end
    pulse_nsamps = calc_num_samps(flash_frac * exp_time, sample_rate)
    las_intervals = map(x-> ClosedInterval(maximum(x)-pulse_nsamps+1, maximum(x)), exp_intervals)
    cam = gen_pulses(nsamps, exp_intervals)
    las = gen_pulses(nsamps, las_intervals)
    output = Dict("positioner" => pos, "camera" => cam, "laser" => las)
    return output
end
 
