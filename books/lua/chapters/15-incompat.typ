#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= incompatibilities with 5.4

The manual's section 8 lists four language breaks and one library
break. This chapter pins each against the binary, then adds three
more observable changes the manual made outside section 8, each
verified against 5.5.1 and compared with the 5.4 documentation.

== the language list

`global` is reserved, softened in the stock build by the
`LUA_COMPAT_GLOBAL` default documented in #xref-to("lua",
"lexical"): the word stays
usable as a name, but the declaration statement still enforces
itself. The `for` control variable is read only, and the migration
is the manual's own suggestion, shadow it with a local. A chain of
`__call` metamethods caps at 15 objects. An error whose object is
nil gets the string `"<no error object>"` instead:

#listing("lua/samples/ch15_incompat.lua", first: 16, last: 46, caption: [reserved global under compat, read only loop variables, the call chain cap, nil error objects])

#diagram([the four language breaks of manual section 8], length: 13pt, {
  cdraw.rect((0.5, 2.6), (21.5, 11.6), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 10.4), (21.5, 10.4), stroke: luma(150))
  cdraw.line((6.0, 2.6), (6.0, 11.6), stroke: luma(150))
  for y in (9.1, 7.8, 6.5, 5.2, 3.9) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((3.25, 11.0), [break], size: 6.5pt)
  cdraw.content((13.75, 11.0), [what 5.5 does], size: 6.5pt)
  let row(y, brk, rule) = {
    cdraw.content((3.25, y), brk, size: 6pt)
    cdraw.content((13.75, y), rule, size: 6pt)
  }
  row(9.75, [global reserved], [compat un-reserves it, the declaration stands])
  row(8.45, [the for variable], [read only, shadow it with a local])
  row(7.15, [\_\_call chains], [capped at 15 objects])
  row(5.85, [a nil error object], [becomes the string "\<no error object\>"])
  cdraw.content((11.0, 3.25), [each pinned against the binary in the listing above], size: 6.5pt)
})

== the library list

The garbage collector no longer takes parameters through the
`"incremental"` and `"generational"` options. Extra arguments are
not an error, they are ignored, and the parameters moved to
`"param"` as #xref-to("lua", "environments") showed:

#listing("lua/samples/ch15_incompat.lua", first: 49, last: 57, caption: [ignored arguments, the param option])

#diagram([collectgarbage's options before and after the release], length: 13pt, {
  // the 5.4 call shape against the 5.5 one
  cdraw.rect((0.5, 6.2), (10.0, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.25, 7.95), [5.4: the mode options], size: 6pt)
  cdraw.content((5.25, 6.85), [took parameters inline], size: 6pt)
  cdraw.line((10.2, 7.4), (11.4, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.6, 6.2), (21.5, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((16.55, 7.95), [5.5: extra arguments are], size: 6pt)
  cdraw.content((16.55, 6.85), [silently ignored, not errors], size: 6pt)
  // where the parameters went
  cdraw.content((11.0, 5.0), [the knobs moved to one "param" option, chapter 8's figure], size: 6.5pt)
  cdraw.content((11.0, 3.8), [the manual lists this as the release's one library break], size: 6.5pt)
})

== beyond the list

Three observable deltas sit outside section 8. The default collector
mode is generational, where 5.4 defaulted to incremental, and the
manual states it only in its introduction. `math.floor`,
`math.ceil`, and `math.modf` return integers when the result fits,
a spec change in their manual entries. And the arithmetic error
messages were reworded to name the operation and both operand
types, where 5.4 said "attempt to perform arithmetic on a":

#listing("lua/samples/ch15_incompat.lua", first: 60, last: 78, caption: [default mode, integer floors, the new message wording])

#diagram([three deltas outside manual section 8], length: 13pt, {
  cdraw.rect((0.5, 3.9), (21.5, 11.6), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 10.4), (21.5, 10.4), stroke: luma(150))
  cdraw.line((6.5, 3.9), (6.5, 11.6), stroke: luma(150))
  for y in (9.1, 7.8, 6.5, 5.2) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((3.5, 11.0), [delta], size: 6.5pt)
  cdraw.content((14.0, 11.0), [where the manual says it], size: 6.5pt)
  let row(y, d, rule) = {
    cdraw.content((3.5, y), d, size: 6pt)
    cdraw.content((14.0, y), rule, size: 6pt)
  }
  row(9.75, [the default mode], [generational now, stated only in the introduction])
  row(8.45, [floor, ceil, modf], [integer when the result fits, a change in their entries])
  row(7.15, [arithmetic errors], [name the operation and both operand types])
  row(5.85, [the vararg rework], [compatible, but the largest semantic change, chapter 6])
})

The vararg rework, the tables and names of #xref-to("lua",
"functions"), is technically
compatible, old `...` code keeps working, but it is the largest
semantic change of the release and belongs in any migration review:

#listing("lua/samples/ch15_incompat.lua", first: 74, last: 78, caption: [vararg tables as the release's real headline])

== the api list

#diagram([the c side changes, documented only, not exercised by the chapter 14 hosts], length: 13pt, {
  cdraw.rect((0.5, 1.2), (21.5, 11.6), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 10.4), (21.5, 10.4), stroke: luma(150))
  cdraw.line((6.5, 1.2), (6.5, 11.6), stroke: luma(150))
  for y in (9.1, 7.8, 6.5, 5.2, 3.9, 2.6) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((3.5, 11.0), [call], size: 6.5pt)
  cdraw.content((14.0, 11.0), [the change], size: 6.5pt)
  let row(y, call, rule) = {
    cdraw.content((3.5, y), call, size: 6pt)
    cdraw.content((14.0, y), rule, size: 6pt)
  }
  row(9.75, [nresults], [capped at 250, LUA\_MULTRET for everything])
  row(8.45, [lua\_newstate], [a third parameter seeds string hashing])
  row(7.15, [lua\_closethread], [replaces lua\_resetthread, from = null])
  row(5.85, [lua\_dump], [the writer runs one extra time to signal the end])
  row(4.55, [LUA\_GCPARAM], [replaces LUA\_GCINC and LUA\_GCGEN])
  row(3.25, [lua\_pushvfstring], [reports errors instead of raising them])
  row(1.95, [lua\_setcstacklimit], [deprecated, removable])
})

The c side changes, unverifiable from pure lua and recorded here as
documentation: `nresults` in `lua_call` and related functions is
capped at 250, with `LUA_MULTRET` for more. `lua_newstate` takes a
third parameter, a seed for string hashing. `lua_resetthread` is
deprecated in favor of `lua_closethread` with a null `from`,
`lua_setcstacklimit` is deprecated and removable, `lua_dump` now
specifies its stack behavior and calls the writer one extra time to
signal the end, `LUA_GCINC` and `LUA_GCGEN` gave way to
`LUA_GCPARAM`, and `lua_pushvfstring` reports errors instead of
raising them.

sources: lua.org manual 5.5 section 8 in full, sections 1, 2.5, 3.4,
6.8 for the beyond-the-list items, accessed 2026-09-08, plus the
5.5.1 source tree's luaconf.h, ldo.h, lstate.c for limits. 10 tests
green through `make verify-lua`.
