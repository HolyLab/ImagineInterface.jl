#Mappings from DAQ channel to friendlier default names
const ocpi1_mappings = Dict("AO0"=>"axial piezo",
                      "AO1"=>"analogout1",
                      "AI0"=>"axial piezo monitor",
                      "AI2"=>"analogin1",
                      "AI3"=>"analogin2",
                      "AI4"=>"analogin3",
                      "AI5"=>"analogin4",
                      "AI6"=>"analogin5",
                      "AI7"=>"analogin6",
                      "AI8"=>"analogin7",
                      "AI9"=>"analogin8",
                      "AI10"=>"analogin9",
                      "AI11"=>"analogin10",
                      "AI12"=>"analogin11",
                      "AI13"=>"analogin12",
                      "AI14"=>"analogin13",
                      "AI15"=>"analogin14",
                      "P0.0"=>"stimulus1",
                      "P0.1"=>"stimulus2",
                      "P0.2"=>"stimulus3",
                      "P0.3"=>"stimulus4",
                      "P0.4"=>"488nm laser shutter",
                      "P0.5"=>"camera1",
                      "P0.6"=>"stimulus5",
                      "P0.7"=>"camera1 frame monitor")

const ocpi2_mappings = Dict("AO0"=>"axial piezo",
                      "AO1"=>"horizontal piezo",
                      "AO2"=>"analogout3",
                      "AO3"=>"analogout4",
                      "AI0"=>"axial piezo monitor",
                      "AI1"=>"horizontal piezo monitor",
                      "AI2"=>"analogin1",
                      "AI3"=>"analogin2",
                      "AI4"=>"analogin3",
                      "AI5"=>"analogin4",
                      "AI6"=>"analogin5",
                      "AI7"=>"analogin6",
                      "AI8"=>"analogin7",
                      "AI9"=>"analogin8",
                      "AI10"=>"analogin9",
                      "AI11"=>"analogin10",
                      "AI12"=>"analogin11",
                      "AI13"=>"analogin12",
                      "AI14"=>"analogin13",
                      "AI15"=>"analogin14",
                      "AI16"=>"analogin15",
                      "AI17"=>"analogin16",
                      "AI18"=>"analogin17",
                      "AI19"=>"analogin18",
                      "AI20"=>"analogin19",
                      "AI21"=>"analogin20",
                      "AI22"=>"analogin21",
                      "AI23"=>"analogin22",
                      "AI24"=>"analogin23",
                      "AI25"=>"analogin24",
                      "AI26"=>"analogin25",
                      "AI27"=>"analogin26",
                      "AI28"=>"analogin27",
                      "AI29"=>"analogin28",
                      "AI30"=>"analogin29",
                      "AI31"=>"analogin30",
                      "P0.0"=>"stimulus1",
                      "P0.1"=>"stimulus2",
                      "P0.2"=>"stimulus3",
                      "P0.3"=>"stimulus4",
                      "P0.4"=>"all lasers",
                      "P0.5"=>"camera1",
                      "P0.6"=>"camera2",
#                      "P0.7"=>"reserved",
                      "P0.8"=>"405nm laser",
                      "P0.9"=>"445nm laser",
                      "P0.10"=>"488nm laser",
                      "P0.11"=>"514nm laser",
                      "P0.12"=>"561nm laser",
                      "P0.13"=>"stimulus5",
                      "P0.14"=>"stimulus6",
                      "P0.15"=>"stimulus7",
                      "P0.16"=>"stimulus8",
                      "P0.17"=>"stimulus9",
                      "P0.18"=>"stimulus10",
                      "P0.19"=>"stimulus11",
                      "P0.20"=>"stimulus12",
                      "P0.21"=>"stimulus13",
                      "P0.22"=>"stimulus14",
                      "P0.23"=>"stimulus15",
                      "P0.24"=>"camera1 frame monitor",
                      "P0.25"=>"camera2 frame monitor",
                      "P0.26"=>"diginput1",
                      "P0.27"=>"diginput2",
                      "P0.28"=>"diginput3",
                      "P0.29"=>"diginput4",
                      "P0.30"=>"diginput5",
                      "P0.31"=>"diginput6",)

#Much like OCPI2, but with missing channels for missing hardware
const ocpi_lsk_mappings = Dict("AO0"=>"axial piezo",
#                      "AO1"=>"reserved",
                      "AO2"=>"analogout3",
                      "AO3"=>"analogout4",
                      "AI0"=>"axial piezo monitor",
#                      "AI1"=>"reserved",
                      "AI2"=>"analogin1",
                      "AI3"=>"analogin2",
                      "AI4"=>"analogin3",
                      "AI5"=>"analogin4",
                      "AI6"=>"analogin5",
                      "AI7"=>"analogin6",
                      "AI8"=>"analogin7",
                      "AI9"=>"analogin8",
                      "AI10"=>"analogin9",
                      "AI11"=>"analogin10",
                      "AI12"=>"analogin11",
                      "AI13"=>"analogin12",
                      "AI14"=>"analogin13",
                      "AI15"=>"analogin14",
                      "AI16"=>"analogin15",
                      "AI17"=>"analogin16",
                      "AI18"=>"analogin17",
                      "AI19"=>"analogin18",
                      "AI20"=>"analogin19",
                      "AI21"=>"analogin20",
                      "AI22"=>"analogin21",
                      "AI23"=>"analogin22",
                      "AI24"=>"analogin23",
                      "AI25"=>"analogin24",
                      "AI26"=>"analogin25",
                      "AI27"=>"analogin26",
                      "AI28"=>"analogin27",
                      "AI29"=>"analogin28",
                      "AI30"=>"analogin29",
                      "AI31"=>"analogin30",
                      "P0.0"=>"stimulus1",
                      "P0.1"=>"stimulus2",
                      "P0.2"=>"stimulus3",
                      "P0.3"=>"stimulus4",
                      "P0.4"=>"all lasers",
                      "P0.5"=>"camera1",
#                      "P0.6"=>"reserved",
#                      "P0.7"=>"reserved",
#                      "P0.8"=>"reserved",
#                      "P0.9"=>"reserved",
#                      "P0.10"=>"reserved",
#                      "P0.11"=>"reserved",
#                      "P0.12"=>"reserved",
                      "P0.13"=>"stimulus5",
                      "P0.14"=>"stimulus6",
                      "P0.15"=>"stimulus7",
                      "P0.16"=>"stimulus8",
                      "P0.17"=>"stimulus9",
                      "P0.18"=>"stimulus10",
                      "P0.19"=>"stimulus11",
                      "P0.20"=>"stimulus12",
                      "P0.21"=>"stimulus13",
                      "P0.22"=>"stimulus14",
                      "P0.23"=>"stimulus15",
                      "P0.24"=>"camera1 frame monitor",
#                      "P0.25"=>"reserved",
                      "P0.26"=>"diginput1",
                      "P0.27"=>"diginput2",
                      "P0.28"=>"diginput3",
                      "P0.29"=>"diginput4",
                      "P0.30"=>"diginput5",
                      "P0.31"=>"diginput6",)

const DEFAULT_DAQCHANS_TO_NAMES = Dict("ocpi-1" => ocpi1_mappings,
                                      "ocpi-2" => ocpi2_mappings,
                                      "ocpi-lsk" => ocpi_lsk_mappings)
const DEFAULT_NAMES_TO_DAQCHANS = Dict("ocpi-1" => map(reverse, ocpi1_mappings),
                                      "ocpi-2" => map(reverse, ocpi2_mappings),
                                      "ocpi-lsk" => map(reverse, ocpi_lsk_mappings))
                                      
#Lists of analog output channels
const ocpi1_aochans = map(x->"AO$(x)", 0:1)
const ocpi2_aochans = map(x->"AO$(x)", 0:3) 
const ocpi_lsk_aochans = map(x->"AO$(x)", [0;2;3]) 
const AO_CHANS= Dict("ocpi-1" => ocpi1_aochans,
                      "ocpi-2" => ocpi2_aochans,
                      "ocpi-lsk" => ocpi_lsk_aochans)
#Lists of analog input channels                      
const ocpi1_aichans = map(x->"AI$(x)", vcat([0;], [2:15...])) #currently AI1 is unused 
const ocpi2_aichans = map(x->"AI$(x)", 0:31)
const ocpi_lsk_aichans = map(x->"AI$(x)", vcat([0;], [2:15...])) #currently AI1 is unused 
const AI_CHANS= Dict("ocpi-1" => ocpi1_aichans,
                      "ocpi-2" => ocpi2_aichans,
                      "ocpi-lsk" => ocpi_lsk_aichans)
#Lists of digital output channels
const ocpi1_dochans = map(x->"P0.$(x)", 0:6)
const ocpi2_dochans = map(x->"P0.$(x)", vcat([0:6...], [8:23...])) 
const ocpi_lsk_dochans = map(x->"P0.$(x)", vcat([0:5...], [13:23...])) 
const DO_CHANS= Dict("ocpi-1" => ocpi1_dochans,
                      "ocpi-2" => ocpi2_dochans,
                      "ocpi-lsk" => ocpi_lsk_dochans)
#Lists of digital input channels                      
const ocpi1_dichans = ["P0.7";]
const ocpi2_dichans = map(x->"P0.$(x)", 24:31)
const ocpi_lsk_dichans = map(x->"P0.$(x)", vcat([24;], [26:31...]))
const DI_CHANS= Dict("ocpi-1" => ocpi1_dichans,
                      "ocpi-2" => ocpi2_dichans,
                      "ocpi-lsk" => ocpi_lsk_dichans)

const ocpi1_bit_fields = Dict(zip(sort(ocpi1_dichans), 0:(length(ocpi1_dichans)-1)))
const ocpi2_bit_fields = Dict(zip(sort(ocpi2_dichans), 0:(length(ocpi2_dichans)-1)))
const ocpi_lsk_bit_fields = Dict(zip(sort(ocpi_lsk_dichans), 0:(length(ocpi_lsk_dichans)-1)))
const DI_BIT_FIELDS = Dict("ocpi-1" => ocpi1_bit_fields,
                      "ocpi-2" => ocpi2_bit_fields,
                      "ocpi-lsk" => ocpi_lsk_bit_fields)

#Lists of positioner control daq channels (a subset of AO_CHANS)                                      
const ocpi1_pos_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["axial piezo"])
const ocpi2_pos_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-2"][x], ["axial piezo"; "horizontal piezo"])
const ocpi_lsk_pos_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-lsk"][x], ["axial piezo"])
const POS_CONTROL_CHANS= Dict("ocpi-1" => ocpi1_pos_ctrl_chans,
                      "ocpi-2" => ocpi2_pos_ctrl_chans,
                      "ocpi-lsk" => ocpi_lsk_pos_ctrl_chans)
#Lists of positioner monitor daq channels (a subset of AI_CHANS)                                      
const ocpi1_pos_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["axial piezo monitor"])
const ocpi2_pos_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-2"][x], ["axial piezo monitor"; "horizontal piezo monitor"])
const ocpi_lsk_pos_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-lsk"][x], ["axial piezo monitor"])
const POS_MONITOR_CHANS= Dict("ocpi-1" => ocpi1_pos_mon_chans,
                      "ocpi-2" => ocpi2_pos_mon_chans,
                      "ocpi-lsk" => ocpi_lsk_pos_mon_chans)

#Lists of camera control daq channels                                      
const ocpi1_cam_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["camera1"])
const ocpi2_cam_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-2"][x], ["camera1"; "camera2"])
const ocpi_lsk_cam_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-lsk"][x], ["camera1"])
const CAM_CONTROL_CHANS= Dict("ocpi-1" => ocpi1_cam_ctrl_chans,
                      "ocpi-2" => ocpi2_cam_ctrl_chans,
                      "ocpi-lsk" => ocpi_lsk_cam_ctrl_chans)
#Lists of camera frame monitor daq chans
const ocpi1_cam_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["camera1 frame monitor"])
const ocpi2_cam_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-2"][x], ["camera1 frame monitor"; "camera2 frame monitor"])
const ocpi_lsk_cam_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-lsk"][x], ["camera1 frame monitor"])
const CAM_MONITOR_CHANS= Dict("ocpi-1" => ocpi1_cam_mon_chans,
                      "ocpi-2" => ocpi2_cam_mon_chans,
                      "ocpi-lsk" => ocpi_lsk_cam_mon_chans)

#Lists of laser daq channels                                      
const ocpi1_laschans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["488nm laser shutter"])
const ocpi2_laschans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-2"][x], ["405nm laser"; "445nm laser"; "488nm laser"; "514nm laser"; "561nm laser"; "all lasers"])
const ocpi_lsk_laschans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-lsk"][x], ["all lasers"])
const LAS_CONTROL_CHANS= Dict("ocpi-1" => ocpi1_laschans,
                      "ocpi-2" => ocpi2_laschans,
                      "ocpi-lsk" => ocpi_lsk_laschans)

#Lists of (digital) stimulus daq channels                                      
const ocpi1_stimchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["stimulus$x" for x = 1:5])
const ocpi2_stimchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-2"][x], ["stimulus$x" for x = 1:15])
const ocpi_lsk_stimchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-lsk"][x], ["stimulus$x" for x = 1:15])
const STIM_CHANS= Dict("ocpi-1" => ocpi1_stimchans,
                      "ocpi-2" => ocpi2_stimchans,
                      "ocpi-lsk" => ocpi_lsk_stimchans)

daq_channel_number(ch::String) = parse(Int, last(split("AO0", ['.', 'I', 'O'])))

#These names aren't allowed to be changed by users when writing command files
const ocpi1_fixed_names = ["axial piezo", "axial piezo monitor", "488nm laser shutter", "camera1", "camera1 frame monitor"]
const ocpi1_fixed_daqchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ocpi1_fixed_names)
const ocpi2_fixed_names = ["axial piezo", "axial piezo monitor", "horizontal piezo", "horizontal piezo monitor", "camera1", "camera1 frame monitor", "camera2", "camera2 frame monitor", "405nm laser", "445nm laser", "488nm laser", "514nm laser", "561nm laser"]
const ocpi2_fixed_daqchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-2"][x], ocpi2_fixed_names)
const ocpi_lsk_fixed_names = ["axial piezo", "axial piezo monitor", "all lasers", "camera1", "camera1 frame monitor"]
const ocpi_lsk_fixed_daqchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-lsk"][x], ocpi_lsk_fixed_names)

const FIXED_NAMES = Dict("ocpi-1" => ocpi1_fixed_names, "ocpi-2" => ocpi2_fixed_names, "ocpi-lsk" => ocpi_lsk_fixed_names)
const FIXED_DAQ_CHANS = Dict("ocpi-1" => ocpi1_fixed_daqchans, "ocpi-2" => ocpi2_fixed_daqchans, "ocpi-lsk" => ocpi_lsk_fixed_daqchans)

isfree(daq_chan::String, rig::String) = !in(daq_chan, FIXED_DAQ_CHANS[rig])
isdigital(daq_chan::String, rig::String) = in(daq_chan, DI_CHANS[rig]) || in(daq_chan, DO_CHANS[rig])
isoutput(daq_chan::String, rig::String) = in(daq_chan, AO_CHANS[rig]) || in(daq_chan, DO_CHANS[rig])
ispos(daq_chan::String, rig::String) = in(daq_chan, POS_CONTROL_CHANS[rig])
isposmonitor(daq_chan::String, rig::String) = in(daq_chan, POS_MONITOR_CHANS[rig])
iscam(daq_chan::String, rig::String) = in(daq_chan, CAM_CONTROL_CHANS[rig])
iscammonitor(daq_chan::String, rig::String) = in(daq_chan, CAM_MONITOR_CHANS[rig])
islas(daq_chan::String, rig::String) = in(daq_chan, LAS_CONTROL_CHANS[rig])
isstim(daq_chan::String, rig::String) = in(daq_chan, STIM_CHANS[rig])

const PCO_EDGE_5_5_CHIP_SIZE = (2560, 2160)
const PCO_EDGE_4_2_CHIP_SIZE = (2060, 2048) #We use the (older) CameraLink version (without the new sensor)
const RIG_CHIP_SIZES = Dict("ocpi-1" => PCO_EDGE_5_5_CHIP_SIZE, "ocpi-2" => PCO_EDGE_4_2_CHIP_SIZE) #TODO: add ocpi-lsk
const PCO_EDGE_5_5_FRAMERATE_FUNC = x::Tuple{Int,Int} -> 100 * 2^(log(2, 2048/x[2]))
const PCO_EDGE_4_2_FRAMERATE_FUNC = x::Tuple{Int,Int} -> 100 * 2^(log(2, 2048/x[2]))
const RIG_FRAMERATE_FUNCS = Dict("ocpi-1" => PCO_EDGE_5_5_FRAMERATE_FUNC, "ocpi-2" => PCO_EDGE_4_2_FRAMERATE_FUNC) #TODO: add ocpi-lsk
const EXPOSURE_TRIGGER_DELAY = 0.0 * Unitful.ns #TODO: Get this with PCO_GetImageTiming 

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
    return RIG_FRAMERATE_FUNCS[rig]((hsize,vsize)) * Unitful.s^-1
end

