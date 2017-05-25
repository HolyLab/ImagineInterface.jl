using JSON, AxisArrays, UnitfulPlots, Plots
using ImagineInterface

plotlyjs()
#gr()

d = JSON.parsefile("controls_triangle.json")
pos = parse_command(d, "positioner1")
allcoms = parse_commands("controls_triangle.json")
sampsa = decompress(pos, 1, 78750)
sampsd = decompress(getname(allcoms, "laser1") , 1, 78750)

plot(sampsa) #has y units but not time

plot(axisvalues(sampsa[Axis{:time}]), sampsa) #has y and time units.  Should we make this easier
