module ImagineInterface

using JSON, Unitful
using MappedArrays, AxisArrays, IntervalSets
using Compat

import Base: convert, show, length, size, isempty, ==, append!, pop!, empty!

using Unitful: μm, V
@compat const Voltage{T,U} = Quantity{T, typeof(0.0V).parameters[2], U}

include("unitfactory.jl")
include("imaginecommand.jl")
include("constants.jl")
include("convenience.jl")
include("parse.jl")
include("write.jl")

#imaginecommand.jl
export ImagineCommand,
        name,
	rawtype,
        worldtype,
        sample_rate,
	isdigital,
        sequences,
	sequence_names,
	sequence_lookup,
        decompress,
        replace!

#constants.jl
export rigtemplate

#convenience.jl
export getname,
        getdigital,
        getanalog,
        getpositioners,
        getcameras,
        getlasers,
        getstimuli

#parse.jl
export parse_command,
        parse_commands

#write.jl
export write_commands

end #module
