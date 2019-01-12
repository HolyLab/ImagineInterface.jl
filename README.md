# ImagineInterface
[![Build Status](https://travis-ci.com/HolyLab/ImagineInterface.svg?branch=master)](https://travis-ci.org/HolyLab/ImagineInterface)
[![Build status](https://ci.appveyor.com/api/projects/status/obywii010u9stx5f/branch/master?svg=true)](https://ci.appveyor.com/project/Cody-G/imagineinterface/branch/master)
[![codecov](https://codecov.io/gh/HolyLab/ImagineInterface/branch/master/graph/badge.svg)](https://codecov.io/gh/HolyLab/ImagineInterface)

Read and write Imagine analog and digital recordings and commands.

Consider using this package if your OCPI experiment requires more flexibility in design than can be provided from the Imagine GUI.  Any analog or digital input or output signal carried by the microscope's DAQ board can be modified with this package.  Currently we can't run experiments directly from this package (but work has started on that with https://github.com/HolyLab/Imagine.jl).  For now instead of running experiments directly you can save a file describing your imaging experiment in a JSON (".json") file that can be loaded and run by the [Imagine](https://github.com/HolyLab/Imagine) GUI.

See the examples folder for usage demos, especially the [heavily commented workflow script](https://github.com/HolyLab/ImagineInterface/blob/master/examples/workflow.jl) and the [ijulia notebook](https://github.com/HolyLab/ImagineInterface/blob/master/examples/presentation.ipynb).

A work-in-progress, reading and writing of command files is implemented.  As we work on this package we may decide it's worthwhile to change some of Imagine's naming conventions as well as what/where metadata should be recorded.

**Note:** Plotting capabilities have moved to the [ImaginePlots](https://github.com/HolyLab/ImaginePlots) package.
