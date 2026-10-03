#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= pandas

This chapter teaches pandas before #xref-to("python", "capstone2") builds
its report leg on it, and the version matters more here than anywhere
else in the book: pandas 3.0.5, a patch of the 3.0 line released
2026-01-21, where copy-on-write became the only behavior and a dedicated
string dtype became the default. Search results still surface 2.x
answers by volume, and half of them describe a library that silently
mutated through views, which is precisely what 3.0 removed. The frames
are built on the arrays of #xref-to("python", "numpy"), they carry the
same dtypes underneath, and every behavioral claim below is an ok line
in the four samples, 33 in total, or a sentence quoted from the pandas
3.0 documentation fetched 2026-09-12.

== series and dataframe

A Series is one column of values plus an Index, and a DataFrame is
columns sharing one Index. The index is first class, not row numbering:
it travels with the data, slicing by label includes both endpoints,
and arithmetic aligns two Series on the union of their indexes, filling
the gaps with nan. The sample pins all three, and the alignment check
is the one that surprises newcomers, `a + b` on indexes that partially
overlap answers at the union with holes where either side is missing:

#listing("python/samples/src/Ch25/frames.py", first: 20, last: 25, caption: [the chapter contract: the interpreter pin, then the pandas 3.0.5 pin asserted in-sample])

#listing("python/samples/src/Ch25/frames.py", first: 9, last: 16, caption: [arithmetic aligns on the union of the two indexes, gaps become nan])

Construction takes dicts for frames, lists plus an index for series,
and the dtype inference has one 3.0 rule to know, quoted from the
release notes: "Starting with pandas 3.0, a dedicated string data type
is enabled by default (backed by PyArrow under the hood, if installed,
otherwise falling back to being backed by NumPy object-dtype)." This
book does not pin pyarrow, so the fallback storage serves, `str(dtype)`
reads "str", and a missing entry is nan. The two addressing doors are
`loc` by label and `iloc` by position, and the endpoint rule is the
difference between them:

#listing("python/samples/src/Ch25/frames.py", first: 27, last: 34, caption: [series and frame construction, and a loc write in one statement])

#listing("python/samples/src/Ch25/frames.py", first: 36, last: 48, caption: [the index and name travel, text infers str, integers infer int64])

#listing("python/samples/src/Ch25/frames.py", first: 49, last: 63, caption: [loc by label with both endpoints, iloc by position without, a boolean mask keeps rows])

The numpy handoff goes both ways and keeps the buffer:
`to_numpy` returns the ndarray underneath, and an ndarray plus column
names builds a frame directly:

#listing("python/samples/src/Ch25/frames.py", first: 65, last: 73, caption: [alignment on the union, then to_numpy and back])

#callout("note", "label slices close, position slices do not", [
  `s.loc[10:20]` on an index of 10, 20, 30 returns two rows, both
  endpoints included, because labels identify rows rather than counting
  them. `s.iloc[0:2]` over the same series returns two rows by the
  python convention, endpoint excluded. The sample pins both answers on
  the same index so the contrast is one red line if either changes.
])

#diagram([a frame as columns over one shared index, the two addressing doors, and the union rule], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(3.0, 7.0, 3.0, 2.6, [the index, #linebreak() mon tue wed], fill: luma(205))
  cell(6.6, 7.0, 4.2, 2.6, [temps, #linebreak() one column, #linebreak() float64])
  cell(11.4, 7.0, 4.2, 2.6, [labels, #linebreak() one column, #linebreak() str])
  cell(16.2, 7.0, 4.2, 2.6, [notes, #linebreak() one column, #linebreak() object or str])
  cdraw.content((10.5, 9.9), [a dataframe: named columns over one shared index], wrap: text.with(size: 6.5pt))
  cell(3.0, 4.2, 6.2, 1.5, [loc, by label, #linebreak() both endpoints included])
  cell(11.0, 4.2, 6.2, 1.5, [iloc, by position, #linebreak() endpoint excluded])
  cdraw.line((6.1, 7.0), (6.1, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.1, 7.0), (14.1, 5.7), stroke: luma(100), mark: (end: ">"))
  cell(3.0, 1.4, 6.2, 1.6, [a + b, #linebreak() aligns on the #linebreak() union of indexes], fill: luma(250))
  cell(11.0, 1.4, 6.2, 1.6, [gaps become nan, #linebreak() never silent #linebreak() reindexing], fill: luma(250))
  cdraw.line((6.1, 4.2), (6.1, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.1, 4.2), (14.1, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.6, 4.9), [`to_numpy` keeps #linebreak() the buffer], wrap: text.with(size: 6pt, fill: luma(100)))
})

== io and copy-on-write

The io doors round trip. `to_csv` and `read_csv` come back equal with
the text column re-inferred as str, `to_json` and `read_json` with
`orient="records"` come back equal the same way, and the sample does
both inside a `tempfile.mkdtemp` sandbox, no scratch files anywhere
else:

#listing("python/samples/src/Ch25/cowio.py", first: 11, last: 22, caption: [csv and json round trips, dtypes re-inferred, equality asserted])

The 3.0 behavior is copy-on-write, and the release notes state it as
two rules: "The result of _any_ indexing operation (subsetting a
DataFrame or Series in any way, i.e. including accessing a DataFrame
column as a Series) or any method returning a new DataFrame or Series,
always _behaves as if_ it were a copy in terms of user API", and as the
consequence, "if you want to modify an object (DataFrame or Series),
the only way to do this is to directly modify that object itself." The
user guide names the mechanism underneath: "A new lazy copy mechanism
that defers the copy until the object in question is modified and only
if this object shares data with another object." What that means in
checks: extracting a column and filling it in place changes the
extracted Series only, a slice write changes the slice only, and even
`copy(deep=False)` no longer aliases:

#listing("python/samples/src/Ch25/cowio.py", first: 25, last: 36, caption: [column, slice, and shallow copy writes all stay isolated under copy-on-write])

Chained assignment is the headline removal. The release notes: chained
assignment "will stop working. Because this now consistently never
works, the `SettingWithCopyWarning` is removed, and defensive `.copy()`
calls to silence the warning are no longer needed", and the user guide
adds that it will "raise a `ChainedAssignmentError` warning with CoW
enabled". The sample asserts the 3.0 semantics directly, the write
does not land and the warning fires, and then does the same edit the
supported way, one `loc` statement, which the guide states plainly:
"`loc` should be used as an alternative."

#listing("python/samples/src/Ch25/cowio.py", first: 39, last: 51, caption: [chained assignment never lands and warns, one loc statement lands])

The option that used to toggle all this is itself deprecated:
"Setting the option `mode.copy_on_write` no longer has any impact. The
option is deprecated and will be removed in pandas 4.0." Reading it
still answers True while warning. One keyword did disappear outright,
`fillna(method=...)` is gone in 3.0 and the method calls `ffill` and
`bfill` replace it:

#listing("python/samples/src/Ch25/cowio.py", first: 54, last: 67, caption: [the deprecated option still reads True, and fillna(method=) raises TypeError])

#diagram([before and after: the same four edits in the 2.x world and the 3.0 copy-on-write world], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((5.0, 9.2), [pandas 2.x, warnings and silent mutations], wrap: text.with(size: 6.5pt))
  cdraw.content((16.2, 9.2), [pandas 3.0, copy-on-write], wrap: text.with(size: 6.5pt))
  box(0.6, 6.9, 8.8, 1.5, [chained assignment, #linebreak() sometimes landed, always warned])
  box(0.6, 5.0, 8.8, 1.5, [column write propagated #linebreak() back into the frame])
  box(0.6, 3.1, 8.8, 1.5, [`copy(deep=False)` aliased, #linebreak() writes crossed])
  box(0.6, 1.2, 8.8, 1.5, [defensive `copy()` calls #linebreak() to silence warnings], fill: luma(245))
  box(12.0, 6.9, 8.8, 1.5, [never lands, #linebreak() ChainedAssignmentError])
  box(12.0, 5.0, 8.8, 1.5, [isolated, the frame #linebreak() never changes])
  box(12.0, 3.1, 8.8, 1.5, [lazy copy, defers #linebreak() until a write])
  box(12.0, 1.2, 8.8, 1.5, [one `loc` statement #linebreak() is the edit], fill: luma(245))
  cdraw.line((9.4, 7.6), (12.0, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.4, 5.7), (12.0, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.4, 3.8), (12.0, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.4, 1.9), (12.0, 1.9), stroke: luma(100), mark: (end: ">"))
})

#callout("warning", "old tutorials will hand you 2.x code", [
  The classic 2.x idiom `df["a"][0] = 5` looks executable and does
  nothing in 3.0 beyond raising a `ChainedAssignmentError` warning, so
  code copied from an older answer fails silently in the exact way the
  removal was designed to make loud. The supported forms are one
  statement each: `df.loc[0, "a"] = 5` for a cell, and
  `df.loc[mask, "a"] = 5` for a masked set. The sample pins that the
  chained form leaves `[1, 2, 3]` untouched while the `loc` form
  writes `[1, 0, 0]`.
])

== reshape and join

The working set for this section is one small sales frame, regions,
kinds, units, and prices, small enough to verify every reshape by hand.
`groupby` splits on keys, aggregates each group, and returns the keys
sorted, which is default behavior worth knowing because the pinned
expectations encode the sorted order, region e before n before s. The
named aggregation spells output columns directly, and a list of keys
builds a MultiIndex whose tuples are the groups:

#listing("python/samples/src/Ch25/reshape.py", first: 6, last: 14, caption: [the sales fixture, five rows, three keys])

#listing("python/samples/src/Ch25/reshape.py", first: 17, last: 34, caption: [groupby sum with as_index, named agg with total and avg, multi key tuples])

Joins come in two shapes. `merge` is the sql door, `how=` picks left,
inner, or outer, the outer form gains an `_merge` column through
`indicator=True` reporting left_only, both, or right_only per row, and
the output arrives sorted on the key. `join` aligns on the indexes.
`validate=` turns a relational assumption into an assertion, duplicate
keys under `one_to_one` raise `MergeError` instead of producing a
quietly exploded cross product:

#listing("python/samples/src/Ch25/reshape.py", first: 37, last: 47, caption: [left keeps rows with nan gaps, inner intersects, outer reports provenance])

#listing("python/samples/src/Ch25/reshape.py", first: 50, last: 61, caption: [join on the index, and validate refusing duplicate merge keys])

Wide and long are two layouts of one table. `pivot` widens, one column
per distinct key value, and refuses duplicate index pairs, `melt`
stacks back to long, and `pivot_table` aggregates where `pivot` would
refuse. The index algebra underneath is `set_index` promoting a column
and `reset_index` demoting it back, `concat` stacks frames with
`ignore_index` rebuilding positions, and the counting helpers,
`value_counts`, `nlargest`, and `sort_values`, answer the everyday
questions:

#listing("python/samples/src/Ch25/reshape.py", first: 64, last: 77, caption: [pivot widens with a hole where no data exists, melt stacks back, pivot_table aggregates])

#listing("python/samples/src/Ch25/reshape.py", first: 80, last: 94, caption: [set_index and reset_index, concat with ignore_index, counts and nlargest])

#diagram([the reshape pipeline: tidy frame to grouped totals to merged lookup to wide pivot and back], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.9, 4.0, 1.6, [tidy frame, #linebreak() one row per #linebreak() observation])
  box(6.0, 6.9, 4.0, 1.6, [groupby, #linebreak() split, aggregate, #linebreak() sorted keys])
  box(11.4, 6.9, 4.0, 1.6, [merge, #linebreak() how and validate])
  box(16.8, 6.9, 4.4, 1.6, [pivot, #linebreak() wide, one column #linebreak() per value])
  cdraw.line((4.6, 7.7), (6.0, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.0, 7.7), (11.4, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 7.7), (16.8, 7.7), stroke: luma(100), mark: (end: ">"))
  box(11.4, 4.0, 4.0, 1.6, [melt, #linebreak() back to long], fill: luma(250))
  cdraw.line((18.9, 6.9), (13.4, 5.6), stroke: luma(100), mark: (end: ">"))
  box(0.6, 4.0, 9.4, 1.6, [set_index and reset_index, #linebreak() promote a column, demote it back])
  box(12.4, 1.2, 8.8, 1.8, [counts, nlargest, sort, #linebreak() no reshape needed], fill: luma(245))
  box(0.6, 1.2, 9.4, 1.6, [concat stacks, ignore_index rebuilds positions], fill: luma(245))
  cdraw.line((5.3, 4.0), (5.3, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.4, 9.4), [the wide hole where no data #linebreak() exists is nan, never zero], wrap: text.with(size: 6pt, fill: luma(100)))
})

== time series and missing

A datetime index turns the frame into a time series, and 3.0 stamps it
at microsecond resolution by default, `datetime64[us]`, naive unless a
tz is attached. Forty-eight hourly stamps build with `date_range`,
`resample("D").sum()` folds them into two day buckets summing 276 and
852, and `rolling(3).mean()` slides a three point window that leads
with two nan because the first two windows are short:

#listing("python/samples/src/Ch25/timeseries.py", first: 7, last: 10, caption: [forty-eight hourly stamps, the working series])

#listing("python/samples/src/Ch25/timeseries.py", first: 28, last: 49, caption: [microsecond index, resample D, the rolling lead, partial and exact string indexing])

String indexing is the ergonomic win, `ts.loc["2026-09-08"]` selects
the whole day as a partial match, and a full timestamp string selects
one row. `shift` moves values down a slot, `diff` subtracts the
previous row, and the index itself answers calendar questions,
`dayofweek` is 0 for the monday this series starts on, with `day_name`
spelling it out.

#listing("python/samples/src/Ch25/timeseries.py", first: 50, last: 61, caption: [shift and diff against the previous row, and the calendar accessors])

Missing data has its own small toolbox. `isna` counts the holes,
`fillna` plugs them with a constant, `dropna` removes the rows that
carry them, and the three directional fills each mean something
different: `ffill` carries the last value forward, `bfill` borrows the
next value backward, and `interpolate` walks between the neighbors.
The method matters on irregular stamps, linear interpolation by
position would put 2.0 in the middle of a 1.0 and 3.0 gap, but
`method="time"` weighs the stamps, one day then three days, and lands
1.5:

#listing("python/samples/src/Ch25/timeseries.py", first: 12, last: 23, caption: [ffill, bfill, and interpolate, linear and time weighted])

#listing("python/samples/src/Ch25/timeseries.py", first: 64, last: 78, caption: [isna counts, fillna plugs, dropna removes])

#callout("pitfall", "interpolate linear and time disagree on uneven stamps", [
  On an index stamped one day, then three days apart, the gap value
  sits closer to the first stamp in time. Position-based interpolation
  answers 2.0, the midpoint of two positions, while
  `interpolate(method="time")` answers 1.5, the midpoint of the
  interval. The sample pins both numbers on the same data so the
  choice is visible as two different ok lines rather than a preference.
])

#diagram([forty-eight hourly points folded into two day buckets, a three point window with its two nan lead, and a gap filled three ways], length: 13pt, {
  let x_of(i) = { 4.2 + i * 0.34 }
  let y_of(v) = { 3.2 + v / 23 * 2.1 }
  let y2_of(v) = { 3.2 + (v - 684) / 168 * 2.1 }
  for i in range(24) {
    cdraw.circle((x_of(i), y_of(i)), radius: 0.07, fill: luma(90))
    cdraw.circle((x_of(i + 24), y2_of(852 - i * 7)), radius: 0.07, fill: luma(160))
  }
  cdraw.line((3.4, 3.2), (18.2, 3.2), stroke: luma(150) + 2.4pt)
  cdraw.content((2.0, 3.2), [0], wrap: text.with(size: 6pt))
  cdraw.content((1.6, 4.6), [values], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((8.2, 3.0), (8.2, 7.0), stroke: luma(140), dash: "dashed")
  cdraw.content((5.6, 7.4), [day one, 276], wrap: text.with(size: 6pt))
  cdraw.content((13.2, 7.4), [day two, 852], wrap: text.with(size: 6pt))
  cdraw.line((4.2, 5.6), (5.2, 5.6), stroke: luma(60) + 1.4pt, mark: (start: "|", end: "|"))
  cdraw.content((5.6, 6.4), [the 3 point window, #linebreak() two nan lead], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((19.0, 6.4), [a gap at 1.0 and 3.0], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 5.6), [ffill: 1.0, bfill: 3.0], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 4.8), [time: 1.5, linear: 2.0], wrap: text.with(size: 6pt))
  cdraw.content((10.6, 1.6), [resample D folds 48 stamps into 2 buckets, rolling keeps the shape and nan leads], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "33 checks, the pin asserted first", [
  A scoped run, `pwsh tools/run-py-samples.ps1 -Chapter Ch25`, walks
  the four samples through the run and format legs and reports: 4
  files, 33 checks, format clean. `frames.py` carries the interpreter
  and pandas pins and contributes 12, construction, the str default,
  both addressing doors with their endpoint rules, the union
  alignment, and the numpy handoff. `cowio.py` adds 6, both io round
  trips, the three isolation proofs, the chained assignment refusal
  with its warning, the deprecated option, and the removed keyword.
  `reshape.py` adds 5, groupby in its three forms, merge in its three
  joins with validation, pivot and melt, and the index algebra.
  `timeseries.py` adds 10, the resample and rolling numbers, string
  indexing, shift and diff, the four fills with the 1.5 against 2.0
  pair, and the calendar accessors. Every expected value was produced
  by this venv, then pinned.
])

sources: pandas.pydata.org/docs/whatsnew/v3.0.0.html (the dedicated
str dtype default and its pyarrow fallback sentence, the copy-on-write
summary rules, the chained assignment stop and SettingWithCopyWarning
removal, the mode.copy_on_write deprecation note),
pandas.pydata.org/docs/user_guide/copy_on_write.html (the
ChainedAssignmentError warning, the lazy copy mechanism, loc as the
alternative), both accessed 2026-09-12. The groupby key sort, the
outer merge sort order, the microsecond index resolution, the fillna
method removal, and every expected value probed on this machine under
the pinned venv the same day. Sample behavior verified by
`make verify-py`, 33 checks in chapter 25.
