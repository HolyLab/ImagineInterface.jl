#####Convenience functions for filtering arrays of Imagine commands by channel name, channel type######

findname(coms::AbstractArray{ImagineSignal,1}, nm::AbstractString) = findfirst(x->name(x) == nm, coms)
function getname(coms::AbstractArray{ImagineSignal,1}, nm::AbstractString)
    namei = findname(coms, nm)
    if namei == 0
        error("Name $nm not found")
    else
        coms[namei]
    end
end
finddaqchan(coms::AbstractArray{ImagineSignal,1}, nm::AbstractString) = findfirst(x->daq_channel(x) == nm, coms)
getdaqchan(coms::AbstractArray{ImagineSignal,1}, nm::AbstractString) = coms[finddaqchan(coms, nm)]

isdigital(com::ImagineSignal)  = isdigital(daq_channel(com), rig_name(com))
finddigital(coms::AbstractArray{ImagineSignal,1}) = find(x->isdigital(x), coms)
getdigital(coms::AbstractArray{ImagineSignal,1}) = view(coms, finddigital(coms))
isanalog(daq_chan::AbstractString, rig::AbstractString) = !isdigital(daq_chan, rig)
isanalog(com::ImagineSignal)  = isanalog(daq_channel(com), rig_name(com))
findanalog(coms::AbstractArray{ImagineSignal,1}) = find(x->!isdigital(x), coms)
getanalog(coms::AbstractArray{ImagineSignal,1}) = view(coms, findanalog(coms))

isoutput(com::ImagineSignal)  = isoutput(daq_channel(com), rig_name(com))
findoutputs(coms::AbstractArray{ImagineSignal,1}) = find(x->isoutput(x), coms)
getoutputs(coms::AbstractArray{ImagineSignal,1}) = view(coms, findoutputs(coms))
findinputs(coms::AbstractArray{ImagineSignal,1}) = find(x->!isoutput(x), coms)
getinputs(coms::AbstractArray{ImagineSignal,1}) = view(coms, findinputs(coms))

isfree(com::ImagineSignal)  = isfree(daq_channel(com), rig_name(com))
findfree(coms::AbstractArray{ImagineSignal,1}) = find(x->isfree(x), coms)
getfree(coms::AbstractArray{ImagineSignal,1}) = view(coms, findfree(coms))
findfixed(coms::AbstractArray{ImagineSignal,1}) = find(x->!isfree(x), coms)
getfixed(coms::AbstractArray{ImagineSignal,1}) = view(coms, findfixed(coms))

ispos(com::ImagineSignal)  = ispos(daq_channel(com), rig_name(com))
findpositioners(coms::AbstractArray{ImagineSignal,1}) = find(x->ispos(x), coms)
getpositioners(coms::AbstractArray{ImagineSignal,1}) = view(coms, findpositioners(coms))

isposmonitor(com::ImagineSignal)  = isposmonitor(daq_channel(com), rig_name(com))
findpositionermonitors(coms::AbstractArray{ImagineSignal,1}) = find(x->isposmonitor(x), coms)
getpositionermonitors(coms::AbstractArray{ImagineSignal,1}) = view(coms, findpositionermonitors(coms))

iscam(com::ImagineSignal)  = iscam(daq_channel(com), rig_name(com))
findcameras(coms::AbstractArray{ImagineSignal,1}) = find(x->iscam(x), coms)
getcameras(coms::AbstractArray{ImagineSignal,1}) = view(coms, findcameras(coms))

iscammonitor(com::ImagineSignal)  = iscammonitor(daq_channel(com), rig_name(com))
findcameramonitors(coms::AbstractArray{ImagineSignal,1}) = find(x->iscammonitor(x), coms)
getcameramonitors(coms::AbstractArray{ImagineSignal,1}) = view(coms, findcameramonitors(coms))

islas(com::ImagineSignal)  = islas(daq_channel(com), rig_name(com))
findlasers(coms::AbstractArray{ImagineSignal,1}) = find(x->islas(x), coms)
getlasers(coms::AbstractArray{ImagineSignal,1}) = view(coms, findlasers(coms))

isstim(com::ImagineSignal)  = isstim(daq_channel(com), rig_name(com))
findstimuli(coms::AbstractArray{ImagineSignal,1}) = find(x->isstim(x), coms)
getstimuli(coms::AbstractArray{ImagineSignal,1}) = view(coms, findstimuli(coms))


hasmonitor(com::ImagineSignal) = iscam(com) || ispos(com)
hasactuator(com::ImagineSignal) = iscammonitor(com) || isposmonitor(com)

function monitor_name(com::ImagineSignal)
    if !hasmonitor(com)
        error("There is not monitor (input) corresponding to this channel")
    end
    if iscam(com)
        return name(com) * " frame monitor"
    else
        return name(com) * " monitor"
    end
end
function getmonitor(com::ImagineSignal)
    mon_nm = monitor_name(com)
    temp = rigtemplate(rig_name(com); sample_rate = samprate(com))
    return getname(temp, mon_nm)
end

function actuator_name(com::ImagineSignal)
    if !hasactuator(com)
        error("There is not actuator (output) corresponding to this channel")
    end
    if iscammonitor(com)
        return String(split(name(com), " frame monitor")[1])
    else
        return String(split(name(com), " monitor")[1])
    end
end
function getactuator(com::ImagineSignal)
    act_nm = actuator_name(com)
    temp = rigtemplate(rig_name(com); sample_rate = samprate(com))
    return getname(temp, act_nm)
end

