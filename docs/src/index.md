# ChunkSplitters.jl

[ChunkSplitters.jl](https://github.com/m3g/ChunkSplitters.jl) facilitates the splitting of a given list of work items (of potentially uneven workload) into chunks that can be readily used for parallel processing. Operations on these chunks can, for example, be parallelized with Julia's multithreading tools, where separate tasks are created for each chunk. Compared to naive parallelization, ChunkSplitters.jl therefore effectively allows for more fine-grained control of the composition and workload of each parallel task.

Working with chunks and their respective indices also improves thread-safety compared to a naive approach based on `threadid()` indexing (see [PSA: Thread-local state is no longer recommended](https://julialang.org/blog/2023/07/PSA-dont-use-threadid/)). 

## Installation

Install with:
```julia-repl
julia> import Pkg; Pkg.add("ChunkSplitters")
```

## The `chunks` iterator

The main interface is the `chunks` iterator:

```julia
chunks(array::AbstractArray, nchunks::Int, type::Symbol=:batch)
```

This iterator returns a `Tuple{UnitRange,Int}` which indicates the range of indices of the input `array` for each given chunk and the index of the latter. If `type == :batch`, the ranges are consecutive. If `type == :scatter`, the range is scattered over the array.

The different chunking variants are illustrated in the following figure: 

![splitter types](./assets/splitters.svg)

For `type=:batch`, each chunk is "filled up" one after another with work items such that all chunks hold the same number of work items (as far as possible). For `type=:scatter`, the work items are assigned to chunks in a round-robin fashion. As shown below, this way of chunking can be beneficial if the workload (i.e. the computational weight) for different items is uneven. 

## Example

Here we illustrate which are the indexes of the chunks returned by each iterator:

```julia
julia> using ChunkSplitters 

julia> x = rand(7);

julia> Threads.@threads for (xrange,ichunk) in chunks(x, 3, :batch)
           @show (xrange, ichunk)
       end
(xrange, ichunk) = (1:3, 1)
(xrange, ichunk) = (6:7, 3)
(xrange, ichunk) = (4:5, 2)

julia> Threads.@threads for (xrange,ichunk) in chunks(x, 3, :scatter)
           @show (xrange, ichunk)
       end
(xrange, ichunk) = (2:3:5, 2)
(xrange, ichunk) = (1:3:7, 1)
(xrange, ichunk) = (3:3:6, 3)
```

If the third argument is ommitted (i. e. `:batch` or `:scatter`), the default `:batch` option
is used.

Now, we illustrate the use of the iterator in a practical example:

```julia
julia> using BenchmarkTools

julia> using ChunkSplitters

julia> function sum_parallel(f, x; nchunks=Threads.nthreads())
           s = fill(zero(eltype(x)), nchunks)
           Threads.@threads for (xrange, ichunk) in chunks(x, nchunks)
               for i in xrange
                  s[ichunk] += f(x[i])
               end
           end
           return sum(s)
       end

julia> x = rand(10^7);

julia> Threads.nthreads()
12

julia> @btime sum(x -> log(x)^7, $x)
  115.026 ms (0 allocations: 0 bytes)
-5.062317099586189e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=12)
  33.723 ms (77 allocations: 6.55 KiB)
-5.062317099581316e10
```

## Lower-level chunks function 

The package also provides a lower-level chunks function:

```julia
chunks(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)
```

that returns a range of indexes of `array`, given the number of chunks in
which the array is to be split, `nchunks`, and the current chunk number `ichunk`. 

### Example

The example shows how to compute a sum of a function applied to the elements of an array,
and the effect of the parallelization and the number of chunks in the performance:

```julia
julia> using BenchmarkTools

julia> using ChunkSplitters: chunks

julia> function sum_parallel(f, x; nchunks=Threads.nthreads())
           s = fill(zero(eltype(x)), nchunks)
           Threads.@threads for ichunk in 1:nchunks
               for i in chunks(x, ichunk, nchunks)
                   s[ichunk] += f(x[i])
               end
           end
           return sum(s)
       end

julia> x = rand(10^7);

julia> Threads.nthreads()
12

julia> @btime sum(x -> log(x)^7, $x)
  122.085 ms (0 allocations: 0 bytes)
-5.062317099586189e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=4)
  34.802 ms (74 allocations: 6.61 KiB)
-5.062317099581316e10
```

### Examples of different splitters

For example, if we have an array of 7 elements, and the work on the elements is divided
into 3 chunks, we have (using the default `type = :batch` option):

```julia
julia> using ChunkSplitters

julia> x = rand(7);

julia> chunks(x, 1, 3)
1:3

julia> chunks(x, 2, 3)
4:5

julia> chunks(x, 3, 3)
6:7
```

And using `type = :scatter`, we have:

```julia
julia> chunks(x, 1, 3, :scatter)
1:3:7

julia> chunks(x, 2, 3, :scatter)
2:3:5

julia> chunks(x, 3, 3, :scatter)
3:3:6
```

## Load balancing considerations

Here we define two functions which (artificially) result in very uneven workload distributions
among tasks. Basically, we sum `log(x[i])^7` for `x[i]` being the elements of an array. However,
each task has to sum a different number of elements, defined in a `workload` vector. The 
workload vector will have `64` tasks, with a workload that decreases for each task. 

The functions are defined using `Threads.@threads` or `Threads.@sync/Threads.@spawn` macros of 
base julia, which imply different possibilities of load balancing.

We create a very unbalanced workload, with:

```julia-repl
julia> x = rand(10^4); work_load = collect(div(10^4,i) for i in 1:64);

julia> using UnicodePlots

julia> lineplot(work_load; xlabel="task", ylabel="workload")
                   ┌────────────────────────────────────────┐ 
            10 000 │⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⠸⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
   workload        │⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⠀⢱⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⠀⠸⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⠀⠀⢇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⠀⠀⠈⢆⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                   │⠀⠀⠀⠀⠈⠲⢤⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                 0 │⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠓⠒⠒⠒⠒⠒⠦⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⣀⣀⣀⠀⠀⠀│ 
                   └────────────────────────────────────────┘ 
                   ⠀0⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀70⠀ 
                   ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀task⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 
```

Thus, the first tasks will operate on all elements of the array, while the final tasks
will perform a sum over much less elements. 

### Using `@threads`

First, we consider the case where the `@threads` macro is used. The threaded operation is:

```julia
julia> using Base.Threads, ChunkSplitters

julia> function uneven_workload_threads(x, work_load; nchunks::Int, chunk_type::Symbol)
           s = fill(zero(eltype(x)), nchunks)
           @threads for (xrange, ichunk) in chunks(work_load, nchunks, chunk_type)
               for i in xrange
                   s[ichunk] += sum(log(x[j])^7 for j in 1:work_load[i]) 
               end
           end
           return sum(s)
       end
```

Using `nchunks == nthreads()`, which are `8` in this case, we get the following timings:

```julia
julia> @btime uneven_workload_threads($x, $work_load; nchunks=8, chunk_type=:batch)
  1.451 ms (46 allocations: 4.61 KiB)
-1.5503788131612685e8

julia> @btime uneven_workload_threads($x, $work_load; nchunks=8, chunk_type=:scatter)
  826.857 μs (46 allocations: 4.61 KiB)
-1.5503788131612682e8
```

Therefore, it is possible to deal with the unbalaced workload with the `:scatter` option, since there is, here, a correlation between chunk index and workload. However, if that is not known, one can deal with the workload by increasing the number of chunks, if using the `@sync/@spawn` option:

### Using `@sync/@spawn`

The same pattern can be used if the `@sync/@spawn` macros where used for spawning threads. The difference is that
the spawned tasks are not bound to any thread, such that varying the number of chunks can have an effect on the
load balancing. 

The function is similar to the previous one,

```julia
julia> function uneven_workload_spawn(x, work_load; nchunks::Int, chunk_type::Symbol)
           s = fill(zero(eltype(x)), nchunks)
           @sync for (xrange, ichunk) in chunks(work_load, nchunks, chunk_type)
               @spawn for i in xrange
                   s[ichunk] += sum(log(x[j])^7 for j in 1:work_load[i]) 
               end
           end
           return sum(s)
       end
```

And we get a similar speedup when using the `:scatter` chunking style:

```julia
julia> @btime uneven_workload_spawn($x, $work_load; nchunks=8, chunk_type=:batch)
  1.398 ms (59 allocations: 5.08 KiB)
-1.5503788131612685e8

julia> @btime uneven_workload_spawn($x, $work_load; nchunks=8, chunk_type=:scatter)
  745.953 μs (59 allocations: 5.08 KiB)
-1.5503788131612682e8
```

Now, alternativelly (or additionally), one can vary the number of chunks, and that can improve the load balancing as well:

```julia
julia> @btime uneven_workload_spawn($x, $work_load; nchunks=64, chunk_type=:batch)
  603.476 μs (398 allocations: 38.83 KiB)
-1.5503788131612682e8
```

Note that the same does not work if using `@threads`, because the first `8` tasks will noneless be assigned to the same thread:

```julia
julia> @btime uneven_workload_threads($x, $work_load; nchunks=64, chunk_type=:batch)
  1.451 ms (47 allocations: 5.08 KiB)
-1.5503788131612682e8
```

!!! note
    Note that increasing the number of chunks beyond `nthreads()` gives better performance for the simple sum shown [in the Example section above](#Example). However, this is due to more subtle effects (false-sharing) and not related to the chunking and the distribution of work among threads. For well-designed parallel algorithms, `nchunks == nthreads()` should be optimal in conjuction with `@threads`.
