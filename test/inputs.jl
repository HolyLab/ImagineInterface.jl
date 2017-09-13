using ImagineInterface, ImagineFormat
using Base.Test
using Unitful
import Unitful:s

e_dir = joinpath(dirname(@__DIR__), "examples")

ai_recs = parse_ai(joinpath(e_dir, "t.ai"); imagine_header = joinpath(e_dir, "t.imagine"))
di_recs = parse_di(joinpath(e_dir, "t.di"); imagine_header = joinpath(e_dir, "t.imagine"))
o_coms = parse_commands(joinpath(e_dir, "t.json"))
do_coms = getoutputs(getdigital(o_coms))
ao_coms = getoutputs(getanalog(o_coms))
di_coms = getinputs(getdigital(o_coms))
ai_coms = getinputs(getanalog(o_coms))

@test length(di_coms) == length(di_recs)
@test length(ai_coms) == length(ai_recs)

hdr = ImagineFormat.parse_header(joinpath(e_dir, "t.imagine"))

ai_chans = hdr["channel list"]
ai_labs = split(hdr["label list"], "\$")

for (i, r) in enumerate(ai_recs)
    mon = getname(ai_coms, name(r))
    @test daq_channel(mon) == daq_channel(r)
    hdr_idx = findfirst(x->x==name(r), ai_labs)
    @test hdr_idx == findfirst(x->x==parse(Int, split(daq_channel(r), "I")[2]), ai_chans)
    @test hdr["rig"] == rig_name(r)  == rig_name(mon)
    @test mapper(r).samprate == mapper(mon).samprate == hdr["scan rate"] * s^-1
    @test daq_channel(r) == daq_channel(mon) == "AI$(ai_chans[hdr_idx])"
    if hasactuator(mon)
        com = getname(ao_coms, actuator_name(mon))
        @test hdr["rig"] == rig_name(com)
        @test mapper(com).samprate == hdr["scan rate"] * s^-1
        @test length(r) == length(com)
        @test duration(r) == duration(com)
    end
end

di_chans = hdr["di channel list"]
di_labs = split(hdr["di label list"], "\$")

for (i, r) in enumerate(di_recs)
    mon = getname(di_coms, name(r))
    @test daq_channel(mon) == daq_channel(r)
    hdr_idx = findfirst(x->x==name(r), di_labs)
    @test hdr_idx == findfirst(x->x==parse(Int, split(daq_channel(r), ".")[2]), di_chans)
    @test hdr["rig"] == rig_name(r)  == rig_name(mon)
    @test mapper(r).samprate == mapper(mon).samprate == hdr["di scan rate"] * s^-1
    @test daq_channel(r) == daq_channel(mon) == "P0.$(di_chans[hdr_idx])"
    if hasactuator(mon)
        com = getname(do_coms, actuator_name(mon))
        @test hdr["rig"] == rig_name(com)
        @test mapper(com).samprate == hdr["scan rate"] * s^-1
        @test length(r) == length(com)
        @test duration(r) == duration(com)
    end
end

@test length(di_labs) - length(find(x->x=="unused", di_labs)) == length(di_recs)

nexp_di = count_pulses(getname(di_recs, "camera1 frame monitor")) 
nexp_ai = count_pulses(getname(ai_recs, "camera1 analog monitor"))
nexp_do = count_pulses(getname(do_coms, "camera1"))
npulse_laser = count_pulses(getname(do_coms, "all lasers"))
@test nexp_di == nexp_ai == nexp_do == npulse_laser == hdr["number of frames requested"]

pos_ao = ustrip(get_samples(getname(ao_coms, "axial piezo")))
pos_ai = ustrip(get_samples(getname(ai_recs, "axial piezo monitor")))
@test cor(pos_ao, pos_ai) >= 0.99

#Automatic .json, .ai, .di, and .imagine loading
exp_sigs = load_signals(joinpath(e_dir, "t.json"))
@test length(exp_sigs) == length(do_coms) + length(ao_coms) + length(di_recs) + length(ai_recs)
for s in Iterators.flatten((do_coms, ao_coms, di_recs, ai_recs))
    @test s == getname(exp_sigs, name(s))
end

@test all(exp_sigs .== load_signals(joinpath(e_dir, "t.imagine")))
@test all(exp_sigs .== load_signals(joinpath(e_dir, "t.ai")))
@test all(exp_sigs .== load_signals(joinpath(e_dir, "t.di")))

