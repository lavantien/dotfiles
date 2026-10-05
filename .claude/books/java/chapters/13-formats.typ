#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= text, numbers, and time

Programs spend their days on strings, numbers, and timestamps, and
java's story on all three is a long climb out of 90s decisions: a
`String` api that grew modern methods across 11, 12, and 15, text
blocks that made multiline literals writable, exact decimal and
integer arithmetic when binary floats will not do, a `java.time`
package that replaced `java.util.Date` wholesale at 8, and utf-8 as
the platform charset since 18. This chapter walks each one end to
end with the pitfalls next to the fixes.

== String as the modern api

Strings are immutable and live in the string pool when literal, the
`+` operator compiles to an `invokedynamic` concatenation strategy
since 9, so hot loops no longer need hand-written `StringBuilder`
churn, though building incrementally still uses one directly. The
batch that modernized daily work landed in 11: `isBlank`,
`lines`, `strip`, `stripLeading`, `stripTrailing`, and `repeat`.

#listing("java/samples/src/Ch13/Strings.java", first: 15, last: 24, caption: [the 11 batch, and strip against trim on a U+2000 space])

`strip` against `trim` is the sleeper difference: `trim` cuts
characters up to U+0020, an ascii-era definition, `strip` uses
unicode whitespace, and the check keeps a U+2000 space alive through
`trim` to prove it. `lines` splits on all three line terminators and
returns a `Stream`, so it chains directly into the chapter 12
vocabulary. `indent` (12) pads or strips a per-line margin, and
`stripIndent` (15) applies the text-block algorithm to any string,
which the next section needs.

#listing("java/samples/src/Ch13/Strings.java", first: 25, last: 36, caption: [indent, stripIndent, formatted, and the 18 charset default])

`formatted` (15) puts `String.format` on the instance, the fluent
reading order the printf-style call always wanted.

=== utf-8 by default

Before 18 the default charset followed the operating system, so a
`FileReader` read the same bytes differently on a Windows machine
than on Linux, and files moved between them corrupted quietly. Jep
400 made utf-8 the default charset in 18 everywhere, `file.encoding`
reads utf-8 on a stock jvm, and code needing a different one says so
explicitly with `new InputStreamReader(in, charset)`. The sample
probes both properties on the running machine. Programs that always
passed an explicit charset noticed nothing, which was the point.

== text blocks

Multiline strings fought escaping for 20 years. Text blocks,
previewed in 13 and 14, final in 15 (jep 378), fixed it: open with
`"""` and a newline, close with `"""`, and the content keeps its
shape.

#listing("java/samples/src/Ch13/TextBlocks.java", first: 19, last: 34, caption: [the indentation algorithm, minimum strip with a closing-delimiter cap])

The algorithm, precisely: the compiler finds the common whitespace
prefix across the content lines, and the closing delimiter's own
line counts when it sits left of the content, capping how much is
stripped. Move the closing `"""` left and the content shifts right
with it, slide it past the content's left edge and nothing strips.
`String.stripIndent` implements the same minimum-indent rule for
runtime strings, and `translateEscapes` completes the pair. The
final newline before the closing delimiter is part of the content,
the checks assert it, and every line's trailing whitespace is
removed unless escaped.

Two escapes exist because of that trailing-whitespace rule and long
lines: `\` at end of line joins two source lines into one logical
line, and `\s` pins a real space that would otherwise be stripped,
both since 14.

#listing("java/samples/src/Ch13/TextBlocks.java", first: 38, last: 58, caption: [the two escapes, free quotes, and plain-String identity])

At runtime a text block is a `String`, nothing else, the last check
compares it against the ordinary literal. Their natural habitat is
embedded languages: json, sql, html ride without double escaping,
and chapter 19's http kernel builds its test fixtures from blocks.

== BigInteger and BigDecimal

Binary floating point cannot hold 0.1, and money is counted in
tenths. `java.math` carries the exact pair: `BigInteger` for
unbounded integers, `BigDecimal` for arbitrary-precision decimal.
The one rule that prevents the classic bug: construct from strings
or `valueOf`, never from a double.

#listing("java/samples/src/Ch13/Numbers.java", first: 16, last: 41, caption: [exact arithmetic, the double constructor trap, and the two equality semantics])

`new BigDecimal(0.1)` prints
`0.1000000000000000055511151231257827021181583404541015625`, the
exact binary double the literal names, while the string and
`valueOf` forms hold 0.1. Division without a target scale throws
`ArithmeticException` on non-terminating results, 1/3 has no
decimal end, so real code passes a scale and a `RoundingMode`.
And the equality trap: `equals` compares scale, `1.0` is not
`1.00`, `compareTo` compares values, so sorted maps of decimals key
on `compareTo` or normalize first.

#listing("java/samples/src/Ch13/Numbers.java", first: 42, last: 63, caption: [BigInteger measured, compact formatting since 12, locale currency])

Measured 2026-10-04 on the pinned build: 2^10000 has 3,011 decimal
digits at a bitLength of 10,001, arithmetic that would overflow
`long` stays exact. Compact number formatting arrived with 12
(`getCompactNumberInstance`), 1,000,000,000 formats as `1B` short
and `1 billion` long, locale aware, and the currency instance groups
and rounds, `$1,234,567.89`. For the floating-point side, 17 made
every operation strictly IEEE 754 (jep 306), the `strictfp` keyword
became a no-op, and the pitfalls that remain are binary
representation itself, the reason this section exists.

== java.time

The 8 overhaul (jsr 310) replaced `Date` and `Calendar` with a
package built on one distinction: a point on the timeline is an
`Instant`, a machine reading with nanoseconds since the epoch.
Calendar-shaped types, `LocalDate`, `LocalTime`, `LocalDateTime`,
carry fields without a zone, `ZonedDateTime` adds one, and
`OffsetDateTime` carries just the utc offset. Everything is
immutable and the api is fluent: `plus`, `minus`, `with`, `truncatedTo`.

#listing("java/samples/src/Ch13/Time.java", first: 16, last: 27, caption: [Instant, and Duration's machine time against Period's calendar walk])

`Duration` counts seconds and nanoseconds, exact machine time.
`Period` counts years, months, days on the calendar, and the check
shows the difference on real dates: January 31 to March 1, 2026 is
one month and one day through the calendar, 29 days on a timeline.
Mixing them up breaks billing logic.

#listing("java/samples/src/Ch13/Time.java", first: 29, last: 44, caption: [dst edges resolved, formatting and parsing both ways])

Time zones are rules, not offsets, and the rules change: the jvm
carries its own tzdata copy, so zone-rule updates ride jdk updates.
The two hard edges behave deterministically: a local time inside
the spring-forward gap shifts forward, 02:30 on March 8, 2026 in
New York becomes 03:30, and an ambiguous fall-back time takes the
earlier offset. Formatters parse what they print, `DateTimeFormatter`
patterns and predefined ISO constants, and `MonthDay` and
`YearMonth` cover the partial shapes.

#listing("java/samples/src/Ch13/Time.java", first: 46, last: 58, caption: [the injected clock, deterministic time in tests])

`Clock` is the seam that makes time-dependent code testable: pass a
`Clock` in, production gets `Clock.systemUTC()`, a test gets
`Clock.fixed` for one instant and `Clock.offset` to travel, and
`now(clock)` becomes a pure function of its argument. The service
spine's token expiry checks in chapter 22 ride exactly this. Legacy
`Date` converts one way, `toInstant`, and stays at the boundary.

#diagram([the type lattice: machine time left, calendar right, zones bridged], length: 13pt, {
  cdraw.rect((0.3, 2.0), (6.6, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.45, 4.5), [machine time], size: 6.5pt)
  cdraw.content((3.45, 3.6), [Instant, utc nanos], size: 6pt)
  cdraw.content((3.45, 2.7), [Duration between instants], size: 6pt)
  cdraw.rect((8.4, 2.0), (14.7, 5.0), fill: luma(228), radius: 0.02)
  cdraw.content((11.55, 4.5), [human time], size: 6.5pt)
  cdraw.content((11.55, 3.6), [LocalDate, LocalTime,], size: 6pt)
  cdraw.content((11.55, 2.7), [LocalDateTime, no zone], size: 6pt)
  cdraw.rect((8.4, -1.2), (14.7, 1.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.55, 1.3), [zoned time], size: 6.5pt)
  cdraw.content((11.55, 0.4), [ZonedDateTime, ZoneId rules], size: 6pt)
  cdraw.content((11.55, -0.5), [Period across calendar], size: 6pt)
  cdraw.line((6.7, 3.5), (8.3, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.5, 3.95), [atZone], size: 6pt)
  cdraw.line((11.55, 1.9), (11.55, 2.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((0.3, 0.9), [Clock injected, now(clock) deterministic], size: 6pt)
  cdraw.content((0.3, 0.0), [instant now, fixed, offset: the test seam], size: 6pt)
})

sources: JEP 378 text blocks final 15 (openjdk.org/jeps/378, the
re-indentation algorithm, stripIndent equivalence, line-join and \s
escapes delivered by the 14 preview JEP 368), JEP 400 utf-8 default
18, JEP 306 strict floating point 17, all accessed 2026-10-04. API
since tags verified against the pinned build's own source in
tools/jdk27/build/jdk-27/lib/src.zip: String isBlank, lines, repeat,
strip 11, indent 12, stripIndent and formatted 15, read 2026-10-04.
Compact number formatting since 12 confirmed from the same source's
NumberFormat (getCompactNumberInstance since 12) and the openjdk
JDK 12 project page, which lists it as a non-JEP enhancement,
accessed 2026-10-04. The 8-to-17 arcs (string literals and
immutability, the concatenation story and its 9 invokedynamic
change, toString and valueOf, regex at a mention, two's complement,
IEEE 754 and the Goldberg reading, the java.time walkthrough with
Instant, Duration, TemporalQuery, adjusters, zone data, and legacy
conversion) ground on Java in a Nutshell 8th edition chapter 9,
pages 319 to 341. Measurements and behaviors verified by
`java/samples/src/Ch13` under `pwsh tools/run-java-samples.ps1
-Chapter Ch13`, dated 2026-10-04 on tools/jdk27/build/jdk-27: 38
checks including the U+2000 strip/trim split, the text-block
indentation outcomes with the closing-delimiter cap and final
newline, 2^10000 at 3,011 digits, compact 1B and 1 billion,
currency \$1,234,567.89, the dst gap and overlap resolutions, and
the fixed and offset clock determinism.
