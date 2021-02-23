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

cam_num_from_name(nm::String) = parse(Int, last(nm))

function initialize_outdict(rig::String, seq_lookup::Dict, which_cams,
                            nstacks, frames_per_stack, exp_time, samp_rate::TTI,
                            nsamps, exp_trig_mode, isbidi) where{TTI<:HasInverseTimeUnits}
    out_dict = Dict{String,Any}()
    ana_dict = Dict{String,Any}()
    dig_dict = Dict{String,Any}()
    out_dict[VERSION_KEY] = VERSION_STRING
    out_dict[ANALOG_KEY] = ana_dict
    out_dict[DIGITAL_KEY] = dig_dict
    out_dict[COMPONENT_KEY] = seq_lookup
    sampr = convert(Int, ustrip(upreferred(samp_rate)))
    @assert isa(sampr, Integer) #TODO: Check for samprate beyond DAQ's capability
    out_dict[METADATA_KEY] = Dict("samples per second" => sampr,
                                            "sample num" => nsamps,
                                            "rig" => rig,
                                            "generated from" => "ImagineInterface")
    for c in which_cams
        camdict = Dict{String, Any}()
        out_dict[METADATA_KEY][c] = camdict
        i = cam_num_from_name(c)
        #in the case that only one value was supplied, assume equal for both cameras
        #Note that the three lines below wouldn't work more than two cameras
        camdict["frames per stack"] = frames_per_stack[min(i, length(frames_per_stack))]
        camdict["stacks"] = nstacks[min(i, length(nstacks))]
        camdict["exposure time in seconds"] = ustrip(uconvert(Unitful.s, exp_time[min(i, length(exp_time))]))
        camdict["exposure trigger mode"] = exp_trig_mode[min(i, length(nstacks))]
        camdict["bidirectional"] = isbidi[min(i, length(nstacks))]
    end
    out_dict["version"] = "v1.1"
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
                @warn "Writing the $(name(c)) channel as an input even though it has one or more sample sequences"
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
            if findname(coms_used, monitor_name(c)) != nothing
                push!(output, getmonitor(c))
            end
        end
    end
    return output
end

function check_cam_param_counts(cams, params, description::String)
    if length(cams) > 1  && length(params) == 1
        @warn "Two camera output signals were supplied with only one $description argument.  Applying this argument to both cameras"
    elseif length(cams) == 1 && length(params) == 2
        error("Two $description parameters were supplied but only one camera is in use")
    elseif length(cams) != length(params)
        error("Invalid camera and parameter combination")
    end
end

function check_cam_meta(coms::Vector{ImagineSignal}, nstacks, nframes_per_stack, exp_time, exp_trig_mode)
    cams = getcameras(coms)
    check_cam_param_counts(cams, nstacks, "nstacks")
    check_cam_param_counts(cams, nframes_per_stack, "nframes_per_stack")
    check_cam_param_counts(cams, exp_time, "exp_time")
    allowed_modes = ["External Start"; "External Control"; "Fast External Control"]
    for m in exp_trig_mode
        if !in(m, allowed_modes)
            error("Exposure trigger mode $m is unrecognized.  Only these modes are allowed: $(allowed_modes)")
        end
    end
    check_cam_param_counts(cams, exp_trig_mode, "exp_trig_mode")
    frame_counts = zeros(length(cams))
    for i = 1:length(cams)
        frame_counts[i] = count_pulses(cams[i])
        expected_count = nframes_per_stack[min(i,length(nframes_per_stack))] * nstacks[min(i, length(nstacks))]
        if frame_counts[i] != nframes_per_stack[min(i,length(nframes_per_stack))] * nstacks[min(i, length(nstacks))]
            error("Expected $expected_count frames but only counted $(frame_counts[i]) exposure trigger pulses for $(name(cams[i]))")
        end
    end
end

function write_commands(fname::String, coms::Vector{ImagineSignal}, nstacks::NS,
                        nframes_per_stack::NF, exp_time::EXP;
                        exp_trig_mode = ["External Start";], isbidi=false, skip_validation=false,
                        active_cams_sz=default_cams_sz(coms)
                        ) where{NS<:Union{Int, Vector{Int}}, NF<:Union{Int, Vector{Int}}, EXP<:Union{HasTimeUnits, Vector{HasTimeUnits}}}
    @assert splitext(fname)[2] == ".json"
    if isa(exp_trig_mode, AbstractString)
        exp_trig_mode = [exp_trig_mode;]
    end
    isused = map(x-> !isoutput(x) || !isempty(x), coms)
    coms_used = coms[isused]
    if !skip_validation
        print("Validating signals before writing...\n")
        check_cam_meta(coms_used, nstacks, nframes_per_stack, exp_time, exp_trig_mode)
        validate_all(coms_used; check_is_sufficient = true, active_cams_sz=active_cams_sz)
        print("...finished validating signals\n")
    end
    which_cams = map(name, getcameras(coms))
    rig = rig_name(first(coms_used))
    seq_lookup = combine_lookups(coms_used)
    if rig == "ocpi-2" && findname(coms_used, "all lasers")==nothing
        ref_sig = first(getoutputs(coms_used))
        rt = rigtemplate("ocpi-2"; sample_rate = samprate(ref_sig))
        all_las = getname(rt, "all lasers")
        all_las.sequence_lookup = seq_lookup
        append!(all_las, randstring(12), trues(length(ref_sig)))
        check_laser(all_las)
        push!(coms_used, all_las)
    end
    mons = get_missing_monitors(coms_used)
    out_dict = initialize_outdict(rig, seq_lookup, which_cams, nstacks, nframes_per_stack, exp_time, samprate(coms[1]), length(coms[1]), exp_trig_mode, isbidi)
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
