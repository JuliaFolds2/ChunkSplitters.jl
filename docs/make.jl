import Pkg
Pkg.add("Documenter")
using Documenter
using ChunkSplitters
push!(LOAD_PATH,"../src/")
makedocs(
    modules=[ChunkSplitters],
    sitename="ChunkSplitters.jl",
    pages = [
        "Home" => "index.md",
    ]
)
deploydocs(
    repo = "github.com/m3g/ChunkSplitters.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "main", 
    versions = ["stable" => "v^", "v#.#" ],
)
