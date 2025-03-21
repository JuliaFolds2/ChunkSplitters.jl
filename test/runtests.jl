using TestItemRunner: @run_package_tests
using TestItems: @testitem, @testsnippet

@run_package_tests

@testsnippet Testing begin
    function test_index_chunks(; array_length, n, size, split, result)
        if n === nothing
            d, r = divrem(array_length, size)
            nchunks = d + (r != 0)
        elseif size === nothing
            nchunks = n
        else
            throw(ArgumentError("both n and size === nothing"))
        end
        c = index_chunks(rand(Int, array_length); n=n, size=size, split=split)
        ranges = [c[i] for i in 1:nchunks]
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
        if which == "index_chunks"
            Threads.@threads for (ichunk, range) in enumerate(index_chunks(x; n=n, size=size, split=split))
                s[ichunk] = sum(@view(x[range]))
            end
        elseif which == "chunk"
            Threads.@threads for (ichunk, xdata) in enumerate(chunks(x; n=n, size=size, split=split))
                s[ichunk] = sum(xdata)
            end
        else
            throw(ArgumentError("unsupported argument for which: $which"))
        end
        return sum(s)
    end

    function test_sum(; array_length, n, size, split)
        x = rand(array_length)
        a = sum_parallel(x, n, size, split, "index_chunks") ≈ sum(x)
        b = sum_parallel(x, n, size, split, "chunk") ≈ sum(x)
        return a && b
    end
end

# -------- test items --------
@testitem "Aqua.test_all" begin
    import Aqua
    Aqua.test_all(ChunkSplitters)
end

@testitem "Doctests" begin
    using Documenter: doctest
    doctest(ChunkSplitters)
end

@testitem "Consecutive" setup = [Testing] begin
    using OffsetArrays: OffsetArray
    # FixedCount
    @test test_index_chunks(; array_length=1, n=1, size=nothing, split=Consecutive(), result=[1:1])
    @test test_index_chunks(; array_length=2, n=1, size=nothing, split=Consecutive(), result=[1:2])
    @test test_index_chunks(; array_length=2, n=2, size=nothing, split=Consecutive(), result=[1:1, 2:2])
    @test test_index_chunks(; array_length=3, n=2, size=nothing, split=Consecutive(), result=[1:2, 3:3])
    @test test_index_chunks(; array_length=7, n=3, size=nothing, split=Consecutive(), result=[1:3, 4:5, 6:7])
    @test test_index_chunks(; array_length=12, n=4, size=nothing, split=Consecutive(), result=[1:3, 4:6, 7:9, 10:12])
    @test test_index_chunks(; array_length=15, n=4, size=nothing, split=Consecutive(), result=[1:4, 5:8, 9:12, 13:15])
    @test test_sum(; array_length=1, n=1, size=nothing, split=Consecutive())
    @test test_sum(; array_length=2, n=1, size=nothing, split=Consecutive())
    @test test_sum(; array_length=2, n=2, size=nothing, split=Consecutive())
    @test test_sum(; array_length=3, n=2, size=nothing, split=Consecutive())
    @test test_sum(; array_length=7, n=3, size=nothing, split=Consecutive())
    @test test_sum(; array_length=12, n=4, size=nothing, split=Consecutive())
    @test test_sum(; array_length=15, n=4, size=nothing, split=Consecutive())
    @test test_sum(; array_length=117, n=4, size=nothing, split=Consecutive())
    x = OffsetArray(1:7, -1:5)
    @test collect.(index_chunks(x; n=3, split=Consecutive())) == [[-1, 0, 1], [2, 3], [4, 5]]

    # FixedSize
    @test test_index_chunks(; array_length=1, n=nothing, size=1, split=Consecutive(), result=[1:1])
    @test test_index_chunks(; array_length=2, n=nothing, size=2, split=Consecutive(), result=[1:2])
    @test test_index_chunks(; array_length=2, n=nothing, size=1, split=Consecutive(), result=[1:1, 2:2])
    @test test_index_chunks(; array_length=3, n=nothing, size=2, split=Consecutive(), result=[1:2, 3:3])
    @test test_index_chunks(; array_length=4, n=nothing, size=1, split=Consecutive(), result=[1:1, 2:2, 3:3, 4:4])
    @test test_index_chunks(; array_length=7, n=nothing, size=3, split=Consecutive(), result=[1:3, 4:6, 7:7])
    @test test_index_chunks(; array_length=7, n=nothing, size=4, split=Consecutive(), result=[1:4, 5:7])
    @test test_index_chunks(; array_length=7, n=nothing, size=5, split=Consecutive(), result=[1:5, 6:7])
    @test test_index_chunks(; array_length=12, n=nothing, size=3, split=Consecutive(), result=[1:3, 4:6, 7:9, 10:12])
    @test test_index_chunks(; array_length=15, n=nothing, size=4, split=Consecutive(), result=[1:4, 5:8, 9:12, 13:15])
    @test test_sum(; array_length=1, n=nothing, size=1, split=Consecutive())
    @test test_sum(; array_length=2, n=nothing, size=2, split=Consecutive())
    @test test_sum(; array_length=2, n=nothing, size=1, split=Consecutive())
    @test test_sum(; array_length=3, n=nothing, size=2, split=Consecutive())
    @test test_sum(; array_length=4, n=nothing, size=1, split=Consecutive())
    @test test_sum(; array_length=7, n=nothing, size=3, split=Consecutive())
    @test test_sum(; array_length=7, n=nothing, size=4, split=Consecutive())
    @test test_sum(; array_length=7, n=nothing, size=5, split=Consecutive())
    @test test_sum(; array_length=12, n=nothing, size=3, split=Consecutive())
    @test test_sum(; array_length=15, n=nothing, size=4, split=Consecutive())
    x = OffsetArray(1:7, -1:5)
    @test collect.(index_chunks(x; n=nothing, size=3, split=Consecutive())) == [[-1, 0, 1], [2, 3, 4], [5]]
end

@testitem "RoundRobin" setup = [Testing] begin
    using OffsetArrays: OffsetArray
    @test test_index_chunks(; array_length=1, n=1, size=nothing, split=RoundRobin(), result=[1:1])
    @test test_index_chunks(; array_length=2, n=1, size=nothing, split=RoundRobin(), result=[1:2])
    @test test_index_chunks(; array_length=2, n=2, size=nothing, split=RoundRobin(), result=[1:1, 2:2])
    @test test_index_chunks(; array_length=3, n=2, size=nothing, split=RoundRobin(), result=[1:2:3, 2:2:2])
    @test test_index_chunks(; array_length=7, n=3, size=nothing, split=RoundRobin(), result=[1:3:7, 2:3:5, 3:3:6])
    @test test_index_chunks(; array_length=12, n=4, size=nothing, split=RoundRobin(), result=[1:4:9, 2:4:10, 3:4:11, 4:4:12])
    @test test_index_chunks(; array_length=15, n=4, size=nothing, split=RoundRobin(), result=[1:4:13, 2:4:14, 3:4:15, 4:4:12])
    @test test_sum(; array_length=1, n=1, size=nothing, split=RoundRobin())
    @test test_sum(; array_length=2, n=1, size=nothing, split=RoundRobin())
    @test test_sum(; array_length=2, n=2, size=nothing, split=RoundRobin())
    @test test_sum(; array_length=3, n=2, size=nothing, split=RoundRobin())
    @test test_sum(; array_length=7, n=3, size=nothing, split=RoundRobin())
    @test test_sum(; array_length=12, n=4, size=nothing, split=RoundRobin())
    @test test_sum(; array_length=15, n=4, size=nothing, split=RoundRobin())
    @test test_sum(; array_length=117, n=4, size=nothing, split=RoundRobin())
    x = OffsetArray(1:7, -1:5)
    @test collect.(index_chunks(x; n=3, split=RoundRobin())) == [[-1, 2, 5], [0, 3], [1, 4]]

    # FixedSize
    @test_throws ArgumentError collect(index_chunks(1:10; size=2, split=RoundRobin())) # not supported (yet?)
end

@testitem "check input argument errors" begin
    for f in (chunks, index_chunks)
        @testset "$f" begin
            @test_throws ArgumentError f(1:10)
            @test_throws ArgumentError f(1:10; n=nothing)
            @test_throws ArgumentError f(1:10; n=-1)
            @test_throws ArgumentError f(1:10; size=-1)
            @test_throws ArgumentError f(1:10; size=nothing)
            @test_throws ArgumentError f(1:10; n=5, size=2)
            @test_throws ArgumentError f(1:10; n=5, size=20)
            @test_throws TypeError f(1:10; n=2, split=:scatter) # not supported anymore
            @test_throws BoundsError f(0:-1; n=2)[1]
            @test_throws BoundsError f(1:10; n=2)[3]
        end
    end
end

@testitem "enumerate(index_chunks(...))" begin
    using Base.Threads: @spawn, @threads, nthreads
    x = rand(100)
    s = zeros(nthreads())
    @threads for (ichunk, range) in enumerate(index_chunks(x; n=nthreads()))
        for i in range
            s[ichunk] += x[i]
        end
    end
    @test sum(s) ≈ sum(x)

    s = zeros(nthreads())
    @sync for (ichunk, range) in enumerate(index_chunks(x; n=nthreads()))
        @spawn begin
            for i in range
                s[ichunk] += x[i]
            end
        end
    end
    @test sum(s) ≈ sum(x)

    y = [1.0, 5.0, 7.0, 9.0, 3.0]
    # Consecutive()
    @test collect(enumerate(index_chunks(2:10; n=2))) == [(1, 1:5), (2, 6:9)]
    @test typeof(collect(enumerate(index_chunks(2:10; n=2)))) == Vector{Tuple{Int64,UnitRange{Int64}}}
    @test collect(enumerate(index_chunks(y; n=2))) == [(1, 1:3), (2, 4:5)]
    @test typeof(collect(enumerate(index_chunks(y; n=2)))) <: (Vector{Tuple{Int64,T}} where {T<:UnitRange})
    @test eltype(enumerate(index_chunks(2:10; n=2))) <: Tuple{Int64,UnitRange{Int64}}
    @test eltype(enumerate(index_chunks(y; n=2))) <: Tuple{Int64,UnitRange}
    @test eachindex(enumerate(index_chunks(2:10; n=3))) == 1:3
    @test eachindex(enumerate(index_chunks(2:10; size=2))) == 1:5

    # RoundRobin()
    @test collect(enumerate(index_chunks(2:10; n=2, split=RoundRobin()))) == [(1, 1:2:9), (2, 2:2:8)]
    @test typeof(collect(enumerate(index_chunks(2:10; n=2, split=RoundRobin())))) == Vector{Tuple{Int64,StepRange{Int64,Int64}}}
    @test collect(enumerate(index_chunks(y; n=2, split=RoundRobin()))) == [(1, 1:2:5), (2, 2:2:4)]
    @test typeof(collect(enumerate(index_chunks(y; n=2, split=RoundRobin())))) <: (Vector{Tuple{Int64,T}} where {T<:StepRange})
    @test eltype(enumerate(index_chunks(2:10; n=2, split=RoundRobin()))) <: Tuple{Int64,StepRange{Int64,Int64}}
    @test eltype(enumerate(index_chunks(y; n=2, split=RoundRobin()))) <: Tuple{Int64,StepRange}
    @test eachindex(enumerate(index_chunks(2:10; n=3, split=RoundRobin()))) == 1:3
end

@testitem "enumerate(chunks(...))" begin
    using Base.Threads: @spawn, @threads, nthreads
    x = rand(100)
    s = zeros(nthreads())
    @threads for (ichunk, xchunk) in enumerate(chunks(x; n=nthreads()))
        s[ichunk] += sum(xchunk)
    end
    @test sum(s) ≈ sum(x)

    s = zeros(nthreads())
    @sync for (ichunk, xchunk) in enumerate(chunks(x; n=nthreads()))
        @spawn s[ichunk] += sum(xchunk)
    end
    @test sum(s) ≈ sum(x)

    y = [1.0, 5.0, 7.0, 9.0, 3.0]
    # Consecutive()
    @test collect(enumerate(chunks(2:10; n=2))) == [(1, 2:6), (2, 7:10)]
    @test typeof(collect(enumerate(chunks(2:10; n=2)))) == Vector{Tuple{Int64,UnitRange{Int64}}}
    @test collect(enumerate(chunks(y; n=2))) == [(1, [1.0, 5.0, 7.0]), (2, [9.0, 3.0])]
    @test typeof(collect(enumerate(chunks(y; n=2)))) <: (Vector{Tuple{Int64,T}} where {T<:SubArray})
    @test eltype(enumerate(chunks(2:10; n=2))) <: Tuple{Int64,UnitRange{Int64}}
    @test eltype(enumerate(chunks(y; n=2))) <: Tuple{Int64,SubArray}
    @test eachindex(enumerate(chunks(2:10; n=3))) == 1:3
    @test eachindex(enumerate(chunks(2:10; size=2))) == 1:5

    # RoundRobin()
    @test collect(enumerate(chunks(2:10; n=2, split=RoundRobin()))) == [(1, 2:2:10), (2, 3:2:9)]
    @test typeof(collect(enumerate(chunks(2:10; n=2, split=RoundRobin())))) == Vector{Tuple{Int64,StepRange{Int64,Int64}}}
    @test collect(enumerate(chunks(y; n=2, split=RoundRobin()))) == [(1, [1.0, 7.0, 3.0]), (2, [5.0, 9.0])]
    @test typeof(collect(enumerate(chunks(y; n=2, split=RoundRobin())))) <: (Vector{Tuple{Int64,T}} where {T<:SubArray})
    @test eltype(enumerate(chunks(2:10; n=2, split=RoundRobin()))) <: Tuple{Int64,StepRange{Int64,Int64}}
    @test eltype(enumerate(chunks(y; n=2, split=RoundRobin()))) <: Tuple{Int64,SubArray}
    @test eachindex(enumerate(chunks(2:10; n=3, split=RoundRobin()))) == 1:3
end

@testitem "ChunksIterators: parametric types order" begin
    # Try not to break the order of the type parameters. The ChunksIterators are
    # not public, but they're being used by OhMyThreads.
    using ChunkSplitters.Internals: ViewChunks, IndexChunks
    using ChunkSplitters.Internals: FixedCount, Consecutive
    @test IndexChunks{typeof(1:7),FixedCount,Consecutive}(1:7, 3, 0) ==
          IndexChunks{UnitRange{Int64},FixedCount,Consecutive}(1:7, 3, 0)
    @test IndexChunks{typeof(1:7),FixedCount,Consecutive}(1:7, 3, 0) ==
          IndexChunks{UnitRange{Int64},FixedCount,Consecutive}(1:7, 3, 0)
    @test ViewChunks{typeof(1:7),FixedCount,Consecutive}(1:7, 3, 0) ==
          ViewChunks{UnitRange{Int64},FixedCount,Consecutive}(1:7, 3, 0)
    @test ViewChunks{typeof(1:7),FixedCount,Consecutive}(1:7, 3, 0) ==
          ViewChunks{UnitRange{Int64},FixedCount,Consecutive}(1:7, 3, 0)
end

@testitem "indexing" begin
    for f in (chunks, index_chunks)
        @testset "$f" begin
            # FixedCount
            c = f(2:6; n=4)
            @test firstindex(c) == 1
            @test firstindex(enumerate(c)) == 1
            @test lastindex(c) == 4
            @test lastindex(enumerate(c)) == 4
            if f == index_chunks
                @test first(c) == 1:2
                @test first(enumerate(c)) == (1, 1:2)
                @test last(c) == 5:5
                @test last(enumerate(c)) == (4, 5:5)
                @test c[2] == 3:3
            elseif f == chunks
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
            if f == index_chunks
                @test first(c) == 1:2
                @test first(enumerate(c)) == (1, 1:2)
                @test last(c) == 5:5
                @test last(enumerate(c)) == (3, 5:5)
                @test c[2] == 3:4
            elseif f == chunks
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
    for f in (chunks, index_chunks)
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
            @test collect(f(1:10; n=2, minsize=2)) == [1:5, 6:10]
            @test collect(f(1:10; n=5, minsize=3)) == [1:4, 5:7, 8:10]
            @test collect(f(1:11; n=10, minsize=3)) == [1:4, 5:8, 9:11]
            @test_throws ArgumentError f(1:10; n=2, minsize=0)
            @test_throws ArgumentError f(1:10; size=2, minsize=2)
            @test_throws ArgumentError f(1:10; size=2, minsize=11)
        end
    end
end

@testitem "Custom types" begin
    struct CustomType end
    Base.firstindex(::CustomType) = 1
    Base.lastindex(::CustomType) = 7
    Base.length(::CustomType) = 7
    ChunkSplitters.is_chunkable(::CustomType) = true
    x = CustomType()
    @test collect(index_chunks(x; n=3)) == [1:3, 4:5, 6:7]
    @test collect(enumerate(index_chunks(x; n=3))) == [(1, 1:3), (2, 4:5), (3, 6:7)]
    @test eltype(enumerate(index_chunks(x; n=3))) == Tuple{Int64,UnitRange{Int}}
    @test typeof(first(index_chunks(x; n=3))) == UnitRange{Int}
    @test collect(index_chunks(x; n=3, split=RoundRobin())) == [1:3:7, 2:3:5, 3:3:6]
    @test collect(enumerate(index_chunks(x; n=3, split=RoundRobin()))) == [(1, 1:3:7), (2, 2:3:5), (3, 3:3:6)]
    @test eltype(enumerate(index_chunks(x; n=3, split=RoundRobin()))) == Tuple{Int64,StepRange{Int64,Int64}}

    @test_throws MethodError collect(chunks(x; n=3))
    Base.view(m::CustomType, I::UnitRange{Int64}) = CustomType()
    @test collect(chunks(x; n=3)) == [CustomType(), CustomType(), CustomType()]
    @test_throws MethodError collect(chunks(x; n=3, split=RoundRobin()))
    Base.view(m::CustomType, I::StepRange{Int64,Int64}) = CustomType()
    @test collect(chunks(x; n=3, split=RoundRobin())) == [CustomType(), CustomType(), CustomType()]
end

@testitem "empty input" begin
    for f in (index_chunks, chunks)
        @testset "$f" begin
            # if we use UnitRange input the output types are identical because
            # view will also output a UnitRange/StepRange
            @test isempty(collect(f(10:9; n=2)))
            @test typeof(collect(f(10:9; n=2))) == Vector{UnitRange{Int}}
            @test isempty(collect(f(10:9; size=2)))
            @test typeof(collect(f(10:9; size=2))) == Vector{UnitRange{Int}}
            @test isempty(collect(enumerate(f(10:9; n=2))))
            @test typeof(collect(enumerate(f(10:9; n=2)))) == Vector{Tuple{Int64,UnitRange{Int64}}}
            @test isempty(collect(enumerate(f(10:9; size=2))))
            @test typeof(collect(enumerate(f(10:9; size=2)))) == Vector{Tuple{Int64,UnitRange{Int64}}}
            @test isempty(collect(f(10:9; n=2, split=RoundRobin())))
            @test typeof(collect(f(10:9; n=2, split=RoundRobin()))) == Vector{StepRange{Int,Int}}
            @test isempty(collect(f(10:9; size=2, split=RoundRobin())))
            @test typeof(collect(f(10:9; size=2, split=RoundRobin()))) == Vector{StepRange{Int,Int}}
            @test isempty(collect(enumerate(f(10:9; n=2, split=RoundRobin()))))
            @test typeof(collect(enumerate(f(10:9; n=2, split=RoundRobin())))) == Vector{Tuple{Int64,StepRange{Int,Int}}}
            @test isempty(collect(enumerate(f(10:9; size=2, split=RoundRobin()))))
            @test typeof(collect(enumerate(f(10:9; size=2, split=RoundRobin())))) == Vector{Tuple{Int64,StepRange{Int,Int}}}
        end
    end

    @test isempty(collect(index_chunks(Float64[]; n=2)))
    @test typeof(collect(index_chunks(Float64[]; n=2))) == Vector{UnitRange{Int64}}
    @test isempty(collect(chunks(Float64[]; n=2)))
    @test typeof(collect(chunks(Float64[]; n=2))) == Vector{SubArray{Float64,1,Vector{Float64},Tuple{UnitRange{Int64}},true}}
end

@testitem "type inference" begin
    for f in (index_chunks, chunks)
        f_batch = () -> f(1:7; n=4)
        @test f_batch() == @inferred f_batch()
        f_scatter = () -> f(1:7; n=4, split=RoundRobin())
        @test f_scatter() == @inferred f_scatter()
        f_size = () -> f(1:7; size=4)
        @test f_size() == @inferred f_size()
    end
end

@testitem "zero-allocation benchmark" begin
    using BenchmarkTools
    @testset "index_chunks" begin
        function f_index_chunks(x; n=nothing, size=nothing)
            s = zero(eltype(x))
            for xdata in index_chunks(x; n=n, size=size)
                s += sum(xdata)
            end
            return s
        end
        x = rand(10^3)
        b = @benchmark $f_index_chunks($x; n=4) samples = 1 evals = 1
        @test b.allocs == 0
        b = @benchmark $f_index_chunks($x; size=10) samples = 1 evals = 1
        @test b.allocs == 0
    end
    @testset "chunk" begin
        function f_chunks(x; n=nothing, size=nothing)
            s = zero(eltype(x))
            for xdata in chunks(x; n=n, size=size)
                s += sum(xdata)
            end
            return s
        end
        x = rand(10^3)
        b = @benchmark $f_chunks($x; n=4) samples = 1 evals = 1
        @test b.allocs == 0
        b = @benchmark $f_chunks($x; size=10) samples = 1 evals = 1
        if VERSION >= v"1.10"
            @test b.allocs == 0
        else
            @test_broken b.allocs == 0
        end
    end
end
