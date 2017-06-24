function parse_commands(filename::String)
    @assert splitext(filename)[2] == ".json"
    parse_commands(JSON.parsefile(filename))
end

function parse_commands(d::Dict)
    output = ImagineCommand[]
    rig = d[METADATA_KEY]["rig"]
    for typ_key in (ANALOG_KEY, DIGITAL_KEY)
        for k in keys(d[typ_key])
            v = d[typ_key][k]
            seq = haskey(v, "sequence") ? convert(RLEVector, v["sequence"]) : convert(RLEVector, [])
            push!(output, ImagineCommand(rig, k, v["daq channel"], seq, d[COMPONENT_KEY], Int(d[METADATA_KEY]["samples per second"])*Unitful.s^-1))
        end
    end
    return output
end

function parse_command(filename::String, comname::String)
    @assert splitext(filename)[2] == ".json"
    parse_command(JSON.parsefile(filename; dicttype=Dict, use_mmap=true), comname)
end

function parse_command(d::Dict, comname::String)
    rig = d[METADATA_KEY]["rig"]
    for typ_key in (ANALOG_KEY, DIGITAL_KEY)
        ad = d[typ_key]
        if haskey(ad, comname)
            seq = haskey(ad[comname], "sequence") ? convert(RLEVector, ad[comname]["sequence"]) : convert(RLEVector, [])
            return ImagineCommand(rig, comname, ad[comname]["daq channel"], seq, d[COMPONENT_KEY], Int(d[METADATA_KEY]["samples per second"])*Unitful.s^-1)
        end
    end
    error("Command signal name not found")
end
