OhMyThreads.jl Changelog
=========================

Version 3.0.0
-------------
- ![BREAKING][badge-breaking] The new lower compat bound for Julia is 1.10. This implies that support for the old LTS 1.6 has been dropped.
- ![BREAKING][badge-breaking] `chunks` has been renamed to `chunk_indices`.
- ![BREAKING][badge-breaking] A new function `chunk` has been introduced that returns an iterator that provides chunks of **elements** rather than chunks of **indices** of a given input collection. To avoid copies, it is based on `view`.
- ![BREAKING][badge-breaking] The old legacy API that relied on positional rather than keyword arguments has been dropped.
- ![BREAKING][badge-breaking] For performance reasons, the `split` keyword option now requires a `Split` instead of a `Symbol`. Concretely, `:batch` should be replaced by `BatchSplit()` and `:scatter` should be replaced by `ScatterSplit()`.
- ![BREAKING][badge-breaking] `getchunk` isn't public API anymore (and has, internally, been renamed to `getchunkindices`).


[badge-breaking]: https://img.shields.io/badge/BREAKING-red.svg
[badge-deprecation]: https://img.shields.io/badge/Deprecation-orange.svg
[badge-feature]: https://img.shields.io/badge/Feature-green.svg
[badge-experimental]: https://img.shields.io/badge/Experimental-yellow.svg
[badge-enhancement]: https://img.shields.io/badge/Enhancement-blue.svg
[badge-bugfix]: https://img.shields.io/badge/Bugfix-purple.svg
[badge-fix]: https://img.shields.io/badge/Fix-purple.svg
[badge-info]: https://img.shields.io/badge/Info-gray.svg
