function parse_commands(filename::String)
    @assert splitext(filename)[2] == ".json"
    parse_commands(JSON.parsefile(filename))
end

function parse_commands(d::Dict)
    output = ImagineCommand[]
    #rig = d[METADATA_KEY]["rig"]
    #TODO: remove this when rig gets added to the metadata
    if haskey(d[METADATA_KEY], "rig")
        rig = d[METADATA_KEY]["rig"]
    else
        rig = "ocpi2"
    end
    for typ_key in (ANALOG_KEY, DIGITAL_KEY)
        for k in keys(d[typ_key])
            v = d[typ_key][k]
            push!(output, ImagineCommand(rig, k, convert(RLEVector, v), d[COMPONENT_KEY], Int(d[METADATA_KEY]["sample rate"])))
        end
    end
    return output
end

function parse_command(filename::String, comname::String)
    @assert splitext(filename)[2] == ".json"
    parse_command(JSON.parsefile(filename; dicttype=Dict, use_mmap=true), comname)
end

function parse_command(d::Dict, comname::String)
    #rig = d[METADATA_KEY]["rig"]
    #TODO: remove this when rig gets added to the metadata
    if haskey(d[METADATA_KEY], "rig")
        rig = d[METADATA_KEY]["rig"]
    else
        rig = "ocpi2"
    end

    for typ_key in (ANALOG_KEY, DIGITAL_KEY)
        ad = d[typ_key]
        if haskey(ad, comname)
            return ImagineCommand(rig, comname, convert(RLEVector, ad[comname]), d[COMPONENT_KEY], Int(d[METADATA_KEY]["sample rate"]))
        end
    end
    error("Command signal name not found")
end
