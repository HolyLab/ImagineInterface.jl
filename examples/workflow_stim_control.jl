using ImagineInterface

import Unitful: μm, s

# See "workflow.jl" for a more detailed overview of package functionality

############PRIOR TO USE#################
# Note that before stimulus control via Imagine can be used, an appropriate Chromeleon program (.pgm file) must be used.
# See documentation elsewhere (Autosampler.jl) for instructions on creation of a .pgm file. 

############LOAD A RIG-SPECIFIC COMMAND TEMPLATE#################
sample_rate = 50000s^-1      
rig = "ocpi-2"
ocpi2 = rigtemplate(rig; sample_rate = sample_rate)

pos = getpositioners(ocpi2)[1]  #positioner trace
las1 = getlasers(ocpi2)[1]      #laser trace
cam1 = getcameras(ocpi2)[1]     #camera trace

stim1 = getstimuli(ocpi2)[1]    #stimulus timing trace

############STACK PARAMETERS#################
pmin = 0.0*μm           #Piezo start position in microns
pmax = 200.0*μm         #Piezo stop position in microns
stack_img_time = 1.0s   #Time to complete the imaging sweep with the piezo (remember we also need to reset it to its starting position)
reset_time = 0.5s       #Only used for unidirectional sweeps. Time to reset piezo to starting position.  This time plus "stack_img_time" determines how long it takes to complete an entire stack and be ready to start a new stack
z_spacing = 3.1μm       #The space between slices in the z-stack.
z_pad = 5.0μm           #Set this greater than 0 if you want to ignore the edges of the positioner sweep (only take slices in a central region)

exp_time = 0.011s       #Exposure time of the camera. Make sure this is greater than mn_exp and less than mx_exp above
flash_frac = 0.1        #fraction of time to keep laser on during exposure.  If you set this greater than 1 then the laser will stay on constantly during the imaging sweep

############STACK TIMING PARAMETERS#################
# These timing parameters depend on the specifics of your experiment.
# You have free control over the recording durations, but the stimulus lead time will depend on tubing volume between the autosampler and recording chamber

stimulus_lead_time = 20s            #Interval between injection time and stimulus arrival time (depends on flowrate and tubing volume, so you should measure this for your setup)
baseline_duration = 10s             #Interval between recording start time and stimulus time (positive if recording starts before stimulus presentation)
stimulus_duration = 20s             #Duration of recording for each trial (after stimulus presentation)

# The total recording time for each trial is the sum of the baseline and stimulus durations
@show total_recording_duration = baseline_duration + stimulus_duration

# We will also need to set the time between each trial, which should be enough to accommodate washing of the recording chamber and sample loop
inter_trial_duration = 30s          #Duration of interval between trials

# The total number of recordings to be obtained. This should be the product of the number of stimuli and number of replicates for your experiment
n_stimuli = 2                               #Number of stimuli to present
n_replicates = 3                            #Number of replicates for each stimulus
@show n_trials = n_stimuli * n_replicates   #Number of trials to record

############STACK GENERATION EXAMPLE#################
# unidirectional sweep waveforms
unidi_samps = gen_unidirectional_stack(pmin, pmax, z_spacing, stack_img_time, reset_time, exp_time, sample_rate, flash_frac; z_pad = z_pad)
append!(pos, "unidi_stack_pos", unidi_samps["positioner"])
append!(las1, "unidi_stack_las1", unidi_samps["laser"])
append!(cam1, "unidi_stack_cam1", unidi_samps["camera"]);
sweep_nframes = unidi_samps["nframes"]; #store this for later

# Repeat the unidirectional waveform enough times to achieve the desired recording duration
@show sweeps_per_stim = Int(ceil(total_recording_duration / (stack_img_time + reset_time)))
replicate!(pos, (sweeps_per_stim-1))    
replicate!(las1, (sweeps_per_stim-1))
replicate!(cam1, (sweeps_per_stim-1))

# inter-stimulus rest waveforms
wait_nsamps = inter_trial_duration * sample_rate
wait_samps = Dict(
    "positioner" => fill(eltype(unidi_samps["positioner"])(pmin), wait_nsamps),
    "laser"      => fill(false, wait_nsamps),
    "camera"     => fill(false, wait_nsamps)
)
append!(pos, "wait_stack_pos", wait_samps["positioner"])
append!(las1, "wait_stack_las1", wait_samps["laser"])
append!(cam1, "wait_stack_cam1", wait_samps["camera"]);

# We now have, for the positioner, camera, and laser traces, a waveform for recording a single trial

# Injection trigger signal (true = on, false = off). The autosampler triggers an injection upon the switch to an "on" signal
stim_on_nsamps = Int(ceil(stimulus_duration * sample_rate))   #Number of samples for the "on" signal
stim_on_samps = fill(true, stim_on_nsamps)
stim_off_nsamps = Int(ceil((total_recording_duration + inter_trial_duration - stimulus_duration) * sample_rate))
stim_off_samps = fill(false, stim_off_nsamps)

stim1 = getstimuli(ocpi2)[1]
append!(stim1, "stim1", [stim_on_samps; stim_off_samps])

# We now have, for the stimulus trace, a waveform for triggering injection for a single trial

############STIMULUS TIMING EXAMPLE#################
# Repeat each trace for the desired number of trials
replicate!(pos, n_trials-1)  # Remember, we already have one trial's worth of data in the trace
replicate!(las1, n_trials-1)
replicate!(cam1, n_trials-1)
replicate!(stim1, n_trials-1)

# Currently, the start of a recording and the injection trigger occur at the same time.
# We need to trigger the injection at the appropriate time to account for the desired baseline duration
# and the time it takes for the stimulus to arrive at the recording chamber for each trial
@show stim_delay = baseline_duration - stimulus_lead_time

# Pad beginning and end of experiment to account for interval between recording start and injection trigger
pad_nsamps = Int(abs(stim_delay) * sample_rate)
pad_samps = Dict(
    "positioner" => fill(eltype(unidi_samps["positioner"])(pmin), pad_nsamps),
    "laser"      => fill(false, pad_nsamps),
    "camera"     => fill(false, pad_nsamps),
    "stimulus"   => fill(false, pad_nsamps)
)

# We handle padding the traces depending on whether the stimulus signal needs to occur before or after recording starts for a trial
if stim_delay > 0s
    append!(pos, "pad_stack_pos", pad_samps["positioner"])
    append!(las1, "pad_stack_las1", pad_samps["laser"])
    append!(cam1, "pad_stack_cam1", pad_samps["camera"]);
    prepend!(stim1, "pad_stack_stim1", pad_samps["stimulus"])   #The injection trigger happens after the start of recording
elseif stim_delay < 0s
    prepend!(pos, "pad_stack_pos", pad_samps["positioner"])
    prepend!(las1, "pad_stack_las1", pad_samps["laser"])
    prepend!(cam1, "pad_stack_cam1", pad_samps["camera"])
    append!(stim1, "pad_stack_stim1", pad_samps["stimulus"])    #The injection trigger happens before the start of recording
end

# visualize
# using ImaginePlots, Plots; gr()
# ImaginePlots.plot([pos; las1; cam1; stim1])

# save output
fname = "stimulus_control_example.json"
nstacks = sweeps_per_stim * n_trials
nframes_per_stack = Int(sweep_nframes)
write_commands(fname, ocpi2, nstacks, nframes_per_stack, exp_time; isbidi = false)