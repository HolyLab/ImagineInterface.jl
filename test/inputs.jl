using ImagineInterface, ImagineFormat
using Base.Test
using Unitful
import Unitful:s

e_dir = "../examples/"

ai_coms = parse_ai(e_dir*"t.ai"; imagine_header = e_dir*"t.imagine")
di_coms = parse_di(e_dir*"t.di"; imagine_header = e_dir*"t.imagine")
hdr = ImagineFormat.parse_header("../examples/t.imagine")

@test hdr["rig"] == rig_name(ai_coms[1])
@test hdr["rig"] == rig_name(di_coms[1])
@test mapper(ai_coms[1]).samprate == hdr["scan rate"] * s^-1
@test mapper(di_coms[1]).samprate == hdr["di scan rate"] * s^-1

ai_chans = hdr["channel list"]
di_chans = hdr["di channel list"]
ai_labs = split(hdr["label list"], "\$")
di_labs = split(hdr["di label list"], "\$")

for i=1:length(ai_chans) 
    com = getname(ai_coms, ai_labs[i])
    @test daq_channel(com) == "AI$(ai_chans[i])"
end

for i=1:length(di_chans) 
    com = getname(di_coms, di_labs[i])
    @test daq_channel(com) == "P0.$(di_chans[i])"
end

#TODO: check number of samples
#TODO: check values of samples
