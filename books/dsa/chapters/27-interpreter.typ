#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= an opcode machine

The smallest useful interpreter is one array and one index. Memory
holds integers, the instruction pointer walks them, and each word
names an operation with its operands sitting in the following cells.
Chapter 26 parsed expressions into trees and evaluated them
recursively, and this chapter compiles the same arithmetic into
linear code with jumps, the shape real bytecode interpreters take.
It is the same design
pushed to networked processors in contest puzzles, a
sibling of the state machines in #xref-to("game-systems", "fsm"),
and the loop at the bottom of #xref-to("python", "interpreter").
The same loop carries the icpc book's 2019 finals, problem I
(karel), a tiny robot language compiled to segments and run
iteratively with an explicit resume stack, the form the shallowest
host call stacks require.

== the instruction pointer loop

Four opcodes carry the whole idea: 1 adds, 2 multiplies, 3 reads
one input, 4 writes one output, and 99 halts. Operands are
addresses, the result address last, every instruction advances the
pointer by its own length, and the machine keeps nothing else, no
registers, no stack. Programs are data, memory can be rewritten by
the program itself, and cells past the halt are fair storage.

The dry run: the fixture is the C\# add program 1,5,6,7,99 with 10
and 20 in its data cells, asserted with its step count by the C\#
suite, the chained 1,1,1,4,99,5,6,0,99 pinning its 30 in the C and
Python suites.

+ The pointer opens at 0, reads opcode 1, add, and the operand
  fields 5 and 6 are addresses: the machine reads 10 out of slot 5
  and 20 out of slot 6.
+ The destination field 7 sends 10 + 20 = 30 into slot 7, the
  pointer advances by its own length of 4, and the 99 there closes
  the run at 2 steps.
+ The multiply twin 2,5,6,7,99 lands 10 × 20 = 200 in the same slot,
  and the echo program 3,0,4,0,99 reads the input 42 into slot 0 and
  writes it back out, 3 steps.
+ The chained program rewrites itself: its first add reads slots 1
  and 1 and stores 1 + 1 = 2 over the halt at slot 4, so the pointer
  now stands on a multiply.
+ That multiply reads slots 5 and 6 and stores 5 × 6 = 30 into slot
  0, and the relocated halt at slot 8 ends the run, memory closing
  30, 1, 1, 4, 2, 5, 6, 0, 99.
+ Cells past the code never move: the machine's clone keeps the
  original program array untouched while its own memory bends.

#diagram([the pointer as a sequence over both fixtures, the c\# add closing in 2 steps, the chained program relocating its own halt before the multiply lands 30], length: 13pt, {
  // track a: the c# fixture 1,5,6,7,99,10,20,0
  let a = (1, 5, 6, 7, 99, 10, 20, 0)
  for (i, v) in a.enumerate() {
    let x = 1.4 + i * 1.6
    cdraw.rect((x, 5.6), (x + 1.5, 6.5), fill: if i in (0, 4) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 6.05), [#v], size: 6.5pt)
    cdraw.content((x + 0.75, 5.3), [#i], size: 6pt)
  }
  cdraw.line((2.15, 6.6), (2.15, 7.0), stroke: luma(100))
  cdraw.line((2.15, 7.0), (8.35, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.35, 7.0), (8.35, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.25, 7.3), [add: 10 + 20 = 30 into slot 7], size: 6pt)
  cdraw.content((7.25, 8.1), [the c\# fixture, 2 steps], size: 6.5pt)
  // track b: the chained 1,1,1,4,99,5,6,0,99
  let b = (1, 1, 1, 4, 99, 5, 6, 0, 99)
  for (i, v) in b.enumerate() {
    let x = 1.4 + i * 1.6
    let hot = i in (0, 4, 8)
    cdraw.rect((x, 1.4), (x + 1.5, 2.3), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 1.85), if i == 4 { [2] } else { [#v] }, size: 6.5pt)
    cdraw.content((x + 0.75, 1.1), [#i], size: 6pt)
  }
  cdraw.line((2.15, 2.4), (2.15, 2.9), stroke: luma(100))
  cdraw.line((2.15, 2.9), (8.35, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.35, 2.9), (8.35, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.25, 3.2), [add: 1 + 1 = 2 over the halt], size: 6pt)
  cdraw.line((8.35, 3.4), (8.35, 3.9), stroke: luma(100))
  cdraw.line((8.35, 3.9), (14.75, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.75, 3.9), (14.75, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.55, 4.2), [mul: 5 × 6 = 30 into slot 0], size: 6pt)
  cdraw.content((7.25, 4.9), [the chained fixture rewrites slot 4], size: 6.5pt)
  cdraw.content((7.05, 0.4), [slot 4 held 99, the add leaves 2], size: 6pt)
  cdraw.content((16.8, 6.05), [echo 3,0,4,0,99: 42 in, 42 out], size: 6pt)
  cdraw.content((16.8, 5.15), [the clone keeps the program intact], size: 6pt)
  cdraw.content((16.8, 1.85), [the classic 30 lands in slot 0], size: 6pt)
  cdraw.content((16.8, 0.95), [halt moved to slot 8], size: 6pt)
})

Both fixtures close at the classic 30, and the listings below run
the loop in six languages.

#listing("dsa/samples-c/src/Ch27/opcodes.c", first: 33, last: 62, caption: [c, run to halt or fault, positional addressing, error flags over exceptions])
#listing("dsa/samples/src/Ch27/Machine.cs", first: 21, last: 74, caption: [c\#, one switch, mode closures below, long memory, a step counter])
#listing("dsa/samples-go/ch27/opcodes.go", first: 39, last: 92, caption: [go, run drives a machine struct, errors returned at every exit])
#listing("dsa/samples-js/src/ch27-opcodes.mjs", first: 6, last: 30, caption: [javascript, the base loop, every operand in position mode])
#listing("dsa/samples-py/src/Ch27/opcodes.py", first: 14, last: 40, caption: [python, slices pull whole instructions, unknown opcodes raise])
#listing("dsa/samples-lua/ch27_opcodes.lua", first: 7, last: 32, caption: [lua, 1-based cells shift every index, steps counted per instruction])

The day-2 style fixtures agree across all six suites: 1,0,0,0,99
writes 1+1 into slot 0, and the chained program 1,1,1,4,99,5,6,0,99
pins the classic 30, the add at slot 0 overwriting the halt that
then moves execution forward. Python squares its own input by
writing it past the code, javascript echoes an input back out, and
the lua suite counts steps, hand-traced instruction executions,
alongside every run. Every language refuses unknown opcodes, by
exception or error flag, and the c loop also stops on exhausted
input instead of spinning.

#diagram([the chained fixture executing, the add at slot 0 reading slots 1 and 1, writing 30 over the halt at slot 4], length: 13pt, {
  // 1,1,1,4,99,5,6,0,99 -> 30,1,1,4,2,5,6,0,99
  let vals = (1, 1, 1, 4, 99, 5, 6, 0, 99)
  let after = (30, 1, 1, 4, 2, 5, 6, 0, 99)
  for i in range(9) {
    let x = 1.6 + i * 1.85
    cdraw.rect((x, 5.2), (x + 1.85, 6.1), fill: if i in (0, 4) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.925, 5.65), [#vals.at(i)], size: 7pt)
    cdraw.content((x + 0.925, 4.8), [#i], size: 6pt)
    cdraw.rect((x, 1.8), (x + 1.85, 2.7), fill: if i in (0, 4) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.925, 2.25), [#after.at(i)], size: 7pt)
  }
  cdraw.line((2.5, 5.05), (2.5, 3.0), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.line((5.5, 5.05), (5.5, 3.0), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.line((2.5, 5.05), (2.5, 4.2), stroke: none)
  cdraw.content((9.0, 7.0), [before: add reads slots 1 and 1], size: 6pt)
  cdraw.content((9.0, 6.2), [writes 2 into slot 4, was 99], size: 6pt)
  cdraw.content((9.0, 3.4), [after: the halt moved to slot 8], size: 6pt)
  cdraw.content((9.0, 1.1), [the machine then halts at the new 99], size: 6pt)
  cdraw.content((2.6, 0.3), [the classic 30 lands in slot 0], size: 6pt)
  cdraw.content((2.6, -0.5), [cells past the halt stay untouched], size: 6pt)
})

== parameter modes

One instruction word carries more than the opcode. The low two
digits name the operation, and each higher decimal digit is the
mode of one parameter, least significant first: 0 reads the value
at the address, 1 uses the literal in the cell. So 1002 is a
multiply with its first operand positional and its second
immediate, 1101 adds two literals, and destinations always write
through an address, modes never apply to them.

The dry run: the fixture is the C\# triplet over one memory shape
with 99 and 2 in the data cells, 101, 9, and 104 asserted by the
C\# suite, go pinning the decoder split of 1002 and python the same
word storing 99.

+ One memory, three instruction words: 1, 1101, and 1001 all point
  their operand fields at 4, 5, 6 with destination 6, and slot 4
  holds 99 while slot 5 holds 2.
+ The positional word 1 reads both fields as addresses: 99 + 2 = 101
  lands in slot 6.
+ The immediate word 1101 reads both fields as literals: 4 + 5 = 9
  in the same slot.
+ The mixed word 1001 reads the first positionally and the second
  immediately: 99 + 5 = 104.
+ The decoder peels the word from the right: 1002 splits into opcode
  2 with modes position then immediate, and python runs that word
  over 33 in slot 4, storing 33 × 3 = 99.
+ The destination never carries a mode: all three words write
  through the literal field 6.

#diagram([the three reads as a sequence over one memory shape, positional arcs dipping into the data cells, immediate labels holding the field itself, the three landings stacked at the right], length: 13pt, {
  // one panel per word: word + operand fields + memory row with index labels
  let panel = (y0, word, m1, m2, res) => {
    cdraw.rect((1.2, y0), (2.5, y0 + 0.9), fill: luma(205), radius: 0.02)
    cdraw.content((1.85, y0 + 0.45), word, size: 6.5pt)
    for k in range(3) {
      cdraw.rect((3.0 + k * 0.9, y0), (3.7 + k * 0.9, y0 + 0.9), fill: luma(235), radius: 0.02)
      cdraw.content((3.35 + k * 0.9, y0 + 0.45), [#(4 + k)], size: 6.5pt)
    }
    let mem = (99, 2, 3, 0)
    for k in range(4) {
      cdraw.rect((6.6 + k * 0.9, y0), (7.3 + k * 0.9, y0 + 0.9), fill: if k < 2 { luma(235) } else { luma(245) }, radius: 0.02)
      cdraw.content((6.95 + k * 0.9, y0 + 0.45), [#mem.at(k)], size: 6.5pt)
      cdraw.content((6.95 + k * 0.9, y0 - 0.35), [#(4 + k)], size: 6pt)
    }
    cdraw.content((3.8, y0 - 0.35), if m1 and m2 { [imm 4, imm 5] } else if m1 { [pos 4 -> 99, imm 5] } else if m2 { [imm 4, pos 5 -> 2] } else { [pos 4 -> 99, pos 5 -> 2] }, size: 6pt)
    if not m1 {
      cdraw.line((3.35, y0 + 0.95), (3.35, y0 + 1.3), stroke: luma(100))
      cdraw.line((3.35, y0 + 1.3), (6.95, y0 + 1.3), stroke: luma(100))
      cdraw.line((6.95, y0 + 1.3), (6.95, y0 + 0.95), stroke: luma(100), mark: (end: ">"))
    }
    if not m2 {
      cdraw.line((4.25, y0 + 0.95), (4.25, y0 + 1.65), stroke: luma(100))
      cdraw.line((4.25, y0 + 1.65), (7.85, y0 + 1.65), stroke: luma(100))
      cdraw.line((7.85, y0 + 1.65), (7.85, y0 + 0.95), stroke: luma(100), mark: (end: ">"))
    }
    cdraw.rect((11.0, y0), (12.6, y0 + 0.9), fill: luma(205), radius: 0.02)
    cdraw.content((11.8, y0 + 0.45), [#res], size: 6.5pt)
    cdraw.content((11.8, y0 - 0.35), [slot 6], size: 6pt)
  }
  panel(6.0, [1], false, false, 101)
  panel(3.0, [1101], true, true, 9)
  panel(0.0, [1001], false, true, 104)
  cdraw.content((3.4, 8.2), [positional], size: 6pt)
  cdraw.content((3.4, 5.2), [immediate], size: 6pt)
  cdraw.content((3.4, 2.2), [mixed], size: 6pt)
  cdraw.content((14.6, 6.45), [both operands dip into memory], size: 6pt)
  cdraw.content((14.6, 3.45), [both fields are their own values], size: 6pt)
  cdraw.content((14.6, 0.45), [one of each, 99 + 5], size: 6pt)
  cdraw.content((14.6, 5.55), [the fields stay 4, 5, 6], size: 6pt)
  cdraw.content((14.6, 2.55), [the mode rides the word itself], size: 6pt)
})

The triplet 101, 9, 104 closes the reads, and the listings below
decode them in six languages.

#listing("dsa/samples-c/src/Ch27/modes.c", first: 30, last: 60, caption: [c, operand walks the mode digits one divide and mod per parameter])
#listing("dsa/samples/src/Ch27/Machine.cs", first: 22, last: 30, caption: [c\#, the mode and read closures inside the loop, tenpow beside])
#listing("dsa/samples-go/ch27/modes.go", first: 3, last: 13, caption: [go, the decoder exposed for teaching, modes packed as a bitmask])
#listing("dsa/samples-js/src/ch27-modes.mjs", first: 8, last: 17, caption: [javascript, decodeword returns opcode plus a modes array])
#listing("dsa/samples-py/src/Ch27/modes.py", first: 14, last: 51, caption: [python, decode peels two digits, a param closure reads either way])
#listing("dsa/samples-lua/ch27_modes.lua", first: 7, last: 37, caption: [lua, floor div and mod peel the digits, target always positional])

The c\# suite pins the teaching triplet on one fixture shape, memory
99 and 2 in the data cells: 2 positional gives 101, the sum of two
cell values, 1101 immediate gives 9, the sum of two literals, and
1001 mixed gives 104, a cell plus a literal. Go pins the decoder as
a unit, 1002 splits into multiply with modes position then
immediate and 11107 into a fully immediate comparison, and python
pins the same 1002 storing 99, the 33 in slot 4 times the literal
3. Javascript and lua run the same mixed multiply, and the
all-position twin in go and python proves the two readings of one
program agree only when the data is arranged for it, which is the
whole point of the modes existing.

#diagram([one instruction word 1002 splitting into an opcode and two mode digits, each digit steering how its operand is read], length: 13pt, {
  // word 1002: opcode 2, mode digits 0 (pos) and 1 (imm) over 1002,4,3,4,33
  cdraw.rect((2.0, 6.6), (5.2, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.6, 7.1), [1002], size: 9pt)
  cdraw.content((3.6, 6.15), [the instruction word], size: 6pt)
  cdraw.line((4.6, 6.5), (6.4, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.6, 6.5), (6.4, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.6, 6.5), (6.4, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.6, 5.4), (9.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((8.1, 5.8), [opcode 02, multiply], size: 6.5pt)
  cdraw.rect((6.6, 4.0), (9.6, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((8.1, 4.4), [digit 0: operand 1 positional], size: 6.5pt)
  cdraw.rect((6.6, 2.6), (9.6, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((8.1, 3.0), [digit 1: operand 2 immediate], size: 6.5pt)
  // the memory row: 1002,4,3,4,33
  let cells = ([1002], [4], [3], [4], [33])
  let notes = ([word], [addr], [lit], [addr], [data])
  for (i, v) in cells.enumerate() {
    let x = 2.0 + i * 1.7
    cdraw.rect((x, 0.4), (x + 1.7, 1.3), fill: if i in (1, 4) { luma(205) } else if i == 2 { luma(215) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.85, 0.85), v, size: 7pt)
    cdraw.content((x + 0.85, 0.0), notes.at(i), size: 6pt)
  }
  cdraw.content((12.8, 5.8), [mem of 4 holds 33], size: 6pt)
  cdraw.content((12.8, 4.4), [first operand: slot 4, value 33], size: 6pt)
  cdraw.content((12.8, 3.0), [second operand: the literal 3], size: 6pt)
  cdraw.content((12.8, 1.4), [product 99 lands in slot 4], size: 6pt)
  cdraw.content((12.8, 0.5), [the target address is always literal], size: 6pt)
})

== jumps and comparisons

Opcodes 5 and 6 move the pointer: jump if the first parameter is
nonzero, or zero, to the address in the second. Opcodes 7 and 8
write a comparison flag, 1 or 0, into a cell. Together they build
loops, and the loop program is the chapter's capstone fixture: read
n, decrement it, count the passes, jump back while n is nonzero,
output the count. Data cells sit past the halt so the loop cannot
overwrite its own code, and the jump targets are immediates, a
position-mode target would be dereferenced first.

The dry run: the fixture is the countdown program at input 3, its
outputs, final cells, and 15 hand-traced steps asserted by the C\#
suite, lua pinning the same trace.

+ The read at cell 0 stores 3 into data slot 20, 1 step, and the
  pointer lands on the zero test at 2.
+ Pass one: the test reads 3, nonzero, and falls through, the two
  immediate adds take n to 2 and the count to 1, and the backward
  jump returns to 2, 4 steps.
+ Pass two repeats on n = 2: n falls to 1, the count rises to 2, the
  jump returns, 4 steps.
+ Pass three leaves n at 0 and the count at 3, and now the nonzero
  test fails, so the pointer falls through to the output at 16,
  4 steps.
+ The output writes 3 and the halt at 18 closes the run:
  1 + 4 + 4 + 4 + 2 = 15 steps, slot 20 at 0 and slot 21 at 3.
+ Input 0 jumps straight from the test to the output, 4 steps and 0
  out, and input 7 loops seven passes to 7.

#table(
  columns: (auto, auto, auto, auto, 1.5fr),
  inset: 4pt,
  table.header([*phase*], [*n*], [*count*], [*steps*], [*pointer walk*]),
  [read into slot 20], [3], [0], [1], [0 -> 2],
  [pass one], [3 to 2], [0 to 1], [4], [2 -> 5 -> 9 -> 13 -> 2],
  [pass two], [2 to 1], [1 to 2], [4], [2 -> 5 -> 9 -> 13 -> 2],
  [pass three], [1 to 0], [2 to 3], [4], [2 -> 5 -> 9 -> 13 -> 16],
  [output then halt], [0], [3], [2], [16 -> 18],
)

The 15 steps close at the pinned 3, and the listings below build
the loop in six languages.

#listing("dsa/samples-c/src/Ch27/jumps.c", first: 87, last: 100, caption: [c, the sum program, data registers past the 29 cells of code])
#listing("dsa/samples/src/Ch27/Machine.cs", first: 49, last: 68, caption: [c\#, cases 5 through 8, the pointer moves or advances, never both])
#listing("dsa/samples-go/ch27/jumps.go", first: 3, last: 30, caption: [go, the countdown program as data, the cell map in its comment])
#listing("dsa/samples-js/src/ch27-jumps.mjs", first: 8, last: 43, caption: [javascript, both jump kinds read condition and target under modes])
#listing("dsa/samples-py/src/Ch27/jumps.py", first: 55, last: 87, caption: [python, the loop with its jump target read through slot 27])
#listing("dsa/samples-lua/ch27_jumps.lua", first: 62, last: 78, caption: [lua, the countdown table, 15 hand-traced steps at n equal to 3])

The countdown shape is shared by c\#, go, and lua, identical cell
layouts with the two data cells past the code, and the answers pin
across the family: input 3 outputs 3, input 0 jumps straight out
with 0, input 7 outputs 7, lua also pinning the full final memory
and the hand-traced 15 instructions. The c suite sums 1 to n
forward instead, registers at cells 28 through 31 past the code,
its backwards jump coded as 1006, flag positional and target
immediate. Python is the deliberate outlier: its loop reads the
jump target positionally through slot 27, so the loop-start address
is itself data in a cell, and that difference is stated in its
comment. Go adds the comparison programs, equals-7 and below-10, as
two more data tables.

#diagram([the countdown loop as code cells and data cells, the two jumps drawn as arcs, forward exit and backward loop], length: 13pt, {
  // cells: 0 read n, 2 test, 5 dec, 9 inc, 13 back-jump, 16 output, 18 halt; data 20, 21
  let rows = (
    ([0], [3, 20], [read n]),
    ([2], [1006, 20, 16], [if n = 0 goto 16]),
    ([5], [101, -1, 20, 20], [n -= 1]),
    ([9], [101, 1, 21, 21], [count += 1]),
    ([13], [1005, 20, 2], [if n != 0 goto 2]),
    ([16], [4, 21], [output count]),
    ([18], [99], [halt]),
    ([20], [n], [data]),
    ([21], [count], [data]),
  )
  for (r, row) in rows.enumerate() {
    let y = 7.6 - r * 1.05
    let (addr, code, note) = row
    let data = r >= 7
    cdraw.content((1.6, y), addr, size: 6.5pt)
    cdraw.rect((2.6, y - 0.4), (6.6, y + 0.4), fill: if data { luma(225) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.6, y), code, size: 6.5pt)
    cdraw.content((7.0, y), note, size: 6.5pt)
  }
  cdraw.line((8.6, 7.05), (9.4, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.4, 7.05), (9.4, 2.75), stroke: luma(100))
  cdraw.line((9.4, 2.75), (8.6, 2.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.6, 5.0), [exit jump to 16], size: 6pt)
  cdraw.line((8.6, 3.4), (9.9, 3.4), stroke: (paint: luma(60), dash: "dashed"), mark: (end: ">"))
  cdraw.line((9.9, 3.4), (9.9, 6.05), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.line((9.9, 6.05), (8.6, 6.05), stroke: (paint: luma(60), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.4, 4.2), [loop jump to 2], size: 6pt)
  cdraw.content((2.0, -1.1), [data past the code survives every pass], size: 6pt)
  cdraw.content((2.0, -1.9), [targets immediate: 16 and 2 are literals], size: 6pt)
  cdraw.content((14.6, 7.3), [n = 3: 15 traced steps], size: 6pt)
  cdraw.content((14.6, 6.4), [outputs 3, n ends 0], size: 6pt)
  cdraw.content((14.6, 5.5), [n = 0: straight out], size: 6pt)
  cdraw.content((14.6, 4.6), [outputs 0], size: 6pt)
})

== across the six languages

Featured build size counted as non-blank, non-comment lines of the
chapter's three sample files, test scripts included where the
language embeds them:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [302], [static arrays], [error flags over exceptions, sum program with registers past the code],
  [c\#], [72], [one file, closures for modes], [long memory, step counter, the 101, 9, 104 triplet pinned],
  [go], [131], [machine struct, int64 slices], [decoder exposed as a bitmask, countdown as returned data],
  [javascript], [97], [array spread copies], [modes as an array, jump targets under full modes],
  [python], [230], [lists, slices per instruction], [jump target read positionally through a cell, the stated outlier],
  [lua], [194], [tables, 1-based cells], [steps counted and hand traced, errors carry level 2],
)

sources: learn.microsoft.com for pattern-switch dispatch, go.dev
for multiple return values and `fmt.Errorf`, developer.mozilla.org
for spread copies, docs.python.org for slice assignment, lua.org
for integer floor division and modulo, accessed 2026-09-14. Sample
behavior verified by the six suite gates scoped to chapter 27: c 3
files and 49 checks, c\# 7 tests, go 14 tests, javascript 12 tests,
python 3 files and 28 asserts, lua 11 checks, zero skipped.
