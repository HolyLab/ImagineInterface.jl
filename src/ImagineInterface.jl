__precompile__()

module ImagineInterface

using JSON, Unitful
using MappedArrays, AxisArrays, IntervalSets
using Compat

import Base: convert, show, length, size, isempty, ==, append!, pop!, empty! #, scale

using Unitful: μm, s, V
@compat const HasVoltageUnits{T,U} = Quantity{T, typeof(0.0V).parameters[2], U}
@compat const HasTimeUnits{T,U} = Quantity{T, typeof(0.0s).parameters[2], U}
@compat const HasInverseTimeUnits{T,U} = Quantity{T, typeof(inv(0.0s)).parameters[2], U}
@compat const HasLengthUnits{T,U} = Quantity{T, typeof(0.0μm).parameters[2], U}

include("samplemapper.jl")
include("imaginecommand.jl")
include("constants.jl")
include("hardware.jl")
include("convenience.jl")
include("parse.jl")
include("sequence_analysis.jl")
include("write.jl")
include("stack.jl")

#imaginecommand.jl
export ImagineCommand,
        name,
        daq_channel,
        rig_name,
	rawtype,
        worldtype,
        samprate,
        intervals,
        interval_raw,
        interval_volts,
        interval_world,
	isdigital,
        sequences,
	sequence_names,
	sequence_lookup,
        mapper,
        decompress,
        replace!,
        replicate!

#constants.jl
export rigtemplate

#hardware.jl
export chip_size,
        max_framerate

#convenience.jl
export getname,
        getdigital,
        getanalog,
        getpositioners,
        getcameras,
        getlasers,
        getstimuli,
        finddigital,
        findanalog,
        findpositioners,
        findcameras,
        findlasers,
        findstimuli


#parse.jl
export parse_command,
        parse_commands

#sequence_analysis.jl
export find_pulse_starts,
        find_pulse_stops,
        count_pulses

#write.jl
export write_commands

#stack.jl
export gen_sweep,
        gen_sawtooth,
        gen_bidi_pos,
        spaced_intervals,
        gen_pulses,
        scale,
        gen_bidirectional_stack,
        gen_unidirectional_stack,
        gen_2d_timeseries

end #module
