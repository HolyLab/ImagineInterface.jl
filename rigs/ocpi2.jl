rig_key = "ocpi-2"
push!(RIGS, rig_key)

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

DEFAULT_DAQCHANS_TO_NAMES[rig_key] = ocpi2_mappings
DEFAULT_NAMES_TO_DAQCHANS[rig_key] = map(reverse, ocpi2_mappings)

const ocpi2_aochans = map(x->"AO$(x)", 0:3) 
const ocpi2_aichans = map(x->"AI$(x)", 0:31)
const ocpi2_dochans = map(x->"P0.$(x)", vcat([0:6...], [8:23...])) 
const ocpi2_dichans = map(x->"P0.$(x)", 24:31)
const ocpi2_pos_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["axial piezo"; "horizontal piezo"])
const ocpi2_pos_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["axial piezo monitor"; "horizontal piezo monitor"])
const ocpi2_cam_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["camera1"; "camera2"])
const ocpi2_cam_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["camera1 frame monitor"; "camera2 frame monitor"])
const ocpi2_laschans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["405nm laser"; "445nm laser"; "488nm laser"; "514nm laser"; "561nm laser"; "all lasers"])
const ocpi2_stimchans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["stimulus$x" for x = 1:15])
const ocpi2_fixed_names = ["axial piezo", "axial piezo monitor", "horizontal piezo", "horizontal piezo monitor", "camera1", "camera1 frame monitor", "camera2", "camera2 frame monitor", "405nm laser", "445nm laser", "488nm laser", "514nm laser", "561nm laser"]
const ocpi2_fixed_daqchans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ocpi2_fixed_names)

AO_CHANS[rig_key] = OrderedSet(ocpi2_aochans)
AI_CHANS[rig_key] = OrderedSet(ocpi2_aichans)
DO_CHANS[rig_key] = OrderedSet(ocpi2_dochans)
DI_CHANS[rig_key] = OrderedSet(ocpi2_dichans)
POS_CONTROL_CHANS[rig_key] = ocpi2_pos_ctrl_chans
POS_MONITOR_CHANS[rig_key] = ocpi2_pos_mon_chans
CAM_CONTROL_CHANS[rig_key] = ocpi2_cam_ctrl_chans
CAM_MONITOR_CHANS[rig_key] = ocpi2_cam_mon_chans
LAS_CONTROL_CHANS[rig_key] = ocpi2_laschans
STIM_CHANS[rig_key] =OrderedSet(ocpi2_stimchans)
FIXED_NAMES[rig_key] = ocpi2_fixed_names
FIXED_DAQ_CHANS[rig_key] = ocpi2_fixed_daqchans

RIG_CHIP_SIZES[rig_key] = PCO_EDGE_4_2_CHIP_SIZE
RIG_FRAMERATE_FUNCS[rig_key] = PCO_EDGE_4_2_FRAMERATE_FUNC

#TODO: measure these
LASER_ON_TIME[rig_key] = 100 * Unitful.μs
LASER_OFF_TIME[rig_key] = 50 * Unitful.μs

PIEZO_RANGES[rig_key] = (0.0μm .. 800.0μm, 0.0V .. 10.0V)
PIEZO_MAX_SPEED[rig_key] = 2000*Unitful.μm / Unitful.s
AO_RANGE[rig_key] = -10.0V .. 10.0V
AI_RANGE[rig_key] = AO_RANGE[rig_key] #TODO: make sure this is true.  (true if we are recording -10..10V on analog inputs)
