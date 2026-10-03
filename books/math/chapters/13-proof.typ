#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= logic, sets, and proof

The discrete half of this book starts here: propositions as bit patterns
a machine can exhaust, quantifiers as bounded loops that return evidence,
sets and relations as masks and boolean matrices, functions with
injections and the pigeonhole principle, induction written as a loop
invariant, and invariants that must survive mutation. Every behavioral
claim below is one of the 45 checks in the 4 samples of chapter 13 or a
sentence quoted from a canonical source fetched 2026-09-21. The dsa
book's #xref-to("dsa", "analysis") chapter measures what algorithms cost;
this chapter builds the proof patterns that establish what a program is
true of, with counting left to #xref-to("dsa", "combinatorics") and to
the next chapter.

The one idea that carries all six sections: a finite mathematical claim
is data. A proposition over 3 variables is 8 bits, a subset of a fixed
universe is one integer, a relation on 5 points is 5 integers, a
function between finite sets is a short array. Once the claim is data,
checking it is a loop, and a proof by exhaustion is a mask comparison.

== propositions as bit patterns

A proposition is a claim with a truth value. Connectives build compound
propositions: $not p$, $p and q$, $p or q$, $p xor q$, implication
$p -> q$, biconditional $p <-> q$. Over $k$ variables the truth table has
$2^k$ rows, and stacking the output column of row $i$ into bit $i$ of an
integer turns the whole table into one machine word. Variable $j$ reads
bit $(k - 1 - j)$ of the row index: with $(p, q, r)$ and $k = 3$, row 5
is $101$, so $p$ holds and $r$ holds.

Every connective becomes one bit operation on the whole vector at once.
With `p` = `0xF0`, `q` = `0xCC`, `r` = `0xAA` over the 8-row universe:

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*connective*], [*vector form*], [*mask*], [*true rows*]),
  [$not p$], [`~p & m`], [`0x0F`], [4],
  [$p and q$], [`p & q`], [`0xC0`], [2],
  [$p or q$], [`p | q`], [`0xFC`], [6],
  [$p xor q$], [`p ^ q`], [`0x3C`], [4],
  [$p -> q$], [`(~p | q) & m`], [`0xCF`], [6],
  [$p <-> q$], [`~(p ^ q)`], [`0xC3`], [4],
)

Implication is the one worth a second look: $p -> q$ is $not p or q$,
false in exactly the rows where the antecedent holds and the consequent
does not. Over two variables the vector is `0xB`: true in 3 rows of 4,
false only at $(p, q) = (1, 0)$. That single false row is why $xor$ and
$->$ are different connectives even though both feel like "differs".

A tautology is now a mask comparison: the vector is all ones over the
universe, $v & m == m$. A contradiction is the zero vector. De Morgan
$not (p and q) <-> not (p or q)$, distributivity, the contrapositive
$ (p -> q) <-> (not q -> not p)$, and modus ponens each collapse to
eight-bit checks, which is what proof by exhaustion looks like when the
universe is 8 rows.

#listing("math/samples/src/Ch13/truthvec.c", first: 50, last: 62, caption: [truthvec.c, base vectors and the connective masks over the 8-row universe])

#listing("math/samples/src/Ch13/truthvec.c", first: 64, last: 74, caption: [truthvec.c, named laws checked against every row at once])

The dry run: the implication column below is the mask `0xCF` built row
by row. Row 7 is $(1,1,1)$, antecedent true and consequent true, so the
row reads true. Row 5 is $(1,0,1)$: $p$ holds, $q$ fails, so the row is
false, and row 4 $(1,0,0)$ is the other false row. Six true rows, two
false rows, matching `popcount(0xCF) = 6`.

#diagram([truth vector of implication p -> q over the 8-row universe, false only where p holds and q fails], length: 13pt, {
  let cols = ([i], [p], [q], [r], [p -> q])
  for (j, h) in cols.enumerate() {
    cdraw.content((j * 1.1 + 0.55, 4.7), h, size: 6pt)
  }
  let rows = ((7, 1, 1, 1, 1), (6, 1, 1, 0, 1), (5, 1, 0, 1, 0), (4, 1, 0, 0, 0),
    (3, 0, 1, 1, 1), (2, 0, 1, 0, 1), (1, 0, 0, 1, 1), (0, 0, 0, 0, 1))
  for (ri, row) in rows.enumerate() {
    let y = 4.2 - ri * 0.5
    for (j, v) in row.enumerate() {
      let hot = v == 1
      cdraw.rect((j * 1.1, y), (j * 1.1 + 1.0, y + 0.42),
        fill: if hot { luma(235) } else { luma(255) },
        stroke: if (j == 4 and not hot) { luma(60) } else { luma(140) }, radius: 0.02)
      cdraw.content((j * 1.1 + 0.5, y + 0.21), str(v), size: 6pt)
    }
  }
  cdraw.content((7.1, 2.4), [false rows have p = 1, q = 0], size: 6pt)
})

#callout("pitfall", "implication is not xor", [$p -> q$ fails only at $(p, q) = (1, 0)$, two false rows out of 8 with $r$ free, while $p xor q$ fails in 4. treating "differs" as "implies" in a bitmask flag test inverts exactly the rows where both flags are set. the census in truthvec.c is sharper still: of the 16 binary connectives, 1 is a tautology, 1 a contradiction, 4 ignore one variable ($p$, $q$, $not p$, $not q$), and only 10 depend on both.])

== quantifiers as bounded loops

The quantifiers $forall x, P(x)$ and $exists x, P(x)$ range over a
domain. On a fixed finite domain each is a loop, and the honest loop
returns evidence with its bit: a failing $forall$ returns the first
counterexample, a passing $exists$ returns the first witness. A claim
and its negation are then the same loop read two ways, the duality
$not (forall x, P(x)) <-> exists x, not P(x)$.

The workhorse example: over the domain 1 to 100, does $x^2 > 50$ hold
for all $x$? The $forall$ scan fails immediately at $x = 1$, the dual
$exists$ scan stops at the first witness $x = 8$, and the census says 93
of 100 rows satisfy the predicate. The boundary pair is the two-number
play: $7^2 = 49$ misses, $8^2 = 64$ clears, so the witness is 8.

#listing("math/samples/src/Ch13/truthvec.c", first: 105, last: 130, caption: [truthvec.c, a for-all that fails with counterexample 1 and its dual exists with witness 8])

Quantifier order is not free. Over $Z_4$: $forall x exists y, y = x + 1$
holds, because the witness $y$ may depend on $x$. Swap the prefixes and
$exists y forall x, y = x + 1$ fails: every fixed $y$ candidate is
broken by some $x$, and the sample pins the first breaker of each, $x$
values 0, 1, 0, 0 for $y = 0, 1, 2, 3$. Dependent choice is exactly
what the inner loop of a nested scan expresses.

The strongest loop in the file is a bounded Goldbach check: every even
$n$ from 4 to 100 is a sum of two primes. The outer $forall$ spans 49
values of $n$, and the inner $exists$ carries the smallest witness pair,
$4 = 2 + 2$, $6 = 3 + 3$, up to $98 = 19 + 79$.

#listing("math/samples/src/Ch13/truthvec.c", first: 171, last: 194, caption: [truthvec.c, a bounded for-all whose every instance carries a witness pair])

The dry run: for $n = 98$ the inner scan tries $a = 2$ ($98 - 2 = 96$,
not prime), walks up through $a = 19$ where $79$ is prime, and records
$19 + 79$. No even $n$ in range reaches the end of the scan without a
hit, so the $forall$ holds with 49 witnesses in hand.

#diagram([the exists scan with early exit: the first row that satisfies the predicate becomes the witness], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02, stroke: luma(100))
    cdraw.content((x + w / 2, y + h / 2), t, size: 6pt)
  }
  box(0.0, 2.8, 3.6, 0.9, [next x of 1..100])
  cdraw.line((1.8, 2.8), (1.8, 2.2), stroke: luma(100), mark: (end: ">"))
  box(0.0, 1.3, 3.6, 0.9, [x squared over 50?], fill: luma(205))
  cdraw.line((3.6, 1.75), (5.2, 1.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.4, 2.1), [yes], size: 6pt)
  box(5.2, 1.3, 3.2, 0.9, [witness x = 8])
  cdraw.line((1.8, 1.3), (1.8, 0.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((1.8, 0.25), [no: keep scanning], size: 6pt)
})

#callout("verify", "bounded is not general", [the goldbach check proves the statement for 4 to 100 and says nothing about the unbounded conjecture, which stays open. a for-all loop over a finite domain is a proof of exactly that domain, no wider. when this chapter says every, the universe of the every is the domain array in the sample.])

== sets as bitmasks and relations as matrices

Fix the universe ${{0, .., 7}}$. A set is one `uint8_t`, element $e$ is
bit $e$. Union is `|`, intersection is `&`, complement is xor with the
universe mask, difference is `a & ~b`, and $A subset.eq B$ is the single
expression `(a & ~b) == 0`. Cardinality counts set bits. With
$A = {{0, 2, 4, 6}}$ as mask `0x55` and $B = {{1, 2, 3}}$ as mask
`0x0E`: $abs(A) = 4$, $abs(B) = 3$, $abs(A union B) = 6$,
$abs(A inter B) = 1$, and inclusion-exclusion holds as $4 + 3 - 1 = 6$.

The power set of an 8-element universe is every mask from 0 to 255, and
two census facts fall out of one 256-iteration loop: exactly 128 masks
have even cardinality, and the sum of all cardinalities is $8 dot 2^7 =
1024$, because each element appears in exactly half the masks. Counting
the same total two ways is the set-theoretic version of the two-number
play.

#listing("math/samples/src/Ch13/sets.c", first: 111, last: 130, caption: [sets.c, the set algebra identities as bit operations with pinned masks])

#listing("math/samples/src/Ch13/sets.c", first: 132, last: 142, caption: [sets.c, power set census, each element in half of the 256 masks])

A binary relation on ${0, .., 4}$ is a boolean matrix, stored as one
mask per row: $a R b$ is bit $b$ of row $a$. The four defining
properties are short loops over the matrix:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*property*], [*statement*], [*loop shape*]),
  [reflexive], [$forall a: a R a$], [own bit set in every row],
  [symmetric], [$forall a, b: a R b <-> b R a$], [matrix equals its transpose],
  [antisymmetric], [$a R b and b R a -> a = b$], [no mirrored pair off the diagonal],
  [transitive], [$a R b and b R c -> a R c$], [triple loop, fail on any gap],
)

An equivalence relation is reflexive, symmetric, and transitive, and its
classes partition the universe. The sample's $R_1$ has rows
`07 07 07 18 18`: classes ${{0, 1, 2}}$ and ${{3, 4}}$, 13 pairs total, and
the class scan marks both classes while covering all 5 points exactly
once. The order $R_2$ with $b >= a$ is reflexive, antisymmetric, and
transitive but not symmetric: a partial order, 15 pairs. And $R_3$ =
${{(0,1), (1,2)}}$ is the warning case: antisymmetric yet not transitive,
since $0 R 1$ and $1 R 2$ hold while $0 R 2$ does not.

Warshall's algorithm repairs exactly that gap: for each intermediate $k$,
every row that reaches $k$ also takes in row $k$'s neighborhood. On
$R_3$ the closure adds the single missing pair $(0, 2)$, pair count 2 to
3, and the result is transitive. On $R_1$ the closure changes nothing:
transitive relations are already closed.

#listing("math/samples/src/Ch13/sets.c", first: 144, last: 164, caption: [sets.c, equivalence classes partition the 5-point universe])

#listing("math/samples/src/Ch13/sets.c", first: 166, last: 187, caption: [sets.c, partial order, the non-transitive warning case, and the warshall closure])

The dry run: the closure of $R_3$ walks intermediates $k = 0, 1, 2, 3, 4$.
At $k = 1$, row 0 has bit 1 set, so row 0 takes in row 1's mask `0x04`,
becoming `0x06`: the pair $(0, 2)$ appears. No other row reaches
anything new, so the loop ends with 3 pairs, transitive by exhaustion.

#diagram([the equivalence relation as a boolean matrix: two shaded blocks on the diagonal are the two classes], length: 13pt, {
  for a in range(5) {
    for b in range(5) {
      let inclass = (a <= 2 and b <= 2) or (a >= 3 and b >= 3)
      cdraw.rect((b * 0.8, 4.0 - a * 0.8), (b * 0.8 + 0.7, 4.7 - a * 0.8),
        fill: if inclass { if a <= 2 { luma(235) } else { luma(245) } },
        stroke: luma(140), radius: 0.02)
    }
  }
  cdraw.rect((0.0, 2.4), (2.3, 4.7), stroke: luma(60), radius: 0.02)
  cdraw.rect((2.4, 0.8), (3.9, 2.3), stroke: luma(60), radius: 0.02)
  cdraw.content((5.0, 4.3), [class {0,1,2}], size: 6pt)
  cdraw.content((5.0, 1.6), [class {3,4}], size: 6pt)
  cdraw.content((1.6, -0.4), [column b, row a, a R b shaded], size: 6pt)
})


== functions and the pigeonhole principle

A function $f$ from ${0, .., n-1}$ to ${0, .., m-1}$ is an array with
$f[i] < m$. It is injective when no two inputs share an output, a scan
over all pairs. It is surjective when the image has size $m$, a census
over outputs. Bijective is both, and a bijection on a finite set has a
two-sided inverse: composing with the inverse array yields the identity.

Composition $(f circle g)[i] = f[g[i]]$ is associative, which the
chapter states as prose and the sample checks on three fixed maps,
$(f circle g) circle h = f circle (g circle h)$ entry by entry on all 6
points.

The pigeonhole principle is the first counting theorem with teeth: a map
from $n + 1$ pigeons to $n$ holes cannot be injective, because
$n + 1$ outputs among $n$ holes force a repeat. Stated constructively it
is an algorithm: scan pairs, return the first collision. For the fixed
map {1, 3, 4, 4, 5, 0, 0} from 7 pigeons to 6 holes, the scan returns
the pair $(2, 3)$, both landing in hole 4, and the image misses hole 2:
not injective and not surjective in one pass.

#listing("math/samples/src/Ch13/functions.c", first: 73, last: 94, caption: [functions.c, the 7 into 6 map with the collision witness found by scan])

The dry run: the collision scan walks pairs in index order. It clears
the 6 pairs that start at pigeon 0 and the 5 that start at pigeon 1,
then stops on its 12th pair $(2, 3)$: both entries read 4, the witness
is in hand after 12 comparisons out of the 21 a full triangle would cost.

The average form is just as useful: 10 pigeons into 3 holes force some
hole to hold at least $ceil(10 slash 3) = 4$. The sample's fixed load
array {0, 1, 2, 0, 1, 2, 0, 1, 2, 0} has loads 4, 3, 3, the busiest hole
exactly at the ceiling, and the bound itself is a compile-time
`static_assert`.

Counting functions is where exact integers start to matter. There are
$m^n$ maps from an $n$-set to an $m$-set, so the set of maps from a
20-set to a 20-set has $20^20$ elements, a 27-digit number that needs
87 bits. `uint64_t` holds 64, so it wraps to
16345305773657554944. An `unsigned _BitInt(128)` holds the exact value,
and the sample computes it by 20 multiplications and compares against
the digit string parsed back in. The two numbers side by side are the
point of the section: 87 bits exact versus a 64-bit wrap that looks
plausible and is wrong.

#listing("math/samples/src/Ch13/functions.c", first: 143, last: 170, caption: [functions.c, exact 20^20 in a 128-bit integer and the falling product for injections])

The falling product $20 dot 19 dot .. dot 11 = 20! slash 10! =
670442572800$ counts the injections of a 10-set into a 20-set, and it
still fits in 64 bits: the boundary between counting that fits and
counting that does not sits inside one sample file.

#diagram([seven pigeons into six holes: the scan witness is the pair sharing hole 4], length: 13pt, {
  let f = (1, 3, 4, 4, 5, 0, 0)
  for h in range(6) {
    cdraw.rect((h * 1.3, 0.0), (h * 1.3 + 1.0, 0.9),
      fill: if h == 4 { luma(205) } else { luma(235) }, radius: 0.02,
      stroke: if h == 4 { luma(60) } else { luma(100) })
    cdraw.content((h * 1.3 + 0.5, 0.45), str(h), size: 6pt)
  }
  for i in range(7) {
    let x = i * 1.15 + 0.35
    cdraw.circle((x, 4.2), radius: 0.22, fill: luma(245), stroke: luma(100))
    cdraw.content((x, 4.2), str(i), size: 6pt)
    cdraw.line((x, 3.95), (f.at(i) * 1.3 + 0.5, 0.95),
      stroke: if i == 2 or i == 3 { luma(60) } else { luma(140) },
      mark: (end: ">"))
  }
  cdraw.content((5.2, -0.7), [f(2) = f(3) = 4, the scan witness], size: 6pt)
})

#callout("warning", "128-bit remainder with a runtime divisor", [on this toolchain `%` on `_BitInt(128)` with a divisor known only at runtime lowers to a compiler-rt `__umodti3` call that the msvc-linked build cannot resolve. a compile-time constant divisor is different: the compiler expands it to inline multiply-shift and the link stays clean. reducing a power of two is a mask either way: `v & ((1 << 64) - 1)` gives the low 64 bits with native instructions, and that is what the sample does. probed 2026-09-21 with the pinned clang 23: the runtime-divisor object carries an undefined `__umodti3`, the constant-divisor one does not.])

== induction as a loop invariant

Induction proves a claim $P(n)$ for all $n >= 0$ from two steps: the
base case $P(0)$, and the inductive step $P(k) -> P(k+1)$. The program
twin is exact. A loop that has finished $k$ iterations holds some state
satisfying an invariant, one more iteration preserves the invariant, and
when the loop exits at $k = n$ the invariant is the conclusion $P(n)$.
The `assert` at the loop top is the induction hypothesis, checked at
every rung instead of assumed.

The canonical run: $1 + 2 + .. + n = n(n+1) slash 2$. The loop adds $k$
then asserts the closed form $k(k+1) slash 2$ holds of the running sum,
100 times for one answer, $S(100) = 5050$, and 1000 times for
$S(1000) = 500500$. The odd-number identity
$1 + 3 + .. + (2n-1) = n^2$ gets the same treatment and lands on
$20^2 = 400$.

#listing("math/samples/src/Ch13/induction.c", first: 82, last: 96, caption: [induction.c, the gauss loop asserting the closed form at every rung])

C23 moves the base case to compile time: `static_assert` with a message
checks a constant claim before the program runs, and since C23 the
message is optional and the spelling without underscore is the
non-deprecated one, per the cppreference page fetched 2026-09-21.

#listing("math/samples/src/Ch13/induction.c", first: 27, last: 28, caption: [induction.c, compile-time base cases as static_assert with messages])

The other inductive staples ride the same pattern. The geometric sum
$1 + 2 + 4 + .. + 2^10 = 2^11 - 1 = 2047$ is asserted per exponent. The
divisibility claim $3 | 4^n - 1$ is an invariant on a running power:
$v = 4^n$ starts at 1 with $v mod 3 = 1$, and multiplying by 4 preserves
it because $4 = 1 (mod 3)$, checked for $n = 0$ to 15. Repeated squaring
computes $3^13 = 1594323$ and the plain loop agrees, two algorithms
proving the same arithmetic statement.

The dry run: after 3 iterations of the odd loop the sum is
$1 + 3 + 5 = 9 = 3^2$ and the assert holds, after 4 it is $16 = 4^2$.
Each rung is one instance of the same check, which is exactly why the
loop version of the proof is trusted: it fails loudly at the first rung
that would break the induction.

#diagram([induction as the loop: base case, preservation step, exit value], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02, stroke: luma(100))
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0.0, 2.0, 2.8, [base: S(0) = 0 holds])
  cdraw.line((2.8, 2.5), (3.6, 2.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.2, 2.8), [one more k], size: 6pt)
  box(3.6, 2.0, 3.2, [step: S(k) = k(k+1)/2 preserved], fill: luma(205))
  cdraw.line((6.8, 2.5), (7.6, 2.5), stroke: luma(100), mark: (end: ">"))
  box(7.6, 2.0, 2.8, [exit: S(100) = 5050])
  cdraw.content((5.2, 1.4), [assert at loop top is the hypothesis], size: 6pt)
  cdraw.line((5.2, 1.7), (5.2, 2.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
})

#callout("note", "where the dsa book meets this", [the #xref-to("dsa", "analysis") chapter uses loop invariants and amortized sums to reason about cost; this chapter builds the proof discipline itself and keeps every invariant assert-checked at each rung. the next chapter counts structures, and every count there is proved by the induction patterns fixed here.])

== invariants that survive mutation

An invariant is a claim about a data structure that every operation
must preserve. The chapter's final samples run fixed mutation sequences
over three structures born in the sections above and assert one
invariant after every single mutation, 13 asserts per sequence, zero
violations.

The first structure is the bitmask set with a parity counter kept
alongside: the invariant is `parity == popcount(mask) mod 2`. A fixed
sequence of 13 add, remove, and toggle operations, exactly one a no-op
(the remove of the absent element 7), ends at mask `0xE7` with 6
elements and parity 0, and the assert runs after each of the 13 steps.

#listing("math/samples/src/Ch13/induction.c", first: 147, last: 164, caption: [induction.c, the bitset parity invariant asserted after every mutation])

The second is a permutation under swaps. A swap of distinct entries
flips the permutation's sign, and the invariant is that the running
sign equals the sign recomputed from scratch by cycle decomposition.
The fixed sequence of 13 swaps, 4 of them self-swaps that change
nothing, ends at the permutation [6, 4, 0, 2, 7, 3, 1, 5] with sign $-1$,
and both methods agree after every step. This is the honest form of the
argument: the structure could drift, the fresh recomputation cannot.

#listing("math/samples/src/Ch13/induction.c", first: 166, last: 190, caption: [induction.c, permutation sign by running flip versus cycle decomposition])

The third is rotation on the fixed array [3, 1, 4, 1, 5, 9, 2, 6, 5]:
the multiset is unchanged by a rotation, so the sum 36 is invariant
across all 9 rotations, after which the array is restored to its
original order. Mutation changes arrangement, never membership.

The dry run: the bitset sequence starts empty, adds 3, 5, 6, removes 3,
toggles 1 twice, adds 1 back, removes absent 7, adds 7, adds 2, removes
5, adds 5, and finally toggles 0. Tracing the cardinalities gives
1, 2, 3, 2, 3, 2, 3, 3, 4, 5, 4, 5, 6, and each parity matches the
counter, ending at even. Every step had a witness, and the final state
matches the playground prediction bit for bit.

#diagram([before and after 13 mutations, the parity band asserted at each step], length: 13pt, {
  let bits = (1, 1, 1, 0, 0, 1, 1, 1)
  cdraw.content((0.0, 4.2), [start: mask 0x00, parity 0], size: 6pt)
  for (e, v) in bits.enumerate() {
    cdraw.rect((e * 0.62, 2.6), (e * 0.62 + 0.52, 3.6),
      fill: if v == 1 { luma(235) } else { luma(255) }, stroke: luma(140), radius: 0.02)
    cdraw.content((e * 0.62 + 0.26, 3.9), str(e), size: 6pt)
  }
  cdraw.content((6.6, 3.1), [end: mask 0xE7], size: 6pt)
  cdraw.content((3.5, 1.7), [13 ops: add, remove, toggle], size: 6pt)
  cdraw.rect((0.0, 0.0), (10.2, 0.9), fill: luma(205), radius: 0.02, stroke: luma(60))
  cdraw.content((5.1, 0.45), [parity == popcount mod 2, 13 asserts, 0 fails], size: 6pt)
})

With propositions, quantifiers, sets, relations, functions, induction,
and invariants in hand as data plus loops, the next step is counting
the structures themselves, which is #xref-to("math", "combinatorics").

sources: Hammack, Book of Proof, 3rd ed., 2018, and Rosen, Discrete
Mathematics and Its Applications, 8th ed., 2019, cited by name and
edition for the definitions of connectives, quantifiers, sets,
relations, functions, induction, and the pigeonhole principle, restated
here in our own words and verified by the checks below (the former
people.vcu.edu hosting of the open Hammack text redirected to a
university landing page on access 2026-09-21, so no page text is
quoted). cppreference, "static_assert declaration",
en.cppreference.com/w/c/language/static_assert, fetched 2026-09-21:
`static_assert(expression, message)` since C23, the message optional
since C23, `_Static_assert` the deprecated spelling kept for
compatibility. ISO/IEC 9899:2024 draft N3220 (C23) cited by name as the
authority for bit-precise integer types `_BitInt(N)`. Probed on this
machine the same day: `_BitInt(128)` multiply, shift, and mask link
cleanly under the pinned clang 23 with the MSVC toolset, while `%`
with a runtime divisor lowers to a compiler-rt `__umodti3` call that
fails the link (a constant divisor expands to multiply-shift and links),
so the sample masks by `2^64 - 1` instead, and `<stdbit.h>` is absent from the
toolset headers, so popcount is the clear-lowest-bit loop. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/math/samples/src -Chapter Ch13`, 45 checks in chapter
13 of the math suite, format leg clean, zero failures.
