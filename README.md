[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://m3g.github.io/ChunkSplitters.jl/stable)
[![Stable](https://img.shields.io/badge/docs-dev-blue.svg)](https://m3g.github.io/ChunkSplitters.jl/dev)
[![Tests](https://img.shields.io/badge/build-passing-green)](https://github.com/m3g/ChunkSplitters.jl/actions)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

# ChunkSplitters.jl

[ChunkSplitters.jl](https://github.com/m3g/ChunkSplitters.jl) facilitates the splitting of a given list of work items (of potentially uneven workload) into chunks that can be readily used for parallel processing. Operations on these chunks can, for example, be parallelized with Julia's multithreading tools, where separate tasks are created for each chunk. Compared to naive parallelization, ChunkSplitters.jl therefore effectively allows for more fine-grained control of the composition and workload of each parallel task.

Working with chunks and their respective indices also improves thread-safety compared to a naive approach based on `threadid()` indexing (see [PSA: Thread-local state is no longer recommended](https://julialang.org/blog/2023/07/PSA-dont-use-threadid/)). 

## Installation

Install with:
```julia
julia> import Pkg; Pkg.add("ChunkSplitters")
```

## Documentation

Go to: [https://m3g.github.io/ChunkSplitters.jl](https://m3g.github.io/ChunkSplitters.jl)
