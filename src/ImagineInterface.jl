__precompile__()

module ImagineInterface

using JSON, Unitful, UnitAliases, Random, Mmap
using MappedArrays, IntervalSets, DataStructures, DSP
using ImagineFormat, ImagineHardware
import ImagineHardware:samprate
using AxisArrays
const axes = Base.axes

import Base: convert, show, length, size, isempty, ==, append!, pop!, empty!, replace!#, scale

using Unitful: μm, s, Hz, V

include("metadata_constants.jl")
#Load hardware parameters for all rigs
rig_dir = joinpath(dirname(@__DIR__), "rigs")
for rig_file in readdir(rig_dir)
    include(joinpath(rig_dir, rig_file))
end
include("samplemapper.jl")
include("imaginesignal.jl")
include("hardware_templates.jl")
include("convenience.jl")
include("parse.jl")
include("sequence_analysis.jl")
include("validate_group.jl")
include("window_validate.jl")
include("validate_single.jl")
include("write.jl")
include("stack.jl")

#metadata_constants.jl
export chip_size,
        max_framerate,
        max_roi

#imaginecommand.jl
export RepeatedValue,
        RLEVector,
        full_length,
        ImagineSignal,
        name,
        rename!,
        duration,
        daq_channel,
        rig_name,
	rawtype,
        worldtype,
        samprate,
        intervals,
        interval_raw,
        interval_volts,
        interval_world,
        sequences,
	sequence_names,
	sequence_lookup,
        mapper,
        get_samples,
        add_sequence!,
        replace!,
        replicate!

#hardware_templates.jl
export rigtemplate

#convenience.jl
export  isfree,
        isdigital,
        isanalog,
        isoutput,
        isinput,
        ispos,
        isposmonitor,
        iscam,
        iscammonitor,
        islas,
        isstim,
        getname,
        getdigital,
        getanalog,
        getinputs,
        getoutputs,
        getfree,
        getfixed,
        getpositioners,
        getpositionermonitors,
        getcameras,
        getcameramonitors,
        getlasers,
        getstimuli,
        getgalvos,
        getgalvomonitors,
        hasmonitor,
        hasactuator,
        monitor_name,
        actuator_name,
        finddigital,
        findanalog,
        findinputs,
        findoutputs,
        findfree,
        findfixed,
        findpositioners,
        findcameras,
        findlasers,
        findstimuli

#parse.jl
export parse_command,
        parse_commands,
        parse_ai,
        parse_di,
        load_signals

#sequence_analysis.jl
export find_pulse_starts,
        find_pulse_stops,
        count_pulses

#validate_singles.jl
export validate_all

#write.jl
export write_commands

#stack.jl
export  apply_lp,
        gen_sweep,
        gen_sawtooth,
        gen_bidi_pos,
        spaced_intervals,
        gen_pulses,
        scale,
        gen_bidirectional_stack,
        gen_unidirectional_stack,
        gen_stepped_stack,
        gen_2d_timeseries
#deprecations
@deprecate ImagineCommand ImagineSignal
@deprecate decompress(args...;kwargs...) get_samples(args...;kwargs...)

end #module
