module ChunkSplitters

using TestItems

export chunks, getchunk

"""
    chunks(array::AbstractArray; n::Int=Threads.nthreads(), distribution::Symbol=:batch)

Returns an iterator that splits the *indices* of `array` into `n`-many chunks.
The iterator can be used to process chunks of `array` one after another or in parallel (e.g. with `@threads`).
The optional argument `distribution` can be `:batch` (default) or `:scatter`.

If you need a running chunk index, e.g. to index into a buffer that is shared 
between chunks, you can combine `chunks` with `enumerate`. In particular,
`enumerate(chunks(...))` can be used in conjuction with `@threads`.

## Examples

```jldoctest
julia> using ChunkSplitters 

julia> x = rand(7);

julia> collect(chunks(x; n=3))
3-element Vector{StepRange{Int64, Int64}}:
 1:1:3
 4:1:5
 6:1:7

julia> collect(enumerate(chunks(x; n=3)))
3-element Vector{Tuple{Int64, StepRange{Int64, Int64}}}:
 (1, 1:1:3)
 (2, 4:1:5)
 (3, 6:1:7)
```

Note that `chunks` also works just fine for `OffsetArray`s:

```jldoctest
julia> using ChunkSplitters, OffsetArrays

julia> x = OffsetArray(1:7, -1:5);

julia> collect(chunks(x; n=3))
3-element Vector{StepRange{Int64, Int64}}:
 -1:1:1
 2:1:3
 4:1:5
```

"""
function chunks end

# Current chunks distribution types
const distribution_types = (:batch, :scatter)

# Structure that carries the chunks data
struct Chunk{T<:AbstractArray}
    x::T
    n::Int
    distribution::Symbol
end

# Constructor for the chunks
function chunks(x::AbstractArray; n::Int=Threads.nthreads(), distribution::Symbol=:batch)
    n >= 1 || throw(ArgumentError("n must be >= 1"))
    (distribution in distribution_types) || throw(ArgumentError("distribution must be one of $distribution"))
    Chunk{typeof(x)}(x, min(length(x), n), distribution)
end

import Base: length, eltype
length(c::Chunk) = c.n
eltype(::Chunk) = StepRange{Int,Int}

import Base: firstindex, lastindex, getindex
firstindex(::Chunk) = 1
lastindex(c::Chunk) = c.n
getindex(c::Chunk, i::Int) = getchunk(c.x, i, c.n, c.distribution)

#
# Iteration of the chunks
#
import Base: iterate
function iterate(c::Chunk, state=nothing)
    if isnothing(state)
        chunk = getchunk(c.x, 1, c.n, c.distribution)
        return (chunk, 1)
    elseif state < c.n
        chunk = getchunk(c.x, state + 1, c.n, c.distribution)
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
Base.enumerate(c::Chunk) = Enumerate(c)

function Base.iterate(ec::Enumerate{<:Chunk}, state=nothing)
    if isnothing(state)
        chunk = getchunk(ec.itr.x, 1, ec.itr.n, ec.itr.distribution)
        return ((1, chunk), 1)
    elseif state < ec.itr.n
        state = state + 1
        chunk = getchunk(ec.itr.x, state, ec.itr.n, ec.itr.distribution)
        return ((state, chunk), state)
    end
    return nothing
end
eltype(::Enumerate{<:Chunk}) = Tuple{Int,StepRange{Int,Int}}

# These methods are required for threading over enumerate(chunks(...))
firstindex(::Enumerate{<:Chunk}) = 1
lastindex(ec::Enumerate{<:Chunk}) = ec.itr.n
getindex(ec::Enumerate{<:Chunk}, i::Int) = (i, getchunk(ec.itr.x, i, ec.itr.n, ec.itr.distribution))
length(ec::Enumerate{<:Chunk}) = ec.itr.n

@testitem "enumerate chunks" begin
    using ChunkSplitters
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
    @test collect(enumerate(chunks(1:10; n=2))) == [(1, 1:1:5), (2, 6:1:10)]
    @test collect(enumerate(chunks(rand(7); n=3))) ==
          Tuple{Int64,StepRange{Int64,Int64}}[(1, 1:1:3), (2, 4:1:5), (3, 6:1:7)]
    @test eltype(enumerate(chunks(rand(7); n=3))) == Tuple{Int64,StepRange{Int64,Int64}}
end

#
# This is the lower level function that receives `ichunk` as a parameter
#
"""
    getchunk(array::AbstractArray, i::Int, n::Int, distribution::Symbol=:batch)

Function that returns a range of indices of `array`, given the number of chunks in
which the array is to be split, `n`, and the current chunk number `ichunk`. 

If `distribution == :batch`, the ranges are consecutive. If `distribution == :scatter`, the range
is scattered over the array. 

## Example

For example, if we have an array of 7 elements, and the work on the elements is divided
into 3 chunks, we have (using the default `distribution = :batch` option):

```jldoctest
julia> using ChunkSplitters

julia> x = rand(7);

julia> getchunk(x, 1, 3)
1:1:3

julia> getchunk(x, 2, 3)
4:1:5

julia> getchunk(x, 3, 3)
6:1:7
```

And using `distribution = :scatter`, we have:

```jldoctest
julia> using ChunkSplitters

julia> x = rand(7);

julia> getchunk(x, 1, 3, distribution=:scatter)
1:3:7

julia> getchunk(x, 2, 3, distribution=:scatter)
2:3:5

julia> getchunk(x, 3, 3, distribution=:scatter)
3:3:6
```
"""
function getchunk(array::AbstractArray, ichunk::Int, n::Int, distribution::Symbol=:batch)
    ichunk <= n || throw(ArgumentError("index must be less or equal to number of chunks"))
    ichunk <= length(array) || throw(ArgumentError("ichunk must be less or equal to the length of `array`"))
    if distribution == :batch
        l = length(array)
        n_per_chunk, n_remaining = divrem(l, n)
        first = firstindex(array) + (ichunk - 1) * n_per_chunk + ifelse(ichunk <= n_remaining, ichunk - 1, n_remaining)
        last = (first - 1) + n_per_chunk + ifelse(ichunk <= n_remaining, 1, 0)
        step = 1
    elseif distribution == :scatter
        first = (firstindex(array) - 1) + ichunk
        last = lastindex(array)
        step = n
    else
        throw(ArgumentError("chunk distribution must be :batch or :scatter"))
    end
    return first:step:last
end

#
# Module for testing
#
module Testing
using ..ChunkSplitters
function test_chunks(; array_length, n, distribution, result, return_ranges=false)
    ranges = collect(getchunk(rand(Int, array_length), i, n, distribution) for i in 1:n)
    if return_ranges
        return ranges
    else
        all(ranges .== result)
    end
end
function sum_parallel(x, n, distribution)
    s = fill(zero(eltype(x)), n)
    Threads.@threads for (ichunk, range) in enumerate(chunks(x; n=n, distribution=distribution))
        for i in range
            s[ichunk] += x[i]
        end
    end
    return sum(s)
end
function test_sum(; array_length, n, distribution)
    x = rand(array_length)
    return sum_parallel(x, n, distribution) ≈ sum(x)
end
end # module Testing

@testitem "argument errors" begin
    using ChunkSplitters
    @test_throws ArgumentError chunks(1:10; n=2, distribution=:not_batch)
    @test_throws ArgumentError chunks(1:10; n=0)
    @test_throws ArgumentError chunks(1:10; n=-1)
    @test_throws MethodError chunks(1; n=1)
end

@testitem ":scatter" begin
    using ChunkSplitters
    using OffsetArrays
    import ChunkSplitters.Testing: test_chunks, test_sum
    @test test_chunks(; array_length=1, n=1, distribution=:scatter, result=[1:1])
    @test test_chunks(; array_length=2, n=1, distribution=:scatter, result=[1:2])
    @test test_chunks(; array_length=2, n=2, distribution=:scatter, result=[1:1, 2:2])
    @test test_chunks(; array_length=3, n=2, distribution=:scatter, result=[1:2:3, 2:2:2])
    @test test_chunks(; array_length=7, n=3, distribution=:scatter, result=[1:3:7, 2:3:5, 3:3:6])
    @test test_chunks(; array_length=12, n=4, distribution=:scatter, result=[1:4:9, 2:4:10, 3:4:11, 4:4:12])
    @test test_chunks(; array_length=15, n=4, distribution=:scatter, result=[1:4:13, 2:4:14, 3:4:15, 4:4:12])
    @test test_sum(; array_length=1, n=1, distribution=:scatter)
    @test test_sum(; array_length=2, n=1, distribution=:scatter)
    @test test_sum(; array_length=2, n=2, distribution=:scatter)
    @test test_sum(; array_length=3, n=2, distribution=:scatter)
    @test test_sum(; array_length=7, n=3, distribution=:scatter)
    @test test_sum(; array_length=12, n=4, distribution=:scatter)
    @test test_sum(; array_length=15, n=4, distribution=:scatter)
    @test test_sum(; array_length=117, n=4, distribution=:scatter)
    x = OffsetArray(1:7, -1:5)
    @test collect.(chunks(x; n=3, distribution=:scatter)) == [[-1, 2, 5], [0, 3], [1, 4]]
end

@testitem ":batch" begin
    using ChunkSplitters
    using OffsetArrays
    import ChunkSplitters.Testing: test_chunks, test_sum
    @test test_chunks(; array_length=1, n=1, distribution=:batch, result=[1:1])
    @test test_chunks(; array_length=2, n=1, distribution=:batch, result=[1:2])
    @test test_chunks(; array_length=2, n=2, distribution=:batch, result=[1:1, 2:2])
    @test test_chunks(; array_length=3, n=2, distribution=:batch, result=[1:2, 3:3])
    @test test_chunks(; array_length=7, n=3, distribution=:batch, result=[1:3, 4:5, 6:7])
    @test test_chunks(; array_length=12, n=4, distribution=:batch, result=[1:3, 4:6, 7:9, 10:12])
    @test test_chunks(; array_length=15, n=4, distribution=:batch, result=[1:4, 5:8, 9:12, 13:15])
    @test test_sum(; array_length=1, n=1, distribution=:batch)
    @test test_sum(; array_length=2, n=1, distribution=:batch)
    @test test_sum(; array_length=2, n=2, distribution=:batch)
    @test test_sum(; array_length=3, n=2, distribution=:batch)
    @test test_sum(; array_length=7, n=3, distribution=:batch)
    @test test_sum(; array_length=12, n=4, distribution=:batch)
    @test test_sum(; array_length=15, n=4, distribution=:batch)
    @test test_sum(; array_length=117, n=4, distribution=:batch)
    x = OffsetArray(1:7, -1:5)
    @test collect.(chunks(x; n=3, distribution=:batch)) == [[-1, 0, 1], [2, 3], [4, 5]]
end

@testitem "indexing" begin
    using ChunkSplitters
    c = chunks(1:5; n=4)
    @test firstindex(c) == 1
    @test firstindex(enumerate(c)) == 1
    @test lastindex(c) == 4
    @test lastindex(enumerate(c)) == 4
    @test first(c) == 1:1:2
    @test first(enumerate(c)) == (1, 1:1:2)
    @test last(c) == 5:1:5
    @test last(enumerate(c)) == (4, 5:1:5)
    @test c[2] == 3:1:3
    for (ic, c) in enumerate(chunks(1:10; n=2))
        if ic == 1
            @test c == 1:1:5
        elseif ic == 2
            @test c == 6:1:10
        end
    end
end

@testitem "chunk sizes" begin
    using ChunkSplitters
    # Sanity test for n < array_length
    c = chunks(1:10; n=2)
    @test length(c) == 2
    # When n > array_length, we shouldn't create more chunks than array_length
    c = chunks(1:10; n=20)
    @test length(c) == 10
    # And we shouldn't be able to get an out-of-bounds chunk
    @test length(chunks(zeros(15); n=5)) == 5 # number of chunks
    @test all(length.(chunks(zeros(15); n=5)) .== 3) # the length of each chunk
end

@testitem "return type" begin
    @test typeof(getchunk(1:10, 1, 2, :batch)) == StepRange{Int,Int}
    @test typeof(getchunk(1:10, 1, 2, :scatter)) == StepRange{Int,Int}
    function mwe(ichunk=2, n=5, l=10)
        xs = collect(1:l)
        ys = collect(1:l)
        cx = getchunk(xs, ichunk, n, :batch)
        cy = getchunk(ys, ichunk, n, :batch)
        return Iterators.zip(cx, cy)
    end
    @test @inferred mwe() == zip(3:1:4, 3:1:4)
    @test_throws ArgumentError getchunk(1:10, 1, 2, :error)
    x = rand(10)
    @test typeof(first(chunks(x; n=5))) == StepRange{Int,Int}
    @test eltype(chunks(x; n=5)) == StepRange{Int,Int}
end

end # module ChunkSplitters
