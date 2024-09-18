module ChunkSplitters

using TestItems: @testitem
import Base: iterate, length, eltype
import Base: enumerate, firstindex, lastindex, getindex, eachindex

export chunks, getchunk, SplitStrategy, BatchSplit, ScatterSplit
if VERSION >= v"1.11.0-DEV.469"
    eval(Meta.parse("public is_chunkable, Chunk"))
end

"""
    chunks(itr;
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
`enumerate(chunks(...))` can be used in conjuction with `@threads`.

The `itr` is usually some iterable, indexable object. The interface requires it to have
`firstindex`, `lastindex`, and `length` functions defined, as well as
`ChunkSplitters.is_chunkable(::typeof(itr)) = true`.

## Examples

```jldoctest
julia> using ChunkSplitters

julia> x = rand(7);

julia> collect(chunks(x; n=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:5
 6:7

julia> collect(enumerate(chunks(x; n=3)))
3-element Vector{Tuple{Int64, UnitRange{Int64}}}:
 (1, 1:3)
 (2, 4:5)
 (3, 6:7)

julia> collect(chunks(1:7; size=3))
3-element Vector{UnitRange{Int64}}:
 1:3
 4:6
 7:7
```

Note that `chunks` also works just fine for `OffsetArray`s:

```jldoctest
julia> using ChunkSplitters, OffsetArrays

julia> x = OffsetArray(1:7, -1:5);

julia> collect(chunks(x; n=3))
3-element Vector{UnitRange{Int64}}:
 -1:1
 2:3
 4:5

julia> collect(chunks(x; n=3, split=ScatterSplit()))
3-element Vector{StepRange{Int64, Int64}}:
 -1:3:5
 0:3:3
 1:3:4
```

"""
function chunks end

"""
    is_chunkable(::T) :: Bool

Determines if a of object of type `T` is capable of being `chunk`ed. Overload this function for your custom
types if that type is linearly indexable and supports `firstindex`, `lastindex`, and `length`.
"""
is_chunkable(::Any) = false
is_chunkable(::AbstractArray) = true
is_chunkable(::Tuple) = true


# Current chunks split types
abstract type SplitStrategy end
struct BatchSplit <: SplitStrategy end
struct ScatterSplit <: SplitStrategy end

const split_types = (:batch, :scatter, BatchSplit(), ScatterSplit())

# User defined constraint
abstract type Constraint end
struct FixedCount <: Constraint end
struct FixedSize <: Constraint end

# Structure that carries the chunks data
struct Chunk{T,C<:Constraint,S<:SplitStrategy}
    itr::T
    n::Int
    size::Int
end
is_chunkable(::Chunk) = true

@testitem "Chunk parametric types order" begin
    # Try not to break the order of the type parameters. Chunk is
    # not part of the interface (currently), so its being used
    # by OhMyThreads, so we probably should make it documented
    using ChunkSplitters: Chunk, FixedCount, BatchSplit
    @test Chunk{typeof(1:7), FixedCount, BatchSplit}(1:7, 3, 0) ==
        Chunk{UnitRange{Int64}, FixedCount, BatchSplit}(1:7, 3, 0)
    @test_throws TypeError Chunk{typeof(1:7), BatchSplit, FixedCount}(1:7, 3, 0)
end

# Constructor for the chunks
function chunks(itr;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::Union{Symbol, SplitStrategy}=BatchSplit(),
    minchunksize::Union{Nothing,Integer}=nothing,
)
    if split isa BatchSplit || split == :batch
        chunks(itr, BatchSplit; n, size, minchunksize)
    elseif split isa ScatterSplit || split == :scatter
        chunks(itr, ScatterSplit; n, size, minchunksize)
    else
        split_err()
    end
end

_set_minchunksize(minchunksize::Nothing) = 1
function _set_minchunksize(minchunksize::Integer)
    minchunksize < 1 && throw(ArgumentError("minchunksize must be >= 1"))
    return minchunksize
end
function _set_C_n_size(itr, n::Nothing, size::Integer, minchunksize)
    !isnothing(minchunksize) && mutually_exclusive_err("size","minchunksize")
    size < 1 && throw(ArgumentError("size must be >= 1"))
    return FixedSize, 0, size
end
function _set_C_n_size(itr, n::Integer, size::Nothing, minchunksize)
    n < 1 && throw(ArgumentError("n must be >= 1"))
    mcs = _set_minchunksize(minchunksize)
    nmax = min(length(itr) ÷ mcs, n)
    FixedCount, nmax, 0
end

function chunks(itr, split::Type{<:SplitStrategy};
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    minchunksize::Union{Nothing,Integer}=nothing,
)
    is_chunkable(itr) || not_chunkable_err(itr)
    isnothing(n) && isnothing(size) && missing_input_err()
    !isnothing(size) && !isnothing(n) && mutually_exclusive_err("size","n")
    C, n, size = _set_C_n_size(itr, n, size, minchunksize)
    return Chunk{typeof(itr),C,split}(itr, n, size)
end

function missing_input_err()
    throw(ArgumentError("You must either indicate the desired number of chunks (n) or the target size of a chunk (size)."))
end
function mutually_exclusive_err(var1,var2)
    throw(ArgumentError("$var1 and $var2 are mutually exclusive."))
end
function not_chunkable_err(::T) where {T}
    throw(ArgumentError("Arguments of type $T are not compatible with chunks, either implement a custom chunks method for your type, or if it is compatible with the chunks minimal interface (see https://juliafolds2.github.io/ChunkSplitters.jl/dev/)"))
end
@noinline split_err() = throw(ArgumentError("split must be one of $split_types"))

length(c::Chunk{T,FixedCount,S}) where {T,S} = c.n
length(c::Chunk{T,FixedSize,S}) where {T,S} = cld(length(c.itr), max(1, c.size))
eltype(::Chunk{T,C,BatchSplit}) where {T,C} = UnitRange{Int}
eltype(::Chunk{T,C,ScatterSplit}) where {T,C} = StepRange{Int,Int}

firstindex(::Chunk) = 1
lastindex(c::Chunk) = length(c)
getindex(c::Chunk, i::Int) = getchunk(c, i)

#
# Iteration of the chunks
#
function iterate(c::Chunk, state=nothing)
    length(c.itr) == 0 && return nothing
    if isnothing(state)
        chunk = getchunk(c, 1)
        return (chunk, 1)
    elseif state < length(c)
        chunk = getchunk(c, state + 1)
        return (chunk, state + 1)
    end
    return nothing
end

#
# Iteration over chunks enumeration: usually enumerate is not compatible
# with `@threads`, because of the lack of the general definition of
# `firstindex`, `lastindex`, and `getindex` for `Base.Iterators.Enumerate{<:Any}`. Thus,
# to avoid using the internal `.itr` property of `Enumerate`, we redefine
# the `iterate` method for `ChunkSplitters.Enumerate{<:Chunk}`.
#
struct Enumerate{I<:Chunk}
    itr::I
end
enumerate(c::Chunk) = Enumerate(c)

function iterate(ec::Enumerate{<:Chunk}, state=nothing)
    length(ec.itr.itr) == 0 && return nothing
    if isnothing(state)
        chunk = getchunk(ec.itr, 1)
        return ((1, chunk), 1)
    elseif state < length(ec.itr)
        state = state + 1
        chunk = getchunk(ec.itr, state)
        return ((state, chunk), state)
    end
    return nothing
end
eltype(::Enumerate{<:Chunk{T,C,BatchSplit}}) where {T,C} = Tuple{Int,UnitRange{Int}}
eltype(::Enumerate{<:Chunk{T,C,ScatterSplit}}) where {T,C} = Tuple{Int,StepRange{Int,Int}}

# These methods are required for threading over enumerate(chunks(...))
firstindex(::Enumerate{<:Chunk}) = 1
lastindex(ec::Enumerate{<:Chunk}) = lastindex(ec.itr)
getindex(ec::Enumerate{<:Chunk}, i::Int) = (i, getchunk(ec.itr, i))
length(ec::Enumerate{<:Chunk}) = length(ec.itr)
eachindex(ec::Enumerate{<:Chunk}) = Base.OneTo(length(ec.itr))

@testitem "enumerate chunks" begin
    using ChunkSplitters: chunks
    using Base.Threads: @spawn, @threads, nthreads
    x = rand(100)
    s = zeros(nthreads())
    @threads for (ichunk, range) in enumerate(chunks(x; n=nthreads()))
        for i in range
            s[ichunk] += x[i]
        end
    end
    @test sum(s) ≈ sum(x)
    s = zeros(nthreads())
    @sync for (ichunk, range) in enumerate(chunks(x; n=nthreads()))
        @spawn begin
            for i in range
                s[ichunk] += x[i]
            end
        end
    end
    @test sum(s) ≈ sum(x)
    @test collect(enumerate(chunks(1:10; n=2))) == [(1, 1:5), (2, 6:10)]
    @test collect(enumerate(chunks(rand(7); n=3))) ==
          Tuple{Int64,UnitRange{Int64}}[(1, 1:3), (2, 4:5), (3, 6:7)]
    @test eltype(enumerate(chunks(rand(7); n=3))) == Tuple{Int64,UnitRange{Int64}}
    @test eltype(enumerate(chunks(rand(7); n=3, split=:scatter))) == Tuple{Int64,StepRange{Int64,Int64}}
    @test eachindex(enumerate(chunks(1:10; n=3))) == 1:3
    @test eachindex(enumerate(chunks(1:10; size=2))) == 1:5
end

#
# This is the lower level function that receives `ichunk` as a parameter
#
"""
    getchunk(itr, i::Integer; n::Union{Nothing,Integer}, size::Union{Nothing,Integer}[, split::Union{Symbol, SplitStrategy}=ScatterSplit()])

Returns the range of indices of `itr` that corresponds to the `i`-th chunk.
How the chunks are formed depends on the keyword arguments. See `chunks` for more information.

## Example

If we have an array of 7 elements, and the work on the elements is divided
into 3 chunks, we have (using the default `split = BatchSplit()` option):

```jldoctest
julia> using ChunkSplitters

julia> x = rand(7);

julia> getchunk(x, 1; n=3)
1:3

julia> getchunk(x, 2; n=3)
4:5

julia> getchunk(x, 3; n=3)
6:7
```

And using `split = ScatterSplit()`, we have:

```jldoctest
julia> using ChunkSplitters

julia> x = rand(7);

julia> getchunk(x, 1; n=3, split=ScatterSplit())
1:3:7

julia> getchunk(x, 2; n=3, split=ScatterSplit())
2:3:5

julia> getchunk(x, 3; n=3, split=ScatterSplit())
3:3:6
```

We can also choose the chunk size rather than the number of chunks:

```jldoctest
julia> using ChunkSplitters

julia> x = rand(7);

julia> getchunk(x, 1; size=3)
1:3

julia> getchunk(x, 2; size=3)
4:6

julia> getchunk(x, 3; size=3)
7:7
```


"""
function getchunk(itr, ichunk::Integer;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::Union{Symbol, SplitStrategy}=BatchSplit()
)
    if split isa BatchSplit || split == :batch
        getchunk(itr, ichunk, BatchSplit; n=n, size=size)
    elseif split isa ScatterSplit || split == :scatter
        getchunk(itr, ichunk, ScatterSplit; n=n, size=size)
    else
        split_err()
    end
end

_empty_itr(::Type{BatchSplit}) = 0:-1
_empty_itr(::Type{ScatterSplit}) = 0:1:-1

function getchunk(itr, ichunk::Integer, split::Type{<:SplitStrategy};
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
)
    length(itr) == 0 && return _empty_itr(split)
    !isnothing(n) || !isnothing(size) || missing_input_err()
    !isnothing(n) && !isnothing(size) && mutually_exclusive_err()
    if !isnothing(n)
        C = FixedCount
        n >= 1 || throw(ArgumentError("n must be >= 1"))
    else
        C = FixedSize
        size >= 1 || throw(ArgumentError("size must be >= 1"))
        l = length(itr)
        size = min(l, size) # handle size>length(itr)
        n = cld(l, size)
    end
    n_input = isnothing(n) ? 0 : n
    ichunk <= n_input || throw(ArgumentError("index must be less or equal to number of chunks ($n)"))
    ichunk <= length(itr) || throw(ArgumentError("ichunk must be less or equal to the length of `itr`"))
    is_chunkable(itr) || not_chunkable_err(itr)
    return _getchunk(C, split, itr, ichunk; n, size)
end

# convenient pass-forward methods
getchunk(c::Chunk{T,FixedCount,S}, ichunk::Integer) where {T,S} =
    getchunk(c.itr, ichunk, S; n=c.n, size=nothing)
getchunk(c::Chunk{T,FixedSize,S}, ichunk::Integer) where {T,S} =
    getchunk(c.itr, ichunk, S; n=nothing, size=c.size)

function _getchunk(::Type{FixedCount}, ::Type{BatchSplit}, itr, ichunk; n, kwargs...)
    l = length(itr)
    n_per_chunk, n_remaining = divrem(l, n)
    first = firstindex(itr) + (ichunk - 1) * n_per_chunk + ifelse(ichunk <= n_remaining, ichunk - 1, n_remaining)
    last = (first - 1) + n_per_chunk + ifelse(ichunk <= n_remaining, 1, 0)
    return first:last
end

function _getchunk(::Type{FixedCount}, ::Type{ScatterSplit}, itr, ichunk; n, kwargs...)
    first = (firstindex(itr) - 1) + ichunk
    last = lastindex(itr)
    step = n
    return first:step:last
end

function _getchunk(::Type{FixedSize}, ::Type{BatchSplit}, itr, ichunk; size, kwargs...)
    first = firstindex(itr) + (ichunk - 1) * size
    # last = min((first - 1) + size, length(itr)) # unfortunately doesn't work for offset arrays :(
    d, r = divrem(length(itr), size)
    n = d + (r != 0)
    last = (first - 1) + ifelse(ichunk != n || n == d, size, r + (r == 0))
    return first:last
end

function _getchunk(::Type{FixedSize}, ::Type{ScatterSplit}, itr, ichunk; size, kwargs...)
    throw(ArgumentError("split=ScatterSplit() not yet supported in combination with size keyword argument."))
end

#
# Module for testing
#
module Testing
using ..ChunkSplitters: chunks, getchunk
function test_chunks(; array_length, n, size, split, result)
    if n === nothing
        d, r = divrem(array_length, size)
        nchunks = d + (r != 0)
    elseif size === nothing
        nchunks = n
    else
        throw(ArgumentError("both n and size === nothing"))
    end
    ranges = collect(getchunk(rand(Int, array_length), i; n=n, size=size, split=split) for i in 1:nchunks)
    all(ranges .== result)
end
function sum_parallel(x, n, size, split)
    if n === nothing
        d, r = divrem(length(x), size)
        nchunks = d + (r != 0)
    elseif size === nothing
        nchunks = n
    else
        throw(ArgumentError("both n and size === nothing"))
    end
    s = fill(zero(eltype(x)), nchunks)
    Threads.@threads for (ichunk, range) in enumerate(chunks(x; n=n, size=size, split=split))
        for i in range
            s[ichunk] += x[i]
        end
    end
    return sum(s)
end
function test_sum(; array_length, n, size, split)
    x = rand(array_length)
    return sum_parallel(x, n, size, split) ≈ sum(x)
end
end # module Testing

@testitem "argument errors" begin
    using ChunkSplitters: chunks
    @test_throws ArgumentError chunks(1:10)
    @test_throws ArgumentError chunks(1:10; n=2, split=:not_batch)
    @test_throws ArgumentError chunks(1:10; n=nothing)
    @test_throws ArgumentError chunks(1:10; n=-1)
    @test_throws ArgumentError chunks(1:10; size=nothing)
    @test_throws ArgumentError chunks(1:10; n=5, size=2) # could be supported but we don't
    @test_throws ArgumentError chunks(1:10; n=5, size=20) # could be supported but we don't
end

@testitem ":scatter" begin
    using ChunkSplitters: chunks
    using OffsetArrays: OffsetArray
    using ChunkSplitters.Testing: test_chunks, test_sum
    for split in (:scatter, ScatterSplit())
        @test test_chunks(; array_length=1, n=1, size=nothing, split=split, result=[1:1])
        @test test_chunks(; array_length=2, n=1, size=nothing, split=split, result=[1:2])
        @test test_chunks(; array_length=2, n=2, size=nothing, split=split, result=[1:1, 2:2])
        @test test_chunks(; array_length=3, n=2, size=nothing, split=split, result=[1:2:3, 2:2:2])
        @test test_chunks(; array_length=7, n=3, size=nothing, split=split, result=[1:3:7, 2:3:5, 3:3:6])
        @test test_chunks(; array_length=12, n=4, size=nothing, split=split, result=[1:4:9, 2:4:10, 3:4:11, 4:4:12])
        @test test_chunks(; array_length=15, n=4, size=nothing, split=split, result=[1:4:13, 2:4:14, 3:4:15, 4:4:12])
        @test test_sum(; array_length=1, n=1, size=nothing, split=split)
        @test test_sum(; array_length=2, n=1, size=nothing, split=split)
        @test test_sum(; array_length=2, n=2, size=nothing, split=split)
        @test test_sum(; array_length=3, n=2, size=nothing, split=split)
        @test test_sum(; array_length=7, n=3, size=nothing, split=split)
        @test test_sum(; array_length=12, n=4, size=nothing, split=split)
        @test test_sum(; array_length=15, n=4, size=nothing, split=split)
        @test test_sum(; array_length=117, n=4, size=nothing, split=split)
        x = OffsetArray(1:7, -1:5)
        @test collect.(chunks(x; n=3, split=split)) == [[-1, 2, 5], [0, 3], [1, 4]]

        # FixedSize
        @test_throws ArgumentError collect(chunks(1:10; size=2, split=split)) # not supported (yet?)
    end
end

@testitem ":batch" begin
    using ChunkSplitters: chunks
    using OffsetArrays: OffsetArray
    using ChunkSplitters.Testing: test_chunks, test_sum
    # FixedCount
    for split in (:batch, BatchSplit())
        @test test_chunks(; array_length=1, n=1, size=nothing, split=split, result=[1:1])
        @test test_chunks(; array_length=2, n=1, size=nothing, split=split, result=[1:2])
        @test test_chunks(; array_length=2, n=2, size=nothing, split=split, result=[1:1, 2:2])
        @test test_chunks(; array_length=3, n=2, size=nothing, split=split, result=[1:2, 3:3])
        @test test_chunks(; array_length=7, n=3, size=nothing, split=split, result=[1:3, 4:5, 6:7])
        @test test_chunks(; array_length=12, n=4, size=nothing, split=split, result=[1:3, 4:6, 7:9, 10:12])
        @test test_chunks(; array_length=15, n=4, size=nothing, split=split, result=[1:4, 5:8, 9:12, 13:15])
        @test test_sum(; array_length=1, n=1, size=nothing, split=split)
        @test test_sum(; array_length=2, n=1, size=nothing, split=split)
        @test test_sum(; array_length=2, n=2, size=nothing, split=split)
        @test test_sum(; array_length=3, n=2, size=nothing, split=split)
        @test test_sum(; array_length=7, n=3, size=nothing, split=split)
        @test test_sum(; array_length=12, n=4, size=nothing, split=split)
        @test test_sum(; array_length=15, n=4, size=nothing, split=split)
        @test test_sum(; array_length=117, n=4, size=nothing, split=split)
        x = OffsetArray(1:7, -1:5)
        @test collect.(chunks(x; n=3, split=split)) == [[-1, 0, 1], [2, 3], [4, 5]]

        # FixedSize
        @test test_chunks(; array_length=1, n=nothing, size=1, split=split, result=[1:1])
        @test test_chunks(; array_length=2, n=nothing, size=2, split=split, result=[1:2])
        @test test_chunks(; array_length=2, n=nothing, size=1, split=split, result=[1:1, 2:2])
        @test test_chunks(; array_length=3, n=nothing, size=2, split=split, result=[1:2, 3:3])
        @test test_chunks(; array_length=4, n=nothing, size=1, split=split, result=[1:1, 2:2, 3:3, 4:4])
        @test test_chunks(; array_length=7, n=nothing, size=3, split=split, result=[1:3, 4:6, 7:7])
        @test test_chunks(; array_length=7, n=nothing, size=4, split=split, result=[1:4, 5:7])
        @test test_chunks(; array_length=7, n=nothing, size=5, split=split, result=[1:5, 6:7])
        @test test_chunks(; array_length=12, n=nothing, size=3, split=split, result=[1:3, 4:6, 7:9, 10:12])
        @test test_chunks(; array_length=15, n=nothing, size=4, split=split, result=[1:4, 5:8, 9:12, 13:15])
        @test test_sum(; array_length=1, n=nothing, size=1, split=split)
        @test test_sum(; array_length=2, n=nothing, size=2, split=split)
        @test test_sum(; array_length=2, n=nothing, size=1, split=split)
        @test test_sum(; array_length=3, n=nothing, size=2, split=split)
        @test test_sum(; array_length=4, n=nothing, size=1, split=split)
        @test test_sum(; array_length=7, n=nothing, size=3, split=split)
        @test test_sum(; array_length=7, n=nothing, size=4, split=split)
        @test test_sum(; array_length=7, n=nothing, size=5, split=split)
        @test test_sum(; array_length=12, n=nothing, size=3, split=split)
        @test test_sum(; array_length=15, n=nothing, size=4, split=split)
        x = OffsetArray(1:7, -1:5)
        @test collect.(chunks(x; n=nothing, size=3, split=split)) == [[-1, 0, 1], [2, 3, 4], [5]]
    end
end

@testitem "indexing" begin
    using ChunkSplitters: chunks
    # FixedCount
    c = chunks(1:5; n=4)
    @test firstindex(c) == 1
    @test firstindex(enumerate(c)) == 1
    @test lastindex(c) == 4
    @test lastindex(enumerate(c)) == 4
    @test first(c) == 1:2
    @test first(enumerate(c)) == (1, 1:2)
    @test last(c) == 5:5
    @test last(enumerate(c)) == (4, 5:5)
    @test c[2] == 3:3
    for (ic, c) in enumerate(chunks(1:10; n=2))
        if ic == 1
            @test c == 1:5
        elseif ic == 2
            @test c == 6:10
        end
    end

    # FixedSize
    c = chunks(1:5; size=2)
    @test firstindex(c) == 1
    @test firstindex(enumerate(c)) == 1
    @test lastindex(c) == 3
    @test lastindex(enumerate(c)) == 3
    @test first(c) == 1:2
    @test first(enumerate(c)) == (1, 1:2)
    @test last(c) == 5:5
    @test last(enumerate(c)) == (3, 5:5)
    @test c[2] == 3:4
    for (ic, c) in enumerate(chunks(1:10; size=5))
        if ic == 1
            @test c == 1:5
        elseif ic == 2
            @test c == 6:10
        end
    end
end

@testitem "chunk sizes" begin
    using ChunkSplitters: chunks
    # Sanity test for n < array_length
    c = chunks(1:10; n=2)
    @test length(c) == 2
    # When n > array_length, we shouldn't create more chunks than array_length
    c = chunks(1:10; n=20)
    @test length(c) == 10
    # And we shouldn't be able to get an out-of-bounds chunk
    @test length(chunks(zeros(15); n=5)) == 5 # number of chunks
    @test all(length.(chunks(zeros(15); n=5)) .== 3) # the length of each chunk

    # FixedSize
    c = chunks(1:10; size=5)
    @test length(c) == 2
    # When size > array_length, we shouldn't create more than one chunk
    c = chunks(1:10; size=20)
    @test length(c) == 1
    @test length(first(c)) == 10
    for (l, s) in [(13, 10), (5, 2), (42, 7), (22, 15)]
        local c = chunks(1:l; size=s)
        @test all(length(c[i]) == length(c[i+1]) for i in 1:length(c)-2) # only the last chunk may have different length
    end
    @test collect(chunks(1:10; n=2, minchunksize=2)) == [1:5, 6:10]
    @test collect(chunks(1:10; n=5, minchunksize=3)) == [1:4, 5:7, 8:10]
    @test collect(chunks(1:11; n=10, minchunksize=3)) == [1:4, 5:8, 9:11]
    @test_throws ArgumentError chunks(1:10; n=2, minchunksize=0)
    @test_throws ArgumentError chunks(1:10; size=2, minchunksize=2)
end

@testitem "return type" begin
    using ChunkSplitters: chunks, getchunk
    using BenchmarkTools: @benchmark
    @test typeof(getchunk(1:10, 1; n=2, split=:batch)) == UnitRange{Int}
    @test typeof(getchunk(1:10, 1; size=2, split=:batch)) == UnitRange{Int}
    @test typeof(getchunk(1:10, 1; n=2, split=:scatter)) == StepRange{Int,Int}
    function mwe(ichunk=2, n=5, l=10)
        xs = collect(1:l)
        ys = collect(1:l)
        cx = getchunk(xs, ichunk; n=n, split=:batch)
        cy = getchunk(ys, ichunk; n=n, split=:batch)
        return Iterators.zip(cx, cy)
    end
    function mwe_size(ichunk=2, size=2, l=10)
        xs = collect(1:l)
        ys = collect(1:l)
        cx = getchunk(xs, ichunk; size=size, split=:batch)
        cy = getchunk(ys, ichunk; size=size, split=:batch)
        return Iterators.zip(cx, cy)
    end
    @test zip(3:4, 3:4) == @inferred mwe()
    @test zip(3:4, 3:4) == @inferred mwe_size()
    @test_throws ArgumentError getchunk(1:10, 1; n=2, split=:error)
    x = rand(10)
    @test typeof(first(chunks(x; n=5))) == UnitRange{Int}
    @test eltype(chunks(x; n=5)) == UnitRange{Int}
    @test typeof(first(chunks(x; size=2))) == UnitRange{Int}
    @test eltype(chunks(x; n=2)) == UnitRange{Int}
    # Empty iterator
    @test getchunk(10:9, 1; n=2) === 0:-1
    @test getchunk(10:9, 1; size=2) === 0:-1
    @test getchunk(10:9, 1; n=2, split=:scatter) === 0:1:-1
    @test getchunk(10:9, 1; size=2, split=:scatter) === 0:1:-1
    @test collect(chunks(10:9; n=2)) == Vector{UnitRange{Int}}()
    @test collect(chunks(10:9; size=2)) == Vector{UnitRange{Int}}()
    @test collect(enumerate(chunks(10:9; n=2))) == Tuple{Int64,Vector{UnitRange{Int}}}[]
    @test collect(enumerate(chunks(10:9; size=2))) == Tuple{Int64,Vector{UnitRange{Int}}}[]
    @test collect(chunks(10:9; n=2, split=:scatter)) == Vector{StepRange{Int,Int}}()
    @test collect(chunks(10:9; size=2, split=:scatter)) == Vector{StepRange{Int,Int}}()
    @test collect(enumerate(chunks(10:9; n=2, split=:scatter))) == Tuple{Int64,Vector{StepRange{Int,Int}}}[]
    @test collect(enumerate(chunks(10:9; size=2, split=:scatter))) == Tuple{Int64,Vector{StepRange{Int,Int}}}[]
    # test inference of chunks
    f() = chunks(1:7; n=4)
    @test f() == @inferred f()
    f() = chunks(1:7; n=4, split=:scatter)
    @test f() == @inferred f()
    f() = chunks(1:7; size=4, split=:scatter)
    @test f() == @inferred f()
    function f(x; n=nothing, size=nothing)
        s = zero(eltype(x))
        for inds in chunks(x; n=n, size=size)
            for i in inds
                s += x[i]
            end
        end
        return s
    end
    x = rand(10^3)
    b = @benchmark f($x; n=4) samples = 1 evals = 1
    @test b.allocs == 0
    b = @benchmark f($x; size=10) samples = 1 evals = 1
    @test b.allocs == 0
end

@testitem "Minimial interface" begin
    using ChunkSplitters: ChunkSplitters, chunks
    struct MinimalInterface end
    Base.firstindex(::MinimalInterface) = 1
    Base.lastindex(::MinimalInterface) = 7
    Base.length(::MinimalInterface) = 7
    ChunkSplitters.is_chunkable(::MinimalInterface) = true
    x = MinimalInterface()
    @test collect(chunks(x; n=3)) == [1:3, 4:5, 6:7]
    @test collect(enumerate(chunks(x; n=3))) == [(1, 1:3), (2, 4:5), (3, 6:7)]
    @test eltype(enumerate(chunks(x; n=3))) == Tuple{Int64,UnitRange{Int}}
    @test typeof(first(chunks(x; n=3))) == UnitRange{Int}
    @test collect(chunks(x; n=3, split=ScatterSplit())) == [1:3:7, 2:3:5, 3:3:6]
    @test collect(enumerate(chunks(x; n=3, split=ScatterSplit()))) == [(1, 1:3:7), (2, 2:3:5), (3, 3:3:6)]
    @test eltype(enumerate(chunks(x; n=3, split=ScatterSplit()))) == Tuple{Int64,StepRange{Int64,Int64}}
end

# Preserve legacy 2.0 interface (will be deprecated in 3.0)
include("./legacy.jl")

end # module ChunkSplitters
