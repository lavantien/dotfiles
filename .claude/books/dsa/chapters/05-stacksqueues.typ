#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= stacks, queues, deques

Two disciplines organize more algorithms than any other pair: last in
first out and first in first out. Both are array exercises, and both
earn their keep in the classic algorithms this chapter runs: bracket
matching and the shunting yard.

== the stack

A stack is a vector with one legal entry point. Push, pop, peek, and
an honest underflow, C first with refusal codes.

The dry run: the fixture is the 1, 2, 3 run, asserted by the C\#
suite, with the 1000 push growth exhibit in C\# and the capacity 8
refusal in C, Java, JavaScript, and Lua.

+ Push 1, Push 2, Push 3 write at the count: the count is 3 and the
  top is 3.
+ Pop returns 3, then 2, then 1, the count 0 after the drain.
+ Pop or Peek on the empty stack throws, no value fabricated.
+ The growth exhibit: 1000 pushes hold count 1000 and Pop returns
  999, chapter 3's doubling underneath.
+ The bounded contrast: C, Java, JavaScript, and Lua cap the stack at
  8 and the ninth push refuses where C\# grows.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*op*], [*slots after*], [*count*], [*returns*]),
  [push 1], [1], [1], [],
  [push 2], [1 2], [2], [],
  [push 3], [1 2 3], [3], [],
  [pop], [1 2], [2], [3],
  [pop], [1], [1], [2],
  [pop], [], [0], [1],
)

The 3, 2, 1 drain and the 999 off the 1000 push run are pinned, and
the listings below build the stack seven ways.

#listing("dsa/samples-c/src/Ch05/stack.c", first: 21, last: 40, caption: [c, push, pop, peek over a bounded char array])

#listing("dsa/samples-go/ch05/stack.go", first: 12, last: 30, caption: [go, push, pop, peek over a slice head])

The call protocol is the useful part. Anything naturally nested,
calls, scopes, undo entries, xml depth, becomes a stack the moment
reversal matters: the most recent opener must close first.

#listing("dsa/samples-java/src/Ch05/Stack.java", first: 18, last: 40, caption: [java, the bounded stack, pops and peeks surface as null on underflow])

The C\# class grows instead of refusing at the top end:

#listing("dsa/samples/src/Ch05/Buffers.cs", first: 4, last: 30, caption: [c\#, push, pop, peek, the empty-stack errors])

#listing("dsa/samples-js/src/ch05-stack.mjs", first: 12, last: 26, caption: [javascript, push, pop, peek with null on underflow])

#listing("dsa/samples-py/src/Ch05/stack.py", first: 13, last: 31, caption: [python, the stack class with IndexError refusals])

#listing("dsa/samples-lua/ch05_stack.lua", first: 11, last: 29, caption: [lua, push, pop, peek, nil slots released on pop])

Underflow refuses everywhere, never fabricates a value. C returns
refusal codes, Go returns errors, C\# throws InvalidOperationException,
Python raises IndexError, and Java, JavaScript, and Lua return null
and nil. The top end differs: C, Java, JavaScript, and Lua run
bounded stacks that also refuse at capacity 8, while C\#, Go, and
Python grow without a bound, chapter 3's doubling doing the work.

#diagram([the stack, one legal entry point: push writes at the count, pop reads and clears it], length: 13pt, {
  // vertical strip, index 0 at the bottom, three of four slots live
  for i in range(4) {
    let y = 1.6 + i * 0.85
    cdraw.rect((3.0, y), (4.8, y + 0.75), fill: if i < 3 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.9, y + 0.37), [#i], size: 6pt)
  }
  cdraw.line((2.4, 1.6), (2.4, 4.15), stroke: luma(100))
  cdraw.line((2.4, 1.6), (2.2, 1.6), stroke: luma(100)); cdraw.line((2.4, 4.15), (2.2, 4.15), stroke: luma(100))
  cdraw.content((1.05, 4.5), [count = 3], size: 6pt)
  cdraw.line((6.6, 4.5), (5.0, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.7, 4.62), [push writes at count], size: 6.5pt)
  cdraw.line((4.9, 3.65), (6.5, 3.65), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.5, 3.5), [pop reads and clears], size: 6.5pt)
  cdraw.content((9.2, 2.35), [pop on empty: InvalidOperationException], size: 6.5pt)
  cdraw.content((8.0, 1.45), [the honest refusal, not a crash], size: 6.5pt)
  cdraw.content((8.1, 0.55), [nested work: calls, scopes, undo], size: 6.5pt)
})

== the ring buffer

A queue on a naive array dequeues by shifting everything left, which
is quadratic churn. The ring keeps two cursors in a fixed array and
lets arithmetic do the moving. The head is where the next dequeue
reads, the tail is where the next enqueue writes, and both wrap with
a modulo. C keeps the whole story in 28 lines, grow included.

The dry run: the fixture is Ring(4) across the seam, asserted by the
C\# suite; C, Java, JavaScript, and Lua pin the same layout 5 6 3 4
and the 4 element grow copy.

+ Enqueue 1, 2, 3, 4 fills to capacity: count 4, capacity still 4,
  head and tail both back at slot 0.
+ Dequeue returns 1 then 2, and the head walks to slot 2.
+ Enqueue 5 lands in slot 0, the wrap, and 6 in slot 1: the physical
  layout reads 5 6 3 4.
+ The drain returns 3, 4, 5, 6: fifo order survives the seam.
+ The growth exhibit: 50 enqueues into Ring(2) climb the capacity 2
  to 64 and still drain 0 through 49 in order.

#diagram([the seam run as three layouts: full and level, split across the seam, then the grow rebased to slot 0], length: 13pt, {
  let strip = (y, label, cells, head, tail, note) => {
    cdraw.content((0.7, y + 0.35), label, size: 6pt)
    for (i, v) in cells.enumerate() {
      let x = 2.4 + i * 1.05
      if v == none {
        cdraw.rect((x, y), (x + 1.05, y + 0.7), fill: none, stroke: luma(160), radius: 0.02)
      } else {
        cdraw.rect((x, y), (x + 1.05, y + 0.7), fill: luma(205), radius: 0.02)
        cdraw.content((x + 0.525, y + 0.35), [#v], size: 6pt)
      }
      if i == head { cdraw.content((x + 0.525, y - 0.28), [h], size: 6pt) }
      if i == tail { cdraw.content((x + 0.525, y + 1.02), [t], size: 6pt) }
    }
    cdraw.content((13.6, y + 0.35), note, size: 6pt)
  }
  strip(5.5, [after fill], (1, 2, 3, 4), 0, 0, [count 4, no grow yet])
  strip(3.4, [seam], (5, 6, 3, 4), 2, 2, [5 and 6 wrapped])
  strip(1.0, [after grow], (3, 4, 5, 6, 7, none, none, none), 0, 5, [7 lands at slot 4])
})

The 5 6 3 4 seam and the in-order drain are pinned, and the listings
below build the ring in seven languages.

#listing("dsa/samples-c/src/Ch05/ringqueue.c", first: 30, last: 57, caption: [c, grow rebases to slot 0, enqueue and dequeue wrap])

#listing("dsa/samples-go/ch05/ringqueue.go", first: 24, last: 40, caption: [go, enqueue with the grow inlined and counted])

The other five rings keep the seam handling visible, Java unwinding
`(_head + i) % cap` back to slot zero in its grow:

#listing("dsa/samples-java/src/Ch05/Ringqueue.java", first: 17, last: 57, caption: [java, the ring state, the seam-unwinding grow, enqueue and dequeue])

#listing("dsa/samples/src/Ch05/Buffers.cs", first: 32, last: 87, caption: [c\#, the circular buffer, wraparound, grow in order])

The tests walk the boundary cases: filling exactly to capacity
without growing, the wrap after dequeueing from a full ring, and
growth preserving fifo order when the logical sequence is split
across the array seam. That seam handling in `Grow`, copying
`(_head + i) % len` back to slot zero, is the one subtle line in the
structure, and the interleaved test exists to keep it honest.

#listing("dsa/samples-js/src/ch05-ringqueue.mjs", first: 37, last: 65, caption: [javascript, private grow, enqueue, dequeue])

#listing("dsa/samples-py/src/Ch05/ringqueue.py", first: 22, last: 46, caption: [python, enqueue, dequeue, the seam-unwinding grow])

#listing("dsa/samples-lua/ch05_ringqueue.lua", first: 9, last: 35, caption: [lua, grow, enqueue, dequeue over 1-based slots])

The seam fixture pins identically in C, Java, JavaScript, and Lua:
capacity 4, dequeue two, enqueue two, physical layout 5 6 3 4 with
head at slot 2, then growth copies 3 4 5 6 back to slot 0, 7 lands at
slot 4, and the copy counter reads 4. Python runs the same story with
letters, c d e f g across the seam and head 0 tail 5 after growth.
Go pins the seam positions and the grow copy count in its tests. C\#
does the same rebase inside `Grow`, one door over.

#diagram([the ring, four live slots split across the seam], length: 13pt, {
  let cx = 7.0
  let cy = 2.6
  let rad = 2.3
  let occupied = (6, 7, 0, 1)
  let slot(i) = (cx + rad * calc.cos(90deg - i * 45deg), cy + rad * calc.sin(90deg - i * 45deg))
  for i in range(8) {
    let p = slot(i)
    let f = if i in occupied { luma(205) } else { luma(240) }
    cdraw.circle(p, radius: 0.36, fill: f)
    cdraw.content(p, [#i], size: 6pt)
  }
  cdraw.content((cx, cy), [ring of 8], size: 6.5pt)
  cdraw.content((1.6, 6.1), [head, next dequeue reads slot 6], size: 6.5pt)
  cdraw.line((2.6, 5.9), slot(6))
  cdraw.content((12.6, 6.1), [tail, next enqueue writes slot 2], size: 6.5pt)
  cdraw.line((11.6, 5.9), slot(2))
  cdraw.content((7.0, -0.6), [slots 6, 7, 0, 1 hold the queue in order, across the seam], size: 6.5pt)
})

The BCL `Queue<T>` and the producer consumer `System.Threading.Channels`
are this shape plus locking discipline. The `Channels` version is the
async answer when producers and consumers are tasks, and the ring
here is its single threaded ancestor.

== bracket matching

The canonical stack algorithm. Openers push, closers pop and compare,
and any mismatch or leftover opener fails.

The dry run: the fixture is the theory table over "([]{})", "([)]",
"(((", ")", "", and "a[b]{c}(d)", asserted by the C\# suite; the
other six pin "([)]" false and "{[()]}" true instead.

+ ( opens the run: the stack holds (.
+ [ pushes, then ] pops it and the pair matches: back to (.
+ { pushes, then } pops it and matches: back to (.
+ ) pops the last ( and matches: the stack empties, the string
  balances.
+ The crossed "([)]" dies one char early, ) expects ( on top and
  finds [, and "(((" fails on the leftover openers, while "" never
  pushes and the non-brackets in "a[b]{c}(d)" ride along.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*char*], [*action*], [*stack after*], [*verdict*]),
  [(], [push], [(], [],
  [\[], [push], [( \[], [],
  [\]], [pop, match], [(], [],
  [{], [push], [( {], [],
  [}], [pop, match], [(], [],
  [)], [pop, match], [], [balanced],
)

The crossed false against the nested true is pinned by every suite,
and the listings below build the matcher seven ways.

#listing("dsa/samples-c/src/Ch05/stack.c", first: 42, last: 65, caption: [c, the matcher over the same three primitives])

#listing("dsa/samples-go/ch05/stack.go", first: 38, last: 55, caption: [go, bracket match on the slice-backed stack])

#listing("dsa/samples-java/src/Ch05/Stack.java", first: 42, last: 68, caption: [java, opens and closerFor, every non-opener pops as a closer])

#listing("dsa/samples/src/Ch05/Buffers.cs", first: 89, last: 106, caption: [c\#, nested delimiters, dictionary of expectations])

#listing("dsa/samples-js/src/ch05-stack.mjs", first: 33, last: 49, caption: [javascript, opener sets and closer maps])

#listing("dsa/samples-py/src/Ch05/stack.py", first: 34, last: 45, caption: [python, the pairs map and the scan])

#listing("dsa/samples-lua/ch05_stack.lua", first: 31, last: 46, caption: [lua, table lookups for openers and closers])

Every suite pins "([)]" false and the empty string true. C, Java,
JavaScript, Lua, and Python pin "{[()]}" true, C\#'s positive fixture
is "([]{})". One semantic fork the suites each state: C\#, Go, and
Python ignore non-bracket characters and pin fixtures that use them,
while the C, Java, JavaScript, and Lua matchers treat every non-opener
as a closer, so foreign input fails there.

#diagram([bracket matching, the scan with the opener stack under each step], length: 13pt, {
  // input ( ( ) ) ) with the stack after consuming each char
  let input = ("(", "(", ")", ")", ")")
  let s0 = ("(",)
  let s1 = ("(", "(")
  let stacks = (s0, s1, s0, ())
  cdraw.line((1.6, 6.4), (7.9, 6.4), stroke: luma(100))
  cdraw.line((1.6, 6.4), (1.6, 6.6), stroke: luma(100)); cdraw.line((7.9, 6.4), (7.9, 6.6), stroke: luma(100))
  cdraw.content((4.75, 6.95), [openers push, closers pop and compare], size: 6.5pt)
  for (i, ch) in input.enumerate() {
    let cx = 2.35 + i * 1.4
    cdraw.rect((cx - 0.35, 5.6), (cx + 0.35, 6.2), fill: luma(235), radius: 0.02)
    cdraw.content((cx, 5.9), [#ch], size: 6.5pt)
    if i < 4 {
      let st = stacks.at(i)
      for (j, s) in st.enumerate() {
        let y = 4.7 - j * 0.55
        cdraw.rect((cx - 0.3, y - 0.22), (cx + 0.3, y + 0.22), fill: luma(205), radius: 0.02)
        cdraw.content((cx, y), [#s], size: 6pt)
      }
    } else {
      cdraw.line((cx - 0.25, 4.7), (cx + 0.25, 5.05), stroke: luma(100))
      cdraw.line((cx - 0.25, 5.05), (cx + 0.25, 4.7), stroke: luma(100))
    }
  }
  cdraw.content((10.0, 4.85), [pop on an empty stack: fail], size: 6pt)
  cdraw.content((5.0, 3.05), [each column: the opener stack after that char], size: 6.5pt)
  cdraw.content((5.0, 1.95), [a leftover opener at the end fails the same way], size: 6.5pt)
})

== shunting yard

Dijkstra's algorithm converts infix to postfix with one operator
stack and one output list. Precedence decides when to pop, and the
paren pops until its partner.

The dry run: the fixture is "3 + 4 \* 2" through the yard and back,
asserted by the C\# suite, with the associativity pin "8 - 3 - 2"
beside it.

+ The yard passes 3, 4, and 2 to the output, stacks + , and \* climbs
  on top of it, precedence 2 over 1.
+ The flush pops \* then + , and the postfix reads 3 4 2 \* +,
  pinned as a string.
+ The evaluation pass pushes 3, 4, 2, then \* pops twice: 4 × 2 = 8,
  and 8 goes back on.
+ + pops 8 and 3: 3 + 8 = 11, the pinned answer.
+ The associativity pin: the second minus of "8 - 3 - 2", precedence
  equal at 1, pops the first, the output reads 8 3 - 2 -, and the
  evaluation runs 8 - 3 = 5 then 5 - 2 = 3, the (8 - 3) - 2 grouping.

#diagram([the evaluation pass over 3 4 2 \* +, the operand stack after each token, two pops and a push per operator], length: 13pt, {
  let row = (y, tok, vals, note) => {
    cdraw.content((0.7, y + 0.35), tok, size: 6pt)
    for (i, v) in vals.enumerate() {
      let x = 2.4 + i * 0.9
      cdraw.rect((x, y), (x + 0.9, y + 0.7), fill: if i == vals.len() - 1 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 0.45, y + 0.35), [#v], size: 6pt)
    }
    cdraw.content((8.6, y + 0.35), note, size: 6pt)
  }
  row(5.8, [3], ("3",), [push])
  row(4.6, [4], ("3", "4"), [push])
  row(3.4, [2], ("3", "4", "2"), [push])
  row(2.2, [\*], ("3", "8"), [pops 4 and 2: 4 × 2 = 8])
  row(1.0, [+], ("11",), [pops 8 and 3: 3 + 8 = 11])
})

The 11 and the associativity 3 are the pinned pair, and the listings
below run the yard in seven languages.

#listing("dsa/samples-c/src/Ch05/shunting.c", first: 61, last: 83, caption: [c, the yard over char and token arrays])

#listing("dsa/samples-go/ch05/shunting.go", first: 25, last: 64, caption: [go, the yard with error returns for bad input])

The other five yards, Java evaluating through a switch expression
over a record token:

#listing("dsa/samples-java/src/Ch05/Shunting.java", first: 49, last: 103, caption: [java, precedence, the yard, and the value stack through a switch expression])

#listing("dsa/samples/src/Ch05/Buffers.cs", first: 108, last: 161, caption: [c\#, infix to postfix, then postfix evaluation])

The left associativity rule is where implementations quietly differ:
for equal precedence the loop must pop the stacked operator first,
so `8 - 3 - 2` groups as `(8 - 3) - 2` and evaluates to 3, which the
test pins. Evaluation itself is a second stack pass, operands push,
operators pop twice, compute, push. Reverse polish is trivial to
evaluate and hard to get wrong, which is why some calculators, hp's
classic rpn line, exposed it directly.

Four more yards:

#listing("dsa/samples-js/src/ch05-shunting.mjs", first: 27, last: 51, caption: [javascript, the yard over kind-tagged tokens])

#listing("dsa/samples-py/src/Ch05/shunting.py", first: 17, last: 36, caption: [python, the yard in single-character tokens])

#listing("dsa/samples-lua/ch05_shunting.lua", first: 37, last: 60, caption: [lua, the yard with table.remove as the pop])

The associativity anchor holds in all seven: 8 - 3 - 2 emits
8 3 - 2 - and evaluates to 3. C, Go, and C\# pin the rendered string
directly, Java, JavaScript, and Lua render through the same helper,
Python pins 83-2- in single-character form. Division truncates toward
zero in C, Go, Java, C\#, and JavaScript; Lua and Python floor, and
their fixtures stay positive and exact so the difference never shows.
Go's tokenizer is the only one that rejects unexpected characters
with an error.

#diagram([shunting yard on 8 - 3 - 2, the equal precedence pop keeps it left associative], length: 13pt, {
  let col = i => 5.0 + i * 3.0
  let outs = ("8", "8", "8 3", "8 3 -", "8 3 - 2")
  let ops = ("", "-", "-", "-", "-")
  for i in range(5) {
    cdraw.rect((col(i) - 1.2, 5.3), (col(i) + 1.2, 5.9), fill: luma(235), radius: 0.02)
    cdraw.content((col(i), 5.6), [after #((("8", "-", "3", "-", "2")).at(i))], size: 6.5pt)
  }
  cdraw.line((3.8, 5.3), (16.8, 5.3), stroke: luma(100))
  for i in range(5) {
    cdraw.rect((col(i) - 1.2, 3.6), (col(i) + 1.2, 4.2), fill: luma(235), radius: 0.02)
    cdraw.content((col(i), 3.9), [#outs.at(i)], size: 6pt)
    cdraw.rect((col(i) - 1.2, 2.3), (col(i) + 1.2, 2.9), fill: luma(235), radius: 0.02)
    cdraw.content((col(i), 2.6), [#ops.at(i)], size: 6pt)
  }
  cdraw.content((1.7, 5.6), [token], size: 6.5pt)
  cdraw.content((1.7, 3.9), [output], size: 6.5pt)
  cdraw.content((1.7, 2.6), [op stack], size: 6.5pt)
  cdraw.content((9.5, 1.55), [equal precedence pops the stacked minus first], size: 6.5pt)
  cdraw.content((9.5, 0.45), [flush: 8 3 - 2 -, which is (8 - 3) - 2 = 3], size: 6.5pt)
})

== the deque

#flow(
  [the deque selection rule, which ends are active],
  node((0, 0), [which ends are active?]),
  node((-2.8, -1.7), [both push and pop: #linebreak() the sentinel ring is the deque]),
  node((0, -1.7), [one feeds, one drains: #linebreak() the ring buffer]),
  node((2.8, -1.7), [one end only: #linebreak() the stack]),
  node((0, -3.5), [the BCL ships no Deque<T> #linebreak() as of .NET 10]),
  edge((0, 0), (-2.8, -1.7), "-|>"),
  edge((0, 0), (0, -1.7), "-|>"),
  edge((0, 0), (2.8, -1.7), "-|>"),
  edge((0, -1.7), (0, -3.5), "-|>"),
)

A deque, double ended queue, is what you get when both ends accept
push and pop. Chapter 4's sentinel ring already is one: `AddFirst`,
`AddLast`, remove at either end, all constant. Notably the BCL has
no general `Deque<T>` as of .NET 10, the generic collections page
lists `Queue<T>`, `Stack<T>`, `LinkedList<T>`, and `PriorityQueue`
but no deque, so the ring from chapter 4 is also the local answer
when both ends are active. The selection rule falls out of this
chapter's mechanics: deque when both ends are active, ring when one
end feeds and one drains, stack when only one end exists at all.

The dry run: the fixture is RingDeque(8) across its four C\# tests,
asserted by the C\# suite, with C, Java, JavaScript, and Lua running
the same sequence over checked slots.

+ PushBack 1, 2, 3 fill slots 0, 1, 2, then PushFront 0 steps the
  head back to slot 7: the read is 0, 1, 2, 3 at count 4.
+ The rotate step, its own fixture rebuilt from 0,1,2,3, pops the
  front 0 and pushes it at the back: 1, 2, 3, 0.
+ TryPopBack reads slot 2 and returns 3, TryPopFront reads slot 7
  and returns 0: count 2.
+ PushFront 9 wraps the head from slot 0 back to slot 7: the read is
  9, 1, 2.
+ The empty deque refuses at both ends, and after PushBack 5 the
  back pop returns 5, then refuses again at 0.

#diagram([the deque run over eight slots, the head stepping backward past slot 0 while the values stay put], length: 13pt, {
  let frame = (y, label, vals, head) => {
    cdraw.content((0.7, y + 0.35), label, size: 6pt)
    for i in range(8) {
      let x = 2.2 + i * 1.0
      let v = vals.at(i)
      if v == none {
        cdraw.rect((x, y), (x + 1.0, y + 0.7), fill: none, stroke: luma(160), radius: 0.02)
      } else {
        cdraw.rect((x, y), (x + 1.0, y + 0.7), fill: luma(205), radius: 0.02)
        cdraw.content((x + 0.5, y + 0.35), [#v], size: 6pt)
      }
      cdraw.content((x + 0.5, y - 0.3), [#i], size: 6pt)
    }
    cdraw.content((2.7 + head * 1.0, y + 1.02), [head], size: 6pt)
  }
  frame(5.6, [after pushes], (1, 2, 3, none, none, none, none, 0), 7)
  frame(3.2, [after pops], (1, 2, none, none, none, none, none, none), 0)
  frame(0.8, [pushfront 9], (1, 2, none, none, none, none, none, 9), 7)
})

The 9, 1, 2 wrap and the both-end refusals are pinned, and the
listings below build the deque seven ways.

All seven languages build the ring deque by hand, C first:

#listing("dsa/samples-c/src/Ch05/deque.c", first: 23, last: 49, caption: [c, all four end operations over one head and a count])

#listing("dsa/samples-go/ch05/deque.go", first: 61, last: 77, caption: [go, pop back and the rotate step])

#listing("dsa/samples-java/src/Ch05/Deque.java", first: 18, last: 58, caption: [java, all four end operations over one head and a count, rotate as front to back])

#listing("dsa/samples/src/Ch05/Deque.cs", first: 18, last: 61, caption: [c\#, both pushes, both pops, and the one-step rotate])

#listing("dsa/samples-js/src/ch05-deque.mjs", first: 17, last: 43, caption: [javascript, both pushes and both pops])

#listing("dsa/samples-py/src/Ch05/deque.py", first: 32, last: 63, caption: [python, both ends, the room check, and rotate])

#listing("dsa/samples-lua/ch05_deque.lua", first: 11, last: 37, caption: [lua, the four operations, modulo over 1-based slots])

C, C\#, Java, JavaScript, and Lua share one fixture family: 0 1 2 3
after both-end pushes, one rotate step turns it into 1 2 3 0, both
ends pop, and an empty deque refuses at both ends. Python rotates the
other way, pop back into push front, pins a rotate by the full length
as the identity, and watches growth run 2 to 4 to 8 under front
pushes. Go's Rotate moves the back to the front, Python's direction,
and its ring grows on demand like its queue. The BCL still ships no
`Deque<T>`, so C\# builds the ring by hand too, chapter 4's sentinel
ring in miniature.

== across the seven languages

Build sizes count non-comment source lines over the featured files;
bundled checks count where the language puts them in the same file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [384], [libc only], [four programs over static arrays, bounded stacks refuse at capacity 8, refusal codes instead of exceptions],
  [go], [293], [fmt, strconv, strings], [the tokenizer rejects bad characters with errors, EvalInfix refuses division by zero],
  [java], [390], [jdk 27 stdlib], [ArrayDeque left out, the ring is hand-rolled, pops surface as null where c used a status flag, yard tokens are records evaluated through a switch expression, division truncates toward zero like c],
  [c\#], [197], [bcl only], [the frozen yard files plus the ring deque, no bcl deque exists, TryPop out-parameters refuse underflow],
  [javascript], [185], [node stdlib], [Math.trunc keeps division toward zero like c, tokens carry a kind field],
  [python], [252], [stdlib only], [single-character tokens keep the yard small, fixtures keep division exact so floor never shows],
  [lua], [326], [lib.lua harness], [1-based slots shift every modulo expression by one],
)

sources: learn.microsoft.com, `Queue<T>` and `Stack<T>` api pages
including the circular-array remarks, generic collections in .NET
listing the shipped container set, `System.Threading.Channels`
overview, accessed 2026-09-08. Sample behavior verified by
`make verify-csharp`, 16 tests in chapter 5 of the samples suite.
The seven-language layer verifies the same way: 4 C programs under
`make verify-c`, 12 Go tests, the java runner's 62 Ch05 checks over
4 files under `run-java-samples`, 15 `node --test` cases, 42 Python
checks across 4 files, and 14 Lua checks under `run.lua`.
