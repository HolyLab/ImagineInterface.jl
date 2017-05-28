#You must install Plots and UnitfulPlots in order for this to work
using JSON, AxisArrays, UnitfulPlots, Plots
using ImagineInterface

plotlyjs()
#gr()

pos = parse_command("controls_triangle.json", "positioner1")
allcoms = parse_commands("controls_triangle.json")
sampsa = decompress(pos, 1, 78750)
sampsd = decompress(getname(allcoms, "laser1") , 1, 78750)

plot(sampsa) #has y units but not time

plot(axisvalues(sampsa[Axis{:time}]), sampsa) #has y and time units.  Should we make this easier?
