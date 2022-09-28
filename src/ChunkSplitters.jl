module ChunkSplitters

using TestItems

export splitter

"""

    splitter(array::AbstractArray, nchunks::Int, type::Symbol=:batch)

This function returns an iterable object that will split the *indices* of `array` into
to `nchunks` chunks. `type` can be `:batch` or `:scatter`. It can be used to directly iterate
over the chunks of a collection in a multi-threaded manner.

## Eample

```julia-repl
julia> using ChunkSplitters 

julia> x = rand(7);

julia> Threads.@threads for i in splitter(x, 3, :batch)
    @show Threads.threadid(), collect(i)
end
(Threads.threadid(), collect(i)) = (6, [1, 2, 3])
(Threads.threadid(), collect(i)) = (8, [4, 5])
(Threads.threadid(), collect(i)) = (7, [6, 7])

julia> Threads.@threads for i in splitter(x, 3, :scatter)
    @show Threads.threadid(), collect(i)
end
(Threads.threadid(), collect(i)) = (2, [1, 4, 7])
(Threads.threadid(), collect(i)) = (11, [2, 5])
(Threads.threadid(), collect(i)) = (3, [3, 6])
```


"""
function splitter end

# Current splitter types
const splitter_types = (:batch, :scatter)

# Structure that carries the splitter data
struct Splitter{I,N,T}
    x::I
    nchunks::Int
end

# Constructor for the splitter
function splitter(x::AbstractArray, nchunks::Int, type=:batch)
    nchunks >= 1 || throw(ArgumentError("nchunks must be >= 1"))
    (type in splitter_types) || throw(ArgumentError("type must be one of $splitter_types"))
    Splitter{typeof(x),nchunks,type}(x, nchunks)
end

import Base: length, eltype
length(::Splitter{I,N}) where {I,N} = N
eltype(::Splitter) = UnitRange{Int}

import Base: firstindex, lastindex, getindex
firstindex(::Splitter) = 1
lastindex(::Splitter{I,N}) where {I,N} = N
getindex(it::Splitter{I,N,T}, i::Int) where {I,N,T} = (splitter(it.x, i, it.nchunks, T), i)

#
# Iteration of the splitter
#
import Base: iterate
function iterate(it::Splitter{I,N,T}, state=nothing; type=:batch) where {I,N,T}
    if isnothing(state)
        return ((splitter(it.x, 1, it.nchunks, T), 1), 1)
    elseif state < it.nchunks
        return ((splitter(it.x, state + 1, it.nchunks, T), state + 1), state + 1)
    else
        return nothing
    end
end

#
# This is the lower level function that receives `ichunk` as a parameter
#
"""
    splitter(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)

# Extended help

Function that returns a range of indexes of `array`, given the number of chunks in
which the array is to be split, `nchunks`, and the current chunk number `ichunk`. 

If `type == :batch`, the ranges are consecutive. If `type == :scatter`, the range
is scattered over the array. 

## Example

For example, if we have an array of 7 elements, and the work on the elements is divided
into 3 chunks, we have (using the default `type = :batch` option):

```julia-repl
julia> using ChunkSplitters

julia> x = rand(7);

julia> splitter(x, 1, 3)
1:3

julia> splitter(x, 2, 3)
4:5

julia> splitter(x, 3, 3)
6:7
```

And using `type = :scatter`, we have:

```julia-repl
julia> splitter(x, 1, 3, :scatter)
1:3:7

julia> splitter(x, 2, 3, :scatter)
2:3:5

julia> splitter(x, 3, 3, :scatter)
3:3:6
```
"""
function splitter(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)
    ichunk <= nchunks || throw(ArgumentError("ichunk must be less or equal to nchunks"))
    return _splitter(array, ichunk, nchunks, Val(type))
end

#
# function that splits the work in chunks that are scattered over the array
#
function _splitter(array, ichunk, nchunks, ::Val{:scatter})
    first = (firstindex(array) - 1) + ichunk
    last = lastindex(array)
    step = nchunks
    return first:step:last
end

#
# function that splits the work in batches that are consecutive in the array
#
function _splitter(array, ichunk, nchunks, ::Val{:batch})
    n = length(array)
    n_per_chunk = div(n, nchunks)
    n_remaining = n - nchunks * n_per_chunk
    first = firstindex(array) + (ichunk - 1) * n_per_chunk + ifelse(ichunk <= n_remaining, ichunk - 1, n_remaining)
    last = (first - 1) + n_per_chunk + ifelse(ichunk <= n_remaining, 1, 0)
    return first:last
end

#
# Module for testing
#
module Testing
using ..ChunkSplitters
function test_splitter(; array_length, nchunks, type, result, return_ranges=false)
    ranges = collect(splitter(rand(Int, array_length), i, nchunks, type) for i in 1:nchunks)
    if return_ranges
        return ranges
    else
        all(ranges .== result)
    end
end
function sum_parallel(x, nchunks, type)
    s = fill(zero(eltype(x)), nchunks)  
    Threads.@threads for (range, ichunk) in splitter(x, nchunks, type)
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
    import ChunkSplitters.Testing: test_splitter, test_sum
    @test test_splitter(; array_length=1, nchunks=1, type=:scatter, result=[1:1])
    @test test_splitter(; array_length=2, nchunks=1, type=:scatter, result=[1:2])
    @test test_splitter(; array_length=2, nchunks=2, type=:scatter, result=[1:1, 2:2])
    @test test_splitter(; array_length=3, nchunks=2, type=:scatter, result=[1:2:3, 2:2:2])
    @test test_splitter(; array_length=7, nchunks=3, type=:scatter, result=[1:3:7, 2:3:5, 3:3:6])
    @test test_splitter(; array_length=12, nchunks=4, type=:scatter, result=[1:4:9, 2:4:10, 3:4:11, 4:4:12])
    @test test_splitter(; array_length=15, nchunks=4, type=:scatter, result=[1:4:13, 2:4:14, 3:4:15, 4:4:12])
    @test test_sum(; array_length=1, nchunks=1, type=:scatter)
    @test test_sum(; array_length=2, nchunks=1, type=:scatter)
    @test test_sum(; array_length=2, nchunks=2, type=:scatter)
    @test test_sum(; array_length=3, nchunks=2, type=:scatter)
    @test test_sum(; array_length=7, nchunks=3, type=:scatter)
    @test test_sum(; array_length=12, nchunks=4, type=:scatter)
    @test test_sum(; array_length=15, nchunks=4, type=:scatter)
    @test test_sum(; array_length=117, nchunks=4, type=:scatter)
end

@testitem ":batch" begin
    using ChunkSplitters
    import ChunkSplitters.Testing: test_splitter, test_sum
    @test test_splitter(; array_length=1, nchunks=1, type=:batch, result=[1:1])
    @test test_splitter(; array_length=2, nchunks=1, type=:batch, result=[1:2])
    @test test_splitter(; array_length=2, nchunks=2, type=:batch, result=[1:1, 2:2])
    @test test_splitter(; array_length=3, nchunks=2, type=:batch, result=[1:2, 3:3])
    @test test_splitter(; array_length=7, nchunks=3, type=:batch, result=[1:3, 4:5, 6:7])
    @test test_splitter(; array_length=12, nchunks=4, type=:batch, result=[1:3, 4:6, 7:9, 10:12])
    @test test_splitter(; array_length=15, nchunks=4, type=:batch, result=[1:4, 5:8, 9:12, 13:15])
    @test test_sum(; array_length=1, nchunks=1, type=:batch)
    @test test_sum(; array_length=2, nchunks=1, type=:batch)
    @test test_sum(; array_length=2, nchunks=2, type=:batch)
    @test test_sum(; array_length=3, nchunks=2, type=:batch)
    @test test_sum(; array_length=7, nchunks=3, type=:batch)
    @test test_sum(; array_length=12, nchunks=4, type=:batch)
    @test test_sum(; array_length=15, nchunks=4, type=:batch)
    @test test_sum(; array_length=117, nchunks=4, type=:batch)
end

end # module ChunkSplitters
