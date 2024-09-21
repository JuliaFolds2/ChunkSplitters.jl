# Custom types

This page is about how to make custom types compatible with `chunk_indices` and `chunk`.

## `chunk_indices`

First of all, the custom type must define `ChunkSplitters.is_chunkable(::CustomType) = true`. Moreover it needs to implement at least the functions `Base.firstindex`, `Base.lastindex`, and `Base.length`.

For example:

```jldoctest
julia> using ChunkSplitters

julia> struct CustomType end

julia> ChunkSplitters.is_chunkable(::CustomType) = true

julia> Base.firstindex(::CustomType) = 1

julia> Base.lastindex(::CustomType) = 7

julia> Base.length(::CustomType) = 7

julia> x = CustomType()
CustomType()

julia> collect(chunk_indices(x; n=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:5
 6:7

julia> collect(chunk_indices(x; n=3, split=RoundRobin()))
3-element Vector{StepRange{Int64, Int64}}:
 1:3:7
 2:3:5
 3:3:6
```

## `chunk`

In addition to the requirements above for `chunk_indices`, the type must have an implementation of `view`, especially `view(::CustomType, ::UnitRange)` and `view(::CustomType, ::StepRange)`.
