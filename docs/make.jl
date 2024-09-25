using Documenter
using ChunkSplitters

makedocs(
    modules=[ChunkSplitters],
    checkdocs = :exports,
    sitename="ChunkSplitters.jl",
    pages = [
        "Home" => "index.md",
        "Getting started" => "gettingstarted.md",
        "Multithreading" => "multithreading.md",
        "Custom types" => "customtypes.md",
        "References" => "references.md",
    ]
)
deploydocs(
    repo = "github.com/JuliaFolds2/ChunkSplitters.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "main",
    versions = ["stable" => "v^", "v#.#" ],
    push_preview = true
)
