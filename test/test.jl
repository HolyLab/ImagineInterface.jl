using Base.Test

using JSON, Unitful, AxisArrays
include("../ImagineInterface.jl")
using ImagineInterface

#test reading
fname = "../examples/controls_triangle.json"
nsamps = 78750

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
@test axsv[1] == Ranges.linspace(0.0*Unitful.s,7.8749*Unitful.s,78750)

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
@test eltype(sampsd) == rawtype(las1) #Bool by default


#convenience
digs = getdigital(allcoms)
@test all(map(isdigital, digs))
angs = getanalog(allcoms)
@test all(!map(isdigital, angs))

#ImagineCommand
#emptycommand(true)
#emptycommand(false)

#UnitFactory
#default_unitfactory
