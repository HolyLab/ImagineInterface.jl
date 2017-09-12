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
	#TODO: when writing a set of ImagineSignals, check which wave entries get used and only write those

#instead of adding a CommandList type that shares a single wave lookup dict between multiple ImagineSignals...
#combine into one dict before writing to file. do this by adding the sequence_lookup entries of each command to a growing dict.  Throw error if
#pointers to dicts, arrays, or array values are not equal
function combine_lookups(coms::Vector{ImagineSignal})
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

compress_seqnames(c::ImagineSignal) = compress(sequence_names(c))

function initialize_outdict{TT<:HasTimeUnits, TTI<:HasInverseTimeUnits}(rig::String, seq_lookup::Dict, nstacks, frames_per_stack, exp_time::TT, samp_rate::TTI, nsamps, isbidi)
    out_dict = Dict{String,Any}()
    ana_dict = Dict{String,Any}()
    dig_dict = Dict{String,Any}()
    out_dict[VERSION_KEY] = VERSION_STRING
    out_dict[ANALOG_KEY] = ana_dict
    out_dict[DIGITAL_KEY] = dig_dict
    out_dict[COMPONENT_KEY] = seq_lookup
    sampr = ustrip(uconvert(Unitful.s^-1, samp_rate)) #samprate(coms[1])))
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
                                        "sample num" => nsamps,
                                        "rig" => rig)
    return out_dict
end

function _write_commands!(out_dict, coms)
    dig_dict = out_dict[DIGITAL_KEY]
    ana_dict = out_dict[ANALOG_KEY]
    for c in coms
        if isdigital(c)
            dig_dict[name(c)] = Dict{String,Any}("daq channel"=>daq_channel(c))
            if isoutput(c) #only write the sequence field for outputs
                dig_dict[name(c)]["sequence"] = compress(sequence_names(c))
            elseif !isempty(sequence_names(c))
                warn("Writing the $(name(c)) channel as an input even though it has one or more sample sequences")
            end
        else
            ana_dict[name(c)] = Dict{String,Any}("daq channel"=>daq_channel(c))
            if isoutput(c) #only write the sequence field for outputs
                ana_dict[name(c)]["sequence"] = compress(sequence_names(c))
            end
        end
    end
    return out_dict
end

function get_missing_monitors(coms_used)
    output = similar(coms_used, 0)
    for c in coms_used
        if hasmonitor(c)
            if !isempty(findname(coms_used, monitor_name(c)))
                push!(output, getmonitor(c))
            end
        end
    end
    return output
end

function write_commands(fname::String, coms::Vector{ImagineSignal}, nstacks::Int, nframes::Int, exp_time::HasTimeUnits; isbidi::Bool=false)
    @assert splitext(fname)[2] == ".json"
    isused = map(x-> !isoutput(x) || !isempty(x), coms)
    coms_used = coms[isused]
    print("Validating signals before writing...\n")
    validate_all(coms_used; check_is_sufficient = true)
    print("...finished validating signals\n")
    rig = rig_name(first(coms_used))
    seq_lookup = combine_lookups(coms_used)
    mons = get_missing_monitors(coms_used)
    out_dict = initialize_outdict(rig, seq_lookup, nstacks, nframes, exp_time, samprate(coms[1]), length(coms[1]), isbidi)
    if !isempty(mons)
        print("Adding the following required monitors (inputs) to the command file: $(map(name, mons)) \n")
    end
    _write_commands!(out_dict, coms_used)
    print("Writing these commands as requested: $(map(name, coms_used)) \n")
    _write_commands!(out_dict, mons)
    f = open(fname, "w")
    JSON.print(f, out_dict)
    close(f)
end

function JSON.Writer.show_element(io::JSON.Writer.JSONContext, s, x::RepeatedValue)
    JSON.show_element(io, s, x.n)
    JSON.show_element(io, s, x.value)
end
