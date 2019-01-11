#Functions called on this type return anonymous functions
#converting between analog-to-digital converter bits, voltage, and world units
mutable struct SampleMapper{Traw, TV, TW}
    rawmin::Traw
    rawmax::Traw
    voltmin::TV
    voltmax::TV
    worldmin::TW
    worldmax::TW
    samprate::HasInverseTimeUnits
end

raw2volts(mapper::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW} =
    x::Traw->mapper.voltmin+((Int(x)-mapper.rawmin)/(Int(mapper.rawmax)-mapper.rawmin))*(mapper.voltmax-mapper.voltmin)
volts2world(mapper::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW} =
    x::HasVoltageUnits->convert(TW, mapper.worldmin+((x-mapper.voltmin)/(mapper.voltmax-mapper.voltmin))*(mapper.worldmax-mapper.worldmin))
#A specialized version for mapping digital voltages encoded in analog channels
volts2world(mapper::SampleMapper{Traw, TV, TW}) where{Traw<:Integer, TV, TW<:Bool} =
    x::HasVoltageUnits -> convert(TW, (x-mapper.voltmin)/(mapper.voltmax-mapper.voltmin)>0.5 ? true : false)
world2volts(mapper::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW} =
    x::TW -> mapper.voltmin + ((x-mapper.worldmin)/(mapper.worldmax-mapper.worldmin))*(mapper.voltmax-mapper.voltmin)

function volts2raw(mapper::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW}
    bc = bounds_check(mapper)
    return x::HasVoltageUnits -> bc(round(rawtype(mapper), mapper.rawmin + ((uconvert(unit(TV), x)-mapper.voltmin)/(mapper.voltmax-mapper.voltmin))*(Int(mapper.rawmax)-mapper.rawmin)))
end

function world2raw(mapper::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW}
    bc = bounds_check(mapper)
    w2v = world2volts(mapper)
    v2r = volts2raw(mapper)
    return x::TW -> bc(v2r(w2v(x)))
end

raw2world(mapper::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW} =
    x::Traw -> volts2world(mapper)(raw2volts(mapper)(x))

function bounds_check(mapper::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW}
    x::Traw -> begin
        if (x >= mapper.rawmin && x <= mapper.rawmax)
            return x
        else
            error("Raw value $x is outside of the valid range")
        end
    end
end

rawtype(sm::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW} = Traw
worldtype(sm::SampleMapper{Traw, TV, TW}) where{Traw, TV, TW} = TW

interval_raw(sm::SampleMapper) = ClosedInterval(sm.rawmin, sm.rawmax)
interval_volts(sm::SampleMapper) = ClosedInterval(sm.voltmin, sm.voltmax)
interval_world(sm::SampleMapper) = ClosedInterval(sm.worldmin, sm.worldmax)
intervals(sm::SampleMapper) = (interval_raw(sm), interval_volts(sm), interval_world(sm))

set_samprate!(sm::SampleMapper, r::HasInverseTimeUnits) = sm.samprate = r #round(Int, ustrip(1/r)) * unit(1/r)
samprate(sm::SampleMapper) = sm.samprate

==(sm1::SampleMapper, sm2::SampleMapper) = fieldnames_equal(sm1, sm2)

function fieldnames_equal(v1, v2, nms)
    is_eq = true
    for nm in nms
        if getfield(v1, nm) != getfield(v2, nm)
            is_eq = false
            break
        end
    end
    return is_eq
end

fieldnames_equal(v1::T, v2::T) where T = fieldnames_equal(v1, v2, fieldnames(T))

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


