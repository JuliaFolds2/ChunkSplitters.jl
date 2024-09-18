using TestItemRunner: @run_package_tests
using TestItems: @testitem

@run_package_tests

@testitem "Aqua.test_all" begin
    import Aqua
    Aqua.test_all(ChunkSplitters)
end

# @testitem "Doctests" begin
#     using Documenter: doctest
#     doctest(ChunkSplitters)
# end

# @testitem "ChunksIterator parametric types order" begin
#     # Try not to break the order of the type parameters. ChunksIterator is
#     # not part of the interface (currently), so its being used
#     # by OhMyThreads, so we probably should make it documented
#     using ChunkSplitters: ChunksIterator, FixedCount, BatchSplit
#     @test ChunksIterator{typeof(1:7),FixedCount,BatchSplit}(1:7, 3, 0) ==
#           ChunksIterator{UnitRange{Int64},FixedCount,BatchSplit}(1:7, 3, 0)
#     @test_throws TypeError ChunksIterator{typeof(1:7),BatchSplit,FixedCount}(1:7, 3, 0)
# end

# @testitem "enumerate chunks" begin
#     using ChunkSplitters: chunk_indices
#     using Base.Threads: @spawn, @threads, nthreads
#     x = rand(100)
#     s = zeros(nthreads())
#     @threads for (ichunk, range) in enumerate(chunk_indices(x; n=nthreads()))
#         for i in range
#             s[ichunk] += x[i]
#         end
#     end
#     @test sum(s) ≈ sum(x)
#     s = zeros(nthreads())
#     @sync for (ichunk, range) in enumerate(chunk_indices(x; n=nthreads()))
#         @spawn begin
#             for i in range
#                 s[ichunk] += x[i]
#             end
#         end
#     end
#     @test sum(s) ≈ sum(x)
#     @test collect(enumerate(chunk_indices(1:10; n=2))) == [(1, 1:5), (2, 6:10)]
#     @test collect(enumerate(chunk_indices(rand(7); n=3))) ==
#           Tuple{Int64,UnitRange{Int64}}[(1, 1:3), (2, 4:5), (3, 6:7)]
#     @test eltype(enumerate(chunk_indices(rand(7); n=3))) == Tuple{Int64,UnitRange{Int64}}
#     @test eltype(enumerate(chunk_indices(rand(7); n=3, split=:scatter))) == Tuple{Int64,StepRange{Int64,Int64}}
#     @test eachindex(enumerate(chunk_indices(1:10; n=3))) == 1:3
#     @test eachindex(enumerate(chunk_indices(1:10; size=2))) == 1:5
# end

#
# Module for testing
#
module Testing
using ChunkSplitters: chunk_indices, getchunk
function test_chunk_indices(; array_length, n, size, split, result)
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
    Threads.@threads for (ichunk, range) in enumerate(chunk_indices(x; n=n, size=size, split=split))
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

# @testitem "argument errors" begin
#     using ChunkSplitters: chunk_indices
#     @test_throws ArgumentError chunk_indices(1:10)
#     @test_throws ArgumentError chunk_indices(1:10; n=2, split=:not_batch)
#     @test_throws ArgumentError chunk_indices(1:10; n=nothing)
#     @test_throws ArgumentError chunk_indices(1:10; n=-1)
#     @test_throws ArgumentError chunk_indices(1:10; size=nothing)
#     @test_throws ArgumentError chunk_indices(1:10; n=5, size=2) # could be supported but we don't
#     @test_throws ArgumentError chunk_indices(1:10; n=5, size=20) # could be supported but we don't
# end

# @testitem ":scatter" begin
#     using ChunkSplitters: chunk_indices
#     using OffsetArrays: OffsetArray
#     using ChunkSplitters.Testing: test_chunks, test_sum
#     for split in (:scatter, ScatterSplit())
#         @test test_chunk_indices(; array_length=1, n=1, size=nothing, split=split, result=[1:1])
#         @test test_chunk_indices(; array_length=2, n=1, size=nothing, split=split, result=[1:2])
#         @test test_chunk_indices(; array_length=2, n=2, size=nothing, split=split, result=[1:1, 2:2])
#         @test test_chunk_indices(; array_length=3, n=2, size=nothing, split=split, result=[1:2:3, 2:2:2])
#         @test test_chunk_indices(; array_length=7, n=3, size=nothing, split=split, result=[1:3:7, 2:3:5, 3:3:6])
#         @test test_chunk_indices(; array_length=12, n=4, size=nothing, split=split, result=[1:4:9, 2:4:10, 3:4:11, 4:4:12])
#         @test test_chunk_indices(; array_length=15, n=4, size=nothing, split=split, result=[1:4:13, 2:4:14, 3:4:15, 4:4:12])
#         @test test_sum(; array_length=1, n=1, size=nothing, split=split)
#         @test test_sum(; array_length=2, n=1, size=nothing, split=split)
#         @test test_sum(; array_length=2, n=2, size=nothing, split=split)
#         @test test_sum(; array_length=3, n=2, size=nothing, split=split)
#         @test test_sum(; array_length=7, n=3, size=nothing, split=split)
#         @test test_sum(; array_length=12, n=4, size=nothing, split=split)
#         @test test_sum(; array_length=15, n=4, size=nothing, split=split)
#         @test test_sum(; array_length=117, n=4, size=nothing, split=split)
#         x = OffsetArray(1:7, -1:5)
#         @test collect.(chunk_indices(x; n=3, split=split)) == [[-1, 2, 5], [0, 3], [1, 4]]

#         # FixedSize
#         @test_throws ArgumentError collect(chunk_indices(1:10; size=2, split=split)) # not supported (yet?)
#     end
# end

# @testitem "BatchSplit()" begin
#     using ChunkSplitters: chunk_indices
#     using OffsetArrays: OffsetArray
#     using .Testing: test_chunks, test_sum
#     # FixedCount
#     @test test_chunk_indices(; array_length=1, n=1, size=nothing, split=BatchSplit(), result=[1:1])
#     @test test_chunk_indices(; array_length=2, n=1, size=nothing, split=BatchSplit(), result=[1:2])
#     @test test_chunk_indices(; array_length=2, n=2, size=nothing, split=BatchSplit(), result=[1:1, 2:2])
#     @test test_chunk_indices(; array_length=3, n=2, size=nothing, split=BatchSplit(), result=[1:2, 3:3])
#     @test test_chunk_indices(; array_length=7, n=3, size=nothing, split=BatchSplit(), result=[1:3, 4:5, 6:7])
#     @test test_chunk_indices(; array_length=12, n=4, size=nothing, split=BatchSplit(), result=[1:3, 4:6, 7:9, 10:12])
#     @test test_chunk_indices(; array_length=15, n=4, size=nothing, split=BatchSplit(), result=[1:4, 5:8, 9:12, 13:15])
#     @test test_sum(; array_length=1, n=1, size=nothing, split=BatchSplit())
#     @test test_sum(; array_length=2, n=1, size=nothing, split=BatchSplit())
#     @test test_sum(; array_length=2, n=2, size=nothing, split=BatchSplit())
#     @test test_sum(; array_length=3, n=2, size=nothing, split=BatchSplit())
#     @test test_sum(; array_length=7, n=3, size=nothing, split=BatchSplit())
#     @test test_sum(; array_length=12, n=4, size=nothing, split=BatchSplit())
#     @test test_sum(; array_length=15, n=4, size=nothing, split=BatchSplit())
#     @test test_sum(; array_length=117, n=4, size=nothing, split=BatchSplit())
#     x = OffsetArray(1:7, -1:5)
#     @test collect.(chunk_indices(x; n=3, split=BatchSplit())) == [[-1, 0, 1], [2, 3], [4, 5]]

#     # FixedSize
#     @test test_chunk_indices(; array_length=1, n=nothing, size=1, split=BatchSplit(), result=[1:1])
#     @test test_chunk_indices(; array_length=2, n=nothing, size=2, split=BatchSplit(), result=[1:2])
#     @test test_chunk_indices(; array_length=2, n=nothing, size=1, split=BatchSplit(), result=[1:1, 2:2])
#     @test test_chunk_indices(; array_length=3, n=nothing, size=2, split=BatchSplit(), result=[1:2, 3:3])
#     @test test_chunk_indices(; array_length=4, n=nothing, size=1, split=BatchSplit(), result=[1:1, 2:2, 3:3, 4:4])
#     @test test_chunk_indices(; array_length=7, n=nothing, size=3, split=BatchSplit(), result=[1:3, 4:6, 7:7])
#     @test test_chunk_indices(; array_length=7, n=nothing, size=4, split=BatchSplit(), result=[1:4, 5:7])
#     @test test_chunk_indices(; array_length=7, n=nothing, size=5, split=BatchSplit(), result=[1:5, 6:7])
#     @test test_chunk_indices(; array_length=12, n=nothing, size=3, split=BatchSplit(), result=[1:3, 4:6, 7:9, 10:12])
#     @test test_chunk_indices(; array_length=15, n=nothing, size=4, split=BatchSplit(), result=[1:4, 5:8, 9:12, 13:15])
#     @test test_sum(; array_length=1, n=nothing, size=1, split=BatchSplit())
#     @test test_sum(; array_length=2, n=nothing, size=2, split=BatchSplit())
#     @test test_sum(; array_length=2, n=nothing, size=1, split=BatchSplit())
#     @test test_sum(; array_length=3, n=nothing, size=2, split=BatchSplit())
#     @test test_sum(; array_length=4, n=nothing, size=1, split=BatchSplit())
#     @test test_sum(; array_length=7, n=nothing, size=3, split=BatchSplit())
#     @test test_sum(; array_length=7, n=nothing, size=4, split=BatchSplit())
#     @test test_sum(; array_length=7, n=nothing, size=5, split=BatchSplit())
#     @test test_sum(; array_length=12, n=nothing, size=3, split=BatchSplit())
#     @test test_sum(; array_length=15, n=nothing, size=4, split=BatchSplit())
#     x = OffsetArray(1:7, -1:5)
#     @test collect.(chunk_indices(x; n=nothing, size=3, split=BatchSplit())) == [[-1, 0, 1], [2, 3, 4], [5]]
# end

# @testitem "indexing" begin
#     using ChunkSplitters: chunk_indices
#     # FixedCount
#     c = chunk_indices(1:5; n=4)
#     @test firstindex(c) == 1
#     @test firstindex(enumerate(c)) == 1
#     @test lastindex(c) == 4
#     @test lastindex(enumerate(c)) == 4
#     @test first(c) == 1:2
#     @test first(enumerate(c)) == (1, 1:2)
#     @test last(c) == 5:5
#     @test last(enumerate(c)) == (4, 5:5)
#     @test c[2] == 3:3
#     for (ic, c) in enumerate(chunk_indices(1:10; n=2))
#         if ic == 1
#             @test c == 1:5
#         elseif ic == 2
#             @test c == 6:10
#         end
#     end

#     # FixedSize
#     c = chunk_indices(1:5; size=2)
#     @test firstindex(c) == 1
#     @test firstindex(enumerate(c)) == 1
#     @test lastindex(c) == 3
#     @test lastindex(enumerate(c)) == 3
#     @test first(c) == 1:2
#     @test first(enumerate(c)) == (1, 1:2)
#     @test last(c) == 5:5
#     @test last(enumerate(c)) == (3, 5:5)
#     @test c[2] == 3:4
#     for (ic, c) in enumerate(chunk_indices(1:10; size=5))
#         if ic == 1
#             @test c == 1:5
#         elseif ic == 2
#             @test c == 6:10
#         end
#     end
# end

# @testitem "chunk sizes" begin
#     using ChunkSplitters: chunk_indices
#     # Sanity test for n < array_length
#     c = chunk_indices(1:10; n=2)
#     @test length(c) == 2
#     # When n > array_length, we shouldn't create more chunks than array_length
#     c = chunk_indices(1:10; n=20)
#     @test length(c) == 10
#     # And we shouldn't be able to get an out-of-bounds chunk
#     @test length(chunk_indices(zeros(15); n=5)) == 5 # number of chunks
#     @test all(length.(chunk_indices(zeros(15); n=5)) .== 3) # the length of each chunk

#     # FixedSize
#     c = chunk_indices(1:10; size=5)
#     @test length(c) == 2
#     # When size > array_length, we shouldn't create more than one chunk
#     c = chunk_indices(1:10; size=20)
#     @test length(c) == 1
#     @test length(first(c)) == 10
#     for (l, s) in [(13, 10), (5, 2), (42, 7), (22, 15)]
#         local c = chunk_indices(1:l; size=s)
#         @test all(length(c[i]) == length(c[i+1]) for i in 1:length(c)-2) # only the last chunk may have different length
#     end
#     @test collect(chunk_indices(1:10; n=2, minchunksize=2)) == [1:5, 6:10]
#     @test collect(chunk_indices(1:10; n=5, minchunksize=3)) == [1:4, 5:7, 8:10]
#     @test collect(chunk_indices(1:11; n=10, minchunksize=3)) == [1:4, 5:8, 9:11]
#     @test_throws ArgumentError chunk_indices(1:10; n=2, minchunksize=0)
#     @test_throws ArgumentError chunk_indices(1:10; size=2, minchunksize=2)
# end

# @testitem "return type" begin
#     using ChunkSplitters: chunk_indices, getchunk
#     using BenchmarkTools: @benchmark
#     @test typeof(getchunk(1:10, 1; n=2, split=:batch)) == UnitRange{Int}
#     @test typeof(getchunk(1:10, 1; size=2, split=:batch)) == UnitRange{Int}
#     @test typeof(getchunk(1:10, 1; n=2, split=:scatter)) == StepRange{Int,Int}
#     function mwe(ichunk=2, n=5, l=10)
#         xs = collect(1:l)
#         ys = collect(1:l)
#         cx = getchunk(xs, ichunk; n=n, split=:batch)
#         cy = getchunk(ys, ichunk; n=n, split=:batch)
#         return Iterators.zip(cx, cy)
#     end
#     function mwe_size(ichunk=2, size=2, l=10)
#         xs = collect(1:l)
#         ys = collect(1:l)
#         cx = getchunk(xs, ichunk; size=size, split=:batch)
#         cy = getchunk(ys, ichunk; size=size, split=:batch)
#         return Iterators.zip(cx, cy)
#     end
#     @test zip(3:4, 3:4) == @inferred mwe()
#     @test zip(3:4, 3:4) == @inferred mwe_size()
#     @test_throws ArgumentError getchunk(1:10, 1; n=2, split=:error)
#     x = rand(10)
#     @test typeof(first(chunk_indices(x; n=5))) == UnitRange{Int}
#     @test eltype(chunk_indices(x; n=5)) == UnitRange{Int}
#     @test typeof(first(chunk_indices(x; size=2))) == UnitRange{Int}
#     @test eltype(chunk_indices(x; n=2)) == UnitRange{Int}
#     # Empty iterator
#     @test getchunk(10:9, 1; n=2) === 0:-1
#     @test getchunk(10:9, 1; size=2) === 0:-1
#     @test getchunk(10:9, 1; n=2, split=:scatter) === 0:1:-1
#     @test getchunk(10:9, 1; size=2, split=:scatter) === 0:1:-1
#     @test collect(chunk_indices(10:9; n=2)) == Vector{UnitRange{Int}}()
#     @test collect(chunk_indices(10:9; size=2)) == Vector{UnitRange{Int}}()
#     @test collect(enumerate(chunk_indices(10:9; n=2))) == Tuple{Int64,Vector{UnitRange{Int}}}[]
#     @test collect(enumerate(chunk_indices(10:9; size=2))) == Tuple{Int64,Vector{UnitRange{Int}}}[]
#     @test collect(chunk_indices(10:9; n=2, split=:scatter)) == Vector{StepRange{Int,Int}}()
#     @test collect(chunk_indices(10:9; size=2, split=:scatter)) == Vector{StepRange{Int,Int}}()
#     @test collect(enumerate(chunk_indices(10:9; n=2, split=:scatter))) == Tuple{Int64,Vector{StepRange{Int,Int}}}[]
#     @test collect(enumerate(chunk_indices(10:9; size=2, split=:scatter))) == Tuple{Int64,Vector{StepRange{Int,Int}}}[]
#     # test inference of chunks
#     f() = chunk_indices(1:7; n=4)
#     @test f() == @inferred f()
#     f() = chunk_indices(1:7; n=4, split=:scatter)
#     @test f() == @inferred f()
#     f() = chunk_indices(1:7; size=4, split=:scatter)
#     @test f() == @inferred f()
#     function f(x; n=nothing, size=nothing)
#         s = zero(eltype(x))
#         for inds in chunk_indices(x; n=n, size=size)
#             for i in inds
#                 s += x[i]
#             end
#         end
#         return s
#     end
#     x = rand(10^3)
#     b = @benchmark f($x; n=4) samples = 1 evals = 1
#     @test b.allocs == 0
#     b = @benchmark f($x; size=10) samples = 1 evals = 1
#     @test b.allocs == 0
# end

# @testitem "Minimial interface" begin
#     using ChunkSplitters: chunk_indicesplitters, chunks
#     struct MinimalInterface end
#     Base.firstindex(::MinimalInterface) = 1
#     Base.lastindex(::MinimalInterface) = 7
#     Base.length(::MinimalInterface) = 7
#     ChunkSplitters.is_chunkable(::MinimalInterface) = true
#     x = MinimalInterface()
#     @test collect(chunk_indices(x; n=3)) == [1:3, 4:5, 6:7]
#     @test collect(enumerate(chunk_indices(x; n=3))) == [(1, 1:3), (2, 4:5), (3, 6:7)]
#     @test eltype(enumerate(chunk_indices(x; n=3))) == Tuple{Int64,UnitRange{Int}}
#     @test typeof(first(chunk_indices(x; n=3))) == UnitRange{Int}
#     @test collect(chunk_indices(x; n=3, split=ScatterSplit())) == [1:3:7, 2:3:5, 3:3:6]
#     @test collect(enumerate(chunk_indices(x; n=3, split=ScatterSplit()))) == [(1, 1:3:7), (2, 2:3:5), (3, 3:3:6)]
#     @test eltype(enumerate(chunk_indices(x; n=3, split=ScatterSplit()))) == Tuple{Int64,StepRange{Int64,Int64}}
# end
