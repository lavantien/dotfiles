#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= parsing and asts

Text becomes numbers through three stages: a lexer chops characters
into tokens, a recursive descent parser folds tokens into a tree,
and an evaluator walks the tree. Chapter 5 already ran infix to
postfix with shunting-yard for a stack machine, and this chapter
builds the same arithmetic the way compilers do it, with a grammar
that bakes precedence into its own shape. The full-language
treatment, keywords, calls, closures, lives in
#xref-to("csharp-net", "capstone"), and chapter 27 runs the
compiled version of these ideas as an opcode machine.

== the lexer

One pass, one cursor. Digit runs accumulate into number tokens,
letter runs into identifiers, the four operators and the
parentheses pass through as themselves, whitespace separates and
vanishes, and anything else is an error reported with its position
rather than a silent drop. Every language appends an end marker or
relies on running out of tokens, and the token stream for one fixed
fixture pins the whole behavior.

The dry run: the fixture is the C\# string 12 + foo \* (bar - 3),
asserted token by token by the C\# suite, lua pinning the same
string, c and java running x1 + 42 shapes of their own in the same
nine-token form.

+ The digit run consumes both characters as one token and carries its
  parsed value beside its text, 12 with value 12.
+ The letter run folds the same way, f, o, o accumulating into the
  single identifier foo, the whitespace between tokens vanishing.
+ The one-character tokens pass through as themselves: +, \*, (, the
  bar run, -, the 3, and ).
+ The end marker rides after the last token and the stream closes at
  ten tokens, nine from the source plus the end.
+ Strangers never join: 2 % 3 throws at the % and a\#b at the \#, each
  error carrying the character and its index.

#diagram([the run as a sequence, the two runs growing one character at a time above, the ten tokens closing on the shaded end marker below], length: 13pt, {
  // digit run 1 -> 12 with its value, letter run f -> fo -> foo
  cdraw.content((2.8, 8.2), [the digit run], size: 6.5pt)
  cdraw.rect((1.2, 6.7), (2.3, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((1.75, 7.15), [1], size: 6.5pt)
  cdraw.line((2.4, 7.15), (3.2, 7.15), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((3.3, 6.7), (4.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.85, 7.15), [12], size: 6.5pt)
  cdraw.content((3.85, 6.3), [value 12], size: 6pt)
  cdraw.content((10.1, 8.2), [the letter run], size: 6.5pt)
  cdraw.rect((7.6, 6.7), (8.5, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((8.05, 7.15), [f], size: 6.5pt)
  cdraw.line((8.6, 7.15), (9.1, 7.15), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.2, 6.7), (10.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((9.8, 7.15), [fo], size: 6.5pt)
  cdraw.line((10.5, 7.15), (11.0, 7.15), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.1, 6.7), (12.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.85, 7.15), [foo], size: 6.5pt)
  // the closing stream, nine source tokens plus the end
  let cells = (
    ([12], 1.2, 1.2), ([+], 2.9, 0.9), ([foo], 4.3, 1.5), ([\*], 6.4, 0.9), ([(], 7.6, 0.9),
    ([bar], 8.9, 1.5), ([-], 11.0, 0.9), ([3], 12.2, 0.9), ([)], 13.4, 0.9), ([end], 14.7, 1.3),
  )
  for (i, cell) in cells.enumerate() {
    let (t, x, w) = cell
    cdraw.rect((x, 2.0), (x + w, 2.9), fill: if i == 9 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, 2.45), t, size: 6.5pt)
  }
  cdraw.line((3.85, 6.6), (1.9, 3.05), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.line((11.85, 6.6), (5.05, 3.05), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.content((9.0, 1.4), [nine source tokens plus the shaded end marker], size: 6pt)
  cdraw.content((17.4, 7.15), [a run is one token], size: 6pt)
  cdraw.content((17.4, 6.25), [operators pass through], size: 6pt)
  cdraw.content((17.4, 5.35), [errors carry the index], size: 6pt)
})

The ten-token stream is the pinned assert, and the listings below
lex it in seven languages.

#listing("dsa/samples-c/src/Ch26/tokens.c", first: 29, last: 79, caption: [c, the cursor loop, digit and letter runs, an err token for strangers])
#listing("dsa/samples-go/ch26/tokens.go", first: 32, last: 68, caption: [go, digits buffer into a run, one letter per identifier, errors as values])
#listing("dsa/samples-java/src/Ch26/Tokens.java", first: 22, last: 75, caption: [java, the cursor loop writing into a pre-allocated token array, digit and letter runs, strangers become err tokens])
#listing("dsa/samples/src/Ch26/Parsing.cs", first: 19, last: 65, caption: [c\#, whitespace skip, digit and letter runs, a switch over the operators])
#listing("dsa/samples-js/src/ch26-tokens.mjs", first: 5, last: 38, caption: [javascript, every token carries its source position])
#listing("dsa/samples-py/src/Ch26/tokens.py", first: 17, last: 44, caption: [python, str methods classify, syntaxerror carries the position])
#listing("dsa/samples-lua/ch26_tokens.lua", first: 6, last: 41, caption: [lua, sub and match over bytes, an end token appended last])

The stream shape agrees everywhere: identifier, plus, number, star,
left paren, identifier, minus, number, right paren, on fixtures like
c's x1 + 42 times (foo - 3) and lua's 12 + foo times (bar - 3), and
multi-digit numbers lex as one token in all seven. The identifier
rule splits by language, and the go listing is the outlier on
purpose: it emits one letter per identifier, so ab reads as two
names, a choice its tests document. The other six accumulate
letters, digits, and underscores, python and java pinning a
underscore 9 b as a single name. Error handling splits the same
way, c and java keep lexing
and return an err token, go returns an error value, javascript,
python, and lua raise, and c\# throws with the offending character
and index in the message.

#diagram([the c fixture sliced into tokens, runs underlined, whitespace dropped, kinds labeled], length: 13pt, {
  // "x1 + 42 * (foo - 3)" -> ident + num * ( ident - num )
  let cells = (
    ([x1], [ident], 1.9), ([+], [op], 0.9), ([42], [num], 1.5), ([\*], [op], 0.9),
    ([(], [paren], 1.0), ([foo], [ident], 1.9), ([-], [op], 0.9), ([3], [num], 0.9),
    ([)], [paren], 1.0),
  )
  let x = 1.2
  for (text, kind, w) in cells {
    cdraw.rect((x, 5.4), (x + w, 6.3), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 5.85), text, size: 7pt)
    cdraw.content((x + w / 2, 4.9), kind, size: 6pt)
    cdraw.line((x, 5.3), (x + w, 5.3), stroke: luma(100))
    x += w + 0.55
  }
  // the source above with runs underlined, spaces grayed
  let src = ([x], [1], [ ], [+], [ ], [4], [2], [ ], [\*], [ ], [(], [f], [o], [o], [ ], [-], [ ], [3], [)])
  let sx = 1.2
  let under = (true, true, false, false, false, true, true, false, false, false, false, true, true, true, false, false, false, true, false)
  for (i, ch) in src.enumerate() {
    cdraw.content((sx, 7.3), ch, size: 7pt, fill: if i in (3, 5, 9, 11, 16, 18) { luma(60) } else { luma(150) })
    if under.at(i) {
      cdraw.line((sx - 0.14, 7.0), (sx + 0.14, 7.0), stroke: luma(100))
    }
    sx += 0.62
  }
  cdraw.content((8.6, 8.1), [runs underline, whitespace grays out], size: 6pt)
  cdraw.content((3.0, 3.7), [a number token carries its parsed value beside its text], size: 6pt)
  cdraw.content((3.0, 2.8), [an end marker rides after the last token], size: 6pt)
  cdraw.content((3.0, 1.9), [go reads ab as two identifiers], size: 6pt)
  cdraw.content((3.0, 1.0), [c returns err tokens, the rest raise], size: 6pt)
})

== recursive descent

The grammar is the code. Expr unfolds a term then loops over plus
or minus, term unfolds a factor then loops over multiply or divide,
and factor is a number, a name, or a parenthesized expr. Precedence
comes from the nesting depth, multiply and divide live one level
down, left associativity comes from the loop folding each new
operator onto everything parsed before it, and parentheses restart
the whole climb at the top.

The dry run: the fixture is 2 + 3 \* 4 with its parenthesized twin,
both trees asserted node for node by the C\# suite, the same shapes
pinning in the other six.

+ Expr calls Term calls Factor, and the first factor takes the 2, the
  cursor resting on the +.
+ Term sees no \* and returns, Expr's loop matches the + and calls
  Term again for the right side.
+ The inner Term takes the 3, its own loop matches the \* and folds
  Factor 4 into a multiply node, and the outer fold closes
  Bin(+, 2, Bin(\*, 3, 4)), the asserted tree.
+ The paren twin restarts the climb inside the parens, 2 + 3 folds
  first, and the tree lifts the plus to the root.
+ The chain 8 - 3 - 2 folds left one loop pass at a time, 8 - 3 = 5
  then 5 - 2 = 3, never the 7 of 8 - (3 - 2).
+ The broken inputs die at Expect: 2 + starves the factor, (2 waits
  for the rparen, and 2 3 leaves input behind at the end check.

#diagram([the parse as a sequence, the cursor events under the token rail on the left, the left fold of 8 - 3 - 2 building one pass at a time on the right], length: 13pt, {
  // the rail for 2 + 3 * 4 with take and peek events
  let toks = (([2], 1.2), ([+], 3.1), ([3], 5.0), ([\*], 6.9), ([4], 8.8))
  let evs = ([1 take], [2 peek], [3 take], [4 peek], [5 take])
  for (i, tk) in toks.enumerate() {
    let (t, x) = tk
    cdraw.rect((x, 6.9), (x + 1.0, 7.8), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.5, 7.35), t, size: 6.5pt)
    cdraw.content((x + 0.5, 6.45), evs.at(i), size: 6pt)
  }
  cdraw.content((5.0, 8.3), [the cursor over 2 + 3 \* 4], size: 6.5pt)
  // the descent chain, one box per level
  let lv = (([expr], 4.9), ([term], 3.5), ([factor], 2.1))
  for (i, l) in lv.enumerate() {
    let (name, y) = l
    cdraw.rect((1.2, y - 0.35), (3.6, y + 0.35), fill: if i == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.4, y), name, size: 6.5pt)
    if i < 2 { cdraw.line((2.4, y - 0.4), (2.4, y - 0.85), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((4.1, 3.5), [calls down, values climb back], size: 6pt, anchor: "west")
  // the left fold: three frames
  cdraw.content((13.7, 8.3), [8 - 3 - 2 folds left], size: 6.5pt)
  cdraw.rect((11.0, 6.6), (13.4, 7.5), fill: luma(235), radius: 0.02)
  cdraw.content((12.2, 7.05), [8 - 3], size: 6.5pt)
  cdraw.content((12.2, 6.25), [\= 5], size: 6pt)
  cdraw.line((13.5, 7.05), (14.3, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.4, 6.6), (17.8, 7.5), fill: luma(205), radius: 0.02)
  cdraw.content((16.1, 7.05), [(8 - 3) - 2], size: 6.5pt)
  cdraw.content((16.1, 6.25), [\= 3], size: 6pt)
  cdraw.content((13.7, 5.3), [the loop refolds everything], size: 6pt)
  cdraw.content((13.7, 4.4), [parsed so far each pass], size: 6pt)
  cdraw.content((4.6, 0.9), [a paren restarts the whole climb at expr], size: 6pt)
})

The pinned trees land the chain at 3, and the listings below parse
them in seven languages.

#listing("dsa/samples-c/src/Ch26/rdparse.c", first: 118, last: 142, caption: [c, term and expr loops over a shared token cursor, factor below adds unary minus])
#listing("dsa/samples-go/ch26/rdparse.go", first: 33, last: 75, caption: [go, parse and expr, errors returned not thrown, factor below])
#listing("dsa/samples-java/src/Ch26/Rdparse.java", first: 105, last: 139, caption: [java, term and expr loops over the shared cursor, factor below adds unary minus as 0 - x, trees pinned as s-expressions])
#listing("dsa/samples/src/Ch26/Parsing.cs", first: 125, last: 158, caption: [c\#, expr, term, factor over a peek and take cursor])
#listing("dsa/samples-js/src/ch26-rdparse.mjs", first: 10, last: 51, caption: [javascript, closures for factor, term, expr, trailing input refused])
#listing("dsa/samples-py/src/Ch26/rdparse.py", first: 38, last: 76, caption: [python, nested closures over a one-slot cursor list])
#listing("dsa/samples-lua/ch26_rdparse.lua", first: 39, last: 81, caption: [lua, locals declared up front so the mutual recursion binds])

The shape pins across languages: 2+3 times 4 nests the multiply
inside the plus, parentheses lift the plus, and the subtraction
chain 8-3-2 parses left associative as (8-3)-2, which is the same
fixture chapter 5's shunting-yard settled. Failure modes are where
the languages part ways. Go threads errors as values through every
level, javascript and python raise SyntaxError, lua and c\# throw
with the token in the message, and c and java set a parse-ok flag
and return a best-effort tree, both parsers accepting a unary minus
by rewriting x as 0-x. C's and java's parse files keep single-letter
names
against a 26-slot symbol table, and go's one-letter identifiers from
the previous section flow straight into its factor rule.

#diagram([two trees from one expression, precedence nesting the multiply, parentheses lifting the plus], length: 13pt, {
  // 2+3*4 -> +(2, *(3,4)); (2+3)*4 -> *(+(2,3), 4)
  let node = (p, label, hot) => {
    cdraw.circle(p, radius: 0.32, fill: if hot { luma(205) } else { luma(235) }, stroke: luma(150))
    cdraw.content(p, label, size: 7pt)
  }
  let edge = (a, b) => cdraw.line(a, b, stroke: luma(150))
  // left tree: + over 2 and * over 3, 4
  cdraw.content((4.0, 8.3), [2 + 3 \* 4], size: 7pt)
  edge((4.0, 7.2), (2.6, 6.2))
  edge((4.0, 7.2), (5.4, 6.2))
  node((4.0, 7.4), [+], true)
  node((2.6, 5.9), [2], false)
  node((5.4, 5.9), [\*], true)
  edge((5.4, 5.6), (4.5, 4.5))
  edge((5.4, 5.6), (6.3, 4.5))
  node((4.5, 4.2), [3], false)
  node((6.3, 4.2), [4], false)
  // right tree: * over + (2,3) and 4
  cdraw.content((15.6, 8.3), [(2 + 3) \* 4], size: 7pt)
  edge((15.6, 7.2), (14.0, 6.2))
  edge((15.6, 7.2), (17.2, 6.2))
  node((15.6, 7.4), [\*], true)
  node((17.2, 5.9), [4], false)
  node((14.0, 5.9), [+], true)
  edge((14.0, 5.6), (13.1, 4.5))
  edge((14.0, 5.6), (14.9, 4.5))
  node((13.1, 4.2), [2], false)
  node((14.9, 4.2), [3], false)
  cdraw.content((4.0, 3.4), [multiply nests one level down], size: 6pt)
  cdraw.content((15.6, 2.5), [the paren restarts at expr], size: 6pt)
  cdraw.content((10.5, 1.3), [8 - 3 - 2 folds left: (8 - 3) - 2 = 3], size: 6pt)
})

== evaluating the ast

Evaluation is a fold over the tree. A number node returns itself, a
name node looks up an environment, an operator node evaluates both
children and applies. Printing walks the same tree, and the test
that keeps printer and parser honest is the round trip: print the
tree, parse the print, land on the identical tree.

The dry run: the fixtures are those two trees with the environment
x = 5, y = -2, every value asserted by the C\# suite, the 14 and 20
pinning in every suite that carries them.

+ The fold bottoms out on the right first: the multiply node folds
  3 × 4 = 12, then the root adds 2 + 12 = 14.
+ The paren twin folds inside out the other way, 2 + 3 = 5 then
  5 × 4 = 20.
+ The chain 8 - 3 - 2 folds to 5 - 2 = 3, and 7 / 2 truncates to 3.
+ Names read the environment: x × x + 1 folds 5 × 5 = 25 then
  25 + 1 = 26, and x × y + 3 folds 5 × -2 = -10 then -10 + 3 = -7.
+ Printing wraps only where precedence demands: 2 + 3 \* 4 prints
  back as itself, 8 - (3 - 2) keeps its pair, and the round trip
  reparses every print into the identical tree.

#diagram([the fold rising from the leaves, the multiply closing first at 12 and the root second at 14, the environment lookups feeding the sibling tree], length: 13pt, {
  // left tree: 2 + (3 * 4) with the rise order marked
  let node = (p, label, hot) => {
    cdraw.circle(p, radius: 0.32, fill: if hot { luma(205) } else { luma(235) }, stroke: luma(150))
    cdraw.content(p, label, size: 6.5pt)
  }
  let edge = (a, b) => cdraw.line(a, b, stroke: luma(150))
  edge((3.6, 6.6), (2.2, 5.2))
  edge((3.6, 6.6), (5.0, 5.2))
  node((3.6, 6.8), [+], false)
  node((2.2, 5.0), [2], false)
  node((5.0, 5.0), [\*], true)
  edge((5.0, 4.7), (4.1, 3.3))
  edge((5.0, 4.7), (5.9, 3.3))
  node((4.1, 3.1), [3], false)
  node((5.9, 3.1), [4], false)
  cdraw.content((7.0, 5.0), [1st: 3 × 4 = 12], size: 6pt, anchor: "west")
  cdraw.content((7.0, 6.8), [2nd: 2 + 12 = 14], size: 6pt, anchor: "west")
  // right tree: x * x + 1 with the lookups
  edge((13.6, 6.6), (12.2, 5.2))
  edge((13.6, 6.6), (15.0, 5.2))
  node((13.6, 6.8), [+], false)
  node((12.2, 5.0), [\*], true)
  node((15.0, 5.0), [1], false)
  edge((12.2, 4.7), (11.3, 3.3))
  edge((12.2, 4.7), (13.1, 3.3))
  node((11.3, 3.1), [x], false)
  node((13.1, 3.1), [x], false)
  cdraw.content((11.3, 2.5), [5], size: 6pt)
  cdraw.content((13.1, 2.5), [5], size: 6pt)
  cdraw.content((17.0, 5.0), [1st: 5 × 5 = 25], size: 6pt, anchor: "west")
  cdraw.content((17.0, 6.8), [2nd: 25 + 1 = 26], size: 6pt, anchor: "west")
  cdraw.content((9.9, 8.1), [values rise, one node at a time], size: 6.5pt)
  cdraw.content((3.6, 1.6), [the paren twin: 5 × 4 = 20], size: 6pt)
  cdraw.content((3.6, 0.7), [x × y + 3: -10 + 3 = -7], size: 6pt)
})

The 14 closes the pinned fold, and the listings below evaluate the
same trees in seven languages.

#listing("dsa/samples-c/src/Ch26/asteval.c", first: 147, last: 187, caption: [c, the fold over node tags, a 26-slot symbol table, print into a char buffer])
#listing("dsa/samples-go/ch26/asteval.go", first: 8, last: 59, caption: [go, eval with a vars map, a fully parenthesized printer, roundtrip helper])
#listing("dsa/samples-java/src/Ch26/Asteval.java", first: 131, last: 165, caption: [java, the switch fold, a 26-slot symbol table, fully parenthesized printing])
#listing("dsa/samples/src/Ch26/Parsing.cs", first: 162, last: 197, caption: [c\#, pattern-switch eval, minimal parentheses by parent precedence])
#listing("dsa/samples-js/src/ch26-asteval.mjs", first: 4, last: 30, caption: [javascript, truncating division, unbound names raise])
#listing("dsa/samples-py/src/Ch26/asteval.py", first: 77, last: 98, caption: [python, the fold, a fully parenthesized render, the round trip])
#listing("dsa/samples-lua/ch26_asteval.lua", first: 76, last: 101, caption: [lua, env lookup with a named error, precedence-aware parens])

The values agree where the fixtures overlap: 2+3 times 4 evaluates
to 14 and (2+3) times 4 to 20 in every suite that pins them, and
the printers split into two honest camps. C, go, java, javascript,
and
python print fully parenthesized, every binary node wrapped, which
loses nothing. C\# and lua print minimal parentheses, wrapping a
child only when its precedence is lower than its parent's, so
2+3 times 4 prints back as itself. Python pins the strongest
property of the section, printing and reparsing its own render
yields a tree structurally equal to the original, and java pins the
value round trip over five fixtures plus the print fixed point,
reprinting the reparsed tree char for char. Division semantics
get one sentence each: c\#, java, and javascript truncate toward
zero,
python and lua floor, go and c use integer division on ints, and
the fixtures are chosen so the distinction never changes an answer.

#diagram([the round trip, source to tree to print to tree again, with the two printer camps], length: 13pt, {
  // 2+3*4 -> tree -> "(2+(3*4))" -> same tree
  let box = (x, y, w, body, hot) => {
    cdraw.rect((x, y - 0.45), (x + w, y + 0.45), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, y), body, size: 6.5pt)
  }
  box(1.0, 6.6, 3.4, [2 + 3 \* 4], false)
  box(1.0, 4.4, 3.4, [the tree], true)
  box(1.0, 2.2, 3.4, [(2+(3\*4))], false)
  box(1.0, 0.0, 3.4, [the same tree], true)
  let arrow = (y) => cdraw.line((2.7, y + 0.5), (2.7, y - 0.5), stroke: luma(100), mark: (end: ">"))
  arrow(5.5)
  arrow(3.3)
  arrow(1.1)
  cdraw.content((4.9, 5.55), [parse], size: 6pt)
  cdraw.content((4.9, 3.35), [print], size: 6pt)
  cdraw.content((4.9, 1.15), [parse again], size: 6pt)
  box(9.6, 4.4, 5.2, [fully parenthesized: c, go, js, py], false)
  box(9.6, 2.2, 5.2, [minimal parens: c\#, lua], false)
  cdraw.line((4.4, 3.3), (9.5, 4.15), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((4.4, 3.1), (9.5, 2.45), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((11.0, 6.6), [eval: 14 either way], size: 6pt)
  cdraw.content((11.0, 0.0), [structural equality, pinned in python], size: 6pt)
  cdraw.content((2.7, 7.6), [print loses nothing, parse restores everything], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's three sample files, test scripts included where the
language embeds them:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [507], [fixed token and node pools], [err tokens instead of exceptions, unary minus rewrite, single-letter names in the parser],
  [c\#], [166], [records, pattern switches], [minimal-parens printer by parent precedence, positions in errors],
  [go], [226], [interfaces for node kinds], [single-letter identifiers, errors as values through every level],
  [java], [512], [jdk 27 stdlib], [err tokens in the lexer, the parse-ok flag with a best-effort tree, unary minus rewritten as 0 - x, the print fixed point pinned],
  [javascript], [96], [plain objects, closures], [source position on every token, truncating division],
  [python], [249], [tuples as nodes], [floor division on exact fixtures, round-trip equality pinned],
  [lua], [291], [tables tagged by kind], [locals declared ahead for mutual recursion, floor division],
)

sources: learn.microsoft.com for records and pattern matching over
them, go.dev for `fmt.Errorf` and interface satisfaction,
developer.mozilla.org for `SyntaxError` and `Math.trunc`,
docs.python.org for `str.isdigit` and friends, lua.org for
`string.match` patterns, accessed 2026-09-14. Sample behavior
verified by the seven suite gates scoped to chapter 26: c 3 files
and 47 checks, c\# 9 tests, go 14 tests, java 3 files and 47 checks,
javascript 11 tests, python 3
files and 27 asserts, lua 12 checks, zero skipped.
