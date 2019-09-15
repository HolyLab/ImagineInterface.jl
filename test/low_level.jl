using Test

using JSON, Unitful, AxisArrays
using ImagineInterface
import ImagineInterface.METADATA_KEY

#test reading

example_dir = joinpath(dirname(@__DIR__), "examples")
fname = joinpath(example_dir, "t.json")

#analog
d = JSON.parsefile(fname)
pos = parse_command(d, "axial piezo")
pos0 = parse_command(fname, "axial piezo")
nsamps = d[METADATA_KEY]["sample num"]
@test length(pos) == length(pos0) == nsamps
@test name(pos) == name(pos0) == "axial piezo"
@test isdigital(pos) == false

sample_rate = d[METADATA_KEY]["samples per second"]
@test sample_rate*Unitful.s^-1 == samprate(pos)

rig = d[METADATA_KEY]["rig"]
@test rig_name(pos) == rig

#show
show(IOBuffer(), pos)

allcoms = parse_commands(fname)
cam = getcameras(allcoms)[1]
camid = name(cam)
@test in(camid, keys(d[METADATA_KEY]))

nframes = d[METADATA_KEY][camid]["frames per stack"]
nstacks = d[METADATA_KEY][camid]["stacks"]
@test nframes*nstacks == count_pulses(cam)


#digital
nm = "488nm laser shutter"
las1 = getname(allcoms, nm)
@test isdigital(las1) == true
@test name(las1) == nm
@test length(las1) == nsamps
@test_throws ErrorException getname(allcoms, "nonexistent name")

#show
show(IOBuffer(), las1)

#decompression
#world-mapped, analog
sampsa0 = get_samples(pos, 1, nsamps; sampmap=:world)
sampsa = get_samples(getname(allcoms, "axial piezo") , 1, nsamps; sampmap=:world)
@test length(sampsa) == nsamps
@test all(sampsa0.==sampsa)

@test unit(sampsa[1]) == Unitful.μm
axs = AxisArrays.axes(sampsa)
@test length(axs) == 1
axsv = axisvalues(axs[1])
@test length(axsv) == 1
@test axsv[1] == range(0.0*Unitful.s, stop=4.74238*Unitful.s, length=nsamps)

#voltage-mapped, analog
sampsa = get_samples(pos, 1, nsamps; sampmap=:volts)
@test unit(sampsa[1]) == Unitful.V

#raw, analog
sampsa = get_samples(pos, 1, nsamps; sampmap=:raw)
@test eltype(sampsa) == rawtype(pos) #Int16 by default

#world-mapped, digital
sampsd = get_samples(las1, 1, nsamps; sampmap=:world)
@test length(sampsd) == nsamps

sampsdsub = get_samples(las1, 50000, 100000; sampmap=:world)
@test all(sampsdsub.==sampsd[50000:100000])

sampsd = get_samples(las1, 1, nsamps; sampmap=:volts)
@test unit(sampsd[1]) == Unitful.V

sampsd = get_samples(las1, 1, nsamps; sampmap=:raw)
@test eltype(sampsd) == rawtype(las1) #UInt8 by default

#time-based indexing
sampsd = get_samples(las1, 1, nsamps; sampmap=:world)
subsamps = get_samples(las1, 0.0*Unitful.s, 0.0*Unitful.s)
@test length(subsamps) == 1
@test subsamps[1] == sampsd[1]
subsamps = get_samples(las1, 0.0*Unitful.s, 0.1*Unitful.s)
@test all(sampsd[1:500].==subsamps[1:500])
@test get_samples(las1, 0.0049*Unitful.s, 0.0050*Unitful.s) == [false, false, false, false, false, true]

#allow 0-count RepeatedValues
stim_com = getstimuli(rigtemplate("ocpi-2"; sample_rate = 5*Unitful.s^-1))[1]
nsamps_on = nsamps_off = 2
stim_on = RepeatedValue(nsamps_on, true)
stim_off = RepeatedValue(nsamps_off, false)
stim_0=RepeatedValue(0, false)

#0-count first
stim_vec = RepeatedValue{UInt8}[]
push!(stim_vec,stim_0)
push!(stim_vec, stim_on)
push!(stim_vec, stim_off)
v = convert(Vector{UInt8}, stim_vec)
append!(stim_com, "on_off", stim_vec)
@test ImagineInterface.get_samples_raw(stim_com, 1, length(stim_com)) == convert(Vector{UInt8}, stim_vec)

#0-count middle
empty!(stim_com; clear_library=true)
stim_vec = RepeatedValue{UInt8}[]
push!(stim_vec, stim_on)
push!(stim_vec,stim_0)
push!(stim_vec, stim_off)
v = convert(Vector{UInt8}, stim_vec)
append!(stim_com, "on_off", stim_vec)
@test ImagineInterface.get_samples_raw(stim_com, 1, length(stim_com)) == convert(Vector{UInt8}, stim_vec)

#0-count last
empty!(stim_com; clear_library=true)
stim_vec = RepeatedValue{UInt8}[]
push!(stim_vec, stim_on)
push!(stim_vec, stim_off)
push!(stim_vec,stim_0)
v = convert(Vector{UInt8}, stim_vec)
append!(stim_com, "on_off", stim_vec)
@test ImagineInterface.get_samples_raw(stim_com, 1, length(stim_com)) == convert(Vector{UInt8}, stim_vec)

#this caught an off-by-one error
oc2 = rigtemplate("ocpi-2"; sample_rate = 1000 * inv(Unitful.s))
_cam = getcameras(oc2)[1]
c = fill(UInt8(1), 10)
c[1] = 0
c[end] = 0
append!(_cam, "c", c)
@test ImagineInterface.get_samples_raw(_cam, 10, 10)[1] == false
galvos = getgalvos(oc2)
@test hasmonitor(galvos[1]) && hasmonitor(galvos[2])
galvo_mons = getgalvomonitors(oc2)
@test hasactuator(galvo_mons[1]) && hasactuator(galvo_mons[2])

#convenience
digs = getdigital(allcoms)
for di in digs
    if isoutput(di)
        @test in(daq_channel(di), ImagineInterface.DO_CHANS[rig])
    else
        @test in(daq_channel(di), ImagineInterface.DI_CHANS[rig])
    end
end

angs = getanalog(allcoms)
for an in angs
    if isoutput(an)
        @test in(daq_channel(an), ImagineInterface.AO_CHANS[rig])
    else
        @test in(daq_channel(an), ImagineInterface.AI_CHANS[rig])
    end
end

#write
outname = splitext(tempname())[1] *".json"
exp_time = d[METADATA_KEY]["camera1"]["exposure time in seconds"] * Unitful.s
write_commands(outname, allcoms, nstacks, nframes, exp_time; exp_trig_mode = "External Start", isbidi = false)
allcoms2 = parse_commands(outname)
d2 = JSON.parsefile(outname)
@test d2["version"] == "v1.1"
@test d2[METADATA_KEY]["camera1"]["exposure trigger mode"] == "External Start"
@test d2[METADATA_KEY]["camera1"]["bidirectional"] == false

sp = sortperm(map(name,allcoms)) #sort alphabetically to compare
sp2 = sortperm(map(name,allcoms2))
@test length(allcoms2) == length(allcoms)
@assert length(findinputs(allcoms2)) == 4
@test allcoms[sp] == allcoms2[sp2]
rm(outname)

#build commands from template
ocpi1 = rigtemplate("ocpi-1"; sample_rate = 20000*Unitful.s^-1)
@test length(getcameras(ocpi1)) == 1
@test length(getlasers(ocpi1)) == 1
@test length(getpositioners(ocpi1)) == 1
@test length(getstimuli(ocpi1)) == 5

ocpi2 = rigtemplate("ocpi-2"; sample_rate = 20000*Unitful.s^-1)
@test length(getcameras(ocpi2)) == 2
@test length(getlasers(ocpi2)) == 6
@test length(getpositioners(ocpi2)) == 2
@test length(getstimuli(ocpi2)) == 15

@test samprate(ocpi2[1]) == 20000*Unitful.s^-1
@test all(x->x==0, map(length, ocpi2))

#append!
pos = getpositioners(ocpi2)[1]
rawdat = Int16[0:typemax(Int16)...]
append!(pos, "ramp_up", rawdat)
dat = get_samples(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[end] == mapper(pos).worldmax
append!(pos, "ramp_up") #append existing
@test_throws Exception append!(pos, "alajvekaj") #does not exist
@test_throws Exception add_sequence!(pos, "ramp_up", rawdat) #cannot add because exists
lpos = length(pos)
@test lpos == 2*typemax(Int16)+2

#append! already compressed
stim1 = getstimuli(ocpi2)[1]
stim2 = getstimuli(ocpi2)[2]
append!(stim1, "on_100", trues(100))
rlev = RepeatedValue{rawtype(stim2)}[]
push!(rlev, RepeatedValue(100, true))
append!(stim2, "on_100_2", rlev)
@test length(stim1) == length(stim2)
@test all(get_samples(stim1) .== get_samples(stim2))

#test invalid sample types
rawdat = Int32[1:5...]
@test_throws(Exception, append!(pos, "bad", rawdat))
rawdat = Float64[1:5...] * Unitful.A
@test_throws(Exception, append!(pos, "bad", rawdat))

#test bounds checking
rawdat = Int16[-5:1:5...] #negative samples for the positioner should be invalid
@test_throws(Exception, append!(pos, "bad", rawdat))
rawdat = Int16[-5:1:5...] * Unitful.V
@test_throws(Exception, append!(pos, "bad", rawdat))
rawdat = Int16[-5:1:5...] * Unitful.μm
@test_throws(Exception, append!(pos, "bad", rawdat))

#rename!
@test !isfree(pos)
@test_throws(Exception, rename!(pos, "mypiezo"))
c = ocpi1[findfirst(x->isfree(x), ocpi1)]
nm = name(c)
rename!(c, "new name")
@test name(c) == "new name"
rename!(c, nm)

#replace!
rawdat2 = Int16[typemax(Int16):-1:0...]
replace!(pos, "ramp_up", rawdat2)
@test_throws Exception replace!(pos, "alkjbroaj", rawdat2) #error because sequence does not exist
dat = get_samples(pos, "ramp_up")
@test dat[end] == mapper(pos).worldmin
@test dat[1] == mapper(pos).worldmax
rawdat3 = Int16[0;0;typemax(Int16)] #change length
replace!(pos, "ramp_up", rawdat3)
dat = get_samples(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[3] == mapper(pos).worldmax
@test length(pos) == 6

#pop!
pop!(pos)
dat = get_samples(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[3] == mapper(pos).worldmax
@test length(pos) == 3

#empty!
empty!(pos)
@test length(pos) == 0
@test length(sequence_lookup(pos)) != 0
append!(pos, "ramp_up")
empty!(pos; clear_library=true)
@test !haskey(sequence_lookup(pos), "ramp_up")

#append! volts and world units
newdat = Unitful.V * [0.0:0.1:10.0...]
append!(pos, "ramp_up", newdat)
dat = get_samples(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[end] == mapper(pos).worldmax

newdat = Unitful.μm * [0.0:0.8:800.0...]
replace!(pos, "ramp_up", newdat)
dat = get_samples(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[end] == mapper(pos).worldmax

lpos = length(pos)
append!(pos, "ramp_up2", newdat[1:5])
append!(pos, "ramp_up2") #append existing, not the first sequence
@test length(pos) == lpos + 10
@test all(get_samples(pos, "ramp_up2") .== get_samples(pos)[lpos+6:end])

#Test metadata retrieval functions
cs2 = chip_size("ocpi-2")
cs1 = chip_size("ocpi-1")
@test max_framerate("ocpi-2", cs2...) == 100.0*Unitful.s^-1
@test max_framerate("ocpi-2", cs2[1], div(cs2[2],2)) == 200.0*Unitful.s^-1
@test max_framerate("ocpi-1", cs1...) == 100.0*Unitful.s^-1
@test max_framerate("ocpi-1", cs1[1], div(cs1[2],2)) == 200.0*Unitful.s^-1

@test max_roi("ocpi-2", 100*Unitful.s^-1) == cs2
@test max_roi("ocpi-2", 200*Unitful.s^-1) == (cs2[1], floor(Int, cs2[2]/2))
@test max_roi("ocpi-1", 100*Unitful.s^-1) == cs1
@test max_roi("ocpi-1", 200*Unitful.s^-1) == (cs1[1], floor(Int, cs1[2]/2))
