#TODO: set more constants.  A partial is below.  These should probably be OCPI rig-specific
#   --keys for extracting conversion factor for raw data to volts (first needs to be added to the metadata in the JSON file)
#       *We may want to store the DAQ's raw type, min voltage, and max voltage in the json metadata
#   --other constants that will help with reading .ai or .di files from various rigs

const ANALOG_KEY = "analog waveform"
const DIGITAL_KEY = "digital pulse"
const COMPONENT_KEY = "wave list"
const METADATA_KEY = "metadata"
const VERSION_KEY = "version"
const VERSION_STRING = "v1.0"
const RIGS = ["ocpi-1"; "ocpi-2"; "ocpi-lsk"]
