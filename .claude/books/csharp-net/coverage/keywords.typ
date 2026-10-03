// keyword coverage matrix, enumerated from learn.microsoft.com
// dotnet/csharp/language-reference/keywords, accessed 2026-09-08,
// recounted 2026-09-13: reserved 77, contextual 48 in the live table,
// union filed under contextual from the union types reference page,
// the index table had not listed it yet on the recount date
// status: covered means a chapter teaches it, planned means the matrix row exists
#let reserved = (
  "abstract", "as", "base", "bool", "break", "byte", "case", "catch", "char",
  "checked", "class", "const", "continue", "decimal", "default", "delegate",
  "do", "double", "else", "enum", "event", "explicit", "extern", "false",
  "finally", "fixed", "float", "for", "foreach", "goto", "if", "implicit",
  "in", "int", "interface", "internal", "is", "lock", "long", "namespace",
  "new", "null", "object", "operator", "out", "override", "params",
  "private", "protected", "public", "readonly", "ref", "return", "sbyte",
  "sealed", "short", "sizeof", "stackalloc", "static", "string", "struct",
  "switch", "this", "throw", "true", "try", "typeof", "uint", "ulong",
  "unchecked", "unsafe", "ushort", "using", "virtual", "void", "volatile",
  "while",
)

#let contextual = (
  "add", "allows", "alias", "and", "ascending", "args", "async", "await",
  "by", "closed", "descending", "dynamic", "equals", "extension", "field",
  "file", "from", "get", "global", "group", "init", "into", "join", "let",
  "managed", "nameof", "nint", "not", "notnull", "nuint", "on", "or",
  "orderby", "partial", "record", "remove", "required", "safe", "scoped",
  "select", "set", "union", "unmanaged", "value", "var", "when", "where",
  "with", "yield",
)

// chapter mapping: where each keyword is taught
#let taught-in = (
  "abstract": "typesystem", "as": "patterns", "base": "typesystem",
  "bool": "lexical", "break": "patterns", "byte": "lexical",
  "case": "patterns", "catch": "exceptions", "char": "lexical",
  "checked": "memory", "class": "typesystem", "const": "members",
  "continue": "patterns", "decimal": "lexical", "default": "patterns",
  "delegate": "delegates", "do": "patterns", "double": "lexical",
  "else": "patterns", "enum": "typesystem", "event": "delegates",
  "explicit": "members", "extern": "memory", "false": "lexical",
  "finally": "exceptions", "fixed": "memory", "float": "lexical",
  "for": "patterns", "foreach": "patterns", "goto": "patterns",
  "if": "patterns", "implicit": "members", "in": "patterns",
  "int": "lexical", "interface": "typesystem", "internal": "members",
  "is": "patterns", "lock": "async", "long": "lexical",
  "namespace": "toolchain", "new": "members", "null": "lexical",
  "object": "typesystem", "operator": "members", "out": "members",
  "override": "typesystem", "params": "members", "private": "members",
  "protected": "members", "public": "members", "readonly": "memory",
  "ref": "memory", "return": "patterns", "sbyte": "lexical",
  "sealed": "typesystem", "short": "lexical", "sizeof": "memory",
  "stackalloc": "memory", "static": "members", "string": "lexical",
  "struct": "typesystem", "switch": "patterns", "this": "members",
  "throw": "exceptions", "true": "lexical", "try": "exceptions",
  "typeof": "reflection", "uint": "lexical", "ulong": "lexical",
  "unchecked": "memory", "unsafe": "memory", "ushort": "lexical",
  "using": "toolchain", "virtual": "typesystem", "void": "lexical",
  "volatile": "async", "while": "patterns",
  "add": "delegates", "allows": "generics", "alias": "toolchain",
  "and": "patterns", "ascending": "linq", "args": "toolchain",
  "async": "async", "await": "async", "by": "linq", "closed": "typesystem",
  "descending": "linq", "dynamic": "reflection", "equals": "linq",
  "extension": "members", "field": "members", "file": "toolchain",
  "from": "linq", "get": "members", "global": "toolchain",
  "group": "linq", "init": "members", "into": "linq", "join": "linq",
  "let": "linq", "managed": "memory", "nameof": "members",
  "nint": "memory", "not": "patterns", "notnull": "generics",
  "nuint": "memory", "on": "linq", "or": "patterns", "orderby": "linq",
  "partial": "members", "record": "typesystem", "remove": "delegates",
  "required": "members", "safe": "memory", "scoped": "memory",
  "select": "linq", "set": "members", "unmanaged": "generics",
  "union": "lexical",
  "value": "members", "var": "toolchain", "when": "exceptions",
  "where": "generics", "with": "typesystem", "yield": "idioms",
)

#let matrix = reserved.map(k => (word: k, kind: "reserved", chapter: taught-in.at(k, default: "unmapped"))) + contextual.map(k => (word: k, kind: "contextual", chapter: taught-in.at(k, default: "unmapped")))

// f# tour coverage, scoped to the tour chapters 19-21 only: the words and
// symbols the tour exercises, enumerated from learn.microsoft.com
// dotnet/fsharp/language-reference keyword reference and symbol and
// operator reference, accessed 2026-09-13, with `and!` read from the task
// expressions page. this is a tour table, not a census: the full f#
// keyword table, its ocaml-reserved and future-reserved tokens included,
// lives upstream and the f# chapters claim no count over it
#let fsharp-tour = (
  (word: "let", kind: "keyword", chapter: "fsharp-language"),
  (word: "mutable", kind: "keyword", chapter: "fsharp-language"),
  (word: "rec", kind: "keyword", chapter: "fsharp-language"),
  (word: "type", kind: "keyword", chapter: "fsharp-language"),
  (word: "of", kind: "keyword", chapter: "fsharp-language"),
  (word: "with", kind: "keyword", chapter: "fsharp-language"),
  (word: "match", kind: "keyword", chapter: "fsharp-language"),
  (word: "module", kind: "keyword", chapter: "fsharp-language"),
  (word: "open", kind: "keyword", chapter: "fsharp-language"),
  (word: "fun", kind: "keyword", chapter: "fsharp-language"),
  (word: "member", kind: "keyword", chapter: "fsharp-pipeline"),
  (word: "private", kind: "keyword", chapter: "fsharp-pipeline"),
  (word: "let!", kind: "computation expression", chapter: "fsharp-pipeline"),
  (word: "and!", kind: "computation expression", chapter: "fsharp-pipeline"),
  (word: "return", kind: "computation expression", chapter: "fsharp-pipeline"),
  (word: "|>", kind: "symbol", chapter: "fsharp-pipeline"),
  (word: ">>", kind: "symbol", chapter: "fsharp-pipeline"),
  (word: "<-", kind: "symbol", chapter: "fsharp-language"),
  (word: "_", kind: "symbol", chapter: "fsharp-language"),
  (word: ".[ ]", kind: "symbol", chapter: "fsharp-pipeline"),
  (word: "[< >]", kind: "symbol", chapter: "fsharp-language"),
  (word: "?", kind: "symbol", chapter: "fsharp-dotnet"),
)
