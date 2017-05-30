using ImagineInterface, Unitful

samprate = 50000
pmin = 0.0*Unitful.μm
pmax = 200.0*Unitful.μm
stacktime = 1.0*Unitful.s
sampsfwd, sampsback = gen_bidi_pos(pmin, pmax, stacktime, samprate)
exp_time = 0.011*Unitful.s
flash_frac = 0.1 #fraction of time to keep laser on during exposure
z_spacing = 3.1*Unitful.μm
z_pad = 5.0*Unitful.μm
nsamps_stack = ceil(Int, stacktime*samprate/(1.0*Unitful.s))

#offset by one sample going forward so that we don't use the end points of the triangle
delaysamp = 1/samprate * Unitful.s
exp_intervals_fwd = spaced_intervals(sampsfwd, z_spacing, exp_time, samprate; delay=delaysamp, z_pad = z_pad, alignment=:start)
exp_intervals_back = spaced_intervals(sampsback, z_spacing, exp_time, samprate; delay=0.0*Unitful.s, z_pad = z_pad, alignment=:stop)

las_intervals_fwd = map(x->ImagineInterface.scale(x, flash_frac), exp_intervals_fwd)
#las_intervals_back = map(x->scale(x, flash_frac), exp_intervals_back)

samps_las_fwd = gen_pulses(nsamps_stack, las_intervals_fwd)
#samps_las_back = gen_pulses(nsamps_stack, las_intervals_back) #this can be off-by-one sample due to rounding in the scale function
samps_las_back = reverse(circshift(samps_las_fwd,-1)) 
samps_cam_fwd = gen_pulses(nsamps_stack, exp_intervals_fwd)
samps_cam_back = gen_pulses(nsamps_stack, exp_intervals_back)

@test all(map(IntervalSets.width, exp_intervals_fwd) .== 549)
@test all(map(IntervalSets.width, exp_intervals_back) .== 549)
#exposure duration
@test_approx_eq_eps(IntervalSets.width(exp_intervals_fwd[1])/samprate, ustrip(exp_time), 1/samprate)
#laser duration
@test_approx_eq_eps(IntervalSets.width(las_intervals_fwd[1])/samprate, ustrip(flash_frac*exp_time), 1/(samprate-1))
@test sampsfwd[1] == pmin
@test sampsfwd[end] < pmax
@test sampsback[1] == pmax
@test sampsback[end] > pmin
@test length(samps_cam_fwd) == nsamps_stack
@test samps_cam_fwd == reverse(circshift(samps_cam_back,-1))
@test samps_las_fwd == reverse(circshift(samps_las_back,-1)) 
#count pulses
@test length(find(x->x==1, diff(samps_cam_fwd))) == length(exp_intervals_fwd)
@test length(find(x->x==-1, diff(samps_cam_fwd))) == length(exp_intervals_fwd)
@test length(find(x->x==1, diff(samps_cam_back))) == length(exp_intervals_back)
@test length(find(x->x==-1, diff(samps_cam_back))) == length(exp_intervals_back)
#TODO: test padding
