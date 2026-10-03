#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= option, result, and the railway

Chapter #xref-to("math", "adt") built tagged sums with anonymous unions and
exhaustive switches. This chapter puts them to work as error channels: an
option type that makes presence data, a result type whose error track carries
a typed code and a position, the map, and_then, or_else combinators that
compose fallible stages into one railway, the [[nodiscard]] contracts that
make ignoring a returned rail a compile failure, and the defer teardown that
keeps resources honest when a stage steps off the track. Every behavioral
claim below is one of the 78 checks in the 4 samples of chapter 27 or a
sentence quoted from a canonical source fetched 2026-09-22. The dsa book
never builds this machinery, its pipelines return error codes inline, so
this chapter is self contained on that side. Where chapter
#xref-to("math", "error") asked how far a computed number drifts from the
truth, this chapter asks how a computed failure travels through a program
without being dropped on the floor.

== from null to option

The C library answers "did this lookup find anything" with a pointer or a
sentinel. cppreference describes the macro: "The macro NULL is an
implementation-defined null pointer constant ..." (en.cppreference.com/w/c/types/NULL,
fetched 2026-09-22). C23 adds a typed spelling: "The keyword nullptr denotes
a predefined null pointer constant. It is a non-lvalue of type nullptr_t"
(en.cppreference.com/w/c/language/nullptr, fetched 2026-09-22). Both give
absence a representation, and both share one defect: the caller cannot tell
a missing result from a value that happens to equal the sentinel. A table
lookup that returns -1 for a miss collides with the width -1.

The fix is the smallest possible sum type. An option of `int32_t` is the
sum of unit and the payload: one tag byte, 0 or 1, selects between none and
some v. The struct is 8 bytes on this machine, one tag byte, 3 bytes of
padding, and the 4 byte payload, checked by a `static_assert` in the sample
and again at runtime, the width of one pointer. The two-number play: a 4
byte int sentinel makes -5 mean two things, a stored value and a miss,
while one tag byte lets 0 and 1 decide and -5 stays a value.

#listing("math/samples/src/Ch27/option.c", first: 33, last: 63, caption: [the raw nullptr convention, then the option constructors and accessors, all [[nodiscard]]])

The dry run: the config table holds width 12, height 9, depth 4. The lookup
of "width" walks the table, matches on the first entry, and returns some 12.
The lookup of "scale" walks all 3 entries, matches nothing, and returns
none. Mapping add5 over the first gives some 17. Mapping it over the second
changes nothing, and unwrap_or collapses the none onto the fallback 1.

#diagram([the sentinel collision on the left, the tag that removes it on the right], length: 13pt, {
  let box(x, y, w, t, fill: luma(235), stroke: luma(100)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, stroke: stroke, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  cdraw.content((1.9, 8.1), [sentinel returns], size: 6.5pt)
  box(0, 6.2, 3.8, [int lookup])
  cdraw.line((1.9, 6.2), (1.9, 5.4), stroke: luma(60), mark: (end: ">"))
  box(0, 4.4, 3.8, [-1 means missing], fill: luma(205))
  cdraw.line((1.9, 4.4), (1.9, 3.6), stroke: luma(60), mark: (end: ">"))
  box(0, 2.6, 3.8, [-1 is a value too], stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((1.9, 1.9), [both print -1], size: 6pt)

  cdraw.content((11, 8.1), [tagged option], size: 6.5pt)
  box(8.2, 6.2, 5.6, [opt lookup, tag + payload])
  cdraw.line((10.2, 6.2), (10.2, 5.4), stroke: luma(60), mark: (end: ">"))
  cdraw.line((12.6, 6.2), (12.6, 5.4), stroke: luma(60), mark: (end: ">"))
  box(7.4, 4.4, 3.6, [none, tag 0], fill: luma(205))
  box(11.4, 4.4, 3.6, [some v, tag 1])
  cdraw.content((11, 3.4), [the tag decides, -5 stays a value], size: 6pt)
})

Every accessor is [[nodiscard]] because an option nobody examines is a
lookup whose answer went straight to the garbage. The sample checks both
conventions against the same table: the raw pointer version returns
nullptr exactly for the miss, and the option version returns none for the
same miss while some 12 survives mapping, chaining, and fallback.

#listing("math/samples/src/Ch27/option.c", first: 93, last: 123, caption: [the checks: raw nullptr against tagged sums, then map and and_then over the config table])

#callout("pitfall", "a none is not an error", [Option answers "is there a
value". Result answers "did the work fail". A missing table entry is a none,
a nibble the parser cannot read is an error, and merging the two types puts
absence codes into error switches. Keep two types and the switches stay
honest.])

== result, the error channel

Presence has two states. Failure has as many states as the operation has
ways to fail, and each failure wants its own evidence. A result is a sum
with an error channel in the second arm: the ok payload is the parsed
value, the error payload is a code from a fixed underlying type enum plus
one evidence byte, here the string position where the parse died. The C23
sized enum spelling, `enum hex_err : uint8_t`, pins the codes to one byte
so the whole error payload fits the padding beside the value.

The fixture is a hex string parser. It fails 3 ways: the empty string, a
character that is not a nibble at some index, and an accumulator that
crosses the $2^32 - 1$ frontier. Every failure carries its position as
data, so the caller can point at the offending character.

#listing("math/samples/src/Ch27/parsehex.c", first: 8, last: 43, caption: [the sized enum codes, the two track sum, and the accessors])

#listing("math/samples/src/Ch27/parsehex.c", first: 45, last: 68, caption: [the parse loop, each failure path returns a code plus a position])

The dry run: parse "100000000". The first 8 nibbles build 0x10000000, all
zeros after a leading 1. The 9th nibble shifts the accumulator to
0x100000000, which is 4294967296, one past the 4294967295 limit, and the
loop returns too-big with position 8 before the value is ever truncated.
The two-number play sits on that boundary: 4294967295 parses to an ok
value, 4294967296 does not exist on the ok track, and the difference
arrives as 2 bytes of error payload.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([input], [track], [payload]),
  [ffffffff], [ok], [4294967295],
  [100000000], [err], [too-big, at 8],
  [0x10], [err], [bad-nibble, at 1],
  [f0z9], [err], [bad-nibble, at 2],
  [""], [err], [empty, at 0],
)

#diagram([five fixed inputs routed onto the two tracks], length: 13pt, {
  let row(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 0.8), fill: luma(245), stroke: luma(140), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.4), t, size: 6pt)
  }
  row(0, 7.2, 3.4, [ffffffff])
  row(0, 5.6, 3.4, [100000000])
  row(0, 4.0, 3.4, [0x10])
  row(0, 2.4, 3.4, [f0z9])
  row(0, 0.8, 3.4, [" "])
  cdraw.rect((10.5, 6.6), (14.9, 7.6), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((12.7, 7.1), [ok, value], size: 6pt)
  cdraw.rect((10.5, 1.2), (14.9, 2.2), fill: luma(205), stroke: luma(100), radius: 0.02)
  cdraw.content((12.7, 1.7), [err, code + at], size: 6pt)
  cdraw.line((3.4, 7.6), (10.5, 7.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((3.4, 6.0), (10.5, 2.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((3.4, 4.4), (10.5, 1.9), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((3.4, 2.8), (10.5, 1.8), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((3.4, 1.2), (10.5, 1.7), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
})

#listing("math/samples/src/Ch27/parsehex.c", first: 117, last: 140, caption: [the frontier checks: the last ok value, the ninth nibble, the fault positions])

A map over a result squares the ok track and passes the error through with
code and position intact, checked in the sample. That single behavior,
leave the error alone, is what the whole railway runs on.

== the railway, map and then

Scott Wlaschin named the picture: "Many examples in functional programming
assume that you are always on the 'happy path'. But to create a robust real
world application you must deal with validation, logging, network and
service errors, and other annoyances", handled "using a fun and
easy-to-understand railway analogy" (fsharpforfunandprofit.com/rop/,
fetched 2026-09-22). Two tracks run side by side. Stages sit on the top
track and only ever see ok values. Each stage is also a switch: on failure
it drops the computation onto the bottom track, which runs straight to the
caller and skips every later stage.

Three combinators build this in C, all one line each at heart. `map`
transforms the ok payload. `and_then` runs a fallible stage on the ok
payload and lets its result pick the track. `or_else` runs a recovery on
the error payload and can rejoin the top track. A fourth, the statement
macro `RAIL_TRY`, gives the inline C style the same power: bind the value
or return the error to the caller without touching it.

#listing("math/samples/src/Ch27/railway.c", first: 40, last: 61, caption: [the combinator trio plus the try propagation macro])

The pipeline fixture: stage 1 parses a hex string, stage 2 demands a 12 bit
4-aligned address and says which demand failed, stage 3 packs a check byte,
the value xor 0xA5, above the value. Failure is injected by the inputs
themselves, no randomness anywhere.

#listing("math/samples/src/Ch27/railway.c", first: 63, last: 88, caption: [stage 1, the parser from the previous section returning rails])

#listing("math/samples/src/Ch27/railway.c", first: 90, last: 118, caption: [stage 2 with typed refusals, stage 3, and the two driver forms])

The dry run: pipeline("13"). Stage 1 parses 13 hex to 19 and returns ok.
Stage 2 computes 19 mod 4 = 3, refuses alignment, and returns an error
carrying residue 3. Stage 3 never runs. The counters prove it: the sample
resets 3 stage counters before each scenario and checks them after, and
the align failure leaves them at 1, 1, 0. The same counters read 1, 0, 0
for the input "zz", whose parse error means stage 2 never wakes up either.

#diagram([the two track railway: stages on top, the dashed error track short circuiting stage 3], length: 13pt, {
  let station(x, t) = {
    cdraw.rect((x, 6.3), (x + 3.0, 7.3), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + 1.5, 6.8), t, size: 6pt)
  }
  cdraw.line((0.4, 5.9), (5.3, 5.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.9, 5.9), (11.3, 5.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((12.9, 5.9), (18.4, 5.9), stroke: luma(60), mark: (end: ">"))
  station(1.2, [stage 1 parse])
  station(7.1, [stage 2 validate])
  station(13.1, [stage 3 encode])
  cdraw.content((18.1, 6.6), [ok out], size: 6pt)
  cdraw.line((8.6, 6.3), (8.6, 2.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((14.6, 6.3), (14.6, 2.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((5.3, 2.0), (18.4, 2.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((18.1, 2.7), [err out], size: 6pt)
  cdraw.content((10.6, 2.65), [error track, code and info ride it], size: 6pt)
  cdraw.content((11.5, 1.1), [a stage 2 failure skips stage 3 entirely], size: 6pt)
})

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([input], [counters c1 c2 c3], [outcome]),
  [a8], [1 1 1], [ok, encode 852136],
  [0abc], [1 1 1], [ok, encode 169413308],
  [13], [1 1 0], [err align, residue 3],
  [1234], [1 1 0], [err range, excess 1],
  [zz], [1 0 0], [err bad-nibble, at 0],
)

#listing("math/samples/src/Ch27/railway.c", first: 141, last: 176, caption: [the scenarios: values pinned, counters proving the short circuit on every failure])

Recovery is the same picture read backwards. `rail_or_else(pipeline("13"),
clamp_recover)` hands the align error to a recovery that encodes address 0,
and the result is an ok rail worth 10813440 with stage 3 having run exactly
once. Wlaschin's own page carries the caveat, "please don't take it to
extremes", and the caveat is the design rule: the error track pays for
itself where failures are ordinary, and it is dead weight where a failure
is a bug that should stop the program.

#callout("verify", "the counter proof", [Short circuit claims are cheap to
state and easy to fake. The sample makes each stage increment a static
counter, resets all 3 before every scenario, and CHECKs the triple after
the run, so "stage 3 never ran" is 3 compared integers, not a diagram
assertion.])

== contracts the compiler can check

A railway only works if callers hold the rail. C23 has one attribute for
that, and cppreference states its exact strength: "from a discarded-value
expression other than a cast to void, a function declared nodiscard is
called ... the compiler is encouraged to issue a warning", with the same
rule for a function returning a struct, union, or enum declared nodiscard
(en.cppreference.com/w/c/language/attributes/nodiscard, fetched 2026-09-22).
Encouraged is the honest word. The attribute is a request to the
diagnostic, worth nothing at runtime and worth everything once the build
upgrades it: this corpus compiles every sample under -Werror, and chapter
#xref-to("c-os-cloud", "llvm") pins the exact diagnostic, "declared with
'nodiscard' attribute [-Werror,-Wunused-result]", on a call site that
ignored one.

Every constructor and accessor in this chapter's samples carries
[[nodiscard]], and `option.c` opens with a preprocessor check that pins the
attribute value itself, `__has_c_attribute(nodiscard)` equal to 202003L,
so the file refuses to build where the contract cannot be asked for. The
runtime side of the contract is the tag: reading the union payload of a
result without checking the tag first is the one discipline the compiler
cannot see, which is why the samples funnel every read through accessors
that check.

#diagram([two call sites, one diagnostic apart], length: 13pt, {
  let box(x, y, w, t, fill: luma(235), stroke: luma(100)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, stroke: stroke, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  cdraw.content((2.6, 7.3), [discarded], size: 6.5pt)
  box(0, 5.4, 5.2, [config_get(k);])
  cdraw.line((2.6, 5.4), (2.6, 4.6), stroke: luma(60), mark: (end: ">"))
  box(0, 3.6, 5.2, [unused result], fill: luma(205))
  cdraw.content((2.6, 2.9), [an error under -Werror], size: 6pt)
  cdraw.content((10.8, 7.3), [examined], size: 6.5pt)
  box(7.4, 5.4, 6.8, [w = unwrap_or(...)])
  cdraw.line((10.8, 5.4), (10.8, 4.6), stroke: luma(60), mark: (end: ">"))
  box(7.4, 3.6, 6.8, [value bound], fill: luma(235))
  cdraw.content((10.8, 2.9), [0 runtime bytes either way], size: 6pt)
})

The static side gets contracts too. The samples `static_assert` the 8 byte
width of every sum, tag, padding, and 4 byte payload together the width of
one pointer, and `parsehex.c` asserts the error codes distinct. These are
compile time facts about the channel, checked once per
build. The two-number play for this section: 2 call sites, 1 attribute, 0
runtime bytes, and the difference between them is one build failure.

#callout("note", "nodiscard is a warning at heart", [The standard
encourages, it does not require. A build without -Werror or an explicit
cast to void silences the diagnostic and the rail is still dropped. Treat
the attribute as the compiler joining the contract, and treat the unwrapped
read of a union payload as the contract only the tag can enforce.])

== cleanup ownership on both tracks

Error channels carry values. Resources are different: a file, a lock, a
buffer want release on every path, and the failure paths are exactly the
ones hand written cleanup forgets. C23 does not have defer. It arrives from
technical specification 25755, and clang 23.1.1 ships it as `stddefer.h`,
which enables the `defer` keyword under the `-fdefer-ts` driver flag the
sample gate carries. Chapter #xref-to("c-os-cloud", "stdlib") pins the
header, the flag, and the unwind orders on this machine.

The ownership rule for the railway: register the release with defer at the
point of acquisition, inside the same scope that owns the resource. Then
every exit from that scope, including the failure returns, unwinds the
registrations in reverse order, and the reverse order is the correct one
because later resources depend on earlier ones.

#listing("math/samples/src/Ch27/cleanup.c", first: 52, last: 91, caption: [the scene openers: one defer per acquisition, plus a scope local resource d that dies at its block end])

The dry run: open_scene with the failure injected at c. Acquire a, register
release a. Acquire b, register release b. Acquire c is refused, the
function returns 3, and the two registered defers fire in reverse: b, then
a. The recorder collects the string "ba". On the happy path the same
mechanism collects "cba". The invariant is checked per path: acquired
count equals released count, 3 and 3 on the happy path, 2 and 2 on the
failure at c, 0 and 0 when the very first acquisition is refused.

The layered scene adds the scope rule. Resource d lives inside a block,
its defer registered in that block, so d is released when the block closes,
before b and c are even requested. The full happy trace is "dcba", and
when c later refuses, the trace is "dba": d already gone at its block end,
b and a unwound at the return. The paired scene shows the compound form,
one defer wrapping a two step teardown, flush then close, firing as a unit
before the earlier registrations unwind.

#diagram([the defer stack: registration order down the left, reverse unwind out the right, the refused c shown dashed], length: 13pt, {
  let slot(x, y, t, dashed: false) = {
    let stroke = if dashed { (paint: luma(150), dash: "dashed") } else { luma(100) }
    cdraw.rect((x, y), (x + 2.4, y + 0.9), fill: luma(235), stroke: stroke, radius: 0.02)
    cdraw.content((x + 1.2, y + 0.45), t, size: 6pt)
  }
  slot(0.8, 2.0, [defer a])
  slot(0.8, 3.3, [defer b])
  slot(0.8, 4.6, [defer c], dashed: true)
  cdraw.line((0.4, 1.6), (0.4, 5.5), stroke: luma(140))
  cdraw.content((0.1, 1.1), [registration], size: 6pt)
  cdraw.line((3.2, 3.75), (6.4, 3.75), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.8, 4.05), [1st, b out], size: 6pt)
  cdraw.line((3.2, 2.45), (6.4, 2.45), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.8, 2.75), [2nd, a out], size: 6pt)
  cdraw.content((4.8, 5.05), [c refused, never registered], size: 6pt)
  cdraw.content((4.8, 0.8), [fail at c: trace "ba"], size: 6pt)
})

#listing("math/samples/src/Ch27/cleanup.c", first: 93, last: 108, caption: [the compound defer, a two step teardown registered as one unit])

#listing("math/samples/src/Ch27/cleanup.c", first: 122, last: 175, caption: [the path checks: pinned release traces and the acquired equals released invariant])

The interaction with the railway is the point. A stage that acquires and
returns a rail on failure does not need a cleanup branch per error, the
defers already cover every return. What defer cannot do is span the tracks:
a resource acquired inside stage 2 and needed by stage 3 wants ownership
passed through the ok payload, and that pattern, bracketing a fallible
computation with acquisition and release, is exactly the shape the next
chapter names and generalizes.

#callout("note", "defer is a technical specification, not c23", [The
keyword comes from TS 25755 and needs `-fdefer-ts` with clang 23.1.1's
`stddefer.h`. The corpus gate carries the flag, so these samples build in
the verified lane, and the corpus pins the unwind orders in its own c
book. Code aimed at plain c23 compilers needs the goto cleanup idiom
instead.])

== where the railway goes

This chapter built the channel in one concrete shape, a uint32 payload
with a byte of code and a byte of evidence. Nothing in map, and_then, or
or_else looked at those types. Each combinator is one tag test plus one
function call, and the same three definitions carry an option of doubles,
a result of matrices, or a parse forest. Three combinators, one macro, and
two chapters of generalization ahead.

#diagram([the combinator core and the two chapters that generalize it], length: 13pt, {
  cdraw.rect((0, 4.6), (6.2, 6.0), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((3.1, 5.5), [the railway, ch 27], size: 6pt)
  cdraw.content((3.1, 4.95), [map and_then or_else try], size: 6pt)
  cdraw.line((6.2, 5.5), (8.6, 6.6), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.2, 5.1), (8.6, 4.0), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((8.6, 6.1), (15.4, 7.2), fill: luma(245), stroke: luma(140), radius: 0.02)
  cdraw.content((12.0, 6.85), [functors and monads, ch 28], size: 6pt)
  cdraw.content((12.0, 6.4), [any carrier, the laws], size: 6pt)
  cdraw.rect((8.6, 3.5), (15.4, 4.6), fill: luma(245), stroke: luma(140), radius: 0.02)
  cdraw.content((12.0, 4.25), [pipelines and effects, ch 29], size: 6pt)
  cdraw.content((12.0, 3.8), [state, io, composition], size: 6pt)
})

Chapter #xref-to("math", "monads") peels the types off these combinators,
states the laws they satisfy, and rebuilds them over any carrier type,
which is where option and result stop being a convention and start being
an instance of a functor and a monad. Chapter #xref-to("math", "pipeline")
stops treating stages as pure functions, threading state and effects
through the same tracks, and the capstone game assembles the whole
machinery into a program whose failure paths are checked the same way this
chapter checked a parser's.

sources: cppreference NULL, en.cppreference.com/w/c/types/NULL, cppreference
nullptr, en.cppreference.com/w/c/language/nullptr, cppreference attribute
nodiscard, en.cppreference.com/w/c/language/attributes/nodiscard, all
fetched 2026-09-22. Scott Wlaschin, "Railway Oriented Programming",
fsharpforfunandprofit.com/rop/, fetched 2026-09-22, the two-track analogy
and the happy-path blurb quoted, the extremity caveat his. Defer ground
truth from the corpus's own pinned coverage, TS 25755 and clang 23.1.1
`stddefer.h` under `-fdefer-ts`, c-os-cloud ch 06, and the nodiscard
-Werror=unused-result diagnostic, c-os-cloud ch 07. mml-book draft
2024-01-15: no mapped chapter for functional error channels, none cited.
Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch27`,
78 checks in chapter 27 of the math suite, format and asan clean.
