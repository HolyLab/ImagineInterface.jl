rig_key = "realm"
push!(RIGS, rig_key)
#Mappings from DAQ channel to friendlier default names
const realm_mappings = Dict("AO0"=>"axial piezo",
                      "AO1"=>"horizontal piezo",
                      "AI0"=>"axial piezo monitor",
                      "AI1"=>"horizontal piezo monitor",
                      "AI2"=>"stimuli",
                      "AI3"=>"analogin2",
                      "AI4"=>"AI4",
                      "AI5"=>"AI5",
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

DEFAULT_DAQCHANS_TO_NAMES[rig_key] = realm_mappings
DEFAULT_NAMES_TO_DAQCHANS[rig_key] = dictmap(reverse, realm_mappings)

const realm_aochans = map(x->"AO$(x)", 0:1)
const realm_aichans = map(x->"AI$(x)", 0:15)
const realm_dochans = map(x->"P0.$(x)", 0:6)
const realm_dichans = ["P0.7";]
const realm_pos_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["axial piezo","horizontal piezo"])
const realm_pos_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["axial piezo monitor","horizontal piezo monitor"])
const realm_cam_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["camera1"])
const realm_cam_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["camera1 frame monitor"])
const realm_laschans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["488nm laser shutter"])
const realm_stimchans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["stimulus$x" for x = 1:5])
const realm_fixed_names = ["axial piezo", "axial piezo monitor", "488nm laser shutter", "camera1", "camera1 frame monitor", "stimuli"]
const realm_fixed_daqchans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], realm_fixed_names)

AO_CHANS[rig_key] = OrderedSet(realm_aochans)
AI_CHANS[rig_key] = OrderedSet(realm_aichans)
DO_CHANS[rig_key] = OrderedSet(realm_dochans)
DI_CHANS[rig_key] = OrderedSet(realm_dichans)
POS_CONTROL_CHANS[rig_key] = realm_pos_ctrl_chans
POS_MONITOR_CHANS[rig_key] = realm_pos_mon_chans
CAM_CONTROL_CHANS[rig_key] = realm_cam_ctrl_chans
CAM_MONITOR_CHANS[rig_key] = realm_cam_mon_chans
LAS_CONTROL_CHANS[rig_key] = realm_laschans
STIM_CHANS[rig_key] =OrderedSet(realm_stimchans)
GALVO_CONTROL_CHANS[rig_key] = String[]
GALVO_MONITOR_CHANS[rig_key] = String[]
FIXED_NAMES[rig_key] = realm_fixed_names
FIXED_DAQ_CHANS[rig_key] = realm_fixed_daqchans

RIG_CHIP_SIZES[rig_key] = PCO_EDGE_5_5_CHIP_SIZE
RIG_FRAMERATE_FUNCS[rig_key] = PCO_EDGE_5_5_FRAMERATE_FUNC
RIG_ROI_FUNCS[rig_key] = PCO_EDGE_5_5_ROI_FUNC

LASER_ON_TIME[rig_key] = 10 * Unitful.ms
LASER_OFF_TIME[rig_key] = 10 * Unitful.ms

CAMERA_ON_TIME[rig_key] = 19526.0 * Unitful.ns #This is the worst jitter measured with Edge 5.5 and 4.2 cameras, see ImagineInterface issue #18
CAMERA_OFF_TIME[rig_key] = 19526.0 * Unitful.ns #This is the worst jitter measured with Edge 5.5 and 4.2 cameras, see ImagineInterface issue #18

PIEZO_RANGES[rig_key] = (-400.0μm .. 400.0μm, -10.0V .. 10.0V)
PIEZO_MAX_SPEED[rig_key] = 2000*Unitful.μm / Unitful.s
AO_RANGE[rig_key] = -10.0V .. 10.0V
AI_RANGE[rig_key] = AO_RANGE[rig_key] #TODO: make sure this is true.  (true if we are recording -10..10V on analog inputs)

