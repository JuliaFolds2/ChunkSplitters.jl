# Minimal interface

This page is about how to make custom types compatible with `chunk_indices` and `chunk`.

## `chunk_indices`

First of all, the type must define `ChunkSplitters.is_chunkable(::YourType) = true`. Moreover it needs to implement at least the functions `Base.firstindex`, `Base.lastindex`, and `Base.length`.

For example:

```jldoctest
julia> using ChunkSplitters

julia> struct MinimalInterface end

julia> ChunkSplitters.is_chunkable(::MinimalInterface) = true

julia> Base.firstindex(::MinimalInterface) = 1

julia> Base.lastindex(::MinimalInterface) = 7

julia> Base.length(::MinimalInterface) = 7

julia> x = MinimalInterface()
MinimalInterface()

julia> collect(chunk_indices(x; n=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:5
 6:7

julia> collect(chunk_indices(x; n=3, split=ScatterSplit()))
3-element Vector{StepRange{Int64, Int64}}:
 1:3:7
 2:3:5
 3:3:6
```

## `chunk`

In addition to the requirements above for `chunk_indices`, the type must have an implementation of `view`, especially `view(::YourType, ::UnitRange)` and `view(::YourType, ::StepRange)`.
