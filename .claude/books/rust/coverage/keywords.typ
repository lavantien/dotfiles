// keyword coverage matrix, enumerated from the rust reference, keywords
// chapter (doc.rust-lang.org/stable/reference/keywords.html, accessed
// 2026-10-13, verified against the pinned 1.99.0 rust-docs offline set):
// 39 strict keywords, 14 reserved for future use with gen joining in the
// 2024 edition, and the weak set that parses only in specific positions.
// the chapter map filled 2026-10-14 by grepping the 32 written chapters
// for each word's teaching site, the section that introduces it, not
// every mention. every strict keyword mapped; 12 of the 14 reserved
// words never leave this matrix, the book names them nowhere, and the
// weak safe keyword shares that fate, its 2024 unsafe(...) counterpart
// is taught, the safe(...) spelling is not. since values quote only
// what a chapter states outright
#let strict = (
  "_", "as", "async", "await", "break", "const", "continue", "crate",
  "dyn", "else", "enum", "extern", "false", "fn", "for", "if", "impl",
  "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref",
  "return", "self", "Self", "static", "struct", "super", "trait", "true",
  "type", "unsafe", "use", "where", "while",
)

// reserved for future use, never valid identifiers in any edition;
// gen was promoted from weak to reserved by the 2024 edition
#let reserved = (
  "abstract", "become", "box", "do", "final", "gen", "macro", "override",
  "priv", "try", "typeof", "unsized", "virtual", "yield",
)

// weak keywords: valid identifiers except in their special positions
#let weak = (
  (word: "union", note: "a union type only where a type is expected"),
  (word: "macro_rules", note: "the declarative macro definer"),
  (word: "raw", note: "raw identifiers, r#ident"),
  (word: "safe", note: "the 2024 safe static analysis attribute context"),
  (word: "'static", note: "the lifetime label, a weak token by position"),
)

#let taught-in = (
  "_": "adts", "as": "types", "async": "async", "await": "async",
  "break": "closures-iterators", "const": "types", "continue": "adts",
  "crate": "crates", "dyn": "traits", "else": "adts", "enum": "adts",
  "extern": "unsafe", "false": "types", "fn": "ownership",
  "for": "closures-iterators", "if": "adts", "impl": "adts",
  "in": "closures-iterators", "let": "types", "loop": "async",
  "match": "adts", "mod": "crates", "move": "ownership",
  "mut": "borrowing", "pub": "crates", "ref": "adts", "return": "errors",
  "self": "adts", "Self": "traits", "static": "types", "struct": "adts",
  "super": "crates", "trait": "traits", "true": "types", "type": "types",
  "unsafe": "unsafe", "use": "crates", "where": "generics-macros",
  "while": "concurrency", "gen": "editions", "try": "editions",
  "union": "unsafe", "macro_rules": "generics-macros", "raw": "lexical",
  "'static": "borrowing",
)

#let since-in = (
  "async": "1.39", "await": "1.39", "dyn": "1.27",
  "gen": "1.85, 2024 ed.", "try": "2018 ed.", "raw": "1.30",
)

#let matrix = strict.map(k => (word: k, kind: "strict", since: since-in.at(k, default: none), chapter: taught-in.at(k, default: "unmapped"))) + reserved.map(k => (word: k, kind: "reserved", since: since-in.at(k, default: none), chapter: taught-in.at(k, default: "unmapped"))) + weak.map(w => (word: w.word, kind: "weak", since: since-in.at(w.word, default: none), chapter: taught-in.at(w.word, default: "unmapped")))
