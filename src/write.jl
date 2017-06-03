#v1.0 command file layout:
#JSON dict with these entries:
#"analog waveform" => Dict{String,Any}(Pair{String,Any}("positioner1",Any[3,"positioner1_001",2,"positioner1_001",3,"positioner1_001"]))
#	(This dict maps constant analog channel names to a list of subsequences (defined in the "wave list" dict entry).  For each wave entry in the list, the number of repetitions
#	of that entry is specified in the previous list entry, so the ordering is [wave1count, wave1id, wave2count, wave2id...]
#	see hardware.jl for currently allowed names
#  "digital pulse"   => Dict{String,Any}(Pair{String,Any}("laser1",Any[3,"laser1_001",2,"laser1_001",3,"laser1_001"]),Pair{String,Any}("camera2",Any[3,"camera1_001",2,"ca…
#	(this dict follows the same conventions as the analog waveform entry)
#	see hardware.jl for currently allowed names
#  "metadata"        => Dict{String,Any}(Pair{String,Any}("frames",20),Pair{String,Any}("sample rate",10000),Pair{String,Any}("bi-direction",false),Pair{String,Any}("expo…
#	(another dict with this  metadata:
	#  "frames per stack"       (integer)
	#  "samples per second"  (integer, samples per second)
	#  "bi-direction" (true or false)
	#  "exposure time in seconds"     (floating point)
	#  "sample num"   (integer)
	#  "stacks"       (integer)
        #  "rig"          (string)
	#TODO: eliminate redundancies between these parameters and those recorded in the .imagine header (once we move to always using command files in the backend)

#  "version"         => "v1.0"
#  "wave list"       => Dict{String,Any}(Pair{String,Any}("stimulus1_001",Any[100,0,6000,1,2650,0]),Pair{String,Any}("laser_bidirection",Any[601,0,5000,1,1000,0,5000,
	#This is a dict of building block sequences that are composed to create the sequences in "analog waveform" and "digital pulse"
	#Each of these sequences is a list of integers.  Every other element of the list specifies a voltage or (if digital) a true/false value.  The intervening elements
	#store the number of repetitions of the value.  This is useful to compress signals that remain constant much of the time.
	#The order is [samp1count, samp1value, samp2count, samp2value...]
	#Currently we don't require that entries in the wave dict have consistent key strings, or even that they get used at all.
	#TODO: when writing a set of ImagineCommands, check which wave entries get used and only write those

function check_samptypes(coms::Vector{ImagineCommand}, rig::AbstractString)
    #check that all analog and digital entries are acceptable for this rig
    tm = rigtemplate(rig)
    chans0 = map(daq_channel, tm)
    chans = map(daq_channel, coms)
    for chan in chans
        if intervals(getdaqchan(coms, chan)) != intervals(getdaqchan(tm, chan))
            error("The sample value intervals for channel '$chan' are incompatible with the $rig rig.")
        end
    end
    #check that all have equal sample rate
    rs = map(samprate,coms)
    if !all(rs.==rs[1])
        error("All commands must use equal sample rates.  This can be set per-channel with `set_samprate!`")
    end
    #check that all have equal number of samples
    nsamps = map(length, coms)
    if !all(nsamps.==nsamps[1])
        error("All commands must have an equal number of samples.  Check this with `length(com::ImagineCommand)`")
    end
    return true
end

#instead of adding a CommandList type that shares a single wave lookup dict between multiple ImagineCommands...
#combine into one dict before writing to file. do this by adding the sequence_lookup entries of each command to a growing dict.  Throw error if
#pointers to dicts, arrays, or array values are not equal
function combine_lookups(coms::Vector{ImagineCommand})
    output = Dict()
    for c in coms
        sl = sequence_lookup(c)
        for k in keys(sl)
            if !haskey(output, k)
                output[k] = sl[k]
            elseif pointer(output[k]) != pointer(sl[k])
                if !all(output[k].==sl[k])
                    error("Multiple commands contain different versions of the same sequence $k")
                end
            end
        end
    end
    return output
end

compress_seqnames(c::ImagineCommand) = compress(sequence_names(c))

function build_outdict(coms, rig::String, nstacks, frames_per_stack, exp_time, isbidi)
    seq_lookup = combine_lookups(coms)
    out_dict = Dict()
    ana_dict = Dict()
    dig_dict = Dict()
    out_dict[VERSION_KEY] = VERSION_STRING
    out_dict[ANALOG_KEY] = ana_dict
    out_dict[DIGITAL_KEY] = dig_dict
    out_dict[COMPONENT_KEY] = seq_lookup
    sampr = ustrip(uconvert(Unitful.s^-1, samprate(coms[1])))
#    print("Counting frames and exposure samples...")
#    frame_starts = map(pulse_starts, getcameras(coms)) #TODO: implement this function
#    nfs = map(length, frame_starts)
#    nf = nfs[1]
#    if !all(nfs.==nf)
#        error("Currently all cameras must take an equal number of frames")
#    end #TODO: Let cameras have different frame counts?
#    exp_times = map(pulse_stops, getcameras(coms)[1]) - frame_starts
#    exp_time = exp_times[1]
    @assert isa(sampr, Integer) #TODO: Check for samprate beyond DAQ's capability
    out_dict[METADATA_KEY] = Dict("samples per second" => sampr,
                                        "frames per stack" => frames_per_stack,
                                        "stacks" => nstacks,
                                        "bi-direction" => isbidi,
                                        "exposure time in seconds" => ustrip(uconvert(Unitful.s, exp_time)),
                                        "sample num" => length(coms[1]),
                                        "rig" => rig)
    for c in coms
        if isdigital(c)
            dig_dict[name(c)] = Dict("daq channel"=>daq_channel(c), "sequence"=>compress(sequence_names(c)))
        else
            ana_dict[name(c)] = Dict("daq channel"=>daq_channel(c), "sequence"=>compress(sequence_names(c)))
        end
    end
    return out_dict
end

#In order to be "sufficient" a command must include a positioner trace, at least one camera trace, and at least one laser trace
function check_sufficiency(coms::Vector{ImagineCommand})
    if length(findcameras(coms)) == 0
        error("No camera commands were found")
    end
    if length(findpositioners(coms)) == 0
        error("No positioner commands were found")
    end
    if length(findlasers(coms)) == 0
        error("No laser commands were found")
    end
end

#Check whether user has modified fixed names
function check_fixed_names(coms::Vector{ImagineCommand}, rig::String)
    fixed_names = FIXED_NAMES[rig]
    name_lookup = DEFAULT_DAQCHANS_TO_NAMES[rig]
    for c in coms
        nm = name(c)
        dc = daq_channel(c)
        if nm != name_lookup[dc] && in(name_lookup[dc], fixed_names)
            error("DAQ Channel $(dc) must have the name $(name_lookup[dc]) but instead it is named $nm")
        end
    end
    return true
end

#checks that all commands in the vector have the same rig, and the rig is recognized
function check_rig_names(coms::Vector{ImagineCommand})
    rig = rig_name(coms[1])
    if !all(map(rig_name, coms) .== rig)
        error("The set of commands to be written must all be targeted to the same rig")
    end
    if !in(rig, RIGS)
        error("Unrecognized rig: $rig")
    end
    return true
end

#Check for invalid DAQ channel names
function check_valid_channels(coms::Vector{ImagineCommand}, rig::String)
    name_lookup = DEFAULT_DAQCHANS_TO_NAMES[rig]
    for c in map(daq_channel, coms)
        if !haskey(name_lookup, c)
            error("The channel $c is not accessible on this rig")
        end
    end
    nms = map(name, coms)
    chan_nms = map(daq_channel, coms)
    if length(unique(nms)) != length(nms)
        error("Found one or more duplicate channel names")
    end
    if length(unique(chan_nms)) != length(chan_nms)
        error("Found one or more duplicate DAQ channel identifiers")
    end
    return true
end

function write_commands(fname::String, coms::Vector{ImagineCommand}, nstacks::Int, nframes::Int, exp_time::HasTimeUnits; isbidi::Bool=false)
    @assert splitext(fname)[2] == ".json"
    isused = map(x->!isempty(x), coms)
    coms_used = coms[isused]
    check_rig_names(coms_used)
    rig = rig_name(coms_used[1])
    check_valid_channels(coms_used, rig)
    check_fixed_names(coms_used, rig)
    check_sufficiency(coms_used)
    check_samptypes(coms_used, rig)
    #check_speed_limits(coms_used, rig) #TODO: implement this
    print("Writing commands for the following channels: $(map(name, coms)) \n")
    out_dict = build_outdict(coms_used, rig, nstacks, nframes, exp_time, isbidi)
    f = open(fname, "w")
    JSON.print(f, out_dict)
    close(f)
end

function JSON.Writer.show_element(io::JSON.Writer.JSONContext, s, x::RepeatedValue)
    JSON.show_element(io, s, x.n)
    JSON.show_element(io, s, x.value)
end
