using TestItemRunner: @run_package_tests
using TestItems: @testitem, @testsnippet

@run_package_tests

@testsnippet Testing begin
    using ChunkSplitters.Internals: getchunk

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

    function sum_parallel(x, n, size, split, which)
        if n === nothing
            d, r = divrem(length(x), size)
            nchunks = d + (r != 0)
        elseif size === nothing
            nchunks = n
        else
            throw(ArgumentError("both n and size === nothing"))
        end
        s = zeros(eltype(x), nchunks)
        if which == "chunk_indices"
            Threads.@threads for (ichunk, range) in enumerate(chunk_indices(x; n=n, size=size, split=split))
                s[ichunk] = sum(@view(x[range]))
            end
        elseif which == "chunk"
            Threads.@threads for (ichunk, xdata) in enumerate(chunk(x; n=n, size=size, split=split))
                s[ichunk] = sum(xdata)
            end
        else
            throw(ArgumentError("unsupported argument for which: $which"))
        end
        return sum(s)
    end

    function test_sum(; array_length, n, size, split)
        x = rand(array_length)
        a = sum_parallel(x, n, size, split, "chunk_indices") ≈ sum(x)
        b = sum_parallel(x, n, size, split, "chunk") ≈ sum(x)
        return a && b
    end
end

# -------- test items --------
@testitem "Aqua.test_all" begin
    import Aqua
    Aqua.test_all(ChunkSplitters)
end

# @testitem "Doctests" begin
#     using Documenter: doctest
#     doctest(ChunkSplitters)
# end

@testitem "BatchSplit" setup = [Testing] begin
    using OffsetArrays: OffsetArray
    # FixedCount
    @test test_chunk_indices(; array_length=1, n=1, size=nothing, split=BatchSplit(), result=[1:1])
    @test test_chunk_indices(; array_length=2, n=1, size=nothing, split=BatchSplit(), result=[1:2])
    @test test_chunk_indices(; array_length=2, n=2, size=nothing, split=BatchSplit(), result=[1:1, 2:2])
    @test test_chunk_indices(; array_length=3, n=2, size=nothing, split=BatchSplit(), result=[1:2, 3:3])
    @test test_chunk_indices(; array_length=7, n=3, size=nothing, split=BatchSplit(), result=[1:3, 4:5, 6:7])
    @test test_chunk_indices(; array_length=12, n=4, size=nothing, split=BatchSplit(), result=[1:3, 4:6, 7:9, 10:12])
    @test test_chunk_indices(; array_length=15, n=4, size=nothing, split=BatchSplit(), result=[1:4, 5:8, 9:12, 13:15])
    @test test_sum(; array_length=1, n=1, size=nothing, split=BatchSplit())
    @test test_sum(; array_length=2, n=1, size=nothing, split=BatchSplit())
    @test test_sum(; array_length=2, n=2, size=nothing, split=BatchSplit())
    @test test_sum(; array_length=3, n=2, size=nothing, split=BatchSplit())
    @test test_sum(; array_length=7, n=3, size=nothing, split=BatchSplit())
    @test test_sum(; array_length=12, n=4, size=nothing, split=BatchSplit())
    @test test_sum(; array_length=15, n=4, size=nothing, split=BatchSplit())
    @test test_sum(; array_length=117, n=4, size=nothing, split=BatchSplit())
    x = OffsetArray(1:7, -1:5)
    @test collect.(chunk_indices(x; n=3, split=BatchSplit())) == [[-1, 0, 1], [2, 3], [4, 5]]

    # FixedSize
    @test test_chunk_indices(; array_length=1, n=nothing, size=1, split=BatchSplit(), result=[1:1])
    @test test_chunk_indices(; array_length=2, n=nothing, size=2, split=BatchSplit(), result=[1:2])
    @test test_chunk_indices(; array_length=2, n=nothing, size=1, split=BatchSplit(), result=[1:1, 2:2])
    @test test_chunk_indices(; array_length=3, n=nothing, size=2, split=BatchSplit(), result=[1:2, 3:3])
    @test test_chunk_indices(; array_length=4, n=nothing, size=1, split=BatchSplit(), result=[1:1, 2:2, 3:3, 4:4])
    @test test_chunk_indices(; array_length=7, n=nothing, size=3, split=BatchSplit(), result=[1:3, 4:6, 7:7])
    @test test_chunk_indices(; array_length=7, n=nothing, size=4, split=BatchSplit(), result=[1:4, 5:7])
    @test test_chunk_indices(; array_length=7, n=nothing, size=5, split=BatchSplit(), result=[1:5, 6:7])
    @test test_chunk_indices(; array_length=12, n=nothing, size=3, split=BatchSplit(), result=[1:3, 4:6, 7:9, 10:12])
    @test test_chunk_indices(; array_length=15, n=nothing, size=4, split=BatchSplit(), result=[1:4, 5:8, 9:12, 13:15])
    @test test_sum(; array_length=1, n=nothing, size=1, split=BatchSplit())
    @test test_sum(; array_length=2, n=nothing, size=2, split=BatchSplit())
    @test test_sum(; array_length=2, n=nothing, size=1, split=BatchSplit())
    @test test_sum(; array_length=3, n=nothing, size=2, split=BatchSplit())
    @test test_sum(; array_length=4, n=nothing, size=1, split=BatchSplit())
    @test test_sum(; array_length=7, n=nothing, size=3, split=BatchSplit())
    @test test_sum(; array_length=7, n=nothing, size=4, split=BatchSplit())
    @test test_sum(; array_length=7, n=nothing, size=5, split=BatchSplit())
    @test test_sum(; array_length=12, n=nothing, size=3, split=BatchSplit())
    @test test_sum(; array_length=15, n=nothing, size=4, split=BatchSplit())
    x = OffsetArray(1:7, -1:5)
    @test collect.(chunk_indices(x; n=nothing, size=3, split=BatchSplit())) == [[-1, 0, 1], [2, 3, 4], [5]]
end

@testitem "ScatterSplit" setup = [Testing] begin
    using OffsetArrays: OffsetArray
    @test test_chunk_indices(; array_length=1, n=1, size=nothing, split=ScatterSplit(), result=[1:1])
    @test test_chunk_indices(; array_length=2, n=1, size=nothing, split=ScatterSplit(), result=[1:2])
    @test test_chunk_indices(; array_length=2, n=2, size=nothing, split=ScatterSplit(), result=[1:1, 2:2])
    @test test_chunk_indices(; array_length=3, n=2, size=nothing, split=ScatterSplit(), result=[1:2:3, 2:2:2])
    @test test_chunk_indices(; array_length=7, n=3, size=nothing, split=ScatterSplit(), result=[1:3:7, 2:3:5, 3:3:6])
    @test test_chunk_indices(; array_length=12, n=4, size=nothing, split=ScatterSplit(), result=[1:4:9, 2:4:10, 3:4:11, 4:4:12])
    @test test_chunk_indices(; array_length=15, n=4, size=nothing, split=ScatterSplit(), result=[1:4:13, 2:4:14, 3:4:15, 4:4:12])
    @test test_sum(; array_length=1, n=1, size=nothing, split=ScatterSplit())
    @test test_sum(; array_length=2, n=1, size=nothing, split=ScatterSplit())
    @test test_sum(; array_length=2, n=2, size=nothing, split=ScatterSplit())
    @test test_sum(; array_length=3, n=2, size=nothing, split=ScatterSplit())
    @test test_sum(; array_length=7, n=3, size=nothing, split=ScatterSplit())
    @test test_sum(; array_length=12, n=4, size=nothing, split=ScatterSplit())
    @test test_sum(; array_length=15, n=4, size=nothing, split=ScatterSplit())
    @test test_sum(; array_length=117, n=4, size=nothing, split=ScatterSplit())
    x = OffsetArray(1:7, -1:5)
    @test collect.(chunk_indices(x; n=3, split=ScatterSplit())) == [[-1, 2, 5], [0, 3], [1, 4]]

    # FixedSize
    @test_throws ArgumentError collect(chunk_indices(1:10; size=2, split=ScatterSplit())) # not supported (yet?)
end

@testitem "check input argument errors" begin
    for f in (chunk, chunk_indices)
        @testset "$f" begin
            @test_throws ArgumentError f(1:10)
            @test_throws ArgumentError f(1:10; n=nothing)
            @test_throws ArgumentError f(1:10; n=-1)
            @test_throws ArgumentError f(1:10; size=-1)
            @test_throws ArgumentError f(1:10; size=nothing)
            @test_throws ArgumentError f(1:10; n=5, size=2)
            @test_throws ArgumentError f(1:10; n=5, size=20)
            @test_throws TypeError f(1:10; n=2, split=:batch) # not supported anymore
        end
    end
end

@testitem "enumerate(chunk_indices(...))" begin
    using Base.Threads: @spawn, @threads, nthreads
    x = rand(100)
    s = zeros(nthreads())
    @threads for (ichunk, range) in enumerate(chunk_indices(x; n=nthreads()))
        for i in range
            s[ichunk] += x[i]
        end
    end
    @test sum(s) ≈ sum(x)

    s = zeros(nthreads())
    @sync for (ichunk, range) in enumerate(chunk_indices(x; n=nthreads()))
        @spawn begin
            for i in range
                s[ichunk] += x[i]
            end
        end
    end
    @test sum(s) ≈ sum(x)

    y = [1.0, 5.0, 7.0, 9.0, 3.0]
    # BatchSplit()
    @test collect(enumerate(chunk_indices(2:10; n=2))) == [(1, 1:5), (2, 6:9)]
    @test typeof(collect(enumerate(chunk_indices(2:10; n=2)))) == Vector{Tuple{Int64,UnitRange{Int64}}}
    @test collect(enumerate(chunk_indices(y; n=2))) == [(1, 1:3), (2, 4:5)]
    @test typeof(collect(enumerate(chunk_indices(y; n=2)))) <: (Vector{Tuple{Int64,T}} where {T<:UnitRange})
    @test eltype(enumerate(chunk_indices(2:10; n=2))) <: Tuple{Int64,UnitRange{Int64}}
    @test eltype(enumerate(chunk_indices(y; n=2))) <: Tuple{Int64,UnitRange}
    @test eachindex(enumerate(chunk_indices(2:10; n=3))) == 1:3
    @test eachindex(enumerate(chunk_indices(2:10; size=2))) == 1:5

    # ScatterSplit()
    @test collect(enumerate(chunk_indices(2:10; n=2, split=ScatterSplit()))) == [(1, 1:2:9), (2, 2:2:8)]
    @test typeof(collect(enumerate(chunk_indices(2:10; n=2, split=ScatterSplit())))) == Vector{Tuple{Int64,StepRange{Int64,Int64}}}
    @test collect(enumerate(chunk_indices(y; n=2, split=ScatterSplit()))) == [(1, 1:2:5), (2, 2:2:4)]
    @test typeof(collect(enumerate(chunk_indices(y; n=2, split=ScatterSplit())))) <: (Vector{Tuple{Int64,T}} where {T<:StepRange})
    @test eltype(enumerate(chunk_indices(2:10; n=2, split=ScatterSplit()))) <: Tuple{Int64,StepRange{Int64,Int64}}
    @test eltype(enumerate(chunk_indices(y; n=2, split=ScatterSplit()))) <: Tuple{Int64,StepRange}
    @test eachindex(enumerate(chunk_indices(2:10; n=3, split=ScatterSplit()))) == 1:3
end

@testitem "enumerate(chunk(...))" begin
    using Base.Threads: @spawn, @threads, nthreads
    x = rand(100)
    s = zeros(nthreads())
    @threads for (ichunk, xchunk) in enumerate(chunk(x; n=nthreads()))
        s[ichunk] += sum(xchunk)
    end
    @test sum(s) ≈ sum(x)

    s = zeros(nthreads())
    @sync for (ichunk, xchunk) in enumerate(chunk(x; n=nthreads()))
        @spawn s[ichunk] += sum(xchunk)
    end
    @test sum(s) ≈ sum(x)

    y = [1.0, 5.0, 7.0, 9.0, 3.0]
    # BatchSplit()
    @test collect(enumerate(chunk(2:10; n=2))) == [(1, 2:6), (2, 7:10)]
    @test typeof(collect(enumerate(chunk(2:10; n=2)))) == Vector{Tuple{Int64,UnitRange{Int64}}}
    @test collect(enumerate(chunk(y; n=2))) == [(1, [1.0, 5.0, 7.0]), (2, [9.0, 3.0])]
    @test typeof(collect(enumerate(chunk(y; n=2)))) <: (Vector{Tuple{Int64,T}} where {T<:SubArray})
    @test eltype(enumerate(chunk(2:10; n=2))) <: Tuple{Int64,UnitRange{Int64}}
    @test eltype(enumerate(chunk(y; n=2))) <: Tuple{Int64,SubArray}
    @test eachindex(enumerate(chunk(2:10; n=3))) == 1:3
    @test eachindex(enumerate(chunk(2:10; size=2))) == 1:5

    # ScatterSplit()
    @test collect(enumerate(chunk(2:10; n=2, split=ScatterSplit()))) == [(1, 2:2:10), (2, 3:2:9)]
    @test typeof(collect(enumerate(chunk(2:10; n=2, split=ScatterSplit())))) == Vector{Tuple{Int64,StepRange{Int64,Int64}}}
    @test collect(enumerate(chunk(y; n=2, split=ScatterSplit()))) == [(1, [1.0, 7.0, 3.0]), (2, [5.0, 9.0])]
    @test typeof(collect(enumerate(chunk(y; n=2, split=ScatterSplit())))) <: (Vector{Tuple{Int64,T}} where {T<:SubArray})
    @test eltype(enumerate(chunk(2:10; n=2, split=ScatterSplit()))) <: Tuple{Int64,StepRange{Int64,Int64}}
    @test eltype(enumerate(chunk(y; n=2, split=ScatterSplit()))) <: Tuple{Int64,SubArray}
    @test eachindex(enumerate(chunk(2:10; n=3, split=ScatterSplit()))) == 1:3
end

@testitem "ChunksIterator parametric types order" begin
    # Try not to break the order of the type parameters. ChunksIterator is
    # not public, but its being used by OhMyThreads.
    using ChunkSplitters.Internals: ChunksIterator
    using ChunkSplitters.Internals: FixedCount, BatchSplit, ReturnIndices, ReturnViews
    @test ChunksIterator{typeof(1:7),FixedCount,BatchSplit,ReturnIndices}(1:7, 3, 0) ==
          ChunksIterator{UnitRange{Int64},FixedCount,BatchSplit,ReturnIndices}(1:7, 3, 0)
    @test ChunksIterator{typeof(1:7),FixedCount,BatchSplit,ReturnViews}(1:7, 3, 0) ==
          ChunksIterator{UnitRange{Int64},FixedCount,BatchSplit,ReturnViews}(1:7, 3, 0)
end

@testitem "indexing" begin
    for f in (chunk, chunk_indices)
        @testset "$f" begin
            # FixedCount
            c = f(2:6; n=4)
            @test firstindex(c) == 1
            @test firstindex(enumerate(c)) == 1
            @test lastindex(c) == 4
            @test lastindex(enumerate(c)) == 4
            if f == chunk_indices
                @test first(c) == 1:2
                @test first(enumerate(c)) == (1, 1:2)
                @test last(c) == 5:5
                @test last(enumerate(c)) == (4, 5:5)
                @test c[2] == 3:3
            elseif f == chunk
                @test first(c) == 2:3
                @test first(enumerate(c)) == (1, 2:3)
                @test last(c) == 6:6
                @test last(enumerate(c)) == (4, 6:6)
                @test c[2] == 4:4
            end

            # FixedSize
            c = f(2:6; size=2)
            @test firstindex(c) == 1
            @test firstindex(enumerate(c)) == 1
            @test lastindex(c) == 3
            @test lastindex(enumerate(c)) == 3
            if f == chunk_indices
                @test first(c) == 1:2
                @test first(enumerate(c)) == (1, 1:2)
                @test last(c) == 5:5
                @test last(enumerate(c)) == (3, 5:5)
                @test c[2] == 3:4
            elseif f == chunk
                @test first(c) == 2:3
                @test first(enumerate(c)) == (1, 2:3)
                @test last(c) == 6:6
                @test last(enumerate(c)) == (3, 6:6)
                @test c[2] == 4:5
            end
        end
    end
end

@testitem "chunk sizes" begin
    for f in (chunk, chunk_indices)
        @testset "$f" begin
            # Sanity test for n < array_length
            c = f(2:11; n=2)
            @test length(c) == 2
            # When n > array_length, we shouldn't create more chunks than array_length
            c = f(2:11; n=20)
            @test length(c) == 10
            # And we shouldn't be able to get an out-of-bounds chunk
            @test length(f(zeros(15); n=5)) == 5 # number of chunks
            @test all(length.(f(zeros(15); n=5)) .== 3) # the length of each chunk

            # FixedSize
            c = f(2:11; size=5)
            @test length(c) == 2
            # When size > array_length, we shouldn't create more than one chunk
            c = f(2:11; size=20)
            @test length(c) == 1
            @test length(first(c)) == 10
            for (l, s) in [(13, 10), (5, 2), (42, 7), (22, 15)]
                local c = f(1:l; size=s)
                @test all(length(c[i]) == length(c[i+1]) for i in 1:length(c)-2) # only the last chunk may have different length
            end
            @test collect(f(1:10; n=2, minchunksize=2)) == [1:5, 6:10]
            @test collect(f(1:10; n=5, minchunksize=3)) == [1:4, 5:7, 8:10]
            @test collect(f(1:11; n=10, minchunksize=3)) == [1:4, 5:8, 9:11]
            @test_throws ArgumentError f(1:10; n=2, minchunksize=0)
            @test_throws ArgumentError f(1:10; size=2, minchunksize=2)
        end
    end
end

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
