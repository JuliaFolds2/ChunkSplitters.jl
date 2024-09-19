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
        "Minimal interface" => "minimalinterface.md",
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
