ChunkSplitters.jl Changelog
===========================

Version 3.1.2
-------------
- ![ENHANCEMENT][badge-enhancement] Return a single chunk if `minsize > length(collection)`.
- ![BUGFIX][badge-bugfix] Indexing chunk iterators returns out-of-bounds error if the iterator is empty now (previously returned an empty range).
  
Version 3.1.1
-------------
- ![BUGFIX][badge-bugfix] Throw an error if `minsize > length(collection)`. Before returned an empty collection of chunks.

Version 3.1.0
-------------
- ![INFO][badge-info] Recover support for Julia 1.6+. All tests pass from 1.9+, and an allocation test fails in 1.6.

Version 3.0.0
-------------
- ![BREAKING][badge-breaking] The new lower compat bound for Julia is 1.10. This implies that support for the old LTS 1.6 has been dropped.
- ![BREAKING][badge-breaking] The old main API function `chunks` has been renamed to `index_chunks`.
- ![BREAKING][badge-breaking] A new function `chunks` has been introduced that returns an iterator that provides chunks of **elements** rather than chunks of **indices** of a given input collection. To avoid copies, it is based on `view`.
- ![BREAKING][badge-breaking] For performance reasons, the `split` keyword option now requires a `Split` instead of a `Symbol`. Concretely, `:batch` should be replaced by `Consecutive()` and `:scatter` should be replaced by `RoundRobin()`.
- ![BREAKING][badge-breaking] The keyword argument `minchunksize` has been renamed to `minsize`.
- ![BREAKING][badge-breaking] `getchunk` isn't public API anymore (and has, internally, been renamed to `getchunkindices`). If you really need a replacement, consider using `index_chunks(...)[i]` instead.
- ![BREAKING][badge-breaking] The old legacy API that relied on positional rather than keyword arguments has been dropped.


[badge-breaking]: https://img.shields.io/badge/BREAKING-red.svg
[badge-deprecation]: https://img.shields.io/badge/Deprecation-orange.svg
[badge-feature]: https://img.shields.io/badge/Feature-green.svg
[badge-experimental]: https://img.shields.io/badge/Experimental-yellow.svg
[badge-enhancement]: https://img.shields.io/badge/Enhancement-blue.svg
[badge-bugfix]: https://img.shields.io/badge/Bugfix-purple.svg
[badge-fix]: https://img.shields.io/badge/Fix-purple.svg
[badge-info]: https://img.shields.io/badge/Info-gray.svg
