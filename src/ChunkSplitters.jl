module ChunkSplitters

using TestItems

export chunks, getchunk

"""
    chunks(array::AbstractArray, nchunks::Int, type::Symbol=:batch)

This function returns an iterable object that will split the *indices* of `array` into
to `nchunks` chunks. `type` can be `:batch` or `:scatter`. It can be used to directly iterate
over the chunks of a collection in a multi-threaded manner.

## Example

```julia-repl
julia> using ChunkSplitters

julia> x = rand(7);

julia> for i in chunks(x, 3, :batch)
           @show Threads.threadid(), collect(i)
       end
(Threads.threadid(), collect(i)) = (6, [1, 2, 3])
(Threads.threadid(), collect(i)) = (8, [4, 5])
(Threads.threadid(), collect(i)) = (7, [6, 7])

julia> for i in chunks(x, 3, :scatter)
           @show Threads.threadid(), collect(i)
       end
(Threads.threadid(), collect(i)) = (2, [1, 4, 7])
(Threads.threadid(), collect(i)) = (11, [2, 5])
(Threads.threadid(), collect(i)) = (3, [3, 6])
```


"""
function chunks end

# Current chunks types
const chunks_types = (:batch, :scatter)

# Structure that carries the chunks data
struct Chunk{T<:AbstractArray}
    x::T
    nchunks::Int
    type::Symbol
end

# Constructor for the chunks
function chunks(x::AbstractArray, nchunks::Int, type=:batch)
    nchunks >= 1 || throw(ArgumentError("nchunks must be >= 1"))
    (type in chunks_types) || throw(ArgumentError("type must be one of $chunks_types"))
    Chunk{typeof(x)}(x, min(length(x), nchunks), type)
end

import Base: length, eltype
length(c::Chunk) = c.nchunks
eltype(::Chunk) = UnitRange{Int}

import Base: firstindex, lastindex, getindex
firstindex(::Chunk) = 1
lastindex(c::Chunk) = c.nchunks
getindex(c::Chunk, i::Int) = (getchunk(c.x, i, c.nchunks, c.type), i)

import Base: collect
collect(c::Chunk) = [(getchunk(c.x, i, c.nchunks, c.type), i) for i in 1:c.nchunks]

#
# Iteration of the chunks
#
import Base: iterate
function iterate(c::Chunk, state=nothing)
    if isnothing(state)
        return ((getchunk(c.x, 1, c.nchunks, c.type), 1), 1)
    elseif state < c.nchunks
        return ((getchunk(c.x, state + 1, c.nchunks, c.type), state + 1), state + 1)
    else
        return nothing
    end
end

#
# This is the lower level function that receives `ichunk` as a parameter
#
"""
    getchunk(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)

Function that returns a range of indexes of `array`, given the number of chunks in
which the array is to be split, `nchunks`, and the current chunk number `ichunk`.

If `type == :batch`, the ranges are consecutive. If `type == :scatter`, the range
is scattered over the array.

!!! note
    The `getchunk` function is available in version 2 of the package. In version 1 it was named `chunks`.

## Example

For example, if we have an array of 7 elements, and the work on the elements is divided
into 3 chunks, we have (using the default `type = :batch` option):

```julia-repl
julia> using ChunkSplitters

julia> x = rand(7);

julia> getchunk(x, 1, 3)
1:3

julia> getchunk(x, 2, 3)
4:5

julia> getchunk(x, 3, 3)
6:7
```

And using `type = :scatter`, we have:

```julia-repl
julia> getchunk(x, 1, 3, :scatter)
1:3:7

julia> getchunk(x, 2, 3, :scatter)
2:3:5

julia> getchunk(x, 3, 3, :scatter)
3:3:6
```
"""
function getchunk(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)
    ichunk <= nchunks || throw(ArgumentError("ichunk must be less or equal to nchunks"))
    ichunk <= length(array) || throw(ArgumentError("ichunk must be less or equal to the length of `array`"))
    if type == :batch
        n = length(array)
        n_per_chunk, n_remaining = divrem(n, nchunks)
        first = firstindex(array) + (ichunk - 1) * n_per_chunk + ifelse(ichunk <= n_remaining, ichunk - 1, n_remaining)
        last = (first - 1) + n_per_chunk + ifelse(ichunk <= n_remaining, 1, 0)
        step = 1
    elseif type == :scatter
        first = (firstindex(array) - 1) + ichunk
        last = lastindex(array)
        step = nchunks
    else
        throw(ArgumentError("chunk type must be :batch or :scatter"))
    end
    return first:step:last
end

#
# Module for testing
#
module Testing
using ..ChunkSplitters
function test_chunks(; array_length, nchunks, type, result, return_ranges=false)
    ranges = collect(getchunk(rand(Int, array_length), i, nchunks, type) for i in 1:nchunks)
    if return_ranges
        return ranges
    else
        all(ranges .== result)
    end
end
function sum_parallel(x, nchunks, type)
    s = fill(zero(eltype(x)), nchunks)
    Threads.@threads for (range, ichunk) in chunks(x, nchunks, type)
        for i in range
            s[ichunk] += x[i]
        end
    end
    return sum(s)
end
function test_sum(; array_length, nchunks, type)
    x = rand(array_length)
    return sum_parallel(x, nchunks, type) ≈ sum(x)
end
end # module Testing

@testitem ":scatter" begin
    using ChunkSplitters
    using OffsetArrays
    import ChunkSplitters.Testing: test_chunks, test_sum
    @test test_chunks(; array_length=1, nchunks=1, type=:scatter, result=[1:1])
    @test test_chunks(; array_length=2, nchunks=1, type=:scatter, result=[1:2])
    @test test_chunks(; array_length=2, nchunks=2, type=:scatter, result=[1:1, 2:2])
    @test test_chunks(; array_length=3, nchunks=2, type=:scatter, result=[1:2:3, 2:2:2])
    @test test_chunks(; array_length=7, nchunks=3, type=:scatter, result=[1:3:7, 2:3:5, 3:3:6])
    @test test_chunks(; array_length=12, nchunks=4, type=:scatter, result=[1:4:9, 2:4:10, 3:4:11, 4:4:12])
    @test test_chunks(; array_length=15, nchunks=4, type=:scatter, result=[1:4:13, 2:4:14, 3:4:15, 4:4:12])
    @test test_sum(; array_length=1, nchunks=1, type=:scatter)
    @test test_sum(; array_length=2, nchunks=1, type=:scatter)
    @test test_sum(; array_length=2, nchunks=2, type=:scatter)
    @test test_sum(; array_length=3, nchunks=2, type=:scatter)
    @test test_sum(; array_length=7, nchunks=3, type=:scatter)
    @test test_sum(; array_length=12, nchunks=4, type=:scatter)
    @test test_sum(; array_length=15, nchunks=4, type=:scatter)
    @test test_sum(; array_length=117, nchunks=4, type=:scatter)
    x = OffsetArray(1:7, -1:5)
    @test collect.(getindex.(collect(chunks(x, 3, :scatter)), 1)) == [[-1, 2, 5], [0, 3], [1, 4]]
end

@testitem ":batch" begin
    using ChunkSplitters
    using OffsetArrays
    import ChunkSplitters.Testing: test_chunks, test_sum
    @test test_chunks(; array_length=1, nchunks=1, type=:batch, result=[1:1])
    @test test_chunks(; array_length=2, nchunks=1, type=:batch, result=[1:2])
    @test test_chunks(; array_length=2, nchunks=2, type=:batch, result=[1:1, 2:2])
    @test test_chunks(; array_length=3, nchunks=2, type=:batch, result=[1:2, 3:3])
    @test test_chunks(; array_length=7, nchunks=3, type=:batch, result=[1:3, 4:5, 6:7])
    @test test_chunks(; array_length=12, nchunks=4, type=:batch, result=[1:3, 4:6, 7:9, 10:12])
    @test test_chunks(; array_length=15, nchunks=4, type=:batch, result=[1:4, 5:8, 9:12, 13:15])
    @test test_sum(; array_length=1, nchunks=1, type=:batch)
    @test test_sum(; array_length=2, nchunks=1, type=:batch)
    @test test_sum(; array_length=2, nchunks=2, type=:batch)
    @test test_sum(; array_length=3, nchunks=2, type=:batch)
    @test test_sum(; array_length=7, nchunks=3, type=:batch)
    @test test_sum(; array_length=12, nchunks=4, type=:batch)
    @test test_sum(; array_length=15, nchunks=4, type=:batch)
    @test test_sum(; array_length=117, nchunks=4, type=:batch)
    x = OffsetArray(1:7, -1:5)
    @test collect.(getindex.(collect(chunks(x, 3, :batch)), 1)) == [[-1, 0, 1], [2, 3], [4, 5]]
end

@testitem "indexing" begin
    using ChunkSplitters
    c = chunks(1:5, 4)
    @test first(c) == (1:2, 1)
    @test last(c) == (5:5, 4)
    @test c[2] == (3:3, 2)
    @test length(c) == 4
    @test eltype(c) == UnitRange{Int64}
    for (ic, c) in enumerate(chunks(1:10, 2))
        if ic == 1
            @test c == (1:1:5, 1)
        elseif ic == 2
            @test c == (6:1:10, 2)
        end
    end
end

@testitem "chunk sizes" begin
    using ChunkSplitters

    # Sanity test for nchunks < array_length
    c = chunks(1:10, 2)
    @test length(c) == 2

    # When nchunks > array_length, we shouldn't create more chunks than array_length
    c = chunks(1:10, 20)
    @test length(c) == 10

    # And we shouldn't be able to get an out-of-bounds chunk
    @test_throws ArgumentError chunks(1:10, 20, 40)


end

@testitem "return type" begin
    @test typeof(getchunk(1:10, 1, 2, :batch)) == StepRange{Int64, Int64}
    @test typeof(getchunk(1:10, 1, 2, :scatter)) == StepRange{Int64, Int64}
    function mwe(ichunk=2, nchunks=5, n=10)
        xs = collect(1:n)
        ys = collect(1:n)
        cx = getchunk(xs, ichunk, nchunks, :batch)
        cy = getchunk(ys, ichunk, nchunks, :batch)
        return Iterators.zip(cx, cy)
    end
    @test @inferred mwe() == zip(3:1:4, 3:1:4)
    @test_throws ArgumentError getchunk(1:10, 1, 2, :error)
end

end # module ChunkSplitters
