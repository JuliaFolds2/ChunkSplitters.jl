# Multithreading

The iterators `chunks` and `index_chunks` can be very useful in combination with `@spawn` and `@threads` for task-based multithreading. Let's see how we can use them together.

## Example: Parallel summation

```julia-repl
julia> using ChunkSplitters: chunk

julia> using Base.Threads: nthreads, @spawn

julia> function parallel_sum(f, x; n=nthreads())
           tasks = map(chunks(x; n=n)) do c
               @spawn sum(f, c)
           end
           return sum(fetch, tasks)
       end
parallel_sum (generic function with 1 method)

julia> x = rand(10^5);

julia> parallel_sum(identity, x) ≈ sum(identity, x) # true
true

julia> using BenchmarkTools

julia> @btime sum(x -> log(x)^7, $x);

  938.583 μs (0 allocations: 0 bytes)

julia> @btime parallel_sum(x -> log(x)^7, $x; n=Threads.nthreads());
  321.083 μs (44 allocations: 3.42 KiB)
```

Equivalently, we can use `index_chunks` to iterate over the *index ranges* (instead of the elements) and manually create views:

```julia-repl
julia> using ChunkSplitters: index_chunks

julia> using Base.Threads: nthreads, @spawn

julia> function parallel_sum(f, x; n=nthreads())
           tasks = map(index_chunks(x; n=n)) do inds
               @spawn sum(f, @view(x[inds]))
           end
           return sum(fetch, tasks)
       end
parallel_sum (generic function with 1 method)

julia> x = rand(10^5);

julia> parallel_sum(identity, x) ≈ sum(identity, x) # true
true
```

Note that by chunking `x` we can readily control how many tasks we will use for the parallelisation. One reason why this is useful is that we can reduce the (large) overhead that we would have to pay if we would simply spawn `length(x)` tasks:

```julia-repl
julia> @btime parallel_sum(x -> log(x)^7, $x; n=length(x)); # equivalent no chunking
  40.259 ms (700006 allocations: 54.17 MiB)
```

Another reason why chunking is useful is that by setting `n <= nthreads()` we can make `parallel_sum` use only a subset of the available Julia threads:

```julia-repl
julia> @btime parallel_sum(x -> log(x)^7, $x; n=2); # use only 2 tasks/threads
  506.875 μs (16 allocations: 1.20 KiB)
```

Lastly, as we'll discuss further down below, the ability to control the elements-to-task mapping allows you to tune load-balancing for non-uniform workload.

## `@threads` and `enumerate`

If you try to rewrite the parallel summation example above and try to use `@threads` instead of `@spawn` you might realize that it won't work by just using `chunks` alone. The reason is that we need to store the partial (chunk-)sums in a vector and to write to the correct slots of this vector, we need a chunk index in each task.

The natural solution is to use `enumerate(chunks(...))`, which will give us the necessary chunk indices besides the chunks. And in fact, this works:

```julia-repl
julia> using ChunkSplitters: chunk

julia> using Base.Threads: nthreads, @threads

julia> function parallel_sum(f, x; n=nthreads())
           psums = Vector{eltype(x)}(undef, n)
           @threads for (i, c) in enumerate(chunks(x; n=n))
               psums[i] = sum(f, c)
           end
           return sum(psums)
       end
parallel_sum (generic function with 1 method)

julia> x = rand(10^5);

julia> parallel_sum(identity, x) ≈ sum(identity, x) # true
true

julia> using BenchmarkTools

julia> @btime sum(x -> log(x)^7, $x);
  936.625 μs (0 allocations: 0 bytes)

julia> @btime parallel_sum(x -> log(x)^7, $x; n=Threads.nthreads());
  319.000 μs (35 allocations: 3.42 KiB)
```

Alternatively, we can use `index_chunks` instead of `enumerate(chunks(...))`. Since `index_chunks` directly provides index ranges, it is a natural fit for this use case:

```julia-repl
julia> using ChunkSplitters: index_chunks

julia> using Base.Threads: nthreads, @threads

julia> function parallel_sum(f, x; n=nthreads())
           psums = Vector{eltype(x)}(undef, n)
           @threads for (i, inds) in enumerate(index_chunks(x; n=n))
               psums[i] = sum(f, @view(x[inds]))
           end
           return sum(psums)
       end
parallel_sum (generic function with 1 method)

julia> x = rand(10^5);

julia> parallel_sum(identity, x) ≈ sum(identity, x) # true
true
```

However, the fact that this works is that we actively support it. In general, `@threads` isn't compatible with `enumerate`:

```julia-repl
julia> @threads for (i, x) in enumerate(1:10)
           @show i, x
       end
ERROR: TaskFailedException

    nested task error: MethodError: no method matching firstindex(::Base.Iterators.Enumerate{UnitRange{Int64}})
    
[...]
```

## Dynamic load balancing

Consider the following function:

```julia
f_nonuniform(x) = sum(abs2, rand() for _ in 1:(2^14*x))
```

The workload and computational cost of `f_nonuniform(x)` is non-uniform and increases linearly with `x`:

```julia-repl
julia> xs = 1:2^7;

julia> workload = 2^14 .* xs;

julia> lineplot(xs, workload; xlabel="x", ylabel="∝ workload of f_nonuniform(x)", xlim=(1,2^7), ylim=(minimum(ys), maximum(ys)))
                                           ┌────────────────────────────────────────┐ 
                                 2 097 152 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠔⠋│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠚⠁⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠖⠉⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠴⠋⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠔⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠔⠊⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
   ∝ workload of f_nonuniform(x)           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠊⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠔⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠔⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⠀⠀⠀⣠⠖⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⠀⠀⠀⣀⠴⠊⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           │⠀⠀⢀⡤⠊⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                    16 384 │⣠⠔⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
                                           └────────────────────────────────────────┘ 
                                           ⠀1⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀128⠀ 
                                           ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀x⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 
```

Let's now reconsider our `parallel_sum` implementation from above and see how it can handle the non-uniformity of the workload for different values of `n`.

```julia-repl
julia> using ChunkSplitters, Base.Threads, BenchmarkTools

julia> xs = 1:512

julia> f_nonuniform(x) = sum(abs2, rand() for _ in 1:(2^14*x))

julia> function parallel_sum(f, x; n=nthreads(), split=Consecutive())
           tasks = map(chunks(x; n=n, split=split)) do c
               @spawn sum(f, c)
           end
           return sum(fetch, tasks)
       end
parallel_sum (generic function with 1 method)

julia> @btime parallel_sum($f_nonuniform, $xs; n=nthreads());
  861.248 ms (45 allocations: 3.39 KiB)

julia> @btime parallel_sum($f_nonuniform, $xs; n=2*nthreads());
  683.033 ms (86 allocations: 6.59 KiB)

julia> @btime parallel_sum($f_nonuniform, $xs; n=4*nthreads());
  638.611 ms (170 allocations: 13.06 KiB)

julia> @btime parallel_sum($f_nonuniform, $xs; n=8*nthreads());
  585.203 ms (338 allocations: 26.02 KiB)

julia> @btime parallel_sum($f_nonuniform, $xs; n=16*nthreads());
  567.806 ms (674 allocations: 51.88 KiB)

julia> @btime parallel_sum($f_nonuniform, $xs; n=32*nthreads());
  557.139 ms (1346 allocations: 103.67 KiB)

julia> @btime parallel_sum($f_nonuniform, $xs; n=64*nthreads());
  556.886 ms (2690 allocations: 207.33 KiB)

julia> @btime parallel_sum($f_nonuniform, $xs; n=128*nthreads());
  558.612 ms (3586 allocations: 276.33 KiB)
```

We notice that, up to some point, increasing the number of tasks beyond `nthreads()` improves the runtime. The reason is that we give the dynamic scheduler more freedom to dynamically balance the increasing number tasks/chunks among threads. Compare this to `n=nthreads()`, where there is only one task/chunk per thread and no flexibility for load balancing at all. On the other hand, we can also see the downside of creating more tasks: the number and size of allocations increases.

From this we learn that, in general, a balance must be found between more tasks (→ better load balancing) and not too many tasks (→ fewer allocations and less overhead).

## "Load balancing" via `RoundRobin`

Apart from increasing the number of tasks/chunks to improve *dynamic* load balancing, we can also *statically* distribute the workload more efficiently among tasks by choosing `split=RoundRobin()`. This way, each task/chunk will get workload from everywhere along the linear curve plotted above. This effectively leads to better balancing of the load.

Let's demonstrate and benchmark this effect for the case `n=nthreads()`, which, essentially, corresponds to turned off *dynamic* load balancing.

```julia-repl
julia> @btime parallel_sum($f_nonuniform, $xs; n=nthreads(), split=Consecutive());
  857.914 ms (44 allocations: 3.36 KiB)

julia> @btime parallel_sum($f_nonuniform, $xs; n=nthreads(), split=RoundRobin());
  566.818 ms (45 allocations: 3.39 KiB)
```

Note that with `RoundRobin()`, we obtain a runtime that is comparable to `n=16*nthreads()` with `Consecutive()` (dynamic load balancing, see above). At the same time, the `RoundRobin()` variant is more efficient in terms of allocations.

### `@threads :static`

The strategy of using `RoundRobin()` as a mean to get static load balancing also works with `@threads` and even `@threads :static`.

```julia-repl
julia> function parallel_sum_atthreads(f, x; n=nthreads(), split=Consecutive())
           psums = zeros(Float64, n)
           @threads :static for (i, c) in enumerate(chunks(x; n=n, split=split))
               psums[i] = sum(f, c)
           end
           return sum(psums)
       end

julia> @btime parallel_sum_atthreads($f_nonuniform, $xs; n=nthreads(), split=Consecutive());
  850.475 ms (35 allocations: 3.53 KiB)

julia> @btime parallel_sum_atthreads($f_nonuniform, $xs; n=nthreads(), split=RoundRobin());
  567.175 ms (35 allocations: 3.53 KiB)
```