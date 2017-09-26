#gets the index of the first high value for each pulse in a sequence
#if pad_first is true then the first index counts if it is high
function find_pulse_starts(pulses::AbstractVector{Bool}; pad_first = true)
    output = Int[]
    if pad_first && pulses[1]
        push!(output, 1)
    end
    is_high = pulses[1]
    for i = 2:length(pulses)
        if !is_high
            if pulses[i]
                push!(output, i)
                is_high = true
            end
        elseif !pulses[i]
                is_high = false
        end
    end
    return output
end

#gets the index of the last high value for each pulse in a sequence
#if pad_last is true then the last index counts if it is high
function find_pulse_stops(pulses::AbstractVector{Bool}; pad_last = true)
    output = Int[]
    is_low = !pulses[1]
    for i = 2:length(pulses)
        if !is_low
            if !pulses[i]
                push!(output, i-1)
                is_low = true
            end
        elseif pulses[i]
                is_low = false
        end
    end
    if pad_last && pulses[end]
        push!(output, length(pulses))
    end
    return output
end

find_pulse_starts(pulses::AbstractVector{Bool}, thresh) = find_pulse_starts(pulses)
find_pulse_stops(pulses::AbstractVector{Bool}, thresh) = find_pulse_stops(pulses)
find_pulse_starts(pulses::AbstractVector{Bool}, thresh::Bool) = find_pulse_starts(pulses)
find_pulse_stops(pulses::AbstractVector{Bool}, thresh::Bool) = find_pulse_stops(pulses)

find_pulse_starts{T}(pulses::AbstractVector{T}, thresh::T) = find_pulse_starts(pulses.>=thresh)
find_pulse_stops{T}(pulses::AbstractVector{T}, thresh::T) = find_pulse_stops(pulses.>=thresh)
find_pulse_starts(com::ImagineSignal; thresh = 1.15 * Unitful.V, sampmap = :world) = find_pulse_starts(get_samples(com; sampmap=sampmap).data, thresh)
find_pulse_stops(com::ImagineSignal; thresh = 1.15 * Unitful.V, sampmap = :world) = find_pulse_stops(get_samples(com; sampmap=sampmap).data, thresh)

function count_pulses{T}(pulses::AbstractVector{T}, thresh::T)
    nstarts = length(find_pulse_starts(pulses, thresh))
    nstops = length(find_pulse_stops(pulses, thresh))
    if nstarts != nstops
        warn("Found a different number of pulse starts than stops; returning the larger number")
    end
    return max(nstarts, nstops)
end

#default threshold is half of 3.3V TTL pulse -> 1.15V
count_pulses(com::ImagineSignal; thresh = isdigital(com) ? true : 1.15 * Unitful.V, sampmap = :world) = count_pulses(get_samples(com; sampmap = sampmap).data, thresh)

