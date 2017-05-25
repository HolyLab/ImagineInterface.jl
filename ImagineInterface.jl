module ImagineInterface

using JSON, Unitful
using MappedArrays, AxisArrays

import Base.show, Base.length, Base.size, Base.isempty

include("constants.jl")
include("unitfactory.jl")
include("imaginecommand.jl")
include("parse.jl")
include("convenience.jl")

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

#parse.jl
export parse_command,
        parse_commands

#convenience.jl
export getname,
        getdigital,
        getanalog

end #module
