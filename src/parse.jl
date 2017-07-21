function parse_commands(filename::String)
    @assert splitext(filename)[2] == ".json"
    parse_commands(JSON.parsefile(filename))
end

function parse_commands(d::Dict)
    output = ImagineCommand[]
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

function parse_command(filename::String, comname::String)
    @assert splitext(filename)[2] == ".json"
    parse_command(JSON.parsefile(filename; dicttype=Dict, use_mmap=true), comname)
end

function parse_command(d::Dict, comname::String)
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
function _parse_command(rig_name::String, chan_name::String, daq_chan_name::String, seqs_compressed::RLEVector, seqs_lookup::Dict, sample_rate::HasInverseTimeUnits)
    sampmapper = default_samplemapper(rig_name, daq_chan_name; sample_rate = sample_rate)
    rawtyp = rawtype(sampmapper)
    vectype = isoutput(daq_chan_name, rig_name) ? RLEVector{rawtyp} : AbstractVector{rawtyp}
    seqlist = Vector{vectype}(0)
    seqnames = String[]
    if !isoutput(daq_chan_name, rig_name) && !isempty(seqs_compressed)
        warn("Found samples written to the .json file for input channel $(chan_name).  Loading anyway, but this probably indicates a problem")
    end
    for s in seqs_compressed
        for c = 1:s.n
            push!(seqlist, seqs_lookup[s.value])
            push!(seqnames, s.value)
        end
    end
    cumlen = zeros(Int, length(seqlist))
    calc_cumlength!(cumlen, seqlist)
    return ImagineCommand{vectype}(chan_name, daq_chan_name, rig_name, seqlist, seqnames, seqs_lookup, cumlen, sampmapper)
end

function parse_ai(ai_name::String; imagine_header = splitext(ai_name)[1]*".imagine")
    if !isfile(ai_name) && isfile(ai_name*".ai")
        ai_name = ai_name*".ai"
    end
    if !isfile(imagine_header)
        error(".imagine header not found.  Please specify header file name by keyword argument.")
    end
    hdr = ImagineFormat.parse_header(imagine_header)
    chns = hdr["channel list"] #note: zero-based, need to add a constant for mapping these indices to DAQ channels
    nchannels = length(chns)
    labs = split(hdr["label list"], "\$")
    rig = hdr["rig"]
    samp_rate = convert(Int, hdr["scan rate"]) * Unitful.s^-1
    if nchannels != length(labs)
        error("Invalid .imagine header: The number of channels does not match the number of channel labels")
    end
    tmp = rigtemplate(rig; sample_rate = samp_rate)
    incoms = getanalog(getinputs(tmp))
    aitype = rawtype(incoms[1])
    nbytes = filesize(ai_name)
    nsamples = convert(Int,nbytes/nchannels/sizeof(aitype))
    f = open(ai_name, "r")
    A = Mmap.mmap(f, Matrix{aitype}, (nchannels,nsamples))
    output = ImagineCommand[]
    for i = 1:length(chns)
        daq_chan_str = "AI$(chns[i])"
        comi = finddaqchan(incoms, daq_chan_str)
        if comi == 0
            warn("DAQ channel $(daq_chan_str) is not an analog input channel for this rig.  Attempting to load it anyway.")
        end
        com = incoms[comi]
        samps = view(A, i, :)
        vectyp = typeof(samps)
        sampsarr = Array{vectyp}(0)
        push!(sampsarr, samps)
        lookup_nm = string(hash(daq_chan_str))
        mon = ImagineCommand{vectyp}(labs[i], daq_chan_str, rig, sampsarr, [lookup_nm;], Dict(lookup_nm=>samps), [length(samps);], mapper(com))
        push!(output, mon)
    end
    return output
end

function parse_di(di_name::String; imagine_header = splitext(di_name)[1]*".imagine", load_unused = false)
    if !isfile(di_name) && isfile(di_name*".di")
        di_name = di_name*".di"
    end
    if !isfile(imagine_header)
        error(".imagine header not found.  Please specify header file name by keyword argument.")
    end
    hdr = ImagineFormat.parse_header(imagine_header)
    chns = hdr["di channel list"] #note: zero-based, need to add a constant for mapping these indices to DAQ channels
    nchannels = length(chns)
    labs = split(hdr["di label list"], "\$")
    rig = hdr["rig"]
    samp_rate = convert(Int, hdr["di scan rate"]) * Unitful.s^-1
    if nchannels != length(labs)
        error("Invalid .imagine header: The number of channels does not match the number of channel labels")
    end
    tmp = rigtemplate(rig; sample_rate = samp_rate)
    incoms = getdigital(getinputs(tmp))
    nsamples = filesize(di_name) #each sample is one byte
    f = open(di_name, "r")
    A = Mmap.mmap(f, BitArray, (8,nsamples))
    output = ImagineCommand[]
    for i = 1:length(chns)
        daq_chan_str = "P0.$(chns[i])"
        comi = finddaqchan(incoms, daq_chan_str)
        if comi == 0
            warn("DAQ channel $(daq_chan_str) is not a digital input channel for this rig.  Attempting to load it anyway.")
        end
        com = incoms[comi]
        biti = findfirst(x->x==chns[i], hdr["di channel list"])
        if biti != findfirst(x->x==daq_chan_str, DI_CHANS[rig])
            warn("DI channel list entry #$(biti) found in the .imagine header does not match the expected entry for this rig. Loading anyway, but please report this issue")
        end
        if labs[i] != "unused" || load_unused
            samps = view(A, biti, :)
            vectyp = typeof(samps)
            sampsarr = Array{vectyp}(0)
            push!(sampsarr, samps)
            lookup_nm = string(hash(daq_chan_str))
            mpr = SampleMapper(false, true, 0.0*Unitful.V, 3.3*Unitful.V, false, true, samp_rate) #unlike for outputs, the raw type is Bool
            mon = ImagineCommand{vectyp}(labs[i], daq_chan_str, rig, sampsarr, [lookup_nm;], Dict(lookup_nm=>samps), [length(samps);], mpr)
            push!(output, mon)
        end
    end
    return output
end

function append_or_replace!(coms::Vector{ImagineCommand}, newcoms)
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

    coms = ImagineCommand[]
    comnm = basenm * ".json"
    has_comfile = false
    if isfile(comnm)
        has_comfile = true
        append!(coms, parse_commands(comnm))
    else
        warn("A matching .json command file was not found in the supplied directory.  Attempting to load .ai and .di file anyway")
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
        warn("Analog input file (with .ai extension) was not found in the supplied directory")
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
        warn("Digital input file (with .di extension) was not found in the supplied directory")
    end
    return coms
end
