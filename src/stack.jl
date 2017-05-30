using Ranges #delete this when we drop 0.5 support

#The sweep covers an interval that is closed on the left and open on the right.
#i.e. a sweep from 0 to 10 will include a sample at 0 but not at 10
function gen_sweep(pmin::Unitful.Length, pmax::Unitful.Length, tsweep::Unitful.Time, samprate::Int)
    tsweeps = uconvert(Unitful.s, tsweep)
    pminum = uconvert(Unitful.μm, pmin)
    pmaxum = uconvert(Unitful.μm, pmax)
    nsamps = round(Int, (tsweeps/unit(tsweeps))*samprate)
    increment = (pmaxum - pminum) / nsamps
    return Ranges.linspace(pminum, pmaxum-increment, nsamps)
end

#Generate sets of samples describing the motion of the positioner during one stack
function gen_sawtooth(pmin::Unitful.Length, pmax::Unitful.Length, tfwd::Unitful.Time, treset::Unitful.Time, samprate::Int)
    fwd_linspace = gen_sweep(pmin, pmax, tfwd, samprate)
    reset_linspace = gen_sweep(pmax, pmin, treset, samprate)
#    samp_vec = vcat(fwd_samps, reset_samps)
#    ax = Axis{:time}(linspace(0.0*Unitful.s, (length(samp_vec)-1)*dt, length(samp_vec)))
#    return AxisArray(samp_vec, ax)
    return fwd_linspace, reset_linspace
end
gen_bidi_pos(pmin::Unitful.Length, pmax::Unitful.Length, tsweep::Unitful.Time, samprate::Int) = gen_sawtooth(pmin, pmax, tsweep, tsweep, samprate)

#returns a vector of sample-index intervals separated by `spacing`.  The first interval is offset from the first sample of the sampled region by the `offset` keyword arg
#function spaced_intervals{T}(sampled_region::LinSpace{T}, wdth::T, spacing::T; offset=0::Int)
function spaced_intervals{TS, TT}(samples_space::Ranges.LinSpace{TS}, spacing::TS, duration::TT, samprate::Int;
                                delay=uconvert(unit(TT), 0.0*Unitful.s), z_pad = uconvert(unit(TS), 1.0*Unitful.μm), alignment=:start)
    if !in(alignment, (:start, :stop))
        error("Only :start and :stop alignment is supported")
    end
#    times = axisvalues(axes(sampled_region, Axis{:time}))[1]
    sampdur = uconvert(unit(TT), (1/samprate)*Unitful.s)
    sampsize = abs(step(samples_space))
    pad_samps = round(Int, z_pad/sampsize)
    delay_samps = round(Int, delay/sampdur)
    offset = pad_samps + delay_samps
    nsamps = length(samples_space) - offset - pad_samps
    dur_samps = duration/sampdur
    if abs(dur_samps-round(Int, dur_samps))/dur_samps > 0.01
        warn("The requested duration cannot be achieved to within 1% accuracy with the current sampling rate.  Consider increasing the sampling rate.")
    end
    dur_samps = round(Int, dur_samps)
    spacing_samps = spacing/sampsize
    if abs(spacing_samps-round(Int, spacing_samps))/spacing_samps > 0.01
        warn("The requested spacing cannot be achieved to within 1% accuracy with the current sampling rate.  Consider increasing the sampling rate.")
    end
    spacing_samps = round(Int, spacing_samps)
    
    if spacing_samps <= dur_samps
        error("The requested spacing results in overlapping intervals.  Increase spacing, decrease duration, or change sampling rate.")
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
        error("The requested duration is longer than the sampled region.")
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


