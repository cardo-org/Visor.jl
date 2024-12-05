using Pkg
using Coverage

try
    Pkg.test("Visor"; coverage=true)
catch e
    @error "coverage: $e"
finally
    coverage = process_folder()
    LCOV.writefile("lcov.info", coverage)
end

for dir in ["src", "test"]
    foreach(rm, filter(endswith(".cov"), readdir(dir; join=true)))
end
