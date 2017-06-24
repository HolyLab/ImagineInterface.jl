using Base.Test

using JSON, Unitful, AxisArrays
using ImagineInterface
import ImagineInterface.METADATA_KEY

#test reading
fname = "../examples/controls_triangle.json"

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

allcoms = parse_commands(fname)
cam = getcameras(allcoms)[1]
nframes = d[METADATA_KEY]["frames per stack"]
nstacks = d[METADATA_KEY]["stacks"]
@test nframes*nstacks == count_pulses(cam)

#digital
nm = "405nm laser"
las1 = getname(allcoms, nm)
@test isdigital(las1) == true
@test name(las1) == nm
@test length(las1) == nsamps

#decompression
#world-mapped, analog
sampsa0 = decompress(pos, 1, nsamps; sampmap=:world)
sampsa = decompress(getname(allcoms, "axial piezo") , 1, nsamps; sampmap=:world)
@test length(sampsa) == nsamps
@test all(sampsa0.==sampsa)

@test unit(sampsa[1]) == Unitful.μm
axs = axes(sampsa)
@test length(axs) == 1
axsv = axisvalues(axs[1])
@test length(axsv) == 1
@test axsv[1] == linspace(0.0*Unitful.s,6.9999*Unitful.s,nsamps)

#voltage-mapped, analog
sampsa = decompress(pos, 1, nsamps; sampmap=:volts)
@test unit(sampsa[1]) == Unitful.V

#raw, analog
sampsa = decompress(pos, 1, nsamps; sampmap=:raw)
@test eltype(sampsa) == rawtype(pos) #Int16 by default

#world-mapped, digital
sampsd = decompress(las1, 1, nsamps; sampmap=:world)
@test length(sampsd) == nsamps

sampsd = decompress(las1, 1, nsamps; sampmap=:volts)
@test unit(sampsd[1]) == Unitful.V

sampsd = decompress(las1, 1, nsamps; sampmap=:raw)
@test eltype(sampsd) == rawtype(las1) #UInt8 by default


#convenience
digs = getdigital(allcoms)
@test all(map(isdigital, digs))
angs = getanalog(allcoms)
@test all(map(!, map(isdigital, angs)))
#getcameras
#getlasers
#getpositioners
#getstimuli

#write
outname = "test.json"
exp_time = d[METADATA_KEY]["exposure time in seconds"] * Unitful.s
write_commands(outname, allcoms, nstacks, nframes, exp_time; isbidi = false)
allcoms2 = parse_commands(outname)
sp = sortperm(map(name,allcoms)) #sort alphabetically to compare
sp2 = sortperm(map(name,allcoms2))
#The example file doesn't have input entries, so they should have been added automatically when saving
@test length(allcoms2) == length(allcoms) + 3
@assert length(findinputs(allcoms2)) == 3
@test allcoms[sp] == getoutputs(allcoms2[sp2])
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
dat = decompress(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[end] == mapper(pos).worldmax
append!(pos, "ramp_up") #append existing
@test length(pos) == 2*typemax(Int16)+2

#test bounds checking
rawdat = Int16[-5:1:5...] #negative samples for the positioner should be invalid
@test_throws(Exception, append!(pos, "bad", rawdat))
rawdat = Int16[-5:1:5...] * Unitful.V
@test_throws(Exception, append!(pos, "bad", rawdat))
rawdat = Int16[-5:1:5...] * Unitful.μm
@test_throws(Exception, append!(pos, "bad", rawdat))


#replace!
rawdat2 = Int16[typemax(Int16):-1:0...]
replace!(pos, "ramp_up", rawdat2)
dat = decompress(pos, "ramp_up")
@test dat[end] == mapper(pos).worldmin
@test dat[1] == mapper(pos).worldmax
rawdat3 = Int16[0;0;typemax(Int16)] #change length
replace!(pos, "ramp_up", rawdat3)
dat = decompress(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[3] == mapper(pos).worldmax
@test length(pos) == 6

#pop!
pop!(pos)
dat = decompress(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[3] == mapper(pos).worldmax
@test length(pos) == 3

#empty!
empty!(pos)
@test length(pos) == 0
@test length(sequence_lookup(pos)) != 0
empty!(pos; clear_library=true)
@test length(sequence_lookup(pos)) == 0

#append! volts and world units
newdat = Unitful.V * [0.0:0.1:10.0...]
append!(pos, "ramp_up", newdat)
dat = decompress(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[end] == mapper(pos).worldmax

newdat = Unitful.μm * [0.0:0.8:800.0...]
replace!(pos, "ramp_up", newdat)
dat = decompress(pos, "ramp_up")
@test dat[1] == mapper(pos).worldmin
@test dat[end] == mapper(pos).worldmax

