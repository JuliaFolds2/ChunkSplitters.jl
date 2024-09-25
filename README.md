[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaFolds2.github.io/ChunkSplitters.jl/stable)
[![Stable](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaFolds2.github.io/ChunkSplitters.jl/dev)
[![Tests](https://img.shields.io/badge/build-passing-green)](https://github.com/JuliaFolds2/ChunkSplitters.jl/actions)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

# ChunkSplitters.jl

## Installation

Install with:
```julia
julia> import Pkg; Pkg.add("ChunkSplitters")
```

## Documentation

Go to: [https://JuliaFolds2.github.io/ChunkSplitters.jl](https://JuliaFolds2.github.io/ChunkSplitters.jl)

## Overview

[ChunkSplitters.jl](https://github.com/JuliaFolds2/ChunkSplitters.jl) makes it easy to split the elements or indices of a collection into chunks:

```julia-repl
julia> using ChunkSplitters

julia> x = [1.2, 3.4, 5.6, 7.8, 9.1, 10.11, 11.12];

julia> for inds in index_chunks(x; n=3)
           @show inds
       end
inds = 1:3
inds = 4:5
inds = 6:7

julia> for c in chunks(x; n=3)
           @show c
       end
c = [1.2, 3.4, 5.6]
c = [7.8, 9.1]
c = [10.11, 11.12]
```

This can be useful in many areas, one of which is multithreading, where we can use chunking to control the number of spawned tasks:

```julia
function parallel_sum(x; ntasks=nthreads())
    tasks = map(chunks(x; n=ntasks)) do chunk_of_x
        @spawn sum(chunk_of_x)
    end
    return sum(fetch, tasks)
end
```

Working with chunks and their respective indices also improves thread-safety compared to a naive parallelisation approach based on `threadid()` (see [PSA: Thread-local state is no longer recommended](https://julialang.org/blog/2023/07/PSA-dont-use-threadid/)). 
