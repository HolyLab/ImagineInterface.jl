push!(RIGS, "ocpi-1")
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

DEFAULT_DAQCHANS_TO_NAMES["ocpi-1"] = ocpi1_mappings
DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"] = map(reverse, ocpi1_mappings)

const ocpi1_aochans = map(x->"AO$(x)", 0:1)
const ocpi1_aichans = map(x->"AI$(x)", vcat([0;], [2:15...])) #currently AI1 is unused 
const ocpi1_dochans = map(x->"P0.$(x)", 0:6)
const ocpi1_dichans = ["P0.7";]
const ocpi1_pos_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["axial piezo"])
const ocpi1_pos_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["axial piezo monitor"])
const ocpi1_cam_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["camera1"])
const ocpi1_cam_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["camera1 frame monitor"])
const ocpi1_laschans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["488nm laser shutter"])
const ocpi1_stimchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ["stimulus$x" for x = 1:5])
const ocpi1_fixed_names = ["axial piezo", "axial piezo monitor", "488nm laser shutter", "camera1", "camera1 frame monitor"]
const ocpi1_fixed_daqchans = map(x->DEFAULT_NAMES_TO_DAQCHANS["ocpi-1"][x], ocpi1_fixed_names)

AO_CHANS["ocpi-1"] = OrderedSet(ocpi1_aochans)
AI_CHANS["ocpi-1"] = OrderedSet(ocpi1_aichans)
DO_CHANS["ocpi-1"] = OrderedSet(ocpi1_dochans)
DI_CHANS["ocpi-1"] = OrderedSet(ocpi1_dichans)
POS_CONTROL_CHANS["ocpi-1"] = ocpi1_pos_ctrl_chans
POS_MONITOR_CHANS["ocpi-1"] = ocpi1_pos_mon_chans
CAM_CONTROL_CHANS["ocpi-1"] = ocpi1_cam_ctrl_chans
CAM_MONITOR_CHANS["ocpi-1"] = ocpi1_cam_mon_chans
LAS_CONTROL_CHANS["ocpi-1"] = ocpi1_laschans
STIM_CHANS["ocpi-1"] =OrderedSet(ocpi1_stimchans)
FIXED_NAMES["ocpi-1"] = ocpi1_fixed_names
FIXED_DAQ_CHANS["ocpi-1"] = ocpi1_fixed_daqchans

RIG_CHIP_SIZES["ocpi-1"] = PCO_EDGE_5_5_CHIP_SIZE
RIG_FRAMERATE_FUNCS["ocpi-1"] = PCO_EDGE_5_5_FRAMERATE_FUNC
