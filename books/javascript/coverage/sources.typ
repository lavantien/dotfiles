// book level source pins. the 1.0 pins were fetched 2026-09-08; the
// 2.0 restructure re-probed the toolchain and fetched the new
// material 2026-09-13; the 4.0 framework wave added the react,
// svelte, vite, and import maps material 2026-09-21, so the table
// carries three dates.
#let sources = (
  (topic: "announcing typescript 7.0", url: "devblogs.microsoft.com/typescript/announcing-typescript-7-0", accessed: "2026-09-08"),
  (topic: "typescript 6.0 stepping stone", url: "devblogs.microsoft.com/typescript/announcing-typescript-6-0", accessed: "2026-09-08"),
  (topic: "tsconfig reference", url: "typescriptlang.org/tsconfig", accessed: "2026-09-08"),
  (topic: "handbook: everyday types, narrowing", url: "typescriptlang.org/docs/handbook", accessed: "2026-09-08"),
  (topic: "handbook 2: mapped, conditional, template types", url: "typescriptlang.org/docs/handbook/2", accessed: "2026-09-08"),
  (topic: "mdn lexical grammar and reserved words", url: "developer.mozilla.org/docs/Web/JavaScript/Reference/Lexical_grammar", accessed: "2026-09-08"),
  (topic: "mdn javascript reference", url: "developer.mozilla.org/docs/Web/JavaScript/Reference", accessed: "2026-09-08"),
  (topic: "mdn iteration protocols", url: "developer.mozilla.org/docs/Web/JavaScript/Reference/Iteration_protocols", accessed: "2026-09-08"),
  (topic: "node test runner", url: "nodejs.org/api/test", accessed: "2026-09-08"),
  (topic: "node esm and import attributes", url: "nodejs.org/api/esm", accessed: "2026-09-08"),
  (topic: "node type stripping", url: "nodejs.org/api/typescript", accessed: "2026-09-08"),
  (topic: "tc39 proposals: groupby, fromAsync, withResolvers", url: "tc39.es", accessed: "2026-09-08"),
  (topic: "tc39 decorators proposal", url: "github.com/tc39/proposal-decorators", accessed: "2026-09-08"),
  (topic: "ecma 262 es2026, the 17th edition, approved 2026-06-30", url: "ecma-international.org", accessed: "2026-09-13"),
  (topic: "tc39 temporal proposal, stage 4, slated for es2027", url: "github.com/tc39/proposal-temporal", accessed: "2026-09-13"),
  (topic: "node 26.3.0 release line, v8 14.6, npm 12.0.2", url: "nodejs.org/en/blog/release", accessed: "2026-09-13"),
  (topic: "typescript package pin, 7.0.2, es2026 rejected TS6046", url: "npmjs.com/package/typescript", accessed: "2026-09-13"),
  (topic: "v8 dev blog, tail calls and temporal shipping", url: "v8.dev/blog", accessed: "2026-09-13"),
  (topic: "tc39 proposals: iterator.concat, getOrInsert, uint8array codecs", url: "tc39.es", accessed: "2026-09-13"),
  (topic: "tc39 explicit resource management and import attributes", url: "tc39.es", accessed: "2026-09-13"),
  (topic: "react 19 reference: hooks, use, actions, error boundaries", url: "react.dev/reference/react", accessed: "2026-09-21"),
  (topic: "react 19 release post, ref as prop and form actions", url: "react.dev/blog/2024/12/05/react-19", accessed: "2026-09-21"),
  (topic: "svelte 5 docs: runes, snippets, custom elements, stores", url: "svelte.dev/docs/svelte", accessed: "2026-09-21"),
  (topic: "vite guide and library mode", url: "vite.dev/guide", accessed: "2026-09-21"),
  (topic: "whatwg import maps specification", url: "html.spec.whatwg.org/multipage/scripting.html#import-maps", accessed: "2026-09-21"),
)
