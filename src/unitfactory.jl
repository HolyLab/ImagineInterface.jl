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

function default_unitfactory(is_digital::Bool, rawtype::DataType; time_per_sample=1e-4*Unitful.s)
    if is_digital
        return UnitFactory(convert(rawtype, 0),
                            convert(rawtype,1),
                            0.0*Unitful.V,
                            3.3*Unitful.V,
                            false,
                            true,
                            time_per_sample)
    else
        return UnitFactory(typemin(rawtype),
                            typemax(rawtype),
                            0.0*Unitful.V,
                            10.0*Unitful.V,
                            0.0*Unitful.μm,
                            800.0*Unitful.μm,
                            time_per_sample)
    end
end


