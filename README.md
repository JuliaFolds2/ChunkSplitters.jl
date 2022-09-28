# ChunkSplitters

This package provides the `splitter` function, that facilitates writing multi-threaded
executions that split the work in chunks.

```julia
splitter(array::AbstractArray, ichunk::Int, nchunks::Int, type::Symbol=:batch)
```

Function that returns a range of indexes of `array`, given the number of chunks in
which the array is to be split, `nchunks`, and the current chunk number `ichunk`. 

If `type == :batch`, the ranges are consecutive. If `type == :scatter`, the range
is scattered over the array. 

## Examples

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