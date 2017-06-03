using Ranges #delete this when we drop 0.5 support

#The sweep covers an interval that is closed on the left and open on the right.
#i.e. a sweep from 0 to 10 will include a sample at 0 but not at 10
function gen_sweep(pmin::HasLengthUnits, pmax::HasLengthUnits, tsweep::HasTimeUnits, sample_rate::HasInverseTimeUnits)
    tsweeps = uconvert(Unitful.s, tsweep)
    pminum = uconvert(Unitful.μm, pmin)
    pmaxum = uconvert(Unitful.μm, pmax)
    nsamps = round(Int, tsweeps*sample_rate)
    increment = (pmaxum - pminum) / nsamps
    return Ranges.linspace(pminum, pmaxum-increment, nsamps)
end

#Generate sets of samples describing the motion of the positioner during one stack
function gen_sawtooth(pmin::HasLengthUnits, pmax::HasLengthUnits, tfwd::HasTimeUnits, treset::HasTimeUnits, sample_rate::HasInverseTimeUnits)
    fwd_linspace = gen_sweep(pmin, pmax, tfwd, sample_rate)
    reset_linspace = gen_sweep(pmax, pmin, treset, sample_rate)
    return fwd_linspace, reset_linspace
end
gen_bidi_pos(pmin::HasLengthUnits, pmax::HasLengthUnits, tsweep::HasTimeUnits, sample_rate::HasInverseTimeUnits) = gen_sawtooth(pmin, pmax, tsweep, tsweep, sample_rate)

#returns a vector of sample-index intervals separated by `interval_spacing`.
#The first interval is offset from the first sample of the sampled region by the `offset` keyword arg
#The `z_pad` kwarg, specified in non-temporal units, will prevent placement of intervals at the extremes of the smaple space
#The `alignment` kwarg determines whether the first interval begins at the first valid sample (:start) or the last interval ends at the last valid sample (:stop)
#Thus :start and :stop will produce equal results for certain well-dividing sample counts, but most of the time they are different
function spaced_intervals{TS, TT}(samples_space::Ranges.LinSpace{TS}, interval_spacing::TS, interval_duration::TT, samp_duration::TT;
                                delay::TT=uconvert(unit(TT), 0.0*Unitful.s), z_pad::TS = uconvert(unit(TS), 1.0*Unitful.μm), alignment=:start)
    if !in(alignment, (:start, :stop))
        error("Only :start and :stop alignment is supported")
    end
    sampsize = abs(step(samples_space))
    pad_samps = round(Int, z_pad/sampsize)
    delay_samps = round(Int, delay/samp_duration)
    offset = pad_samps + delay_samps
    nsamps = length(samples_space) - offset - pad_samps
    dur_samps = interval_duration/samp_duration + 1
    if abs(dur_samps-round(Int, dur_samps))/dur_samps > 0.01
        warn("The requested interval_duration cannot be achieved to within 1% accuracy with the current sampling rate.  Consider increasing the sampling rate.")
    end
    dur_samps = round(Int, dur_samps)
    spacing_samps = interval_spacing/sampsize
    if abs(spacing_samps-round(Int, spacing_samps))/spacing_samps > 0.01
        warn("The requested spacing cannot be achieved to within 1% accuracy with the current sampling rate.  Consider increasing the sampling rate.")
    end
    spacing_samps = round(Int, spacing_samps)
    
    if spacing_samps <= dur_samps
        error("The requested spacing results in overlapping intervals.  Increase interval_spacing, decrease interval_duration, or change sampling rate.")
    end
    inter_samps = spacing_samps - dur_samps #number of samples between end of one interval and start of the next
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

function gen_bidirectional_stack{TL<:HasLengthUnits, TT<:HasTimeUnits, TTI<:HasInverseTimeUnits}(pmin::TL, pmax::TL, z_spacing::TL, stack_time::TT, exp_time::TT, sample_rate::TTI, flash_frac::Real; z_pad::TL = 1.0*Unitful.μm)
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

    nsamps_stack = ceil(Int, stack_time*sample_rate)
    posfwd, posback = gen_bidi_pos(pmin, pmax, stack_time, sample_rate)
    #offset by one sample going forward so that we don't use the end points of the triangle
    delay1samp = 1/sample_rate

    exp_intervals_fwd = spaced_intervals(posfwd, z_spacing, exp_time, 1/sample_rate; delay=delay1samp, z_pad = z_pad, alignment=:start)
    exp_intervals_back = spaced_intervals(posback, z_spacing, exp_time, 1/sample_rate; delay=0.0*Unitful.s, z_pad = z_pad, alignment=:stop)
    
    if flash
        las_intervals_fwd = map(x->scale(x, flash_frac), exp_intervals_fwd)
        lasfwd = gen_pulses(nsamps_stack, las_intervals_fwd)
        #samps_las_back = gen_pulses(nsamps_stack, las_intervals_back) #this can be off-by-one sample due to rounding in the scale function
        lasback = reverse(circshift(lasfwd,-1)) 
    else
        lasfwd = fill(true, length(posfwd))
        lasback = fill(true, length(posback))
    end

    camfwd = gen_pulses(nsamps_stack, exp_intervals_fwd)
    camback = gen_pulses(nsamps_stack, exp_intervals_back)

    output = Dict("positioner" => vcat(posfwd, posback), "camera" => vcat(camfwd, camback), "laser" => vcat(lasfwd, lasback), "nframes" => length(exp_intervals_fwd)*2)

    return output
end

function gen_unidirectional_stack{TL<:HasLengthUnits, TT<:HasTimeUnits, TTI<:HasInverseTimeUnits}(pmin::TL, pmax::TL, z_spacing::TL, stack_time::TT, reset_time::TT, exp_time::TT, sample_rate::TTI, flash_frac::Real; z_pad::TL = 1.0*Unitful.μm)
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

    nsamps_stack = ceil(Int, stack_time*sample_rate)
    posfwd, posreset = gen_sawtooth(pmin, pmax, stack_time, reset_time, sample_rate)

    exp_intervals = spaced_intervals(posfwd, z_spacing, exp_time, 1/sample_rate; z_pad = z_pad, alignment=:start)
    
    if flash
        las_intervals = map(x->scale(x, flash_frac), exp_intervals)
        lasfwd = gen_pulses(nsamps_stack, las_intervals)
    else
        lasfwd = fill(true, length(posfwd))
    end

    camfwd = gen_pulses(nsamps_stack, exp_intervals)
    reset_digi = fill(false, length(posreset))

    output = Dict("positioner" => vcat(posfwd, posreset), "camera" => vcat(camfwd, reset_digi), "laser" => vcat(lasfwd, reset_digi), "nframes" => length(exp_intervals))

    return output
end
