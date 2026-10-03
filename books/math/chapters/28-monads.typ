#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= functors and monads in c

Chapter #xref-to("math", "adt") gave C a tagged product, a struct with a
discriminant and a payload, and chapter #xref-to("math", "railway") ran those
carriers as a railway where a failing stage hands its error forward untouched
and the next stage never executes. Both chapters leaned on one unstated
promise: threading partial functions through tagged carriers behaves the same
however you group the steps. This chapter states that promise as three
equations and turns it into checks. The moves are: the functor and monad
interface stated against Wadler's notation, map and bind over option with the
three laws pinned on fixed integers, the same shape over result with typed
errors and a counter proof that the failing path skips stages, the list monad
where bind becomes concatenation and nondeterminism becomes exact enumeration,
one bind spelling dispatched over several carrier types by a macro that
emulates the higher-kinded type and moves ownership under the tag, and
closures as context structs whose purity is exactly what the laws buy. Every
behavioral claim below is one of the 61 checks in the 4 samples of chapter 28
or a bibliographic line quoted from a canonical source fetched 2026-09-22.
The dsa book stays algorithm-first and never names a monad; here the theory is
the payload.

== the shape railway generalized

A functor is a carrier M with a map: given a plain function f from T to U,
map applies f to the payload and leaves the effect alone. A monad adds two
primitives to that. The constructor unit injects a plain value into the
carrier: some for option, ok for result, the one element list for lists. The
combinator bind threads a carrier through a kleisli arrow, a function k that
already returns a carrier: bind runs k on the payload when m carries one and
reproduces the effect of m otherwise. In notation, where >>= spells bind:

$ "unit"(a) >>= k = k(a) $

$ m >>= "unit" = m $

$ (m >>= k) >>= h = m >>= (lambda x. k(x) >>= h) $

Read them as: injecting then binding is just calling k, binding unit changes
nothing, and regrouping a chain of binds is free. The first law is what makes
unit an identity on the left, the second what makes it an identity on the
right, the third what lets you flatten a pipeline into one arrow or split it
into stages without changing behavior. All three date to the standard
formulation of Moggi's computational metalanguage carried into functional
programming by Wadler, cited below by name and edition.

#callout("note", "WHERE THE LAWS COME FROM", [Philip Wadler, "Monads for
functional programming", Marktoberdorf Summer School on Program Design
Calculi, NATO ASI Series F, Volume 118, Springer, August 1992, also in J.
Jeuring and E. Meijer, editors, Advanced Functional Programming, LNCS 925,
Springer, 1995. That paper states the three laws in exactly this
unit and bind form. The venue lines were verified at the author's page
fetched 2026-09-22; the paper text is cited by name and edition and the laws
are restated here in our own notation.])

The notation maps onto C with nothing exotic: constructors are inline
functions returning compound literals, a lambda is a static function whose
signature is T to carrier, and >>= is a function taking the carrier and a
function pointer.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*notation*], [*c realization*], [*this chapter*]),
  [$"unit"(a)$], [constructor: some(a), res_ok(a), ilist_unit(a)], [option, result, list],
  [$lambda x. k(x)$], [static function $T -> M$], [k_add3, stage_a, k_pair10],
  [$m >>= k$], [bind(m, k) by carrier], [opt_bind, res_bind, ilist_bind],
  [$M(T)$], [typedef struct with tag and payload], [opt, res, ilist],
)

One consequence worth pinning before any code: map needs no independent
definition. Applying f under the tag is binding the arrow that injects the
result of f, and the map equals bind check of this chapter's first sample
proves the two agree, 6 through 3x+1 landing on some 19 both ways. The
section's two numbers: 2 primitives generate the whole interface and 3
equations police them.

#diagram([the general shape: unit injects a value, bind threads a carrier
through a kleisli arrow, the three laws pin the contract], length: 13pt, {
  let box(x, y, w, h, t, fill) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, size: 6pt)
  }
  box(0.6, 3.0, 1.6, 0.8, [value t], luma(245))
  cdraw.line((2.2, 3.4), (3.4, 3.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((2.8, 3.72), [unit], size: 6pt)
  box(3.4, 2.9, 2.6, 1.0, [carrier of t], luma(235))
  cdraw.line((6.0, 3.4), (9.0, 3.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((7.5, 3.72), [bind], size: 6pt)
  cdraw.content((7.5, 2.5), [k takes t, returns a carrier], size: 6pt)
  box(9.0, 2.9, 2.6, 1.0, [carrier of u], luma(235))
  cdraw.line((1.4, 3.85), (1.4, 4.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.4, 4.6), (10.3, 4.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((10.3, 4.6), (10.3, 3.95), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((5.85, 4.88), [map f is bind with unit after f], size: 6pt)
})

== map and bind over option

The carrier is the two field struct from the railway chapter: a bool tag and
an int payload, payload unread when the tag is false. Equality, map, and bind
fit in 19 lines, and the shape of bind is the whole story: the empty case
reproduces the effect, the full case delegates to k.

#listing("math/samples/src/Ch28/option.c", first: 33, last: 51, caption: [
  the option carrier: equality, map lifting a plain function, bind threading
  a kleisli arrow])

The kleisli arrows are plain static functions, including one partial arrow
that returns none for nonpositive inputs, and one counted arrow so a check
can prove a bind really did not call it.

#listing("math/samples/src/Ch28/option.c", first: 57, last: 80, caption: [
  the fixture arrows: total, partial, and counted kleisli functions])

The dry run: the left identity fixture is some 7 through k = +3, and both
sides land on some 10, one by injecting then binding, one by just calling
k(7). The right identity fixture is some 5 and none through the unit arrow,
both unchanged. The associativity fixture is some 2 through k = 10x then
h = -5: grouped left, 2 binds to some 20 and 20 binds to some 15; grouped
right, x = 2 runs k(2) = some 20 then h(20) = some 15 inside the arrow, and
the outer bind lands on the same some 15. The failing fixture is some -3
through the partial arrow: k(-3) is none, so both groupings are none and the
h counter reads 0 invocations, while the success fixture 4 through the same
pair reads exactly 1.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*law*], [*fixture*], [*left side*], [*right side*]),
  [left identity], [some 7, k = +3], [some 10], [some 10],
  [right identity], [some 5], [some 5], [some 5],
  [right identity], [none], [none], [none],
  [associativity], [some 2, k = 10x, h = -5], [some 15], [some 15],
  [associativity], [none], [none], [none],
  [associativity], [some -3, partial k], [none, h ran 0], [none, h ran 0],
)

#listing("math/samples/src/Ch28/option.c", first: 92, last: 121, caption: [
  the three laws as checks: fixed integers on both sides, the counter proving
  the skipped call])

The two numbers of the section: h runs 1 time on the success path and 0 times
on the failing path through the identical bind chain.

#diagram([bind over option: the tag decides, k runs only under some], length: 13pt, {
  cdraw.rect((0.4, 5.2), (2.4, 6.0), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((1.4, 5.6), [m : opt], size: 6pt)
  cdraw.line((1.4, 5.2), (1.4, 4.8), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((0.7, 4.1), (2.1, 4.8), fill: luma(245), stroke: luma(100), radius: 0.02)
  cdraw.content((1.4, 4.45), [has?], size: 6pt)
  cdraw.line((1.4, 4.1), (1.4, 3.5), stroke: luma(60), mark: (end: ">"))
  cdraw.content((1.78, 3.8), [true], size: 6pt)
  cdraw.rect((0.2, 2.6), (2.6, 3.5), fill: luma(205), stroke: luma(100), radius: 0.02)
  cdraw.content((1.4, 3.05), [k(v)], size: 6pt)
  cdraw.line((1.4, 2.6), (1.4, 2.0), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((0.2, 1.2), (2.6, 2.0), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((1.4, 1.6), [k(v) : opt], size: 6pt)
  cdraw.line((2.1, 4.45), (4.6, 4.45), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.6, 4.45), (4.6, 2.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((4.6, 1.6), [none], size: 6pt)
  cdraw.content((7.3, 3.15), [false: k never runs], size: 6pt)
  cdraw.rect((3.4, 1.2), (5.8, 2.0), fill: luma(245), stroke: luma(140), radius: 0.02)
})

#callout("verify", "RUN THE LAWS", [The laws are not prose here, the three
of them run as 7 of the 14 checks in option.c. Rerun with `pwsh
-NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/math/samples/src -Chapter Ch28` and read the ok lines: each
law check prints the exact integers it compared.])

== result with typed errors

The result carrier from the railway chapter carries either a long payload or
a typed error tag in an anonymous union, with the enum pinned to a one byte
underlying type by static_assert. map and bind have exactly the option shape
with one addition: the error that passes through is the error that comes out,
byte for byte.

#listing("math/samples/src/Ch28/result.c", first: 52, last: 64, caption: [
  map and bind over result: the failing case returns m itself])

The pipeline fixture is three counted stages: a triples rejecting inputs
above 400 with E_RANGE, b subtracts 7 rejecting zero with E_ZERO, c squares
rejecting negatives with E_NEG.

#listing("math/samples/src/Ch28/result.c", first: 91, last: 117, caption: [
  three kleisli stages with call counters and the chained pipeline])

The dry run: 12 enters, a makes 36, b makes 29, c makes 841, and the counter
triples read (1, 1, 1). The input 500 dies at a with E_RANGE and the counters
read (1, 0, 0): b and c never ran. The input 0 triples to 0, b rejects it
with E_ZERO, c never ran. The input 2 makes 6 then -1, and c rejects the
negative with E_NEG after all three stages ran. A final check binds an
E_RANGE error through stages b and c directly and reads the tag out the far
end unchanged with all counters still flat.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*input*], [*a: 3x*], [*b: -7*], [*c: square*], [*outcome, counters*]),
  [12], [36], [29], [841], [ok 841, (1,1,1)],
  [500], [E_RANGE], [skipped], [skipped], [E_RANGE, (1,0,0)],
  [0], [0], [E_ZERO], [skipped], [E_ZERO, (1,1,0)],
  [2], [6], [-1], [E_NEG], [E_NEG, (1,1,1)],
)

#listing("math/samples/src/Ch28/result.c", first: 159, last: 192, caption: [
  the propagation proof: per stage counters pin exactly which stages ran])

The two numbers: 841 against E_RANGE on the same three stage chain, and
downstream counters (1,1,1) against (0,0).

#callout("pitfall", "THE SHORT CIRCUIT IS LOAD BEARING", [Returning m itself
on the failing case, rather than calling k or inventing a default error, is
what makes right identity hold for errors and what carries the first error's
tag to the end verbatim. A bind that "recovers" inside the combinator breaks
both checks: the tag changes and the counter proves a stage ran that the
railway promised to skip.])

#diagram([the result railway: an error at any stage drops to the dashed rail
and later stages never run], length: 13pt, {
  let stage(x, t) = {
    cdraw.rect((x, 3.6), (x + 2.8, 4.6), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + 1.4, 4.1), t, size: 6pt)
  }
  stage(0.4, [a: 3x])
  stage(4.2, [b: -7])
  stage(8.0, [c: square])
  cdraw.line((1.7, 5.0), (1.7, 4.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((1.7, 5.25), [12], size: 6pt)
  cdraw.line((3.2, 4.1), (4.2, 4.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((3.7, 4.45), [36], size: 6pt)
  cdraw.line((7.0, 4.1), (8.0, 4.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((7.5, 4.45), [29], size: 6pt)
  cdraw.line((10.8, 4.1), (11.9, 4.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((11.35, 4.45), [841], size: 6pt)
  cdraw.line((1.7, 3.6), (1.7, 1.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.7, 1.5), (10.4, 1.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((10.4, 1.5), (10.4, 2.2), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((5.4, 1.1), [b and c skipped, their counters stay 0], size: 6pt)
  cdraw.rect((8.4, 2.2), (12.4, 3.0), fill: luma(245), stroke: luma(140), radius: 0.02)
  cdraw.content((10.4, 2.6), [typed error out], size: 6pt)
})

== the list monad

For lists the effect is plurality: a list of T stands for every value it
holds. unit is the one element list, map applies f pointwise, and bind runs
k on every element and concatenates the outcomes in order. That last clause
is where the list monad earns its other name, the nondeterminism monad: a
kleisli arrow that returns two outcomes per input doubles the possibilities,
and bind is the enumeration.

#listing("math/samples/src/Ch28/list.c", first: 54, last: 71, caption: [
  map pointwise and bind as ordered concatenation over a fixed capacity
  array])

The arrows: k_pair10 branches every input into the pair {x, x + 10},
k_die_b pairs a fixed die face with every face 1 to 3 of a second die coded
as 10a + b, and k_keep_sum3 is the partial arrow that keeps a pair only when
its two faces sum to a multiple of 3, which is filtering expressed as bind.

#listing("math/samples/src/Ch28/list.c", first: 80, last: 108, caption: [
  the fixture arrows: branching, dice enumeration, and filtering as a partial
  arrow])

The dry run: the list {2, 3} through k_pair10 concatenates {2, 12} then
{3, 13} into {2, 12, 3, 13}, order pinned. Associativity with h = double:
grouped left, the branch list maps pointwise to {4, 24, 6, 26}; grouped
right, each x binds through its own k then h, producing {4, 24} then
{6, 26}, and the concatenation is the same list. The dice fixture enumerates
all 9 ordered pairs of two three faced dice, 11 through 33, and the sum
filter keeps exactly 12, 21, and 33.

#listing("math/samples/src/Ch28/list.c", first: 124, last: 165, caption: [
  the laws with array equality, then the 9 pair enumeration and the 3
  survivors])

The two numbers: 9 pairs enumerated from 3 times 3 faces, 3 survive the
filter.

#diagram([the list monad as a tree: two dice enumerate 9 ordered pairs, the
3 darkened leaves survive the sum filter], length: 13pt, {
  cdraw.rect((6.6, 8.2), (11.8, 9.0), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((9.2, 8.6), [bind(die a, k_die_b)], size: 6pt)
  let anode(x, t) = {
    cdraw.rect((x, 6.4), (x + 1.6, 7.2), fill: luma(245), stroke: luma(100), radius: 0.02)
    cdraw.content((x + 0.8, 6.8), t, size: 6pt)
  }
  anode(6.9, [a = 1])
  anode(8.7, [a = 2])
  anode(10.5, [a = 3])
  cdraw.line((8.0, 8.2), (7.7, 7.2), stroke: luma(100))
  cdraw.line((8.7, 8.2), (9.5, 7.2), stroke: luma(100))
  cdraw.line((9.4, 8.2), (11.3, 7.2), stroke: luma(100))
  let leaf(x, t, dark) = {
    cdraw.rect((x, 4.8), (x + 1.5, 5.6), fill: if dark { luma(205) } else { luma(245) }, stroke: luma(100), radius: 0.02)
    cdraw.content((x + 0.75, 5.2), t, size: 6pt)
  }
  let xs = (3.0, 4.7, 6.4, 8.1, 9.8, 11.5, 13.2, 14.9, 16.6)
  let labels = ([11], [12], [13], [21], [22], [23], [31], [32], [33])
  let darks = (false, true, false, true, false, false, false, false, true)
  for i in range(9) {
    leaf(xs.at(i), labels.at(i), darks.at(i))
    let ax = if i < 3 { 7.7 } else if i < 6 { 9.5 } else { 11.3 }
    cdraw.line((ax, 6.4), (xs.at(i) + 0.75, 5.6), stroke: luma(140))
  }
  cdraw.content((10.5, 4.2), [faces sum to a multiple of 3: 12, 21, 33], size: 6pt)
})

== one spelling, many types

Everything above hardcodes the payload type per file, which is honest C but
repetitive, and the repetition hides the interesting claim: map and bind
mean the same thing over int, over a rational, over any payload. C has no
type constructors over types, so the corpus answer is two moves. A macro
stamps the carrier, unit, map, bind, equality, and a take for a named
payload type, and `_Generic` reads the carrier type off an expression at
compile time to pick the stamped combinator, one BIND spelling for every
instantiation.

#listing("math/samples/src/Ch28/dispatch.c", first: 56, last: 106, caption: [
  the macro that stamps the option monad for a payload type, the two
  instantiations, and the `_Generic` dispatch])

The second instantiation carries exact rationals, sign in the numerator,
denominator positive, fully reduced by a gcd loop, so the law checks run on
fractions with no floating point in sight: 1/2 through multiply by 3/2 is
3/4 on both sides of left identity, 5/4 through unit stays 5/4, and both
groupings of multiply by 3/2 then 5/3 land on 5/4. The dispatched map gives
3x+1 over int, 6 landing on 19, and multiply by 3/4 over frac, 1/3 landing
on 1/4.

Ownership rides in the same macro. take moves the payload out of the carrier
and flips the tag to false: the first take of a box holding 15/12 hands back
5/4 and empties the box, a second take fails, and the box refills and moves
again. The tag is the borrow discipline: a spent carrier is visibly spent,
and reading the payload requires the guard.

#listing("math/samples/src/Ch28/dispatch.c", first: 223, last: 259, caption: [
  the same BIND and FMAP spellings checking the laws over both
  instantiations])

#listing("math/samples/src/Ch28/dispatch.c", first: 261, last: 275, caption: [
  ownership transfer: take hands the payload out once, the guard flips, the
  box refills])

The two numbers: one macro line instantiates 2 carriers, and 15/12 moves out
exactly once as 5/4.

#diagram([one macro stamps the monad per payload type, `_Generic` picks the
combinator, take moves the payload out under the tag], length: 13pt, {
  cdraw.rect((0.2, 7.0), (7.2, 7.8), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((3.7, 7.4), [DEFINE_MONAD(NAME, T)], size: 6pt)
  cdraw.rect((0.2, 5.2), (2.8, 6.0), fill: luma(245), stroke: luma(100), radius: 0.02)
  cdraw.content((1.5, 5.6), [bint over int], size: 6pt)
  cdraw.rect((3.8, 5.2), (6.6, 6.0), fill: luma(245), stroke: luma(100), radius: 0.02)
  cdraw.content((5.2, 5.6), [bfrac over frac], size: 6pt)
  cdraw.line((2.5, 7.0), (1.5, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.5, 7.0), (5.2, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.5, 3.4), (6.5, 4.2), fill: luma(245), stroke: luma(60), radius: 0.02)
  cdraw.content((3.5, 3.8), [BIND dispatch], size: 6pt)
  cdraw.line((1.5, 4.2), (1.5, 5.2), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((5.2, 4.2), (5.2, 5.2), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.rect((8.2, 5.2), (12.2, 6.0), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((10.2, 5.6), [has = 1, 15/12], size: 6pt)
  cdraw.line((12.2, 5.6), (13.2, 5.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((12.7, 6.3), [take], size: 6pt)
  cdraw.rect((13.2, 5.2), (15.2, 6.0), fill: luma(245), stroke: luma(100), radius: 0.02)
  cdraw.content((14.2, 5.6), [has = 0], size: 6pt)
  cdraw.content((11.7, 4.7), [5/4 moves out once], size: 6pt)
})

== closures, purity, and the price of state

Kleisli arrows so far were plain functions. A closure is a function pointer
plus the environment it carries, one struct, and the environment is where C
programmers get to break the laws. Three closures run the gamut: a pure one
with a null environment that doubles {1, 2, 3} into {2, 4, 6}, an
accumulator whose mutable sum reports running totals {1, 3, 6}, and a
read-only threshold that keeps {5, 9, 6} from the 8 element fixture.

#listing("math/samples/src/Ch28/dispatch.c", first: 120, last: 150, caption: [
  the closure struct and three environments: null, mutable, read-only])

The trap demo gives two arrows a shared counter that both read and bump.
Grouped left over {10, 20}, both k calls run before any h, so h sees the
counter at 2 then 3 and the list is {12, 24}. Grouped right, each k is
immediately followed by its h, so h sees 1 then 3 and the list is {11, 25}.
Same 4 calls, same final counter, different lists: associativity is gone,
and the exact numbers show the damage is evaluation order, not arithmetic.

#listing("math/samples/src/Ch28/dispatch.c", first: 189, last: 221, caption: [
  single outcome bind, the per element right side, and the two impure
  arrows])

#listing("math/samples/src/Ch28/dispatch.c", first: 299, last: 317, caption: [
  the associativity break as checks: 12,24 against 11,25 on the same 4
  calls])

The two numbers: {12, 24} against {11, 25}, the same computation regrouped.
That is the whole contract in one fixture: the laws buy regrouping, staging,
and inlining for arrows that are functions of their argument alone, and
chapter #xref-to("math", "pipeline") builds effectful pipelines on exactly
that guarantee.

#callout("warning", "THE LAWS ASSUME PURE ARROWS", [A kleisli arrow that
reads or writes shared state is not a function of its argument, and none of
the three laws survive it: the impure fixture passes every arithmetic check
while producing different lists under regrouping. Reach for a mutable
environment when the effect is the point, as with the accumulator trace, and
keep the arrows pure when the pipeline shape is the point.])

#diagram([evaluation order made visible: the same 4 calls in a different
order give 12,24 against 11,25], length: 13pt, {
  let row(y, title, labels) = {
    cdraw.content((6.6, y + 1.4), title, size: 6pt)
    let xs = (0.3, 3.6, 6.9, 10.2)
    for i in range(4) {
      cdraw.rect((xs.at(i), y), (xs.at(i) + 2.7, y + 0.8), fill: luma(245), stroke: luma(100), radius: 0.02)
      cdraw.content((xs.at(i) + 1.35, y + 0.4), labels.at(i), size: 6pt)
      if i < 3 {
        cdraw.line((xs.at(i) + 2.7, y + 0.4), (xs.at(i) + 3.3, y + 0.4), stroke: luma(60), mark: (end: ">"))
      }
    }
  }
  row(5.6, [grouped left: (m >>= k) >>= h], ([k(10), sc 0], [k(20), sc 1], [h(10), sc 2], [h(21), sc 3]))
  cdraw.content((14.7, 6.0), [list {12, 24}], size: 6pt)
  row(3.2, [grouped right: m >>= (x -> k(x) >>= h)], ([k(10), sc 0], [h(10), sc 1], [k(20), sc 2], [h(22), sc 3]))
  cdraw.content((14.7, 3.6), [list {11, 25}], size: 6pt)
  cdraw.content((7.5, 2.4), [same 4 calls, same final counter, different lists], size: 6pt)
})

sources: Philip Wadler, "Monads for functional programming", in M. Broy,
editor, Marktoberdorf Summer School on Program Design Calculi, NATO ASI
Series F: Computer and systems sciences, Volume 118, Springer Verlag,
August 1992, also in J. Jeuring and E. Meijer, editors, Advanced Functional
Programming, LNCS 925, Springer, 1995, venue lines verified at
homepages.inf.ed.ac.uk/wadler/topics/monads.html, fetched 2026-09-22, paper
text cited by name and edition, the three laws restated in our own notation,
our own words and code throughout. The monad-as-semantics lineage is
Eugenio Moggi, "Notions of computation and monads", Information and
Computation 93(1), 1991, cited by name only. This chapter is not mapped to
mml-book
draft 2024-01-15 and no mml pages were read. All C23 features used
(constexpr, `_Generic`, anonymous unions, enum with fixed underlying type,
static_assert, [[nodiscard]], nullptr, compound literals, auto) are
exercised and machine verified by the sample gate on this machine, clang
23.1.1 msvc-target, 2026-09-22. Sample behavior verified by `pwsh
-NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src
-Ch28`, 61 checks in chapter 28 of the math suite, format and asan legs
clean.
