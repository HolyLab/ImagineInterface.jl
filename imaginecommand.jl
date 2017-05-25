type ImagineCommand #{T,A,F} <: AbstractArray{T,1}
    chan_name::String
    sequences::Array
    sequence_names::Vector{String}
    sequence_lookup::Dict
    rawtype::DataType
    cumlength::Array{Int64,1}
    is_digital::Bool
    fac::UnitFactory
end

function default_rawtype(is_digital::Bool)
    if !is_digital
        return UInt16
    else
        return Bool
    end
end

function empty_command(is_digital::Bool; chan_name="default", time_per_sample = 1e-4*Unitful.s)
    rawtype = is_digital ? Bool : UInt16
    return ImagineCommand(chan_name, [], String[], Dict(), rawtype, Int64[], is_digital, default_unitfactory(is_digital, rawtype; time_per_sample = time_per_sample))
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
    print(io, "               Raw type: $(com.rawtype)\n")
    print(io, "      Duration(samples): $(length(com))\n")
    print(io, "      Duration(seconds): $(length(com)*com.fac.time_interval)")
end


Base.length(com::ImagineCommand) = isempty(com) ? 0 : com.cumlength[end]
Base.size(C::ImagineCommand)    = length(C)
Base.isempty(com::ImagineCommand) = isempty(com.sequences)
name(com::ImagineCommand) = com.chan_name
rawtype(com::ImagineCommand) = com.rawtype
isdigital(com::ImagineCommand) = com.is_digital
sequence_names(com::ImagineCommand) = com.sequence_names
sequence_lookup(com::ImagineCommand) = com.sequence_lookup

#In the JSON arrays, waveforms and counts-of-waves are specified in alternating order: count,wave,count,wave...
function ImagineCommand(chan_name::String, seqs_compressed, is_digital::Bool, seqs_lookup::Dict; rawtype=Nullable(Any,true))
    @assert iseven(length(seqs_compressed))
    seqlist = []
    seqnames = String[]
    for i = 1:2:length(seqs_compressed)
        for c = 1:Int(seqs_compressed[1])
            push!(seqlist, seqs_lookup[seqs_compressed[i+1]])
            push!(seqnames, seqs_compressed[i+1])
        end
    end
    typ = isnull(rawtype) ? default_rawtype(is_digital) : rawtype
    return ImagineCommand(chan_name, seqlist, seqnames, seqs_lookup, typ, is_digital)
end

function ImagineCommand(chan_name::String, seqs, seqnames::Vector{String}, seqs_lookup::Dict, rawtype::DataType, is_digital::Bool)
    nwaves = length(seqs)
    cumlength = zeros(Int64, nwaves)
    if nwaves > 0
        cumlength[1] = sum(view(seqs[1], 1:2:length(seqs[1])))
        for s = 2:length(seqs)
            cumlength[s] = cumlength[s-1] + sum(view(seqs[s], 1:2:length(seqs[s])))
        end
    end
    return ImagineCommand(chan_name, seqs, seqnames, seqs_lookup, rawtype, cumlength, is_digital, default_unitfactory(is_digital, rawtype))
end

function decompress(com::ImagineCommand, tstart::Unitful.Time, tstop::Unitful.Time; sampmap=:world)
    istart = (tstart / com.fac.time_interval)+1
    istop = (tstop / com.fac.time_interval)+1
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
    
    curvals = view(com.sequences[iseq], 2:2:length(com.sequences[iseq]))
    curcounts = view(com.sequences[iseq], 1:2:length(com.sequences[iseq]))
    ival = 1
    curcount = 1
    icount = 0
    #find istart in terms of its current index in the val array, index in the count array, and count
    while offset0 > 1
        icount+=1
        offset0-=1
        if icount > curcounts[curcount]
            curcount+=1
            ival+=1
            icount = 0
        end
    end

    num_samps = istop - istart + 1
    output = zeros(rawtype(com), num_samps)
    #decompress num_samps samples beginning at istart
    so_far = 1
    output[so_far] = curvals[ival] #write first sample
    while so_far < num_samps
        icount+=1
        if icount == curcounts[curcount] #if we should increment curcount, ival and reset icount
            if curcount+1 > length(curcounts) #if we should increment iseq and reset curcount,icount,ival
                iseq+=1
                curvals = view(com.sequences[iseq], 2:2:length(com.sequences[iseq]))
                curcounts = view(com.sequences[iseq], 1:2:length(com.sequences[iseq]))
                curcount = ival = 1
                icount = 0
            else
                curcount+=1
                ival+=1
                icount = 0
            end
        end
        so_far+=1
        output[so_far] = curvals[ival]
    end
    return output
end


