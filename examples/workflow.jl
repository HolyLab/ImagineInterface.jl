using ImagineInterface

import Unitful: μm, s

############LOAD A RIG-SPECIFIC COMMAND TEMPLATE#################
sample_rate = 50000s^-1 #analog output samples per second
				#Currently all output channels must use the same sample rate
				#Currently this also sets the analog input rate in Imagine
				#High-framerate recordings should use a high sample rate.
@show ImagineInterface.RIGS #show supported rigs                                
rig = "ocpi-2"
ocpi2 = rigtemplate(rig; sample_rate = sample_rate)
@show ocpi2 #This is a vector where each element is an empty ImagineSignal
#We can edit commands individually by extracting them from this array.
#Note however that after you finish editing and are ready to write a command file, all commands must have an equal number of samples (or remain empty)

#Let's look at a positioner trace
positioners = getpositioners(ocpi2)
pos = positioners[1]
#"pos" is an ImagineSignal.  We can append sequences of samples to the (currently empty) signal to use as a command for Imagine.
#We can append vectors of raw samples, voltage units (since this is an analog output device), or world units.
#If you're not sure what type os samples you can append, or what ranges of values are allowed, you can check with this command
@show intervals(pos) #this signal has 3 (equivalent) representations, one uses raw sample units, one uses Voltage units, and the other uses Length units
#While you can append vectors using any of the 3 representations, in practice it's most intuitive to use "world" units (μm for the positioner)  when interacting with ImagineSignals

#You can also query the intervals individually
@show interval_raw(pos)
@show interval_volts(pos)
@show interval_world(pos)

#We can create a sample vector describing motion in microns like this
#If the appended vector does not lie within its corresponding interval (as queried by the `intervals` function)
#then you will get an error
sweep_up = [0.0:0.1:800.0...] * Unitful.μm #sweep once from the min to max
#If you want to add these samples to the positioner command, you can do it like this:
append!(pos, "sweep_up", sweep_up)
#When appending a sequence, the sequence is automatically compressed to save storage space.
#Repeated sequences cost almost zero additional storage space.
#In order to retrieve the sequence again, you must decompress it.
#You can decompress using its key, in this case "sweep_up":
sweep_up2 = get_samples(pos, "sweep_up") #now sweep_up == sweep_up2
#Or you can use sample indices
some_samps = get_samples(pos, 50, 100)
#OR you can use time
more_samps = get_samples(pos, 0.1s, 0.13s)

#You can also remove the last set of samples appended to the list like this:
pop!(pos)
#This package provides easier-to-use functions to get commonly used sequences of samples.
#Currently you can generate an entire stack of positioner, camera, and laser pulse signals in the fashion shown below

############STACK PARAMETERS#################
pmin = 0.0*μm #Piezo start position in microns
pmax = 200.0*μm #Piezo stop position in microns
stack_img_time = 1.0s #Time to complete the imaging sweep with the piezo (remember we also need to reset it to its starting position)
reset_time = 0.5s #Time to reset piezo to starting position.  This time plus "stack_img_time" determines how long it takes to complete an entire stack and be ready to start a new stack
z_spacing = 3.1μm #The space between slices in the z-stack.
z_pad = 5.0μm #Set this greater than 0 if you want to ignore the edges of the positioner sweep (only take slices in a central region)
			#This is helpful for high-speed acquisitions where the piezo positioner may oscillate at the edges of sweeps
#Now we need to set the exposure time.  With constraints imposed by the above pmin, pmax, stack_img_time, and z_spacing parameters there is actually a maximum exposure time.
#If you exceed this time then you will get en error.  The helper function below will tell you what is the maximum time possible with these parameters
#(We add/subtract z_pad because it shrinks the effective range of imaging sweep)
#@show mx_exp = max_exp_time((pmax-z_pad) - (pmin+z_pad), z_spacing, stack_img_time) #TODO: implement this function

#There is also a minimum exposure time that the camera can achieve.  This depends on the camera model.  For now all OCPI microscopes have similar cameras, but the helper
#function still requires you to specify the target rig in case cameras change in the future
#Note also that the camera's maximum frame-per-second rate depends on the ROI size.  For more details see the PCO.Edge camera manuals.
#If you're not sure of the maximal ROI size on an OCPI rig, retrieve it with this function:
@show hmax, vmax = chip_size(rig)
#You can check the maximal framerate when using a smaller rectangular section of the chip
#Note that current PCO.Edge camera framerates only depend on the vertical size of the ROI
h = 1000 #doesn't matter with current cameras
v = 1000
@show mx_f = max_framerate(rig, h,v)
mn_exp = 1/mx_f #This is the minimum possible exposure time
exp_time = 0.011s  #Exposure time of the camera. Make sure this is greater than mn_exp and less than mx_exp above
flash_frac = 0.1 #fraction of time to keep laser on during exposure.  If you set this greater than 1 then the laser will stay on constantly during the imaging sweep


############STACK GENERATION EXAMPLE#################
#The below function generates 3 sequences of samples, stored in a dictionary
d = gen_unidirectional_stack(pmin, pmax, z_spacing, stack_img_time, reset_time, exp_time, sample_rate, flash_frac; z_pad = z_pad)
#d["positioner"] is a vector of piezo samples (in length units)
#d["camera"]  is vector of true-or-false values encoding a camera exposure trigger sequence
#d["laser"]  is vector of true-or-false values encoding laser flash sequence (these will be center-aligned with the exposure pulses)
@show nframes = d["nframes"]  # is an integer keeping track of the number of frames in this sequence, useful when creating the command file

#Similarly we can also generate a bidirectional imaging cycle (which actually includes two stacks)
#Note the command is the same except "reset_time" is missing because imaging occurs during what was the reset period in the previous example
#...and the forward and backward imaging sweeps are of equal duration
d2 = gen_bidirectional_stack(pmin, pmax, z_spacing, stack_img_time, exp_time, sample_rate, flash_frac; z_pad = z_pad)
@show d2["nframes"] #note that there are twice as many frames as in the unidirectional example because one cycle of the positioner includes two stacks

#Let's append our newly-created sample vectors to their respective commands in the template
append!(pos, "uni_stack_pos", d["positioner"])
lasers = getlasers(ocpi2)
las1 = lasers[1] #You could also append to any of the other lasers
append!(las1, "uni_stack_las1", d["laser"])
cams = getcameras(ocpi2)
cam1 = cams[1] #You could also append to the other camera
append!(cam1, "uni_stack_cam1", d["camera"])


using Plots, ImaginePlots #You will have to install ImaginePlots with Pkg.clone before it will work

#There is a special plot method that lets you visualize all commands.  Currently it groups commands in multiple plot windows base on hardware
plot(ocpi2) #note that this currently won't display when you run the script via include("workflow.jl") Type or paste the command in the terminal to see the plot

#If you are satisfied with the waveform created and would like to duplicate it many times for a multi-stack acquisition with Imagine...
replicate!(pos, 9) #appends the current contents of pos 9 times to the end of pos
#In this case the replicate! command is equivalent to calling append!(pos, "uni_stack_pos") 99 times
replicate!(las1, 9) #appends the current contents of pos 9 times to the end of pos
replicate!(cam1, 9) #appends the current contents of pos 9 times to the end of pos

#If you plot again you'll see a total of 10 stacks
#However plotting is pretty slow at the moment, so it's recommended to visualize one stack at a time
#plot(ocpi2)

#When you are ready, export the set of commands to a .json file readable by Imagine

#All commands passed to this function must have an equal number of samples OR no samples
#In addition to the commands themselves, currently you must provide additional metadata so that the .imagine header gets written correctly during a recording
nstacks = 10
write_commands("test.json", ocpi2, nstacks, nframes, exp_time; isbidi = false)
write_commands("test.json", ocpi2, nstacks, nframes, exp_time; isbidi = false, active_cams_sz=[(h,v)]) # If you want to apply camera capture size
                    # to `check_camera`, specify `active_cams_sz` arguemnt which shoul be vector of tuple holding active sizes of cameras

