// stdlib coverage matrix for the two layer book: family by family,
// placed on its edition shelf with this runtime's verdict. the
// es2026 edition was approved 2026-06-30, node 26.3.0 runs five of
// its seven features, ships the json half, and lacks one outright.
#let components = (
  // es2023 and es2024 shelves
  (component: "Array change-by-copy: toSorted, with, toReversed", chapter: "stdlib", status: "covered, es2023"),
  (component: "Object.groupBy and its null prototype", chapter: "stdlib", status: "covered, es2024"),
  (component: "Promise.withResolvers", chapter: "stdlib", status: "shelf row only, es2024, not demonstrated"),
  // es2025 shelf
  (component: "Iterator helpers: map, filter, take, drop, flatMap", chapter: "iteration", status: "covered, es2025, lazy by call count"),
  (component: "Iterator.concat", chapter: "iteration", status: "covered, es2026, lazy by tap count"),
  (component: "Set algebra: four producers, three predicates", chapter: "iteration", status: "covered, es2025"),
  (component: "iteration protocols, Symbol.iterator, replay", chapter: "iteration", status: "covered"),
  (component: "generators, yield delegation, two way next", chapter: "iteration", status: "covered"),
  (component: "Map and Set, SameValueZero, insertion order", chapter: "iteration", status: "covered"),
  (component: "Map and WeakMap getOrInsert, getOrInsertComputed", chapter: "iteration", status: "covered, es2026"),
  (component: "WeakMap and WeakRef, the deterministic facts", chapter: "iteration", status: "covered"),
  (component: "Float16Array, Math.f16round, DataView", chapter: "iteration", status: "covered, es2025"),
  (component: "Uint8Array base64 and hex codecs", chapter: "iteration", status: "covered, es2026, byte exact"),
  (component: "RegExp.escape, the measured escape classes", chapter: "stdlib", status: "covered, es2025"),
  (component: "Promise.try", chapter: "async", status: "covered, es2025"),
  (component: "using, Symbol.dispose, DisposableStack", chapter: "modules", status: "covered, es2025"),
  (component: "import attributes with json, the with clause", chapter: "modules", status: "covered, es2025, assert removed"),
  // es2026 shelf, five live here
  (component: "Array.fromAsync", chapter: "async", status: "covered, es2026, esnext.array fragment"),
  (component: "Error.isError", chapter: "stdlib", status: "covered, es2026"),
  (component: "JSON.rawJSON and isRawJSON", chapter: "stdlib", status: "covered, es2026, emit exact only"),
  // es2026, the two honest absences
  (component: "Math.sumPrecise", chapter: "stdlib", status: "absent, undefined on node 26.3.0, pinned by test"),
  (component: "JSON.parse source text access", chapter: "stdlib", status: "absent, arity 2, parse returns the double"),
  // es2027 slated, live here
  (component: "Temporal: Instant, PlainDate, ZonedDateTime, Duration", chapter: "stdlib", status: "covered at runtime, stage 4, es2027 slated"),
  (component: "Temporal string boundary, toJSON rfc 9557", chapter: "stdlib", status: "covered, relational operators throw"),
  // the standing families
  (component: "Promise: all, allSettled, race, any", chapter: "async", status: "covered"),
  (component: "AbortSignal, timeout, any", chapter: "async", status: "covered"),
  (component: "microtask and timer ordering", chapter: "async", status: "covered"),
  (component: "for await..of, async generators, Symbol.asyncIterator", chapter: "async", status: "covered"),
  (component: "prototypes, Object.create, Symbol.hasInstance", chapter: "objects", status: "covered"),
  (component: "Object statics: keys, defineProperty, freeze", chapter: "objects", status: "covered"),
  (component: "string code points against utf-16 units", chapter: "lexical", status: "covered"),
  (component: "structuredClone boundaries", chapter: "stdlib", status: "covered"),
  (component: "Error cause chains", chapter: "stdlib", status: "covered, es2022"),
  (component: "Intl.Collator numeric sorting", chapter: "stdlib", status: "covered"),
  (component: "live bindings, dynamic import, import.meta", chapter: "modules", status: "covered"),
  (component: "node:test and node:assert/strict", chapter: "toolchain", status: "covered"),
  (component: "node:fs, node:path, node:child_process probes", chapter: "typemodules", status: "covered"),
  (component: "node:sqlite, DatabaseSync, Symbol.dispose", chapter: "capstone", status: "covered, engine 3.53.1 measured"),
  // 3.0 runtime deep dives
  (component: "node:v8, getHeapSpaceStatistics, heap spaces", chapter: "heap", status: "covered, 15 spaces measured on 26.3.0"),
  (component: "ArrayBuffer external memory, memoryUsage counters", chapter: "heap", status: "covered, arrayBuffers against heapUsed measured"),
  (component: "WeakRef and FinalizationRegistry under --expose-gc", chapter: "heap", status: "covered, child run measured"),
  (component: "Float64Array against object literals, the particle kernel", chapter: "heap", status: "covered, 1m and 100m measured"),
  (component: "--cpu-prof and --heap-prof captures, parsed in suite", chapter: "profiling", status: "covered, child runs measured"),
  (component: "node:inspector Session, Profiler domain", chapter: "profiling", status: "covered, in-process session asserted"),
  (component: "monitorEventLoopDelay percentiles, perf_hooks", chapter: "profiling", status: "covered, p50 p99 measured"),
  (component: "AsyncLocalStorage and async_hooks tracing", chapter: "profiling", status: "covered, trace across awaits"),
  (component: "node:sqlite row kernel, GROUP BY against a cursor walk", chapter: "profiling", status: "covered, 10m and 100m measured"),
  (component: "decorators and the accessor keyword", chapter: "typeclasses", status: "covered, stage 3"),
)

#let stdlib-coverage = components
