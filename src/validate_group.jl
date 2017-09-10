function check_samptypes(coms::Vector{ImagineSignal}, rig::AbstractString)
    #check that all analog and digital entries are acceptable for this rig
    tm = rigtemplate(rig)
    chans0 = map(daq_channel, tm)
    chans = map(daq_channel, coms)
    for chan in chans
        if intervals(getdaqchan(coms, chan)) != intervals(getdaqchan(tm, chan))
            error("The sample value intervals for channel '$chan' are incompatible with the $rig rig.")
        end
    end
    #check that all have equal sample rate
    rs = map(samprate,coms)
    if !all(rs.==rs[1])
        error("All commands must use equal sample rates.  This can be set per-channel with `set_samprate!`")
    end
    #check that all have equal number of samples
    nsamps = map(length, getoutputs(coms))
    if !all(nsamps.==nsamps[1])
        error("All output commands must have an equal number of samples.  Check this with `length(com::ImagineSignal)`")
    end
    return true
end


#In order to be "sufficient" a command must include a positioner trace, at least one camera trace, and at least one laser trace
function check_sufficiency(coms::Vector{ImagineSignal})
    if length(findcameras(coms)) == 0
        error("No camera commands were found")
    end
    if length(findpositioners(coms)) == 0
        error("No positioner commands were found")
    end
    if length(findlasers(coms)) == 0
        error("No laser commands were found")
    end
end

#Check whether user has modified fixed names
function check_fixed_names(coms::Vector{ImagineSignal}, rig::String)
    fixed_names = FIXED_NAMES[rig]
    name_lookup = DEFAULT_DAQCHANS_TO_NAMES[rig]
    for c in coms
        nm = name(c)
        dc = daq_channel(c)
        if nm != name_lookup[dc] && in(name_lookup[dc], fixed_names)
            error("DAQ Channel $(dc) must have the name $(name_lookup[dc]) but instead it is named $nm")
        end
    end
    return true
end

#checks that all commands in the vector have the same rig, and the rig is recognized
function check_rig_names(coms::Vector{ImagineSignal})
    rig = rig_name(coms[1])
    if !all(map(rig_name, coms) .== rig)
        error("The set of commands to be written must all be targeted to the same rig")
    end
    if !in(rig, RIGS)
        error("Unrecognized rig: $rig")
    end
    return true
end

#Check for invalid DAQ channel names
function check_valid_channels(coms::Vector{ImagineSignal}, rig::String)
    name_lookup = DEFAULT_DAQCHANS_TO_NAMES[rig]
    for c in map(daq_channel, coms)
        if !haskey(name_lookup, c)
            error("The channel $c is not accessible on this rig")
        end
    end
    nms = map(name, coms)
    chan_nms = map(daq_channel, coms)
    if length(unique(nms)) != length(nms)
        error("Found one or more duplicate channel names")
    end
    if length(unique(chan_nms)) != length(chan_nms)
        error("Found one or more duplicate DAQ channel identifiers")
    end
    return true
end

function validate_group(sigs::Vector{ImagineSignal}; check_is_sufficient = true)
    check_rig_names(sigs)
    rig = rig_name(first(sigs))
    check_valid_channels(sigs, rig)
    check_fixed_names(sigs, rig)
    if check_is_sufficient
        check_sufficiency(sigs)
    end
    check_samptypes(sigs, rig)
    #check_speed_limits(coms_used, rig) #TODO: implement this
    return true
end
