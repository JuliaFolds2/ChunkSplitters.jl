# ChunkSplitters.jl

[ChunkSplitters.jl](https://github.com/JuliaFolds2/ChunkSplitters.jl) makes it easy to split the elements or indexes of a collection into chunks:

```julia-repl
julia> using ChunkSplitters

julia> x = [1.2, 3.4, 5.6, 7.8, 9.0];

julia> collect(chunk(x; n=3))
3-element Vector{SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}}:
 [1.2, 3.4]
 [5.6, 7.8]
 [9.0]

julia> collect(chunk_indices(x; n=3))
3-element Vector{UnitRange{Int64}}:
 1:2
 3:4
 5:5
```

This can be useful in many areas, one of which is multithreading:

```julia
using ChunkSplitters: chunk
using Base.Threads: nthreads, @spawn

x = rand(10^8);

function parallel_sum(x; ntasks=nthreads())
    tasks = map(chunk(x; n=ntasks)) do chunk_of_x
        @spawn sum(chunk_of_x)
    end
    return sum(fetch, tasks)
end

parallel_sum(x) ≈ sum(x) # true
```

Here, we spawn a task per chunk, each computing a partial sum. Note that for `ntasks < nthreads()` this allows us to effectively control the number of utilised Julia threads.

Working with chunks and their respective indices also improves thread-safety compared to a naive parallelisation approach based on `threadid()` (see [PSA: Thread-local state is no longer recommended](https://julialang.org/blog/2023/07/PSA-dont-use-threadid/)). 

## Installation

Install with:
```julia-repl
julia> import Pkg; Pkg.add("ChunkSplitters")
```