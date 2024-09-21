module ChunkSplitters

include("api.jl")
include("internals.jl")

export chunk_indices, chunk
export Split, Consecutive, RoundRobin

if VERSION >= v"1.11.0-DEV.469"
    eval(Meta.parse("public is_chunkable"))
end

end # module
