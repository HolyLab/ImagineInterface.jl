plotlyjs()
#gr()
#pyplot()

get_times{T}(v::AxisArray{T}) = axisvalues(v[Axis{:time}])[1]

#This version plots groups in separate windows
#function plot(coms::Vector{ImagineCommand}; sampmap=:world)
#    used_idxs = find(x->length(x) > 0, coms)
#    used_coms = coms[used_idxs]
#    nsamps = length(used_coms[1])
#    @assert all(map(length, used_coms).==nsamps)
#    #TODO: bug report because plotting of matrices with UnitfulPlots isn't working
#    p = []
#    for (comgroup, groupname) in zip((getpositioners(used_coms), getcameras(used_coms), getlasers(used_coms), getstimuli(used_coms)), ("Positioners","Cameras", "Lasers", "Stimuli"))  #assumes each as the same world units within-group
#        ncoms = length(comgroup)
#        if ncoms == 0
#            continue
#        end
#        times = [get_times(decompress(comgroup[1]))...]
#        for i = 1:ncoms
#            cursamps = decompress(comgroup[i])
#            if eltype(cursamps) == Bool #work around another plotting bug
#                cursamps = map(UInt8, cursamps)
#            end
#            if i == 1
#                p = plot(times, cursamps, lab=name(comgroup[i]), title=groupname, reuse=false, show=true)
#            else
#                plot!(p, times, cursamps, lab=name(comgroup[i]), show=true)
#            end
#        end
#    end
#end

#This plots all signals in a single plot via subplots
function plot(coms::Vector{ImagineCommand}; sampmap=:world)
    used_idxs = find(x->length(x) > 0, coms)
    used_coms = coms[used_idxs]
    nsamps = length(used_coms[1])
    @assert all(map(length, used_coms).==nsamps)
    #TODO: bug report because plotting of matrices with UnitfulPlots isn't working
    plts = []
    nuc = length(used_coms)
    ct = 1
    clrs = Colors.distinguishable_colors(nuc)
    for (comgroup, groupname) in zip((getpositioners(used_coms), getcameras(used_coms), getlasers(used_coms), getstimuli(used_coms)), ("Positioners","Cameras", "Lasers", "Stimuli"))  #assumes each as the same world units within-group
        ncoms = length(comgroup)
        if ncoms == 0
            continue
        end
        times = [get_times(decompress(comgroup[1]))...]
        for i = 1:ncoms
            cursamps = decompress(comgroup[i])
            if eltype(cursamps) == Bool #work around another plotting bug
                cursamps = map(UInt8, cursamps)
            end
            #push!(plts, plot(times, cursamps, lab=name(comgroup[i]), title=groupname, reuse=false, show=false))
            push!(plts, plot(times, cursamps, lab=name(comgroup[i]), color = clrs[ct], show=false))
            ct+=1
        end
    end
    xts = Array(Any, 1, nuc)
    hts = fill(0.1, nuc)
    fill!(xts, nothing)
    xts[end] = :auto
    yts = :auto
    hts[findpositioners(used_coms)] = 0.4
    output = plot(plts..., layout = grid(nuc,1,heights=hts), link=:x, xticks=xts, yticks=yts, reuse=false, show=true)
    return output
end

function plot(com::ImagineCommand; sampmap=:world)
    samps = decompress(com)
    times = get_times(samps)
    if eltype(samps) == Bool #work around another plotting bug
        samps = map(UInt8, samps)
    end

    plot(times, samps, show=true, reuse=false)
end
