var documenterSearchIndex = {"docs":
[{"location":"gettingstarted/#Getting-started","page":"Getting started","title":"Getting started","text":"","category":"section"},{"location":"gettingstarted/#chunk_indices-and-chunk","page":"Getting started","title":"chunk_indices and chunk","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"The two main API functions are chunk_indices and chunk. They return iterators that split the indices or elements of a given collection into chunks. But it's easiest to just consider an explicit example.","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"julia> using ChunkSplitters\n\njulia> x = [1.2, 3.4, 5.6, 7.8, 9.1, 10.11, 11.12];\n\njulia> for inds in chunk_indices(x; n=3)\n           @show inds\n       end\ninds = 1:3\ninds = 4:5\ninds = 6:7\n\njulia> for c in chunk(x; n=3)\n           @show c\n       end\nc = [1.2, 3.4, 5.6]\nc = [7.8, 9.1]\nc = [10.11, 11.12]","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"Because we have set n=3, we will get three chunks. Alternatively, we can use size to specify the desired chunk size (the number of chunks will be computed).","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"julia> for c in chunk(x; size=2)\n           @show c\n       end\nc = [1.2, 3.4]\nc = [5.6, 7.8]\nc = [9.1, 10.11]\nc = [11.12]\n\njulia> for inds in chunk_indices(x; size=2)\n           @show inds\n       end\ninds = 1:2\ninds = 3:4\ninds = 5:6\ninds = 7:7","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"Note that if n is set, chunks will have the most even distribution of sizes possible. If size is set, chunks will have the same size, except, possibly, the very last chunk.","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"When using n, we also support a minchunksize keyword argument that allows you to set a desired minimum chunk size. This will soften the effect of n and will decrease the number of chunks if the size of each chunk is too small.","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"julia> collect(chunk_indices(x; n=5, minchunksize=2))\n3-element Vector{UnitRange{Int64}}:\n 1:3\n 4:5\n 6:7","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"Note how only three chunks were created, because the minchunksize option took precedence over n.","category":"page"},{"location":"gettingstarted/#Enumeration","page":"Getting started","title":"Enumeration","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"If we need a running chunk index, we can combine chunk_indices and chunk with enumerate:","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"julia> for (i, inds) in enumerate(chunk_indices(x; n=3))\n           @show i, inds\n       end\n(i, inds) = (1, 1:3)\n(i, inds) = (2, 4:5)\n(i, inds) = (3, 6:7)\n\njulia> for (i, c) in enumerate(chunk(x; n=3))\n           @show i, c\n       end\n(i, c) = (1, [1.2, 3.4, 5.6])\n(i, c) = (2, [7.8, 9.1])\n(i, c) = (3, [10.11, 11.12])","category":"page"},{"location":"gettingstarted/#Indexing","page":"Getting started","title":"Indexing","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"Apart from iterating over chunk or chunk_indices, you can also index into the resulting iterators:","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"julia> chunk_indices(x; n=4)[1]\n1:2\n\njulia> chunk_indices(x; n=4)[2]\n3:4\n\njulia> chunk(x; n=4)[1]\n2-element view(::Vector{Float64}, 1:2) with eltype Float64:\n 1.2\n 3.4\n\njulia> chunk(x; n=4)[2]\n2-element view(::Vector{Float64}, 3:4) with eltype Float64:\n 5.6\n 7.8","category":"page"},{"location":"gettingstarted/#Return-types","page":"Getting started","title":"Return types","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"To avoid unnecessary copies, chunk tries to return views into the original data. For our input (Vector{Float64}) chunks will be SubArrays:","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"julia> eltype(chunk(x; n=3))\nSubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}\n\njulia> collect(chunk(x; n=3))\n3-element Vector{SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}}:\n [1.2, 3.4, 5.6]\n [7.8, 9.1]\n [10.11, 11.12]","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"For chunk_indices we generally get (cheap) ranges:","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"julia> eltype(chunk_indices(x; n=3))\nUnitRange{Int64}\n\njulia> collect(chunk_indices(x; n=3))\n3-element Vector{UnitRange{Int64}}:\n 1:3\n 4:5\n 6:7","category":"page"},{"location":"gettingstarted/#Non-standard-arrays","page":"Getting started","title":"Non-standard arrays","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"Generally, we try to support most/all AbstractArrays. For example, OffsetArrays work just fine.","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"julia> using ChunkSplitters, OffsetArrays\n\njulia> y = OffsetArray(1:7, -1:5);\n\njulia> collect(chunk_indices(y; n=3))\n3-element Vector{UnitRange{Int64}}:\n -1:1\n 2:3\n 4:5\n\njulia> collect(chunk(y; n=3))\n3-element Vector{SubArray{Int64, 1, OffsetVector{Int64, UnitRange{Int64}}, Tuple{UnitRange{Int64}}, true}}:\n [1, 2, 3]\n [4, 5]\n [6, 7]","category":"page"},{"location":"gettingstarted/#Splitting-strategy","page":"Getting started","title":"Splitting strategy","text":"","category":"section"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"Both chunk_indices and chunk take an optional keyword argument split that you can use to determine how the input collection is split into chunks. We support to strategies: BatchSplit() (default) and ScatterSplit().","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"With BatchSplit(), chunks are \"filled up\" with indices/elements one after another. They will consist of consecutive indices/elements will hold approximately the same number of indices/elements (as far as possible). Note that this is unlike Iterators.partition.","category":"page"},{"location":"gettingstarted/","page":"Getting started","title":"Getting started","text":"With ScatterSplit(), indices or elements are scattered across chunks in a round-robin fashion. The first index/element goes to the first chunk, the second index/element goes to the second chunk, and so on, until we run out of chunks and continue with the first chunk again.","category":"page"},{"location":"multithreading/#Multithreading","page":"Multithreading","title":"Multithreading","text":"","category":"section"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"The iterators chunk and chunk_indices can be very useful in combination with @spawn and @threads for task-based multithreading. Let's see how we can use them together.","category":"page"},{"location":"multithreading/#Example:-Parallel-summation","page":"Multithreading","title":"Example: Parallel summation","text":"","category":"section"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> using ChunkSplitters: chunk\n\njulia> using Base.Threads: nthreads, @spawn\n\njulia> function parallel_sum(f, x; n=nthreads())\n           tasks = map(chunk(x; n=n)) do c\n               @spawn sum(f, c)\n           end\n           return sum(fetch, tasks)\n       end\nparallel_sum (generic function with 1 method)\n\njulia> x = rand(10^5);\n\njulia> parallel_sum(identity, x) ≈ sum(identity, x) # true\ntrue\n\njulia> using BenchmarkTools\n\njulia> @btime sum(x -> log(x)^7, $x);\n\n  938.583 μs (0 allocations: 0 bytes)\n\njulia> @btime parallel_sum(x -> log(x)^7, $x; n=Threads.nthreads());\n  321.083 μs (44 allocations: 3.42 KiB)","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"Note that by chunking x we can readily control how many tasks we will use for the parallelisation. One reason why this is useful is that we can reduce the (large) overhead that we would have to pay if we would simply spawn length(x) tasks:","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> @btime parallel_sum(x -> log(x)^7, $x; n=length(x)); # equivalent no chunking\n  40.259 ms (700006 allocations: 54.17 MiB)","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"Another reason why chunking is useful is that by setting n <= nthreads() we can make parallel_sum use only a subset of the available Julia threads:","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> @btime parallel_sum(x -> log(x)^7, $x; n=2); # use only 2 tasks/threads\n  506.875 μs (16 allocations: 1.20 KiB)","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"Lastly, as we'll discuss further down below, the ability to control the elements-to-task mapping allows you to tune load-balancing for non-uniform workload.","category":"page"},{"location":"multithreading/#@threads-and-enumerate","page":"Multithreading","title":"@threads and enumerate","text":"","category":"section"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"If you try to rewrite the parallel summation example above and try to use @threads instead of @spawn you might realize that it won't work by just using chunk alone. The reason is that we need to store the partial (chunk-)sums in a vector and to write to the correct slots of this vector, we need a chunk index in each task.","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"The natural solution is to use enumerate(chunk(...)), which will give us the necessary chunk indices besides the chunks. And in fact, this works:","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> using ChunkSplitters: chunk\n\njulia> using Base.Threads: nthreads, @threads\n\njulia> function parallel_sum(f, x; n=nthreads())\n           psums = Vector{eltype(x)}(undef, n)\n           @threads for (i, c) in enumerate(chunk(x; n=n))\n               psums[i] = sum(f, c)\n           end\n           return sum(psums)\n       end\nparallel_sum (generic function with 1 method)\n\njulia> x = rand(10^5);\n\njulia> parallel_sum(identity, x) ≈ sum(identity, x) # true\ntrue\n\njulia> using BenchmarkTools\n\njulia> @btime sum(x -> log(x)^7, $x);\n  936.625 μs (0 allocations: 0 bytes)\n\njulia> @btime parallel_sum(x -> log(x)^7, $x; n=Threads.nthreads());\n  319.000 μs (35 allocations: 3.42 KiB)","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"However, the fact that this works is that we actively support it. In general, @threads isn't compatible with enumerate:","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> @threads for (i, x) in enumerate(1:10)\n           @show i, x\n       end\nERROR: TaskFailedException\n\n    nested task error: MethodError: no method matching firstindex(::Base.Iterators.Enumerate{UnitRange{Int64}})\n    \n[...]","category":"page"},{"location":"multithreading/#Dynamic-load-balancing","page":"Multithreading","title":"Dynamic load balancing","text":"","category":"section"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"Consider the following function:","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"f_nonuniform(x) = sum(abs2, rand() for _ in 1:(2^14*x))","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"The workload and computational cost of f_nonuniform(x) is non-uniform and increases linearly with x:","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> xs = 1:2^7;\n\njulia> workload = 2^14 .* xs;\n\njulia> lineplot(xs, workload; xlabel=\"x\", ylabel=\"∝ workload of f_nonuniform(x)\", xlim=(1,2^7), ylim=(minimum(ys), maximum(ys)))\n                                           ┌────────────────────────────────────────┐ \n                                 2 097 152 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠔⠋│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠚⠁⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠖⠉⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠴⠋⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠔⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠔⠊⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n   ∝ workload of f_nonuniform(x)           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠊⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠔⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠔⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⠀⠀⠀⣠⠖⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⠀⠀⠀⣀⠴⠊⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           │⠀⠀⢀⡤⠊⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                    16 384 │⣠⠔⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                                           └────────────────────────────────────────┘ \n                                           ⠀1⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀128⠀ \n                                           ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀x⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"Let's now reconsider our parallel_sum implementation from above and see how it can handle the non-uniformity of the workload for different values of n.","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> using ChunkSplitters, Base.Threads, BenchmarkTools\n\njulia> xs = 1:512\n\njulia> f_nonuniform(x) = sum(abs2, rand() for _ in 1:(2^14*x))\n\njulia> function parallel_sum(f, x; n=nthreads(), split=BatchSplit())\n           tasks = map(chunk(x; n=n, split=split)) do c\n               @spawn sum(f, c)\n           end\n           return sum(fetch, tasks)\n       end\nparallel_sum (generic function with 1 method)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=nthreads());\n  861.248 ms (45 allocations: 3.39 KiB)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=2*nthreads());\n  683.033 ms (86 allocations: 6.59 KiB)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=4*nthreads());\n  638.611 ms (170 allocations: 13.06 KiB)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=8*nthreads());\n  585.203 ms (338 allocations: 26.02 KiB)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=16*nthreads());\n  567.806 ms (674 allocations: 51.88 KiB)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=32*nthreads());\n  557.139 ms (1346 allocations: 103.67 KiB)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=64*nthreads());\n  556.886 ms (2690 allocations: 207.33 KiB)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=128*nthreads());\n  558.612 ms (3586 allocations: 276.33 KiB)","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"We notice that, up to some point, increasing the number of tasks beyond nthreads() improves the runtime. The reason is that we give the dynamic scheduler more freedom to dynamically balance the increasing number tasks/chunks among threads. Compare this to n=nthreads(), where there is only one task/chunk per thread and no flexibility for load balancing at all. On the other hand, we can also see the downside of creating more tasks: the number and size of allocations increases.","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"From this we learn that, in general, a balance must be found between more tasks (→ better load balancing) and not too many tasks (→ fewer allocations and less overhead).","category":"page"},{"location":"multithreading/#\"Load-balancing\"-via-ScatterSplit","page":"Multithreading","title":"\"Load balancing\" via ScatterSplit","text":"","category":"section"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"Apart from increasing the number of tasks/chunks to improve dynamic load balancing, we can also statically distribute the workload more efficiently among tasks by choosing split=ScatterSplit(). This way, each task/chunk will get workload from everywhere along the linear curve plotted above. This effectively leads to better balancing of the load.","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"Let's demonstrate and benchmark this effect for the case n=nthreads(), which, essentially, corresponds to turned off dynamic load balancing.","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> @btime parallel_sum($f_nonuniform, $xs; n=nthreads(), split=BatchSplit());\n  857.914 ms (44 allocations: 3.36 KiB)\n\njulia> @btime parallel_sum($f_nonuniform, $xs; n=nthreads(), split=ScatterSplit());\n  566.818 ms (45 allocations: 3.39 KiB)","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"Note that with ScatterSplit(), we obtain a runtime that is comparable to n=16*nthreads() with BatchSplit() (dynamic load balancing, see above). At the same time, the ScatterSplit() variant is more efficient in terms of allocations.","category":"page"},{"location":"multithreading/#@threads-:static","page":"Multithreading","title":"@threads :static","text":"","category":"section"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"The strategy of using ScatterSplit() as a mean to get static load balancing also works with @threads and even @threads :static.","category":"page"},{"location":"multithreading/","page":"Multithreading","title":"Multithreading","text":"julia> function parallel_sum_atthreads(f, x; n=nthreads(), split=BatchSplit())\n           psums = zeros(Float64, n)\n           @threads :static for (i, c) in enumerate(chunk(x; n=n, split=split))\n               psums[i] = sum(f, c)\n           end\n           return sum(psums)\n       end\n\njulia> @btime parallel_sum_atthreads($f_nonuniform, $xs; n=nthreads(), split=BatchSplit());\n  850.475 ms (35 allocations: 3.53 KiB)\n\njulia> @btime parallel_sum_atthreads($f_nonuniform, $xs; n=nthreads(), split=ScatterSplit());\n  567.175 ms (35 allocations: 3.53 KiB)","category":"page"},{"location":"references/#References","page":"References","title":"References","text":"","category":"section"},{"location":"references/#Index","page":"References","title":"Index","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"Pages   = [\"references.md\"]\nOrder   = [:function, :type]","category":"page"},{"location":"references/#Iterators","page":"References","title":"Iterators","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"chunk_indices\nchunk","category":"page"},{"location":"references/#ChunkSplitters.chunk_indices","page":"References","title":"ChunkSplitters.chunk_indices","text":"chunk_indices(collection;\n    n::Union{Nothing, Integer}=nothing,\n    size::Union{Nothing, Integer}=nothing,\n    [split::Split=BatchSplit(),]\n    [minchunksize::Union{Nothing,Integer}=nothing,]\n)\n\nReturns an iterator that splits the indices of collection into n-many chunks (if n is given) or into chunks of a certain size (if size is given). The returned iterator can be used to process chunks of indices of collection one after another. If you want to process chunks of elements of collection, check out chunk(...) instead.\n\nThe keyword arguments n and size are mutually exclusive.\n\nKeyword arguments (optional)\n\nsplit can be used to determine the splitting strategy, i.e. the distribution of the indices among chunks. If split = BatchSplit() (default), chunks will hold consecutive indices and will hold approximately the same number of indices (as far as possible). If split = ScatterSplit(), indices will be assigned to chunks in a round-robin fashion.\nminchunksize can be used to specify the minimum size of a chunk, and can be used in combination with the n keyword. If, for the given n, the chunks are smaller than minchunksize, the number of chunks will be decreased to ensure that each chunk is at least minchunksize long.\n\nNoteworthy\n\nIf you need a running chunk index you can combine chunks with enumerate. In particular, enumerate(chunk_indices(...)) can be used in conjuction with @threads.\n\nRequirements\n\nThe type of the input collection must have at least firstindex, lastindex, and length functions defined, as well as ChunkSplitters.is_chunkable(::typeof(collection)) = true. Out of the box, AbstractArrays and Tuples are supported.\n\nExamples\n\njulia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> collect(chunk_indices(x; n=3))\n3-element Vector{UnitRange{Int64}}:\n 1:3\n 4:5\n 6:7\n\njulia> collect(enumerate(chunk_indices(x; n=3)))\n3-element Vector{Tuple{Int64, UnitRange{Int64}}}:\n (1, 1:3)\n (2, 4:5)\n (3, 6:7)\n\njulia> collect(chunk_indices(1:7; size=3))\n3-element Vector{UnitRange{Int64}}:\n 1:3\n 4:6\n 7:7\n\n\n\n\n\n","category":"function"},{"location":"references/#ChunkSplitters.chunk","page":"References","title":"ChunkSplitters.chunk","text":"chunk(collection;\n    n::Union{Nothing, Integer}=nothing,\n    size::Union{Nothing, Integer}=nothing,\n    [split::Split=BatchSplit(),]\n    [minchunksize::Union{Nothing,Integer}=nothing,]\n)\n\nReturns an iterator that splits the elements of collection into n-many chunks (if n is given) or into chunks of a certain size (if size is given). To avoid copies, chunks will generally hold a view into the original collection. The returned iterator can be used to process chunks of elements of collection one after another. If you want to process chunks of indices of collection, check out chunk_indices(...) instead.\n\nThe keyword arguments n and size are mutually exclusive.\n\nKeyword arguments (optional)\n\nsplit can be used to determine the splitting strategy, i.e. the distribution of the indices among chunks. If split = BatchSplit() (default), chunks will hold consecutive elements and will hold approximately the same number of elements (as far as possible). If split = ScatterSplit(), elements will be assigned to chunks in a round-robin fashion.\nminchunksize can be used to specify the minimum size of a chunk, and can be used in combination with the n keyword. If, for the given n, the chunks are smaller than minchunksize, the number of chunks will be decreased to ensure that each chunk is at least minchunksize long.\n\nNoteworthy\n\nIf you need a running chunk index you can combine chunks with enumerate. In particular, enumerate(chunk(...)) can be used in conjuction with @threads.\n\nRequirements\n\nIn addition to the requirements for chunk_indices (see docstring), the type of the input collection must have an implementation of view, especially view(::typeof(collection), ::UnitRange) and view(::typeof(collection), ::StepRange). Out of the box, AbstractArrays and Tuples are supported.\n\nExamples\n\njulia> using ChunkSplitters\n\njulia> x = [1.2, 3.4, 5.6, 7.8, 9.0];\n\njulia> collect(chunk(x; n=3))\n3-element Vector{SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}}:\n [1.2, 3.4]\n [5.6, 7.8]\n [9.0]\n\njulia> collect(enumerate(chunk(x; n=3)))\n3-element Vector{Tuple{Int64, SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}}}:\n (1, [1.2, 3.4])\n (2, [5.6, 7.8])\n (3, [9.0])\n\njulia> collect(chunk(x; size=3))\n2-element Vector{SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}}:\n [1.2, 3.4, 5.6]\n [7.8, 9.0]\n\n\n\n\n\n","category":"function"},{"location":"references/#Splitting-strategies","page":"References","title":"Splitting strategies","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"Split\nBatchSplit\nScatterSplit","category":"page"},{"location":"references/#ChunkSplitters.Split","page":"References","title":"ChunkSplitters.Split","text":"Subtypes can be used to indicate a splitting strategy for chunk and chunk_indices (split keyword argument).\n\n\n\n\n\n","category":"type"},{"location":"references/#ChunkSplitters.BatchSplit","page":"References","title":"ChunkSplitters.BatchSplit","text":"Chunks will hold consecutive indices/elements and will hold approximately the same number of them (as far as possible).\n\n\n\n\n\n","category":"type"},{"location":"references/#ChunkSplitters.ScatterSplit","page":"References","title":"ChunkSplitters.ScatterSplit","text":"Elements/indices will be assigned to chunks in a round-robin fashion.\n\n\n\n\n\n","category":"type"},{"location":"minimalinterface/#Minimal-interface","page":"Minimal interface","title":"Minimal interface","text":"","category":"section"},{"location":"minimalinterface/","page":"Minimal interface","title":"Minimal interface","text":"This page is about how to make custom types compatible with chunk_indices and chunk.","category":"page"},{"location":"minimalinterface/#chunk_indices","page":"Minimal interface","title":"chunk_indices","text":"","category":"section"},{"location":"minimalinterface/","page":"Minimal interface","title":"Minimal interface","text":"First of all, the type must define ChunkSplitters.is_chunkable(::YourType) = true. Moreover it needs to implement at least the functions Base.firstindex, Base.lastindex, and Base.length.","category":"page"},{"location":"minimalinterface/","page":"Minimal interface","title":"Minimal interface","text":"For example:","category":"page"},{"location":"minimalinterface/","page":"Minimal interface","title":"Minimal interface","text":"julia> using ChunkSplitters\n\njulia> struct MinimalInterface end\n\njulia> ChunkSplitters.is_chunkable(::MinimalInterface) = true\n\njulia> Base.firstindex(::MinimalInterface) = 1\n\njulia> Base.lastindex(::MinimalInterface) = 7\n\njulia> Base.length(::MinimalInterface) = 7\n\njulia> x = MinimalInterface()\nMinimalInterface()\n\njulia> collect(chunk_indices(x; n=3))\n3-element Vector{UnitRange{Int64}}:\n 1:3\n 4:5\n 6:7\n\njulia> collect(chunk_indices(x; n=3, split=ScatterSplit()))\n3-element Vector{StepRange{Int64, Int64}}:\n 1:3:7\n 2:3:5\n 3:3:6","category":"page"},{"location":"minimalinterface/#chunk","page":"Minimal interface","title":"chunk","text":"","category":"section"},{"location":"minimalinterface/","page":"Minimal interface","title":"Minimal interface","text":"In addition to the requirements above for chunk_indices, the type must have an implementation of view, especially view(::YourType, ::UnitRange) and view(::YourType, ::StepRange).","category":"page"},{"location":"#ChunkSplitters.jl","page":"Home","title":"ChunkSplitters.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"ChunkSplitters.jl makes it easy to split the elements or indices of a collection into chunks:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using ChunkSplitters\n\njulia> x = [1.2, 3.4, 5.6, 7.8, 9.1, 10.11, 11.12];\n\njulia> for inds in chunk_indices(x; n=3)\n           @show inds\n       end\ninds = 1:3\ninds = 4:5\ninds = 6:7\n\njulia> for c in chunk(x; n=3)\n           @show c\n       end\nc = [1.2, 3.4, 5.6]\nc = [7.8, 9.1]\nc = [10.11, 11.12]","category":"page"},{"location":"","page":"Home","title":"Home","text":"This can be useful in many areas, one of which is multithreading, where we can use chunking to control the number of spawned tasks:","category":"page"},{"location":"","page":"Home","title":"Home","text":"function parallel_sum(x; ntasks=nthreads())\n    tasks = map(chunk(x; n=ntasks)) do chunk_of_x\n        @spawn sum(chunk_of_x)\n    end\n    return sum(fetch, tasks)\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"Working with chunks and their respective indices also improves thread-safety compared to a naive parallelisation approach based on threadid() (see PSA: Thread-local state is no longer recommended). ","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Install with:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> import Pkg; Pkg.add(\"ChunkSplitters\")","category":"page"}]
}
