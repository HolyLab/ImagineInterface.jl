immutable RepeatedValue{T}
    n::Int
    value::T
end

convert{T}(::Type{RepeatedValue{T}}, rv::RepeatedValue) = RepeatedValue{T}(rv.n, rv.value)

"RLEVector is a run-length encoded vector"
@compat const RLEVector{T} = Vector{RepeatedValue{T}}

# julia-0.5 has trouble building containers of abstractly-typed
# objects, so we use RLEVector{Any} for all objects. With higher
# versions of Julia, we attempt to allow concretely-typed vectors.
if VERSION < v"0.6.0-pre"
    const RLEVec = RLEVector{Any}
    convert(::Type{RLEVector}, v::AbstractVector) = convert(RLEVector{Any}, v)
else
    const RLEVec = RLEVector
    # Use the first "real" value to infer the type. Not type-stable.
    convert(::Type{RLEVector}, v::AbstractVector) = isempty(v) ?
        convert(RLEVector{Any}, v) :
        convert(RLEVector{typeof(v[2])}, v)
end

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

type ImagineCommand
    chan_name::String
    sequences::Vector{RLEVec}
    sequence_names::Vector{String}
    sequence_lookup::Dict
    cumlength::Vector{Int}
    fac::UnitFactory
end

function show(io::IO, com::ImagineCommand)
    if isdigital(com)
        print(io, "Digital ")
    else
        print(io, "Analog ")
    end
    print(io, "ImagineCommand")
    if isdigital(com)
        print(io, "\n")
    else
        print(io, " encoding values from $(com.fac.worldmin) to $(com.fac.worldmax)\n")
    end
    print(io, "           Channel name: $(name(com))\n")
    print(io, "               Raw type: $(rawtype(com))\n")
    print(io, "              Intervals: $(intervals(com))\n")
    print(io, "      Duration(samples): $(length(com))\n")
    print(io, "      Duration(seconds): $(length(com)*com.fac.time_interval)")
end

Base.length(com::ImagineCommand) = isempty(com) ? 0 : com.cumlength[end]
Base.size(C::ImagineCommand)    = length(C)
Base.isempty(com::ImagineCommand) = isempty(cumlength(com))

function ==(com1::ImagineCommand, com2::ImagineCommand)
    eq = true
    for nm in fieldnames(com1)
        if getfield(com1, nm) != getfield(com2, nm)
            eq = false
            break
        end
    end
    return eq
end

name(com::ImagineCommand) = com.chan_name
rawtype(com::ImagineCommand) = rawtype(com.fac)
worldtype(com::ImagineCommand) = worldtype(com.fac)
isdigital(com::ImagineCommand) = typeof(com.fac.worldmin) == Bool
sequences(com::ImagineCommand) = com.sequences
sequence_names(com::ImagineCommand) = com.sequence_names
sequence_lookup(com::ImagineCommand) = com.sequence_lookup
intervals(com::ImagineCommand) = intervals(com.fac)
interval_raw(com::ImagineCommand) = interval_raw(com.fac)
interval_volts(com::ImagineCommand) = interval_volts(com.fac)
interval_world(com::ImagineCommand) = interval_world(com.fac)
cumlength(com::ImagineCommand) = com.cumlength
#assumes rate is in samples per second
sample_rate(com::ImagineCommand) = sample_rate(com.fac)
set_sample_rate!(com::ImagineCommand, r::Int) = set_sample_rate!(com.fac, r)

#In the JSON arrays, waveforms and counts-of-waves are specified in alternating order: count,wave,count,wave...
function ImagineCommand(rig_name::String, chan_name::String, seqs_compressed::RLEVec, seqs_lookup::Dict, samprate::Int)
    seqlist = RLEVec[]
    seqnames = String[]
    for s in seqs_compressed
        for c = 1:s.n
            push!(seqlist, seqs_lookup[s.value])
            push!(seqnames, s.value)
        end
    end
    return ImagineCommand(rig_name, chan_name, seqlist, seqnames, seqs_lookup, samprate)
end

function calc_cumlength!{RV<:RLEVec}(output::Vector{Int}, seqs::Vector{RV})
    if !isempty(seqs)
        output[1] = sum(s.n for s in seqs[1])
        for i = 2:length(seqs)
            output[i] = output[i-1] + sum(s.n for s in seqs[i])
        end
    end
    return output
end

recalculate_cumlength!(com) = calc_cumlength!(com.cumlength, sequences(com))

function ImagineCommand(rig_name::String, chan_name::String, seqs, seqnames::Vector{String}, seqs_lookup::Dict, samprate::Int)
    cumlen = zeros(Int, length(seqs))
    calc_cumlength!(cumlen, seqs)
    return ImagineCommand(chan_name, seqs, seqnames, seqs_lookup, cumlen, default_unitfactory(rig_name, chan_name; samprate = samprate))
end

function decompress(com::ImagineCommand, tstart::Unitful.Time, tstop::Unitful.Time; sampmap=:world)
    istart = ceil(Int64, (tstart / com.fac.time_interval)+1)
    istop = floor(Int64, (tstop / com.fac.time_interval)+1)
    return decompress(com, istart, istop; sampmap=sampmap)
end

function decompress(com::ImagineCommand, istart::Int, istop::Int; sampmap=:world)
    if !in(sampmap, (:world, :volts, :raw))
        error("Unrecognized sample mapping")
    end
    @assert istart <= istop
    datm = decompress_raw(com, istart, istop)

    if sampmap == :world || sampmap == :volts
        f0 = raw2volts(com.fac)
        f0inv = volts2raw(com.fac)
        datm = mappedarray((f0,f0inv), datm)
    end
    if sampmap == :world
        f1 = volts2world(com.fac)
        f1inv = world2volts(com.fac)
        datm = mappedarray((f1, f1inv), datm)
    end
    tstart = (istart-1) * com.fac.time_interval
    tstop = (istop-1) * com.fac.time_interval
    ax = Axis{:time}(tstart:com.fac.time_interval:tstop)
    return AxisArray(datm, ax)
end

function decompress_raw(com::ImagineCommand, istart::Int, istop::Int)
    if istart < 1 || istop > length(com) #bounds check
        error("The requested time interval is out of bounds")
    end

    iseq = 1
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
    ival = 1
    curcount = 1
    icount = 0
    #find istart in terms of its current index in the val array, index in the count array, and count
    while offset0 > 1
        icount+=1
        offset0-=1
        if icount > seq[curcount].n
            curcount+=1
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
        if icount == seq[curcount].n #if we should increment curcount, ival and reset icount
            if curcount+1 > length(seq) #if we should increment iseq and reset curcount,icount,ival
                iseq+=1
                seq = com.sequences[iseq]
                curcount = ival = 1
                icount = 0
            else
                curcount+=1
                ival+=1
                icount = 0
            end
        end
        so_far+=1
        output[so_far] = seq[ival].value
    end
    return output
end

function decompress(com::ImagineCommand, sequence_name::String; sampmap = :world)
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
    return decompress(com, starti, stopi; sampmap=sampmap)
end

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

compress{Traw, TW, TT}(seq::AbstractVector{Traw}, fac::UnitFactory{Traw, TW, TT}) = compress!(RepeatedValue{Traw}[], seq)
compress{Traw, TW, TT}(seq::AbstractVector{typeof(0.0*Unitful.V)}, fac::UnitFactory{Traw, TW, TT}) = compress!(RepeatedValue{Traw}[], mappedarray(volts2raw(fac), seq))
compress{Traw, TW, TT}(seq::AbstractVector{TW}, fac::UnitFactory{Traw, TW, TT}) = compress!(RepeatedValue{Traw}[], mappedarray(world2raw(fac), seq))

function append!(com::ImagineCommand, seqname::String)
    seqdict = sequence_lookup(com)
    if !haskey(seqdict, seqname)
        error("The requested sequence name was not found.  To add a new sequence by this name, use `append!(com, seqname, sequence)`")
    else
        #find the length of this sequence and append to cumlength vector
        seqi = findfirst(x->x==seqname, sequence_names(com))
	push!(sequence_names(com), seqname)
        newseq = sequence_lookup(com)[seqname]
	push!(sequences(com), newseq)
        lseq = 0
        if seqi == 0 #we didn't use this sequence yet
            lseq = sum(newseq[1:2:end])
        elseif seqi == 1
            lseq = cumlength(com)[1]
        else
            lseq = cumlength(com)[seqi] - cumlength(com)[seqi-1]
        end
        push!(com.cumlength, length(com) + lseq)
    end
    return com
end

function append!{T}(com::ImagineCommand, seqname::String, sequence::AbstractVector{T})
    seqdict = sequence_lookup(com)
    if haskey(seqdict, seqname)
        error("Sequence name exists.  If you mean to add append another copy of the existing sequence, call `append!(com, seqname)` instead")
    else
        #compress it, add it to seqdict, append it to the sequence list, and append the name to the name list
        cseq = compress(sequence, com.fac)
        seqdict[seqname] = cseq
	push!(sequences(com), cseq)
	push!(sequence_names(com), seqname)
        push!(cumlength(com), length(com) + length(sequence))
    end
    return com
end

function pop!(com::ImagineCommand)
    pop!(cumlength(com))
    seq = pop!(sequences(com))
    nm = pop!(sequence_names(com))
    return seq
end

function empty!(com::ImagineCommand; clear_library = false)
    empty!(com.cumlength)
    empty!(com.sequence_names)
    empty!(com.sequences)
    if clear_library
        empty!(com.sequence_lookup)
    end
    return com
end

function replace!{T}(com::ImagineCommand, seqname::String, sequence::AbstractVector{T})
    seqdict = sequence_lookup(com)
    if !haskey(seqdict, seqname)
        error("The requested sequence name was not found.  To add a new sequence by this name, use `append!(com, seqname, sequence)`")
    else
        cseq = compress(sequence, com.fac)
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
