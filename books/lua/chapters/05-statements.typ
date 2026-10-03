#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= statements and scope

Assignment is a list operation: lua evaluates every value on the right
before storing anything on the left, which makes the classic swap a
one liner, and adjusts lists to the target's length exactly the way
calls adjust arguments, padding with nil and dropping extras:

#listing("lua/samples/ch05_statements.lua", first: 5, last: 27, caption: [swap, call-shaped adjustment, multiple returns spread and truncate])

#diagram([assignment as a list operation, evaluate, adjust, then store], length: 13pt, {
  // the pipeline: evaluate the right list, adjust it, store left to right
  let stage(x0, x1, txt) = {
    cdraw.rect((x0, 8.6), (x1, 10.0), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 9.3), txt, size: 6pt)
  }
  stage(0.5, 7.0, [right side #linebreak() fully evaluated])
  stage(8.5, 15.0, [adjusted to #linebreak() the target count])
  stage(16.5, 22.0, [stored, #linebreak() left to right])
  cdraw.line((7.0, 9.3), (8.5, 9.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 9.3), (16.5, 9.3), stroke: luma(100), mark: (end: ">"))
  // the swap: why the order makes it a one liner
  cdraw.content((4.0, 7.0), [a, b = b, a], size: 6pt)
  cdraw.content((4.0, 5.6), [before: a \[1\] b \[2\]], size: 6pt)
  cdraw.content((4.0, 4.3), [after: a \[2\] b \[1\], no temp], size: 6pt)
  // list adjustment: truncate on the left, pad on the right
  cdraw.content((13.2, 7.0), [two targets, three values], size: 6.5pt)
  let cella = ("1", "2", "3")
  for (i, v) in cella.enumerate() {
    let f = if i == 2 { luma(205) } else { luma(235) }
    cdraw.rect((10.2 + i * 1.5, 5.1), (11.7 + i * 1.5, 6.1), fill: f, radius: 0.02)
    cdraw.content((10.95 + i * 1.5, 5.6), [#v], size: 6pt)
  }
  cdraw.line((14.8, 5.6), (16.2, 5.6), stroke: luma(100), mark: (end: ">"))
  for i in range(2) {
    cdraw.rect((16.3 + i * 1.5, 5.1), (17.8 + i * 1.5, 6.1), fill: luma(235), radius: 0.02)
    cdraw.content((17.05 + i * 1.5, 5.6), [#{int(cella.at(i))}], size: 6pt)
  }
  cdraw.content((12.5, 4.0), [the third value drops], size: 6pt)
  cdraw.content((13.2, 2.7), [three targets, one value], size: 6.5pt)
  cdraw.rect((10.2, 0.8), (11.7, 1.8), fill: luma(235), radius: 0.02)
  cdraw.content((10.95, 1.3), [1], size: 6pt)
  cdraw.line((11.8, 1.3), (13.2, 1.3), stroke: luma(100), mark: (end: ">"))
  for i in range(3) {
    let f = if i > 0 { luma(205) } else { luma(235) }
    cdraw.rect((13.3 + i * 1.5, 0.8), (14.8 + i * 1.5, 1.8), fill: f, radius: 0.02)
    cdraw.content((14.05 + i * 1.5, 1.3), [#{if i > 0 [nil] else [1]}], size: 6pt)
  }
  cdraw.content((16.0, 0.15), [nil pads the rest], size: 6pt)
})

A `local` declaration's scope begins after the statement itself, so
`local x = x + 1` reads the outer x and defines a new one. Blocks are
`do end`, function bodies, and control structure bodies, and the chunk
is a block.

== attributes

`local` takes `<const>` and `<close>`. `<const>` is a compile time
lock: the assignment is a syntax error, the same mechanism 5.5 now
applies to for loop control variables and global declarations.
`<close>` registers a to-be-closed variable for the block's exit:
reverse declaration order, skipped quietly for nil and false, and an
error at scope exit for anything without a callable `__close`:

#listing("lua/samples/ch05_statements.lua", first: 39, last: 61, caption: [closing order, the nil exemption, both failure modes])

#diagram([the life of a block, const at compile time, closes at exit in reverse], length: 13pt, {
  // the block timeline, event boxes straddling it
  cdraw.line((0.8, 6.0), (21.5, 6.0), stroke: luma(100), mark: (end: ">"))
  let event(x, half, txt, hot) = {
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((x - half, 4.9), (x + half, 6.3), fill: f, radius: 0.02)
    cdraw.content((x, 5.6), txt, size: 6pt)
  }
  event(3.2, 2.4, [local a \<close\>], false)
  event(8.2, 2.4, [local b \<close\>], false)
  event(12.6, 1.4, [the body], false)
  event(16.4, 1.3, [close b], true)
  event(20.0, 1.3, [close a], true)
  // the error path joins the same closes
  cdraw.line((12.6, 4.85), (12.6, 4.42), stroke: luma(180), mark: (end: ">"))
  cdraw.content((7.2, 4.0), [an error unwinds, closes still run], size: 6.5pt)
  cdraw.content((18.2, 4.45), [reverse order], size: 6pt)
  // the const lane
  cdraw.rect((0.8, 0.3), (11.6, 3.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 2.7), [local x \<const\> = 1], size: 6pt)
  cdraw.content((5.4, 1.35), [the lock is compile time, #linebreak() any assignment is a load error], size: 6pt)
  // the exemptions and the failure
  cdraw.content((17.4, 3.3), [nil and false are exempt], size: 6pt)
  cdraw.content((16.4, 1.5), [no callable \_\_close: #linebreak() error at scope exit], size: 6pt)
})

#callout("note", "closes run on errors too", [
  To-be-closed variables close when the block exits for any reason,
  including an error unwinding through it, which is what makes
  `<close>` the right tool for file and lock lifetimes. Chapter 7
  revisits it from the coroutine side, where closing a suspended
  coroutine is how you cancel it.
])

== loops

`while` tests before, `repeat` tests after, and the repeat test sees
locals declared in the body, the one place a condition can reference
something the body created. The numeric `for` evaluates start, limit,
and step exactly once, before the first iteration, holds the loop
variable as read-only in 5.5, and counts with integer arithmetic that
does not wrap past `math.maxinteger`:

#listing("lua/samples/ch05_statements.lua", first: 63, last: 96, caption: [repeat's late scope, single evaluation, read-only control, no wrap loop, float steps])

#flow(
  [the generic for as a call loop, the first nil terminates it],
  node((0, 0), [for k, v in f, s, init]),
  node((0, 1.6), [call f(s, control)]),
  node((0, 3.2), [first result nil?]),
  node((-2.7, 3.2), [the loop ends]),
  node((0, 4.8), [k, v assigned, #linebreak() the body runs]),
  node((3.2, 0), [numeric for: bounds read once, #linebreak() integer counting never wraps]),
  node((3.2, 1.6), [next fits directly, #linebreak() no closure allocated]),
  node((3.2, 4.8), [control = #linebreak() the first result]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (0, 3.2), "-|>"),
  edge((0, 3.2), (-2.7, 3.2), "-|>", label: [yes]),
  edge((0, 3.2), (0, 4.8), "-|>", label: [no]),
  edge((0, 4.8), (0, 1.6), "-|>", bend: -60deg),
)

The generic `for` calls a function repeatedly with a state and a
control value, stopping at the first nil. `next` fits directly, so
`for k, v in next, t` iterates without allocating a closure, and a
hand written iterator gets one last call that returns nil:

#listing("lua/samples/ch05_statements.lua", first: 97, last: 115, caption: [stateless next, closure iterator, nil terminates])

When the `in` expression list carries a fourth value, the loop closes
it as a to-be-closed variable on exit, break and error included,
which is the half of the protocol `io.lines` rides in chapter 12.

== goto and returns

`goto` jumps to a label forward in the same block, cannot enter the
scope of a local, and powers the continue idiom lua otherwise lacks:

#listing("lua/samples/ch05_statements.lua", first: 116, last: 131, caption: [continue by label, and the scope boundary error])

#flow(
  [goto validity, and return closing its block],
  node((0, 0), [a goto and its label]),
  node((0, 1.7), [label forward, #linebreak() in the same block?]),
  node((0, 3.4), [enters a local's scope?]),
  node((-2.9, 2.55), [load time error]),
  node((0, 5.1), [the jump runs]),
  node((3.0, 1.7), [this powers #linebreak() the continue idiom]),
  node((3.0, 3.4), [return must close its block, #linebreak() a void ; may follow]),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 1.7), (-2.9, 2.55), "-|>", label: [no]),
  edge((0, 1.7), (0, 3.4), "-|>", label: [yes]),
  edge((0, 3.4), (-2.9, 2.55), "-|>", label: [yes]),
  edge((0, 3.4), (0, 5.1), "-|>", label: [no]),
)

`return` must close its block, with an optional semicolon after it;
empty `;` statements are void anywhere. `break` exits the innermost
loop. Both are statements, not expressions, and the grammar enforces
the shape at load time.

#listing("lua/samples/ch05_statements.lua", first: 132, last: 143, caption: [return as block end, void semicolons])

sources: lua.org manual 5.5 sections 2.2, 3.2, 3.3, accessed
2026-09-08. Close and goto error wording verified live with lua 5.5.1,
15 tests green through `make verify-lua`.
