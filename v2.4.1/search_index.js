var documenterSearchIndex = {"docs":
[{"location":"references/#References","page":"References","title":"References","text":"","category":"section"},{"location":"references/#Index","page":"References","title":"Index","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"Pages   = [\"references.md\"]\nOrder   = [:function, :type]","category":"page"},{"location":"references/#ChunkSplitters","page":"References","title":"ChunkSplitters","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"Modules = [ChunkSplitters]\nPages   = [\"ChunkSplitters.jl\"]","category":"page"},{"location":"references/#ChunkSplitters.chunks","page":"References","title":"ChunkSplitters.chunks","text":"chunks(itr; n::Union{Nothing, Integer}, size::Union{Nothing, Integer} [, split::Symbol=:batch])\n\nReturns an iterator that splits the indices of itr into n-many chunks (if n is given) or into chunks of a certain size (if size is given). The keyword arguments n and size are mutually exclusive. The returned iterator can be used to process chunks of itr one after another or in parallel (e.g. with @threads).\n\nThe optional argument split can be :batch (default) or :scatter and determines the distribution of the indices among the chunks. If split == :batch, chunk indices will be consecutive. If split == :scatter, the range is scattered over itr.\n\nIf you need a running chunk index you can combine chunks with enumerate. In particular, enumerate(chunks(...)) can be used in conjuction with @threads.\n\nThe itr is usually some iterable, indexable object. The interface requires it to have firstindex, lastindex, and length functions defined, as well as ChunkSplitters.is_chunkable(::typeof(itr)) = true.\n\nExamples\n\njulia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> collect(chunks(x; n=3))\n3-element Vector{StepRange{Int64, Int64}}:\n 1:1:3\n 4:1:5\n 6:1:7\n\njulia> collect(enumerate(chunks(x; n=3)))\n3-element Vector{Tuple{Int64, StepRange{Int64, Int64}}}:\n (1, 1:1:3)\n (2, 4:1:5)\n (3, 6:1:7)\n\njulia> collect(chunks(1:7; size=3))\n3-element Vector{StepRange{Int64, Int64}}:\n 1:1:3\n 4:1:6\n 7:1:7\n\nNote that chunks also works just fine for OffsetArrays:\n\njulia> using ChunkSplitters, OffsetArrays\n\njulia> x = OffsetArray(1:7, -1:5);\n\njulia> collect(chunks(x; n=3))\n3-element Vector{StepRange{Int64, Int64}}:\n -1:1:1\n 2:1:3\n 4:1:5\n\n\n\n\n\n","category":"function"},{"location":"references/#ChunkSplitters.getchunk-Tuple{Any, Integer}","page":"References","title":"ChunkSplitters.getchunk","text":"getchunk(itr, i::Integer; n::Integer, size::Integer[, split::Symbol=:batch])\n\nReturns the range of indices of itr that corresponds to the i-th chunk. How the chunks are formed depends on the keyword arguments. See chunks for more information.\n\nExample\n\nIf we have an array of 7 elements, and the work on the elements is divided into 3 chunks, we have (using the default split = :batch option):\n\njulia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> getchunk(x, 1; n=3)\n1:1:3\n\njulia> getchunk(x, 2; n=3)\n4:1:5\n\njulia> getchunk(x, 3; n=3)\n6:1:7\n\nAnd using split = :scatter, we have:\n\njulia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> getchunk(x, 1; n=3, split=:scatter)\n1:3:7\n\njulia> getchunk(x, 2; n=3, split=:scatter)\n2:3:5\n\njulia> getchunk(x, 3; n=3, split=:scatter)\n3:3:6\n\nWe can also choose the chunk size rather than the number of chunks:\n\njulia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> getchunk(x, 1; size=3)\n1:1:3\n\njulia> getchunk(x, 2; size=3)\n4:1:6\n\njulia> getchunk(x, 3; size=3)\n7:1:7\n\n\n\n\n\n","category":"method"},{"location":"references/#ChunkSplitters.is_chunkable-Tuple{Any}","page":"References","title":"ChunkSplitters.is_chunkable","text":"is_chunkable(::T) :: Bool\n\nDetermines if a of object of type T is capable of being chunked. Overload this function for your custom types if that type is linearly indexable and supports firstindex, lastindex, and length.\n\n\n\n\n\n","category":"method"},{"location":"references/#Interface-requirements","page":"References","title":"Interface requirements","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"compat: Compat\nSupport for this minimal interface requires version 2.2.0.","category":"page"},{"location":"references/","page":"References","title":"References","text":"For the chunks and getchunk functions to work, the input value must overload  ChunkSplitters.is_chunkable(::YourType) = true, and support the functions Base.firstindex, Base.lastindex, and Base.length.","category":"page"},{"location":"references/","page":"References","title":"References","text":"For example:","category":"page"},{"location":"references/","page":"References","title":"References","text":"julia> using ChunkSplitters\n\njulia> struct MinimalInterface end\n\njulia> Base.firstindex(::MinimalInterface) = 1\n\njulia> Base.lastindex(::MinimalInterface) = 7\n\njulia> Base.length(::MinimalInterface) = 7\n\njulia> ChunkSplitters.is_chunkable(::MinimalInterface) = true\n\njulia> x = MinimalInterface()\nMinimalInterface()\n\njulia> collect(chunks(x; n=3))\n3-element Vector{StepRange{Int64, Int64}}:\n 1:1:3\n 4:1:5\n 6:1:7\n\njulia> collect(chunks(x; n=3, split=:scatter))\n3-element Vector{StepRange{Int64, Int64}}:\n 1:3:7\n 2:3:5\n 3:3:6","category":"page"},{"location":"load_balancing/#Load-balancing-considerations","page":"Load balancing","title":"Load balancing considerations","text":"","category":"section"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"We create a very unbalanced workload:","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"julia> work_load = ceil.(Int, collect(10^3 * exp(-0.002*i) for i in 1:2^11));\n\njulia> using UnicodePlots\n\njulia> lineplot(work_load; xlabel=\"task\", ylabel=\"workload\", xlim=(1,2^11))\n                  ┌────────────────────────────────────────┐ \n            1 000 │⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠘⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⢹⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠈⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠈⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n   workload       │⠀⠀⠀⠀⠀⠀⠳⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠙⢦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠲⢤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠓⠦⠤⣄⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                0 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠓⠒⠒⠒⠦⠤⠤⠤⠤⠤⠤│ \n                  └────────────────────────────────────────┘ \n                  ⠀1⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀2 048⠀ \n                  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀task⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"The scenario that we will consider below is the following: We want to parallelize the operation sum(y -> log(y)^7, x), where x is a regular array. However, to establish the uneven workload shown above, we will make each task sum up a different number of elements of x, specifically as many elements as is indicated by the work_load array for the given task/work item.","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"For parallelization, we will use @spawn and @threads, which, respectively, does and doesn't implement load balancing. We'll test those in conjunction with the chunking variants :batch and :scatter described above.","category":"page"},{"location":"load_balancing/#Using-@threads","page":"Load balancing","title":"Using @threads","text":"","category":"section"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"First, we consider a variant where the @threads macro is used. The multithreaded operation is:","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"julia> using Base.Threads, ChunkSplitters\n\njulia> function uneven_workload_threads(x, work_load; n::Int, split::Symbol)\n           chunk_sums = Vector{eltype(x)}(undef, n)\n           @threads for (ichunk, inds) in enumerate(chunks(work_load; n=n, split=split))\n               local s = zero(eltype(x))\n               for i in inds\n                   s += sum(j -> log(x[j])^7, 1:work_load[i])\n               end\n               chunk_sums[ichunk] = s\n           end\n           return sum(chunk_sums)\n       end","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"Using n == Thread.nthreads() == 12, we get the following timings:","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"julia> using BenchmarkTools \n\njulia> @btime uneven_workload_threads($x, $work_load; n=nthreads(), split=:batch)\n  2.030 ms (71 allocations: 7.06 KiB)\n\njulia> @btime uneven_workload_threads($x, $work_load; n=nthreads(), split=:scatter)\n  587.309 μs (70 allocations: 7.03 KiB)","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"Note that despite the fact that @threads doesn't balance load internally, one can get \"poor man's load balancing\" by using :scatter instead of :batch. This is due to the fact that for :scatter we create chunks by sampling from the entire workload: chunks will consist of work items with vastly different computational weight. In contrast, for :batch, the first couple of chunks will have high workload and the latter ones very low workload.","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"For @threads, increasing n beyond nthreads() typically isn't helpful. This is because it will anyways always create nthreads() tasks (i.e. a fixed number), grouping up multiple of our chunks if necessary.","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"julia> @btime uneven_workload_threads($x, $work_load; n=8*nthreads(), split=:batch);\n  2.081 ms (74 allocations: 7.88 KiB)\n\njulia> @btime uneven_workload_threads($x, $work_load; n=8*nthreads(), split=:scatter);\n  632.149 μs (75 allocations: 7.91 KiB)","category":"page"},{"location":"load_balancing/#Using-@spawn","page":"Load balancing","title":"Using @spawn","text":"","category":"section"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"We can use @spawn to get \"proper\" load balancing through Julia's task scheduler. The spawned tasks, each associated with a chunk of the work_load array, will be dynamically scheduled at runtime. If there are enough tasks/chunks, the scheduler can map them to Julia threads in such a way that the overall workload per Julia thread is balanced.","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"Here is the implementation that we'll consider.","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"julia> function uneven_workload_spawn(x, work_load; n::Int, split::Symbol)\n           ts = map(chunks(work_load; n=n, split=split)) do inds\n               @spawn begin\n                   local s = zero(eltype(x))\n                   for i in inds\n                       s += sum(log(x[j])^7 for j in 1:work_load[i])\n                   end\n                   s\n               end\n           end\n           return sum(fetch.(ts))\n       end","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"For n == Thread.nthreads() == 12, we expect to see similar performance as for the @threads variant above, because we're creating the same (number of) chunks/tasks.","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"julia> @btime uneven_workload_spawn($x, $work_load; n=nthreads(), split=:batch);\n  1.997 ms (93 allocations: 7.30 KiB)\n\njulia> @btime uneven_workload_spawn($x, $work_load; n=nthreads(), split=:scatter);\n  573.399 μs (91 allocations: 7.23 KiB)","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"However, by increasing n > nthreads() we can give the dynamic scheduler more tasks (\"units of work\") to balance out and improve the load balancing. In this case, the difference between :batch and :scatter chunking becomes negligible.","category":"page"},{"location":"load_balancing/","page":"Load balancing","title":"Load balancing","text":"julia> @btime uneven_workload_spawn($x, $work_load; n=8*nthreads(), split=:batch);\n  603.830 μs (597 allocations: 53.30 KiB)\n\njulia> @btime uneven_workload_spawn($x, $work_load; n=8*nthreads(), split=:scatter);\n  601.519 μs (597 allocations: 53.30 KiB)","category":"page"},{"location":"#ChunkSplitters.jl","page":"Home","title":"ChunkSplitters.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"ChunkSplitters.jl facilitates the splitting of a given list of work items (of potentially uneven workload) into chunks that can be readily used for parallel processing. Operations on these chunks can, for example, be parallelized with Julia's multithreading tools, where separate tasks are created for each chunk. Compared to naive parallelization, ChunkSplitters.jl therefore effectively allows for more fine-grained control of the composition and workload of each parallel task.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Working with chunks and their respective indices also improves thread-safety compared to a naive approach based on threadid() indexing (see PSA: Thread-local state is no longer recommended). ","category":"page"},{"location":"","page":"Home","title":"Home","text":"compat: Compat\nIn ChunkSplitters version 2.1 the iteration with chunks returns the ranges of indices only. To retrieve the chunk indices, use enumerate(chunks(...)). Additionally, the number of chunks and the split type of chunks are assigned with keyword arguments n, and split.  This change is not breaking because the legacy interface (of version 2.0) is still valid, although it is no longer documented and will be deprecated in version 3.0.","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Install with:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> import Pkg; Pkg.add(\"ChunkSplitters\")","category":"page"},{"location":"#The-chunks-iterator","page":"Home","title":"The chunks iterator","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The main interface is the chunks iterator, and the enumeration of chunks, with enumerate.","category":"page"},{"location":"","page":"Home","title":"Home","text":"chunks(array::AbstractArray; n::Int, size::Int, split::Symbol=:batch)","category":"page"},{"location":"","page":"Home","title":"Home","text":"This iterator returns a vector of ranges which indicates the range of indices of the input array for each given chunk. The split parameter is optional. If split == :batch, the ranges are consecutive (default behavior). If split == :scatter, the range is scattered over the array.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The different chunking variants are illustrated in the following figure: ","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: splitter types)","category":"page"},{"location":"","page":"Home","title":"Home","text":"For split=:batch, each chunk is \"filled up\" with work items one after another such that all chunks hold approximately the same number of work items (as far as possible). For split=:scatter, the work items are assigned to chunks in a round-robin fashion. As shown below, this way of chunking can be beneficial if the workload (i.e. the computational weight) for different items is uneven. ","category":"page"},{"location":"","page":"Home","title":"Home","text":"The chunks can be defined by their number n, or by their size size, in the call to the chunks method. If n is set, the chunks will have the most even distribution of sizes possible, while if size is set, the chunks will have a constant size, except for possible last remaining chunk.   ","category":"page"},{"location":"","page":"Home","title":"Home","text":"compat: Compat\nDefining the chunks with size was introduced in version 2.3.0, and is only compatible with the :batch  chunking option. ","category":"page"},{"location":"#Basic-interface","page":"Home","title":"Basic interface","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Let's first illustrate the chunks returned by chunks for the different chunking variants:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> for inds in chunks(x; n=3, split=:batch)\n           @show inds\n       end\ninds = 1:1:3\ninds = 4:1:5\ninds = 6:1:7\n\njulia> for inds in chunks(x; n=3, split=:scatter)\n           @show inds\n       end\ninds = 1:3:7\ninds = 2:3:5\ninds = 3:3:6\n\njulia> for inds in chunks(x; size=4)\n           @show inds\n       end\ninds = 1:1:4\ninds = 5:1:7","category":"page"},{"location":"","page":"Home","title":"Home","text":"The chunk indices can be retrieved with the enumerate function, which is specialized for the ChunkSplitters structure such that it works with @threads: ","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using ChunkSplitters, Base.Threads\n\njulia> x = rand(7);\n\njulia> @threads for (ichunk, inds) in enumerate(chunks(x; n=3))\n           @show ichunk, inds\n       end\n(ichunk, inds) = (1, 1:1:3)\n(ichunk, inds) = (2, 4:1:5)\n(ichunk, inds) = (3, 6:1:7)","category":"page"},{"location":"#Simple-multi-threaded-example","page":"Home","title":"Simple multi-threaded example","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Now, let's demonstrate how to use chunks in a simple multi-threaded example:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using BenchmarkTools\n\njulia> using ChunkSplitters\n\njulia> function sum_parallel(f, x; n=Threads.nthreads())\n           t = map(chunks(x; n=n)) do inds\n               Threads.@spawn sum(f, @view x[inds])\n           end\n           return sum(fetch.(t))\n       end\n\njulia> x = rand(10^8);\n\njulia> Threads.nthreads()\n12\n\njulia> @btime sum(x -> log(x)^7, $x);\n  1.353 s (0 allocations: 0 bytes)\n\njulia> @btime sum_parallel(x -> log(x)^7, $x; n=Threads.nthreads());\n  120.429 ms (98 allocations: 7.42 KiB)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Of course, chunks can also be used in conjunction with @threads (see below).","category":"page"},{"location":"#Shared-buffers:-using-enumerate","page":"Home","title":"Shared buffers: using enumerate","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"If shared buffers are required, the enumeration of the buffers by chunk using enumerate is useful, to avoid using the id of the thread. For example, here we accumulate intermediate results of the sum in an array chunk_sums of length n, which is later reduced:","category":"page"},{"location":"","page":"Home","title":"Home","text":"A simple @threads-based example:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using ChunkSplitters, Base.Threads\n\njulia> x = collect(1:10^5);\n\njulia> n = nthreads();\n\njulia> chunk_sums = zeros(Int, n);\n\njulia> @threads for (ichunk, inds) in enumerate(chunks(x; n=n))\n           chunk_sums[ichunk] += sum(@view x[inds])\n       end\n\njulia> sum(chunk_sums)\n5000050000","category":"page"},{"location":"","page":"Home","title":"Home","text":"warning: Warning\nUsing shared buffers like this can lead to performance issues caused by false-sharing: A thread writes to the buffer, invalidates the cache-line for other threads, and thus causes expensive restoration of cache coherence. The example above intends to illustrate the syntax to be used to index the buffers, rather than to suggest this a an optimal pattern for parallelization. ","category":"page"},{"location":"#Lower-level-getchunk-function","page":"Home","title":"Lower-level getchunk function","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The package also provides a lower-level getchunk function:","category":"page"},{"location":"","page":"Home","title":"Home","text":"getchunk(array::AbstractArray, ichunk::Int; n::Int, size::Int, split::Symbol=:batch)","category":"page"},{"location":"","page":"Home","title":"Home","text":"that returns the range of indices corresponding to the work items in the input array that are associated with chunk number ichunk. ","category":"page"},{"location":"","page":"Home","title":"Home","text":"The chunks can be defined by their number, n, or by their size size.","category":"page"},{"location":"","page":"Home","title":"Home","text":"For example, if we have an array of 7 elements, and the work on the elements is divided into 3 chunks, we have (using the default split == :batch option):","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> getchunk(x, 1; n=3)\n1:1:3\n\njulia> getchunk(x, 2; n=3)\n4:1:5\n\njulia> getchunk(x, 3; n=3)\n6:1:7\n\njulia> getchunk(x, 1; size=3)\n1:1:3","category":"page"},{"location":"","page":"Home","title":"Home","text":"And using split = :scatter, we have:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using ChunkSplitters \n\njulia> x = rand(7);\n\njulia> getchunk(x, 1; n=3, split=:scatter)\n1:3:7\n\njulia> getchunk(x, 2; n=3, split=:scatter)\n2:3:5\n\njulia> getchunk(x, 3; n=3, split=:scatter)\n3:3:6","category":"page"},{"location":"#Example:-getchunk-usage","page":"Home","title":"Example: getchunk usage","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"julia> using BenchmarkTools\n\njulia> using ChunkSplitters\n\njulia> function sum_parallel_getchunk(f, x; n=Threads.nthreads())\n           t = map(1:n) do ichunk\n               Threads.@spawn begin\n                   local inds = getchunk(x, ichunk; n=n)\n                   sum(f, @view x[inds])\n               end\n           end\n           return sum(fetch.(t))\n       end\n\njulia> x = rand(10^8);\n\njulia> Threads.nthreads()\n12\n\njulia> @btime sum(x -> log(x)^7, $x);\n  1.363 s (0 allocations: 0 bytes)\n\njulia> @btime sum_parallel_getchunk(x -> log(x)^7, $x; n=Threads.nthreads());\n  121.651 ms (100 allocations: 7.31 KiB)","category":"page"}]
}
