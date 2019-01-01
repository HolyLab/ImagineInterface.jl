using Pkg
pkgs = ["UnitAliases", "ImagineHardware"]

for p in pkgs
    try
        Pkg.installed(p)
    catch
        Pkg.add(PackageSpec(url="https://github.com/HolyLab/"*p*".jl.git"))
    end
end
