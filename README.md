# ImagineInterface
[![Build Status](https://travis-ci.com/HolyLab/ImagineInterface.jl.svg?branch=master)](https://travis-ci.org/HolyLab/ImagineInterface)
[![Build status](https://ci.appveyor.com/api/projects/status/obywii010u9stx5f/branch/master?svg=true)](https://ci.appveyor.com/project/Cody-G/imagineinterface/branch/master)
[![codecov](https://codecov.io/gh/HolyLab/ImagineInterface.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/HolyLab/ImagineInterface.jl)

**Note:** Julia 0.6 users should checkout the `julia0.6` branch; `master` works on Julia 0.7/1.x only.

Read and write Imagine analog and digital recordings and commands.

Consider using this package if your OCPI experiment requires more flexibility in design than can be provided from the Imagine GUI.  Any analog or digital input or output signal carried by the microscope's DAQ board can be modified with this package.  Currently we can't run experiments directly from this package (but work has started on that with https://github.com/HolyLab/Imagine.jl).  For now instead of running experiments directly you can use this package to save a file describing your imaging experiment (JSON format) that can be loaded and run by the [Imagine](https://github.com/HolyLab/Imagine) GUI.

See the examples folder for usage demos, especially the [heavily commented workflow script](https://github.com/HolyLab/ImagineInterface/blob/master/examples/workflow.jl),
the [`.ai` file reading example](https://github.com/HolyLab/ImagineInterface/blob/master/examples/reading_ai.jl),
and the [ijulia notebook](https://github.com/HolyLab/ImagineInterface/blob/master/examples/presentation.ipynb).

**Note:** Plotting capabilities have moved to the [ImaginePlots.jl](https://github.com/HolyLab/ImaginePlots) package.
