#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= react state: context, redux, graphql

State management questions are really caching questions wearing a
state hat. The workspace builds the three answers in miniature:
context for ambient values, a redux-shaped store bound through
`useSyncExternalStore`, and a request cache with dedupe and
invalidation, the part rtk query automates for a living.

== context versus a store [EWC]

Context is a dependency injection mechanism: one provider, many
consumers, and a value change re-renders every consumer. A store is
observable state plus dispatch, and react binds to it through
`useSyncExternalStore`:

#listing("interview-repertoire/samples/ch12-react/src/state/store.js", first: 9, last: 46, caption: [a redux-shaped store, and the react binding over it])

#diagram([context versus a store: who re-renders on a change], length: 13pt, {
  // left: one provider value fans to every consumer; right: only slice readers
  cdraw.content((5.2, 8.8), [context], size: 6.5pt)
  cdraw.rect((2.8, 7.2), (7.6, 8.0), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.2, 7.6), [provider], size: 6.5pt)
  cdraw.line((5.2, 7.2), (5.2, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.5, 6.7), [value change], size: 6pt)
  for (x, t) in ((1.6, "a"), (4.4, "b"), (7.2, "c")) {
    cdraw.rect((x, 5.2), (x + 2.4, 6.0), fill: luma(205), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 1.2, 5.6), [#t], size: 6.5pt)
  }
  cdraw.content((5.6, 4.6), [every consumer re-renders], size: 6pt)
  cdraw.content((5.6, 3.4), [the whole subscribed subtree], size: 6pt)
  cdraw.content((17.2, 8.8), [store], size: 6.5pt)
  cdraw.rect((14.6, 7.2), (19.8, 8.0), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.2, 7.6), [store], size: 6.5pt)
  cdraw.line((17.2, 7.2), (17.2, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((20.9, 6.7), [dispatch], size: 6pt)
  for (x, t, hot) in ((13.6, "count", true), (16.4, "name", false), (19.2, "count", true)) {
    cdraw.rect((x, 5.2), (x + 2.4, 6.0), fill: if hot { luma(205) } else { luma(245) }, stroke: luma(120), radius: 0.02)
    cdraw.content((x + 1.2, 5.6), [#t], size: 6.5pt)
  }
  cdraw.content((17.6, 4.6), [only the count readers], size: 6pt)
  cdraw.content((17.6, 3.4), [re-render, name does not], size: 6pt)
})

The line that scores: reach for context when the value is ambient
and changes rarely, theme, locale, the current user. Reach for a
store when many components read slices of fast-changing state,
because a context value change re-renders the whole consumer
subtree while a store subscription re-renders exactly the
components whose slice changed. The suite proves the binding: one
dispatch, the readout moves, and the same store serves a second
component without threading.

== what rtk query automates [EWC]

Redux toolkit query is a request cache with dedupe, invalidation,
and lifecycle flags. The workspace rebuilds the core of it in
forty lines so the answer is not a product name:

#listing("interview-repertoire/samples/ch12-react/src/state/store.js", first: 49, last: 84, caption: [dedupe by inflight promise, fresh cache, failure eviction, invalidation])

#diagram([the request cache state machine rtk query automates], length: 13pt, {
  // one key's lifecycle: empty, inflight with dedupe, fresh, evicted on failure
  let state(x0, x1, t) = {
    cdraw.rect((x0, 4.8), (x1, 5.6), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.2), [#t], size: 6.5pt)
  }
  state(1.4, 4.4, "empty")
  state(7.6, 11.2, "inflight")
  state(14.0, 17.2, "fresh")
  cdraw.line((4.4, 5.2), (7.6, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.9, 6.4), [first read], size: 6pt)
  cdraw.line((11.2, 5.2), (14.0, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.6, 6.4), [success], size: 6pt)
  // failure drops back to empty instead of poisoning the slot
  cdraw.line((9.4, 4.8), (9.4, 3.5), (2.9, 3.5), (2.9, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.15, 2.95), [failure evicts the slot], size: 6pt)
  // invalidation forces the next fly
  cdraw.line((15.6, 5.6), (15.6, 6.9), (9.4, 6.9), (9.4, 5.55), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.5, 7.45), [invalidate: the next read flies], size: 6pt)
  cdraw.content((20.1, 6.4), [two callers, one key], size: 6pt)
  cdraw.content((20.3, 5.2), [share one flight], size: 6pt)
  cdraw.content((20.2, 4.0), [second load: a hit], size: 6pt)
})

The tests pin the four behaviors an interviewer is really asking
about: two callers loading the same key share one flight, a second
load hits the fresh cache without flying, a failure evicts instead
of poisoning the slot, and invalidate forces the next read to fly.
Say the rtk query names for these, same key sharing, cache
lifetime tags, refetch on invalidation, and the miniature maps
onto the product one to one.

== graphql, rest, and n+1 [EWC]

The n+1 question is arithmetic, and the workspace makes it count:
ten users naive is one users query plus ten post queries, and
batching the posts by user ids is two queries total:

#listing("interview-repertoire/samples/ch12-react/src/state/store.js", first: 74, last: 90, caption: [the naive count, the batched count, and both loaders against the cache])

#diagram([ten users naive is 11 queries, batched is 2], length: 13pt, {
  // left: one users query plus one posts query per user; right: both in two
  cdraw.content((5.0, 9.2), [naive], size: 6.5pt)
  cdraw.rect((2.0, 7.7), (8.0, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.0, 8.05), [users: 1 query], size: 6pt)
  for i in range(10) {
    let y = 7.15 - i * 0.55
    cdraw.rect((2.0, y), (8.0, y + 0.5), fill: luma(235), stroke: luma(120), radius: 0.02)
  }
  // the bracket names the stack: ten posts queries, one per user
  cdraw.line((8.3, 7.15), (8.3, 2.7), stroke: luma(160))
  cdraw.line((8.1, 7.15), (8.3, 7.15), stroke: luma(160))
  cdraw.line((8.1, 2.7), (8.3, 2.7), stroke: luma(160))
  cdraw.content((10.8, 5.5), [10 posts queries,], size: 6pt)
  cdraw.content((10.8, 4.3), [one per user], size: 6pt)
  cdraw.content((5.0, 1.7), [11 queries], size: 6.5pt)
  cdraw.content((5.0, 0.4), [one posts query per user], size: 6pt)
  cdraw.content((16.8, 9.2), [batched], size: 6.5pt)
  cdraw.rect((13.6, 7.7), (19.6, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((16.6, 8.05), [users: 1 query], size: 6pt)
  cdraw.rect((13.6, 6.7), (19.6, 7.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((16.6, 7.05), [posts: 1 query], size: 6pt)
  cdraw.content((16.8, 5.8), [2 queries], size: 6.5pt)
  cdraw.content((17.4, 4.5), [who batches: the resolver], size: 6pt)
  cdraw.content((17.4, 3.3), [layer (data loader) or a], size: 6pt)
  cdraw.content((17.4, 2.1), [rest batch endpoint], size: 6pt)
})

The fake network in the test records every key loaded, so the
assertion is on observable fetches, not on a promise the code
makes in a comment. The graphql half of the question, said
plainly: graphql moves the n+1 problem server-side, the client
asks once and the resolver layer batches, data loader style,
exactly like the `batchedPosts` key the test watches. Rest does
the same with a batch endpoint or a compound resource, and the
either-or framing of the question is usually false.

sources: verified by `npm run verify` under node 26.3.0, 5 tests in
`src/state` of `ch12-react`. Store binding through
useSyncExternalStore per the react api docs, react.dev, accessed
2026-09-10.
