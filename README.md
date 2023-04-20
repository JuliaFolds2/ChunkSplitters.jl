# ChunkSplitters.jl

ChunkSplitters facilitate the splitting of the workload of parallel
jobs independently on the number of threads that are effectively available. It allows for a finer, lower level, control
of the load of each task.

The way chunks are indexed is also recommended for guaranteeing that the workload if completely thread safe 
(without the use `threadid()` - see [here](https://juliafolds.github.io/FLoops.jl/dev/explanation/faq/#faq-state-threadid)). 

A discussion on the possible use of `ChunkSplitters` to improve load-balancing is available [here](https://m3g.github.io/JuliaNotes.jl/stable/loadbalancing/).

## Installation

Install with:
```julia
julia> import Pkg; Pkg.add("ChunkSplitters")
```

## Documentation

Go to: [https://m3g.github.io/ChunkSplitters.jl](https://m3g.github.io/ChunkSplitters.jl)
