#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= stdlib numerics: math, statistics, decimal, random

Before #xref-to("python", "numpy") puts numbers into arrays, the standard
library already answers the four questions this chapter walks through in
order. How do floats actually round, and why does `0.1 + 0.2` miss, the
`math` and `cmath` answer, plus the integer boundary facts, 53 bit mantissas
and the 4300 digit conversion limit. What does a one pass summary look like,
the `statistics` answer, exact types in, exact types out, and a `NormalDist`
object that inverts its own cdf. When must arithmetic be exact, the
`decimal` answer, money from strings with a context that rounds on results
only, and `fractions` for exact rationals. And where does randomness come
from, the `random` answer, one mersenne twister behind module functions,
instances you can own, and the hard line where `secrets` takes over. Every
behavioral claim below is an ok line in the four samples, 74 in total, or a
sentence quoted from a page at docs.python.org fetched 2026-09-12. The
array and dataframe machinery of #xref-to("python", "numpy") and
#xref-to("python", "pandas") starts from these semantics, it does not
replace them.

== math and cmath

Four different operations turn a float toward an integer, and they disagree
in the negative half. `math.floor(-3.5)` is -4, "the largest integer less
than or equal to *x*", `math.ceil(-3.5)` is -3, "the smallest integer
greater than or equal to *x*", `int(-3.5)` is -3 because int conversion
truncates toward zero, and `math.trunc(-3.5)` is documented as that
truncation, "equivalent to `floor()` for positive *x*, and equivalent to
`ceil()` for negative *x*". The `//` operator sides with floor: `-7 // 2`
is -4, not -3:

#listing("python/samples/src/Ch23/mathmod.py", first: 14, last: 31, caption: [the four integerings of -3.5 and -7, `floor` and `//` go down, `int` and `trunc` go toward zero])

Floats are binary64 and the sample shows the representation limits
concretely rather than describing them. `0.1 + 0.2` is the neighbor double
`0.30000000000000004`, `repr` picks the shortest string that round trips
while 17 significant digits reveal what is stored, and past `2**53` the
last mantissa bit is gone, so `float(2**63 + 1)` reads back as `2**63`.
Accumulation drift is demonstrated the honest way, a manual `+=` loop lands
on `0.9999999999999999` while `math.fsum`, which "avoids loss of precision
by tracking multiple intermediate partial sums", lands exactly on 1.0:

#listing("python/samples/src/Ch23/mathmod.py", first: 32, last: 39, caption: [the neighbor double, and the shortest repr versus the 17 digit truth])

#listing("python/samples/src/Ch23/mathmod.py", first: 53, last: 60, caption: [the lost bit past `2**53`, and the `+=` drift that fsum corrects])

Equality on top of that representation is `math.isclose`, with the contract
printed as a formula: "the result will be: `abs(a-b) <= max(rel_tol *
max(abs(a), abs(b)), abs_tol)`", default `rel_tol=1e-09`, `abs_tol=0.0`.
The default relative tolerance arbitrates the `0.1 + 0.2` case, but "near
zero only `abs_tol` can say close, rel_tol of 0 is 0", and the special
values follow their own rules, "NaN is not considered close to any other
value, including NaN. `inf` and `-inf` are only considered close to
themselves":

#listing("python/samples/src/Ch23/mathmod.py", first: 40, last: 52, caption: [isclose with the default, the abs_tol leg near zero, and the inf and nan rules])

The special values are citizens, not errors. Overflow "saturates", the
sample reaches `inf` both by literal, `float("1e400")`, and by arithmetic,
`1e308 * 10`, nan never compares equal, `0.0` "is considered finite" while
inf is not, and `-0.0` compares equal to `0.0` with `copysign(1.0, -0.0)`
returning -1.0, the only witness to the sign bit:

#listing("python/samples/src/Ch23/mathmod.py", first: 61, last: 77, caption: [inf by two roads, nan unequal to itself and to any other nan, minus zero exposed only by copysign])

The module boundary is one sentence on the math page: "These functions
cannot be used with complex numbers; use the functions of the same name
from the `cmath` module if you require support for complex numbers."
`math.sqrt(-1)` is a `ValueError`, and 3.14 spells the domain out in the
message, "expected a nonnegative input, got -1.0", the improved error text
this release added. `cmath.sqrt(-1)` is `1j` across the branch cut,
`cmath.polar(3+4j)` is radius 5 and the angle, `cmath.rect` rebuilds `1j`
from `pi/2` up to the 6.1e-17 error in `cos`:

#listing("python/samples/src/Ch23/mathmod.py", first: 78, last: 93, caption: [math refuses complex input with the new domain message, cmath crosses the branch and polar and rect round the plane])

Integers have no such ceiling, "Python floats typically carry no more than
53 bits of precision", but ints are arbitrary precision and `2**200`
carries all 61 digits. The one integer boundary is in base 10: converting
between int and decimal string is quadratic, so the interpreter limits it,
and the sample asserts the defaults, `sys.get_int_max_str_digits()` at
4300 with the check threshold at 640, then trips both directions, `int` of
a 5000 digit string and `str` of a 5001 digit int are `ValueError`, while
`hex` and back round trips freely since power of two bases are linear:

#listing("python/samples/src/Ch23/mathmod.py", first: 94, last: 105, caption: [arbitrary precision ints, the 4300 digit default limit, and the hex path that ignores it])

#listing("python/samples/src/Ch23/mathmod.py", first: 134, last: 153, caption: [the limit probed from both sides, int of a string and str of an int, hex unaffected])

#diagram([the integerings as a matrix: one input, four rules, plus the two boundary rows where int and float stop being freely convertible], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  let colw = 4.4
  let lx = 0.6
  cell(lx, 8.5, 3.4, 1.1, [input], fill: luma(205))
  cell(lx + 3.8, 8.5, colw, 1.1, [`math.floor`], fill: luma(205))
  cell(lx + 8.6, 8.5, colw, 1.1, [`math.ceil`], fill: luma(205))
  cell(lx + 13.4, 8.5, colw, 1.1, [`int` and `trunc`], fill: luma(205))
  cell(lx, 6.8, 3.4, 1.4, [-3.5])
  cell(lx + 3.8, 6.8, colw, 1.4, [-4, down to #linebreak() the floor])
  cell(lx + 8.6, 6.8, colw, 1.4, [-3, up to #linebreak() the ceiling])
  cell(lx + 13.4, 6.8, colw, 1.4, [-3, toward #linebreak() zero])
  cell(lx, 5.3, 3.4, 1.4, [`-7 // 2`])
  cell(lx + 3.8, 5.3, colw, 1.4, [-4, `//` floors])
  cell(lx + 8.6, 5.3, colw, 1.4, [n/a])
  cell(lx + 13.4, 5.3, colw, 1.4, [n/a])
  cell(lx, 3.0, 21.0, 1.4, [float boundary: 53 bit mantissa, `2**63 + 1` reads back as `2**63`, `0.1 + 0.2` is the neighbor double], fill: luma(245))
  cell(lx, 1.4, 21.0, 1.4, [int boundary: arbitrary precision, but base 10 string conversion capped at 4300 digits by default], fill: luma(245))
  cdraw.content((11.0, 0.5), [the equality that survives the top row is `math.isclose`, never `==`, on floats], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== statistics

The module's type rule is the first sentence of the page: "Unless
explicitly noted, these functions support `int`, `float`, `Decimal` and
`Fraction`." The mean family shows what that buys. `mean` preserves the
input's exactness, fractions in give `Fraction(13, 21)` out, decimals give
`Decimal("0.5625")`, while `fmean` is the float fast path, "Convert *data*
to floats and compute the arithmetic mean. This runs faster than the
`mean()` function and it always returns a `float`":

#listing("python/samples/src/Ch23/stats.py", first: 28, last: 45, caption: [mean keeps fractions and decimals exact, fmean converts to float and stays there])

Position and frequency need no arithmetic at all. `median` picks the middle
value or the mean of the middle pair, `mode` returns the first most common
value on ties, "if there are multiple modes with the same frequency,
returns the first one encountered in the *data*", and works on names, and
`multimode` lists every leader "in the order they were first encountered":

#listing("python/samples/src/Ch23/stats.py", first: 46, last: 57, caption: [median, mode with first tie win on names, multimode listing every leader])

Spread comes in two denominators and the docs name them exactly:
`pstdev` is "the population standard deviation", `stdev` "the sample
standard deviation", n versus n-1, and the sample version is always the
larger one. Both floats assert to their last digit, 0.986893273527251
against 1.0810874155219827 on the docs' own six value dataset:

#listing("python/samples/src/Ch23/stats.py", first: 58, last: 66, caption: [population versus sample stdev, exact floats, n-1 always the bigger number])

`quantiles` cuts data into equal probability intervals, "Returns a list of
*n - 1* cut points", default `n=4` for quartiles, and the method default
matters, `'exclusive'`, "used for data sampled from a population that can
have more extreme values than found in the samples", versus `'inclusive'`
which lands the cuts on data points. On 1 through 5 the two give
`[1.5, 3.0, 4.5]` and `[2.0, 3.0, 4.0]`:

#listing("python/samples/src/Ch23/stats.py", first: 67, last: 74, caption: [quartiles under both methods, defaults pinned to exclusive])

`NormalDist` is "a tool for creating and manipulating normal distributions
of a random variable", and it is bidirectional: `cdf(0.0)` is exactly 0.5,
`inv_cdf(0.975)` is 1.9599639845400536, the standard two sided 5 percent
cut, and scaling to mean 100 sigma 15 moves it to 129.3994597681008. Its
`samples` method takes a seed and "creates a new instance of the underlying
random number generator", so the seeded sample list asserts exactly and
repeats:

#listing("python/samples/src/Ch23/stats.py", first: 75, last: 90, caption: [cdf and inv_cdf both exact, and seeded samples reproducible to the last float])

The mean family has two more members with their own domains:
`harmonic_mean([40, 60])` is 48.0, "the reciprocal of the arithmetic
`mean()` of the reciprocals", and the error paths are part of the contract,
`mean` of nothing and `geometric_mean` of a negative are both
`StatisticsError`:

#listing("python/samples/src/Ch23/stats.py", first: 91, last: 98, caption: [harmonic mean exact, and the two empty or invalid datasets raising cleanly])

#diagram([the standard normal as a curve: cdf at zero, the 2.5 percent tail beyond 1.96 sigma, the one sigma band the two stdevs measure], length: 13pt, {
  let x_to_px(x) = { 11.0 + x * 3.0 }
  let y_of(x) = { 7.8 * calc.exp(-x * x / 2) + 1.2 }
  let pts = ()
  for i in range(-30, 31) {
    let x = i / 10
    pts += ((x_to_px(x), y_of(x)),)
  }
  cdraw.line((8.0, 1.2), (14.0, 1.2), stroke: luma(150) + 3.2pt)
  for i in range(pts.len() - 1) {
    cdraw.line(pts.at(i), pts.at(i + 1), stroke: luma(60) + 0.8pt)
  }
  cdraw.line((2.0, 1.2), (20.6, 1.2), stroke: luma(120), mark: (end: ">"))
  cdraw.line((11.0, 1.2), (11.0, 9.2), stroke: luma(140), dash: "dashed")
  cdraw.content((11.0, 9.6), [mu, `cdf(0.0) == 0.5`], wrap: text.with(size: 6pt))
  cdraw.line((16.88, 1.2), (16.88, y_of(1.96)), stroke: luma(60), mark: (end: ">"))
  cdraw.content((17.2, 4.4), [`inv_cdf(0.975)` #linebreak() at 1.96 sigma, #linebreak() tail 2.5 percent], wrap: text.with(size: 6pt))
  cdraw.content((19.6, 1.7), [tail], wrap: text.with(size: 6pt))
  cdraw.content((4.0, 3.4), [one sigma band, #linebreak() pstdev over n, #linebreak() stdev over n-1], wrap: text.with(size: 6pt))
  cdraw.content((11.0, 0.4), [quantiles cuts data, not the curve: 1.5, 3.0, 4.5 on data 1 to 5, exclusive method], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== decimal and fractions

The before and after is one expression. In binary floating point
`0.1 + 0.1 + 0.1 - 0.3` drifts to `5.551115123125783e-17`, which the
decimal page names as the reason "differences prevent reliable equality
testing and differences can accumulate". The same expression over decimal
literals is exactly zero, because each literal is the decimal it says it is.
The everyday form agrees, `Decimal("0.1") + Decimal("0.2")` is
`Decimal("0.3")`:

#listing("python/samples/src/Ch23/exact.py", first: 22, last: 31, caption: [the drift and the zero, same expression, two number systems])

Significance is part of the value. The module "incorporates a notion of
significant places so that `1.30 + 1.20` is `2.50`. The trailing zero is
kept to indicate significance. This is the customary presentation for
monetary applications", and multiplication goes further, "`1.3 * 1.2` gives
`1.56` while `1.30 * 1.20` gives `1.5600`", every input figure used:

#listing("python/samples/src/Ch23/exact.py", first: 32, last: 40, caption: [trailing zeros survive the add, and multiplication uses every input figure])

The context is where rounding lives, and its defaults are assertable:
"The default values are `Context.prec`=`28`, `Context.rounding`=
`ROUND_HALF_EVEN`", with traps enabled for `Overflow`, `InvalidOperation`,
and `DivisionByZero`. Its scope is narrower than newcomers expect, "The
significance of a new Decimal is determined solely by the number of digits
input. Context precision and rounding only come into play during
arithmetic operations", and the FAQ's phrasing is the rule to remember:
"It occurs *after* the computation", the inputs stay whole and the result
rounds. An 11 digit pi constructs at all 11 digits, then `pi + 0` inside a
`localcontext` of precision 5 rounds to `3.1416`, and `1/3` carries 28
threes at the default and 6 inside a scoped context:

#listing("python/samples/src/Ch23/exact.py", first: 41, last: 51, caption: [the default context asserted: precision 28, half even, traps armed])

#listing("python/samples/src/Ch23/exact.py", first: 52, last: 60, caption: [construction keeps every digit, arithmetic rounds the result, localcontext scopes the change])

Money is the application. Prices as decimal strings sum exactly, 19.99 and
0.01 and 20.00 and 0.01 total 40.01 with no drift anywhere, and `quantize`
puts the cent back on a sum that wandered: `2.675` at two places rounds
half even to `2.68` while the float path through `round(2.675, 2)` gives
2.67, because the float nearest 2.675 is below it. The traps are load
bearing, quantize "would be greater than precision" signals
`InvalidOperation` rather than silently mangling, and division by zero
raises `DivisionByZero`:

#listing("python/samples/src/Ch23/exact.py", first: 61, last: 73, caption: [cents from strings, summed with zero drift])

#listing("python/samples/src/Ch23/exact.py", first: 74, last: 91, caption: [quantize half even versus the float path, round down, and both traps firing])

The float door is documented and exact in its own way: "If *value* is a
`float`, the binary floating-point value is losslessly converted to its
exact decimal equivalent. This conversion can often require 53 or more
digits of precision", so `Decimal.from_float(0.1)` is the 55 digit
expansion of the stored double and is not `Decimal("0.1")`. Python 3.14
adds `Decimal.from_number()` as "an alternative constructor", the same
conversion by another door:

#listing("python/samples/src/Ch23/exact.py", first: 92, last: 98, caption: [from float and the new from_number, both the exact 55 digit double])

`fractions` is exactness without a context. `Fraction(1, 3) +
Fraction(1, 6)` is `Fraction(1, 2)`, `Fraction(1, 3) * 3` is the int 1, and
the constructors are the whole map: from string `Fraction("0.1")` is
exactly 1/10, from float `Fraction(0.1)` is "the exact binary ratio",
`3602879701896397 / 36028797018963968`, matching `(0.1).as_integer_ratio()`
digit for digit. Python 3.14 widens the door twice, "A `Fraction` object
may now be constructed from any object with the `as_integer_ratio()`
method", which is how `Fraction(Decimal("0.1"))` is 1/10, and
`Fraction.from_number()` joins decimal's matching constructor.
`limit_denominator` closes the section with the classic: the best rational
approximation of pi with denominator under 1000 is 355/113:

#listing("python/samples/src/Ch23/exact.py", first: 99, last: 114, caption: [exact arithmetic, and the three construction doors including the two new in 3.14])

#listing("python/samples/src/Ch23/exact.py", first: 115, last: 123, caption: [limit_denominator finds 355/113, and the float door loses the round trip])

#diagram([before and after: the same four computations in float and in decimal, fractions exact off to the side], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 8.4, 9.8, 1.1, [float, binary64], fill: luma(205))
  box(11.0, 8.4, 9.8, 1.1, [decimal, base 10 with a context], fill: luma(205))
  box(0.6, 6.9, 9.8, 1.2, [`0.1 + 0.2` #linebreak() `0.30000000000000004`])
  box(11.0, 6.9, 9.8, 1.2, [`Decimal("0.1") + Decimal("0.2")` #linebreak() `Decimal("0.3")`])
  box(0.6, 5.4, 9.8, 1.2, [`0.1 x3 - 0.3` #linebreak() drift `5.5e-17`])
  box(11.0, 5.4, 9.8, 1.2, [same expression #linebreak() exactly 0])
  box(0.6, 3.9, 9.8, 1.2, [`round(2.675, 2)` #linebreak() `2.67`, the stored double is low])
  box(11.0, 3.9, 9.8, 1.2, [`quantize` half even #linebreak() `2.68` from the exact literal])
  box(0.6, 2.4, 9.8, 1.2, [53 bit mantissa, #linebreak() `2**63 + 1` reads back as `2**63`])
  box(11.0, 2.4, 9.8, 1.2, [precision 28 on results, #linebreak() traps on overflow, invalid, zero])
  box(0.6, 0.7, 21.2, 1.3, [fractions, no context at all: `1/3 + 1/6 == 1/2`, `1/3 * 3 == 1`, pi to 355/113 under 1000], fill: luma(245))
  cdraw.content((11.0, 0.2), [the float door into either world is exact: 55 digits for decimal, the integer ratio for fractions], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== random

The module's own description is the state machine: "Python uses the
Mersenne Twister as the core generator. It produces 53-bit precision floats
and has a period of 2\*\*19937-1. The underlying implementation in C is both
fast and threadsafe", and it "is completely deterministic", which is the
feature. Seeding is the entry point, `random.seed(4242)` twice replays the
same three float sequence while 4243 diverges, and a string seed uses
"all of its bits" under the version 2 conversion:

#listing("python/samples/src/Ch23/randommod.py", first: 73, last: 80, caption: [reseeding replays the stream, a different seed diverges])

The module functions are not free floating. "The functions supplied by
this module are actually bound methods of a hidden instance of the
`random.Random` class. You can instantiate your own instances of `Random`
to get generators that don't share state." Both halves are checks: after
`random.seed(1234)` the module's first draw equals `Random(1234)`'s first
draw, and heavy module drawing never moves a seeded instance's stream,
its next value still matches a fresh same seeded instance's second draw:

#listing("python/samples/src/Ch23/randommod.py", first: 83, last: 100, caption: [the hidden instance and your own: same seed same draw, module draws never perturb an instance])

The draws are contract bound, floats "uniformly in the half-open range
`0.0 <= X < 1.0`", checked across 1000 seeded draws. The selection family
splits by replacement: `sample` is "random sampling without replacement"
whose members "need not be hashable or unique" and whose result is "a new
list containing elements from the population while leaving the original
population unchanged", asserted on the exact selection order, while
`shuffle` permutes in place and sorted order recovers the original.
`choices` draws with replacement and takes weights, the sample pins a zero
weight never appearing, and the error contract is part of the api, "A
`ValueError` is raised if all weights are zero" and "a `TypeError` to
specify both *weights* and *cum_weights*":

#listing("python/samples/src/Ch23/randommod.py", first: 103, last: 110, caption: [sample without replacement, exact order, population untouched])

#listing("python/samples/src/Ch23/randommod.py", first: 37, last: 50, caption: [choices honoring a zero weight, and randbytes length plus difference])

State is inspectable and restorable, `getstate` before a draw and
`setstate` after replays the same value, which is how a test can branch a
random run without reseeding the world. And the boundary the module draws
itself is quoted in its warning, verbatim: "The pseudo-random generators
of this module should not be used for security purposes. For security or
cryptographic uses, see the `secrets` module." The sample checks the
`secrets` surface, 16 hex characters from `token_hex(8)`, 4 bytes from
`token_bytes`, neither ever repeating across calls, because that path
rides `os.urandom`, not the twister:

#listing("python/samples/src/Ch23/randommod.py", first: 126, last: 136, caption: [the weights error contract, both errors raised on demand])

#listing("python/samples/src/Ch23/randommod.py", first: 146, last: 151, caption: [getstate and setstate replay one value, the branch point for tests])

#callout("warning", "the line between random and secrets is about the attacker", [
  The mersenne twister is deterministic by design, and reproducibility is
  what makes seeded simulations and golden tests possible. Deterministic
  is precisely what a token must never be: after observing a few hundred
  outputs the twister's state is recoverable and every future value is
  known. Anything an adversary could influence or observe, session ids,
  salts, tokens, reset links, belongs to `secrets`, which is why the
  module's own warning is the loudest sentence on the page.
  #xref-to("python", "plumbing") places this same line in the operational
  context of hashing and secrets handling.
])

#diagram([random as a state machine: seed into 624 words of state, next per draw, module functions bound to the hidden instance, secrets on a different road entirely], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.8, 4.6, 1.5, [`seed`, int, str, #linebreak() bytes, all bits used])
  box(5.8, 6.8, 5.2, 1.5, [state, 624 words, #linebreak() period 2\*\*19937 - 1], fill: luma(215))
  box(11.6, 6.8, 5.0, 1.5, [temper and draw, #linebreak() 53 bit float, #linebreak() 0.0 <= x < 1.0])
  box(17.2, 6.8, 4.4, 1.5, [getstate, setstate, #linebreak() branch the stream])
  cdraw.line((5.2, 7.55), (5.8, 7.55), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 7.55), (11.6, 7.55), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.6, 7.55), (17.2, 7.55), stroke: luma(100), mark: (end: ">"))
  box(0.6, 4.3, 10.4, 1.5, [module functions: bound methods #linebreak() of one hidden `Random` instance])
  box(11.6, 4.3, 10.0, 1.5, [your `Random(n)`: own state, #linebreak() module draws never touch it])
  cdraw.line((8.4, 6.8), (5.8, 5.8), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((14.1, 6.8), (16.6, 5.8), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  box(0.6, 1.9, 10.4, 1.5, [`sample` no replacement, `shuffle` in place, #linebreak() `choices` with weights, `randbytes`])
  box(11.6, 1.9, 10.0, 1.5, [`secrets`: `os.urandom`, #linebreak() no state, no replay, #linebreak() the security side], fill: luma(245))
  cdraw.line((5.8, 4.3), (5.8, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.6, 4.3), (16.6, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 0.6), [reproducibility on the left is the feature, on the right it would be the vulnerability], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "74 checks, machine pinned, no approximations in the asserts", [
  `mathmod.py` pins the interpreter at 3.14.7 and contributes 22 checks,
  the four integerings, the neighbor double and the 53 bit boundary, the
  isclose contract with its special values, the accumulation drift against
  fsum, cmath across the branch, and both directions of the 4300 digit
  conversion limit. `stats.py` adds 17, exact types preserved through
  mean, the two denominators, both quantile methods, cdf and inv_cdf to
  the last digit, and the error paths. `exact.py` adds 20, the drift and
  the zero, significance arithmetic, the asserted default context, scoped
  precision, money with quantize and traps, the 55 digit float door, and
  fractions through all three construction doors. `randommod.py` adds 15,
  seeding, the hidden instance, isolation, the selection family with its
  weight errors, state replay, and the secrets boundary. Every expected
  value in these files was produced by this same interpreter, then pinned,
  so a change in any of them is a red, not a rounding dispute.
])

sources: docs.python.org/3/library/math.html (floor, ceil, trunc, isclose
and its formula and special value rules, fsum, copysign, the 53 bit note,
the complex boundary), cmath.html (sqrt, polar, rect), statistics.html
(the type rule, fmean, mode and multimode tie order, pstdev and stdev,
quantiles and both methods, NormalDist, cdf, inv_cdf, samples, harmonic
mean), decimal.html (the exact arithmetic claims, significance and money,
the default context values, construction exactness and from_float, the
rounding after computation faq, quantize and its InvalidOperation,
from_number), fractions.html (exact arithmetic, construction, the 3.14
as_integer_ratio rule and from_number, limit_denominator), random.html
(the mersenne twister description and period, the hidden instance, seed
semantics, the half open range, sample, shuffle, choices weights errors,
randbytes, getstate, setstate, and the security warning), the stdtypes
integer string conversion length limitation section (the 4300 digit
default, the 640 threshold, the affected conversions), and
docs.python.org/3/whatsnew/3.14.html (math domain error messages,
`Decimal.from_number`, the fractions construction changes), all accessed
2026-09-12. Sample behavior verified by `make verify-py`, 74 checks in
chapter 23.
