#Functions called on this type return anonymous functions 
#converting between analog-to-digital converter bits, voltage, and world units
type UnitFactory{Traw,TW, TT}
    rawmin::Traw
    rawmax::Traw
    voltmin::typeof(1.0u"V")
    voltmax::typeof(1.0u"V")
    worldmin::TW
    worldmax::TW
    time_interval::TT
end

raw2volts{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> fac.voltmin + ((x-fac.rawmin)/(fac.rawmax-fac.rawmin))*(fac.voltmax-fac.voltmin)
volts2world{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> fac.worldmin + ((x-fac.voltmin)/(fac.voltmax-fac.voltmin))*(fac.worldmax-fac.worldmin)
world2volts{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> fac.voltmin + ((x-fac.worldmin)/(fac.worldmax-fac.worldmin))*(fac.voltmax-fac.voltmin)
volts2raw{Traw,TW,TT}(fac::UnitFactory{Traw,TW,TT}) = x -> fac.rawmin + ((x-fac.voltmin)/(fac.voltmax-fac.voltmin))*(fac.rawmax-fac.rawmin)

interval_raw(uf::UnitFactory) = ClosedInterval(uf.rawmin, uf.rawmax)
interval_volts(uf::UnitFactory) = ClosedInterval(uf.voltmin, uf.voltmax)
interval_world(uf::UnitFactory) = ClosedInterval(uf.worldmin, uf.worldmax)
intervals(uf::UnitFactory) = (interval_raw(uf), interval_volts(uf), interval_world(uf))

#rate is samples per second
set_sample_rate!(uf::UnitFactory, r::Int) = uf.time_interval = 1/r * Unitful.s
sample_rate(uf::UnitFactory) = convert(Int64, 1.0*Unitful.s / uf.time_interval)

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

function get_prefix(chan_name::String)
    istop = 0
    for cur = 1:length(chan_name)
        if !isnumber(chan_name[cur])
            istop+=1
        else
            break
        end
    end
    if istop == 0
        error("No non-numeric prefix exists")
    end
    return chan_name[1:istop]
end

isttl(chan_name::String) = in(get_prefix(chan_name), TTL_PREFIXES)
ispos(chan_name::String) = in(get_prefix(chan_name), POS_PREFIXES)

function default_unitfactory(rig_name::String, chan_name::String; samprate = 10000)
    if isttl(chan_name)
        return ttl_unitfactory(; samprate = samprate)
    elseif ispos(chan_name)
        if rig_name == "ocpi1"
            return piezo_unitfactory(0.0*Unitful.μm, 400.0*Unitful.μm; rawtype=UInt16, samprate = samprate) 
        elseif rig_name == "ocpi2"
            return piezo_unitfactory(0.0*Unitful.μm, 800.0*Unitful.μm; rawtype=UInt16, samprate = samprate) 
        else
            error("Unrecognized rig")
        end
    else
        error("Unrecognized channel name")
    end
end

#Shortcut for creating a piezo controller UnitFactory, assumes that piezo operates with 0-10V input
function piezo_unitfactory(pmin::Unitful.Length, pmax::Unitful.Length; rawtype=UInt16, samprate=10000)
    return UnitFactory(typemin(rawtype), typemax(rawtype), 0.0*Unitful.V, 10.0*Unitful.V, pmin, pmax, 1/samprate * Unitful.s)
end

#Shortcut for creating a generic digital TTL UnitFactory, assumes TTL level of 3.3V (though this doesn't matter to Imagine, only for visualizing in Julia)
function ttl_unitfactory(; samprate=10000)
    return UnitFactory(UInt8(false), UInt8(true), 0.0*Unitful.V, 3.3*Unitful.V, false, true, 1/samprate * Unitful.s)
end
