#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= exceptions and context managers

Errors are values in motion, and python gives them two vehicles:
exceptions that unwind the stack looking for a handler, and context
managers that wrap a block with entry and exit code so cleanup does not
depend on the unwind finding one. This chapter walks the exception tree
first, because knowing what derives from what decides what your
`except` clauses can even see, then the exact semantics of `try`, then
exception groups, the structure that lets one `raise` carry several
failures at once, and closes on the `with` protocol and the `contextlib`
toolkit built on it. Every claim below is one of the 53 checks in the
four samples, run under cpython 3.14.7 with `-X utf8`, with the
grammar refusals probed through `compile` rather than trusted.

== the exception tree

Everything derives from `BaseException`, and only most of it from
`Exception`. That split is the tree's load bearing wall, because
`except Exception` is the conventional catch-all of application code,
and it deliberately misses `KeyboardInterrupt` and `SystemExit`:

#listing("python/samples/src/Ch10/tree.py", first: 18, last: 30, caption: [a custom error under exception, and one outside it on purpose])

#listing("python/samples/src/Ch10/tree.py", first: 33, last: 51, caption: [the tree facts, and the subclass that except exception cannot see])

Lines 34-40 pin the bypass by `issubclass`, and lines 46-51 pin it
behaviorally: `Explode`, raised from `launch`, sails past `except
Exception` and lands in `except BaseException`. Handlers match
subclasses, line 52-55, `FileNotFoundError` is an `OSError`. Some
builtin classes unpack their arguments into attributes, lines 56-61:
`OSError(22, "invalid mode", "data.txt")` carries `errno`, `strerror`,
and `filename` for free, the shape your own error classes should aim
for. Chaining has two forms, explicit and implicit:

#listing("python/samples/src/Ch10/tree.py", first: 62, last: 83, caption: [raise from sets the cause, an unrelated raise chains anyway])

`raise ... from exc` at line 66 sets `__cause__`, marks
`__suppress_context__` so tracebacks show only the causal chain, and
still records the ambient `__context__`. The plain `raise` at line 78
leaves `__cause__` empty but fills `__context__` with the exception
being handled, the "during handling" chain. `from None` at line 94
suppresses context entirely, and any exception can serve as a cause,
lines 97-100. The custom class design in one listing: `ConfigError`
formats its message once in `super().__init__`, stores structured
attributes, and keeps `args` consistent with `str`, lines 22-27 and
84-92.

#diagram([the tree, and what a handler can see], length: 13pt, {
  cdraw.rect((7.4, 7.9), (14.8, 9.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.1, 8.45), [BaseException], wrap: text.with(size: 7pt))
  cdraw.rect((0.7, 5.9), (5.6, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((3.15, 6.4), [KeyboardInterrupt], wrap: text.with(size: 6pt))
  cdraw.rect((6.4, 5.9), (9.6, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((8.0, 6.4), [SystemExit], wrap: text.with(size: 6pt))
  cdraw.rect((10.4, 5.9), (16.0, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((13.2, 6.4), [Exception], wrap: text.with(size: 7pt))
  cdraw.rect((16.8, 5.9), (22.4, 6.9), fill: luma(248), radius: 0.02)
  cdraw.content((19.6, 6.4), [GeneratorExit], wrap: text.with(size: 6pt))
  cdraw.line((9.2, 7.9), (3.15, 6.9), stroke: luma(100))
  cdraw.line((10.2, 7.9), (8.0, 6.9), stroke: luma(100))
  cdraw.line((11.1, 7.9), (13.2, 6.9), stroke: luma(100))
  cdraw.line((13.4, 7.9), (19.6, 6.9), stroke: luma(100))
  cdraw.rect((8.6, 3.7), (12.6, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((10.6, 4.6), [OSError], wrap: text.with(size: 6.5pt))
  cdraw.content((10.6, 4.1), [errno, strerror, filename], wrap: text.with(size: 5.5pt))
  cdraw.rect((13.2, 3.7), (17.6, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((15.4, 4.6), [ArithmeticError], wrap: text.with(size: 6.5pt))
  cdraw.content((15.4, 4.1), [ZeroDivisionError below], wrap: text.with(size: 5.5pt))
  cdraw.rect((6.0, 3.7), (8.2, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((7.1, 4.35), [ValueError], wrap: text.with(size: 6.5pt))
  cdraw.rect((18.2, 3.7), (22.4, 5.0), fill: luma(248), radius: 0.02)
  cdraw.content((20.3, 4.35), [your errors], wrap: text.with(size: 6.5pt))
  cdraw.line((12.4, 5.9), (10.6, 5.0), stroke: luma(100))
  cdraw.line((13.0, 5.9), (7.1, 5.0), stroke: luma(100))
  cdraw.line((13.8, 5.9), (15.4, 5.0), stroke: luma(100))
  cdraw.line((14.4, 5.9), (20.3, 5.0), stroke: luma(100))
  cdraw.content((11.1, 2.6), [ExceptionGroup lives here too, section 3], wrap: text.with(size: 6pt))
  cdraw.rect((0.7, 1.2), (10.4, 2.1), fill: luma(205), radius: 0.02)
  cdraw.content((5.55, 1.65), [except Exception catches this half], wrap: text.with(size: 6pt))
  cdraw.content((16.4, 1.65), [except BaseException catches everything, rarely what you want], wrap: text.with(size: 6pt))
})

#callout("note", "why the split exists", [
  Control flow that crosses your program's boundary is not an error in
  it: ctrl-c, interpreter exit, generator close. Forcing those through
  `except Exception` would mean a library's blanket handler eats your
  shutdown. Catch `Exception` in application code, let the rest travel.
])

== try semantics

The `try` statement has 4 blocks and one fixed order: the body runs,
handlers are tested top to bottom on failure, `else` runs only when no
failure happened, and `finally` always runs, on success, on failure,
even on `return`:

#listing("python/samples/src/Ch10/trysem.py", first: 19, last: 50, caption: [three probes: matching order, else, and the recorded block order])

Handler matching is first match wins, not best match: lines 63-68 of
the sample pin that a `KeyError` matches a `ValueError` handler not at
all and a `LookupError` handler regardless of position, and an
`IndexError`, which is both a `LookupError` and would match later
clauses, stops at the `LookupError` line. The recorded order at lines
73-77 is the whole state machine in one list, try, except, finally
when failing, try, else, finally when clean. The trap the block order
enables is famous and now warned about:

#listing("python/samples/src/Ch10/trysem.py", first: 53, last: 60, caption: [the swallowing finally, and the bare raise that preserves the original])

The source at line 53 is compiled under a warning recorder, and
cpython 3.14 emits a `SyntaxWarning`, "'return' in a 'finally' block",
lines 78-84. The compiled function still returns 42, line 86, and the
`ValueError` it was unwinding is gone, no handler will ever see it,
which is why the warning exists. The remaining semantics are pinned
one by one: a bare `raise` inside a handler re-raises the active
exception, lines 87-92, a bare `raise` with nothing active raises
`RuntimeError`, "No active exception to re-raise", lines 93-101, the
`as` name is deleted when the handler exits, lines 102-111, and
`finally` runs while the exception is still traveling, visible as the
try, finally, outer except order at lines 113-121.

A handler may name several exception types, and 3.14 changed how that
is spelled. Through 3.13 the parenthesized tuple was the only form,
`except (ValueError, UnicodeDecodeError):`, and PEP 758 legalizes the
paren-less `except ValueError, UnicodeDecodeError:`. The parentheses
return the moment an `as` clause rides the handler: the interpreter
refuses `except ValueError, UnicodeDecodeError as exc:` with
"multiple exception types must be parenthesized when using 'as'"
while the parenthesized twin with `as` parses. Matching does not
change, the list is the same tuple and first match still wins. The
formatter has an opinion under a py314 target: `ruff format` rewrites
the parenthesized form to the paren-less one, which is why the
service part's kernel in #xref-to("python", "http-kernel") ships the
paren-less spelling.

#diagram([the try statement as a state machine], length: 13pt, {
  cdraw.rect((8.9, 8.1), (13.3, 9.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.1, 8.55), [enter try], wrap: text.with(size: 7pt))
  cdraw.line((11.1, 8.05), (11.1, 7.45), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((3.4, 6.4), (9.4, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 6.9), [body runs], wrap: text.with(size: 6.5pt))
  cdraw.line((9.4, 6.9), (12.2, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 7.2), [no exception], wrap: text.with(size: 6pt))
  cdraw.rect((12.2, 6.4), (15.8, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((14.0, 6.9), [else], wrap: text.with(size: 6.5pt))
  cdraw.line((6.4, 6.35), (6.4, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.9, 5.9), [exception], wrap: text.with(size: 6pt))
  cdraw.rect((3.4, 4.3), (9.4, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 4.8), [handlers, top to bottom], wrap: text.with(size: 6.5pt))
  cdraw.line((6.4, 4.25), (6.4, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.9, 3.8), [none match], wrap: text.with(size: 6pt))
  cdraw.line((9.4, 4.8), (14.0, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 5.1), [first match wins], wrap: text.with(size: 6pt))
  cdraw.rect((12.2, 4.3), (15.8, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((14.0, 4.8), [handler runs], wrap: text.with(size: 6.5pt))
  cdraw.rect((7.9, 2.2), (14.3, 3.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.1, 2.7), [finally, always], wrap: text.with(size: 6.5pt))
  cdraw.line((14.0, 4.25), (12.0, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.0, 6.35), (12.0, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.4, 3.25), (9.6, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.1, 1.4), [return in finally: the exception is discarded, warning since 3.14], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 8.6), [the as name dies at handler exit], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 7.9), [bare raise: re-raise the active one], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 7.2), [raise other: implicit \_\_context\_\_ chain], wrap: text.with(size: 6pt))
  cdraw.content((2.2, 1.1), [unmatched exceptions keep traveling after finally], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== exception groups

One operation can fail in several ways at once, and PEP 654 gave that
a carrier: `ExceptionGroup`, a node holding a message and a tuple of
leaves and other groups:

#listing("python/samples/src/Ch10/groups.py", first: 19, last: 28, caption: [a group is a message plus a tuple, and identity is not equality])

The `kinds` helper at 26-27 exists because exceptions compare by
identity: two `ValueError(1)` instances are not equal, so the sample
compares types and args. The structure operations are `split` and
`subgroup`, and they recurse:

#listing("python/samples/src/Ch10/groups.py", first: 30, last: 61, caption: [split partitions, subgroup filters, nesting is preserved, and the two container classes differ])

`split` at 30-35 returns a pair, matched and rest, each a group with
the original shape. The nested case at 40-47 is the design point:
subgrouping a tree prunes it, it does not flatten it. Containment has
a rule, lines 48-61: `ExceptionGroup` refuses `BaseException` leaves
with `TypeError`, and `BaseExceptionGroup` exists for when you mean
it. The handler syntax is `except*`, with semantics deliberately
different from `except`:

#listing("python/samples/src/Ch10/groups.py", first: 63, last: 91, caption: [wrapping of plain exceptions, every matching clause runs, leftovers propagate])

A plain exception that matches is wrapped in a group with an empty
message so the `as` name is always a group, lines 63-73. Every
matching clause runs, lines 74-90: the `TypeError` clause and the
`OSError` clause each handle their slice, and the unmatched
`ValueError` leaf leaves the statement as a new group. The grammar
polices the sharp edges, lines 92-112: `except` and `except*` cannot
mix in one `try`, a bare `except*` is a `SyntaxError`, and
`break`, `continue`, and `return` are banned inside the star blocks.
The place groups surface in real code is structured concurrency:

#listing("python/samples/src/Ch10/groups.py", first: 124, last: 141, caption: [a taskgroup with two failing tasks delivers both failures at once])

The `TaskGroup` waits for every task, then raises one
`ExceptionGroup` carrying both failures with the message "unhandled
errors in a TaskGroup", so a partial failure cancels siblings and
still reports everything. #xref-to("python", "asyncio") owns the full
async story, this is the delivery mechanism arriving early.

#diagram([one group, split by a handler], length: 13pt, {
  cdraw.rect((0.7, 5.0), (9.0, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.85, 8.1), [ExceptionGroup "eg"], wrap: text.with(size: 6.5pt))
  cdraw.rect((1.1, 6.6), (3.2, 7.5), fill: luma(248), radius: 0.02)
  cdraw.content((2.15, 7.05), [VE(1)], wrap: text.with(size: 6pt))
  cdraw.rect((3.5, 6.6), (5.6, 7.5), fill: luma(248), radius: 0.02)
  cdraw.content((4.55, 7.05), [TE(2)], wrap: text.with(size: 6pt))
  cdraw.rect((5.9, 6.6), (8.0, 7.5), fill: luma(248), radius: 0.02)
  cdraw.content((6.95, 7.05), [VE(3)], wrap: text.with(size: 6pt))
  cdraw.content((4.85, 5.9), [leaves may be groups, nesting recurses], wrap: text.with(size: 6pt))
  cdraw.content((4.85, 5.35), [ VE and TE compare by identity, not args], wrap: text.with(size: 5.5pt))
  cdraw.line((9.0, 6.9), (10.2, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 7.35), [except\* TE], wrap: text.with(size: 6pt))
  cdraw.rect((10.2, 6.4), (15.2, 7.4), fill: luma(205), radius: 0.02)
  cdraw.content((12.7, 6.9), [matched: TE(2)], wrap: text.with(size: 6pt))
  cdraw.line((10.2, 5.6), (15.2, 5.6), stroke: luma(100))
  cdraw.rect((10.2, 4.2), (15.2, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((12.7, 4.7), [rest: VE(1), VE(3)], wrap: text.with(size: 6pt))
  cdraw.line((12.7, 5.65), (12.7, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.7, 3.6), [every matching clause runs], wrap: text.with(size: 6pt))
  cdraw.content((12.7, 2.9), [leftovers merge and propagate as a group], wrap: text.with(size: 6pt))
  cdraw.content((19.4, 6.9), [plain raise wraps into #linebreak() a group with empty message], wrap: text.with(size: 6pt))
  cdraw.content((19.4, 5.3), [taskgroup raises one group, #linebreak() chapter 21 tells that story], wrap: text.with(size: 6pt))
  cdraw.content((11.6, 1.6), [ExceptionGroup refuses baseexception leaves, BaseExceptionGroup allows them], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== context managers

`try/finally` dedicates a statement to cleanup. The `with` statement
dedicates an object to it, and the protocol is two methods:

#listing("python/samples/src/Ch10/ctxmgr.py", first: 19, last: 46, caption: [three two-method classes: a reporter, a suppressor, a failure])

`__enter__`'s return value is what the `as` name binds, and `__exit__`
receives the triple of exception type, value, and traceback, or three
`None`s on a clean exit, sample lines 49-60. The return value of
`__exit__` is a verdict: falsy lets the exception continue, truthy
suppresses it, sample lines 61-63, any truthy value, not just `True`.
An `__exit__` that itself raises replaces the body exception and
chains it as context, lines 64-73. The generator spelling covers the
common case:

#listing("python/samples/src/Ch10/ctxmgr.py", first: 75, last: 102, caption: [code before yield is enter, after yield is exit, and reuse is refused])

Everything before `yield` runs at entry, the yielded value binds to
`as`, and everything after runs at exit, in a `try/finally` so
exceptions run it too, lines 87-89. The manager object is single use,
and 3.14 makes the second entry an `AttributeError`, lines 90-102,
call the function again for each `with`. The toolkit rounds out the
common shapes:

#listing("python/samples/src/Ch10/ctxmgr.py", first: 103, last: 112, caption: [suppress, and the re-raise discipline it encodes])

`contextlib.suppress` swallows exactly the listed types and lets
everything else travel, which is the re-raise discipline stated as a
library: never catch broadly and quietly, catch narrowly or not at
all. `closing` calls `close()` on the way out for objects that are not
context managers, sample lines 115-126. `ExitStack` is the composition
tool, lines 127-146: callbacks run last in first out, `pop_all`
detaches the stack so an outer manager can finish the job later, and
`enter_context` adopts other managers into the same unwind.

#diagram([the with statement, entry to verdict], length: 13pt, {
  let stage(x, w, t, fill: luma(235)) = {
    cdraw.rect((x, 6.2), (x + w, 7.6), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, 6.9), t, wrap: text.with(size: 6pt))
  }
  stage(0.6, 4.4, [with expr])
  stage(5.6, 4.4, [\_\_enter\_\_(), #linebreak() as binds its value])
  stage(10.6, 4.4, [body runs])
  stage(15.6, 6.4, [\_\_exit\_\_(etype, val, tb), #linebreak() or three nones], fill: luma(205))
  cdraw.line((5.0, 6.9), (5.6, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.0, 6.9), (10.6, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 6.9), (15.6, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.8, 8.5), [the verdict], wrap: text.with(size: 6.5pt))
  cdraw.rect((16.6, 6.9), (21.8, 7.9), fill: luma(248), radius: 0.02)
  cdraw.content((19.2, 7.4), [falsy return: exception travels], wrap: text.with(size: 6pt))
  cdraw.rect((16.6, 5.6), (21.8, 6.6), fill: luma(248), radius: 0.02)
  cdraw.content((19.2, 6.1), [truthy return: suppressed], wrap: text.with(size: 6pt))
  cdraw.line((18.8, 6.15), (19.2, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.8, 7.35), (19.2, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.6, 3.6), (10.4, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 4.6), [contextlib.contextmanager], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 4.05), [before yield is enter, after is exit, #linebreak() single use, build one per with], wrap: text.with(size: 6pt))
  cdraw.rect((11.0, 3.6), (22.4, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.7, 4.6), [suppress, closing, ExitStack], wrap: text.with(size: 6pt))
  cdraw.content((16.7, 4.05), [listed types only, close on exit, #linebreak() lifo callbacks, pop_all detaches], wrap: text.with(size: 6pt))
  cdraw.content((11.5, 2.4), [async with is the same protocol one await later, chapter 21], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.5, 1.4), [exit raising replaces the body error and chains it as context], wrap: text.with(size: 6.5pt))
})

#callout("verify", "53 checks behind this chapter", [
  `tree.py` pins the tree and both chaining forms, 12 checks,
  `trysem.py` block order and the swallowing finally, 11, `groups.py`
  the group structure and `except*` semantics with grammar refusals,
  13, and `ctxmgr.py` the `with` protocol and the toolkit, 17. Two
  drafts went red: exception equality is identity, so the group checks
  compare types and args, and the module-level `return` in `except*`
  probe reported the wrong syntax error, the function-scoped probe
  gives the real one.
])

sources: docs.python.org/3/library/exceptions.html, the hierarchy and
`OSError` attributes, accessed 2026-09-12; docs.python.org/3/reference/compound_stmts.html,
the `try` statement, `except*`, and the `with` statement, accessed
2026-09-12; peps.python.org/pep-0654, exception groups and `except*`,
accessed 2026-09-12; docs.python.org/3/library/contextlib.html and
docs.python.org/3/library/exceptiongroup.html, accessed 2026-09-12;
every chaining flag, split result, warning text, and grammar message
probed on this machine the same day. Sample behavior verified by
`make verify-py`, 53 checks in chapter 10 of the samples suite.
