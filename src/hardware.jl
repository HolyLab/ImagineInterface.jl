function default_samplemapper(rig_name::String, chan_name::String; samprate = 10000s^-1)
    if iscam(chan_name) || islas(chan_name) || isstim(chan_name)
        return ttl_samplemapper(; samprate = samprate)
    elseif ispos(chan_name)
        return piezo_samplemapper(default_piezo_ranges[rig_name]...; rawtype=UInt16, samprate = samprate)
    else
        error("Unrecognized channel name")
    end
end

function piezo_samplemapper{TL<:HasLengthUnits,TV<:HasVoltageUnits, TU}(p::AbstractInterval{TL}, v::AbstractInterval{TV}; rawtype=UInt16, samprate::HasInverseTimeUnits{Int, TU}=10000s^-1)
    return SampleMapper(typemin(rawtype), typemax(rawtype), minimum(v), maximum(v), minimum(p), maximum(p), samprate)
end

#Shortcut for creating a generic digital TTL SampleMapper, assumes TTL level of 3.3V (though this doesn't matter to Imagine, only for visualizing in Julia)
function ttl_samplemapper{U}(; samprate::HasInverseTimeUnits{Int, U}=10000s^-1)
    return SampleMapper(UInt8(false), UInt8(true), 0.0*Unitful.V, 3.3*Unitful.V, false, true, samprate)
end

const default_piezo_ranges = Dict("ocpi1"=>(0.0μm .. 400.0μm, 0.0V .. 10.0V),
                                  "ocpi2"=>(0.0μm .. 800.0μm, 0.0V .. 10.0V))

function rigtemplate(rig::String; samprate = 10000s^-1)
    if !in(rig, RIGS)
        error("Unsupported rig")
    end
    if rig == "ocpi1"
        return ocpi1template(; samprate = samprate)
    else
        return ocpi2template(; samprate = samprate)
    end
end

#returns an array of empty ImagineCommands, one for each channel accessible to OCPI2 users
function ocpi2template{U}(; samprate::HasInverseTimeUnits{Int,U} = 10000s^-1)
    coms = ImagineCommand[]
    shared_dict = Dict()
    #positioner
    push!(coms, ImagineCommand("positioner1", [], String[], shared_dict, Int[], piezo_samplemapper(default_piezo_ranges["ocpi2"]...; rawtype = UInt16, samprate = samprate)))
    #cameras
    push!(coms, ImagineCommand("camera1", [], String[], shared_dict, Int[], ttl_samplemapper(;samprate = samprate)))
    push!(coms, ImagineCommand("camera2", [], String[], shared_dict, Int[], ttl_samplemapper(;samprate = samprate)))
    #lasers
    for i = 1:5
        push!(coms, ImagineCommand("laser$i", [], String[], shared_dict, Int[], ttl_samplemapper(;samprate = samprate)))
    end
    #stimuli
    for i = 1:8
        push!(coms, ImagineCommand("stimulus$i", [], String[], shared_dict, Int[], ttl_samplemapper(;samprate = samprate)))
    end
    return coms
end

#returns an array of empty ImagineCommands, one for each channel accessible to OCPI1 users
function ocpi1template{U}(; samprate::HasInverseTimeUnits{Int,U} = 10000s^-1)
    coms = ImagineCommand[]
    shared_dict = Dict()
    #positioner
    push!(coms, ImagineCommand("positioner1", [], String[], shared_dict, Int64[], piezo_samplemapper(default_piezo_ranges["ocpi1"]...; rawtype = UInt16, samprate = samprate)))
    #cameras
    push!(coms, ImagineCommand("camera1", [], String[], shared_dict, Int64[], ttl_samplemapper(;samprate = samprate)))
    #laser shutter
    push!(coms, ImagineCommand("laser1", [], String[], shared_dict, Int64[], ttl_samplemapper(;samprate = samprate)))
    #stimuli
    for i = 1:8
        push!(coms, ImagineCommand("stimulus$i", [], String[], shared_dict, Int64[], ttl_samplemapper(;samprate = samprate)))
    end
    return coms
end
