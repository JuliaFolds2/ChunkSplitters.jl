module ChunkSplitters

include("api.jl")
include("internals.jl")

export chunk_indices, chunk, Split, BatchSplit, ScatterSplit
if VERSION >= v"1.11.0-DEV.469"
    eval(Meta.parse("public is_chunkable"))
end

end # module
