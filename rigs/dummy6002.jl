#For testing using the National Instruments USB-6002 DAQ.
rig_key = "dummy-6002"
push!(RIGS, rig_key)
#The device doesn't support buffered digital I/O so we use an analog output
#for camera pulse commands and analog input to measure feedback

const d6002_mappings = Dict("AO0"=>"axial piezo",
                      "AO1"=>"camera1",
                      "AI0"=>"axial piezo monitor",
                      "AI1"=>"camera1 frame monitor",
                      "AI2"=>"analogin1",
                      "AI3"=>"analogin2",
                      "AI4"=>"analogin3",
                      "AI5"=>"analogin4",
                      "AI6"=>"analogin5",
                      "AI7"=>"analogin6")

DEFAULT_DAQCHANS_TO_NAMES[rig_key] = d6002_mappings
DEFAULT_NAMES_TO_DAQCHANS[rig_key] = dictmap(reverse, d6002_mappings)

const d6002_aochans = map(x->"AO$(x)", 0:1)
const d6002_aichans = map(x->"AI$(x)", [0:7...])
const d6002_dochans = String[]
const d6002_dichans = String[]
const d6002_pos_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["axial piezo"])
const d6002_pos_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["axial piezo monitor"])
const d6002_cam_ctrl_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["camera1"])
const d6002_cam_mon_chans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], ["camera1 frame monitor"])
const d6002_laschans = String[]
const d6002_stimchans = String[]
const d6002_fixed_names = ["axial piezo", "axial piezo monitor", "camera1", "camera1 frame monitor"]
const d6002_fixed_daqchans = map(x->DEFAULT_NAMES_TO_DAQCHANS[rig_key][x], d6002_fixed_names)

AO_CHANS[rig_key] = OrderedSet(d6002_aochans)
AI_CHANS[rig_key] = OrderedSet(d6002_aichans)
DO_CHANS[rig_key] = OrderedSet(d6002_dochans)
DI_CHANS[rig_key] = OrderedSet(d6002_dichans)
POS_CONTROL_CHANS[rig_key] = d6002_pos_ctrl_chans
POS_MONITOR_CHANS[rig_key] = d6002_pos_mon_chans
CAM_CONTROL_CHANS[rig_key] = d6002_cam_ctrl_chans
CAM_MONITOR_CHANS[rig_key] = d6002_cam_mon_chans
LAS_CONTROL_CHANS[rig_key] = d6002_laschans
STIM_CHANS[rig_key] =OrderedSet(d6002_stimchans)
FIXED_NAMES[rig_key] = d6002_fixed_names
FIXED_DAQ_CHANS[rig_key] = d6002_fixed_daqchans

RIG_CHIP_SIZES[rig_key] = PCO_EDGE_4_2_CHIP_SIZE
RIG_FRAMERATE_FUNCS[rig_key] = PCO_EDGE_4_2_FRAMERATE_FUNC

LASER_ON_TIME[rig_key] = 100 * Unitful.μs
LASER_OFF_TIME[rig_key] = 100 * Unitful.μs

CAMERA_ON_TIME[rig_key] = 19526.0 * Unitful.ns #This is the worst jitter measured with Edge 5.5 and 4.2 cameras, see ImagineInterface issue #18
CAMERA_OFF_TIME[rig_key] = 19526.0 * Unitful.ns #This is the worst jitter measured with Edge 5.5 and 4.2 cameras, see ImagineInterface issue #18

PIEZO_RANGES[rig_key] = (0.0μm .. 400.0μm, 0.0V .. 10.0V)
PIEZO_MAX_SPEED[rig_key] = 2000*Unitful.μm / Unitful.s
AO_RANGE[rig_key] = -10.0V .. 10.0V
AI_RANGE[rig_key] = AO_RANGE[rig_key] #TODO: make sure this is true.  (true if we are recording -10..10V on analog inputs)
