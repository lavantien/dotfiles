// keyword coverage matrix, enumerated from the java language spec se 27
// s3.9 (docs.oracle.com/javase/specs/jls/se27/html/jls-3.html, accessed
// 2026-10-04) and recounted against chapter 3's own census: 51 reserved
// words frozen since 9 when the underscore joined, 17 contextual keywords
// dated by arrival, and the 3 literal tokens true false null that the spec
// reserves like keywords but classifies as literals. two reserved words
// stay unmapped: assert and transient, the book's recorded honest drops
// (the assertion budget rides the ok contract and junit, the io chapter
// walks the modern path instead of object serialization)
#let reserved = (
  "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
  "class", "const", "continue", "default", "do", "double", "else", "enum",
  "extends", "final", "finally", "float", "for", "goto", "if", "implements",
  "import", "instanceof", "int", "interface", "long", "native", "new",
  "package", "private", "protected", "public", "return", "short", "static",
  "strictfp", "super", "switch", "synchronized", "this", "throw", "throws",
  "transient", "try", "void", "volatile", "while", "_",
)

// the spec classifies these as literals, not keywords, but they are
// reserved the same way and belong in the census
#let literals = ("true", "false", "null")

// contextual keywords with the release that minted them: the module system
// brought 10 in 9, var in 10, yield final in 14 after the 13 preview,
// record final in 16 after the 14 preview, the sealed trio in 17 after the
// 15 preview, when final in 21 after riding the pattern switch previews
#let contextual = (
  (word: "module", since: 9), (word: "open", since: 9),
  (word: "requires", since: 9), (word: "transitive", since: 9),
  (word: "exports", since: 9), (word: "opens", since: 9),
  (word: "to", since: 9), (word: "uses", since: 9),
  (word: "provides", since: 9), (word: "with", since: 9),
  (word: "var", since: 10), (word: "yield", since: 14),
  (word: "record", since: 16), (word: "sealed", since: 17),
  (word: "permits", since: 17), (word: "non-sealed", since: 17),
  (word: "when", since: 21),
)

// chapter mapping: where each word is taught, chapter ids from the manifest
#let taught-in = (
  "abstract": "classes", "assert": "unmapped", "boolean": "types",
  "break": "lexical", "byte": "types", "case": "patterns",
  "catch": "io", "char": "types", "class": "classes", "const": "lexical",
  "continue": "lexical", "default": "patterns", "do": "lexical",
  "double": "types", "else": "lexical", "enum": "enums",
  "extends": "classes", "final": "classes", "finally": "conc",
  "float": "types", "for": "lexical", "goto": "lexical", "if": "lexical",
  "implements": "classes", "import": "modules", "instanceof": "patterns",
  "int": "types", "interface": "classes", "long": "types",
  "native": "concurrency", "new": "classes", "package": "modules",
  "private": "classes", "protected": "classes", "public": "classes",
  "return": "lexical", "short": "types", "static": "classes",
  "strictfp": "lexical", "super": "classes", "switch": "patterns",
  "synchronized": "concurrency", "this": "classes", "throw": "io",
  "throws": "io", "transient": "unmapped", "try": "io", "void": "types",
  "volatile": "concurrency", "while": "lexical", "_": "patterns",
  "true": "lexical", "false": "lexical", "null": "lexical",
  "module": "modules", "open": "modules", "requires": "modules",
  "transitive": "modules", "exports": "modules", "opens": "modules",
  "to": "modules", "uses": "modules", "provides": "modules",
  "with": "modules", "var": "types", "yield": "lexical",
  "record": "classes", "sealed": "types", "permits": "types",
  "non-sealed": "types", "when": "patterns",
)

#let matrix = reserved.map(k => (word: k, kind: "reserved", since: none, chapter: taught-in.at(k, default: "unmapped"))) + literals.map(k => (word: k, kind: "literal", since: none, chapter: taught-in.at(k, default: "unmapped"))) + contextual.map(c => (word: c.word, kind: "contextual", since: c.since, chapter: taught-in.at(c.word, default: "unmapped")))
