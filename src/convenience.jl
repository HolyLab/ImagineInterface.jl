#####Convenience functions for filtering arrays of Imagine commands by channel name, channel type######

findname(coms::AbstractArray{ImagineCommand,1}, nm::String) = findfirst(x->name(x) == nm, coms)
getname(coms::AbstractArray{ImagineCommand,1}, nm::String) = coms[findname(coms, nm)]

finddigital(coms::AbstractArray{ImagineCommand,1}) = find(x->isdigital(x), coms)
getdigital(coms::AbstractArray{ImagineCommand,1}) = view(coms, finddigital(coms))

findanalog(coms::AbstractArray{ImagineCommand,1}) = find(x->!isdigital(x), coms)
getanalog(coms::AbstractArray{ImagineCommand,1}) = view(coms, findanalog(coms))

ispos(chan_name::String) = startswith(chan_name, "positioner")
ispos(com::ImagineCommand)  = ispos(name(com))
findpositioners(coms::AbstractArray{ImagineCommand,1}) = find(x->ispos(x), coms)
getpositioners(coms::AbstractArray{ImagineCommand,1}) = view(coms, findpositioners(coms))

iscam(chan_name::String) = startswith(chan_name, "camera")
iscam(com::ImagineCommand)  = iscam(name(com))
findcameras(coms::AbstractArray{ImagineCommand,1}) = find(x->iscam(x), coms)
getcameras(coms::AbstractArray{ImagineCommand,1}) = view(coms, findcameras(coms))

islas(chan_name::String) = startswith(chan_name, "laser")
islas(com::ImagineCommand)  = islas(name(com))
findlasers(coms::AbstractArray{ImagineCommand,1}) = find(x->islas(x), coms)
getlasers(coms::AbstractArray{ImagineCommand,1}) = view(coms, findlasers(coms))

#TODO: Remove these when we allow arbitrary renaming of stimulus channels?
isstim(chan_name::String) = startswith(chan_name, "stimulus")
isstim(com::ImagineCommand)  = isstim(name(com))
findstimuli(coms::AbstractArray{ImagineCommand,1}) = find(x->isstim(x), coms)
getstimuli(coms::AbstractArray{ImagineCommand,1}) = view(coms, findstimuli(coms))
