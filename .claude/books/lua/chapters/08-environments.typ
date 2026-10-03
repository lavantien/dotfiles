#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= environments, load, gc

There is no global scope, only a variable named `_ENV`. Every free
name `var` compiles to `_ENV.var`, every chunk is compiled inside an
external local named `_ENV`, and every function captures whichever
`_ENV` was visible where it was defined. Shadow `_ENV` with a local
and the code inside that block changes worlds, imports and all:

#listing("lua/samples/ch08_environments.lua", first: 5, last: 13, caption: [a local env variable redirects every free name in the block])

#diagram([how free names really resolve, and what load's fourth argument swaps], length: 13pt, {
  // inside the chunk, a free name is an index into _ENV
  cdraw.rect((0.5, 9.8), (4.5, 11.0), fill: luma(235), radius: 0.02)
  cdraw.content((2.5, 10.4), [print(x)], size: 6pt)
  cdraw.line((4.7, 10.4), (5.8, 10.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.0, 9.8), (14.0, 11.0), fill: luma(205), radius: 0.02)
  cdraw.content((10.0, 10.4), [\_ENV.print(\_ENV.x)], size: 6pt)
  cdraw.content((17.8, 10.4), [every free name #linebreak() rides \_ENV], size: 6pt)
  // the environment table itself, _G just one entry in it
  cdraw.rect((0.5, 5.4), (21.5, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 8.3), [\_ENV, an external local around the whole chunk, is a table], size: 6pt)
  cdraw.rect((2.0, 6.2), (5.0, 7.4), fill: luma(245), radius: 0.02)
  cdraw.content((3.5, 6.8), [print], size: 6pt)
  cdraw.rect((5.5, 6.2), (8.5, 7.4), fill: luma(245), radius: 0.02)
  cdraw.content((7.0, 6.8), [require], size: 6pt)
  cdraw.rect((9.0, 6.2), (12.0, 7.4), fill: luma(205), radius: 0.02)
  cdraw.content((10.5, 6.8), [\_G], size: 6pt)
  cdraw.line((10.5, 7.5), (10.5, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.0, 7.05), [\_G's value is this very table], size: 6pt)
  cdraw.content((16.8, 5.9), [reassigning it changes nothing], size: 6pt)
  // the load swap
  cdraw.rect((0.5, 0.8), (8.5, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.5, 1.6), [load(src, name, "t", env)], size: 6pt)
  cdraw.line((8.7, 1.6), (9.8, 1.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.0, 0.8), (21.5, 2.4), fill: luma(205), radius: 0.02)
  cdraw.content((15.75, 1.6), [the table you pass is its world], size: 6pt)
  cdraw.content((11.0, 3.4), [the fourth argument swaps the world, text mode only], size: 6.5pt)
})

`_G` is not the mechanism. It is an ordinary global whose value
happens to be the table the interpreter booted with, so reassigning
it changes nothing about how globals resolve, and a sandboxed chunk
cannot escape through it because it only sees what its environment
table contains:

#listing("lua/samples/ch08_environments.lua", first: 15, last: 43, caption: [the global table as plain data, the load env argument, and a sandbox with no io])

The 5.5 global declaration compiles into this same picture: it is
syntactic only, the assignments still land in whatever `_ENV` is
current, which the environment-injected declaration test pins. For
loading untrusted code the working set is `load(src, name, "t",
env)`, text mode only, explicit environment, no bytecode accepted.

== the collector

5.5's fourth headline change is here: major collections in
generational mode are themselves incremental, and the default mode is
now generational, where 5.4 defaulted to incremental. The mode
options report the mode they replaced, and 5.5 removed their argument
taking: extra arguments to `"incremental"` and `"generational"` are
silently ignored rather than setting parameters, which is the
incompatibility chapter's library item:

#listing("lua/samples/ch08_environments.lua", first: 56, last: 64, caption: [generational by default, switches report the previous mode])

#diagram([the 5.5 collector, the default flip and where the knobs went], length: 13pt, {
  // the version flip
  cdraw.rect((0.5, 10.0), (8.0, 12.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.25, 11.1), [5.4: incremental #linebreak() by default], size: 6pt)
  cdraw.line((8.2, 11.1), (9.3, 11.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.5, 10.0), (21.5, 12.2), fill: luma(205), radius: 0.02)
  cdraw.content((15.5, 11.1), [5.5: generational by default, #linebreak() major cycles run incrementally], size: 6pt)
  // the mode switch report
  cdraw.rect((0.5, 7.4), (9.0, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.75, 8.1), [collectgarbage("incremental")], size: 6pt)
  cdraw.line((9.2, 8.1), (10.3, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.5, 7.4), (21.5, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((16.0, 8.1), [returns "generational"], size: 6pt)
  cdraw.content((16.0, 6.9), [the mode it just replaced], size: 6.5pt)
  // the six knobs as two trios under one param option
  cdraw.content((7.0, 6.7), [the six knobs, one "param" option], size: 6.5pt)
  let trio(y, names, widths, fill) = {
    let x = 2.0
    for (i, k) in names.enumerate() {
      cdraw.rect((x, y), (x + widths.at(i), y + 1.2), fill: fill, radius: 0.02)
      cdraw.content((x + widths.at(i) / 2, y + 0.6), [#k], size: 6pt)
      x += widths.at(i) + 0.3
    }
  }
  trio(4.6, ("pause", "stepmul", "stepsize"), (2.3, 2.8, 3.0), luma(235))
  cdraw.content((17.3, 5.2), [incremental], size: 6pt)
  trio(2.6, ("minormul", "minormajor", "majorminor"), (3.4, 4.3, 4.3), luma(205))
  cdraw.content((17.3, 3.2), [generational], size: 6pt)
  // count and step
  cdraw.content((11.0, 1.4), [every call returns the previous value], size: 6.5pt)
  cdraw.content((11.0, 0.25), [count reports kilobytes, step wants an integer], size: 6.5pt)
})

Parameters moved to one new option, `"param"`, with six names,
`pause`, `stepmul`, `stepsize` for incremental work and `minormul`,
`minormajor`, `majorminor` for generational. Every call returns the
previous value, values are stored compressed so a read-back can round
slightly, the manual's documented range is 0 to 100000, and this
build accepts and stores values beyond it without complaint, a
discrepancy the suite pins rather than repeats:

#listing("lua/samples/ch08_environments.lua", first: 66, last: 83, caption: [reading and writing the six knobs, the out of range fact])

`"count"` reports kilobytes with a fraction, `"step"` takes an
optional integer, and passing anything else to it is an argument
error, not a silent ignore:

#listing("lua/samples/ch08_environments.lua", first: 80, last: 83, caption: [step's type gate])

== weak tables and finalizers

`__mode = "v"` or `"k"` makes values or keys weak, and a full collect
clears entries whose only reference was the weak table. Finalization
has three rules the tests hold in place: `__gc` marks the object only
if present when `setmetatable` runs, finalizers run in reverse order
of marking at the end of the cycle, and a finalizer that stores its
object somewhere reachable resurrects it permanently:

#listing("lua/samples/ch08_environments.lua", first: 85, last: 126, caption: [weak entries, reverse order, the mark time rule])

#flow(
  [an object with a finalizer, from marking to resurrection],
  node((0, 0), [an object, \_\_gc present #linebreak() at setmetatable time]),
  node((0, 1.6), [marked for finalization]),
  node((0, 3.2), [the cycle ends]),
  node((0, 4.8), [the finalizer runs, #linebreak() reverse marking order]),
  node((-2.9, 4.8), [resurrected, stored #linebreak() somewhere reachable]),
  node((0, 6.4), [freed]),
  node((3.0, 0), [\_\_gc added later: #linebreak() never marked, never run]),
  node((3.0, 3.2), [a weak entry whose last link #linebreak() was the table drops now]),
  node((3.0, 4.8), [finalizer errors surface #linebreak() as warnings, contained]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (0, 3.2), "-|>"),
  edge((0, 3.2), (0, 4.8), "-|>"),
  edge((0, 4.8), (-2.9, 4.8), "-|>", label: [stores itself]),
  edge((0, 4.8), (0, 6.4), "-|>", label: [lets go]),
)

#callout("warning", "a classic self-deceiving probe", [
  The mark time test first passed for the wrong reason: a
  `_ = early, proper` line to silence unused variable hints is a
  multiple assignment that stores `early` into the global `_` and
  drops `proper`, keeping exactly the wrong object alive. The tests
  now simply let the block end. Chapter 6's adjustment rules, biting
  their author.
])

Finalizer errors are contained, they surface as warnings, never as
propagated errors, so a broken `__gc` cannot take down the process
during collection:

#listing("lua/samples/ch08_environments.lua", first: 127, last: 148, caption: [errors contained, resurrection through a global])

sources: lua.org manual 5.5 sections 2.2, 2.5, 3.2, 6.2, accessed
2026-09-08. Default mode, param behavior, and finalizer ordering
verified live with lua 5.5.1, 16 tests green through `make verify-lua`.
