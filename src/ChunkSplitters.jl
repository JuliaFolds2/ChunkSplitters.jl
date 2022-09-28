module ChunkSplitters

using TestItems

export splitter

"""

splitter(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)

Function that returns a range of indexes of `array`, given the number of chunks in
which the array is to be split, `nchunks`, and the current chunk number `ichunk`. 

If `type == :batch`, the ranges are consecutive. If `type == :scatter`, the range
is scattered over the array. 

## Examples

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
    n_remaining = n - nchunks*n_per_chunk
    first = firstindex(array) + (ichunk-1)*n_per_chunk + ifelse(ichunk <= n_remaining, ichunk - 1, n_remaining)
    last = (first - 1) + n_per_chunk + ifelse(ichunk <= n_remaining, 1, 0) 
    return first:last
end

#
# Module for testing
#
module Testing
    using ..ChunkSplitters
    function test_splitter(;array_length, nchunks, type, result, return_ranges=false)
        ranges = collect(splitter(rand(Int, array_length), i, nchunks, type) for i in 1:nchunks)
        if return_ranges
            return ranges
        else
            all(ranges .== result)
        end
    end
end

@testitem ":scatter" begin
    using ChunkSplitters
    import ChunkSplitters.Testing: test_splitter
    @test test_splitter(;array_length=1, nchunks=1, type=:scatter, result=[ 1:1 ])
    @test test_splitter(;array_length=2, nchunks=1, type=:scatter, result=[ 1:2 ])
    @test test_splitter(;array_length=2, nchunks=2, type=:scatter, result=[ 1:1, 2:2 ])
    @test test_splitter(;array_length=3, nchunks=2, type=:scatter, result=[ 1:2:3, 2:2:2 ])
    @test test_splitter(;array_length=7, nchunks=3, type=:scatter, result=[ 1:3:7, 2:3:5, 3:3:6 ])
    @test test_splitter(;array_length=12, nchunks=4, type=:scatter, result=[ 1:4:9, 2:4:10, 3:4:11, 4:4:12 ])
    @test test_splitter(;array_length=15, nchunks=4, type=:scatter, result=[ 1:4:13, 2:4:14, 3:4:15, 4:4:12 ])
end

@testitem ":batch" begin
    using ChunkSplitters
    import ChunkSplitters.Testing: test_splitter
    @test test_splitter(;array_length=1, nchunks=1, type=:batch, result=[ 1:1 ])
    @test test_splitter(;array_length=2, nchunks=1, type=:batch, result=[ 1:2 ])
    @test test_splitter(;array_length=2, nchunks=2, type=:batch, result=[ 1:1, 2:2 ])
    @test test_splitter(;array_length=3, nchunks=2, type=:batch, result=[ 1:2, 3:3 ])
    @test test_splitter(;array_length=7, nchunks=3, type=:batch, result=[ 1:3, 4:5, 6:7 ])
    @test test_splitter(;array_length=12, nchunks=4, type=:batch, result=[ 1:3, 4:6, 7:9, 10:12 ])
    @test test_splitter(;array_length=15, nchunks=4, type=:batch, result=[ 1:4, 5:8, 9:12, 13:15 ])
end

end # module ChunkSplitters
