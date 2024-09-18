"""
    chunk_indices(itr;
        n::Union{Nothing, Integer}, size::Union{Nothing, Integer}
        [, split::Union{SplitStrategy, Symbol}=BatchSplit()]
        [, minchunksize::Union{Nothing,Integer}]
    )

Returns an iterator that splits the *indices* of `itr` into
`n`-many chunks (if `n` is given) or into chunks of a certain size (if `size` is given).
The keyword arguments `n` and `size` are mutually exclusive.
The returned iterator can be used to process chunks of `itr` one after another or
in parallel (e.g. with `@threads`).

The optional argument `split` can be `BatchSplit()` (or `:batch`) (default) or
`ScatterSplit()` (or `:scatter`) and determines the distribution of the indices among the
chunks.
If `split == BatchSplit()`, chunk indices will be consecutive.
If `split == ScatterSplit()`, the range is scattered over `itr`.
Note that providing `split` in form of symbols (`:batch` or `:scatter`) can be slightly
less efficient.

The optional argument `minchunksize` can be used to specify the minimum size of a chunk,
and can be used in combination with the `n` keyword. If, for the given `n`, the chunks
are smaller than `minchunksize`, the number of chunks will be decreased to ensure that
each chunk is at least `minchunksize` long.

If you need a running chunk index you can combine `chunks` with `enumerate`. In particular,
`enumerate(chunk_indices(...))` can be used in conjuction with `@threads`.

The `itr` is usually some iterable, indexable object. The interface requires it to have
`firstindex`, `lastindex`, and `length` functions defined, as well as
`ChunkSplitters.is_chunkable(::typeof(itr)) = true`.

## Examples

```jldoctest
julia> using ChunkSplitters

julia> x = rand(7);

julia> collect(chunk_indices(x; n=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:5
 6:7

julia> collect(enumerate(chunk_indices(x; n=3)))
3-element Vector{Tuple{Int64, UnitRange{Int64}}}:
 (1, 1:3)
 (2, 4:5)
 (3, 6:7)

julia> collect(chunk_indices(1:7; size=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:6
 7:7
```

Note that `chunk_indices` also works just fine for `OffsetArray`s:

```jldoctest
julia> using ChunkSplitters, OffsetArrays

julia> x = OffsetArray(1:7, -1:5);

julia> collect(chunk_indices(x; n=3))
3-element Vector{UnitRange{Int64}}:
 -1:1
 2:3
 4:5

julia> collect(chunk_indices(x; n=3, split=ScatterSplit()))
3-element Vector{StepRange{Int64, Int64}}:
 -1:3:5
 0:3:3
 1:3:4
```

"""
function chunk_indices end

function chunk end

"""
    is_chunkable(::T) :: Bool

Determines if a of object of type `T` is capable of being `chunk`ed. Overload this function for your custom
types if that type is linearly indexable and supports `firstindex`, `lastindex`, and `length`.
"""
function is_chunkable end

# TODO: document
abstract type SplitStrategy end
struct BatchSplit <: SplitStrategy end
struct ScatterSplit <: SplitStrategy end
