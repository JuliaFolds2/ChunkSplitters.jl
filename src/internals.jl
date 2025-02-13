module Internals

using ChunkSplitters: Split, Consecutive, RoundRobin
import ChunkSplitters: index_chunks, chunks, is_chunkable

abstract type Constraint end
struct FixedCount <: Constraint end
struct FixedSize <: Constraint end

abstract type AbstractChunks{T,C<:Constraint,S<:Split} end

struct ViewChunks{T,C<:Constraint,S<:Split} <: AbstractChunks{T,C,S}
    collection::T
    n::Int
    size::Int
end

struct IndexChunks{T,C<:Constraint,S<:Split} <: AbstractChunks{T,C,S}
    collection::T
    n::Int
    size::Int
end

function ViewChunks(s::Split; collection, n=nothing, size=nothing, minsize=nothing)
    is_chunkable(collection) || err_not_chunkable(collection)
    isnothing(n) && isnothing(size) && err_missing_input()
    !isnothing(size) && !isnothing(n) && err_mutually_exclusive("size", "n")
    C, n, size = _set_C_n_size(collection, n, size, minsize)
    return ViewChunks{typeof(collection),C,typeof(s)}(collection, n, size)
end

function IndexChunks(s::Split; collection, n=nothing, size=nothing, minsize=nothing)
    is_chunkable(collection) || err_not_chunkable(collection)
    isnothing(n) && isnothing(size) && err_missing_input()
    !isnothing(size) && !isnothing(n) && err_mutually_exclusive("size", "n")
    C, n, size = _set_C_n_size(collection, n, size, minsize)
    return IndexChunks{typeof(collection),C,typeof(s)}(collection, n, size)
end

# public API
function index_chunks(collection;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::Split=Consecutive(),
    minsize::Union{Nothing,Integer}=nothing,
)
    return IndexChunks(split; collection, n, size, minsize)
end

# public API
function chunks(collection;
    n::Union{Nothing,Integer}=nothing,
    size::Union{Nothing,Integer}=nothing,
    split::Split=Consecutive(),
    minsize::Union{Nothing,Integer}=nothing,
)
    return ViewChunks(split; collection, n, size, minsize)
end

# public API
is_chunkable(::Any) = false
is_chunkable(::AbstractArray) = true
is_chunkable(::Tuple) = true
is_chunkable(::AbstractChunks) = true

_set_minsize(minsize::Nothing, _) = 1
function _set_minsize(minsize::Integer, collection_length::Integer)
    minsize < 1 && throw(ArgumentError("minsize must be >= 1"))
    minsize > collection_length && throw(ArgumentError("minsize must be <= length(collection)"))
    return minsize
end
function _set_C_n_size(collection, n::Nothing, size::Integer, minsize)
    !isnothing(minsize) && err_mutually_exclusive("size", "minsize")
    size < 1 && throw(ArgumentError("size must be >= 1"))
    return FixedSize, 0, size
end
function _set_C_n_size(collection, n::Integer, size::Nothing, minsize)
    n < 1 && throw(ArgumentError("n must be >= 1"))
    mcs = _set_minsize(minsize, length(collection))
    nmax = min(length(collection) ÷ mcs, n)
    return FixedCount, nmax, 0
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

Base.firstindex(::AbstractChunks) = 1

Base.lastindex(c::AbstractChunks) = length(c)

Base.length(c::AbstractChunks{T,FixedCount,S}) where {T,S} = c.n
Base.length(c::AbstractChunks{T,FixedSize,S}) where {T,S} = cld(length(c.collection), max(1, c.size))

Base.getindex(c::IndexChunks{T,C,S}, i::Int) where {T,C,S} = getchunkindices(c, i)
Base.getindex(c::ViewChunks{T,C,S}, i::Int) where {T,C,S} = @view(c.collection[getchunkindices(c, i)])

Base.eltype(::IndexChunks{T,C,Consecutive}) where {T,C} = UnitRange{Int}
Base.eltype(::IndexChunks{T,C,RoundRobin}) where {T,C} = StepRange{Int,Int}
Base.eltype(c::ViewChunks{T,C,Consecutive}) where {T,C} = typeof(c[firstindex(c)])
Base.eltype(c::ViewChunks{T,C,RoundRobin}) where {T,C} = typeof(c[firstindex(c)])

function Base.iterate(c::AbstractChunks, state=firstindex(c))
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
# the `iterate` method for `ChunkSplitters.Enumerate{<:AbstractChunks}`.
struct Enumerate{I<:AbstractChunks}
    itr::I
end
Base.enumerate(c::AbstractChunks) = Enumerate(c)

function Base.iterate(ec::Enumerate{<:AbstractChunks}, state=firstindex(ec.itr))
    if state > lastindex(ec.itr)
        return nothing
    else
        return ((state, @inbounds(ec.itr[state])), state + 1)
    end
end

Base.eltype(ec::Enumerate{<:AbstractChunks{T,C,Consecutive}}) where {T,C} = Tuple{Int,eltype(ec.itr)}
Base.eltype(ec::Enumerate{<:AbstractChunks{T,C,RoundRobin}}) where {T,C} = Tuple{Int,eltype(ec.itr)}

Base.firstindex(::Enumerate{<:AbstractChunks}) = 1

Base.lastindex(ec::Enumerate{<:AbstractChunks}) = lastindex(ec.itr)

Base.getindex(ec::Enumerate{<:AbstractChunks}, i::Int) = (i, ec.itr[i])

Base.length(ec::Enumerate{<:AbstractChunks}) = length(ec.itr)

Base.eachindex(ec::Enumerate{<:AbstractChunks}) = Base.OneTo(length(ec.itr))

_empty_itr(::Type{Consecutive}) = 0:-1
_empty_itr(::Type{RoundRobin}) = 0:1:-1

"""
    getchunkindices(c::AbstractChunks, i::Integer)

Returns the range of indices of `collection` that corresponds to the `i`-th chunk.
"""
function getchunkindices(c::AbstractChunks{T,C,S}, ichunk::Integer) where {T,C,S}
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
