using Visor
using Documenter
using Weave

const EXAMPLES_DIR = "examples"

weaved_files = ["stop_process.jl"]

for fn in weaved_files
    weave(joinpath(EXAMPLES_DIR, fn); doctype="github", out_path=joinpath("docs", "src"))
end

DocMeta.setdocmeta!(Visor, :DocTestSetup, :(using Visor); recursive=true)

makedocs(;
    modules=[Visor],
    authors="Attilio Donà",
    repo="https://github.com/cardo-org/Visor.jl/blob/{commit}{path}#{line}",
    sitename="Visor.jl",
    doctest=true,
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://cardo-org.github.io/Visor.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Process" => "process.md",
        "Supervisor" => "supervisor.md",
        "Messages" => "messages.md",
        "Shutting down" => "stop_process.md",
        "No exception handler available" => "no_handler_available.md",
    ],
)

deploydocs(; repo="github.com/cardo-org/Visor.jl", devbranch="main")
