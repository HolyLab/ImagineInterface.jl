#find the index of the first high sample
find_pulse_starts(pulses::AbstractVector{Bool}) = find(x->x==1, diff(pulses)).+1
#find index of the last high sample
find_pulse_stops(pulses::AbstractVector{Bool}) = find(x->x==-1, diff(pulses))
find_pulse_starts(pulses::AbstractVector{Bool}, thresh::Bool) = find_pulse_starts(pulses)
find_pulse_stops(pulses::AbstractVector{Bool}, thresh::Bool) = find_pulse_stops(pulses)

find_pulse_starts{T}(pulses::AbstractVector{T}, thresh::T) = find_pulse_starts(pulses.>=thresh)
find_pulse_stops{T}(pulses::AbstractVector{T}, thresh::T) = find_pulse_stops(pulses.>=thresh)
find_pulse_starts(com::ImagineCommand; thresh = 1.15 * Unitful.V, sampmap = :world) = find_pulse_starts(decompress(com; sampmap=sampmap), thresh)
find_pulse_stops(com::ImagineCommand; thresh = 1.15 * Unitful.V, sampmap = :world) = find_pulse_stops(decompress(com; sampmap=sampmap), thresh)

function count_pulses{T}(pulses::AbstractVector{T}, thresh::T)
    nstarts = length(find_pulse_starts(pulses, thresh))
    nstops = length(find_pulse_stops(pulses, thresh))
    if nstarts != nstops
        warn("Found a different number of pulse starts than stops; returning the larger number")
    end
    return max(nstarts, nstops)
end

#default threshold is half of 3.3V TTL pulse -> 1.15V
count_pulses(com::ImagineCommand; thresh = isdigital(com) ? true : 1.15 * Unitful.V, sampmap = :world) = count_pulses(decompress(com; sampmap = sampmap), thresh)

