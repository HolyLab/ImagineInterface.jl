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
function _parse_command(rig_name::String, chan_name::String, daq_chan_name::String, seqs_compressed::RLEVec, seqs_lookup::Dict, sample_rate::HasInverseTimeUnits)
    sampmapper = default_samplemapper(rig_name, daq_chan_name; sample_rate = sample_rate)
    rawtyp = rawtype(sampmapper)
    vectype = isoutput(daq_chan_name, rig_name) ? RLEVec{rawtyp} : AbstractVector{rawtyp}
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
        lookup_nm = randstring(12)
        mon = ImagineCommand{vectyp}(labs[i], daq_chan_str, rig, sampsarr, [lookup_nm;], Dict(lookup_nm=>samps), [length(samps);], mapper(com))
        push!(output, mon)
    end
    return output
end

function parse_di(di_name::String; imagine_header = splitext(di_name)[1]*".imagine")
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
        biti = DI_BIT_FIELDS[rig][daq_chan_str] + 1
        samps = view(A, biti, :)
        vectyp = typeof(samps)
        sampsarr = Array{vectyp}(0)
        push!(sampsarr, samps)
        lookup_nm = randstring(12)
        mpr = SampleMapper(false, true, 0.0*Unitful.V, 3.3*Unitful.V, false, true, samp_rate) #unlike for outputs, the raw type is Bool
        mon = ImagineCommand{vectyp}(labs[i], daq_chan_str, rig, sampsarr, [lookup_nm;], Dict(lookup_nm=>samps), [length(samps);], mpr)
        push!(output, mon)
    end
    return output
end

