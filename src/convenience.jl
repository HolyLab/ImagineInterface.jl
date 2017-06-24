#####Convenience functions for filtering arrays of Imagine commands by channel name, channel type######

findname(coms::AbstractArray{ImagineCommand,1}, nm::String) = findfirst(x->name(x) == nm, coms)
function getname(coms::AbstractArray{ImagineCommand,1}, nm::String)
    namei = findname(coms, nm)
    if namei == 0
        error("Name not found")
    else
        coms[findname(coms, nm)]
    end
end
finddaqchan(coms::AbstractArray{ImagineCommand,1}, nm::String) = findfirst(x->daq_channel(x) == nm, coms)
getdaqchan(coms::AbstractArray{ImagineCommand,1}, nm::String) = coms[finddaqchan(coms, nm)]

isdigital(daq_chan::String, rig::String) = in(daq_chan, DI_CHANS[rig]) || in(daq_chan, DO_CHANS[rig])
isdigital(com::ImagineCommand)  = isdigital(daq_channel(com), rig_name(com))
finddigital(coms::AbstractArray{ImagineCommand,1}) = find(x->isdigital(x), coms)
getdigital(coms::AbstractArray{ImagineCommand,1}) = view(coms, finddigital(coms))
isanalog(daq_chan::String, rig::String) = !isdigital(daq_chan, rig)
isanalog(com::ImagineCommand)  = isanalog(daq_channel(com), rig_name(com))
findanalog(coms::AbstractArray{ImagineCommand,1}) = find(x->!isdigital(x), coms)
getanalog(coms::AbstractArray{ImagineCommand,1}) = view(coms, findanalog(coms))

isoutput(daq_chan::String, rig::String) = in(daq_chan, AO_CHANS[rig]) || in(daq_chan, DO_CHANS[rig])
isoutput(com::ImagineCommand)  = isoutput(daq_channel(com), rig_name(com))
findoutputs(coms::AbstractArray{ImagineCommand,1}) = find(x->isoutput(x), coms)
getoutputs(coms::AbstractArray{ImagineCommand,1}) = view(coms, findoutputs(coms))
findinputs(coms::AbstractArray{ImagineCommand,1}) = find(x->!isoutput(x), coms)
getinputs(coms::AbstractArray{ImagineCommand,1}) = view(coms, findinputs(coms))

isfree(daq_chan::String, rig::String) = !in(daq_chan, FIXED_DAQ_CHANS[rig])
isfree(com::ImagineCommand)  = isfree(daq_channel(com), rig_name(com))
findfree(coms::AbstractArray{ImagineCommand,1}) = find(x->isfree(x), coms)
getfree(coms::AbstractArray{ImagineCommand,1}) = view(coms, findfree(coms))
findfixed(coms::AbstractArray{ImagineCommand,1}) = find(x->!isfree(x), coms)
getfixed(coms::AbstractArray{ImagineCommand,1}) = view(coms, findfixed(coms))

ispos(daq_chan::String, rig::String) = in(daq_chan, POS_CONTROL_CHANS[rig])
ispos(com::ImagineCommand)  = ispos(daq_channel(com), rig_name(com))
findpositioners(coms::AbstractArray{ImagineCommand,1}) = find(x->ispos(x), coms)
getpositioners(coms::AbstractArray{ImagineCommand,1}) = view(coms, findpositioners(coms))

isposmonitor(daq_chan::String, rig::String) = in(daq_chan, POS_MONITOR_CHANS[rig])
isposmonitor(com::ImagineCommand)  = isposmonitor(daq_channel(com), rig_name(com))
findpositionermonitors(coms::AbstractArray{ImagineCommand,1}) = find(x->isposmonitor(x), coms)
getpositionermonitors(coms::AbstractArray{ImagineCommand,1}) = view(coms, findpositionermonitors(coms))

iscam(daq_chan::String, rig::String) = in(daq_chan, CAM_CONTROL_CHANS[rig])
iscam(com::ImagineCommand)  = iscam(daq_channel(com), rig_name(com))
findcameras(coms::AbstractArray{ImagineCommand,1}) = find(x->iscam(x), coms)
getcameras(coms::AbstractArray{ImagineCommand,1}) = view(coms, findcameras(coms))

iscammonitor(daq_chan::String, rig::String) = in(daq_chan, CAM_MONITOR_CHANS[rig])
iscammonitor(com::ImagineCommand)  = iscammonitor(daq_channel(com), rig_name(com))
findcameramonitors(coms::AbstractArray{ImagineCommand,1}) = find(x->iscammonitor(x), coms)
getcameramonitors(coms::AbstractArray{ImagineCommand,1}) = view(coms, findcameramonitors(coms))

islas(daq_chan::String, rig::String) = in(daq_chan, LAS_CONTROL_CHANS[rig])
islas(com::ImagineCommand)  = islas(daq_channel(com), rig_name(com))
findlasers(coms::AbstractArray{ImagineCommand,1}) = find(x->islas(x), coms)
getlasers(coms::AbstractArray{ImagineCommand,1}) = view(coms, findlasers(coms))

isstim(daq_chan::String, rig::String) = in(daq_chan, STIM_CHANS[rig])
isstim(com::ImagineCommand)  = isstim(daq_channel(com), rig_name(com))
findstimuli(coms::AbstractArray{ImagineCommand,1}) = find(x->isstim(x), coms)
getstimuli(coms::AbstractArray{ImagineCommand,1}) = view(coms, findstimuli(coms))


hasmonitor(com::ImagineCommand) = iscam(com) || ispos(com)
function getmonitor_name(com::ImagineCommand)
    if !hasmonitor(com)
        error("There is not monitor (input) corresponding to this channel")
    end
    if iscam(com)
        return name(com) * " frame monitor"
    else
        return name(com) * " monitor"
    end
end
function getmonitor(com::ImagineCommand)
    mon_nm = getmonitor_name(com)
    temp = rigtemplate(rig_name(com); sample_rate = samprate(com))
    return getname(temp, mon_nm)
end
