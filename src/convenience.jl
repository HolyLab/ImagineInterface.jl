#####Convenience functions for filtering arrays of Imagine commands by channel name, channel type######

findname{T<:ImagineSignal}(coms::AbstractVector{T}, nm::AbstractString) = findfirst(x->name(x) == nm, coms)
function getname{T<:ImagineSignal}(coms::AbstractVector{T}, nm::AbstractString)
    namei = findname(coms, nm)
    if namei == 0
        error("Name $nm not found")
    else
        coms[namei]
    end
end
finddaqchan{T<:ImagineSignal}(coms::AbstractVector{T}, nm::AbstractString) = findfirst(x->daq_channel(x) == nm, coms)
getdaqchan{T<:ImagineSignal}(coms::AbstractVector{T}, nm::AbstractString) = coms[finddaqchan(coms, nm)]

isdigital{T<:ImagineSignal}(com::T)  = isdigital(daq_channel(com), rig_name(com))
finddigital{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->isdigital(x), coms)
getdigital{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, finddigital(coms))
isanalog(daq_chan::AbstractString, rig::AbstractString) = !isdigital(daq_chan, rig)
isanalog{T<:ImagineSignal}(com::T)  = isanalog(daq_channel(com), rig_name(com))
findanalog{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->!isdigital(x), coms)
getanalog{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findanalog(coms))

isoutput{T<:ImagineSignal}(com::T)  = isoutput(daq_channel(com), rig_name(com))
findoutputs{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->isoutput(x), coms)
getoutputs{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findoutputs(coms))
findinputs{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->!isoutput(x), coms)
getinputs{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findinputs(coms))

isfree{T<:ImagineSignal}(com::T)  = isfree(daq_channel(com), rig_name(com))
findfree{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->isfree(x), coms)
getfree{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findfree(coms))
findfixed{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->!isfree(x), coms)
getfixed{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findfixed(coms))

ispos{T<:ImagineSignal}(com::T)  = ispos(daq_channel(com), rig_name(com))
findpositioners{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->ispos(x), coms)
getpositioners{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findpositioners(coms))

isposmonitor{T<:ImagineSignal}(com::T)  = isposmonitor(daq_channel(com), rig_name(com))
findpositionermonitors{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->isposmonitor(x), coms)
getpositionermonitors{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findpositionermonitors(coms))

iscam{T<:ImagineSignal}(com::T)  = iscam(daq_channel(com), rig_name(com))
findcameras{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->iscam(x), coms)
getcameras{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findcameras(coms))

iscammonitor{T<:ImagineSignal}(com::T)  = iscammonitor(daq_channel(com), rig_name(com))
findcameramonitors{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->iscammonitor(x), coms)
getcameramonitors{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findcameramonitors(coms))

islas{T<:ImagineSignal}(com::T)  = islas(daq_channel(com), rig_name(com))
findlasers{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->islas(x), coms)
getlasers{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findlasers(coms))

isstim{T<:ImagineSignal}(com::T)  = isstim(daq_channel(com), rig_name(com))
findstimuli{T<:ImagineSignal}(coms::AbstractVector{T}) = find(x->isstim(x), coms)
getstimuli{T<:ImagineSignal}(coms::AbstractVector{T}) = view(coms, findstimuli(coms))


hasmonitor{T<:ImagineSignal}(com::T) = iscam(com) || ispos(com)
hasactuator{T<:ImagineSignal}(com::T) = iscammonitor(com) || isposmonitor(com)

function monitor_name{T<:ImagineSignal}(com::T)
    if !hasmonitor(com)
        error("There is not monitor (input) corresponding to this channel")
    end
    if iscam(com)
        return name(com) * " frame monitor"
    else
        return name(com) * " monitor"
    end
end
function getmonitor{T<:ImagineSignal}(com::T)
    mon_nm = monitor_name(com)
    temp = rigtemplate(rig_name(com); sample_rate = samprate(com))
    return getname(temp, mon_nm)
end

function actuator_name{T<:ImagineSignal}(com::T)
    if !hasactuator(com)
        error("There is not actuator (output) corresponding to this channel")
    end
    if iscammonitor(com)
        return String(split(name(com), " frame monitor")[1])
    else
        return String(split(name(com), " monitor")[1])
    end
end
function getactuator{T<:ImagineSignal}(com::T)
    act_nm = actuator_name(com)
    temp = rigtemplate(rig_name(com); sample_rate = samprate(com))
    return getname(temp, act_nm)
end

