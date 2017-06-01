using Ranges #delete this when we drop 0.5 support

#The sweep covers an interval that is closed on the left and open on the right.
#i.e. a sweep from 0 to 10 will include a sample at 0 but not at 10
function gen_sweep(pmin::HasLengthUnits, pmax::HasLengthUnits, tsweep::HasTimeUnits, samprate::HasInverseTimeUnits)
    tsweeps = uconvert(Unitful.s, tsweep)
    pminum = uconvert(Unitful.μm, pmin)
    pmaxum = uconvert(Unitful.μm, pmax)
    nsamps = round(Int, tsweeps*samprate)
    increment = (pmaxum - pminum) / nsamps
    return Ranges.linspace(pminum, pmaxum-increment, nsamps)
end

#Generate sets of samples describing the motion of the positioner during one stack
function gen_sawtooth(pmin::HasLengthUnits, pmax::HasLengthUnits, tfwd::HasTimeUnits, treset::HasTimeUnits, samprate::HasInverseTimeUnits)
    fwd_linspace = gen_sweep(pmin, pmax, tfwd, samprate)
    reset_linspace = gen_sweep(pmax, pmin, treset, samprate)
    return fwd_linspace, reset_linspace
end
gen_bidi_pos(pmin::HasLengthUnits, pmax::HasLengthUnits, tsweep::HasTimeUnits, samprate::HasInverseTimeUnits) = gen_sawtooth(pmin, pmax, tsweep, tsweep, samprate)

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


