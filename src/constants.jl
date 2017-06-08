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
const RIGS = ["ocpi-1"; "ocpi-2"]
#const TTL_PREFIXES = ["camera"; "laser"; "stimulus"]
#const POS_PREFIXES = ["positioner"]

