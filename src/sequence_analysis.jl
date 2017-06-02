find_pulse_starts(pulses::AbstractVector{Bool}) = find(x->x==1, diff(pulses))
find_pulse_stops(pulses::AbstractVector{Bool}) = find(x->x==-1, diff(pulses))

function find_pulse_starts(com::ImagineCommand) 
    if !isdigital(com)
        error("This function requires a digital command")
    end
    return find_pulse_starts(decompress(com))
end

function find_pulse_stops(com::ImagineCommand) 
    if !isdigital(com)
        error("This function requires a digital command")
    end
    return find_pulse_stops(decompress(com))
end

function count_pulses(pulses::AbstractVector{Bool})
    nstarts = length(find_pulse_starts(pulses))
    nstops = length(find_pulse_stops(pulses))
    if nstarts != nstops
        warn("Found a different number of pulse starts than stops; returning the larger number")
    end
    return max(nstarts, nstops)
end

function count_pulses(com::ImagineCommand)
    if !isdigital(com)
        error("This function requires a digital command")
    end
    return count_pulses(decompress(com))
end

