module Internals

using ChunkSplitters: Split, Consecutive, RoundRobin
import ChunkSplitters: index_chunks, chunks, is_chunkable
import Base: iterate, length, eltype, enumerate, firstindex, lastindex, getindex, eachindex

abstract type Constraint end
struct FixedCount <: Constraint end
struct FixedSize <: Constraint end

abstract type AbstractChunksIterator{T,C<:Constraint,S<:Split} end

struct ViewChunksIterator{T,C<:Constraint,S<:Split} <: AbstractChunksIterator{T,C,S}
    collection::T
    n::Int
    size::Int
end

struct IndexChunksIterator{T,C<:Constraint,S<:Split} <: AbstractChunksIterator{T,C,S}
    collection::T
    n::Int
    size::Int
end

function ViewChunksIterator(s::Split; collection, n=nothing, size=nothing, minchunksize=nothing)
    is_chunkable(collection) || err_not_chunkable(collection)
    isnothing(n) && isnothing(size) && err_missing_input()
    !isnothing(size) && !isnothing(n) && err_mutually_exclusive("size", "n")
    C, n, size = _set_C_n_size(collection, n, size, minchunksize)
    return ViewChunksIterator{typeof(collection),C,typeof(s)}(collection, n, size)
end

function IndexChunksIterator(s::Split; collection, n=nothing, size=nothing, minchunksize=nothing)
    is_chunkable(collection) || err_not_chunkable(collection)
    isnothing(n) && isnothing(size) && err_missing_input()
    !isnothing(size) && !isnothing(n) && err_mutually_exclusive("size", "n")
    C, n, size = _set_C_n_size(collection, n, size, minchunksize)
    return IndexChunksIterator{typeof(collection),C,typeof(s)}(collection, n, size)
end

# public API
function index_chunks(collection;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::Split=Consecutive(),
    minchunksize::Union{Nothing,Integer}=nothing,
)
    return IndexChunksIterator(split; collection, n, size, minchunksize)
end

# public API
function chunks(collection;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::Split=Consecutive(),
    minchunksize::Union{Nothing,Integer}=nothing,
)
    return ViewChunksIterator(split; collection, n, size, minchunksize)
end

# public API
is_chunkable(::Any) = false
is_chunkable(::AbstractArray) = true
is_chunkable(::Tuple) = true
is_chunkable(::AbstractChunksIterator) = true

_set_minchunksize(minchunksize::Nothing) = 1
function _set_minchunksize(minchunksize::Integer)
    minchunksize < 1 && throw(ArgumentError("minchunksize must be >= 1"))
    return minchunksize
end
function _set_C_n_size(collection, n::Nothing, size::Integer, minchunksize)
    !isnothing(minchunksize) && err_mutually_exclusive("size", "minchunksize")
    size < 1 && throw(ArgumentError("size must be >= 1"))
    return FixedSize, 0, size
end
function _set_C_n_size(collection, n::Integer, size::Nothing, minchunksize)
    n < 1 && throw(ArgumentError("n must be >= 1"))
    mcs = _set_minchunksize(minchunksize)
    nmax = min(length(collection) ÷ mcs, n)
    FixedCount, nmax, 0
end

function err_missing_input()
    throw(ArgumentError("You must either indicate the desired number of chunks (n) or the target size of a chunk (size)."))
end
function err_mutually_exclusive(var1, var2)
    throw(ArgumentError("$var1 and $var2 are mutually exclusive."))
end
function err_not_chunkable(::T) where {T}
    throw(ArgumentError("Arguments of type $T are not compatible with chunks, either implement a custom chunks method for your type, or implement the custom type interface (see https://juliafolds2.github.io/ChunkSplitters.jl/dev/)"))
end

firstindex(::AbstractChunksIterator) = 1

lastindex(c::AbstractChunksIterator) = length(c)

length(c::AbstractChunksIterator{T,FixedCount,S}) where {T,S} = c.n
length(c::AbstractChunksIterator{T,FixedSize,S}) where {T,S} = cld(length(c.collection), max(1, c.size))

getindex(c::IndexChunksIterator{T,C,S}, i::Int) where {T,C,S} = getchunkindices(c, i)
getindex(c::ViewChunksIterator{T,C,S}, i::Int) where {T,C,S} = @view(c.collection[getchunkindices(c, i)])

eltype(::IndexChunksIterator{T,C,Consecutive}) where {T,C} = UnitRange{Int}
eltype(::IndexChunksIterator{T,C,RoundRobin}) where {T,C} = StepRange{Int,Int}
eltype(c::ViewChunksIterator{T,C,Consecutive}) where {T,C} = typeof(c[firstindex(c)])
eltype(c::ViewChunksIterator{T,C,RoundRobin}) where {T,C} = typeof(c[firstindex(c)])

function iterate(c::AbstractChunksIterator, state=firstindex(c))
    if state > lastindex(c)
        return nothing
    else
        return @inbounds(c[state]), state + 1
    end
end

# Usually enumerate is not compatible
# with `@threads` and co, because of the lack of the general definition of
# `firstindex`, `lastindex`, and `getindex` for `Base.Iterators.Enumerate{<:Any}`. Thus,
# to avoid using the internal `.itr` property of `Enumerate`, we redefine
# the `iterate` method for `ChunkSplitters.Enumerate{<:AbstractChunksIterator}`.
struct Enumerate{I<:AbstractChunksIterator}
    itr::I
end
enumerate(c::AbstractChunksIterator) = Enumerate(c)

function iterate(ec::Enumerate{<:AbstractChunksIterator}, state=nothing)
    length(ec.itr.collection) == 0 && return nothing
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

eltype(ec::Enumerate{<:AbstractChunksIterator{T,C,Consecutive}}) where {T,C} = Tuple{Int,eltype(ec.itr)}
eltype(ec::Enumerate{<:AbstractChunksIterator{T,C,RoundRobin}}) where {T,C} = Tuple{Int,eltype(ec.itr)}

firstindex(::Enumerate{<:AbstractChunksIterator}) = 1

lastindex(ec::Enumerate{<:AbstractChunksIterator}) = lastindex(ec.itr)

getindex(ec::Enumerate{<:AbstractChunksIterator}, i::Int) = (i, ec.itr[i])

length(ec::Enumerate{<:AbstractChunksIterator}) = length(ec.itr)

eachindex(ec::Enumerate{<:AbstractChunksIterator}) = Base.OneTo(length(ec.itr))

_empty_itr(::Type{Consecutive}) = 0:-1
_empty_itr(::Type{RoundRobin}) = 0:1:-1

"""
    getchunkindices(c::AbstractChunksIterator, i::Integer)

Returns the range of indices of `collection` that corresponds to the `i`-th chunk.
"""
function getchunkindices(c::AbstractChunksIterator{T,C,S}, ichunk::Integer) where {T,C,S}
    length(c) == 0 && return _empty_itr(S)
    ichunk <= length(c.collection) || throw(ArgumentError("ichunk must be less or equal to the length of the ChunksIterator"))
    if C == FixedCount
        n = c.n
        size = nothing
        n >= 1 || throw(ArgumentError("n must be >= 1"))
    elseif C == FixedSize
        n = nothing
        size = c.size
        size >= 1 || throw(ArgumentError("size must be >= 1"))
        l = length(c.collection)
        size = min(l, size) # handle size>length(c.collection)
        n = cld(l, size)
    end
    ichunk <= n || throw(ArgumentError("index must be less or equal to number of chunks ($n)"))
    return _getchunkindices(C, S, c.collection, ichunk; n, size)
end

function _getchunkindices(::Type{FixedCount}, ::Type{Consecutive}, collection, ichunk; n, kwargs...)
    l = length(collection)
    n_per_chunk, n_remaining = divrem(l, n)
    first = firstindex(collection) + (ichunk - 1) * n_per_chunk + ifelse(ichunk <= n_remaining, ichunk - 1, n_remaining)
    last = (first - 1) + n_per_chunk + ifelse(ichunk <= n_remaining, 1, 0)
    return first:last
end

function _getchunkindices(::Type{FixedCount}, ::Type{RoundRobin}, collection, ichunk; n, kwargs...)
    first = (firstindex(collection) - 1) + ichunk
    last = lastindex(collection)
    step = n
    return first:step:last
end

function _getchunkindices(::Type{FixedSize}, ::Type{Consecutive}, collection, ichunk; size, kwargs...)
    first = firstindex(collection) + (ichunk - 1) * size
    # last = min((first - 1) + size, length(collection)) # unfortunately doesn't work for offset arrays :(
    d, r = divrem(length(collection), size)
    n = d + (r != 0)
    last = (first - 1) + ifelse(ichunk != n || n == d, size, r + (r == 0))
    return first:last
end

function _getchunkindices(::Type{FixedSize}, ::Type{RoundRobin}, collection, ichunk; size, kwargs...)
    throw(ArgumentError("split=RoundRobin() not yet supported in combination with size keyword argument."))
end

end # module
