#####Convenience functions for filtering arrays of Imagine commands by channel name, channel type######

findname(coms::AbstractArray{ImagineCommand,1}, nm::String) = findfirst(x->name(x) == nm, coms)
getname(coms::AbstractArray{ImagineCommand,1}, nm::String) = coms[findname(coms, nm)]

finddigital(coms::AbstractArray{ImagineCommand,1}) = find(x->isdigital(x), coms)
getdigital(coms::AbstractArray{ImagineCommand,1}) = view(coms, finddigital(coms))

findanalog(coms::AbstractArray{ImagineCommand,1}) = find(x->!isdigital(x), coms)
getanalog(coms::AbstractArray{ImagineCommand,1}) = view(coms, findanalog(coms))

findpositioners(coms::AbstractArray{ImagineCommand,1}) = find(x->startswith(name(x), "positioner"), coms)
getpositioners(coms::AbstractArray{ImagineCommand,1}) = view(coms, findpositioners(coms))

findcameras(coms::AbstractArray{ImagineCommand,1}) = find(x->startswith(name(x), "camera"), coms)
getcameras(coms::AbstractArray{ImagineCommand,1}) = view(coms, findcameras(coms))

findlasers(coms::AbstractArray{ImagineCommand,1}) = find(x->startswith(name(x), "laser"), coms)
getlasers(coms::AbstractArray{ImagineCommand,1}) = view(coms, findlasers(coms))

findstimuli(coms::AbstractArray{ImagineCommand,1}) = find(x->startswith(name(x), "stimulus"), coms)
getstimuli(coms::AbstractArray{ImagineCommand,1}) = view(coms, findstimuli(coms))
