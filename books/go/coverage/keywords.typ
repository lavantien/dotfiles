// keyword coverage matrix, enumerated from go.dev/ref/spec,
// keywords section, accessed 2026-09-08. go has 25 reserved words
// and no contextual keywords: predeclared identifiers are not
// reserved and are covered in the lexical chapter instead.
#let keywords = (
  "break", "default", "func", "interface", "select",
  "case", "defer", "go", "map", "struct",
  "chan", "else", "goto", "package", "switch",
  "const", "fallthrough", "if", "range", "type",
  "continue", "for", "import", "return", "var",
)

// chapter mapping: where each keyword is taught
#let taught-in = (
  "break": "structure", "default": "structure", "func": "functions",
  "interface": "types", "select": "concurrency",
  "case": "structure", "defer": "functions", "go": "concurrency",
  "map": "types", "struct": "types",
  "chan": "concurrency", "else": "structure", "goto": "structure",
  "package": "toolchain", "switch": "structure",
  "const": "structure", "fallthrough": "structure", "if": "structure",
  "range": "structure", "type": "structure",
  "continue": "structure", "for": "structure", "import": "toolchain",
  "return": "functions", "var": "structure",
)

#let matrix = keywords.map(k => (word: k, kind: "reserved", chapter: taught-in.at(k, default: "unmapped")))
