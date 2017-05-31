#Functions called on this type return anonymous functions
#converting between analog-to-digital converter bits, voltage, and world units
type SampleMapper{Traw,TW, TT}
    rawmin::Traw
    rawmax::Traw
    voltmin::typeof(1.0V)
    voltmax::typeof(1.0V)
    worldmin::TW
    worldmax::TW
    time_interval::TT
end

raw2volts{Traw,TW,TT}(mapper::SampleMapper{Traw,TW,TT}) = x -> mapper.voltmin + ((x-mapper.rawmin)/(mapper.rawmax-mapper.rawmin))*(mapper.voltmax-mapper.voltmin)
volts2world{Traw,TW,TT}(mapper::SampleMapper{Traw,TW,TT}) = x -> mapper.worldmin + ((x-mapper.voltmin)/(mapper.voltmax-mapper.voltmin))*(mapper.worldmax-mapper.worldmin)
world2volts{Traw,TW,TT}(mapper::SampleMapper{Traw,TW,TT}) = x -> mapper.voltmin + ((x-mapper.worldmin)/(mapper.worldmax-mapper.worldmin))*(mapper.voltmax-mapper.voltmin)
volts2raw{Traw,TW,TT}(mapper::SampleMapper{Traw,TW,TT}) = x -> round(rawtype(mapper), mapper.rawmin + ((x-mapper.voltmin)/(mapper.voltmax-mapper.voltmin))*(mapper.rawmax-mapper.rawmin))
world2raw{Traw,TW,TT}(mapper::SampleMapper{Traw,TW,TT}) = x -> volts2raw(mapper)(world2volts(mapper)(x))
raw2world{Traw,TW,TT}(mapper::SampleMapper{Traw,TW,TT}) = x -> volts2world(mapper)(raw2volts(mapper)(x))

rawtype(sm::SampleMapper) = typeof(sm.rawmin)
worldtype(sm::SampleMapper) = typeof(sm.worldmin)

interval_raw(sm::SampleMapper) = ClosedInterval(sm.rawmin, sm.rawmax)
interval_volts(sm::SampleMapper) = ClosedInterval(sm.voltmin, sm.voltmax)
interval_world(sm::SampleMapper) = ClosedInterval(sm.worldmin, sm.worldmax)
intervals(sm::SampleMapper) = (interval_raw(sm), interval_volts(sm), interval_world(sm))

#rate is samples per second
set_sample_rate!(sm::SampleMapper, r::Int) = sm.time_interval = 1/r * Unitful.s
sample_rate(sm::SampleMapper) = convert(Int, 1.0*Unitful.s / sm.time_interval)

function ==(sm1::SampleMapper, sm2::SampleMapper)
    eq = true
    for nm in fieldnames(sm1)
        if getfield(sm1, nm) != getfield(sm2, nm)
            eq = false
            break
        end
    end
    return eq
end

#function get_prefix(chan_name::String)
#    istop = 0
#    for cur = 1:length(chan_name)
#        if !isnumber(chan_name[cur])
#            istop+=1
#        else
#            break
#        end
#    end
#    if istop == 0
#        error("No non-numeric prefix exists")
#    end
#    return chan_name[1:istop]
#end


