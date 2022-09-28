# ChunkSplitters

The purpose of the package is to facilitate the splitting of the workload of parallel
jobs independently on the number of threads that are effectively available. This pattern
is recommended for a finer control of the parallelization, and for guaranteeing that 
the workload if completely thread safe 
(without the use `threadid()` - see [here](https://juliafolds.github.io/FLoops.jl/dev/explanation/faq/#faq-state-threadid)). 

## Iterator

The main interface is the `splitter` iterator:

```julia
splitter(array::AbstractArray, nchunks::Int, type::Symbol=:batch)
```

This iterator returns a `Tuple{UnitRange,Int}` with the range of indices of `array`
to be iterated for each given chunk. If `type == :batch`, the ranges are consecutive. If `type == :scatter`, the range
is scattered over the array. 

This allows iterating (in parallel) among the indices of `array`, with a reasonable
workload distribution. 

### Example

```julia
julia> using ChunkSplitters 

julia> x = rand(7);

julia> Threads.@threads for (range,ichunk) in splitter(x, 3, :batch)
           @show (range, ichunk)
       end
(range, ichunk) = (6:7, 3)
(range, ichunk) = (1:3, 1)
(range, ichunk) = (4:5, 2)

julia> Threads.@threads for (range,ichunk) in splitter(x, 3, :scatter)
           @show (range, ichunk)
       end
(range, ichunk) = (2:3:5, 2)
(range, ichunk) = (1:3:7, 1)
(range, ichunk) = (3:3:6, 3)
```

Now, we illustrate the use of the iterator in a practical example:

```julia
julia> using ChunkSplitters: splitter

julia> function sum_parallel(f, x; nchunks=Threads.nthreads())
           s = fill(zero(eltype(x)), nchunks)
           Threads.@threads for (range, ichunk) in splitter(x, nchunks)
               for i in range
                  s[ichunk] += f(x[i])
              end
           end
           return sum(s)
       end
sum_parallel (generic function with 1 methods)

julia> x = rand(10^7);

julia> Threads.nthreads()
12

julia> @btime sum(x -> log(x)^7, $x)
  115.026 ms (0 allocations: 0 bytes)
-5.062317099586189e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=4)
  40.242 ms (77 allocations: 6.55 KiB)
-5.062317099581316e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=12)
  33.723 ms (77 allocations: 6.61 KiB)
-5.062317099584852e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=64)
  22.105 ms (77 allocations: 7.02 KiB)
-5.062317099585973e10
```

Note that it is possible that `nchunks > nthreads()` is optimal, since that
will distribute the workload more evenly among available threads.

## Lower-level splitter function 

The package also provides a lower-level splitter function:

```julia
splitter(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)
```

that returns a range of indexes of `array`, given the number of chunks in
which the array is to be split, `nchunks`, and the current chunk number `ichunk`. 

### Example

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

julia> Threads.nthreads()
12

julia> @btime sum(x -> log(x)^7, $x)
  122.085 ms (0 allocations: 0 bytes)
-5.062317099586189e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=4)
  45.802 ms (74 allocations: 6.61 KiB)
-5.062317099581316e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=12)
  33.963 ms (74 allocations: 6.67 KiB)
-5.062317099584852e10

julia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=64)
  22.999 ms (74 allocations: 7.08 KiB)
-5.062317099585973e10
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