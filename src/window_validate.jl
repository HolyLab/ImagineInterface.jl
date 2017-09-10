#general validation strategy:
#   check all used subsequences individually, adding them to ValidationState if they pass testing
#   check all sequence transitions
#      iterate chronologically through sequences
#      check whether the ValidationState has an entry for the next sequence.
#      If so, proceed directly to next sequence
#      If not, keep the last min_samps-1 samples and read the first min_samps-1 samples of the next sequence.  Check that sequence
#           note that if there are not min_samps-1 samples in the NEXT sequence then we can't add it to the dictionary.  in that case:
#                keep reading more sequences until we get enough samples, do the check
#                assuming check passes, proceed to the next sequence without adding anything to the dictionary
#      Assuming that the combined sequence passes validation, add the transition to ValidationState
#   

type ValidationState
    sequences::Set{String}
    transitions::Dict{String, Set{String}}
end

valid_sequences(vs::ValidationState) = vs.sequences
valid_transitions(vs::ValidationState) = vs.transitions

set_validated!(vs::ValidationState, seq_name::String) = push!(valid_sequences(vs), seq_name)
set_validated!(vs::ValidationState, trans_from::String, trans_to::String) = push!(valid_transitions(vs)[trans_from], trans_to)

is_validated(vs::ValidationState, seq_name::String) = in(seq_name, valid_sequences(vs))
is_validated(vs::ValidationState, trans_from::String, trans_to::String) = in(trans_to, valid_transitions(vs)[trans_from])

ValidationState() = ValidationState(Set{String}(), Dict{String, Set{String}}())

function window_validate!(vs::ValidationState, val_func::Function, window_sz::Int, sig::ImagineSignal)
    if length(sig) < window_sz
        error("Insufficient samples to check this signal with a window size setting of $window_sz")
    end
    seq_nms = sequence_names(sig)
    lookup = sequence_lookup(sig)
    seq_lens = Dict()
    seqs_used = unique(seq_nms)
    for nm in seqs_used #precompute compressed vector lengths
        seq_lens[nm] = full_length(lookup[nm])
    end
    #check each sequence used
    for nm in seqs_used
        if !is_validated(vs, nm) && seq_lens[nm] >= window_sz
            samps = get_samples(sig, nm; sampmap=:raw).data
            isgood = val_func(samps, window_sz)
            if !isgood
                error() #The caller should catch this to give a more specific error message
            else
                set_validated!(vs, nm)
            end
        end
    end
    #check all transitions between sequences
    for i = 1:(length(seq_nms)-1)
        this_nm = seq_nms[i]
        next_nm = seq_nms[i+1]
        if !is_validated(vs, this_nm, next_nm)
            this_len = seq_lens[this_nm]
            @assert this_len >= 1
            next_len = seq_lens[next_nm]
            #NOTE: below is inefficient because we read the whole sequence.  If it becomes an issue, we should define getindex for RLEVectors
            this_samps = view(get_samples(sig, this_nm; sampmap=:raw).data, max(1, this_len - window_sz + 1), this_len)
            next_samps = -1;
            record_validation = next_len >= (window_sz-1) #only record validation if we have enough samples in the next sequence to do a check
            out_of_seqs = false #useful for if we don't have enough samples to check the last sequence transition
            if !record_validation #keep reading more samples until we have enough.  This is pretty inefficient, but it should happen very rarely.
                nexti = i+1
                enough = false
                next_samps = get_samples(sig, next_nm; sampmap=:raw).data
                while !enough
                    needed = (window_sz-1) - length(next_samps)
                    next_next = get_samples(sig, seq_nms[nexti]; sampmap=:raw).data
                    if length(next_next) >= needed
                        enough = true
                        next_samps = append!(next_samps, next_next[1:needed])
                    elseif nexti > length(seq_nms) #we've run out of sequences
                        out_of_seqs = true
                        break
                    else
                        next_samps = append!(next_samps, next_next)
                        nexti+=1
                    end
                end
            else
                next_samps = view(get_samples(sig, next_nm; sampmap=:raw).data, 1, window_sz)
            end
            samps_to_check = out_of_seqs ? get_samples(sig, length(sig) - 2*window_sz + 2, length(sig)).data : cat(this_samps, next_samps)
            isgood = check_max_speed(samps_to_check, max_dist_raw, window_sz)
            if !isgood
                error() #The caller should catch this to give a more specific error message
            elseif record_validation
                set_validated!(vs, this_nm, next_nm)
            end
        end
    end
    return vs
end

window_validate(val_func::Function, window_sz::Int, sig::ImagineSignal) = window_validate!(ValidationState(), val_func, window_sz, sig)
