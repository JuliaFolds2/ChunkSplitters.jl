"""
    index_chunks(collection;
        n::Union{Nothing, Integer}=nothing,
        size::Union{Nothing, Integer}=nothing,
        [split::Split=Consecutive(),]
        [minsize::Union{Nothing,Integer}=nothing,]
    )

Returns an iterator that splits the *indices* of `collection` into
`n`-many chunks (if `n` is given) or into chunks of a certain size (if `size` is given).
The returned iterator can be used to process chunks of *indices* of `collection` one after
another. If you want to process chunks of *elements* of `collection`,
check out `chunks(...)` instead.

The keyword arguments `n` and `size` are mutually exclusive.

### Keyword arguments (optional)

* `split` can be used to determine the splitting strategy,
  i.e. the distribution of the indices among chunks.
  If `split = Consecutive()` (default), chunks will hold consecutive indices and will hold
  approximately the same number of indices (as far as possible).
  If `split = RoundRobin()`, indices will be assigned to chunks in a round-robin fashion.

* `minsize` can be used to specify the minimum size of a chunk,
  and can be used in combination with the `n` keyword. If, for the given `n`, the chunks
  are smaller than `minsize`, the number of chunks will be decreased to ensure that
  each chunk is at least `minsize` long.

### Noteworthy

If you need a running chunk index you can combine `chunks` with `enumerate`. In particular,
`enumerate(index_chunks(...))` can be used in conjuction with `@threads`.

### Requirements

The type of the input `collection` must have at least `firstindex`, `lastindex`, and
`length` functions defined, as well as
`ChunkSplitters.is_chunkable(::typeof(collection)) = true`.
Out of the box, `AbstractArray`s and `Tuple`s are supported.

## Examples

```jldoctest
julia> using ChunkSplitters

julia> x = rand(7);

julia> collect(index_chunks(x; n=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:5
 6:7

julia> collect(enumerate(index_chunks(x; n=3)))
3-element Vector{Tuple{Int64, UnitRange{Int64}}}:
 (1, 1:3)
 (2, 4:5)
 (3, 6:7)

julia> collect(index_chunks(1:7; size=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:6
 7:7
```
"""
function index_chunks end

"""
    chunks(collection;
        n::Union{Nothing, Integer}=nothing,
        size::Union{Nothing, Integer}=nothing,
        [split::Split=Consecutive(),]
        [minsize::Union{Nothing,Integer}=nothing,]
    )

Returns an iterator that splits the *elements* of `collection` into
`n`-many chunks (if `n` is given) or into chunks of a certain size (if `size` is given).
To avoid copies, chunks will generally hold a view into the original collection.
The returned iterator can be used to process chunks of *elements* of `collection` one after
another. If you want to process chunks of *indices* of `collection`,
check out `index_chunks(...)` instead.

The keyword arguments `n` and `size` are mutually exclusive.

### Keyword arguments (optional)

* `split` can be used to determine the splitting strategy,
  i.e. the distribution of the indices among chunks.
  If `split = Consecutive()` (default), chunks will hold consecutive elements and will hold
  approximately the same number of elements (as far as possible).
  If `split = RoundRobin()`, elements will be assigned to chunks in a round-robin fashion.

* `minsize` can be used to specify the minimum size of a chunk,
  and can be used in combination with the `n` keyword. If, for the given `n`, the chunks
  are smaller than `minsize`, the number of chunks will be decreased to ensure that
  each chunk is at least `minsize` long.

### Noteworthy

If you need a running chunk index you can combine `chunks` with `enumerate`. In particular,
`enumerate(chunks(...))` can be used in conjuction with `@threads`.

### Requirements

In addition to the requirements for `index_chunks` (see docstring), the type of the input
`collection` must have an implementation of `view`, especially
`view(::typeof(collection), ::UnitRange)` and `view(::typeof(collection), ::StepRange)`.
Out of the box, `AbstractArray`s and `Tuple`s are supported.

## Examples

```jldoctest
julia> using ChunkSplitters

julia> x = [1.2, 3.4, 5.6, 7.8, 9.0];

julia> collect(chunks(x; n=3))
3-element Vector{SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}}:
 [1.2, 3.4]
 [5.6, 7.8]
 [9.0]

julia> collect(enumerate(chunks(x; n=3)))
3-element Vector{Tuple{Int64, SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}}}:
 (1, [1.2, 3.4])
 (2, [5.6, 7.8])
 (3, [9.0])

julia> collect(chunks(x; size=3))
2-element Vector{SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}}:
 [1.2, 3.4, 5.6]
 [7.8, 9.0]
```
"""
function chunks end

"""
    is_chunkable(::T)::Bool

Returns `true` if an object of type `T` can be chunked with `chunks`/`index_chunks`.
Overload this function for your custom types if that type is linearly indexable and
supports `firstindex`, `lastindex`, and `length`.
"""
function is_chunkable end

"""
Subtypes can be used to indicate a splitting strategy for `chunks` and `index_chunks`
(`split` keyword argument).
"""
abstract type Split end

"""
Chunks will hold consecutive indices/elements and approximately the same
number of them (as far as possible).
"""
struct Consecutive <: Split end

"""
Elements/indices will be assigned to chunks in a round-robin fashion.
"""
struct RoundRobin <: Split end
