module ImagineInterface

using JSON, Unitful
using MappedArrays, AxisArrays, IntervalSets

import Base.show, Base.length, Base.size, Base.isempty, Base.==

include("unitfactory.jl")
include("imaginecommand.jl")
include("constants.jl")
include("convenience.jl")
include("parse.jl")
include("write.jl")

#imaginecommand.jl
export ImagineCommand,
        empty_command,
        name,
	rawtype,
	isdigital,
	sequence_names,
	sequence_lookup,
#	length,
#	size,
#	isempty,	
        decompress

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
