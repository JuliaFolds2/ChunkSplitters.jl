# References

## Index

```@index
Pages   = ["references.md"]
Order   = [:function, :type]
```

## ChunkSplitters
```@autodocs
Modules = [ChunkSplitters]
Pages   = ["ChunkSplitters.jl"]
```

## Interface requirements 

!!! compat
    Support for this minimal interface requires version 2.2.0.

For the `chunks` and `getchunk` functions to work, the input value must
have implemented only three methods extended from Julia `Base`: `firstindex`,
`lastindex`, and `length`.

For example:
```jldoctest
julia> using ChunkSplitters

julia> struct MinimalInterface end

julia> Base.firstindex(::MinimalInterface) = 1

julia> Base.lastindex(::MinimalInterface) = 7

julia> Base.length(::MinimalInterface) = 7

julia> x = MinimalInterface()
MinimalInterface()

julia> collect(chunks(x; n=3))
3-element Vector{StepRange{Int64, Int64}}:
 1:1:3
 4:1:5
 6:1:7

julia> collect(chunks(x; n=3, split=:scatter))
3-element Vector{StepRange{Int64, Int64}}:
 1:3:7
 2:3:5
 3:3:6
```