immutable RepeatedValue{T}
    n::Int
    value::T
end

value{T}(rv::RepeatedValue{T}) = rv.value
count{T}(rv::RepeatedValue{T}) = rv.n

convert{T}(::Type{RepeatedValue{T}}, rv::RepeatedValue) = RepeatedValue{T}(rv.n, rv.value)

"RLEVector is a run-length encoded vector"
const RLEVector{T} = Vector{RepeatedValue{T}}
full_length{T}(vec::RLEVector{T}) = sum(map(count, vec))
# Use the first "real" value to infer the type. Not type-stable.
convert(::Type{RLEVector}, v::AbstractVector) = isempty(v) ?
convert(RLEVector{Any}, v) :
convert(RLEVector{typeof(v[2])}, v)
convert{T}(::Type{RLEVector{T}}, v::RLEVector{T}) = v
convert{T,S}(::Type{RLEVector{T}}, v::RLEVector{S}) = [convert(RepeatedValue{T}, rv) for rv in v]
convert(::Type{RLEVector}, v::RLEVector) = v

function convert{T,S}(::Type{RLEVector{T}}, v::AbstractVector{S})
    iseven(length(v)) || error("not a run-length encoded vector (length is odd)")
    n = length(v) ÷ 2
    out = Vector{RepeatedValue{T}}(n)
    for i = 1:n
        out[i] = RepeatedValue{T}(v[2i-1], v[2i])
    end
    out
end

type ImagineSignal{Vectype<:AbstractVector}
    chan_name::String
    daq_chan_name::String
    rig_name::String
    sequences::Vector{Vectype}
    sequence_names::Vector{String}
    sequence_lookup::Dict
    cumlength::Vector{Int}
    mapper::SampleMapper
end

function show(io::IO, com::ImagineSignal)
    if isdigital(com)
        print(io, "Digital ")
    else
        print(io, "Analog ")
    end
    if isoutput(com)
        print(io, "Output ")
    else
        print(io, "Input ")
    end
    print(io, "ImagineSignal")
    if isdigital(com)
        print(io, "\n")
    else
        print(io, " encoding values from $(mapper(com).worldmin) to $(mapper(com).worldmax)\n")
    end
    print(io, "           Channel name: $(name(com))\n")
    print(io, "            DAQ Channel: $(daq_channel(com))\n")
    print(io, "                    Rig: $(rig_name(com))\n")
    print(io, "               Raw type: $(rawtype(com))\n")
    print(io, "              Intervals: $(intervals(com))\n")
    print(io, "               Duration: $(duration(com))\n")
    print(io, "      Duration(samples): $(length(com))\n")
end

Base.length(com::ImagineSignal) = isempty(com) ? 0 : com.cumlength[end]
duration(com::ImagineSignal) = length(com)/samprate(com)
Base.size(C::ImagineSignal)    = length(C)
Base.isempty(com::ImagineSignal) = isempty(cumlength(com))

==(com1::ImagineSignal, com2::ImagineSignal) = fieldnames_equal(com1, com2, union(fieldnames(com1), fieldnames(com2)))

function fieldnames_equal(com1::ImagineSignal, com2::ImagineSignal, nms::Vector{Symbol})
    is_eq = true
    for nm in nms
        if getfield(com1, nm) != getfield(com2, nm)
            is_eq = false
            break
        end
    end
    return is_eq
end

function is_similar(com1::ImagineSignal, com2::ImagineSignal)
    can_differ = [:sequences; :sequence_names; :sequence_lookup; :cumlength] #fields related to the count and values of samples
    must_match = setdiff(union(fieldnames(com1), fieldnames(com2)), can_differ)
    return fieldnames_equal(com1, com2, must_match)
end

name(com::ImagineSignal) = com.chan_name
function rename!(com::ImagineSignal, newname::String)
    if isfree(com)
        com.chan_name = newname
    elseif com.chan_name != newname
        error("Cannot rename this command because it's essential to the microscope (camera, positioner, laser, etc).  To see which commands in a list may be renamed, run getfree(coms)")
    end
    return com
end
daq_channel(com::ImagineSignal) = com.daq_chan_name
daq_channel_number(com::ImagineSignal) = daq_channel_number(com.daq_chan_name)
rig_name(com::ImagineSignal) = com.rig_name
rawtype(com::ImagineSignal) = rawtype(mapper(com))
worldtype(com::ImagineSignal) = worldtype(mapper(com))
sequences(com::ImagineSignal) = com.sequences
sequence_names(com::ImagineSignal) = com.sequence_names
sequence_lookup(com::ImagineSignal) = com.sequence_lookup
mapper(com::ImagineSignal) = com.mapper
intervals(com::ImagineSignal) = intervals(mapper(com))
interval_raw(com::ImagineSignal) = interval_raw(mapper(com))
interval_volts(com::ImagineSignal) = interval_volts(mapper(com))
interval_world(com::ImagineSignal) = interval_world(mapper(com))
cumlength(com::ImagineSignal) = com.cumlength
samprate(com::ImagineSignal) = samprate(mapper(com))
set_samprate!(com::ImagineSignal, r::Int) = set_samprate!(mapper(com), r)
iscompressed{T<:RLEVector}(com::ImagineSignal{T}) = true
iscompressed{T}(com::ImagineSignal{T}) = false

function calc_cumlength!{T<:AbstractVector}(output::Vector{Int}, seqs::Vector{T})
    if !isempty(seqs)
        output[1] = length(seqs[1])
        for i = 2:length(seqs)
            output[i] = output[i-1] + length(seqs[i])
        end
    end
    return output
end
function calc_cumlength!{RV<:RLEVector}(output::Vector{Int}, seqs::Vector{RV})
    if !isempty(seqs)
        output[1] = sum(s.n for s in seqs[1])
        for i = 2:length(seqs)
            output[i] = output[i-1] + sum(s.n for s in seqs[i])
        end
    end
    return output
end

recalculate_cumlength!(com) = calc_cumlength!(com.cumlength, sequences(com))

function compress!{T}(output::RLEVector{T}, input::AbstractVector{T})
    if isempty(input)
        return output
    end
    count = 1
    curval = input[1]
    for i = 2:length(input)
        if(curval != input[i])
            push!(output, RepeatedValue(count, curval))
            count = 1
            curval = input[i]
        else
            count+=1
        end
    end
    push!(output, RepeatedValue(count, input[end]))
    return output
end
function compress{T}(input::AbstractVector{T})
    output = Vector{RepeatedValue{T}}(0)
    return compress!(output, input)
end
compress(input::RLEVector) = input
compress{Traw, TV, TW}(seq::AbstractVector{Traw}, mapper::SampleMapper{Traw, TV, TW}) = compress!(RepeatedValue{Traw}[], mappedarray(bounds_check(mapper), seq))
#Digital signals use the same types for raw and world samples, so no need to map them
compress{Traw, TV}(seq::AbstractVector{Traw}, mapper::SampleMapper{Traw, TV, Traw}) = compress!(RepeatedValue{Traw}[], mappedarray(bounds_check(mapper), seq))
compress{Traw, TV1, TV2<:HasVoltageUnits, TW}(seq::AbstractVector{TV2}, mapper::SampleMapper{Traw, TV1, TW}) = compress!(RepeatedValue{Traw}[], mappedarray(volts2raw(mapper), seq))
compress{Traw, TV, TW}(seq::AbstractVector{TW}, mapper::SampleMapper{Traw, TV, TW}) = compress!(RepeatedValue{Traw}[], mappedarray(world2raw(mapper), seq))
#attempt conversion when Quantity types don't exactly match (Float32 vs Float64 precision, for example)
compress{Traw, TV, TW, T}(seq::AbstractVector{T}, mapper::SampleMapper{Traw, TV, TW}) = compress(map(x->convert(TW, x), seq), mapper)

function get_samples(com::ImagineSignal, tstart::HasTimeUnits, tstop::HasTimeUnits; sampmap=:world)
    tstart = uconvert(unit(inv(samprate(com))), tstart)
    tstop = uconvert(unit(inv(samprate(com))), tstop)
    istart = ceil(Int64, tstart * samprate(com))+1
    istop = floor(Int64, tstop * samprate(com))+1
    return get_samples(com, istart, istop; sampmap=sampmap)
end
function get_samples(com::ImagineSignal, istart::Int, istop::Int; sampmap=:world)
    if !in(sampmap, (:world, :volts, :raw))
        error("Unrecognized sample mapping")
    end
    @assert istart <= istop
    nsamps = istop - istart + 1
    datm = get_samples_raw(com, istart, istop)

    if sampmap == :world || sampmap == :volts
        f0 = raw2volts(mapper(com))
        f0inv = volts2raw(mapper(com))
        datm = mappedarray((f0,f0inv), datm)
    end
    if sampmap == :world
        f1 = volts2world(mapper(com))
        f1inv = world2volts(mapper(com))
        datm = mappedarray((f1, f1inv), datm)
    end
    tstart = (istart-1) / samprate(com)
    tstop = (istop-1) / samprate(com)
    ax = Axis{:time}(linspace(tstart, tstop, nsamps))
    return AxisArray(datm, ax)
end
get_samples(com::ImagineSignal; sampmap=:world) = get_samples(com, 1, length(com); sampmap=sampmap)
function get_samples(com::ImagineSignal, sequence_name::String; sampmap = :world)
    #find start and stop indices of the first occurence of that sequence
    seqi = findfirst(x->x==sequence_name, sequence_names(com))
    if seqi == 0
        error("Sequence name not found")
    end
    if seqi == 1
        starti = 1
    else
        starti = cumlength(com)[seqi-1]+1
    end
    stopi = cumlength(com)[seqi]
    return get_samples(com, starti, stopi; sampmap=sampmap)
end

#This version gets called for input signals
get_samples_raw{T<:AbstractVector}(com::ImagineSignal{T}, istart::Int, istop::Int) = sequences(com)[1][istart:istop]

#This version gets called for output signals
function get_samples_raw{T<:RLEVector}(com::ImagineSignal{T}, istart::Int, istop::Int)
    if istart < 1 || istop > length(com) #bounds check
        error("The requested time interval is out of bounds")
    end

    iseq = 1 #index into the sequence vector
    offset0 = 0

    #find the sequence containing istart
    if istart > com.cumlength[1]
        for i = 2:length(com.cumlength)
            curlen = com.cumlength[i]
            if istart <= curlen
                iseq = i
                offset0 = istart - com.cumlength[i-1]
                break
            end
        end
    else
        offset0 = istart
    end
    seq = com.sequences[iseq]
    ival = 1 #index into the RLEVector
    icount = 0 #counts of the current repeatedvalue
    #find istart in terms of its current index in the val array, index in the count array, and count
    while offset0 > 1
        icount+=1
        offset0-=1
        if icount >= count(seq[ival])
            ival+=1
            icount = 0
        end
    end
    num_samps = istop - istart + 1
    output = zeros(rawtype(com), num_samps)
    #decompress num_samps samples beginning at istart
    so_far = 1
    output[so_far] = seq[ival].value #write first sample
    while so_far < num_samps
        icount+=1
        if icount == count(seq[ival]) #if we should increment ival and reset icount
            if ival+1 > length(seq) #if we should increment iseq and reset icount,ival
                iseq+=1
                seq = com.sequences[iseq]
                ival = 1
                icount = 0
            else
                ival+=1
                icount = 0
            end
        end
        so_far+=1
        output[so_far] = seq[ival].value
    end
    return output
end

function add_sequence!{T<:RLEVector, TS}(com::ImagineSignal{T}, seqname::String, sequence::AbstractVector{TS})
    cseq = compress(sequence, mapper(com))
    add_sequence!(com, seqname, cseq)
end

function add_sequence!{T<:RLEVector}(com::ImagineSignal{T}, seqname::String, sequence::T)
    seqdict = sequence_lookup(com)
    @assert full_length(sequence) >= 1
    if haskey(seqdict, seqname)
        error("A sequence by this name exists.  If you want to replace the existing sequence, use the replace! function")
    else
        seqdict[seqname] = sequence
    end
end

function append!{T<:RLEVector}(com::ImagineSignal{T}, seqname::String)
    seqdict = sequence_lookup(com)
    if !haskey(seqdict, seqname)
        error("The requested sequence name was not found.  You most first add the sequence with add_sequence!(com, seqname, sequence), or instead you can add it and append it at the same time with append!(com, seqname, sequence)")
    else
        #TODO: run safety checks here
        #find the length of this sequence and append to cumlength vector
        seqi = findfirst(x->x==seqname, sequence_names(com))
	push!(sequence_names(com), seqname)
        newseq = sequence_lookup(com)[seqname]
	push!(sequences(com), newseq)
        lseq = 0
        if seqi == 0 #we didn't use this sequence yet
            lseq = sum(map(count, newseq))
        elseif seqi == 1
            lseq = cumlength(com)[1]
        else
            lseq = cumlength(com)[seqi] - cumlength(com)[seqi-1]
        end
        push!(com.cumlength, length(com) + lseq)
    end
    return com
end

function append!{T<:RLEVector, TS}(com::ImagineSignal{T}, seqname::String, sequence::AbstractVector{TS})
        cseq = compress(sequence, mapper(com))
        return append!(com, seqname, cseq)
end

function append!{T<:RLEVector}(com::ImagineSignal{T}, seqname::String, sequence::T)
    #TODO: run safety checks here
    @assert full_length(sequence) >= 1
    add_sequence!(com, seqname, sequence)
    push!(sequences(com), sequence)
    push!(sequence_names(com), seqname)
    push!(cumlength(com), length(com) + full_length(sequence))
    return com
end

#Repeat the entire sequence currently described by com nreps times
#(Equivalent to calling append!(com, seqname) nreps times when seqname is the only sequence in com)
function replicate!{T<:RLEVector}(com::ImagineSignal{T}, nreps::Int)
    #TODO: run safety checks here
    names_to_append = deepcopy(sequence_names(com))
    for n = 1:nreps
        for nm in names_to_append
            append!(com, nm)
        end
    end
    return com
end

function pop!{T<:RLEVector}(com::ImagineSignal{T})
    pop!(cumlength(com))
    seq = pop!(sequences(com))
    nm = pop!(sequence_names(com))
    return seq
end

function empty!{T<:RLEVector}(com::ImagineSignal{T}; clear_library = false)
    empty!(com.cumlength)
    empty!(com.sequence_names)
    empty!(com.sequences)
    if clear_library
        empty!(com.sequence_lookup)
    end
    return com
end

function replace!{T<:RLEVector, TS}(com::ImagineSignal{T}, seqname::String, sequence::AbstractVector{TS})
    seqdict = sequence_lookup(com)
    if !haskey(seqdict, seqname)
        error("The requested sequence name was not found.  To add a new sequence by this name, use `append!(com, seqname, sequence)`")
    else
        #TODO: run safety checks here
        cseq = compress(sequence, mapper(com))
        @assert full_length(cseq) >= 1
        seqdict[seqname] = cseq
        seqidxs = find(x->x==seqname, sequence_names(com))
        allseqs = sequences(com)
        for i in seqidxs
            allseqs[i] = cseq
        end
        recalculate_cumlength!(com)
    end
    return com
end
