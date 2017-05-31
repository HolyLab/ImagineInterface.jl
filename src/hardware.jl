function default_unitfactory(rig_name::String, chan_name::String; samprate = 10000)
    if iscam(chan_name) || islas(chan_name) || isstim(chan_name)
        return ttl_unitfactory(; samprate = samprate)
    elseif ispos(chan_name)
        return piezo_unitfactory(default_piezo_ranges[rig_name]...; rawtype=UInt16, samprate = samprate)
    else
        error("Unrecognized channel name")
    end
end

function piezo_unitfactory{TL<:Unitful.Length,TV<:Voltage}(p::AbstractInterval{TL}, v::AbstractInterval{TV}; rawtype=UInt16, samprate=10000)
    return UnitFactory(typemin(rawtype), typemax(rawtype), minimum(v), maximum(v), minimum(p), maximum(p), 1/samprate * Unitful.s)
end

#Shortcut for creating a generic digital TTL UnitFactory, assumes TTL level of 3.3V (though this doesn't matter to Imagine, only for visualizing in Julia)
function ttl_unitfactory(; samprate=10000)
    return UnitFactory(UInt8(false), UInt8(true), 0.0*Unitful.V, 3.3*Unitful.V, false, true, 1/samprate * Unitful.s)
end

const default_piezo_ranges = Dict("ocpi1"=>(0.0μm .. 400.0μm, 0.0V .. 10.0V),
                                  "ocpi2"=>(0.0μm .. 800.0μm, 0.0V .. 10.0V))

function rigtemplate(rig::String; samprate = 10000)
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
function ocpi2template(; samprate = 10000)
    coms = ImagineCommand[]
    shared_dict = Dict()
    #positioner
    push!(coms, ImagineCommand("positioner1", [], String[], shared_dict, Int[], piezo_unitfactory(default_piezo_ranges["ocpi2"]...; rawtype = UInt16, samprate = samprate)))
    #cameras
    push!(coms, ImagineCommand("camera1", [], String[], shared_dict, Int[], ttl_unitfactory(;samprate = samprate)))
    push!(coms, ImagineCommand("camera2", [], String[], shared_dict, Int[], ttl_unitfactory(;samprate = samprate)))
    #lasers
    for i = 1:5
        push!(coms, ImagineCommand("laser$i", [], String[], shared_dict, Int[], ttl_unitfactory(;samprate = samprate)))
    end
    #stimuli
    for i = 1:8
        push!(coms, ImagineCommand("stimulus$i", [], String[], shared_dict, Int[], ttl_unitfactory(;samprate = samprate)))
    end
    return coms
end

#returns an array of empty ImagineCommands, one for each channel accessible to OCPI1 users
function ocpi1template(; samprate = 10000)
    coms = ImagineCommand[]
    shared_dict = Dict()
    #positioner
    push!(coms, ImagineCommand("positioner1", [], String[], shared_dict, Int64[], piezo_unitfactory(default_piezo_ranges["ocpi1"]...; rawtype = UInt16, samprate = samprate)))
    #cameras
    push!(coms, ImagineCommand("camera1", [], String[], shared_dict, Int64[], ttl_unitfactory(;samprate = samprate)))
    #laser shutter
    push!(coms, ImagineCommand("laser1", [], String[], shared_dict, Int64[], ttl_unitfactory(;samprate = samprate)))
    #stimuli
    for i = 1:8
        push!(coms, ImagineCommand("stimulus$i", [], String[], shared_dict, Int64[], ttl_unitfactory(;samprate = samprate)))
    end
    return coms
end
