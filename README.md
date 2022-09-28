# ChunkSplitters

This package provides the `splitter` function, that facilitates writing multi-threaded
executions that split the work in chunks.

It provides the function:

```julia
splitter(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)
```

that returns a range of indexes of `array`, given the number of chunks in
which the array is to be split, `nchunks`, and the current chunk number `ichunk`. 

If `type == :batch`, the ranges are consecutive. If `type == :scatter`, the range
is scattered over the array. 

## Example

The purpose of the package is to facilitate the splitting of the workload of parallel
jobs independently on the number of threads that are effectively available. This pattern
is recommended for a finer control of the parallelization, and for guaranteeing that 
the workload if completely thread safe 
(without the use `threadid()` - see [here](https://juliafolds.github.io/FLoops.jl/dev/explanation/faq/#faq-state-threadid)). 

The example shows how to compute a sum of a function applied to the elements of an array,
and the effect of the parallelization and the number of chunks in the performance:

```julia
julia> using ChunkSplitters: splitter

julia> function sum_parallel(f, x; nchunks=Threads.nthreads())
           s = fill(zero(eltype(x)), nchunks)
           Threads.@threads for ichunk in 1:nchunks
               for i in splitter(x, ichunk, nchunks)
                   s[ichunk] += f(x[i])
               end
           end
           return sum(s)
       end
sum_parallel (generic function with 2 methods)

julia> x = rand(10^7);

julia> @btime sum(x -> log(x)^7, $x)
  120.496 ms (0 allocations: 0 bytes)
-5.019473011538689e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=12)
  44.128 ms (74 allocations: 6.67 KiB)
-5.019473011537357e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=3)
  59.886 ms (74 allocations: 6.59 KiB)
-5.019473011532405e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=32)
  34.097 ms (74 allocations: 6.84 KiB)
-5.0194730115382385e10
```


## Examples of different splitters

For example, if we have an array of 7 elements, and the work on the elements is divided
into 3 chunks, we have (using the default `type = :batch` option):

```julia
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

```julia
julia> splitter(x, 1, 3, :scatter)
1:3:7

julia> splitter(x, 2, 3, :scatter)
2:3:5

julia> splitter(x, 3, 3, :scatter)
3:3:6
```