using Base.Test

using JSON, Unitful, AxisArrays
using ImagineInterface

#test reading
fname = "../examples/controls_triangle.json"
nsamps = 70000

#analog
d = JSON.parsefile(fname)
pos = parse_command(d, "positioner1")
pos0 = parse_command(fname, "positioner1")
@test length(pos) == length(pos0) == nsamps
@test name(pos) == name(pos0) == "positioner1"
@test isdigital(pos) == false
allcoms = parse_commands(fname)

#digital
las1 = getname(allcoms, "laser1")
@test isdigital(las1) == true
@test name(las1) == "laser1"
@test length(las1) == nsamps

#decompression
#world-mapped, analog
sampsa0 = decompress(pos, 1, nsamps; sampmap=:world)
sampsa = decompress(getname(allcoms, "positioner1") , 1, nsamps; sampmap=:world)
@test length(sampsa) == nsamps
@test all(sampsa0.==sampsa)

@test unit(sampsa[1]) == Unitful.μm
axs = axes(sampsa)
@test length(axs) == 1
axsv = axisvalues(axs[1])
@test length(axsv) == 1
@test axsv[1] == linspace(0.0*Unitful.s,6.9999*Unitful.s,70000)

#voltage-mapped, analog
sampsa = decompress(pos, 1, nsamps; sampmap=:volts)
@test unit(sampsa[1]) == Unitful.V

#raw, analog
sampsa = decompress(pos, 1, nsamps; sampmap=:raw)
@test eltype(sampsa) == rawtype(pos) #UInt16 by default

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
write_commands(outname, "ocpi2", allcoms)
allcoms2 = parse_commands(outname)
sp = sortperm(map(name,allcoms)) #sort alphabetically to compare
sp2 = sortperm(map(name,allcoms2))
@test allcoms[sp] == allcoms2[sp]
rm(outname)

#build commands from template
ocpi1 = rigtemplate("ocpi1"; samprate = 20000)
@test length(getcameras(ocpi1)) == 1
@test length(getlasers(ocpi1)) == 1
@test length(getpositioners(ocpi1)) == 1
@test length(getstimuli(ocpi1)) == 8

ocpi2 = rigtemplate("ocpi2"; samprate = 20000)
@test length(getcameras(ocpi2)) == 2
@test length(getlasers(ocpi2)) == 5
@test length(getpositioners(ocpi2)) == 1
@test length(getstimuli(ocpi2)) == 8

@test sample_rate(ocpi2[1]) == 20000
@test all(x->x==0, map(length, ocpi2))

#append!
pos = getpositioners(ocpi2)[1]
rawdat = UInt16[0:typemax(UInt16)...]
append!(pos, "ramp_up", rawdat)
dat = decompress(pos, "ramp_up")
@test dat[1] == pos.fac.worldmin
@test dat[end] == pos.fac.worldmax
append!(pos, "ramp_up") #append existing
@test length(pos) == 2*typemax(UInt16)+2

#replace!
rawdat2 = UInt16[typemax(UInt16):-1:0...]
replace!(pos, "ramp_up", rawdat2)
dat = decompress(pos, "ramp_up")
@test dat[end] == pos.fac.worldmin
@test dat[1] == pos.fac.worldmax
rawdat3 = UInt16[0;0;typemax(UInt16)] #change length
replace!(pos, "ramp_up", rawdat3)
dat = decompress(pos, "ramp_up")
@test dat[1] == pos.fac.worldmin
@test dat[3] == pos.fac.worldmax
@test length(pos) == 6

#pop!
pop!(pos)
dat = decompress(pos, "ramp_up")
@test dat[1] == pos.fac.worldmin
@test dat[3] == pos.fac.worldmax
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
@test dat[1] == pos.fac.worldmin
@test dat[end] == pos.fac.worldmax

newdat = Unitful.μm * [0.0:0.8:800.0...]
replace!(pos, "ramp_up", newdat)
dat = decompress(pos, "ramp_up")
@test dat[1] == pos.fac.worldmin
@test dat[end] == pos.fac.worldmax

