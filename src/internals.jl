module Internals

using ChunkSplitters: SplitStrategy, BatchSplit, ScatterSplit
import ChunkSplitters: chunk_indices, chunk, is_chunkable
import Base: iterate, length, eltype, enumerate, firstindex, lastindex, getindex, eachindex

abstract type Constraint end
struct FixedCount <: Constraint end
struct FixedSize <: Constraint end

abstract type ReturnType end
struct ReturnIndices <: ReturnType end
struct ReturnViews <: ReturnType end

struct ChunksIterator{T,C<:Constraint,S<:SplitStrategy,R<:ReturnType}
    itr::T
    n::Int
    size::Int
end

function chunk_indices(itr;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::SplitStrategy=BatchSplit(),
    minchunksize::Union{Nothing,Integer}=nothing,
)
    is_chunkable(itr) || not_chunkable_err(itr)
    isnothing(n) && isnothing(size) && missing_input_err()
    !isnothing(size) && !isnothing(n) && mutually_exclusive_err("size", "n")
    C, n, size = _set_C_n_size(itr, n, size, minchunksize)

    if split isa BatchSplit
        return ChunksIterator{typeof(itr),C,BatchSplit,ReturnIndices}(itr, n, size)
    elseif split isa ScatterSplit
        return ChunksIterator{typeof(itr),C,ScatterSplit,ReturnIndices}(itr, n, size)
    else
        split_err()
    end
end

function chunk(itr;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::SplitStrategy=BatchSplit(),
    minchunksize::Union{Nothing,Integer}=nothing,
)
    is_chunkable(itr) || not_chunkable_err(itr)
    isnothing(n) && isnothing(size) && missing_input_err()
    !isnothing(size) && !isnothing(n) && mutually_exclusive_err("size", "n")
    C, n, size = _set_C_n_size(itr, n, size, minchunksize)

    if split isa BatchSplit
        return ChunksIterator{typeof(itr),C,BatchSplit,ReturnViews}(itr, n, size)
    elseif split isa ScatterSplit
        return ChunksIterator{typeof(itr),C,ScatterSplit,ReturnViews}(itr, n, size)
    else
        split_err()
    end
end

is_chunkable(::Any) = false
is_chunkable(::AbstractArray) = true
is_chunkable(::Tuple) = true
is_chunkable(::ChunksIterator) = true

_set_minchunksize(minchunksize::Nothing) = 1
function _set_minchunksize(minchunksize::Integer)
    minchunksize < 1 && throw(ArgumentError("minchunksize must be >= 1"))
    return minchunksize
end
function _set_C_n_size(itr, n::Nothing, size::Integer, minchunksize)
    !isnothing(minchunksize) && mutually_exclusive_err("size", "minchunksize")
    size < 1 && throw(ArgumentError("size must be >= 1"))
    return FixedSize, 0, size
end
function _set_C_n_size(itr, n::Integer, size::Nothing, minchunksize)
    n < 1 && throw(ArgumentError("n must be >= 1"))
    mcs = _set_minchunksize(minchunksize)
    nmax = min(length(itr) ÷ mcs, n)
    FixedCount, nmax, 0
end

function missing_input_err()
    throw(ArgumentError("You must either indicate the desired number of chunks (n) or the target size of a chunk (size)."))
end
function mutually_exclusive_err(var1, var2)
    throw(ArgumentError("$var1 and $var2 are mutually exclusive."))
end
function not_chunkable_err(::T) where {T}
    throw(ArgumentError("Arguments of type $T are not compatible with chunks, either implement a custom chunks method for your type, or if it is compatible with the chunks minimal interface (see https://juliafolds2.github.io/ChunkSplitters.jl/dev/)"))
end
@noinline split_err() = throw(ArgumentError("split must be one of $(subtypes(SplitStrategy))"))

firstindex(::ChunksIterator) = 1

lastindex(c::ChunksIterator) = length(c)

length(c::ChunksIterator{T,FixedCount,S}) where {T,S} = c.n
length(c::ChunksIterator{T,FixedSize,S}) where {T,S} = cld(length(c.itr), max(1, c.size))

getindex(c::ChunksIterator{T,C,S,ReturnIndices}, i::Int) where {T,C,S} = getchunk(c, i)
getindex(c::ChunksIterator{T,C,S,ReturnViews}, i::Int) where {T,C,S} = @view(c.itr[getchunk(c, i)])

eltype(::ChunksIterator{T,C,BatchSplit,ReturnIndices}) where {T,C} = UnitRange{Int}
eltype(::ChunksIterator{T,C,ScatterSplit,ReturnIndices}) where {T,C} = StepRange{Int,Int}
eltype(c::ChunksIterator{T,C,BatchSplit,ReturnViews}) where {T,C} = typeof(c[firstindex(c)])
eltype(c::ChunksIterator{T,C,ScatterSplit,ReturnViews}) where {T,C} = typeof(c[firstindex(c)])

function iterate(c::ChunksIterator{T,C,S,R}, state=nothing) where {T,C,S,R}
    length(c.itr) == 0 && return nothing
    if isnothing(state)
        chunk = c[1]
        return (chunk, 1)
    elseif state < length(c)
        chunk = c[state+1]
        return (chunk, state + 1)
    end
    return nothing
end

#
# Iteration over chunks enumeration: usually enumerate is not compatible
# with `@threads`, because of the lack of the general definition of
# `firstindex`, `lastindex`, and `getindex` for `Base.Iterators.Enumerate{<:Any}`. Thus,
# to avoid using the internal `.itr` property of `Enumerate`, we redefine
# the `iterate` method for `ChunkSplitters.Enumerate{<:ChunksIterator}`.
#
struct Enumerate{I<:ChunksIterator}
    itr::I
end
enumerate(c::ChunksIterator) = Enumerate(c)

function iterate(ec::Enumerate{<:ChunksIterator}, state=nothing)
    length(ec.itr.itr) == 0 && return nothing
    if isnothing(state)
        chunk = ec.itr[1]
        return ((1, chunk), 1)
    elseif state < length(ec.itr)
        state = state + 1
        chunk = ec.itr[state]
        return ((state, chunk), state)
    end
    return nothing
end

eltype(ec::Enumerate{<:ChunksIterator{T,C,BatchSplit}}) where {T,C} = Tuple{Int,eltype(ec.itr)}
eltype(ec::Enumerate{<:ChunksIterator{T,C,ScatterSplit}}) where {T,C} = Tuple{Int,eltype(ec.itr)}

firstindex(::Enumerate{<:ChunksIterator}) = 1

lastindex(ec::Enumerate{<:ChunksIterator}) = lastindex(ec.itr)

getindex(ec::Enumerate{<:ChunksIterator}, i::Int) = (i, ec.itr[i])

length(ec::Enumerate{<:ChunksIterator}) = length(ec.itr)

eachindex(ec::Enumerate{<:ChunksIterator}) = Base.OneTo(length(ec.itr))

"""
    getchunk(itr, i::Integer; n::Union{Nothing,Integer}, size::Union{Nothing,Integer}[, split::SplitStrategy=BatchSplit()])

Returns the range of indices of `itr` that corresponds to the `i`-th chunk.
How the chunks are formed depends on the keyword arguments. See `chunk_indices` for more information.
"""
function getchunk(itr, ichunk::Integer;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::SplitStrategy=BatchSplit()
)
    if split isa BatchSplit
        getchunk(itr, ichunk, BatchSplit; n=n, size=size)
    elseif split isa ScatterSplit
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
getchunk(c::ChunksIterator{T,FixedCount,S}, ichunk::Integer) where {T,S} =
    getchunk(c.itr, ichunk, S; n=c.n, size=nothing)
getchunk(c::ChunksIterator{T,FixedSize,S}, ichunk::Integer) where {T,S} =
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

end # module
