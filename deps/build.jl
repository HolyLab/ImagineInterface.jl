pkgs = ["UnitAliases"]

for p in pkgs
    try
        Pkg.installed(p)
    catch
        Pkg.clone("https://github.com/HolyLab/"*p*".jl.git")
    end
end
