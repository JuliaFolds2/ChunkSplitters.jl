using ChunkSplitters
using BenchmarkTools
using Base.Threads

# Parallel summation
x = rand(10^8)
Threads.nthreads()

function sum_parallel(f, x; nchunks=Threads.nthreads())
    t = map(chunks(x, nchunks)) do (inds, ichunk)
        Threads.@spawn sum(f, @view x[inds])
    end
    return sum(fetch.(t))
end

function sum_parallel_getchunk(f, x; nchunks=Threads.nthreads())
    t = map(1:nchunks) do ichunk
        Threads.@spawn begin
            inds = getchunk(x, ichunk, nchunks)
            sum(f, @view x[inds])
        end
    end
    return sum(fetch.(t))
end

@btime sum(x -> log(x)^7, $x);
@btime sum_parallel(x -> log(x)^7, $x);
@btime sum_parallel_getchunk(x -> log(x)^7, $x);


# Uneven workload
work_load = ceil.(Int, collect(10^3 * exp(-0.002 * i) for i in 1:2^11));

## @threads
function uneven_workload_threads(x, work_load; nchunks::Int, chunk_type::Symbol)
    chunk_sums = Vector{eltype(x)}(undef, nchunks)
    @threads for (inds, ichunk) in chunks(work_load, nchunks, chunk_type)
        s = 0.0
        for i in inds
            s += sum(y -> log(y)^7, 1:work_load[i])
        end
        chunk_sums[ichunk] = s
    end
    return sum(chunk_sums)
end

@btime uneven_workload_threads($x, $work_load; nchunks=nthreads(), chunk_distribution=:batch)
@btime uneven_workload_threads($x, $work_load; nchunks=nthreads(), chunk_distribution=:scatter)

@btime uneven_workload_threads($x, $work_load; nchunks=8 * nthreads(), chunk_distribution=:batch)
@btime uneven_workload_threads($x, $work_load; nchunks=8 * nthreads(), chunk_distribution=:scatter)

## @spawn
function uneven_workload_spawn(x, work_load; nchunks::Int, chunk_type::Symbol)
    ts = map(chunks(work_load, nchunks, chunk_type)) do (inds, ichunk)
        @spawn begin
            s = zero(eltype(x))
            for i in inds
                s += sum(log(x[j])^7 for j in 1:work_load[i])
            end
            s
        end
    end
    return sum(fetch.(ts))
end

@btime uneven_workload_spawn($x, $work_load; nchunks=nthreads(), chunk_distribution=:batch)
@btime uneven_workload_spawn($x, $work_load; nchunks=nthreads(), chunk_distribution=:scatter)

@btime uneven_workload_spawn($x, $work_load; nchunks=8 * nthreads(), chunk_distribution=:batch)
@btime uneven_workload_spawn($x, $work_load; nchunks=8 * nthreads(), chunk_distribution=:scatter)
