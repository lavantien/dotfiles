#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= testing with unittest

The whole book runs on the standard library, so the whole book tests on
it too. unittest is the framework, `unittest.mock` is the seam it
supplies for code that talks to things a test must not touch, and
doctest is the third leg, examples that live in the documentation and
fail the suite when the documentation lies. This chapter builds all
three against one pinned interpreter and then shows the part that
usually stays invisible: a suite run programmatically, its result
object inspected, its exit code asserted. The 4 samples under `Ch20/`
carry 27 checks, and the last one is a miniature of the verify gate
this book itself runs under, the same machinery the capstone suite of
#xref-to("python", "capstone1") rides.

== unittest anatomy

The unit is `unittest.TestCase`, and the loader's contract picks the
methods: "Return a suite of all test cases contained in the
TestCase-derived testCaseClass", one instance per method whose name
begins with `test`. The fixture protocol wraps each one. `setUp` "is
called immediately before calling the test method", and "any exception
raised by this method will be considered an error rather than a test
failure", a distinction the result object keeps for the whole run.
`tearDown` runs "even if the test method raised an exception", but
only if setUp succeeded. And the instance is fresh every time: "A new
TestCase instance is created as a unique test fixture used to execute
each individual test method." The first sample makes the interleaving
observable with an events list on the class:

#listing("python/samples/src/Ch20/anatomy.py", first: 18, last: 31, caption: [setUp, the two tests, tearDown, and the shared events list])

The check runs the class alone and requires the exact sequence, setup,
alpha, teardown, setup, beta, teardown, so the per-method fixture is a
measured fact here, not a convention:

#listing("python/samples/src/Ch20/anatomy.py", first: 81, last: 94, caption: [the recorded order asserted exactly: a fresh fixture per test])

The assert inventory is large and honest about what it checks:
`assertEqual` is `==`, `assertTrue` is `bool(x) is True`, and the 3.14
release added to the family, probed here by presence and by use:
`assertStartsWith`, `assertHasAttr`, `assertIsSubclass`. The
exception side belongs to the context manager form, whose page
promise is that "The context manager will store the caught exception
object in its `exception` attribute", so the assertion can extend past
the type into the message, the discipline #xref-to("python",
"exceptions") established for raise sites:

#listing("python/samples/src/Ch20/anatomy.py", first: 48, last: 58, caption: [assertraises as a context manager, and the failure when nothing raised])

The sample's fifth check runs the no-raise case and requires it
recorded as exactly one failure, because the negative paths of a test
framework are tests too. `subTest` covers the parametric grid, and the
docs state its value in one sentence: "Without using a subtest,
execution would stop after the first failure, and the error would be
less easy to diagnose because the value of `i` wouldn't be displayed."
A green grid counts as one test. A broken one names its parameters,
which the third sample measures precisely.

#diagram([one test method through the runner: the fixture cycle and the two red states], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.4, 4.4, 1.3, [fresh instance #linebreak() per method])
  box(6.4, 6.4, 4.4, 1.3, [setup()])
  box(12.2, 6.4, 4.6, 1.3, [test method, #linebreak() subtest loop inside])
  box(18.4, 6.4, 3.4, 1.3, [teardown()])
  cdraw.line((5.0, 7.05), (6.4, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.8, 7.05), (12.2, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 7.05), (18.4, 7.05), stroke: luma(100), mark: (end: ">"))
  box(12.2, 4.4, 4.6, 1.2, [assertion failed], fill: luma(215))
  box(18.4, 4.4, 3.4, 1.2, [recorded as failure])
  box(6.4, 4.4, 4.4, 1.2, [setup raised])
  box(6.4, 2.6, 8.0, 1.2, [recorded as error, teardown skipped], fill: luma(215))
  cdraw.line((14.5, 6.4), (14.5, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.6, 6.4), (8.6, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.6, 4.4), (8.6, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 5.0), (18.4, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.2, 1.4), [failure means the test ran and its assertion said no, error means the fixture or the test broke], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== mocks

The module's own sentence is the whole charter: "unittest.mock is a
library for testing in Python. It allows you to replace parts of your
system under test with mock objects and make assertions about how they
have been used." A `Mock` records calls and answers with what you
configured, `return_value` for the value, `side_effect` for a sequence
or a function, and the assertions are call assertions:
`assert_called_once_with` "Assert that the mock was called exactly
once and that call was with the specified arguments." The sample's
system under test is four lines, a price function used by a total
function, small enough that the seam is the only thing on stage:

#listing("python/samples/src/Ch20/mocks.py", first: 12, last: 27, caption: [the seam: unit\_price is looked up by line\_total, and a patch decorator waits above])

Discipline number one is spec. Given a spec, "Accessing any attribute
not in this list will raise an `AttributeError`", which turns the
classic mock failure, a green test exercising a method the real class
never had, into a loud red one:

#listing("python/samples/src/Ch20/mocks.py", first: 57, last: 65, caption: [spec=session allowed get, refused the invented post])

Discipline number two is aim. The patch page states the rule twice,
once as mechanism, "patch() works by (temporarily) changing the object
that a name points to with another one", and once as the aim:
"The basic principle is that you patch where an object is looked up,
which is not necessarily the same place as where it is defined." The
sample patches this module's `unit_price` because that is the name
`line_total` resolves at call time, and the check requires the restore:
300 before, 15 inside, 300 after:

#listing("python/samples/src/Ch20/mocks.py", first: 67, last: 77, caption: [patch where it is looked up, then the namespace is restored])

When not to mock is the same chapter's answer as when: mock the seam
you own, never the logic you are testing. A pure function like
`line_total` gets a real assertion over real inputs, and the mock
exists for the boundary calls, prices from a ledger, network from a
transport, where the capstone of #xref-to("python", "capstone1") mocks
its transport instead of opening a socket. `MagicMock` is the last
stop, the variant that supports magic methods, so `len()` works when
configured while a plain `Mock` refuses it with a TypeError, probed in
the closing check.

#diagram([one namespace before, during, and after a patch], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 6.4, 6.6, 1.4, [before: unit\_price is the real function, #linebreak() total is 300])
  cell(8.4, 6.4, 6.6, 1.4, [inside the with: the name points at a mock, #linebreak() total is 15], fill: luma(215))
  cell(16.2, 6.4, 5.6, 1.4, [after: restored, #linebreak() total is 300 again])
  cdraw.line((7.2, 7.1), (8.4, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 7.1), (16.2, 7.1), stroke: luma(100), mark: (end: ">"))
  cell(0.6, 4.2, 6.6, 1.4, [the mock records the lookup #linebreak() and answers 5])
  cell(8.4, 4.2, 6.6, 1.4, [spec would refuse an invented name #linebreak() right here], fill: luma(215))
  cell(16.2, 4.2, 5.6, 1.4, [assert\_called\_once\_with #linebreak() audits the seam])
  cdraw.line((3.9, 6.4), (3.9, 5.6), stroke: luma(100))
  cdraw.content((11.2, 2.6), [the swap is temporary and scoped: the exit runs the restore, so the next test starts from the real namespace], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== doctest and parametrics

doctest closes the gap between documentation and behavior by making
the documentation run. The page's charter: "The `doctest` module
searches for pieces of text that look like interactive Python
sessions, and then executes those sessions to verify that they work
exactly as shown." The examples are ordinary repl transcripts in the
docstring, and `testmod` over the module "Return `(failure_count,
test_count)`", two numbers a gate can count:

#listing("python/samples/src/Ch20/doctests.py", first: 14, last: 31, caption: [three examples living in two docstrings, executed as tests])

A wrong example is a failing test with the diff narrated, and the
sample builds one on purpose from a fabricated string, asserting one
failure, one try, and the words Expected and Got in the report:

#listing("python/samples/src/Ch20/doctests.py", first: 64, last: 75, caption: [the fabricated wrong example: expected versus got, counted])

The bridge into unittest is one call, `doctest.DocTestSuite(module)`,
which turns the module's examples into a suite the standard runner
executes, so doc examples and case classes ride the same gate. The
parametric half of the section is the subTest grid, measured at both
edges: a green 4-point grid is one green test, and a grid with 2 of 4
points failing produces exactly 2 failures that name `i=1` and `i=3`
while the passing points stay silent:

#listing("python/samples/src/Ch20/doctests.py", first: 90, last: 95, caption: [the half-broken grid: two failures, both parameters named])

Skipping gets one sentence and no check: a skip is a claim that a test
does not apply, and on this book's box the honest treatment is to
investigate until it applies or delete it loudly, not to leave a
silent green hole in the count. The gate treats a skipped test as
absent from the denominator, and absence is not verification.

#diagram([three ways to state an expectation, and what each one verifies], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 6.8, 6.8, 1.3, [unittest case, #linebreak() assert methods and fixtures], fill: luma(205))
  cell(8.4, 6.8, 6.8, 1.3, [doctest example, #linebreak() a repl transcript in the docstring], fill: luma(205))
  cell(16.2, 6.8, 5.6, 1.3, [subtest grid, #linebreak() one method, n points], fill: luma(205))
  cell(0.6, 5.2, 6.8, 1.3, [verifies behavior, #linebreak() states setup and teardown])
  cell(8.4, 5.2, 6.8, 1.3, [verifies the documentation, #linebreak() output compared literally])
  cell(16.2, 5.2, 5.6, 1.3, [verifies each parameter, #linebreak() names the failures])
  cell(0.6, 3.6, 6.8, 1.3, [failure: assertion, recorded])
  cell(8.4, 3.6, 6.8, 1.3, [failure: expected versus got])
  cell(16.2, 3.6, 5.6, 1.3, [failure per point, #linebreak() the grid keeps going])
  cell(0.6, 2.0, 14.6, 1.1, [doctestsuite bridges the middle column into the left one: one runner, one count], fill: luma(220))
  cdraw.content((11.2, 0.8), [green means every loaded expectation ran and held, skip means it never ran], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the suite in the gate

The last sample is the gate in miniature, and its centerpiece is the
entry point run programmatically. `unittest.main(argv=["gate",
"Parsing", "Totals"], exit=False)` returns instead of exiting, the
`TestProgram` keeps its result, and the counts are inspectable in the
same process, 4 run, zero failures, zero errors, zero skips, with the
runner's stream captured so the OK is an assertion and not decoration:

#listing("python/samples/src/Ch20/gate.py", first: 49, last: 58, caption: [build the suite, run it, and assert what green means])

The red path goes through the same entry point with `exit=True` and a
deliberately broken case: the process would exit with code 1 and the
captured stream says FAILED, both asserted, so the gate's own failure
semantics are themselves under test:

#listing("python/samples/src/Ch20/gate.py", first: 73, last: 88, caption: [the sabotaged run exits 1 and says FAILED, both checked])

The order of work this book follows everywhere is the order this
chapter was built in, and the same order the capstone follows: the
check exists first and is red, the implementation lands and turns it
green, and the commit carries both. A green run then proves exactly
three things, no more: every test method the loader found ran to the
end of its assertions, every fixture cleaned up after itself, and
nothing was skipped. It does not prove the absence of untested paths,
which is why the capstone pins its coverage story to its own test
inventory rather than to a green banner. When the gate runs
`make verify-py`, each sample's ok count is compared against the
number printed in the chapter's closing callout, the capstone's
unittest suite is executed through this same `main` machinery, and any
disagreement is a red build, the drift alarm this whole corpus is
built around.

#diagram([the gate's path from sample to green, and where red comes from], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 6.6, 4.4, 1.4, [sample files, #linebreak() pinned interpreter], fill: luma(205))
  cell(6.2, 6.6, 4.4, 1.4, [ok lines counted, #linebreak() one per check])
  cell(11.8, 6.6, 4.4, 1.4, [unittest suites, #linebreak() run through main])
  cell(17.4, 6.6, 4.4, 1.4, [exit code 0, #linebreak() the gate is green], fill: luma(205))
  cdraw.line((5.0, 7.3), (6.2, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.6, 7.3), (11.8, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.2, 7.3), (17.4, 7.3), stroke: luma(100), mark: (end: ">"))
  cell(6.2, 4.4, 4.4, 1.3, [count disagrees #linebreak() with the callout])
  cell(11.8, 4.4, 4.4, 1.3, [a suite fails, #linebreak() exit 1 asserted])
  cell(17.4, 4.4, 4.4, 1.3, [red build, #linebreak() drift is loud], fill: luma(215))
  cdraw.line((8.4, 6.6), (8.4, 5.7), stroke: luma(100))
  cdraw.line((14.0, 6.6), (14.0, 5.7), stroke: luma(100))
  cdraw.line((19.6, 6.6), (19.6, 5.7), stroke: luma(100))
  cdraw.line((10.6, 5.05), (11.8, 5.05), stroke: luma(140), mark: (end: ">"))
  cdraw.line((16.2, 5.05), (17.4, 5.05), stroke: luma(140), mark: (end: ">"))
  cell(0.6, 2.4, 9.6, 1.2, [test first: the check is written red, #linebreak() the implementation turns it green, one commit carries both])
  cdraw.content((11.2, 1.0), [green proves what ran held, the callout number proves what should have run], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "chapter 20 in the gate", [
  The 4 samples under `python/samples/src/Ch20/` print 27 ok lines:
  `anatomy.py` 7, `mocks.py` 8, `doctests.py` 6, `gate.py` 6. The
  deliberately broken cases, the missing raise, the wrong doctest
  example, the half-failing grid, and the sabotaged suite, run with
  their output captured into strings, so the failure accounting is
  asserted while the gate's own output stays clean.
])

sources: docs.python.org/3.14/library/unittest.html (loadTestsFrom
TestCase, the setUp and tearDown contracts, the fresh instance per
test, subTest's diagnostic sentence, the assert method inventory with
the 3.14 additions, assertRaises storing the exception),
docs.python.org/3.14/library/unittest.mock.html (the module charter,
the spec AttributeError, patch's mechanism and the patch-where-it-is-
looked-up principle, assert\_called\_once\_with),
docs.python.org/3.14/library/doctest.html (the module charter,
testmod's failure and test counts), all accessed 2026-09-12; the
exit-0 help path and the SystemExit(1) of the red run probed through
the pinned interpreter on this machine the same day. Sample behavior
verified by `make verify-py`, 27 checks in chapter 20.
