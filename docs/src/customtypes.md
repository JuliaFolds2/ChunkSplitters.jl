# Custom types

This page is about how to make custom types compatible with `index_chunks` and `chunks`.

## `index_chunks`

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

julia> collect(index_chunks(x; n=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:5
 6:7

julia> collect(index_chunks(x; n=3, split=RoundRobin()))
3-element Vector{StepRange{Int64, Int64}}:
 1:3:7
 2:3:5
 3:3:6
```

## `chunks`

In addition to the requirements above for `index_chunks`, the type must have an implementation of `view`, especially `view(::CustomType, ::UnitRange)` and `view(::CustomType, ::StepRange)`.
