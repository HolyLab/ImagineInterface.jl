function parse_commands(filename::String)
    @assert splitext(filename)[2] == ".json"
    parse_commands(JSON.parsefile(filename))
end

function parse_commands(d::Dict)
    output = ImagineCommand[]
    for (typ_key,is_dig) in zip((ANALOG_KEY, DIGITAL_KEY), (false, true))
        for k in keys(d[typ_key])
            push!(output, ImagineCommand(k, d[typ_key][k], is_dig, d[COMPONENT_KEY]))
        end
    end
    return output
end

function parse_command(filename::String, comname::String)
    @assert splitext(filename)[2] == ".json"
    parse_command(JSON.parsefile(filename; dicttype=Dict, use_mmap=true), comname)
end

function parse_command(d::Dict, comname::String)
    for sigtype in (ANALOG_KEY, DIGITAL_KEY)
        ad = d[sigtype]
        if haskey(ad, comname)
            if sigtype == ANALOG_KEY
                return ImagineCommand(comname, ad[comname], false, d[COMPONENT_KEY])
            else
                return ImagineCommand(comname, ad[comname], true, d[COMPONENT_KEY])
            end
        end
    end
    error("Command signal name not found")
end


