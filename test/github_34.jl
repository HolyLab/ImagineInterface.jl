using Base.Test
using ImagineInterface
import Unitful: μm, s

sample_rate=10000s^-1
ocpi2 = rigtemplate("ocpi-2"; sample_rate = sample_rate)
pmin=100.0μm; pmax=180.0μm
z_spacing = 9.99μm #The space between slices in the z-stack.
stk_rate=5s^-1
reset_time = 0.06s
z_pad = 0.0μm
t_fullstk=1/stk_rate
t_imstk=t_fullstk-reset_time
n_stk_frames=round(Int,(pmax-pmin-2*z_pad)/z_spacing)
frac_realscan=z_spacing*n_stk_frames/(pmax-pmin) # fraction of "meaningful scan" in the forward scanning phase
exp_time=(t_imstk*frac_realscan)/n_stk_frames*0.90
flash_frac=2
stk = gen_unidirectional_stack(pmin, pmax, z_spacing, t_imstk, reset_time, exp_time, sample_rate, flash_frac; z_pad = z_pad)
@test size(stk["positioner"]) == size(stk["camera"]) == @show size(stk["laser"])
