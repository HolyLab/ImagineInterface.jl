using ImagineInterface, Unitful

#Begin with a microscope-specific template of empty commands
#Currently all output channels must use the same sampling rate
#Here we choose 10k samples per second
scope_name = "ocpi-2"
ocpi2 = rigtemplate("ocpi-2"; sample_rate = 10000*s^-1) #This is just an array of ImagineCommands, one for each controllable signal on OCPI2


#Let's add samples to the positioner trace
positioners = getpositioners(ocpi2) #returns an array of length 1
pos = positioners[1]

#"pos" is an ImagineCommand.  We can append sequences of samples to the (currently empty) command.
#We can append vectors of raw samples, voltage units (since this is an analog output device), or world units.
#Let's inspect the types
@show rawtype(pos) #This rig's positioner requires raw samples to be of type UInt8
@show worldtype(pos) #The raw values are eventually translated into units of microns since this is a piezo positioner

#What intervals of values are acceptable for this positioner?
@show intervals(pos) #shows raw, voltage, and world unit intervals

#We can also query them individually
@show interval_raw(pos)
@show interval_volts(pos)
@show interval_world(pos)

#Let's append sample vectors describing motion in microns
#We will begin at 0um, sweep to the maximum, and then sweep back to 0um
#Note that you can also append a vector of raw values or voltage values
#If the appended vector does not lie within its corresponding interval (as queried by the `intervals` function)
#then you will get an error
sweep_up = [0.0:0.1:800.0...] * Unitful.μm #sweep once from the min to max
sweep_down = [800.0:-0.1:0.0...] * Unitful.μm #sweep once from max to min

#length(sweep_up) == 8001, so with a sample rate of 10k samples per second this sweep will take 0.8 seconds to complete
#WARNING: If you ask the piezo to move more quickly than is safe then you could damage it.
#           For now please respect a maximum speed of 8000um per second.  Soon we will add formal checks for this, 
#           but for now it is the responsibility of the user

append!(pos, "sweep_up", sweep_up)
append!(pos, "sweep_down", sweep_down)

#When appending a new sequence, you must also provide a name of your choice for that sequence.
#If you later want to repeat that sequence, you must provide ONLY the name:
append!(pos, "sweep_up")
append!(pos, "sweep_down")

#The reason for this is that all sequences added are stored in a dictionary where they can be easily reused
#Note that by default this dictionary is shared between the set of ImagineCommands returned when we create a template
#This means that you can use the same sequence in multiple commands without using extra storage space
#(Perhaps this is more useful for digital stimulus signals than for the positioner signal)

#When appending a sequence, the sequence is automatically compressed to save storage space.
#Repeated sequences cost almost zero additional storage space.
#In order to retrieve the sequence again, you must decompress it:
sweep_up = decompress(pos, "sweep_up")

#It's also useful to decompress by sample index (these may come from different named sequences)
decompress(pos, 1, 1000) #get the first 1000 samples
decompress(pos, 1, length(pos)) #get all samples

#We can also query using units of time
decompress(pos, 0.3*Unitful.s, 0.7*Unitful.s)

#Remove the most recently appended sequence using pop!
pop!(pos)

#Remove ALL sequences using empty!
empty!(pos)

#By default, empty! does not remove sequences from the dictionary, so we can add them back again like this
append!(pos, "sweep_up")
append!(pos, "sweep_down")

#We can also replace all instances of a sequence
#Here we replace "sweep_down", keeping the positioner at 800.0μm for 1000 samples after sweeping up
replace!(pos, "sweep_up", fill(800.0*Unitful.μm, 1000))

#(Not shown) Now edit the other command signals in the `ocpi2` vector.

#When finished editing each command in the template, write them all to a file to be parsed by Imagine
#Note that this will throw an error if the commands differ in the number of samples or if commands don't correspond
#to those expected by the "ocpi2" template

write_commands("commands.json", "ocpi-2", ocpi2)

#If you want to load a command file created in Julia or by Imagine
coms = parse_commands("commands.json") # == ocpi2

#Higher-level commands are available for generating sets of commands for an experiment.  See the build_stack.jl example
