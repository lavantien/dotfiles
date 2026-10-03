#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= how cpython runs your code

A python file on disk and a running function are four different
things separated by three machines: the tokenizer and parser, the
compiler that emits bytecode, and the eval loop that executes it.
This chapter walks the whole distance on cpython 3.14. Source becomes
a code object through `compile()`, the code object becomes a frame
with locals, globals, and cells when called, the frame feeds an
instruction at a time to an eval loop that rewrites hot instructions
in place, and above that loop sits a tier 2 jit that ships in this
windows build but stays switched off until an environment variable
says otherwise. The verification mode is the gate: the five samples
under `Ch12/` print 51 `ok` lines in total, and an `expect-dis.txt`
sits beside them asserting nine stable bytecode facts, because
bytecode claims should be checked the way terraform claims are, by a
machine.

== source to bytecode

`compile()` is the whole front end as a function: it takes source
text, a filename to stamp into error messages, and a mode. The mode
is a contract about shape. `exec` accepts statements and returns a
module-level code object, `eval` accepts exactly one expression, and
anything else is rejected by name. The return is a `types.CodeType`
whose fields are the program in miniature, `co_name` and
`co_qualname` for identity, `co_varnames` for the local slots in
argument order, `co_consts` for the literals, `co_names` for the
globals the body touches:

#listing("python/samples/src/Ch12/bytecode.py", first: 25, last: 51, caption: [compile in three modes, and the code object fields the body compiled to])

The function body is itself a nested code object inside the module's
`co_consts`, and the sample's `inner_code` helper digs it out to read
`co_varnames == ("x", "factor")` and the default living beside the
code rather than inside it. `exec()` of the compiled module into a
namespace builds the function and runs it, which is the whole import
story of #xref-to("python", "modules") compressed into two calls:
compile, then execute. The `optimize` argument reaches the same
switch `-O` flips at startup, and the sample pins its effect: with
`optimize=2` the assert machinery, compare, conditional jump, and
raise, is absent from the instruction stream entirely:

#listing("python/samples/src/Ch12/bytecode.py", first: 69, last: 84, caption: [optimize=2 compiles the assert away, the same code with and without it])

Imported modules get the same treatment with a cache in front. The
first import of a `.py` file compiles it and writes the bytecode to
`__pycache__` under a tag naming the interpreter, `cpython-314` here.
The reference states the validation rule: "Before Python loads cached
bytecode from a `.pyc` file, it checks whether the cache is
up-to-date with the source `.py` file. By default, Python does this
by storing the source's last-modified timestamp and size in the cache
file when writing it." The sample imports a fresh module, finds the
pyc, and reads the 16-byte header with `struct`: magic, flags, mtime,
size, then asserts mtime and size equal the source's:

#listing("python/samples/src/Ch12/pycache.py", first: 22, last: 40, caption: [the pyc path, and its header unpacked into magic, flags, mtime, size])

The eviction sequence then exercises both halves of the rule. A
rewrite that changes the size invalidates the pyc once the cache
entry is dropped, and a rewrite that keeps the size and lands inside
the same whole second does not, because both stored numbers still
match. The mtime is compared to whole-second resolution, so a same-
length edit inside one second is invisible to the check:

#listing("python/samples/src/Ch12/pycache.py", first: 59, last: 72, caption: [the stale trap: same size, same second, the old bytecode still loads])

#callout("pitfall", "the stale pyc is a real windows edit loop", [
  The trap fires exactly where developers work fastest: save a small
  edit, rerun, see the old behavior. Same-length edits are rare by
  hand but routine for tools that rewrite files in place, and the
  one-second granularity means rapid successive saves can land in one
  bucket. The reference also documents the alternative, hash-based
  pyc files "which store a hash of the source file's contents rather
  than its metadata", written by `py_compile` with its invalidation
  modes. Default cpython runs do not use them.
])

#diagram([source to running code: the two trips, first import and every later one], length: 13pt, {
  let stage(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  stage(0.6, 6.4, 4.4, [shapes.py source], fill: luma(205))
  stage(0.6, 3.2, 4.4, [\_\_pycache\_\_ bytes], fill: luma(215))
  stage(6.4, 6.4, 4.4, [tokenize, parse, compile])
  stage(12.2, 6.4, 4.4, [code object])
  stage(17.6, 6.4, 4.4, [frame, eval loop], fill: luma(205))
  stage(12.2, 3.2, 4.4, [magic, flags, mtime, size])
  cdraw.line((5.0, 6.9), (6.4, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.8, 6.9), (12.2, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.6, 6.9), (17.6, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.4, 6.4), (14.4, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.6, 5.3), [write pyc], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((2.8, 6.4), (2.8, 4.2), stroke: luma(100), mark: (end: "<"))
  cdraw.line((2.8, 3.2), (12.2, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 4.0), [later imports: check mtime and size, then load], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.6, 1.6), [same size inside the same second: the stale pyc still loads, probed], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.6, 0.6), [hash-based pyc files exist but no default run writes them], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== frames and cells

Executing a code object means building a frame around it, and the
frame is where every name lookup begins. `sys._getframe()` returns
the frame of the running call, and its three dictionaries are a
chain: `f_locals` is the call's own slots, `f_globals` is the module
dict the code was defined in, `f_builtins` is where `print` and
friends resolve. A global read walks locals to globals to builtins
and a global write touches only globals. The sample reads its own
frame from inside a function and asserts each layer's identity:

#listing("python/samples/src/Ch12/frames.py", first: 17, last: 32, caption: [one frame, its three dictionaries, and the caller one level up])

Closures are the same machinery pointed sideways. When
`closure_factory` defines `closure_target`, the inner function's
reference to `n` is not a copy, it is a cell, and `MAKE_CELL`
allocates it in the factory's frame before the inner code object ever
runs. The function object carries the cell in `__closure__`, names
it in `co_freevars`, and reads it with `LOAD_DEREF`. The sample
checks all of it, then writes through the cell and shows that every
future call sees the new value:

#listing("python/samples/src/Ch12/frames.py", first: 44, last: 71, caption: [the cell: carried on the function, named in co\_freevars, read with LOAD\_DEREF])

#listing("python/samples/src/Ch12/frames.py", first: 73, last: 78, caption: [the factory side: MAKE\_CELL then SET\_FUNCTION\_ATTRIBUTE attach the cell])

This is the disassembly half of the closure argument in
#xref-to("python", "functions"), which made the same point about
capture by reference with the tools of that chapter. Here the
mechanism is the subject: a cell is one mutable slot shared by every
function that closed over the variable, which is why a loop variable
captured by five lambdas gives five views of one final value.

#diagram([a frame and its chain, with a cell bridging two frames], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.8, 6.2, 6.2, 1.6, [module frame, f\_globals: the module dict], fill: luma(215))
  box(0.8, 3.8, 6.2, 1.6, [call frame, f\_locals: args then locals])
  box(0.8, 1.4, 6.2, 1.6, [f\_builtins: print, len, ...])
  cdraw.line((3.9, 6.2), (3.9, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.9, 3.8), (3.9, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.0, 5.8), [name lookup falls down], wrap: text.with(size: 6pt, fill: luma(100)))
  box(9.6, 3.8, 4.8, 1.6, [cell for n], fill: luma(205))
  cdraw.line((7.0, 4.6), (9.6, 4.6), stroke: luma(100), mark: (end: ">"))
  box(16.0, 5.8, 5.6, 1.2, [closure\_target function object])
  box(16.0, 3.4, 5.6, 1.2, [\_\_closure\_\_: (cell,),])
  box(16.0, 2.2, 5.6, 1.0, [co\_freevars: ("n",)])
  cdraw.line((16.8, 5.8), (14.0, 5.0), stroke: luma(100), mark: (end: "<"))
  cdraw.line((18.8, 3.4), (14.4, 4.2), stroke: luma(140), dash: "dashed")
  cdraw.content((11.5, 6.6), [the factory's MAKE\_CELL], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.4, 0.8), [one cell, many functions: every closure reads and writes the same slot], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the eval loop and specialization

The eval loop reads the code object's instruction stream one entry at
a time, dispatching on the opcode. In 3.14 that dispatch table is
adaptive: a `BINARY_OP` that keeps seeing two ints stops being a
generic arithmetic dispatch and becomes `BINARY_OP_ADD_INT` in place.
This is pep 659's design, the specializing adaptive interpreter, and
it is not a cache you invalidate, it is the bytecode of a live code
object being rewritten as it warms up. The observable contract is in
the `dis` signature: `get_instructions(x, *, first_line=None,
show_caches=False, adaptive=False)`. The default view shows base
opnames, the adaptive view shows what the code object currently
runs, and the docs note that "Changed in version 3.13: The
`show_caches` parameter is deprecated and has no effect":

#snippet("  3           RESUME_CHECK             0\n\n  4           LOAD_FAST_BORROW_LOAD_FAST_BORROW 1 (a, b)\n              BINARY_OP_ADD_INT        0 (+)\n              RETURN_VALUE\n", lang: "text")

That output is real, captured from this interpreter after 30 calls.
The same function before any call disassembles to `RESUME`,
`LOAD_FAST_BORROW_LOAD_FAST_BORROW`, `BINARY_OP`, `RETURN_VALUE`,
and the sample asserts both states. Two more compile-time facts ride
along: the doubled local load is itself a base opcode in 3.14, a
fusion the compiler emits, not a warmup artifact, and small integer
literals travel on `LOAD_SMALL_INT`:

#listing("python/samples/src/Ch12/specialize.py", first: 21, last: 51, caption: [the base stream, the warmed stream, and the opcodes the compiler itself emits])

The discipline this forces on tooling is the reason the gate's
`expect-dis.txt` exists. Base opnames like `RESUME`, `BINARY_OP`, and
`RETURN_VALUE` are stable across runs, specialized names are a fact
about one execution's history, so assertions name only the base
forms. The chapter's file carries nine rows, among them
`warm_target|BINARY_OP` and `small|LOAD_SMALL_INT`, each verified by
compiling the sample source and matching the qualname's instruction
stream.

Above the loop sits the monitoring plane. Pep 669 replaced trace
functions with tool slots and event bit masks, `sys.monitoring` in
the stdlib. The sample books the debugger slot, registers a callback
for `PY_START`, and counts function entries. The event fires once per
call and reads back as 0 once cleared. One machine fact came with it:
on this build `import sys.monitoring` fails with "'sys' is not a
package" because the module ships attached to `sys` itself, so the
sample uses `from sys import monitoring`, which works:

#listing("python/samples/src/Ch12/specialize.py", first: 105, last: 130, caption: [pep 669 in use: book a tool id, register for PY\_START, clear events])

#diagram([tier 1 dispatch and its adaptive rewrites, with monitoring watching from the side], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.8, 5.2, [RESUME ... BINARY\_OP ... RETURN], fill: luma(215))
  box(7.2, 6.8, 5.2, [calls with 2 ints])
  box(13.8, 6.8, 5.2, [BINARY\_OP\_ADD\_INT], fill: luma(205))
  cdraw.line((5.8, 7.3), (7.2, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 7.3), (13.8, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 6.8), (16.4, 5.8), (10.4, 5.8), stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.6, 6.1), [rewrite in place, quickening], wrap: text.with(size: 6pt, fill: luma(100)))
  box(7.2, 4.2, 5.2, [dis, adaptive=False])
  box(13.8, 4.2, 5.2, [dis, adaptive=True])
  cdraw.line((9.8, 6.8), (9.8, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.6, 5.9), [the base stream survives], wrap: text.with(size: 6pt, fill: luma(100)))
  box(0.6, 2.4, 10.0, [sys.monitoring: PY\_START, BRANCH, LINE as bit masks])
  box(12.4, 2.4, 9.2, [expect-dis asserts base names only], fill: luma(215))
  cdraw.content((11.5, 1.0), [specialization is a fact of this run's history, never a promise about the next one], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== tier 2 and the jit

The whatsnew page for 3.14 states the release decision plainly: "The
official macOS and Windows release binaries now include an
experimental just-in-time (JIT) compiler. Although it is not
recommended for production use, it can be tested by setting
`PYTHON_JIT=1` as an environment variable." The same paragraph
supplies the introspection: "a set of introspection functions has
been provided in the `sys._jit` namespace. `sys._jit.is_available()`
can be used to determine if the current executable supports JIT
compilation, while `sys._jit.is_enabled()` can be used to tell if
JIT compilation has been enabled for the current process."

Every one of those sentences checks on this machine, and the sample
is those checks. `sys._jit` exists with exactly `is_active`,
`is_available`, and `is_enabled`. `is_available()` is true on this
build. `is_enabled()` is false in a default run and follows
`PYTHON_JIT` when set, in both states the sample computes the
expectation from the environment and asserts the agreement:

#listing("python/samples/src/Ch12/jit.py", first: 17, last: 33, caption: [the jit surface: shipped, off by default, switched by an environment variable])

#callout("warning", "observed, not claimed as speed", [
  The whatsnew page grades the jit itself: "The JIT is at an early
  stage and still in active development. As such, the typical
  performance impact of enabling it can range from 10% slower to
  20% faster, depending on workload." This chapter accordingly makes
  no timing claims, runs no benchmarks, and asserts nothing about
  `is_active`. The checks say the compiler is present and switchable
  on this interpreter. That is the whole claim, and it is the right
  size for a book whose evidence is a gate output, not a stopwatch.
])

The boundary below the jit is equally explicit. Tier 1's adaptive
specialization is on in every run and observable through `dis`, tier
2 exists in the binary and waits for an opt-in, and the layers above
it, real threads and the gil, or processes that sidestep it, are
#xref-to("python", "threads") and #xref-to("python", "multiprocessing").

#diagram([the execution tiers of this build: what runs by default and what waits], length: 13pt, {
  let layer(y, t, sub, fill: luma(235)) = {
    cdraw.rect((1.0, y), (15.4, y + 1.3), fill: fill, radius: 0.02)
    cdraw.content((8.2, y + 0.85), t, wrap: text.with(size: 6pt))
    cdraw.content((8.2, y + 0.35), sub, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  layer(7.0, [tier 1: the eval loop], [always on, adaptive specialization rewrites in place], fill: luma(215))
  layer(5.4, [tier 2: the jit], [in this binary, off until PYTHON\_JIT=1])
  layer(3.8, [above the tiers], [threads under the gil, processes beside it])
  cdraw.content((18.0, 7.3), [dis shows its work, #linebreak() every run], wrap: text.with(size: 6pt))
  cdraw.content((18.0, 5.6), [sys.\_jit.is\_available(), #linebreak() is\_enabled() per run], wrap: text.with(size: 6pt))
  cdraw.content((18.0, 4.0), [chapters 17 and 18], wrap: text.with(size: 6pt))
  cdraw.content((8.2, 2.4), [no timing claims anywhere in this chapter: observed, not claimed as speed], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((8.2, 1.4), [free-threading builds exist apart from this one, pep 779 is chapter 17's subject], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "what a green run of this chapter proves", [
  The five samples print 51 `ok` lines: compile and code object
  fields, the pyc header and both invalidation outcomes, frame and
  cell structure, base versus adaptive bytecode, the monitoring
  event count, and the jit's presence and switch state. The
  `expect-dis.txt` file adds nine bytecode assertions that recompile
  the sample sources to check. All of it ran on cpython 3.14.7 on
  this machine, and nothing here claims anything about another
  build's flags.
])

sources: docs.python.org/3.14 library/dis (get\_instructions signature,
show\_caches deprecation), library/sys.monitoring, whatsnew/3.14
(binary releases for the experimental just-in-time compiler),
reference/import (cached bytecode invalidation), and peps.python.org
pep 659, pep 744, all accessed 2026-09-12. Sample behavior
verified by `make verify-py`, 51 checks in chapter 12.
