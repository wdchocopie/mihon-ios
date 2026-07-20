# Performance standards

Don't optimize prematurely, but flag obvious problems in hot paths.

- **N+1 queries**: fetching related records in a loop instead of a join or batch load.
- **Algorithmic complexity**: O(n²) or worse where O(n log n) or O(n) is straightforward.
- **Unbounded queries**: loading entire tables when pagination or a limit is needed.
- **Unnecessary work in loops**: computations or allocations that belong outside the loop.
- **Blocking I/O on the main thread**: network or disk calls that should be async.

The test: *is this in a hot path and will it hurt at scale?* If yes, flag it as a Blocker
or Suggestion. If it's a rarely-called admin endpoint, a Suggestion (or a Nit) is enough.
