#TODO: set more constants.  A partial is below.  These should probably be OCPI rig-specific
#   --keys for extracting conversion factor for raw data to volts (first needs to be added to the metadata in the JSON file)
#       *We may want to store the DAQ's raw type, min voltage, and max voltage in the json metadata
#   --Standardized names for various channels ("piezo", "camera1", "camera2", etc)
#   --Physical channel-to-name mappings? (Currently we leave it up to Imagine to determine channel mappings, but we may want to handle it here)
#   --other constants that will help with reading .ai or .di files from various rigs

const ANALOG_KEY = "analog waveform"
const DIGITAL_KEY = "digital pulse"
const COMPONENT_KEY = "wave list"
const METADATA_KEY = "metadata"
const VERSION_KEY = "version"
const VERSION_STRING = "v1.0"
const RIGS = ["ocpi1"; "ocpi2"]
const TTL_PREFIXES = ["camera"; "laser"; "stimulus"]
const POS_PREFIXES = ["positioner"]

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
    push!(coms, ImagineCommand("positioner1", [], String[], shared_dict, Int64[], piezo_unitfactory(0.0*Unitful.μm, 800.0*Unitful.μm; rawtype = UInt16, samprate = samprate)))
    #cameras
    push!(coms, ImagineCommand("camera1", [], String[], shared_dict, Int64[], ttl_unitfactory(;samprate = samprate)))
        push!(coms, ImagineCommand("camera2", [], String[], shared_dict, Int64[], ttl_unitfactory(;samprate = samprate)))
    #lasers
    for i = 1:5
        push!(coms, ImagineCommand("laser$i", [], String[], shared_dict, Int64[], ttl_unitfactory(;samprate = samprate)))
    end
    #stimuli
    for i = 1:5
        push!(coms, ImagineCommand("stimulus$i", [], String[], shared_dict, Int64[], ttl_unitfactory(;samprate = samprate)))
    end
    return coms
end

#returns an array of empty ImagineCommands, one for each channel accessible to OCPI1 users
#function ocpi1template
