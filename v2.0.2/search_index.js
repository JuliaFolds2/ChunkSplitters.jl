var documenterSearchIndex = {"docs":
[{"location":"references/#References","page":"References","title":"References","text":"","category":"section"},{"location":"references/#Index","page":"References","title":"Index","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"Pages   = [\"references.md\"]\nOrder   = [:function, :type]","category":"page"},{"location":"references/#ChunkSplitters","page":"References","title":"ChunkSplitters","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"Modules = [ChunkSplitters]\nPages   = [\"ChunkSplitters.jl\"]","category":"page"},{"location":"references/#ChunkSplitters.chunks","page":"References","title":"ChunkSplitters.chunks","text":"chunks(array::AbstractArray, nchunks::Int, type::Symbol=:batch)\n\nThis function returns an iterable object that will split the indices of array into to nchunks chunks. type can be :batch or :scatter. It can be used to directly iterate over the chunks of a collection in a multi-threaded manner.\n\nExample\n\njulia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> for i in chunks(x, 3, :batch)\n           @show Threads.threadid(), collect(i)\n       end\n(Threads.threadid(), collect(i)) = (6, [1, 2, 3])\n(Threads.threadid(), collect(i)) = (8, [4, 5])\n(Threads.threadid(), collect(i)) = (7, [6, 7])\n\njulia> for i in chunks(x, 3, :scatter)\n           @show Threads.threadid(), collect(i)\n       end\n(Threads.threadid(), collect(i)) = (2, [1, 4, 7])\n(Threads.threadid(), collect(i)) = (11, [2, 5])\n(Threads.threadid(), collect(i)) = (3, [3, 6])\n\n\n\n\n\n","category":"function"},{"location":"references/#ChunkSplitters.getchunk","page":"References","title":"ChunkSplitters.getchunk","text":"getchunk(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)\n\nFunction that returns a range of indexes of array, given the number of chunks in which the array is to be split, nchunks, and the current chunk number ichunk.\n\nIf type == :batch, the ranges are consecutive. If type == :scatter, the range is scattered over the array.\n\nnote: Note\nThe getchunk function is available in version 2 of the package. In version 1 it was named chunks.\n\nExample\n\nFor example, if we have an array of 7 elements, and the work on the elements is divided into 3 chunks, we have (using the default type = :batch option):\n\njulia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> getchunk(x, 1, 3)\n1:3\n\njulia> getchunk(x, 2, 3)\n4:5\n\njulia> getchunk(x, 3, 3)\n6:7\n\nAnd using type = :scatter, we have:\n\njulia> getchunk(x, 1, 3, :scatter)\n1:3:7\n\njulia> getchunk(x, 2, 3, :scatter)\n2:3:5\n\njulia> getchunk(x, 3, 3, :scatter)\n3:3:6\n\n\n\n\n\n","category":"function"},{"location":"#ChunkSplitters.jl","page":"Home","title":"ChunkSplitters.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"ChunkSplitters.jl facilitates the splitting of a given list of work items (of potentially uneven workload) into chunks that can be readily used for parallel processing. Operations on these chunks can, for example, be parallelized with Julia's multithreading tools, where separate tasks are created for each chunk. Compared to naive parallelization, ChunkSplitters.jl therefore effectively allows for more fine-grained control of the composition and workload of each parallel task.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Working with chunks and their respective indices also improves thread-safety compared to a naive approach based on threadid() indexing (see PSA: Thread-local state is no longer recommended). ","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Install with:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> import Pkg; Pkg.add(\"ChunkSplitters\")","category":"page"},{"location":"#The-chunks-iterator","page":"Home","title":"The chunks iterator","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The main interface is the chunks iterator:","category":"page"},{"location":"","page":"Home","title":"Home","text":"chunks(array::AbstractArray, nchunks::Int, type::Symbol=:batch)","category":"page"},{"location":"","page":"Home","title":"Home","text":"This iterator returns a Tuple{UnitRange,Int} which indicates the range of indices of the input array for each given chunk and the index of the latter. The type parameter is optional. If type == :batch, the ranges are consecutive (default behavior). If type == :scatter, the range is scattered over the array.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The different chunking variants are illustrated in the following figure: ","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: splitter types)","category":"page"},{"location":"","page":"Home","title":"Home","text":"For type=:batch, each chunk is \"filled up\" with work items one after another such that all chunks hold approximately the same number of work items (as far as possible). For type=:scatter, the work items are assigned to chunks in a round-robin fashion. As shown below, this way of chunking can be beneficial if the workload (i.e. the computational weight) for different items is uneven. ","category":"page"},{"location":"#Basic-example","page":"Home","title":"Basic example","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Let's first illustrate the chunks returned by chunks for the different chunking variants:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using ChunkSplitters \n\njulia> x = rand(7);\n\njulia> for (xrange,ichunk) in chunks(x, 3, :batch)\n           @show (xrange, ichunk)\n       end\n(xrange, ichunk) = (1:3, 1)\n(xrange, ichunk) = (4:5, 2)\n(xrange, ichunk) = (6:7, 3)\n\njulia> for (xrange,ichunk) in chunks(x, 3, :scatter)\n           @show (xrange, ichunk)\n       end\n(xrange, ichunk) = (1:3:7, 1)\n(xrange, ichunk) = (2:3:5, 2)\n(xrange, ichunk) = (3:3:6, 3)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Now, let's demonstrate how to use chunks in a simple multi-threaded example:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using BenchmarkTools\n\njulia> using ChunkSplitters\n\njulia> function sum_parallel(f, x; nchunks=Threads.nthreads())\n           t = map(chunks(x, nchunks)) do (idcs, ichunk)\n               Threads.@spawn sum(f, @view x[idcs])\n           end\n           return sum(fetch.(t))\n       end\n\njulia> x = rand(10^8);\n\njulia> Threads.nthreads()\n12\n\njulia> @btime sum(x -> log(x)^7, $x);\n  1.353 s (0 allocations: 0 bytes)\n\njulia> @btime sum_parallel(x -> log(x)^7, $x; nchunks=Threads.nthreads());\n  120.429 ms (98 allocations: 7.42 KiB)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Of course, chunks can also be used in conjuction with @threads (see below).","category":"page"},{"location":"#Load-balancing-considerations","page":"Home","title":"Load balancing considerations","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"We create a very unbalanced workload:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> work_load = ceil.(Int, collect(10^3 * exp(-0.002*i) for i in 1:2^11));\n\njulia> using UnicodePlots\n\njulia> lineplot(work_load; xlabel=\"task\", ylabel=\"workload\", xlim=(1,2^11))\n                  ┌────────────────────────────────────────┐ \n            1 000 │⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠘⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⢹⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠈⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠈⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n   workload       │⠀⠀⠀⠀⠀⠀⠳⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠙⢦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠲⢤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠓⠦⠤⣄⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ \n                0 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠓⠒⠒⠒⠦⠤⠤⠤⠤⠤⠤│ \n                  └────────────────────────────────────────┘ \n                  ⠀1⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀2 048⠀ \n                  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀task⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ","category":"page"},{"location":"","page":"Home","title":"Home","text":"The scenario that we will consider below is the following: We want to parallize the operation sum(y -> log(y)^7, x), where x is a regular array. However, to establish the uneven workload shown above, we will make each task sum up a different number of elements of x, specifically as many elements as is indicated by the work_load array for the given task/work item.","category":"page"},{"location":"","page":"Home","title":"Home","text":"For parallelization, we will use @spawn and @threads, which, respectively, does and doesn't implement load balancing. We'll test those in conjuction with the chunking variants :batch and :scatter described above.","category":"page"},{"location":"#Using-@threads","page":"Home","title":"Using @threads","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"First, we consider a variant where the @threads macro is used. The multithreaded operation is:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using Base.Threads, ChunkSplitters\n\njulia> function uneven_workload_threads(x, work_load; nchunks::Int, chunk_type::Symbol)\n           chunk_sums = Vector{eltype(x)}(undef, nchunks)\n           @threads for (idcs, ichunk) in chunks(work_load, nchunks, chunk_type)\n               s = zero(eltype(x))\n               for i in idcs\n                   s += sum(y -> log(y)^7, 1:work_load[i])\n               end\n               chunk_sums[ichunk] = s\n           end\n           return sum(chunk_sums)\n       end","category":"page"},{"location":"","page":"Home","title":"Home","text":"Using nchunks == Thread.nthreads() == 12, we get the following timings:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using BenchmarkTools \n\njulia> @btime uneven_workload_threads($x, $work_load; nchunks=nthreads(), chunk_type=:batch)\n  2.030 ms (71 allocations: 7.06 KiB)\n\njulia> @btime uneven_workload_threads($x, $work_load; nchunks=nthreads(), chunk_type=:scatter)\n  587.309 μs (70 allocations: 7.03 KiB)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note that despite the fact that @threads doesn't balance load internally, one can get \"poor man's load balancing\" by using :scatter instead of :batch. This is due to the fact that for :scatter we create chunks by sampling from the entire workload: chunks will consist of work items with vastly different computational weight. In contrast, for :batch, the first couple of chunks will have high workload and the latter ones very low workload.","category":"page"},{"location":"","page":"Home","title":"Home","text":"For @threads, increasing nchunks beyond nthreads() typically isn't helpful. This is because it will anyways always create O(nthreads()) tasks (i.e. a fixed number), grouping up multiple of our chunks if necessary.","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> @btime uneven_workload_threads($x, $work_load; nchunks=8*nthreads(), chunk_type=:batch);\n  2.081 ms (74 allocations: 7.88 KiB)\n\njulia> @btime uneven_workload_threads($x, $work_load; nchunks=8*nthreads(), chunk_type=:scatter);\n  632.149 μs (75 allocations: 7.91 KiB)","category":"page"},{"location":"#Using-@spawn","page":"Home","title":"Using @spawn","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"We can use @spawn to get \"proper\" load balancing through Julia's task scheduler. The spawned tasks, each associated with a chunk of the work_load array, will be dynamically scheduled at runtime. If there are enough tasks/chunks, the scheduler can map them to Julia threads in such a way that the overall workload per Julia thread is balanced.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Here is the implementation that we'll consider.","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> function uneven_workload_spawn(x, work_load; nchunks::Int, chunk_type::Symbol)\n           ts = map(chunks(work_load, nchunks, chunk_type)) do (idcs, ichunk)\n               @spawn begin\n                   s = zero(eltype(x))\n                   for i in idcs\n                       s += sum(log(x[j])^7 for j in 1:work_load[i])\n                   end\n                   s\n               end\n           end\n           return sum(fetch.(ts))\n       end","category":"page"},{"location":"","page":"Home","title":"Home","text":"For nchunks == Thread.nthreads() == 12, we expect to see similar performance as for the @threads variant above, because we're creating the same (number of) chunks/tasks.","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> @btime uneven_workload_spawn($x, $work_load; nchunks=nthreads(), chunk_type=:batch);\n  1.997 ms (93 allocations: 7.30 KiB)\n\njulia> @btime uneven_workload_spawn($x, $work_load; nchunks=nthreads(), chunk_type=:scatter);\n  573.399 μs (91 allocations: 7.23 KiB)","category":"page"},{"location":"","page":"Home","title":"Home","text":"However, by increasing nchunks > nthreads() we can give the dynamic scheduler more tasks (\"units of work\") to balance out and improve the load balancing. In this case, the difference between :batch and :scatter chunking becomes negligible.","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> @btime uneven_workload_spawn($x, $work_load; nchunks=8*nthreads(), chunk_type=:batch);\n  603.830 μs (597 allocations: 53.30 KiB)\n\njulia> @btime uneven_workload_spawn($x, $work_load; nchunks=8*nthreads(), chunk_type=:scatter);\n  601.519 μs (597 allocations: 53.30 KiB)","category":"page"},{"location":"#Lower-level-getchunk-function","page":"Home","title":"Lower-level getchunk function","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The package also provides a lower-level getchunk function:","category":"page"},{"location":"","page":"Home","title":"Home","text":"getchunk(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)","category":"page"},{"location":"","page":"Home","title":"Home","text":"that returns the range of indexes corresponding to the work items in the input array that are associated with chunk number ichunk. ","category":"page"},{"location":"","page":"Home","title":"Home","text":"For example, if we have an array of 7 elements, and the work on the elements is divided into 3 chunks, we have (using the default type = :batch option):","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using ChunkSplitters\n\njulia> x = rand(7);\n\njulia> getchunk(x, 1, 3)\n1:3\n\njulia> getchunk(x, 2, 3)\n4:5\n\njulia> getchunk(x, 3, 3)\n6:7","category":"page"},{"location":"","page":"Home","title":"Home","text":"And using type = :scatter, we have:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> getchunk(x, 1, 3, :scatter)\n1:3:7\n\njulia> getchunk(x, 2, 3, :scatter)\n2:3:5\n\njulia> getchunk(x, 3, 3, :scatter)\n3:3:6","category":"page"},{"location":"#Example:-getchunk-usage","page":"Home","title":"Example: getchunk usage","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"julia> using BenchmarkTools\n\njulia> using ChunkSplitters\n\njulia> function sum_parallel_getchunk(f, x; nchunks=Threads.nthreads())\n           t = map(1:nchunks) do ichunk\n               Threads.@spawn begin\n                   idcs = getchunk(x, ichunk, nchunks)\n                   sum(f, @view x[idcs])\n               end\n           end\n           return sum(fetch.(t))\n       end\n\njulia> x = rand(10^8);\n\njulia> Threads.nthreads()\n12\n\njulia> @btime sum(x -> log(x)^7, $x);\n  1.363 s (0 allocations: 0 bytes)\n\njulia> @btime sum_parallel_getchunk(x -> log(x)^7, $x; nchunks=Threads.nthreads());\n  121.651 ms (100 allocations: 7.31 KiB)","category":"page"}]
}