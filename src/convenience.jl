#####Convenience functions for filtering arrays of Imagine commands by channel name, channel type######

findname(coms::AbstractArray{ImagineCommand,1}, nm::String) = findfirst(x->name(x) == nm, coms)
getname(coms::AbstractArray{ImagineCommand,1}, nm::String) = coms[findname(coms, nm)]
finddaqchan(coms::AbstractArray{ImagineCommand,1}, nm::String) = findfirst(x->daq_channel(x) == nm, coms)
getdaqchan(coms::AbstractArray{ImagineCommand,1}, nm::String) = coms[finddaqchan(coms, nm)]

finddigital(coms::AbstractArray{ImagineCommand,1}) = find(x->isdigital(x), coms)
getdigital(coms::AbstractArray{ImagineCommand,1}) = view(coms, finddigital(coms))
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

ispos(daq_chan::String, rig::String) = in(daq_chan, POS_CONTROL_CHANS[rig]) || in(daq_chan, POS_MONITOR_CHANS[rig])
ispos(com::ImagineCommand)  = ispos(daq_channel(com), rig_name(com))
findpositioners(coms::AbstractArray{ImagineCommand,1}) = find(x->ispos(x), coms)
getpositioners(coms::AbstractArray{ImagineCommand,1}) = view(coms, findpositioners(coms))

iscam(daq_chan::String, rig::String) = in(daq_chan, CAM_CONTROL_CHANS[rig]) || in(daq_chan, CAM_MONITOR_CHANS[rig])
iscam(com::ImagineCommand)  = iscam(daq_channel(com), rig_name(com))
findcameras(coms::AbstractArray{ImagineCommand,1}) = find(x->iscam(x), coms)
getcameras(coms::AbstractArray{ImagineCommand,1}) = view(coms, findcameras(coms))

islas(daq_chan::String, rig::String) = in(daq_chan, LAS_CONTROL_CHANS[rig])
islas(com::ImagineCommand)  = islas(daq_channel(com), rig_name(com))
findlasers(coms::AbstractArray{ImagineCommand,1}) = find(x->islas(x), coms)
getlasers(coms::AbstractArray{ImagineCommand,1}) = view(coms, findlasers(coms))

isstim(daq_chan::String, rig::String) = in(daq_chan, STIM_CHANS[rig])
isstim(com::ImagineCommand)  = isstim(daq_channel(com), rig_name(com))
findstimuli(coms::AbstractArray{ImagineCommand,1}) = find(x->isstim(x), coms)
getstimuli(coms::AbstractArray{ImagineCommand,1}) = view(coms, findstimuli(coms))
