#Mappings from DAQ channel to friendlier default names
const ocpi1_mappings = Dict("AO0"=>"axial piezo",
                      "AO1"=>"analogout1",
                      "P0.0"=>"stimulus1",
                      "P0.1"=>"stimulus2",
                      "P0.2"=>"stimulus3",
                      "P0.3"=>"stimulus4",
                      "P0.4"=>"488nm laser shutter",
                      "P0.5"=>"camera1",
                      "P0.6"=>"stimulus5",
                      "P0.7"=>"stimulus6")

const ocpi2_mappings = Dict("AO0"=>"axial piezo",
                      "AO1"=>"horizontal piezo",
                      "A02"=>"analogout3",
                      "AO3"=>"analogout4",
                      "P0.0"=>"stimulus1",
                      "P0.1"=>"stimulus2",
                      "P0.2"=>"stimulus3",
                      "P0.3"=>"stimulus4",
                      "P0.4"=>"405nm laser",
                      "P0.5"=>"camera1",
                      "P0.6"=>"camera2",
                      "P0.7"=>"stimulus5",
                      "P0.8"=>"stimulus6",
                      "P0.9"=>"445nm laser",
                      "P0.10"=>"488nm laser",
                      "P0.11"=>"514nm laser",
                      "P0.12"=>"561nm laser",
                      "P0.13"=>"stimulus7",
                      "P0.14"=>"stimulus8",
                      "P0.15"=>"stimulus9",
                      "P0.16"=>"stimulus10",
                      "P0.17"=>"stimulus11",
                      "P0.18"=>"stimulus12",
                      "P0.19"=>"stimulus13",
                      "P0.20"=>"stimulus14",
                      "P0.21"=>"stimulus15",
                      "P0.22"=>"stimulus16",
                      "P0.23"=>"stimulus17",
                      "P0.24"=>"stimulus18",
                      "P0.25"=>"stimulus19",
                      "P0.26"=>"stimulus20",
                      "P0.27"=>"stimulus21",
                      "P0.28"=>"stimulus22",
                      "P0.29"=>"stimulus23",
                      "P0.30"=>"stimulus24",
                      "P0.31"=>"stimulus25")

const DEFAULT_DAQCHANS_TO_NAMES = Dict("ocpi1" => ocpi1_mappings,
                                      "ocpi2" => ocpi2_mappings)
const DEFAULT_NAMES_TO_DAQCHANS = Dict("ocpi1" => map(reverse, ocpi1_mappings),
                                      "ocpi2" => map(reverse, ocpi2_mappings))
#Lists of positioner daq channels                                      
const ocpi1_poschans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi1"][x], ["axial piezo"])
const ocpi2_poschans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi2"][x], ["axial piezo"; "horizontal piezo"])
const POS_CHANS= Dict("ocpi1" => ocpi1_poschans,
                      "ocpi2" => ocpi2_poschans)
#Lists of camera daq channels                                      
const ocpi1_camchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi1"][x], ["camera1"])
const ocpi2_camchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi2"][x], ["camera1"; "camera2"])
const CAM_CHANS= Dict("ocpi1" => ocpi1_camchans,
                      "ocpi2" => ocpi2_camchans)
#Lists of laser daq channels                                      
const ocpi1_laschans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi1"][x], ["488nm laser shutter"])
const ocpi2_laschans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi2"][x], ["405nm laser"; "445nm laser"; "488nm laser"; "514nm laser"; "561nm laser"])
const LAS_CHANS= Dict("ocpi1" => ocpi1_laschans,
                      "ocpi2" => ocpi2_laschans)
#Lists of (digital) stimulus daq channels                                      
const ocpi1_stimchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi1"][x], ["stimulus$x" for x = 1:6])
const ocpi2_stimchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi2"][x], ["stimulus$x" for x = 1:25])
const STIM_CHANS= Dict("ocpi1" => ocpi1_stimchans,
                      "ocpi2" => ocpi2_stimchans)

#These names aren't allowed to be changed by users when writing command files
const ocpi1_fixed_names = ["axial piezo", "488nm laser shutter", "camera1"]
const ocpi2_fixed_names = ["axial piezo", "horizontal piezo", "camera1", "camera2", "405nm laser", "443nm laser", "488 nm laser", "514nm laser", "561nm laser"]
const FIXED_NAMES = Dict("ocpi1" => ocpi1_fixed_names, "ocpi2" => ocpi2_fixed_names)

function default_samplemapper(rig_name::String, daq_chan_name::String; sample_rate = 10000s^-1)
    if iscam(daq_chan_name, rig_name) || islas(daq_chan_name, rig_name) || isstim(daq_chan_name, rig_name)
        return ttl_samplemapper(; sample_rate = sample_rate)
    elseif ispos(daq_chan_name, rig_name)
        return piezo_samplemapper(default_piezo_ranges[rig_name]...; rawtype=UInt16, sample_rate = sample_rate)
    else
        error("Unrecognized channel name")
    end
end

function piezo_samplemapper{TL<:HasLengthUnits,TV<:HasVoltageUnits, TU}(p::AbstractInterval{TL}, v::AbstractInterval{TV}; rawtype=UInt16, sample_rate::HasInverseTimeUnits{Int, TU}=10000s^-1)
    return SampleMapper(typemin(rawtype), typemax(rawtype), minimum(v), maximum(v), minimum(p), maximum(p), sample_rate)
end

#Shortcut for creating a generic digital TTL SampleMapper, assumes TTL level of 3.3V (though this doesn't matter to Imagine, only for visualizing in Julia)
function ttl_samplemapper{U}(; sample_rate::HasInverseTimeUnits{Int, U}=10000s^-1)
    return SampleMapper(UInt8(false), UInt8(true), 0.0*Unitful.V, 3.3*Unitful.V, false, true, sample_rate)
end

const default_piezo_ranges = Dict("ocpi1"=>(0.0μm .. 400.0μm, 0.0V .. 10.0V),
                                  "ocpi2"=>(0.0μm .. 800.0μm, 0.0V .. 10.0V))

#returns an array of empty ImagineCommands, one for each channel accessible to OCPI2 users
function rigtemplate{U}(rig::String; sample_rate::HasInverseTimeUnits{Int,U} = 10000s^-1)
    if !in(rig, RIGS)
        error("Unsupported rig")
    end
    coms = ImagineCommand[]
    shared_dict = Dict()
    name_lookup = DEFAULT_DAQCHANS_TO_NAMES[rig]
    #positioners
    for c in POS_CHANS[rig]
        nm = name_lookup[c]
        push!(coms, ImagineCommand(nm, c, rig, [], String[], shared_dict, Int[], piezo_samplemapper(default_piezo_ranges[rig]...; rawtype = UInt16, sample_rate = sample_rate)))
    end
    #cameras
    for c in CAM_CHANS[rig]
        nm = name_lookup[c]
        push!(coms, ImagineCommand(nm, c, rig, [], String[], shared_dict, Int[], ttl_samplemapper(;sample_rate = sample_rate)))
    end
    #lasers
    for c in LAS_CHANS[rig]
        nm = name_lookup[c]
        push!(coms, ImagineCommand(nm, c, rig, [], String[], shared_dict, Int[], ttl_samplemapper(;sample_rate = sample_rate)))
    end
    #stimuli
    for c in STIM_CHANS[rig]
        nm = name_lookup[c]
        push!(coms, ImagineCommand(nm, c, rig, [], String[], shared_dict, Int[], ttl_samplemapper(;sample_rate = sample_rate)))
    end
    return coms
end

const PCO_EDGE_5_5_CHIP_SIZE = (2560, 2160)
const PCO_EDGE_4_2_CHIP_SIZE = (2060, 2048) #We use the (older) CameraLink version (without the new sensor)
const RIG_CHIP_SIZES = Dict("ocpi1" => PCO_EDGE_5_5_CHIP_SIZE, "ocpi2" => PCO_EDGE_4_2_CHIP_SIZE)
const PCO_EDGE_5_5_FRAMERATE_FUNC = x::Tuple{Int,Int} -> 100 * 2^(log(2, 2048/x[2]))
const PCO_EDGE_4_2_FRAMERATE_FUNC = x::Tuple{Int,Int} -> 100 * 2^(log(2, 2048/x[2]))
const RIG_FRAMERATE_FUNCS = Dict("ocpi1" => PCO_EDGE_5_5_FRAMERATE_FUNC, "ocpi2" => PCO_EDGE_4_2_FRAMERATE_FUNC)

#For querying camera-related info
function chip_size(rig::String)
    if !in(rig, RIGS)
        error("Unrecognized rig")
    end
    return RIG_CHIP_SIZES[rig]
end

function max_framerate(rig::String, hsize::Int, vsize::Int)
    if !in(rig, RIGS)
        error("Unrecognized rig")
    end
    return RIG_FRAMERATE_FUNCS[rig]((hsize,vsize))
end

