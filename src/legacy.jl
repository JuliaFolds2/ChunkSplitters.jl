#
# This file contains the interface for the 2.0 series of ChunkSplitters.jl
#
# This interface will be deprecated in the future version 3.0, but it is kept here for
# backwards compatibility.
#

# Structure that carries the chunks data
struct ChunkLegacy{T<:AbstractArray}
    x::T
    nchunks::Int
    type::Symbol
end

# Constructor for the chunks
function chunks(x::AbstractArray, nchunks::Int, type=:batch)
    nchunks >= 1 || throw(ArgumentError("nchunks must be >= 1"))
    (type in split_types) || throw(ArgumentError("type must be one of $split_types"))
    ChunkLegacy{typeof(x)}(x, min(length(x), nchunks), type)
end

Base.length(c::ChunkLegacy) = c.nchunks
Base.eltype(::ChunkLegacy) = Tuple{StepRange{Int,Int},Int}

@testitem "length, eltype" begin
    x = rand(10)
    @test typeof(first(chunks(x, 5))) == Tuple{StepRange{Int,Int},Int}
    @test eltype(chunks(x, 5)) == Tuple{StepRange{Int,Int},Int}
    @test length(chunks(x, 5)) == 5
end

Base.firstindex(::ChunkLegacy) = 1
Base.lastindex(c::ChunkLegacy) = c.nchunks
Base.getindex(c::ChunkLegacy, i::Int) = (getchunk(c.x, i, c.nchunks, c.type), i)
Base.collect(c::ChunkLegacy) = [(getchunk(c.x, i, c.nchunks, c.type), i) for i in 1:c.nchunks]

#
# Iteration of the chunks
#
function Base.iterate(c::ChunkLegacy, state=nothing)
    if isnothing(state)
        return ((getchunk(c.x, 1, c.nchunks, c.type), 1), 1)
    elseif state < c.nchunks
        return ((getchunk(c.x, state + 1, c.nchunks, c.type), state + 1), state + 1)
    else
        return nothing
    end
end

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

module TestingLegacy
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
    import ChunkSplitters.TestingLegacy: test_chunks, test_sum
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
    import ChunkSplitters.TestingLegacy: test_chunks, test_sum
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
    @test typeof(getchunk(1:10, 1, 2, :batch)) == StepRange{Int,Int}
    @test typeof(getchunk(1:10, 1, 2, :scatter)) == StepRange{Int,Int}
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
