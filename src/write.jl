#v1.0 command file layout:
#JSON dict with these entries:
#"analog waveform" => Dict{String,Any}(Pair{String,Any}("positioner1",Any[3,"positioner1_001",2,"positioner1_001",3,"positioner1_001"]))
#	(This dict maps constant analog channel names to a list of subsequences (defined in the "wave list" dict entry).  For each wave entry in the list, the number of repetitions
#	of that entry is specified in the previous list entry, so the ordering is [wave1count, wave1id, wave2count, wave2id...]
	#currently allowed names:
		#positioner1
		#positioner2 (unneeded?)
		#TODO: analog2, analog3 (OCPI2 only), analog4 (OCPI2 only)
#  "digital pulse"   => Dict{String,Any}(Pair{String,Any}("laser1",Any[3,"laser1_001",2,"laser1_001",3,"laser1_001"]),Pair{String,Any}("camera2",Any[3,"camera1_001",2,"ca…
#	(this dict follows the same conventions as the analog waveform entry)
#	currently allowed names:
#		laser1 -> laser5 (OCPI2 only, at least for entries 2-5)
#		camera1
#		camera2 (OCPI2 only)
#		stimulus1 -> stimulus8	
#  "metadata"        => Dict{String,Any}(Pair{String,Any}("frames",20),Pair{String,Any}("sample rate",10000),Pair{String,Any}("bi-direction",false),Pair{String,Any}("expo…
#	(another dict with this  metadata:
	#  "frames"       (integer)
	#  "sample rate"  (integer, samples per second)
	#  "bi-direction" (true or false)
	#  "exposure"     (floating point)
	#  "sample num"   (integer)
	#  "stacks"       (integer)
	#TODO: add rig identifier (i.e. OCPI1, OCPI2)
	#TODO: propose that we remove all entries except for sample rate and rig identifier (the other ones are inferrable or sometimes irrelevant)

#  "version"         => "v1.0"
#  "wave list"       => Dict{String,Any}(Pair{String,Any}("stimulus1_001",Any[100,0,6000,1,2650,0]),Pair{String,Any}("laser_bidirection",Any[601,0,5000,1,1000,0,5000,
	#This is a dict of building block sequences that are composed to create the sequences in "analog waveform" and "digital pulse"
	#Each of these sequences is a list of integers.  Every other element of the list specifies a voltage or (if digital) a true/false value.  The intervening elements
	#store the number of repetitions of the value.  This is useful to compress signals that remain constant much of the time.
	#The order is [samp1count, samp1value, samp2count, samp2value...]
	#Currently we don't require that entries in the wave dict have consistent key strings, or even that they get used at all.
	#TODO: when writing a set of ImagineCommands, check which wave entries get used and only write those

#determine whether two commands have equal metadata (does not check for differences in the sequence of samples)
#ignores sample rate if `ignore_time` keyword arg is set
function issimilar(com1::ImagineCommand, com2::ImagineCommand; ignore_time=false)
    issim = true
    if rawtype(com1) != rawtype(com2) || name(com1) != name(com2) || isdigital(com1) != isdigital(com2)
        issim = false
    end
    if intervals(com1.fac) != intervals(com2.fac)
        issim = false
    end
    if !ignore_time
        if length(com1) != length(com2) || sample_rate(com1) != sample_rate(com2)
            issim = false
        end
    end
    return issim
end

function validate(coms::Vector{ImagineCommand}, rig::AbstractString)
    #check that all analog and digital entries are acceptable for this rig
    tm = rigtemplate(rig)
    nms0 = map(name, tm)
    nms1 = map(name, coms)
    if !isempty(setdiff(nms0, nms1))
#        error("Missing the following essential commands for this rig: $(setdiff(nms0,nms1))")
    end
    if !isempty(setdiff(nms1, nms0))
        error("The following unsupported commands were found: $(setdiff(nms1,nms0))")
    end
    if length(unique(nms1)) != length(nms1)
        error("Found one or more duplicate channel names")
    end
    for nm in nms1
        if !issimilar(getname(coms, nm), getname(tm, nm); ignore_time=true)
            error("Command '$nm' has metadata incompatible with rig $rig")
        end
    end
    #check that all have equal sample rate
    rs = map(sample_rate,coms)
    if !all(rs.==rs[1])
        error("All commands must use equal sample rates.  This can be set per-channel with `set_sample_rate!`")
    end
    #check that all have equal number of samples OR that they have zero samples? (unused)
    nsamps = map(length, coms)
    if !all(nsamps.==nsamps[1])
#        error("All commands must have an equal number of samples.  Check this with `length(com::ImagineCommand)`")
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

#TODO: disallow empty commands?
function build_outdict(coms::Vector{ImagineCommand}, rig::String)
    seq_lookup = combine_lookups(coms)
    out_dict = Dict()
    ana_dict = Dict()
    dig_dict = Dict()
    out_dict[VERSION_KEY] = VERSION_STRING
    out_dict[ANALOG_KEY] = ana_dict
    out_dict[DIGITAL_KEY] = dig_dict
    out_dict[COMPONENT_KEY] = seq_lookup
    out_dict[METADATA_KEY] = Dict("sample rate" => sample_rate(coms[1]), "rig" => rig)
    for c in coms
        #if isdigital(c) && !isempty(c)
        if isdigital(c)
            dig_dict[name(c)] = compress(sequence_names(c))
        #elseif !isempty(c)
        else
            ana_dict[name(c)] = compress(sequence_names(c))
        end
    end
    return out_dict
end

function write_commands(fname::String, rig::String, coms::Vector{ImagineCommand})
    @assert splitext(fname)[2] == ".json"
    validate(coms, rig)
    out_dict = build_outdict(coms, rig)
    f = open(fname, "w")
    JSON.print(f, out_dict)
    close(f)
end



