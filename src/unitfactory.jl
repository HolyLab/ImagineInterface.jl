#Functions called on this type return anonymous functions
#converting between analog-to-digital converter bits, voltage, and world units
type UnitFactory{Traw,TW, TT}
    rawmin::Traw
    rawmax::Traw
    voltmin::typeof(1.0V)
    voltmax::typeof(1.0V)
    worldmin::TW
    worldmax::TW
    time_interval::TT
end

raw2volts{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> fac.voltmin + ((x-fac.rawmin)/(fac.rawmax-fac.rawmin))*(fac.voltmax-fac.voltmin)
volts2world{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> fac.worldmin + ((x-fac.voltmin)/(fac.voltmax-fac.voltmin))*(fac.worldmax-fac.worldmin)
world2volts{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> fac.voltmin + ((x-fac.worldmin)/(fac.worldmax-fac.worldmin))*(fac.voltmax-fac.voltmin)
volts2raw{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> round(rawtype(fac), fac.rawmin + ((x-fac.voltmin)/(fac.voltmax-fac.voltmin))*(fac.rawmax-fac.rawmin))
world2raw{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> volts2raw(fac)(world2volts(fac)(x))
raw2world{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> volts2world(fac)(raw2volts(fac)(x))

rawtype(uf::UnitFactory) = typeof(uf.rawmin)
worldtype(uf::UnitFactory) = typeof(uf.worldmin)

interval_raw(uf::UnitFactory) = ClosedInterval(uf.rawmin, uf.rawmax)
interval_volts(uf::UnitFactory) = ClosedInterval(uf.voltmin, uf.voltmax)
interval_world(uf::UnitFactory) = ClosedInterval(uf.worldmin, uf.worldmax)
intervals(uf::UnitFactory) = (interval_raw(uf), interval_volts(uf), interval_world(uf))

#rate is samples per second
set_sample_rate!(uf::UnitFactory, r::Int) = uf.time_interval = 1/r * Unitful.s
sample_rate(uf::UnitFactory) = convert(Int, 1.0*Unitful.s / uf.time_interval)

function ==(uf1::UnitFactory, uf2::UnitFactory)
    eq = true
    for nm in fieldnames(uf1)
        if getfield(uf1, nm) != getfield(uf2, nm)
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


