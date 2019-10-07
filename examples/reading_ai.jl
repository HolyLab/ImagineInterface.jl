using ImagineInterface, ImagineFormat

ais = parse_ai("t.ai")

# Grab one particular signal
piezo = getname(ais, "axial piezo monitor")
# piezo is just a reference, the data are loaded on-demand. This lets you
# work with long recordings.
# Extract values in physical units, which here represent the position
data = get_samples(piezo)
# We can also get them in their original voltage units...
datav = get_samples(piezo; sampmap=:volts)
# ...or even in the raw Int16 format
dataraw = get_samples(piezo; sampmap=:raw)

# Let's display this signal
using ImaginePlots   # you have to install this and its dependencies manually
using Plots
plot(piezo)

stimuli = getname(ais, "stimuli")
# This channel is just noise, but if it had had a sequence of TTL pulses
# this would give us a list of scan #s at which the pulses start
stimstarts = find_pulse_starts(stimuli; sampmap=:volts)
