#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= modules and jlink

Before java 9 the runtime was one monolithic `rt.jar` plus a flat
classpath. Every class was reachable from every other, the only
encapsulation was the package private keyword, and half the ecosystem
reached into `sun.misc.Unsafe` and friends, which is why the jdk could
not change its own internals for a decade. Java 9 shipped the java
platform module system, split the jdk itself into modules, and gave
the language a descriptor that states what a code unit requires, what
it offers, and what it keeps private. This chapter builds one module
live, breaks its boundary on purpose, analyzes it with jdeps, links it
into a custom runtime with jlink, and ends with the java 25 import
that shrinks module consumption to one line.

== the classpath world and the unnamed module

The classpath still exists and this book's own samples ride it. All
classpath code lands in the unnamed module, which reads every module
that exports an api and can be read by nobody in return. That is the
migration bridge: no module descriptor, no benefits, full
compatibility:

#listing("java/samples/src/Ch15/Modules.java", first: 59, last: 75, caption: [the sample asserting its own unnamed module facts])

The measured numbers on the pinned jdk 27: a classpath launch
resolves 61 modules into the boot layer, `java --list-modules`
observes 66, `java.base` requires nothing and exports 116 packages,
and the exporters among the `jdk.*` set, `jdk.httpserver`,
`jdk.crypto.cryptoki`, `jdk.crypto.ec`, are default roots, which is
why chapter 14's jwebserver probe needed no `--add-modules` flag.

== the descriptor

A module is a `module-info.java` at the source root. The ten words it
is built from, `module`, `requires`, `exports`, `opens`, `to`,
`uses`, `provides`, `with`, `open`, `transitive`, are restricted
keywords, tokens only inside the descriptor, so no variable named
`opens` anywhere breaks. The chapter's module states a dependency on
`java.net.http`, exports one api package, and binds a service to a
class in a package it does not export:

#listing("java/samples/src/Ch15/Modules.java", first: 81, last: 88, caption: [the greet descriptor: requires, exports, uses, provides])

Compilation turns it into `module-info.class`, bytecode metadata, not
a manifest convention. Running it is a module path launch, `java -p
out -m greet/greet.api.Main`, and the resolution happens before main:
the launcher reads the descriptor, pulls `java.net.http` and
`java.base` into the graph, and refuses to start if a require is
missing.

The boundary is real at compile time. A classpath class that says
`new greet.internal.SecretGreeter()` fails with `package
greet.internal is not visible`, because module greet does not export
that package, and the sample captures that exact diagnostic before
reopening it with the escape hatch, `--add-exports
greet/greet.internal=ALL-UNNAMED`, which compiles and runs the same
source. `--add-opens` is the reflective sibling, it allows
`setAccessible` into the package where `--add-exports` only allows
static references. Both are migration bandages, never shipped
configuration.

`exports` controls compile time and deep reflection is `opens`. An
`open module` opens every package, the honest first step when
migrating a reflection-heavy framework, and `opens some.package to
specific.module` narrows it back down. Chapter 16 returns to this
from the reflection side.

== services

The services mechanism solves the last gap: the point of an api
package is to hide implementations, but `new` needs the
implementation class reachable. `provides` declares the binding
inside the provider's own module, `uses` declares consumption, and
`ServiceLoader` does the lookup:

#listing("java/samples/src/Ch15/Modules.java", first: 108, last: 125, caption: [the main class loads the service and proves the required module is live])

The provider sits in `greet.internal`, unexported, unreachable by
import, and fully usable through the interface. Before modules the
same trick needed `META-INF/services` files on the classpath, which
still works, unnamed module code reads those, but the descriptor form
carries the contract where the compiler and the linker can see it.

== jdeps and jlink

Two jdk tools consume the descriptor. `jdeps` is static analysis: it
reads bytecode, reports package and module dependencies, and its
`-m greet` run against the built module prints the `java.net.http`
edge and both packages, the exported and the hidden. It is the tool
for the migration question, what does this jar actually need.

`jlink` assembles modules into a custom runtime image, a directory
with its own `bin/java`, that runs with no installed jdk:

#listing("java/samples/src/Ch15/Modules.java", first: 192, last: 216, caption: [linking the image, counting it, and running it])

Measured on this machine, 2026-10-04: the greet image is 51.5 mb
against the full 369.2 mb jdk, and its `bin` holds 3 executables,
`java`, `keytool`, and the `greet` launcher script the
`--launcher greet=greet/greet.api.Main` option writes. The module
path is the compiled module plus the jdk's own `jmods` directory,
because jlink links platform modules too. The image is the deployment
story for cli tools and containers, and it only exists because
modules made the dependency graph explicit enough to trace.

== module import declarations

Java 25 finalized module import declarations (JEP 511, previewed in
23 and 24): `import module java.base;` imports every public top level
type of every package the module exports, so the 54 package imports a
`java.base`-heavy file needs collapse to one line:

#listing("java/samples/src/Ch15/Modules.java", first: 230, last: 238, caption: [one import line replaces the per-package imports, final since 25])

The sample compiles it live with the in-process compiler. Two rules
keep it predictable: single type imports shadow module imports, so an
ambiguous simple name like `Date`, `java.util` versus `java.sql`, is
resolved by writing the specific import you mean, and `import module
java.se` fails in classpath code because `java.se` is not a default
root for the unnamed module. Classpath code can import named modules,
never the unnamed one back.

#callout("note", "modules at this book's scale", [
  The service spine in chapters 19 through 31 runs on the classpath
  like these samples do, one `jdk.httpserver` application with no
  descriptor, because a single-module application gains nothing from
  describing itself. Modules pay off the moment a codebase splits
  into parts that must not see each other, or ships as a jlink image.
])

sources: Java in a Nutshell 8th edition, chapters 12 (Java Platform
Modules) and 13 (Platform Tools: jdeps, jlink, jar) for the
8-through-17 grounding, rewritten here, openjdk.org/jeps/511 (module
import declarations final in 25, preview history 23 and 24) and
openjdk.org/projects/jdk/9 (the jep 261 module system, jshell, and
jlink landing) accessed 2026-10-04. Behavior verified live on
`tools/jdk27/build/jdk-27` by the Ch15 sample under `pwsh
tools/run-java-samples.ps1 -Chapter Ch15`: 28 checks covering the
unnamed module facts, the compile, run, encapsulation refusal with
its exact diagnostic, the add-exports reopening, jdeps output, the
51.5 mb image running headless, and the module import compile, all
dated 2026-10-04.
