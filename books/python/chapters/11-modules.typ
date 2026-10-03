#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= modules, packages, and imports

Every file this book has run so far was one module named `__main__` and
the import statement never appeared. This chapter is about everything
the import statement does. A module is an object, a package is a module
with a `__path__`, an import is a lookup in a cache followed, on a
miss, by a walk through finders and loaders that ends with compiled
bytecode in `__pycache__`. The same machinery decides whether a
project layout works before it is installed, and the same cache is why
circular imports fail loudly instead of quietly. The verification mode
is the book's gate, #xref-to("python", "toolchain"): the three samples
under `Ch11/` run under cpython 3.14 and print 31 `ok` lines in total,
and every behavioral claim below is one of those checks or a sentence
from a canonical page fetched 2026-09-12.

== modules and packages

The reference fixes the object model first: "Python has only one type
of module object, and all modules are of this type, regardless of
whether the module is implemented in Python, C, or something else."
What separates the species is data, not type. A plain module carries
`__name__`, `__file__`, and a `__spec__` describing how it was found
and loaded. A package is the same object plus `__path__`, and a
regular package is a directory whose `__init__.py` body becomes the
package module's body. The sample builds one such directory at
runtime, inside a `tempfile.mkdtemp()` tree, and reaches into it by
putting its parent on `sys.path`:

#listing("python/samples/src/Ch11/modules_basics.py", first: 20, last: 33, caption: [a regular package assembled at runtime: the `__init__` body imports from a submodule and declares `__all__`])

The `__init__` runs once, at first import, and what it imports
becomes attributes of the package. The sample asserts the whole chain:
the marker lands, the relative import inside `__init__` succeeds, and
`shapes.circle` is reachable both as an attribute of the package and
as an entry of `sys.modules` under its dotted name. The reference
states the binding rule as a rule: "When a submodule is loaded using
any mechanism (e.g. importlib APIs, the import or import-from
statements, or built-in `__import__()`) a binding is placed in the
parent module's namespace to the submodule object." That is why
`import shapes.circle` in one module makes `shapes.circle` reachable
everywhere the package object travels:

#listing("python/samples/src/Ch11/modules_basics.py", first: 36, last: 45, caption: [first import runs `__init__` once, the second import returns the identical object])

The identity check is the cache at work. The `sys` documentation
describes the dictionary: "This is a dictionary that maps module
names to modules which have already been loaded. This can be
manipulated to force reloading of modules and other tricks." Evicting
both entries and importing again really does rebuild the object, which
the sample checks, and which is also the honest limit of the trick:
the reference warns that "deleting essential items from the dictionary
may cause Python to fail." The supported spelling of a reload in
running code is `importlib.import_module`, which the sample uses after
the eviction:

#listing("python/samples/src/Ch11/modules_basics.py", first: 83, last: 96, caption: [evicting the cache entries and rebuilding the package through importlib])

#diagram([a package as stacked layers: files on disk, one body that runs once, one object that persists], length: 13pt, {
  let layer(y, t, fill: luma(235)) = {
    cdraw.rect((2.0, y), (14.6, y + 1.15), fill: fill, radius: 0.02)
    cdraw.content((8.3, y + 0.57), t, wrap: text.with(size: 6pt))
  }
  layer(7.3, [shapes\/ directory on disk: \_\_init\_\_.py, circle.py], fill: luma(205))
  layer(6.0, [the \_\_init\_\_ body executes once at first import])
  layer(4.7, [the package module object: \_\_name\_\_, \_\_file\_\_, \_\_path\_\_, \_\_spec\_\_])
  layer(3.4, [sys.modules["shapes"] and "shapes.circle"], fill: luma(215))
  cdraw.content((18.3, 7.5), [submodules become, #linebreak() package attributes], wrap: text.with(size: 6pt))
  cdraw.content((18.3, 5.2), [one object per name,, #linebreak() identity from the cache], wrap: text.with(size: 6pt))
  cdraw.content((18.3, 3.6), [eviction plus re-import, #linebreak() builds a new object], wrap: text.with(size: 6pt))
  cdraw.content((8.3, 1.9), [a package is a module plus \_\_path\_\_, the type never changes], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((8.3, 0.9), [the body runs at import time, so keep it cheap: heavy work belongs in submodules], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the import system

An import statement is a cache probe. On a hit in `sys.modules` the
statement binds the cached object and nothing else happens, not even a
stat of the file on disk. On a miss the machinery walks `sys.meta_path`,
and the sample checks the order it finds there: the builtin importer,
the frozen importer, then the path finder. The builtin entry explains
a spec the sample reads off `sys`: a compiled-in module reports
`origin == "built-in"` with `BuiltinImporter` as its loader, while a
filesystem module like `json` reports the real path of its
`__init__.py`. A name nothing can find produces `find_spec` returning
`None`, which is how the machinery says the name does not exist before
the import statement turns that into `ModuleNotFoundError`:

#listing("python/samples/src/Ch11/import_machinery.py", first: 67, last: 90, caption: [the meta path order and three find\_spec outcomes: builtin, path, missing])

A finder returns a spec, and a loader consumes it. The full sequence
is visible without any import statement at all through `importlib`:
`spec_from_file_location` builds the spec for a file that is not on
any path, `module_from_spec` allocates the module object, and
`exec_module` runs the body. This is the programmatic form of the
statement, and it is the honest answer to "how do i load a plugin from
a path the user gave me":

#listing("python/samples/src/Ch11/import_machinery.py", first: 92, last: 102, caption: [loading a file that no finder would reach, spec, module, exec])

The `__main__` guard exists because of how the same file can run. Run
with `-m shapes.cli`, the module's `__name__` is `__main__` and its
`__package__` is `shapes`, so the relative import inside it resolves.
Run as a bare path, `python shapes\cli.py`, the package context is
gone and the identical relative import dies with "attempted relative
import with no known parent package". The sample runs both forms as
children and asserts both outcomes:

#listing("python/samples/src/Ch11/import_machinery.py", first: 47, last: 65, caption: [the same file both ways: -m carries the package, the bare path loses it])

Circular imports break on the cache, not on the cycle. While
`circular.a` is still executing, `sys.modules["circular.a"]` already
holds the half-built module, so `from .a import A_VAL` inside `b` finds
the module but not the name, and the error names the situation
exactly: "cannot import name 'A_VAL' from partially initialized
module". The fix is not a deeper import, it is ordering: define the
name before importing the other side, and import the module rather
than the name so the attribute read happens after both sides exist:

#listing("python/samples/src/Ch11/import_machinery.py", first: 104, last: 130, caption: [the broken pair and the fixed pair, the difference is definition order plus module imports])

#callout("pitfall", "the half-built module is already in the cache", [
  The failing import does not leave `sys.modules` clean in the middle
  of the cycle. The parent under construction sits in the cache with
  whatever attributes it has defined so far, which is exactly why
  `from .a import X` fails while `from . import a` succeeds and
  `a.X` read later works. Retrying a broken circular import inside
  an `except` clause often appears to fix it because the second
  attempt finds the completed module. That is luck wearing a lab coat,
  not a design: reorder the definitions instead.
])

#diagram([one import statement as a state walk: cache probe, meta path, spec, execution, binding], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 7.4, 4.6, [import shapes.circle], fill: luma(205))
  box(6.4, 7.4, 4.6, [sys.modules lookup])
  box(12.2, 7.4, 4.6, [bind the object], fill: luma(215))
  box(6.4, 5.6, 4.6, [sys.meta_path walk])
  box(6.4, 3.8, 4.6, [finder returns a spec])
  box(6.4, 2.0, 4.6, [loader.exec\_module])
  box(12.2, 2.0, 4.6, [store in sys.modules], fill: luma(215))
  cdraw.line((5.2, 7.9), (6.4, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 7.9), (12.2, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.7, 7.4), (8.7, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.1, 7.0), [miss], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((8.7, 5.6), (8.7, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.7, 3.8), (8.7, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 2.5), (12.2, 2.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.5, 2.0), (14.5, 1.2), (8.7, 1.2), (8.7, 2.0), stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  cdraw.content((19.9, 7.9), [hit: nothing, #linebreak() else executes], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((19.9, 4.6), [builtin, frozen, #linebreak() then path finder], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((19.9, 2.5), [the body runs here, #linebreak() cycles break inside it], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((8.7, 0.4), [every step is reachable: importlib.find\_spec, module\_from\_spec, exec\_module], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== project layout

The layout question is which directories the path finder will see and
when. The flat layout puts the import packages beside `pyproject.toml`
at the top of the repository. The src layout moves them down one
level, and the packaging guide names the trade: "The src layout helps
prevent accidental usage of the in-development copy of the code",
because "the Python interpreter includes the current working directory
as the first item on the import path", so a test run from the
repository root can import code the build would never ship. The cost
is stated just as plainly: "The src layout requires installation of
the project to be able to run its code, and the flat layout does
not." This book's own tree is flat by necessity, the samples are run
as files from their directory and never installed, and the gate pins
that fact.

`pyproject.toml` is where a project states its build requirements and
metadata, and this chapter treats it the way the cloud book treats
terraform state: the file is real, documented, and never executed
here. Nothing in this corpus builds a wheel, so every claim about
what a build backend does with the file is a citation, not a check.
Editable installs sit on the same boundary and earn the same
sentence: "The src layout helps enforce that an editable installation
is only able to import files that were meant to be importable", which
is the documented reason to prefer it once installation enters the
workflow at all.

Namespace packages are the layout question the filesystem answers on
its own. The reference defines them: "A namespace package is a
composite of various portions, where each portion contributes a
subpackage to the parent package. Portions may reside in different
locations on the file system." No `__init__.py` anywhere, `__file__`
is absent, `__spec__.origin` is `None`, and `__path__` spans every
portion. The sample assembles two portions under two separate
`sys.path` roots and imports from both:

#listing("python/samples/src/Ch11/namespace_pkgs.py", first: 20, last: 48, caption: [two portions on two path entries, one package with no \_\_init\_\_ anywhere])

Precedence is the trap. The path finder scans `sys.path` in order,
and a regular package on an earlier entry ends the search before any
portion is collected. The sample plants a regular `fused` ahead of
the namespace, evicts the cache, and the winner is the `__init__`
version with a real `__file__`. Remove the regular package from the
path and evict again, and the namespace comes back:

#listing("python/samples/src/Ch11/namespace_pkgs.py", first: 58, last: 84, caption: [a regular package earlier on sys.path shadows the namespace, eviction restores it])

#diagram([layout as a decision: what the path finder does with a directory it is handed], length: 13pt, {
  let q(x, y, t) = cdraw.content((x, y), t, wrap: text.with(size: 6pt))
  cdraw.rect((0.6, 6.6), (8.2, 8.4), fill: luma(215), radius: 0.02)
  q(4.4, 7.5, [a directory named like the import])
  cdraw.rect((0.4, 4.2), (4.2, 5.8), fill: luma(235), radius: 0.02)
  q(2.3, 5.3, [has \_\_init\_\_.py])
  cdraw.rect((4.6, 4.2), (8.4, 5.8), fill: luma(235), radius: 0.02)
  q(6.5, 5.3, [no \_\_init\_\_.py])
  cdraw.line((3.4, 6.6), (2.3, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.4, 6.6), (6.5, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 1.4), (4.2, 3.4), fill: luma(245), radius: 0.02)
  q(2.3, 2.6, [regular package])
  q(2.3, 1.9, [search ends here])
  cdraw.rect((4.6, 1.4), (8.4, 3.4), fill: luma(245), radius: 0.02)
  q(6.5, 2.6, [namespace portion])
  q(6.5, 1.9, [keep scanning the path])
  cdraw.line((2.3, 4.2), (2.3, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.5, 4.2), (6.5, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.4, 3.6), (21.8, 6.4), fill: luma(235), radius: 0.02)
  q(16.1, 5.7, [later portions join the same \_\_path\_\_])
  q(16.1, 4.9, [an earlier regular package shadows all of them])
  q(16.1, 4.1, [\_\_file\_\_ None, origin None, NamespaceLoader])
  cdraw.line((8.4, 2.4), (10.4, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 8.6), [flat layout: importable beside the config, src layout: one level down, install first], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 0.6), [pyproject.toml metadata is documentation-verified in this book, no wheel is ever built], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== environments and pins

The interpreter is the first pin. The gate resolves cpython through
the py launcher, asserts the exact version before running anything,
and refuses to use the 3.13 that also lives on this machine, which is
why every sample in this book behaves identically wherever the tree
is checked out. Above the interpreter sit the environments: a `venv`
is a directory with its own `pyvenv.cfg` and its own site-packages, a
place where `pip` can install without touching the per-user python,
and the third-party chapters, fastapi, numpy, pandas, and pydantic,
each assert the exact pinned version of their library inside the
sample itself, so the run fails the moment the installed library
drifts.

A requirements file is the portable form of that discipline. The pip
documentation states what it is: "Requirements files serve as a list
of items to be installed by pip, when using pip install." The
specifier grammar is shared with the command line, and the pin form
this book uses wherever it pins at all is the double equals, `==`,
which the grammar reads as an exact version. The stdlib chapters,
including this one, carry no requirements beyond the interpreter
because they import nothing outside it, and that absence is itself
checked: every sample in `Ch11/` imports only the standard library.

#callout("note", "ruff formats, it does not verify", [
  The gate runs ruff over the samples as a formatting and lint pass,
  not as a correctness claim. The `ok N` lines are the correctness
  claims, one per check, counted by the harness. Formatting and truth
  are different services: ruff reflowing a line can move a listing
  pin in this book, which is why listings name exact line ranges and
  the tree re-pins rather than hand-editing slices.
])

#diagram([the pin chain from interpreter to a green gate run], length: 13pt, {
  let stage(x, w, t, sub, fill: luma(235)) = {
    cdraw.rect((x, 5.2), (x + w, 7.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, 6.4), t, wrap: text.with(size: 6pt))
    cdraw.content((x + w / 2, 5.7), sub, wrap: text.with(size: 6pt))
  }
  stage(0.6, 4.6, [py launcher], [resolves 3.14, not 3.13], fill: luma(205))
  stage(6.0, 4.6, [venv], [own site-packages])
  stage(11.4, 4.6, [pip install -r], [requirements.txt, == pins])
  stage(16.8, 4.6, [the gate], [runs samples, counts ok lines], fill: luma(205))
  cdraw.line((5.2, 6.1), (6.0, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.6, 6.1), (11.4, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, 6.1), (16.8, 6.1), stroke: luma(100), mark: (end: ">"))
  let note(x, t) = cdraw.content((x, 3.9), t, wrap: text.with(size: 6pt, fill: luma(100)))
  note(2.9, [version asserted first])
  note(8.3, [no global installs])
  note(13.7, [third-party chapters only])
  note(19.1, [ruff formats after])
  cdraw.content((11.7, 2.2), [stdlib chapters pin nothing but the interpreter: every import is standard], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.7, 1.1), [drift is loud: a changed version fails the sample, a changed interpreter fails the gate], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "what a green run of this chapter proves", [
  The three samples print 31 `ok` lines: module and package identity,
  the cache, spec and loader facts, the `-m` versus bare path split,
  both halves of the circular import pair, and the namespace package
  spanning, shadowing, and restoration. A green run proves those
  checks passed on cpython 3.14.7 on this machine, nothing wider.
])

sources: docs.python.org/3.14 reference/import (module objects,
packages, namespace packages, submodule binding, meta path),
library/sys (sys.modules), library/importlib (find\_spec,
spec\_from\_location, import\_module), pep 420, and
packaging.python.org src-layout-versus-flat-layout and
requirements-file-format pages on pip.pypa.io, all accessed
2026-09-12. Sample behavior verified by `make verify-py`, 31 checks in chapter 11.
