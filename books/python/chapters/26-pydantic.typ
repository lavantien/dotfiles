#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= pydantic

This chapter teaches pydantic before #xref-to("python", "fastapi") and
#xref-to("python", "capstone1") build on it, because in both places it
plays the same role: the boundary where untrusted dictionaries become
typed objects or loud failures. The version is 2.13.4, pinned in the
book's requirements file and asserted from inside the first sample,
the second major line of the library, the one with the rust core under
the `pydantic-core` package. The stdlib shapes of
#xref-to("python", "dataclasses") and #xref-to("python", "typing") are
the raw material, annotations on a class, and pydantic turns those
annotations into a validator and a serializer. Every behavioral claim
below is an ok line in the four samples, 25 in total, or a sentence
quoted from the pydantic documentation fetched 2026-09-12.

== basemodel and validation

The manual defines the object in one sentence: "Models are simply
classes which inherit from BaseModel and define fields as annotated
attributes", and the behavior in two more: "Initialization of the
object will perform all parsing and validation", and "Pydantic will
raise a ValidationError exception whenever it finds an error in the
data it's validating." The error is collected, not thrown at the first
offense: "A single exception will be raised regardless of the number
of errors found", and that exception "will contain information about
all of the errors and how they happened". The sample feeds one bad id
and one bad email in the same constructor and gets both back, with
the error surface pinned key for key:

#listing("python/samples/src/Ch26/models.py", first: 77, last: 83, caption: [the chapter contract: the interpreter pin, then the pydantic 2.13.4 pin asserted in-sample])

#listing("python/samples/src/Ch26/models.py", first: 10, last: 26, caption: [three models: plain fields, Field constraints, strict mode, extra=forbid])

#listing("python/samples/src/Ch26/models.py", first: 29, last: 41, caption: [two errors collected at once, each with type, loc, msg, input, and a docs url])

Each error row is a dict with five keys on this version, `input`,
`loc`, `msg`, `type`, and `url`, where `loc` paths into the model and
`url` points at the error's page under errors.pydantic.dev. Some types
add a sixth `ctx` key; `int_parsing` does not. The exception itself
carries `title`, the class name, and `error_count()`. Lax mode is the
default and coerces on the way in, the string "42" becomes the int
42, while `ConfigDict(strict=True)` flips the same input to an
`int_type` error. Constraints live in `Field`: `ge` and `le` bound a
number, an absent required field reports type `missing`, and
`extra="forbid"` turns unknown keys into `extra_forbidden` errors.
Dict entry points run the same machinery, `model_validate` "Validates
the given object against the Pydantic model" and `model_validate_json`
"Validates the given JSON data against the Pydantic model":

#listing("python/samples/src/Ch26/models.py", first: 44, last: 58, caption: [a missing field reports missing, a bounds violation reports less_than_equal])

#listing("python/samples/src/Ch26/models.py", first: 61, last: 74, caption: [strict rejects the string 5, extra keys are forbidden])

#listing("python/samples/src/Ch26/models.py", first: 85, last: 108, caption: [coercion, constraint, strict, forbid, and model_validate, as the run sees them])

#diagram([validation as a state machine: parse each field, collect every failure, hand back one instance or one error with all rows], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 7.6, 4.4, 1.4, [a dict or #linebreak() a json string])
  box(6.6, 7.6, 4.6, 1.4, [parse field one, #linebreak() coerce or reject])
  box(12.8, 7.6, 4.6, 1.4, [parse field two, #linebreak() and so on])
  box(19.0, 7.6, 2.4, 1.4, [done])
  cdraw.line((5.0, 8.3), (6.6, 8.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.2, 8.3), (12.8, 8.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.4, 8.3), (19.0, 8.3), stroke: luma(100), mark: (end: ">"))
  box(12.8, 4.6, 4.6, 1.5, [failures collected, #linebreak() none raise early], fill: luma(250))
  cdraw.line((8.9, 7.6), (14.0, 6.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((15.1, 7.6), (15.1, 6.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  box(2.0, 4.6, 6.0, 1.5, [all fields pass])
  cdraw.line((20.2, 7.6), (20.2, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.2, 5.35), (19.0, 5.35), stroke: luma(100), mark: (end: ">"))
  box(2.0, 1.8, 8.2, 1.5, [the instance, #linebreak() typed and trusted])
  box(12.4, 1.8, 8.2, 1.5, [one ValidationError, #linebreak() a row per failure])
  cdraw.line((5.1, 4.6), (5.1, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.1, 4.6), (15.1, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.1, 0.8), [loc paths in, #linebreak() type names, #linebreak() docs urls out], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((15.1, 0.8), [title and error_count, #linebreak() errors() is a plain list], wrap: text.with(size: 6pt, fill: luma(100)))
})

== serializers and json

The dump side mirrors the validate side. The manual: "Pydantic allows
models (and any other type using type adapters) to be serialized in
two modes: Python and JSON", and the difference is that "The Python
output may contain non-JSON serializable data", a datetime stays a
datetime, while `mode="json"` and `model_dump_json()` produce
json-safe values, the datetime becoming its iso string. The knobs are
part of the daily vocabulary: `exclude_none` drops the None fields,
`Field(exclude=True)` removes a field from every dump, and
`TypeAdapter` extends the same machinery to types that are not models,
`TypeAdapter(list[int]).validate_python(["1", "2"])` answering
`[1, 2]`:

#listing("python/samples/src/Ch26/serial.py", first: 50, last: 58, caption: [python mode keeps the datetime, json mode strings it, the excluded field never appears])

#listing("python/samples/src/Ch26/serial.py", first: 61, last: 69, caption: [model and TypeAdapter json round trips land exactly])

Custom checks hang off annotations. The modern form composes:
`Annotated[str, AfterValidator(strip_lower)]` is a type with a function
attached, reusable anywhere a type goes. The model-scoped forms are
`field_validator`, which sees one field plus the already validated
ones through `info.data`, and `model_validator(mode="after")`, which
sees the whole instance and is the only place a cross field rule can
be checked honestly:

#listing("python/samples/src/Ch26/serial.py", first: 17, last: 30, caption: [a model with an excluded field, and an annotated validator as a reusable type])

#listing("python/samples/src/Ch26/serial.py", first: 32, last: 47, caption: [field_validator for one field, model_validator after for the pair])

The schema is a free byproduct: `model_json_schema()` emits plain json
schema, `gt` surfacing as `exclusiveMinimum`, `ge` and `le` as
`minimum` and `maximum`, and a plain int field spelling nothing more
than type integer with a title. Two escape hatches complete the
picture: `model_copy(update=...)` rebinds fields without revalidating,
and `model_construct` builds an instance with no validation at all,
useful for trusted fast paths and dangerous everywhere else:

#listing("python/samples/src/Ch26/serial.py", first: 85, last: 99, caption: [schema bounds as json schema keys, model_copy updating, model_construct skipping validation])

#diagram([the serializer pipeline: instance to python dict to json text and back, with the knobs on the side], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.9, 4.0, 1.6, [the instance, #linebreak() typed fields])
  box(6.2, 6.9, 4.6, 1.6, [a python dict, #linebreak() `model_dump()`])
  box(12.2, 6.9, 4.6, 1.6, [json text, #linebreak() `model_dump_json()`])
  box(18.2, 6.9, 3.2, 1.6, [back again, #linebreak() validate_json])
  cdraw.line((4.6, 7.7), (6.2, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.8, 7.7), (12.2, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 7.7), (18.2, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.8, 6.9), (3.0, 5.4), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((6.6, 4.9), [the round trip lands exactly], wrap: text.with(size: 6pt, fill: luma(100)))
  box(0.6, 2.9, 6.4, 1.5, [`exclude_none`, #linebreak() `mode="json"`])
  box(7.8, 2.9, 6.4, 1.5, [`Field(exclude=True)`, #linebreak() secrets stay out])
  box(15.0, 2.9, 6.4, 1.5, [`TypeAdapter` for types, #linebreak() `Annotated` validators])
  cdraw.line((3.8, 4.4), (3.8, 5.4), stroke: luma(140), dash: "dashed")
  cdraw.line((11.0, 4.4), (11.0, 5.4), stroke: luma(140), dash: "dashed")
  cdraw.line((18.2, 4.4), (18.2, 5.4), stroke: luma(140), dash: "dashed")
  cdraw.content((11.0, 1.3), [model_copy updates without validating, model_construct skips validation entirely], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== composed models

Fields annotated with other models compose by recursion, and the error
locs show the path: an Outer holding one Inner and a list of them
reports failures at `('inner', 'x')` and `('items', 1, 'x')`, the
list index sitting in the path between the field and the inner field.
Defaults stay per instance, `Field(default_factory=list)` builds a
fresh list each time, and `model_fields_set` records exactly which
fields the input provided, empty for an all defaults construction:

#listing("python/samples/src/Ch26/composed.py", first: 8, last: 15, caption: [a model nested in a model, and a list of them])

#listing("python/samples/src/Ch26/composed.py", first: 55, last: 65, caption: [error locs path into the tree, the list index in the middle])

#listing("python/samples/src/Ch26/composed.py", first: 87, last: 94, caption: [default_factory builds fresh lists, model_fields_set records what was set])

Unions of models have two dispatch strategies. The plain union tries
members left to right, first match wins, which works until two members
share a shape. The discriminated union is the routing answer, and the
manual introduces it under the name it also carries: "sometimes
referred to as 'Tagged unions'", where the union is "validated more
efficiently using a discriminator, by specifically choosing which
member of the union", which "makes validation more efficient and also
avoids a proliferation of errors when validation fails". The tag is a
Literal field common to every member, `Field(discriminator="kind")`
names it, and the failures get their own error types, `union_tag_not_found`
when the tag is absent and `union_tag_invalid` when it names no
member:

#listing("python/samples/src/Ch26/composed.py", first: 17, last: 38, caption: [cat and dog share the literal tag kind, the discriminator routes, the plain union does not])

#listing("python/samples/src/Ch26/composed.py", first: 67, last: 84, caption: [routing by tag, union_tag_invalid for fish, union_tag_not_found for a missing tag])

Computed state can join the dump. A property alone is invisible to
serialization, decorating it with `computed_field` puts it in
`model_dump()` output, the rectangle's area riding along with its
width and height:

#listing("python/samples/src/Ch26/composed.py", first: 40, last: 47, caption: [a computed_field lands in the dump, a plain property does not])

#diagram([the composed tree with its error paths, and the discriminator routing one payload to exactly one member], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 7.4, 5.4, 1.6, [Outer], fill: luma(205))
  box(8.6, 7.4, 4.6, 1.6, [inner: Inner])
  box(15.6, 7.4, 5.6, 1.6, [items: list of Inner])
  cdraw.line((6.0, 8.2), (8.6, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.2, 8.2), (15.6, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.9, 6.6), [loc: inner dot x], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((18.4, 6.6), [loc: items, 1, x], wrap: text.with(size: 6pt, fill: luma(100)))
  box(0.6, 3.4, 5.4, 1.6, [a payload with a kind])
  box(8.6, 5.0, 4.6, 1.4, [kind is cat], fill: luma(250))
  box(8.6, 3.4, 4.6, 1.4, [kind is dog], fill: luma(250))
  box(8.6, 1.8, 4.6, 1.4, [kind is fish])
  cdraw.line((6.0, 4.2), (8.6, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 4.2), (8.6, 4.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 4.2), (8.6, 2.5), stroke: luma(100), mark: (end: ">"))
  box(15.6, 5.0, 5.6, 1.4, [Cat validates])
  box(15.6, 3.4, 5.6, 1.4, [Dog validates])
  box(15.6, 1.8, 5.6, 1.4, [union_tag_invalid])
  cdraw.line((13.2, 5.7), (15.6, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.2, 4.1), (15.6, 4.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.2, 2.5), (15.6, 2.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.3, 1.6), [one member runs, #linebreak() never all of them], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((19.0, 0.5), [a missing tag reports union_tag_not_found], wrap: text.with(size: 6pt, fill: luma(100)))
})

== boundaries and pins

Three boundaries close the chapter, each stated rather than sampled
past its edge. The first is the v1 history. Pydantic v1 was the
2018 to 2022 line, single implementation in python, and v2 arrived in
mid 2023 rewritten over a rust core with the `model_` method names
this chapter uses. The 2.13 package still ships a frozen copy of v1
as the `pydantic.v1` subpackage, reached by importing it, `from
pydantic import v1`, not by attribute access, and a v1 BaseModel
defined from it still coerces the way v1 did, the string "7" becomes
7 in both lines. Migration errors point at
errors.pydantic.dev/2.13/migration, the same host the validation
error urls use:

#listing("python/samples/src/Ch26/bounds.py", first: 19, last: 30, caption: [the v1 namespace imports as a subpackage and still coerces like v1])

The second boundary is settings. `pydantic-settings` is a separate
package, env var and secrets loading over a BaseModel, and it is not
in this book's pins, so the chapter states it and stops. The
#xref-to("python", "plumbing") chapter covers environment handling
with the stdlib, which is the pattern the capstone actually uses.

#listing("python/samples/src/Ch26/bounds.py", first: 32, last: 44, caption: [settings absent by pin, and the dataclass storing what the model would reject])

The third boundary is the dataclass trade-off. A dataclass with `x:
int` stores whatever arrives, the string "42" stays a string, while a
BaseModel validates and coerces on construction. #xref-to("python",
"dataclasses") is the right tool for trusted internal records where
the annotation is documentation, pydantic is the right tool at
boundaries where the data has not been earned. The schema is the
tiebreaker that usually decides it: json schema for free, or none:

#listing("python/samples/src/Ch26/bounds.py", first: 46, last: 65, caption: [the schema is type, properties, required, title, and the checks as the run sees them])

#diagram([the tool matrix: dataclasses, pydantic v2, the v1 namespace, and pydantic-settings against what validates and what this book pins], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 7.6, 5.4, 1.3, [tool], fill: luma(205))
  cell(6.6, 7.6, 7.6, 1.3, [validates on construction], fill: luma(205))
  cell(14.6, 7.6, 6.8, 1.3, [status in this book], fill: luma(205))
  cell(0.6, 5.9, 5.4, 1.4, [dataclass])
  cell(6.6, 5.9, 7.6, 1.4, [no, annotations are docs])
  cell(14.6, 5.9, 6.8, 1.4, [pinned chapter 9])
  cell(0.6, 4.2, 5.4, 1.4, [BaseModel, v2])
  cell(6.6, 4.2, 7.6, 1.4, [yes, coerces, collects errors])
  cell(14.6, 4.2, 6.8, 1.4, [pinned 2.13.4, this chapter])
  cell(0.6, 2.5, 5.4, 1.4, [`pydantic.v1`])
  cell(6.6, 2.5, 7.6, 1.4, [yes, the old rules])
  cell(14.6, 2.5, 6.8, 1.4, [frozen inside 2.13.4])
  cell(0.6, 0.8, 5.4, 1.4, [pydantic-settings])
  cell(6.6, 0.8, 7.6, 1.4, [yes, over env and files])
  cell(14.6, 0.8, 6.8, 1.4, [not pinned, stated], fill: luma(245))
})

#callout("verify", "25 checks, the pin asserted first", [
  A scoped run, `pwsh tools/run-py-samples.ps1 -Chapter Ch26`, walks
  the four samples through the run and format legs and reports: 4
  files, 25 checks, format clean. `models.py` carries the interpreter
  and pydantic pins and contributes 9, the collected error surface
  with its keys and urls, missing and bounds error types, strict and
  forbid modes, and `model_validate`. `serial.py` adds 6, both dump
  modes with the exact json string, round trips through the adapter,
  the annotated and scoped validators, schema bounds, and the two
  escape hatches. `composed.py` adds 6, nested locs, discriminator
  routing with both tag error types, the plain union order, defaults
  with `model_fields_set`, and the computed field in the dump.
  `bounds.py` adds 4, the v1 namespace, the settings absence, the
  dataclass contrast, and the schema shape. Every expected value was
  produced by this venv, then pinned.
])

sources: pydantic.dev/docs/validation/latest/concepts/models/ (the
BaseModel definition, initialization performing parsing and
validation, the single collected ValidationError, model_validate and
model_validate_json), pydantic.dev/docs/validation/latest/concepts/unions/
(tagged unions, the discriminator choosing one member, the efficiency
and error claims), pydantic.dev/docs/validation/latest/concepts/serialization/
(the two serialization modes, python output holding non-json data),
all accessed 2026-09-12. The error row keys, the v1 import path and
its coercion, the pydantic-settings absence, and every expected value
probed on this machine under the pinned venv the same day. Sample
behavior verified by `make verify-py`, 25 checks in chapter 26.
