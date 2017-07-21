#Functions called on this type return anonymous functions
#converting between analog-to-digital converter bits, voltage, and world units
type SampleMapper{Traw,TW}
    rawmin::Traw
    rawmax::Traw
    voltmin::HasVoltageUnits
    voltmax::HasVoltageUnits
    worldmin::TW
    worldmax::TW
    samprate::HasInverseTimeUnits
end

raw2volts{Traw,TW}(mapper::SampleMapper{Traw,TW}) = x::Traw -> mapper.voltmin + ((Int(x)-mapper.rawmin)/(Int(mapper.rawmax)-mapper.rawmin))*(mapper.voltmax-mapper.voltmin)
volts2world{Traw,TW}(mapper::SampleMapper{Traw,TW}) = x::HasVoltageUnits -> convert(TW, mapper.worldmin + ((x-mapper.voltmin)/(mapper.voltmax-mapper.voltmin))*(mapper.worldmax-mapper.worldmin))
world2volts{Traw,TW}(mapper::SampleMapper{Traw,TW}) = x::TW -> mapper.voltmin + ((x-mapper.worldmin)/(mapper.worldmax-mapper.worldmin))*(mapper.voltmax-mapper.voltmin)

function volts2raw{Traw,TW}(mapper::SampleMapper{Traw,TW})
    bc = bounds_check(mapper)
    return x::HasVoltageUnits -> bc(round(rawtype(mapper), mapper.rawmin + ((x-mapper.voltmin)/(mapper.voltmax-mapper.voltmin))*(Int(mapper.rawmax)-mapper.rawmin)))
end

function world2raw{Traw,TW}(mapper::SampleMapper{Traw,TW})
    bc = bounds_check(mapper)
    w2v = world2volts(mapper)
    v2r = volts2raw(mapper)
    return x::TW -> bc(v2r(w2v(x)))
end

raw2world{Traw,TW}(mapper::SampleMapper{Traw,TW}) = x::Traw -> volts2world(mapper)(raw2volts(mapper)(x))

bounds_check{Traw,TW}(mapper::SampleMapper{Traw, TW}) = x::Traw -> (x >= mapper.rawmin && x <= mapper.rawmax) ? x : error("Raw value $x is outside of the valid range")

rawtype{Traw,TW}(sm::SampleMapper{Traw, TW}) = Traw
worldtype{Traw,TW}(sm::SampleMapper{Traw, TW}) = TW

interval_raw(sm::SampleMapper) = ClosedInterval(sm.rawmin, sm.rawmax)
interval_volts(sm::SampleMapper) = ClosedInterval(sm.voltmin, sm.voltmax)
interval_world(sm::SampleMapper) = ClosedInterval(sm.worldmin, sm.worldmax)
intervals(sm::SampleMapper) = (interval_raw(sm), interval_volts(sm), interval_world(sm))

set_samprate!(sm::SampleMapper, r::HasInverseTimeUnits) = sm.samprate = r #round(Int, ustrip(1/r)) * unit(1/r)
samprate(sm::SampleMapper) = sm.samprate

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


