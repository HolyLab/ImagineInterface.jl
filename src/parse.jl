function parse_commands(filename::AbstractString)
    @assert splitext(filename)[2] == ".json"
    parse_commands(JSON.parsefile(filename))
end

function parse_commands(d::Dict)
    output = ImagineSignal[]
    rig = d[METADATA_KEY]["rig"]
    for typ_key in (ANALOG_KEY, DIGITAL_KEY)
        for k in keys(d[typ_key])
            v = d[typ_key][k]
            seq = haskey(v, "sequence") ? convert(RLEVector, v["sequence"]) : convert(RLEVector, [])
            push!(output, _parse_command(rig, k, v["daq channel"], seq, d[COMPONENT_KEY], Int(d[METADATA_KEY]["samples per second"])*Unitful.s^-1))
        end
    end
    return output
end

function parse_command(filename::AbstractString, comname::AbstractString)
    @assert splitext(filename)[2] == ".json"
    parse_command(JSON.parsefile(filename; dicttype=Dict, use_mmap=true), comname)
end

function parse_command(d::Dict, comname::AbstractString)
    rig = d[METADATA_KEY]["rig"]
    for typ_key in (ANALOG_KEY, DIGITAL_KEY)
        ad = d[typ_key]
        if haskey(ad, comname)
            seq = haskey(ad[comname], "sequence") ? convert(RLEVector, ad[comname]["sequence"]) : convert(RLEVector, [])
            return _parse_command(rig, comname, ad[comname]["daq channel"], seq, d[COMPONENT_KEY], Int(d[METADATA_KEY]["samples per second"])*Unitful.s^-1)
        end
    end
    error("Command signal name not found")
end

#In the JSON arrays, waveforms and counts-of-waves are specified in alternating order: count,wave,count,wave...
function _parse_command(rig::AbstractString, chan_name::AbstractString, daq_chan_name::AbstractString, seqs_compressed::RLEVector, seqs_lookup::Dict, sample_rate::HasInverseTimeUnits)
    sampmapper = default_samplemapper(rig, daq_chan_name; sample_rate = sample_rate)
    rawtyp = rawtype(sampmapper)
    vectype = isoutput(daq_chan_name, rig) ? RLEVector{rawtyp} : AbstractVector{rawtyp}
    seqlist = Vector{vectype}(undef, 0)
    seqnames = String[]
    if !isoutput(daq_chan_name, rig) && !isempty(seqs_compressed)
        @warn "Found samples written to the .json file for input channel $(chan_name).  Loading anyway, but this probably indicates a problem"
    end
    for s in seqs_compressed
        for c = 1:s.n
            push!(seqlist, seqs_lookup[s.value])
            push!(seqnames, s.value)
        end
    end
    cumlen = zeros(Int, length(seqlist))
    calc_cumlength!(cumlen, seqlist)
    for s in unique(seqnames) #Convert from Any vectors to RLEVectors
        seqs_lookup[s] = convert(vectype, seqs_lookup[s])
    end
    return ImagineSignal{vectype}(chan_name, daq_chan_name, rig, seqlist, seqnames, seqs_lookup, cumlen, sampmapper)
end

"""
    ai = parse_ai(ainame; imaginename=splitext(ainame)[1]*".imagine")
    ai = parse_ai(ainame, header::Dict{String})

Parse the imagine header and specified `.ai` file to extract the signals used to
represent timing information in an Imagine recording.
`ai` is a vector of memory-mapped signals.
See `examples/reading_ai.jl` for a usage demonstration.
"""
function parse_ai(ai_name::AbstractString; imagine_header::AbstractString = splitext(ai_name)[1]*".imagine")
    if !isfile(ai_name) && isfile(ai_name*".ai")
        ai_name = ai_name*".ai"
    end
    if !isfile(imagine_header)
        error(".imagine header not found.  Please specify header file name by keyword argument.")
    end
    hdr = ImagineFormat.parse_header(imagine_header)
    parse_ai(ai_name, hdr)
end

function parse_ai(ai_name::AbstractString, hdr::Dict{String})
    chns = hdr["channel list"] #note: zero-based, need to add a constant for mapping these indices to DAQ channels
    chns = map(x-> "AI$(x)", chns)
    labs = split(hdr["label list"], "\$")
    rig = hdr["rig"]
    samp_rate = convert(Int, hdr["scan rate"]) * Unitful.s^-1
    if length(chns) != length(labs)
        error("Invalid .imagine header: The number of channels does not match the number of channel labels")
    end
    parse_ai(ai_name, chns, labs, rig, samp_rate)
end

function parse_ai(ai_name, chns, labels, rig, sample_rate::HasInverseTimeUnits)
    nchannels = length(chns)
    tmp = rigtemplate(rig; sample_rate = sample_rate)
    incoms = getanalog(getinputs(tmp))
    aitype = rawtype(incoms[1])
    nbytes = filesize(ai_name)
    nsamples = nbytes/nchannels/sizeof(aitype)
    if !isapprox(nsamples, round(Int, nsamples))
        error("The .ai file doesn't have the correct number of samples.  The recording may have been interrupted.")
    else
        nsamples = round(Int, nsamples)
    end
    f = open(ai_name, "r")
    A = Mmap.mmap(f, Matrix{aitype}, (nchannels,nsamples))

    parse_ai(A, chns, labels, rig, sample_rate)
end

function parse_ai(ai_name, chns, rig, sample_rate::HasInverseTimeUnits)
    labels = map(x->DEFAULT_DAQCHANS_TO_NAMES[rig][x], chns)
    parse_ai(ai_name, chns, labels, rig, sample_rate)
end

function parse_ai(A::Matrix{T}, chns, labels, rig, sample_rate::HasInverseTimeUnits) where T
    nchannels = size(A,1)
    tmp = rigtemplate(rig; sample_rate = sample_rate)
    incoms = getanalog(getinputs(tmp))
    output = ImagineSignal[]
    for i = 1:length(chns)
        comi = finddaqchan(incoms, chns[i])
        if comi == 0
            @warn "DAQ channel $(chns[i]) is not an analog input channel for this rig.  Attempting to load it anyway."
        end
        com = incoms[comi]
        samps = view(A, i, :)
        #sampsarr = Array{AbstractVector}(undef, 0)
        sampsarr = Array{typeof(samps)}(undef, 0)
        push!(sampsarr, samps)
        lookup_nm = string(hash(chns[i]))
        #mon = ImagineSignal{AbstractVector}(labels[i], chns[i], rig, sampsarr, [lookup_nm;], Dict{String,Any}(lookup_nm=>samps), [length(samps);], mapper(com))
        mon = ImagineSignal(labels[i], chns[i], rig, sampsarr, [lookup_nm;], Dict{String,Any}(lookup_nm=>samps), [length(samps);], mapper(com))
        push!(output, mon)
    end
    return output
end

function parse_ai(A::Matrix, chns, rig, sample_rate::HasInverseTimeUnits)
    labels = map(x->DEFAULT_DAQCHANS_TO_NAMES[rig][x], chns)
    parse_ai(A, chns, labels, rig, sample_rate)
end

"""
    di = parse_di(diname; imaginename=splitext(diname)[1]*".imagine", kwargs...)

Parse the imagine header and specified `.di` file to extract the signals used to
represent timing information in an Imagine recording.
`di` is a vector of memory-mapped signals.
"""
function parse_di(di_name::AbstractString; imagine_header = splitext(di_name)[1]*".imagine", kwargs...)
    if !isfile(di_name) && isfile(di_name*".di")
        di_name = di_name*".di"
    end
    if !isfile(imagine_header)
        error(".imagine header not found.  Please specify header file name by keyword argument.")
    end
    hdr = ImagineFormat.parse_header(imagine_header)
    return parse_di(di_name, hdr; kwargs...)
end

"""
    di = parse_di(diname, header::Dict{String}; load_unused=false)

Parse the specified `.di` file to extract the signals used to
represent timing information in an Imagine recording.
`di` is a vector of memory-mapped signals. `header` is an Imagine header.
"""
function parse_di(di_name::AbstractString, hdr::Dict{String,Any}; load_unused = false)
    chns = hdr["di channel list"] #note: zero-based, need to add a constant for mapping these indices to DAQ channels
    chns = map(x->"P0.$(x)", chns)
    labs = split(hdr["di label list"], "\$")
    rig = hdr["rig"]
    samp_rate = convert(Int, hdr["di scan rate"]) * Unitful.s^-1
    nchannels = length(chns)
    if nchannels != length(labs)
        error("Invalid .imagine header: The number of channels does not match the number of channel labels")
    end
    for i = 1:length(chns)
        biti = findfirst(x->x==parse(Int, split(chns[i], ".")[2]), hdr["di channel list"])
        if biti != findfirst(x->x==chns[i], DI_CHANS[rig])
            @warn "DI channel list entry #$(biti) found in the .imagine header does not match the expected entry for this rig. Attempting to load anyway, but please report this issue"
        end
    end
    parse_di(di_name, chns, labs, rig, samp_rate::HasInverseTimeUnits; load_unused = load_unused)
end

#Does not require Imagine file, but allows a loading a subset of the 8 channels based on names
function parse_di(di_name, chns, labels, rig, sample_rate::HasInverseTimeUnits; load_unused = false)
    nchannels = length(labels)
    di_sigs = parse_di(di_name, rig, sample_rate)
    di_sigs_used = ImagineSignal[]
    #assign labels to di_sigs
    for i = 1:length(chns)
        sig = getdaqchan(di_sigs, chns[i])
        if isfree(sig)
            rename!(sig, String(labels[i]))
        elseif String(labels[i]) != name(sig) && labels[i] != "unused"
            @warn "The name $(String(labels[i])) was provided for a di channel that cannot be renamed.  Defaulting to its allowed name"
        end
        if labels[i] != "unused"
            push!(di_sigs_used, sig)
        end
    end
    if load_unused
        return di_sigs
    else
        return di_sigs_used
    end
end

#Does not require imagine file, loads all 8 channels
function parse_di(di_name, rig, sample_rate::HasInverseTimeUnits)
    insigs = getdigital(getinputs(rigtemplate(rig; sample_rate = sample_rate)))
    nsamples = filesize(di_name) #each sample is one byte
    f = open(di_name, "r+")
    A = Mmap.mmap(f, BitArray, (8,nsamples)) #we need all 8 bits even if the user didn't ask for 8 channels of DI
    output = ImagineSignal[]
    close(f)
    for i = 1:length(insigs)
        sig = insigs[i]
        daq_chan_str = daq_channel(sig)
        biti = findfirst(x->x==daq_chan_str, DI_CHANS[rig])
        samps = mappedarray(UInt8, view(A, biti, :)) #feels a bit dishonest to call UInt8 the raw type, but there is no Bit type...
        sampsarr = Array{AbstractVector}(undef, 0)
        push!(sampsarr, samps)
        lookup_nm = string(hash(daq_chan_str))
        mpr = SampleMapper(UInt8(false), UInt8(true), 0.0*Unitful.V, 3.3*Unitful.V, false, true, sample_rate) #unlike for outputs, the raw type is Bool
        mon = ImagineSignal{AbstractVector}(name(sig), daq_chan_str, rig, sampsarr, [lookup_nm;], Dict{String,Any}(lookup_nm=>samps), [length(samps);], mpr)
        push!(output, mon)
    end
    return output
end

function append_or_replace!(coms::Vector{ImagineSignal}, newcoms)
    for c in newcoms
        i = findname(coms, name(c))
        if i != 0
            coms[i] = c
        else
            append!(coms, c)
        end
    end
    return coms
end

function load_signals(any_name::AbstractString)
    if !isfile(any_name)
        error("File not found")
    end
    extn = splitext(any_name)[2]
    basenm = splitext(any_name)[1]
    if extn != ".json" && !isfile(basenm * ".json") && !isfile(basenm * ".imagine")
        error("A matching .json or .imagine header was not found in the supplied directory, so the experiment cannot be loaded")
    end

    coms = ImagineSignal[]
    comnm = basenm * ".json"
    has_comfile = false
    if isfile(comnm)
        has_comfile = true
        append!(coms, parse_commands(comnm))
    else
        @warn "A matching .json command file was not found in the supplied directory.  Attempting to load .ai and .di file anyway"
    end
    ainm = basenm * ".ai"
    dinm = basenm * ".di"
    if isempty(coms) && !isfile(ainm) && !isfile(dinm)
        error("Cannot load anything: no .json file was found, and no .ai or .di file was found to match the .imagine file")
    end

    if isfile(ainm)
        ai_sigs = parse_ai(ainm)
        if has_comfile
            for s in ai_sigs
                if !is_similar(s, getname(coms, name(s)))
                    error("AI file signal $(name(s)) does not match the entry found in the .json command file")
                end
            end
        end
        append_or_replace!(coms, ai_sigs)
    else
        @warn "Analog input file (with .ai extension) was not found in the supplied directory"
    end

    if isfile(dinm)
        di_sigs = parse_di(dinm)
        if has_comfile
            for s in di_sigs
                if !is_similar(s, getname(coms, name(s)))
                    error("DI file signal $(name(s)) does not match the entry found in the .json command file")
                end
            end
        end
        append_or_replace!(coms, di_sigs)
    else
        @warn "Digital input file (with .di extension) was not found in the supplied directory"
    end
    return coms
end
