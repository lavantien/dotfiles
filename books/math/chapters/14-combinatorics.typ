#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= combinatorics

Counting is arithmetic with structure, and the structure is what makes a count trustworthy: the product rule composes independent choices, the binomial coefficient collapses orderings that do not matter, and every identity in this chapter is a statement that two different counting arguments return the same integer. The route runs through the sum and product rules as exact integer code paths, permutations and combinations built by the Pascal recurrence with the uint64 overflow boundary pinned and the wide ladder moved onto C23 `_BitInt`, the binomial theorem verified against schoolbook expansion, inclusion-exclusion with the derangement ladder walking into $n!/e$, linear recurrences from Fibonacci to the Tower of Hanoi with their closed forms pinned beside them, generating functions as exact coefficient arithmetic, and finally the bridge where counting becomes probability. Every behavioral claim below is one of the 60 checks in the 4 samples of chapter 14 or a sentence quoted from the mml-book draft 2024-01-15 anchor sheet and canonical references fetched 2026-09-21. Where #xref-to("dsa", "combinatorics") counts to bound algorithm work, this chapter is the theory underneath: what the identities are and why they hold in exact arithmetic.

== the sum and product rules as code

Definition first. The product rule says a choice made in $k$ independent stages with $n_i$ options at stage $i$ has $n_1 n_2 dots.c n_k$ outcomes, the size of a cartesian product. The sum rule says mutually exclusive cases add: if $A$ and $B$ are disjoint then $|A union B| = |A| + |B|$. Both are theorems about finite sets, and both run as plain loops: an odometer for the product rule, a bucket counter for the sum rule.

The mml book's probability space of section 6.1 is built on exactly these objects [printed pp 172-178 / pdf pp 178-184]: the sample space $Omega$ is "the set of all possible outcomes of the experiment", and two successive coin tosses give $Omega = {h h, t t, h t, t h}$, four outcomes because the product rule composes two 2-element stages [printed p 175 / pdf p 181]. Example 6.1 runs the same construction at a funfair: draw a coin with replacement from a bag of USA `$` and UK `£` coins where "a draw returns at random a \$ with probability 0.3", and let $X$ count dollars [printed p 176 / pdf p 182]. The lookup table eqs (6.1)-(6.4) maps $Omega = {(\$, \$), (\$, £), (£, \$), (£, £)}$ onto target states $cal(T) = {0, 1, 2}$.

The dry run: the 4 outcomes of $Omega$ land on 3 states, and the pre-image sizes eq (6.8) are 1, 2, 1.

+ `($,$)` maps to 2: one outcome, so the pre-image of state 2 has size 1.
+ `($,£)` and `(£,$)` both map to 1: pre-image size 2.
+ `(£,£)` maps to 0: pre-image size 1, and $1 + 2 + 1 = 4$ closes the count.

Those sizes 1, 2, 1 are row 2 of Pascal's triangle, which is where the next two sections are headed. Weight each outcome by its draw probability, held exactly as the rational $3/10$, and the numerators of eqs (6.5)-(6.7) fall out as $7 dot 7 = 49$, $3 dot 7 + 7 dot 3 = 42$, $3 dot 3 = 9$ over the common denominator 100, summing to exactly $100/100$.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*outcome*], [*X*], [*weight*], [*numerator*]),
  [(\$, \$)], [2], [$3 dot 3$], [9/100],
  [(\$, £), (£, \$)], [1], [$3 dot 7$ each], [42/100],
  [(£, £)], [0], [$7 dot 7$], [49/100],
)

#listing("math/samples/src/Ch14/counting.c", first: 74, last: 103, caption: [counting.c, example 6.1 as pure counting: 4 outcomes, pre-image sizes 1, 2, 1, then the same outcomes weighted exactly as the rational 3/10])

The play: the sample space has 4 outcomes but the target space has 3 states, and the 1, 2, 1 multiplicity between them is already a binomial row. The sum rule on subset sizes says the same thing one level up: the 16 subsets of a 4-element set split $1 + 4 + 6 + 4 + 1$ by cardinality, each bucket counted by bitmask scan (checks 4 and 5).

#callout("pitfall", "count the right space", [
  the two classic counting bugs are both space bugs: enumerating ordered tuples when the question wants unordered (every hand counted 5! = 120 times), and forgetting that the sum rule needs disjointness. the fix is mechanical, enumerate the sample space by odometer or bitmask, bucket by the property asked, and let the loop disagree with the formula until they agree for the right reason.
])

#diagram([the example 6.1 mapping, 4 outcomes of the product space collapsing onto 3 states with pre-image sizes 1, 2, 1], length: 13pt, {
  let outc(x, y, t) = {
    cdraw.rect((x, y), (x + 2.2, y + 0.9), fill: luma(235), radius: 0.02, stroke: luma(100))
    cdraw.content((x + 1.1, y + 0.45), t, size: 6pt)
  }
  let st(x, y, t) = {
    cdraw.rect((x, y), (x + 2.6, y + 1.2), fill: luma(245), radius: 0.02, stroke: luma(100))
    cdraw.content((x + 1.3, y + 0.62), t, size: 6pt)
  }
  outc(0.4, 4.2, [(\$, \$)])
  outc(0.4, 2.9, [(\$, £)])
  outc(0.4, 1.6, [(£, \$)])
  outc(0.4, 0.3, [(£, £)])
  st(6.0, 3.6, [X = 2, size 1])
  st(6.0, 1.8, [X = 1, size 2])
  st(6.0, 0.0, [X = 0, size 1])
  cdraw.line((2.6, 4.65), (6.0, 4.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.6, 3.35), (6.0, 2.4), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.6, 2.05), (6.0, 2.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.6, 0.75), (6.0, 0.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.2, 5.5), [product rule: 2 x 2 = 4 outcomes], size: 6pt)
})

== permutations and combinations

An ordered selection of $k$ from $n$ is a permutation count, $P(n, k) = n (n-1) dots.c (n-k+1) = n! \/ (n-k)!$. Forgetting order divides out the $k!$ orderings of each selection and leaves the binomial coefficient $binom(n, k) = n! \/ (k! (n-k)!)$.

The factorial ladder is the first thing to pin because it sets every width decision after it: $20! = 2432902008176640000$ has 62 bits and is the last exact factorial in uint64, while $21! = 51090942171709440000$ needs 66 bits and wraps to $14197454024290336768$ (checks 1 and 2). Unsigned wraparound is defined behavior, the mod $2^64$ arithmetic of #xref-to("c-os-cloud", "machine"), so the wrap is a measurement, not a crash. Computing $binom(n, k)$ through factorials inherits that ceiling immediately, and the floating-point route $n! \/ (k! (n-k)!)$ in doubles loses the integer character of the answer entirely.

The way out is the Pascal recurrence:

$ binom(n, k) = binom(n-1, k-1) + binom(n-1, k), quad binom(0, 0) = 1, quad binom(n, k) = 0 "outside" 0 <= k <= n $

Additions only: no division, no cancellation, no rounding, and every intermediate value is itself a binomial coefficient. On a rolling row of $k + 1$ entries the whole triangle costs $O(n k)$ additions and stays exact until a value leaves the type.

The dry run: row 5 of the triangle, built by the recurrence from row 4's `1 4 6 4 1`.

+ Outside entries copy: $binom(5,0) = binom(5,5) = 1$.
+ Interior entries add two parents: $binom(5,1) = 1 + 4 = 5$, $binom(5,2) = 4 + 6 = 10$, $binom(5,3) = 6 + 4 = 10$, $binom(5,4) = 4 + 1 = 5$.
+ Row 5 reads `1 5 10 10 5 1` and sums to $2^5 = 32$.

#listing("math/samples/src/Ch14/binomial.c", first: 52, last: 70, caption: [binomial.c, the rolling row: only true binomials are ever added, so the value is exact until it leaves the type])

The identities the rest of the book leans on, each CHECKed in both directions against the pinned value:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*identity*], [*instance*], [*pinned value*]),
  [symmetry $binom(n,k) = binom(n,n-k)$], [$binom(50,47) = binom(50,3)$], [19600],
  [pascal $binom(n,k) = binom(n-1,k-1) + binom(n-1,k)$], [$binom(48,12)$], [69668534468],
  [hockey stick $sum_(j=k)^n binom(j,k) = binom(n+1,k+1)$], [$sum_(j=3)^30 binom(j,3)$], [31465],
  [vandermonde $sum_j binom(m,j) binom(n,r-j) = binom(m+n,r)$], [$binom(20+20,10)$], [847660528],
  [absorption $k binom(n,k) = n binom(n-1,k-1)$], [$7 binom(30,7)$], [14250600],
  [row sum $sum_k binom(n,k) = 2^n$], [row 30], [1073741824],
)

The play: a 5-card poker deal has $P(52,5) = 311875200$ orderings but only $C(52,5) = 2598960$ hands, and the ratio of the two pins is exactly $120 = 5!$, the orderings each hand was carrying (checks 4 to 6).

#listing("math/samples/src/Ch14/binomial.c", first: 182, last: 200, caption: [binomial.c, the width ladder: uint64 dies between C(66,33) and C(68,34), the bit-precise types carry the ladder to row 128])

The width ladder continues past 64 bits on the C23 bit-precise integers, with widths stated: the central column is exact in uint64 through $binom(66,33) = 7219428434016265740$, but $binom(68,34) = 28453041475240576740$ leaves 64 bits and the final Pascal addition wraps to $10006297401531025124$ (checks 12 and 13). `_BitInt(128)` carries $binom(100,50) = 100891344545564193334812497256$ (97 bits) and tops out of this chapter's needs at $binom(128,64)$ with 125 bits, and `_BitInt(256)` holds $binom(200,100)$ with 196 bits, written as the `uwb` literal the C23 bit-precise suffix gives (cppreference, integer constants, fetched 2026-09-21). The Pascal recurrence holds at row 128 in the wide type (check 16), and since printf has no `_BitInt` conversion the digits come out by repeated division and round-trip against the decimal string (checks 17 and 18).

#diagram([pascal's triangle rows 0 to 5 with row sums doubling], length: 13pt, {
  let rows = ((1,), (1, 1), (1, 2, 1), (1, 3, 3, 1), (1, 4, 6, 4, 1), (1, 5, 10, 10, 5, 1))
  let sums = (1, 2, 4, 8, 16, 32)
  for (i, row) in rows.enumerate() {
    let y = 2.9 - 0.55 * i
    for (j, v) in row.enumerate() {
      let x = 5.2 + 1.15 * (j - i / 2)
      cdraw.circle((x, y), radius: 0.32, fill: luma(245), stroke: luma(100))
      cdraw.content((x, y), [#v], size: 6pt)
    }
    cdraw.content((11.4, y), [sum $2^(#i)$ = #sums.at(i)], size: 6pt, anchor: "west")
  }
})

== the binomial theorem

The theorem: $(x + y)^n = sum_(k=0)^n binom(n, k) x^k y^(n-k)$, the statement that the expansion coefficients are counted, each coefficient the number of ways to pick which $k$ of the $n$ factors contribute their $x$. Concrete Mathematics proves it by induction and calls it "the most important fact about the binomial coefficients" (Graham, Knuth, Patashnik, 2nd ed, chapter 5).

The verification discipline of this chapter refuses to trust either side: multiply $(1 + z)$ by itself $n$ times schoolbook style and compare every coefficient against the Pascal row.

#listing("math/samples/src/Ch14/theorem.c", first: 81, last: 104, caption: [theorem.c, the expansion checked against the pascal row at n = 12, then the theorem at integer arguments, (3 - 2)^7 = 1])

The dry run: at $n = 2$, $(1 + z)(1 + z) = 1 + 2z + z^2$, and the coefficients `1 2 1` are row 2 of the triangle. One more multiplication gives `1 3 3 1`, and the pattern continues to row 12, where the expansion and $binom(12, k)$ agree at all 13 positions: `1 12 66 220 495 792 924 792 495 220 66 12 1` (check 1). At integer arguments the coefficient sum evaluates $(3 + (-2))^7$ to exactly 1, matching the direct $1^7$ (check 2).

Three sum identities live on the same row, each a different weighting:

$ sum_k binom(n, k) = 2^n, quad sum_k (-1)^k binom(n, k) = 0, quad sum_k k binom(n, k) = n 2^(n-1) $

On row 30 they pin to $1073741824$, $0$, and $16106127360 = 30 dot 2^29$ (checks 3 to 5). The row-sum identity has an exact overflow boundary: every entry of row 64 fits uint64, $binom(64,32) = 1832624140942590534$, but the row sums to exactly $2^64$, so the uint64 accumulator lands on 0 (check 6). The alternating identity is the binomial theorem at $x = 1, y = -1$.

The probability side of the same theorem is already in the counting section: eqs (6.5)-(6.7) of the mml book weight the $binom(2, k)$ pre-images by $0.3^k 0.7^(2-k)$, which is the binomial distribution, the theorem doing double duty as a counting statement and a weighting statement.

The play: row 30 sums to $1073741824$ with all plus signs and to exactly 0 with alternating signs, the same 31 numbers read two ways.

#diagram([coefficients of (x + y)^8, the binomial row as a symmetric bar profile], length: 13pt, {
  let vals = (1, 8, 28, 56, 70, 56, 28, 8, 1)
  for (k, v) in vals.enumerate() {
    let h = 4.4 * v / 70
    let x = 1.0 + 1.3 * k
    cdraw.rect((x, 0), (x + 1.0, h), fill: luma(205), stroke: luma(60))
    cdraw.content((x + 0.5, h + 0.22), [#v], size: 6pt)
    cdraw.content((x + 0.5, -0.3), [#k], size: 6pt)
  }
  cdraw.line((0.8, 0), (12.6, 0), stroke: luma(100))
  cdraw.content((6.7, 5.1), [coefficient of $x^k y^(8-k)$], size: 6pt)
})

== inclusion-exclusion and derangements

Two sets: $|A union B| = |A| + |B| - |A inter B|$, subtracting the outcomes counted twice. Three sets add back the double-subtracted triple:

$ |A union B union C| = |A| + |B| + |C| - |A inter B| - |A inter C| - |B inter C| + |A inter B inter C| $

Worked example, the one the sample runs both ways: integers in $1..1000$ divisible by 3, 5, or 7. The floors are $333, 200, 142$, the pairwise $66, 47, 28$, the triple $9$, and the formula gives $333 + 200 + 142 - 66 - 47 - 28 + 9 = 543$. A 1000-step scan of the same question returns 543 (checks 7 to 10). The formula is 7 divisions, the scan is 1000 tests, and the gap grows with the universe: at $10^(18)$ the scan is dead and the formula still costs 7 divisions.

The dry run: which numbers die at each correction? 15 is divisible by 3 and by 5, so it enters in $|A|$ and $|B|$, leaves in $-|A inter B|$, and never returns, net count 1. 105 is divisible by all three, so it enters three times, leaves three times, and re-enters once in the triple, net count 1.

#listing("math/samples/src/Ch14/theorem.c", first: 131, last: 147, caption: [theorem.c, inclusion-exclusion by 7 divisions against a full scan of 1..1000])

A derangement is a permutation with no fixed point, written $!n$, and it is inclusion-exclusion in its purest form: exclude each fixed point, re-include pairs, and so on, which lands

$ !n = n! sum_(k=0)^n ((-1)^k) / k! quad "~" quad n! \/ e $

The ladder satisfies the recurrence $!n = (n - 1) (!(n-1) + !(n-2))$ with $!0 = 1, !1 = 0$, and the two forms agree exactly: at $n = 4$ the alternating sum is $24 - 24 + 12 - 4 + 1 = 9 = !4$, and at $n = 20$ both give $895014631192902121$ (checks 11 to 14).

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*$n$*], [*$!n$*], [*$!n \/ n!$*], [distance to $1\/e$]),
  [4], [9], [0.375], [7.1e-3],
  [6], [265], [0.368056], [1.8e-4],
  [8], [14833], [0.367882], [2.5e-6],
  [10], [1334961], [0.3678795], [2.3e-8],
  [12], [176214841], [0.367879441], [1.5e-10],
  [20], [895014631192902121], [0.3678794412], [1.9e-20],
)

The ratio column walks into $1\/e = 0.36787944117144233$, and the shortcut "round $n!/e$" is tempting but floats cannot cash it: at $n = 20$ the double $20!\/e$ lands on $895014631192902144$, which is 23 past the exact $!20$, because one ulp at $8.95 times 10^17$ is 128 and the float path cannot see single digits (check 15). The integer path has no such ceiling inside this ladder.

#callout("verify", "two authorities per count", [
  every union size in this section answers to both the formula and the scan, and every derangement to both the recurrence and the alternating sum. when the two disagree the bug is in the overlap structure you modeled, not in the arithmetic, because the arithmetic is exact integers end to end.
])

#diagram([the three-set venn for 1..1000 divisible by 3, 5, 7, region counts netting to 543], length: 13pt, {
  cdraw.circle((4.6, 3.4), radius: 1.9, stroke: luma(60), fill: luma(245))
  cdraw.circle((7.4, 3.4), radius: 1.9, stroke: luma(60), fill: luma(245))
  cdraw.circle((6.0, 5.5), radius: 1.9, stroke: luma(60), fill: luma(245))
  cdraw.content((3.6, 3.6), [229], size: 6pt)
  cdraw.content((8.4, 3.6), [115], size: 6pt)
  cdraw.content((6.0, 6.65), [76], size: 6pt)
  cdraw.content((6.0, 2.95), [57], size: 6pt)
  cdraw.content((4.95, 4.75), [38], size: 6pt)
  cdraw.content((7.05, 4.75), [19], size: 6pt)
  cdraw.content((6.0, 4.1), [9], size: 6pt)
  cdraw.content((1.9, 3.4), [div by 3: 333], size: 6pt, anchor: "east")
  cdraw.content((10.1, 3.4), [div by 5: 200], size: 6pt, anchor: "west")
  cdraw.content((6.0, 7.7), [div by 7: 142], size: 6pt)
  cdraw.content((11.4, 2.2), [union = 543], size: 6pt, anchor: "west")
})

The play: 543 survivors from 7 divisions or from a 1000-step scan, and $895014631192902121$ exact against $895014631192902144$ from the float shortcut.

== recurrences by iteration

A recurrence defines a sequence by its history, and the honest first implementation is iteration: keep the last few terms, add, step. The closed form earns trust only by matching the ladder.

Fibonacci, $F(n) = F(n-1) + F(n-2)$ with $F(0) = 0, F(1) = 1$: the uint64 ladder ends at $F(93) = 12200160415121876738$, and one more step wraps, $F(94) = 19740274219868223167$ collapsing to $1293530146158671551$ (checks 1 to 3). Two identities pin the structure without any closed form: the telescoping sum $sum_(i=0)^n F(i) = F(n+2) - 1$, at $n = 10$ both sides 143, and Cassini's identity $F(n-1) F(n+1) - F(n)^2 = (-1)^n$, at $n = 40$ the exact products are $10472279279564026 - 10472279279564025 = 1$ (checks 4 and 5).

The dry run: the ladder through F(12) reads 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, and the telescoping identity closes on it by hand: $0 + 1 + 1 + 2 + 3 + 5 + 8 + 13 + 21 + 34 + 55 = 143 = 144 - 1 = F(12) - 1$, the eleven terms $F(0)$ through $F(10)$ summing to one less than the next-but-one rung.

The growth ratio converges to the golden ratio $phi = (1 + sqrt(5)) \/ 2 = 1.618033988749895$:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*$n$*], [*$F(n+1) \/ F(n)$*], [distance to $phi$]),
  [10], [1.6181818181818182], [1.48e-4],
  [30], [1.6180339887505408], [6.5e-13],
  [90], [1.618033988749895], [below double resolution],
)

By $n = 90$ the ratio of two exact integers rounds to precisely the double of $phi$, the check comparing `f[91]/f[90]` against `(1 + sqrt(5))/2` for bit equality (checks 6 and 7). Binet's closed form $F(n) = (phi^n - psi^n) \/ sqrt(5)$ with $psi = 1 - phi$ evaluated in doubles lands $6765.000000000005$ at $n = 20$, five trillionths off the exact 6765 and close only because $psi^20$ is already $6.6 times 10^(-5)$ (check 8).

#listing("math/samples/src/Ch14/recurrence.c", first: 70, last: 106, caption: [recurrence.c, the exact ladder to F(93), two identities, the ratio pins, and binet in doubles])

The Tower of Hanoi, $T(n) = 2 T(n-1) + 1$ with $T(1) = 1$: unfold it and each disk-doubling nests, $T(n) = 2^(n-1) T(1) + (2^(n-1) - 1) = 2^n - 1$. The induction that makes the last step legal is the vocabulary of #xref-to("math", "proof"). The sample checks the closed form $2^n - 1$ against the recurrence for every $n$ from 1 to 63, and then the endpoint: $T(64) = 2^64 - 1 = 18446744073709551615$, exactly uint64 max, the 64-disk tower is the entire unsigned range (checks 9 and 10).

Catalan numbers count balanced structures (nested parentheses, binary trees) by the convolution recurrence $C_n = sum_i C_i C_(n-1-i)$ with $C_0 = 1$, and the closed form $binom(2n, n) \/ (n+1)$ agrees with the convolution at every pinned point: $C_15 = binom(30,15) \/ 16 = 9694845$ and $C_20 = binom(40,20) \/ 21 = 6564120420$ (checks 11 and 12).

#listing("math/samples/src/Ch14/recurrence.c", first: 108, last: 136, caption: [recurrence.c, hanoi's closed form checked for all n = 1..63 with T(64) = uint64 max, catalan two ways])

The play: $F(93) = 12200160415121876738$ is the last honest Fibonacci in 64 bits while $T(64)$ fits its entire $2^64 - 1$ range exactly, two recurrences with two different ceilings on the same type.

#diagram([the ratio F(n+1)/F(n) alternating into the golden ratio, dashed], length: 13pt, {
  // exact ratios F(n+1)/F(n) for n = 2..12, from gen.py:
  // 2, 1.5, 5/3, 8/5, 13/8, 21/13, 34/21, 55/34, 89/55, 144/89, 233/144
  let pts = ((2, 2.0), (3, 1.5), (4, 1.667), (5, 1.6), (6, 1.625),
             (7, 1.6154), (8, 1.619), (9, 1.6176), (10, 1.6182),
             (11, 1.618), (12, 1.6181))
  let sx(n) = { 0.4 + 1.05 * n }
  let sy(v) = { 2.6 * (v - 1.45) / 0.55 }
  for i in range(1, pts.len()) {
    cdraw.line((sx(pts.at(i - 1).first()), sy(pts.at(i - 1).last())),
               (sx(pts.at(i).first()), sy(pts.at(i).last())), stroke: luma(60))
  }
  cdraw.line((sx(2), sy(1.618)), (13.2, sy(1.618)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((13.3, sy(1.618)), [phi], size: 6pt, anchor: "west")
  for k in (0, 3, 6, 9) {
    let (n, v) = (pts.at(k).first(), pts.at(k).last())
    cdraw.circle((sx(n), sy(v)), radius: 0.07, fill: luma(205), stroke: luma(60))
    cdraw.content((sx(n), -0.35), [#n], size: 6pt)
  }
  cdraw.content((7.3, 2.5), [F(n+1) \/ F(n), n = 2..12], size: 6pt)
})

== generating functions as exact coefficients

The ordinary generating function of a sequence $a_0, a_1, a_2, ...$ is the formal power series $G(z) = sum_(n >= 0) a_n z^n$. "Formal" is the whole point for a programmer: $z$ is a position marker, never a number, multiplication of two series is the convolution $sum_(i+j=n) a_i b_j$, and everything in this section is exact integer arithmetic on truncated coefficient arrays. Concrete Mathematics opens its generating function chapter with this exact attitude: the series is a clothesline on which the sequence hangs (Graham, Knuth, Patashnik, 2nd ed, chapter 7).

The technique that makes generating functions compute: find the polynomial that annihilates the series. Multiplying by $1 - z$ shifts and subtracts, so $(1 - z) dot 1/(1 - z) = 1$, the geometric series killed by one factor.

The dry run: $(1 - z - z^2)$ against the Fibonacci series $1, 1, 2, 3, 5, ...$, coefficient by coefficient.

+ Constant term: $a_0 = 1$, so the product starts with 1.
+ $z^1$: $a_1 - a_0 = 1 - 1 = 0$.
+ $z^2$: $a_2 - a_1 - a_0 = 2 - 1 - 1 = 0$, and from here on each term is the sum of the two before it, so the subtraction always cancels.
+ The product is exactly 1: $(1 - z - z^2) F(z) = 1$, which says $F(z) = 1 \/ (1 - z - z^2)$.

#listing("math/samples/src/Ch14/recurrence.c", first: 138, last: 174, caption: [recurrence.c, three annihilations checked by convolution: fibonacci, hanoi, triangular])

The sample runs three annihilations, each a loop over exact uint64 coefficients:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*series*], [*annihilator*], [*product*]),
  [fibonacci $1, 1, 2, 3, 5, ...$], [$1 - z - z^2$], [$1$],
  [hanoi $0, 1, 3, 7, 15, ...$], [$1 - 3z + 2z^2$], [$z$],
  [triangular $1, 2, 3, 4, ...$], [$(1 - z)^2$], [$1$],
)

The hanoi identity factors as $T(z) = 1/(1-2z) - 1/(1-z)$, two geometric series whose coefficients $2^n$ and $1$ subtract termwise to $2^n - 1$, the closed form of the previous section read off the clothesline. And the binomial theorem of two sections back is itself a coefficient extraction in this language: $[z^k] (1 + z)^n = binom(n, k)$, the expansion verified by schoolbook multiplication is exactly a statement that multiplying the series $1 + z$ by itself $n$ times has $binom(n, k)$ ways to pick which factors contribute their $z$.

#callout("note", "formal, not convergent", [
  nothing here evaluates $z$. a formal power series is an infinite-tail integer array with finite head, the operations are convolution and shift, and the identity $F(z) = 1/(1 - z - z^2)$ means only "the convolution of both sides is 1", which is what the check verifies over 30 coefficients. convergence questions belong to analysis, not to counting.
])

#diagram([convolution as the mechanism: annihilator times series leaves a finite product], length: 13pt, {
  cdraw.rect((0.4, 3.6), (5.4, 4.6), fill: luma(235), radius: 0.02, stroke: luma(100))
  cdraw.content((2.9, 4.25), [annihilator 1 - z - z^2], size: 6pt)
  cdraw.content((2.9, 3.9), [coeffs 1, -1, -1], size: 6pt)
  cdraw.rect((0.4, 1.9), (5.4, 2.9), fill: luma(235), radius: 0.02, stroke: luma(100))
  cdraw.content((2.9, 2.55), [series 1, 1, 2, 3, 5, ...], size: 6pt)
  cdraw.content((2.9, 2.2), [fibonacci, 30 exact terms], size: 6pt)
  cdraw.line((2.9, 3.6), (2.9, 2.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((5.4, 4.1), (6.8, 3.3), stroke: luma(60), mark: (end: ">"))
  cdraw.line((5.4, 2.4), (6.8, 2.5), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((6.8, 2.4), (13.0, 3.6), fill: luma(205), radius: 0.02, stroke: luma(60))
  cdraw.content((9.9, 3.15), [product 1, 0, 0, 0, ...], size: 6pt)
  cdraw.content((9.9, 2.75), [29 interior coefficients vanish], size: 6pt)
})

The play: one two-term-deep polynomial kills all 29 interior coefficients of the Fibonacci series, and factoring its hanoi counterpart re-derives $2^n - 1$ without touching the recurrence.

== from counting to probability

Everything above counts equally likely outcomes. Probability starts when the outcomes carry weights: the mml book's section 6.1 attaches to each event $A$ a number $P(A) in [0, 1]$ with $P(Omega) = 1$ [printed p 175 / pdf p 181], and on a finite space with uniform weights $P(A) = |A| \/ |Omega|$, which is why the dice table in the first sample is already a probability computation. Its section 6.2.1 defines the joint probability of two discrete variables as exactly a count ratio, $P(X = x_i, Y = y_j) = n_(i j) \/ N$ eq (6.9) [printed p 178 / pdf p 184], and the marginalization is the sum rule over a row or column of the table.

Two fair dice make the whole story a $6 times 6$ grid, $N = 36$: the diagonal $sum = 7$ holds 6 pairs and the half-plane $sum >= 10$ also holds 6, so $P(sum = 7) = P(sum >= 10) = 6/36$, a tie between one exact value and a tail event that only counting sees.

#listing("math/samples/src/Ch14/counting.c", first: 105, last: 115, caption: [counting.c, the joint table of two dice as counts over N = 36, mml eq 6.9])

The mml book's two fundamental rules are the weighted image of the two counting rules. The sum rule eq (6.20) $p(x) = sum_(y in cal(Y)) p(x, y)$ marginalizes a joint table, the weighted sum rule. The product rule eq (6.22) $p(x, y) = p(y | x) p(x)$ factorizes a joint, the weighted product rule, both stated in section 6.3, eq (6.20) [printed p 184 / pdf p 190]. Dividing one product-rule reading by the other gives Bayes' theorem eq (6.23):

$ underbrace(p(x | y), "posterior") = (underbrace(p(y | x), "likelihood") underbrace(p(x), "prior")) / underbrace(p(y), "evidence") $

The dry run: a two-urn table small enough to hold in your head. Urn A holds 2 red and 1 blue, urn B holds 1 red and 2 blue, the urn is picked fair, and the draw comes up red.

+ Joint for A: $1/2 dot 2/3 = 2/6$. Joint for B: $1/2 dot 1/3 = 1/6$.
+ Evidence: $2/6 + 1/6 = 3/6$, the sum rule over the two hypotheses.
+ Posterior: $p(A|"red") = (2/6) \/ (3/6) = 2/3$, computed in exact integer rationals, unreduced $72/108$, cross-multiplied against $2/3$ (check 16).

#listing("math/samples/src/Ch14/recurrence.c", first: 176, last: 187, caption: [recurrence.c, bayes eq 6.23 on the two-urn table as exact rational arithmetic])

The play: the posterior is $2/3$, three exact integers, where the same table in floating point would print $0.6666666666666666$ and hide that it is a ratio of small counts. This is the whole bridge: #xref-to("math", "probability") builds the continuous theory on top of these finite tables, and every distribution it introduces is a weighting scheme over a counted space.

#diagram([bayes on the two-urn table, joints by the product rule, evidence by the sum rule], length: 13pt, {
  cdraw.rect((0.3, 3.4), (3.5, 4.5), fill: luma(235), radius: 0.02, stroke: luma(100))
  cdraw.content((1.9, 4.15), [prior 1/2], size: 6pt)
  cdraw.content((1.9, 3.75), [likelihood 2/3], size: 6pt)
  cdraw.rect((0.3, 1.7), (3.5, 2.8), fill: luma(235), radius: 0.02, stroke: luma(100))
  cdraw.content((1.9, 2.45), [prior 1/2], size: 6pt)
  cdraw.content((1.9, 2.05), [likelihood 1/3], size: 6pt)
  cdraw.line((3.5, 3.95), (5.2, 3.4), stroke: luma(60), mark: (end: ">"))
  cdraw.line((3.5, 2.25), (5.2, 2.4), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((5.2, 2.4), (9.6, 3.4), fill: luma(245), radius: 0.02, stroke: luma(100))
  cdraw.content((7.4, 3.1), [evidence 2/6 + 1/6 = 3/6], size: 6pt)
  cdraw.content((7.4, 2.7), [sum rule, eq 6.20], size: 6pt)
  cdraw.line((9.6, 2.9), (11.0, 2.9), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((11.0, 2.4), (15.0, 3.4), fill: luma(205), radius: 0.02, stroke: luma(60))
  cdraw.content((13.0, 3.1), [posterior 2/3], size: 6pt)
  cdraw.content((13.0, 2.7), [eq 6.23, exact], size: 6pt)
  cdraw.content((4.4, 1.1), [joint A 2/6, joint B 1/6 by the product rule, eq 6.22], size: 6pt)
})

sources: mml-book draft 2024-01-15, ch 6, sec 6.1 construction of a probability space [printed pp 172-178 / pdf pp 178-184] including the sample space, event space and probability definitions and the two coin toss omega [printed p 175 / pdf p 181], example 6.1 funfair draws with lookup table eqs (6.1)-(6.4) and pmf eqs (6.5)-(6.6) [printed p 176 / pdf p 182], eq (6.7) and pre-image eq (6.8) [printed p 177 / pdf p 183], sec 6.2.1 discrete probabilities eq (6.9) [printed p 178 / pdf p 184], and sec 6.3 sum rule, product rule, bayes eqs (6.20), (6.22) [printed p 184 / pdf p 190], (6.23) [printed p 185 / pdf p 191], all read from the verified anchor sheet ref/mml/anchors-prob.md. Concrete Mathematics, Graham, Knuth, Patashnik, 2nd ed 1994, ch 5 binomial coefficients, ch 6 special numbers, ch 7 generating functions, cited by name. Rosen, Discrete Mathematics and Its Applications, 8th ed 2019, ch 6, cited by name. cppreference, c integer constants, en.cppreference.com/w/c/language/integer_constant.html, wb and uwb suffixes, fetched 2026-09-21. Clang 23 language extensions, `_BitInt` section, clang.llvm.org/docs/LanguageExtensions.html, fetched 2026-09-21. Expected values computed with python exact integers in the one-off playground/math-ch14/gen.py. Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch14`, 60 checks in chapter 14 of the math suite, probed on this machine 2026-09-21.
