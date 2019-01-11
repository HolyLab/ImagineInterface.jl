#####Convenience functions for filtering arrays of Imagine commands by channel name, channel type######

findname(coms::AbstractVector{T}, nm::AbstractString) where{T<:ImagineSignal} =
    findfirst(x->name(x) == nm, coms)
function getname(coms::AbstractVector{T}, nm::AbstractString) where{T<:ImagineSignal}
    namei = findname(coms, nm)
    if namei == 0
        error("Name $nm not found")
    else
        coms[namei]
    end
end
finddaqchan(coms::AbstractVector{T}, nm::AbstractString) where{T<:ImagineSignal} =
    findfirst(x->daq_channel(x) == nm, coms)
getdaqchan(coms::AbstractVector{T}, nm::AbstractString) where{T<:ImagineSignal} =
    coms[finddaqchan(coms, nm)]

isdigital(com::T) where{T<:ImagineSignal} =
    isdigital(daq_channel(com), rig_name(com))
finddigital(coms::AbstractVector{T}) where{T<:ImagineSignal} =
    findall(isdigital, coms)
getdigital(coms::AbstractVector{T}) where{T<:ImagineSignal} =
    view(coms, finddigital(coms))
isanalog(daq_chan::AbstractString, rig::AbstractString) where{T<:ImagineSignal} =
    !isdigital(daq_chan, rig)
isanalog(com::T) where{T<:ImagineSignal} =
    isanalog(daq_channel(com), rig_name(com))
findanalog(coms::AbstractVector{T}) where{T<:ImagineSignal} =
    findall(x->!isdigital(x), coms)
getanalog(coms::AbstractVector{T}) where{T<:ImagineSignal} =
    view(coms, findanalog(coms))

isoutput(com::T) where{T<:ImagineSignal} = isoutput(daq_channel(com), rig_name(com))
isinput(com::T) where{T<:ImagineSignal} = !isoutput(com)
findoutputs(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(isoutput, coms)
getoutputs(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findoutputs(coms))
findinputs(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(isinput, coms)
getinputs(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findinputs(coms))

isfree(com::T) where{T<:ImagineSignal} = isfree(daq_channel(com), rig_name(com))
isfixed(com::T) where{T<:ImagineSignal} = !isfree(com)
findfree(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(isfree, coms)
getfree(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findfree(coms))
findfixed(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(x->!isfree(x), coms)
getfixed(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findfixed(coms))

ispos(com::T) where{T<:ImagineSignal} = ispos(daq_channel(com), rig_name(com))
findpositioners(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(ispos, coms)
getpositioners(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findpositioners(coms))

isposmonitor(com::T) where{T<:ImagineSignal} = isposmonitor(daq_channel(com), rig_name(com))
findpositionermonitors(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(isposmonitor, coms)
getpositionermonitors(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findpositionermonitors(coms))

iscam(com::T) where{T<:ImagineSignal} = iscam(daq_channel(com), rig_name(com))
findcameras(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(iscam, coms)
getcameras(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findcameras(coms))

iscammonitor(com::T) where{T<:ImagineSignal} = iscammonitor(daq_channel(com), rig_name(com))
findcameramonitors(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(iscammonitor, coms)
getcameramonitors(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findcameramonitors(coms))

islas(com::T) where{T<:ImagineSignal} = islas(daq_channel(com), rig_name(com))
findlasers(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(islas, coms)
getlasers(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findlasers(coms))

isstim(com::T) where{T<:ImagineSignal} = isstim(daq_channel(com), rig_name(com))
findstimuli(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(isstim, coms)
getstimuli(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findstimuli(coms))

isgalvo(com::T) where{T<:ImagineSignal} = iscam(daq_channel(com), rig_name(com))
findgalvos(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(iscam, coms)
getgalvos(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findcameras(coms))

isgalvomonitor(com::T) where{T<:ImagineSignal} = isgalvomonitor(daq_channel(com), rig_name(com))
findgalvomonitors(coms::AbstractVector{T}) where{T<:ImagineSignal} = findall(isgalvomonitor, coms)
getgalvomonitors(coms::AbstractVector{T}) where{T<:ImagineSignal} = view(coms, findgalvomonitors(coms))

hasmonitor(com::T) where{T<:ImagineSignal} = iscam(com) || ispos(com) || isgalvo(com)
hasactuator(com::T) where{T<:ImagineSignal} = iscammonitor(com) || isposmonitor(com) || isgalvomonitor(com)

function monitor_name(com::T) where{T<:ImagineSignal}
    if !hasmonitor(com)
        error("There is no monitor (input) corresponding to this channel")
    end
    if iscam(com)
        return name(com) * " frame monitor"
    else
        return name(com) * " monitor"
    end
end
function getmonitor(com::T) where{T<:ImagineSignal}
    mon_nm = monitor_name(com)
    temp = rigtemplate(rig_name(com); sample_rate = samprate(com))
    return getname(temp, mon_nm)
end

function actuator_name(com::T) where{T<:ImagineSignal}
    if !hasactuator(com)
        error("There is no actuator (output) corresponding to this channel")
    end
    if iscammonitor(com)
        return String(split(name(com), " frame monitor")[1])
    else
        return String(split(name(com), " monitor")[1])
    end
end
function getactuator(com::T) where{T<:ImagineSignal}
    act_nm = actuator_name(com)
    temp = rigtemplate(rig_name(com); sample_rate = samprate(com))
    return getname(temp, act_nm)
end

