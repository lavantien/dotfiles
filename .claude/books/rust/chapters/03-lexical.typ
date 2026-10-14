#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= lexical structure

Everything rustc sees before it understands types: the token grammar,
identifiers across every unicode script, a literal system that grew one
form per real need, and a `char` that is a unicode scalar value, never
a byte. The reference's lexical section is the spine here, every number
below comes out of a sample run on the pinned 1.99.0 lane.

== tokens, the grammar's shape

Rust source lexes into keywords, identifiers, literals, lifetimes,
punctuation, and delimiters, and the grammar is written as regular
productions for each token kind. Two consequences show up in daily
code. Delimiters are tokens, so the compiler never needs whitespace to
separate a closing brace from the next token. And any literal token may
carry any suffix at lex time, the restriction arrives later: a literal
expression only accepts suffixes from the fixed list of integer and
float type names, so `1suffix` passes a macro untouched and fails as
an expression.

#snippet(
  "macro_rules! blackhole { ($l:literal) => () }\n"
  + "blackhole!(1suffix);   // fine, the macro never interprets it\n"
  + "let x = 1suffix;       // error, no such type suffix\n",
  lang: "rust",
)

#callout("note", "prefixed literals are reserved, since the 2021 edition", [
  An identifier glued to a string literal, `string"..."`, used to lex
  as two tokens and now fails as `unknown prefix`. The reservation is
  what made `c"..."` for C strings possible in 1.77, and the error
  message this toolchain prints is `prefix string is unknown` with the
  hint to insert whitespace, probed 2026-10-13. The lesson is to keep
  a space between a name and a string literal, and to trust that a
  new literal form can arrive without edition breakage.
])

The lifetime token `'a` is its own token kind, which is why the lexer
never confuses a lifetime with a character literal, the grammar for
`CHAR_LITERAL` requires a single quote on both sides and the grammar
for `LIFETIME_TOKEN` requires an identifier after the quote. The
classic confusion goes the other way, `'a` alone is a lifetime, `'a'`
is the character a:

#snippet(
  "let label: &'static str = \"statically\";   // 'static is a lifetime token\n"
  + "let letter: char = 'a';                   // quotes on both sides, a char\n"
  + "let borrowed: &'a str = ask();            // 'a names a region, chapter 6\n",
  lang: "text",
)

== identifiers and raw identifiers

An identifier starts with an XID_Start character or `_` and continues
with XID characters, following Unicode Standard Annex 31. Vietnamese
diacritics, Cyrillic, and CJK are all legal, and this sample leans on
it:

#listing("rust/samples/src/Ch03/RawIdent.rs", first: 52, last: 63, caption: [three scripts, one namespace, NFC normalizes the spellings])

Two identifiers are the same identifier when their NFC normalizations
match. The sample defines a function with a decomposed name, an `o`
followed by a combining circumflex, and calls it through the
precomposed `o` with a circumflex. One name, two byte sequences.

Strict and reserved keywords cannot be identifiers, and the escape is
the raw identifier `r#` plus the word. Raw identifiers landed in 1.30
as the mechanism that let the 2018 and 2024 editions promote words like
`dyn` and `gen` without breaking variables named after them:

#listing("rust/samples/src/Ch03/RawIdent.rs", first: 22, last: 32, caption: [`r#match`, `r#for`, `r#type`, `r#gen` as names, the keywords still parse as keywords])

#callout("note", "the prefix is not part of the name", [
  `r#match` and a hypothetical variable `match` in an older edition are
  the same identifier path. Four words refuse the escape outright,
  `r#self`, `r#Self`, `r#crate`, `r#super`, and `r#_`, because their
  meanings are positional and cannot be borrowed as names. The full
  census, 39 strict, 14 reserved, and the weak set, is frozen in the
  appendix keyword matrix and is not re-enumerated here.
])

== integer and float literals

Integers come in four radices, decimal, `0x` hex, `0o` octal, `0b`
binary, with `_` separators legal between any two digits and directly
after the radix prefix. Suffixes pin the type, and the unsuffixed
default is `i32`:

#listing("rust/samples/src/Ch03/Literals.rs", first: 20, last: 38, caption: [four radices, separators everywhere, the i32 default measured])

The suffix grammar has one trap: an integer suffix may not begin with
`e` or `E`, because that would read as a float exponent, which is why
`2em` lexes as one broken token rather than `2` with suffix `em`. A
decimal literal out of range for its suffix is a compile error, and
the only sanctioned overflow spelling is the unary minus form, where
the literal is truncated to its type:

#listing("rust/samples/src/Ch03/Literals.rs", first: 39, last: 50, caption: [suffixes pin types, and -(128) is how i8::MIN is written])

Floats add the exponent forms and one grammar quirk worth seeing once,
a trailing period makes a float and a leading dot does not:

#listing("rust/samples/src/Ch03/Literals.rs", first: 52, last: 68, caption: [exponents, the f64 default, 2. is 2.0, 3_f64 and 5f32 both work])

#diagram([the literal inventory: bases, separators, suffixes], length: 13pt, {
  let kinds = ([integer], [float], [char], [byte], [string])
  let chips = (
    (`1_000`, `0xff`, `0o777`, `0b1010`),
    (`2.5e3`, `1e3`, `2.`, `3_f64`),
    (`'x'`, `'\u{1F600}'`, `-`),
    (`b'x'`, `b'\x00'`, `-`),
    (`"s"`, `r#"raw"#`, `b"bs"`),
  )
  let notes = (
    [suffixes u8 to u128, usize, isize, default i32],
    [suffixes f32 f64, default f64],
    [4 byte scalar, never a byte],
    [u8, ASCII only],
    [utf-8 bytes, `&str`],
  )
  for i in range(5) {
    let y = 5.2 - i * 1.55
    cdraw.content((1.7, y), kinds.at(i), size: 6.5pt)
    let row = chips.at(i)
    let n = calc.min(row.len(), 4)
    for j in range(n) {
      let w = if row.at(j).text.len() > 6 { 3.6 } else { 2.6 }
      let x0 = 4.0 + j * 3.85 + (if j > 0 { j * 0.35 } else { 0 })
      cdraw.rect((x0, y - 0.55), (x0 + w, y + 0.55), fill: luma(235), radius: 0.02)
      cdraw.content((x0 + w / 2, y), row.at(j), size: 6pt)
    }
    cdraw.content((20.4, y), notes.at(i), size: 6.5pt)
  }
})

== char, the four byte scalar

A `char` is a unicode scalar value, a code point that is not a
surrogate, stored as a 32 bit word with the size and alignment of
`u32`. The range has a hole, `U+D800` through `U+DFFF` are reserved
for utf-16 surrogates and no `char` holds them:

#diagram([the scalar value range with the surrogate gap], length: 13pt, {
  cdraw.rect((0.4, 2.6), (9.4, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 3.9), [U+0000 .. U+D7FF], size: 6.5pt)
  cdraw.content((4.9, 3.1), [the lower scalars], size: 6pt)
  cdraw.rect((9.4, 2.6), (13.6, 4.4), fill: luma(210), radius: 0.02)
  cdraw.content((11.5, 3.9), [U+D800], size: 6pt)
  cdraw.content((11.5, 3.1), [gap], size: 6pt)
  cdraw.rect((13.6, 2.6), (17.8, 4.4), fill: luma(210), radius: 0.02)
  cdraw.content((15.7, 3.9), [U+DFFF], size: 6pt)
  cdraw.content((15.7, 3.1), [gap], size: 6pt)
  cdraw.rect((17.8, 2.6), (23.4, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((20.6, 3.9), [U+E000 .. U+10FFFF], size: 6.5pt)
  cdraw.content((20.6, 3.1), [the upper scalars], size: 6pt)
  cdraw.content((11.9, 1.6), [from_u32 returns None inside the gap and above U+10FFFF, size 4 bytes always], size: 6.5pt)
})

#listing("rust/samples/src/Ch03/CharScalar.rs", first: 41, last: 56, caption: [the surrogate gap and the range ends, measured])

The byte literal `b'x'` is a different type entirely, a `u8`. The two
worlds connect through `as`: `char` to integer always works, integer to
`char` through `as` works only from `u8`, every wider integer goes
through `char::from_u32`, whose associated form carries a 1.52
stability badge:

#listing("rust/samples/src/Ch03/CharScalar.rs", first: 58, last: 76, caption: [char and u8, the cast door between them is one way for u8])

A `char` is not its utf-8 encoding. `'é'` is one `char` and two utf-8
bytes, `'😀'` is one `char` and four bytes, and casting a scalar to
`u8` truncates the code point, it does not encode it:

#listing("rust/samples/src/Ch03/CharScalar.rs", first: 77, last: 90, caption: [truncation versus encoding, the two facts that bite everyone once])

#callout("pitfall", "s.len() counts bytes", [
  `"héllo".len()` is 6, not 5, because `len` answers the byte count of
  the utf-8 buffer. `chars().count()` answers the scalar count. String
  indexing by number does not exist at all, `as_bytes()` hands back raw
  bytes and `0xC3` is a perfectly legal element.
])

== strings, six forms

The string literal family grew one form per real need, and the raw
delimiter counts its hashes to raise the nesting budget:

#listing("rust/samples/src/Ch03/Strings.rs", first: 40, last: 57, caption: [raw strings, one hash, two hashes, escapes off])

Byte strings are borrowed byte arrays, and the C string forms, since
1.77 and the 2021 edition onward, hand a borrowed `CStr` with an
implicit NUL terminator for ffi work:

#listing("rust/samples/src/Ch03/Strings.rs", first: 58, last: 76, caption: [byte strings, raw byte strings, C strings, and the NUL that rides along])

#diagram([the six string forms and what each is for], length: 13pt, {
  let forms = (`"s"`, `r#"…"#`, `b"s"`, `br#"…"#`, `c"s"`, `cr#"…"#`)
  let kinds = (
    [`&str`, escapes on],
    [`&str`, escapes off, hashes nest],
    [`&[u8; N]`, escapes on],
    [`&[u8; N]`, escapes off],
    [`&CStr`, NUL appended, 1.77],
    [`&CStr`, NUL appended, raw],
  )
  for i in range(6) {
    let y = 5.4 - i * 1.35
    cdraw.rect((0.4, y - 0.55), (3.4, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((1.9, y), forms.at(i), size: 6pt)
    cdraw.line((3.4, y), (4.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.4, y), kinds.at(i), size: 6.5pt)
  }
  cdraw.content((11.9, -0.6), [escapes: \\x is ASCII only, \\u{...} names any scalar, \\0 n r t, line continue], size: 6pt)
})

== comments

Line comments `//` and block comments `/* */`, and block comments
nest, which C programmers meet with relief. Documentation comments are
their own token kinds: `///` and `/** */` attach to the item that
follows, `//!` and `/*! */` attach to the enclosing module, and both
are sugar for `#[doc = "..."]` attributes rather than compiler
ignorable text. Four slashes `////` are an ordinary comment, the doc
forms require exactly three, and `/** */` with three or more leading
asterisks stops being a doc comment too. A `CR` character is illegal
inside a doc comment, and a block doc comment ends at the first `*/`
no matter what the markdown inside promised.

#snippet(
  "mod example {\n"
  + "    //! module level doc, inner\n"
  + "    /// item level doc, outer\n"
  + "    pub fn documented() {}\n"
  + "    //// four slashes, just a comment\n"
  + "    /* /* block comments nest */ */\n"
  + "    pub fn nested() {}\n"
  + "}\n",
  lang: "rust",
)

The lexer proof that nesting and the underscore prefix warnings behave
as documented is the sample compile itself, the suite runs under
`rustc --edition 2024 -D warnings` and every fact above that has a
runtime face carries an ok line in `RawIdent.rs`.

sources: the rust reference, tokens and literals, identifiers, and
comments pages, doc.rust-lang.org/stable/reference/tokens.html,
identifiers.html, comments.html, and expressions/literal-expr.html,
accessed 2026-10-13 against the pinned 1.99.0 offline rust-docs set.
version attributions from the release log in that same offline set,
releases.md: raw identifiers in 1.30, `'_` in 1.26, C string literals
in 1.77, read 2026-10-13. claims verified by the Ch03 sample suite,
76 checks under `tools/run-rust-samples.ps1 -Chapter Ch03` on
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc, plus rustc probes
for the compile fail forms: the suffix rejection on `1suffix` as an
expression, the `r#self` refusal, and the overflowing literal error on
`128_i8`, all probed 2026-10-13.
