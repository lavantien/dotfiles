#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw
#import "../coverage/sources.typ": sources

= appendices: question index and sources

This appendix is the audit the book promised in its first chapter:
every question in the inventory this book was commissioned from
mapped to the labeled section that answers it. TDD sections exist
as failing-test-first code under `make verify`, EWC sections walk
code that runs under the same gate, DRILL sections are spoken
answers with their follow-ups. A question missing from this table
is a gap you can see, and a section without a label is one you can
grep.

#callout("verify", "how to audit this table", [
  Every row's section label is part of the chapter files under
  `chapters/`, appended to each section heading, and every TDD or
  EWC row names a workspace under `samples/` whose suite runs in
  the book's verify step. Grep the label, open the section, run
  the suite.
])

== the question to section index

#let q(question) = table.cell[*#question*]
#let loc(ch, sec) = table.cell[#ch, [#sec]]
#let lab(l) = table.cell[#l]

#table(
  columns: (1fr, auto, auto),
  inset: 5pt,
  align: (left, left, center),
  table.header[*question*][*answered in*][*label*],
  table.cell(colspan: 3)[*meta and landscape*],
  q([what changed in interviews 2024 to 2026, ai rounds, narration]), loc([landscape, ch 1], [the whole chapter]), lab([DRILL]),
  q([paradigms, oop versus fp, in go and c\#]), loc([paradigms, ch 2], [oop sections, fp section]), lab([EWC]),
  q([mvc, mvvm, ecs]), loc([paradigms, ch 2], [where state lives]), lab([DRILL]),
  table.cell(colspan: 3)[*data structures and algorithms*],
  q([implement the seven core data structures]), loc([datastructures, ch 3], [all seven sections]), lab([TDD]),
  q([dfs, bfs, when each]), loc([graphs, ch 4], [dfs and bfs section]), lab([TDD]),
  q([shortest path on an unweighted graph]), loc([graphs, ch 4], [shortest path section]), lab([TDD]),
  q([topological sort, course schedule]), loc([graphs, ch 4], [kahn's section]), lab([TDD]),
  q([reverse a string]), loc([classics1, ch 5], [reverser section]), lab([TDD]),
  q([palindrome check]), loc([classics1, ch 5], [reverser section]), lab([TDD]),
  q([is prime, primes under n]), loc([classics1, ch 5], [primes section]), lab([TDD]),
  q([permutations, anagram detection]), loc([classics1, ch 5], [permutations section]), lab([TDD]),
  q([linked list reverse, middle, cycle]), loc([classics1, ch 5], [linked list section]), lab([TDD]),
  q([two sum, sorted and unsorted]), loc([classics1, ch 5], [two sum section]), lab([TDD]),
  q([count isolated islands]), loc([classics1, ch 5], [islands section]), lab([TDD]),
  q([climbing stairs, the dp ladder]), loc([classics2, ch 6], [the ladder section]), lab([TDD]),
  q([trie and autocomplete]), loc([classics2, ch 6], [trie section]), lab([TDD]),
  q([string manipulation, rle, unique char, anagram groups]), loc([classics2, ch 6], [string manipulation section]), lab([TDD]),
  table.cell(colspan: 3)[*javascript*],
  q([hoisting, scope, var let const]), loc([js-core, ch 7], [hoisting section]), lab([EWC]),
  q([closures, the loop capture gotcha]), loc([js-core, ch 7], [closures section]), lab([EWC]),
  q([operator precedence and coercion]), loc([js-core, ch 7], [precedence section]), lab([EWC]),
  q([null versus undefined versus nan, optionals]), loc([js-core, ch 7], [absences section]), lab([EWC]),
  q([prototypes and the class sugar]), loc([js-core, ch 7], [prototypes section]), lab([EWC]),
  q([the event loop, microtasks, timers]), loc([js-core, ch 7], [event loop section]), lab([EWC]),
  q([what is the dom, querySelector]), loc([js-dom, ch 8], [what the dom is]), lab([EWC]),
  q([center a div]), loc([js-dom, ch 8], [four ways section]), lab([EWC]),
  q([class versus arrow functions, this]), loc([js-dom, ch 8], [class versus arrow]), lab([EWC]),
  q([map filter reduce]), loc([js-dom, ch 8], [arrays section]), lab([EWC]),
  q([async await versus promise.all]), loc([js-dom, ch 8], [arrays section]), lab([EWC]),
  q([es6 features]), loc([js-dom, ch 8], [es6 shapes]), lab([EWC]),
  q([word count in one loop]), loc([js-fromscratch, ch 9], [word count]), lab([TDD]),
  q([an event emitter from scratch]), loc([js-fromscratch, ch 9], [emitter]), lab([TDD]),
  q([map filter reduce from scratch]), loc([js-fromscratch, ch 9], [array methods]), lab([TDD]),
  q([a promise from scratch, async await on it]), loc([js-fromscratch, ch 9], [promise subset]), lab([TDD]),
  q([a signal from scratch]), loc([js-fromscratch, ch 9], [signals core]), lab([TDD]),
  q([csv to mongodb migration]), loc([js-data, ch 10], [all three sections]), lab([TDD, DRILL]),
  table.cell(colspan: 3)[*react*],
  q([function versus class components]), loc([react-core, ch 11], [function versus class]), lab([EWC]),
  q([props, children, prop drilling]), loc([react-core, ch 11], [props and drilling]), lab([EWC]),
  q([how the virtual dom works]), loc([react-core, ch 11], [virtual dom]), lab([EWC]),
  q([the built-in hooks, custom hooks]), loc([react-hooks, ch 12], [hooks sections]), lab([EWC]),
  q([react-router]), loc([react-hooks, ch 12], [router section]), lab([EWC]),
  q([react 19, actions, use, useOptimistic, useActionState]), loc([react-hooks, ch 12], [react 19 section]), lab([EWC]),
  q([the react compiler, signals status]), loc([react-hooks, ch 12], [react 19 section]), lab([EWC]),
  q([context versus redux]), loc([react-state, ch 13], [context versus store]), lab([EWC]),
  q([rtk query caching]), loc([react-state, ch 13], [what rtk query automates]), lab([EWC]),
  q([graphql, rest, the n+1 problem]), loc([react-state, ch 13], [graphql section]), lab([EWC]),
  q([build a listing page against a public api]), loc([react-build, ch 14], [beats one and two]), lab([TDD]),
  q([a virtual dom from scratch]), loc([react-build, ch 14], [beat three]), lab([TDD]),
  table.cell(colspan: 3)[*go systems*],
  q([parallelism versus concurrency]), loc([go-runtime, ch 15], [definitions]), lab([EWC]),
  q([go scheduler versus os threads]), loc([go-runtime, ch 15], [scheduler section]), lab([EWC]),
  q([the garbage collector, go 1.26 gc changes]), loc([go-runtime, ch 15], [green tea section]), lab([DRILL]),
  q([design patterns, concurrent patterns, closures, generics]), loc([go-runtime, ch 15], [patterns, closures, generics sections]), lab([EWC]),
  q([context, timeouts, error wrapping]), loc([go-runtime, ch 15], [context section]), lab([EWC]),
  q([sync.Once singleton, race safety]), loc([go-runtime, ch 15], [singleton section]), lab([TDD]),
  q([mocking and dependency injection]), loc([go-testing, ch 16], [fakes and layers]), lab([TDD]),
  q([testing db, service, handler, callback layers]), loc([go-testing, ch 16], [the four layers]), lab([TDD]),
  q([golden-master testing with the -update flag]), loc([go-testing, ch 16], [the golden master, ported small]), lab([EWC]),
  q([bit-identical twins across languages]), loc([go-testing, ch 16], [determinism discipline section]), lab([DRILL]),
  q([acid versus base]), loc([db-answers, ch 17], [acid section]), lab([DRILL]),
  q([postgres cursors, limit offset, jsonb, money]), loc([db-answers, ch 17], [cursors section, money section]), lab([DRILL, TDD]),
  q([normalization and indexing]), loc([db-answers, ch 17], [normalization, indexing]), lab([TDD]),
  q([isolation levels, optimistic versus pessimistic]), loc([db-answers, ch 17], [locking section]), lab([TDD, DRILL]),
  q([mongo geo, point in polygon]), loc([db-answers, ch 17], [mongo geo]), lab([TDD]),
  q([http, tcp, udp, websocket, graphql]), loc([network-answers, ch 18], [stack, echo servers, ws]), lab([TDD, DRILL]),
  q([https, certificates, symmetric versus asymmetric]), loc([network-answers, ch 18], [https section]), lab([DRILL]),
  q([scaling with and without cloud]), loc([design-answers, ch 19], [scaling section]), lab([DRILL]),
  q([gateway, reverse proxy, kubernetes]), loc([design-answers, ch 19], [gateway section]), lab([DRILL]),
  q([bottlenecks, tracing, logging, metrics]), loc([design-answers, ch 19], [bottlenecks section]), lab([DRILL]),
  q([cap, event-driven, orchestration versus choreography]), loc([design-answers, ch 19], [cap section]), lab([DRILL]),
  q([producer consumer and offsets]), loc([design-answers, ch 19], [remaining inventory]), lab([DRILL]),
  q([queue before the database write]), loc([design-answers, ch 19], [queue first section]), lab([DRILL]),
  q([s3 listing, 10gb from postgres, 10gb file in go]), loc([design-answers, ch 19], [remaining inventory]), lab([DRILL]),
  q([cloud cron]), loc([design-answers, ch 19], [remaining inventory]), lab([DRILL]),
  q([a notification system]), loc([design-answers, ch 19], [remaining inventory]), lab([DRILL]),
  q([300k concurrent users]), loc([design-answers, ch 19], [the 300k sketch]), lab([DRILL]),
  q([parallel url fetcher, bounded workers]), loc([go-build1, ch 20], [fetcher section]), lab([TDD]),
  q([rest api with caching and rate limiting]), loc([go-build1, ch 20], [rest api section]), lab([TDD]),
  q([schema generator and parser]), loc([go-build1, ch 20], [schema section]), lab([TDD]),
  q([the client-side rate limiter against an upstream]), loc([go-build1, ch 20], [client-side limiter section]), lab([TDD]),
  q([inventory storefront, no oversell]), loc([go-build2, ch 21], [storefront section]), lab([TDD]),
  q([graceful shutdown, live deploy]), loc([go-build2, ch 21], [shutdown and deploy]), lab([TDD]),
  q([bolt a realtime feed onto the service]), loc([go-build2, ch 21], [the feed, step by step]), lab([TDD]),
  q([jetstream batch producer and consumer]), loc([go-streaming, ch 22], [produce, consume]), lab([TDD]),
  q([durable consumer, redelivery, offsets]), loc([go-streaming, ch 22], [durable and ack floor]), lab([TDD]),
  q([state that survives a broker restart]), loc([go-streaming, ch 22], [restart test]), lab([TDD]),
  q([kafka versus jetstream]), loc([go-streaming, ch 22], [the comparison paragraph]), lab([TDD, DRILL]),
  table.cell(colspan: 3)[*algorithms part 3 and weighted graphs*],
  q([longest substring without repeating characters]), loc([algopatterns, ch 23], [window section]), lab([TDD]),
  q([two pointers, sorted pair sum, in-place dedupe]), loc([algopatterns, ch 23], [two pointers section]), lab([TDD]),
  q([binary search and the rotated array]), loc([algopatterns, ch 23], [binary search section]), lab([TDD]),
  q([greedy, jump game, interval scheduling]), loc([algopatterns, ch 23], [greedy section]), lab([TDD]),
  q([backtracking, subsets and permutations]), loc([algopatterns, ch 23], [backtracking section]), lab([TDD]),
  q([bit manipulation, single number, counting bits]), loc([algopatterns, ch 23], [bits section]), lab([TDD]),
  q([sorting internals, which sort when]), loc([algopatterns, ch 23], [sorting section]), lab([DRILL]),
  q([dijkstra, heap-driven shortest path]), loc([weightedgraphs, ch 24], [dijkstra section]), lab([TDD]),
  q([union-find with path compression]), loc([weightedgraphs, ch 24], [union-find section]), lab([TDD]),
  q([kruskal and prim, the mst pair]), loc([weightedgraphs, ch 24], [mst section]), lab([TDD]),
  q([when bellman-ford and floyd-warshall]), loc([weightedgraphs, ch 24], [negative and all-pairs section]), lab([DRILL]),
  table.cell(colspan: 3)[*distributed and systems floors*],
  q([replication, leaders, followers, and lag]), loc([distributed-answers, ch 25], [replication section]), lab([DRILL]),
  q([sharding and partitioning strategies]), loc([distributed-answers, ch 25], [sharding section]), lab([DRILL]),
  q([consensus and raft, honestly]), loc([distributed-answers, ch 25], [raft section]), lab([DRILL]),
  q([crdts versus distributed transactions]), loc([distributed-answers, ch 25], [crdts section]), lab([DRILL]),
  q([delivery semantics and idempotency]), loc([distributed-answers, ch 25], [delivery section]), lab([DRILL]),
  q([stack, heap, and allocators]), loc([systems-answers, ch 26], [stack and heap section]), lab([DRILL]),
  q([virtual memory, pages, and the tlb]), loc([systems-answers, ch 26], [virtual memory section]), lab([DRILL]),
  q([processes versus threads]), loc([systems-answers, ch 26], [processes section]), lab([DRILL]),
  q([epoll and the event loop]), loc([systems-answers, ch 26], [epoll section]), lab([DRILL]),
  q([c networking, sockets end to end]), loc([systems-answers, ch 26], [sockets section]), lab([DRILL]),
  table.cell(colspan: 3)[*handbook floors: math, mining, languages*],
  q([asymptotics and solving recurrences]), loc([math-answers, ch 27], [asymptotics section]), lab([DRILL]),
  q([probability you can compute at the board]), loc([math-answers, ch 27], [probability section]), lab([DRILL]),
  q([counting and combinatorics]), loc([math-answers, ch 27], [counting section]), lab([DRILL]),
  q([reading statistics, baselines, p-values, overfitting]), loc([math-answers, ch 27], [statistics section]), lab([DRILL]),
  q([exact binomial, auc, and a bootstrap interval, run live]), loc([math-answers, ch 27], [statistics workspace section]), lab([TDD]),
  q([backtesting without lookahead]), loc([math-answers, ch 27], [backtesting section]), lab([DRILL]),
  q([guarded promotion and multiple testing in a game tool]), loc([math-answers, ch 27], [guarded promotion section]), lab([DRILL]),
  q([similarity and distance measures]), loc([mining-answers, ch 28], [similarity section]), lab([DRILL]),
  q([clustering, k-means, hierarchical, dbscan]), loc([mining-answers, ch 28], [clustering section]), lab([DRILL]),
  q([itemsets, apriori and fp-growth]), loc([mining-answers, ch 28], [itemsets section]), lab([DRILL]),
  q([cosine neighbors and smoothed bayes, run live]), loc([mining-answers, ch 28], [cosine neighbors section]), lab([TDD]),
  q([the levelwise pass over baskets, counted and pruned]), loc([mining-answers, ch 28], [levelwise pass section]), lab([TDD]),
  q([pagerank and the pipeline view]), loc([mining-answers, ch 28], [pagerank section]), lab([DRILL]),
  q([the gil and what it actually locks]), loc([python-answers, ch 29], [gil section]), lab([DRILL]),
  q([the data model, dunders and protocols]), loc([python-answers, ch 29], [data model section]), lab([DRILL]),
  q([decorators, closures, scopes]), loc([python-answers, ch 29], [decorators section]), lab([DRILL]),
  q([asyncio versus threads]), loc([python-answers, ch 29], [asyncio section]), lab([DRILL]),
  q([metatables and metamethods]), loc([lua-answers, ch 30], [metatables section]), lab([DRILL]),
  q([coroutines versus javascript async]), loc([lua-answers, ch 30], [coroutines section]), lab([DRILL]),
  q([closures and environments against javascript]), loc([lua-answers, ch 30], [closures section]), lab([DRILL]),
  q([async await machinery, state machines and context]), loc([csharp-answers, ch 31], [async section]), lab([DRILL]),
  q([linq as an embedded dsl]), loc([csharp-answers, ch 31], [linq section]), lab([DRILL]),
  q([value versus reference, boxing]), loc([csharp-answers, ch 31], [value and reference section]), lab([DRILL]),
  q([the gc generations against go's]), loc([csharp-answers, ch 31], [gc section]), lab([DRILL]),
  table.cell(colspan: 3)[*the web platform: css, rendering, security*],
  q([the box model, content-box versus border-box]), loc([css-answers, ch 32], [box model section]), lab([EWC]),
  q([the cascade, specificity, which rule wins]), loc([css-answers, ch 32], [cascade section]), lab([TDD]),
  q([flex, grid, grow and fr arithmetic]), loc([css-answers, ch 32], [flex and grid section]), lab([EWC]),
  q([responsive, media queries, breakpoints]), loc([css-answers, ch 32], [responsive section]), lab([TDD]),
  q([the rendering pipeline, layout, paint, composite]), loc([rendering-answers, ch 33], [layout paint composite section]), lab([DRILL]),
  q([reflow versus repaint versus compositing]), loc([rendering-answers, ch 33], [reflow section]), lab([TDD]),
  q([the accessibility tree, semantic html]), loc([rendering-answers, ch 33], [accessibility tree section]), lab([TDD]),
  q([aria, contrast, keyboard paths, wcag]), loc([rendering-answers, ch 33], [aria contrast section]), lab([TDD]),
  q([the owasp taxonomy, naming a vulnerability family]), loc([security-answers, ch 34], [the taxonomy section]), lab([DRILL]),
  q([xss and csrf, escaping by context, SameSite=Lax, can cors prevent csrf]), loc([security-answers, ch 34], [xss and csrf section]), lab([TDD]),
  q([cors, the same-origin triple, preflight, the credentials error]), loc([security-answers, ch 34], [cors and the same-origin rule]), lab([TDD]),
  q([sql injection, concatenation versus placeholders, second-order]), loc([security-answers, ch 34], [sql injection section]), lab([TDD]),
  q([password storage lanes, 401 versus 403, idor, oauth oidc pkce]), loc([security-answers, ch 34], [authn, authz, tokens section]), lab([DRILL]),
  table.cell(colspan: 3)[*system design at altitude: estimation and prompts*],
  q([back of the envelope: the method and the sanity band]), loc([estimation-answers, ch 35], [the method section]), lab([DRILL]),
  q([the numbers every round expects, powers of two and the latency ladder]), loc([estimation-answers, ch 35], [the numbers section]), lab([DRILL]),
  q([storage, qps, headroom, five timed boards]), loc([estimation-answers, ch 35], [storage through boards sections]), lab([DRILL]),
  q([how to run a design prompt, the clock]), loc([design-prompts, ch 36], [the protocol section]), lab([DRILL]),
  q([design a url shortener]), loc([design-prompts, ch 36], [url shortener section]), lab([TDD, DRILL]),
  q([design a rate limiter, the distributed one]), loc([design-prompts, ch 36], [rate limiter section]), lab([DRILL]),
  q([design a news feed, fanout on write or read]), loc([design-prompts, ch 36], [news feed section]), lab([DRILL]),
  q([design a chat service, and long polling versus sse versus websockets]), loc([design-prompts, ch 36], [chat and delivery ladder sections]), lab([DRILL]),
  table.cell(colspan: 3)[*the human loop: behavioral, observed, negotiation, transfer*],
  q([tell me about yourself, the ninety second arc]), loc([behavioral-answers, ch 37], [tell me about yourself]), lab([DRILL]),
  q([the story cards, conflict, failure, ownership, proudest, wrong once]), loc([behavioral-answers, ch 37], [the story cards, the three scripts]), lab([DRILL]),
  q([why leaving, why us, weakness, why not hire]), loc([behavioral-answers, ch 37], [why leaving, why us, weakness]), lab([DRILL]),
  q([the gap, why no titles, five years, salary in a screen]), loc([behavioral-answers, ch 37], [the drill and the traps]), lab([DRILL]),
  q([the first five minutes, restating the problem, definition of done]), loc([observed-answers, ch 38], [the first five minutes]), lab([DRILL]),
  q([narration while writing, blanking, ai assist norms]), loc([observed-answers, ch 38], [narration, blanking, ai sections]), lab([DRILL]),
  q([timed mocks, the deck from this book, partner protocol]), loc([observed-answers, ch 38], [timed mocks from this book]), lab([DRILL]),
  q([take-home discipline, the debugging round, proving a fix]), loc([observed-answers, ch 38], [take-home, debugging]), lab([DRILL]),
  q([reading an offer, base, bonus, equity, benefits, scope]), loc([negotiation-answers, ch 39], [reading an offer section]), lab([DRILL]),
  q([anchoring, the offer conversation, no metrics as an asset]), loc([negotiation-answers, ch 39], [anchoring section]), lab([DRILL]),
  q([exploding offers, competing timelines, the acceleration ask]), loc([negotiation-answers, ch 39], [timelines section]), lab([DRILL]),
  q([the scripts: range answer, offer call, counter, accept, decline, after a no]), loc([negotiation-answers, ch 39], [scripts and closing sections]), lab([DRILL]),
  q([the transfer method, what transfers between languages]), loc([transfer-answers, ch 40], [the transfer method]), lab([DRILL]),
  q([our shop is java: jvm gc, virtual threads, streams, checked exceptions, spring]), loc([transfer-answers, ch 40], [java section]), lab([DRILL]),
  q([our shop is rust: ownership, option and result, no gc, the traps]), loc([transfer-answers, ch 40], [rust and traps sections]), lab([DRILL]),
)

#diagram([every question maps to a label; a missing row is a visible gap], length: 13pt, {
  // the label contract as a matrix, with the gap row dashed
  let row(y, label, a1, a2, audit) = {
    cdraw.content((2.5, y), [#label], size: 6.5pt)
    cdraw.content((9.0, y + 0.4), [#a1], size: 6pt)
    cdraw.content((9.0, y - 0.65), [#a2], size: 6pt)
    cdraw.content((17.5, y), [#audit], size: 6pt)
  }
  cdraw.content((2.5, 9.2), [label], size: 6pt)
  cdraw.content((9.0, 9.2), [its evidence], size: 6pt)
  cdraw.content((17.5, 9.2), [how to audit], size: 6pt)
  cdraw.line((0.8, 8.75), (22.5, 8.75), stroke: luma(120))
  row(7.7, "TDD", "a failing test first,", "then the code that passes", "run the suite")
  row(5.6, "EWC", "existing code walked,", "gated by the same verify", "read with the suite")
  row(3.5, "DRILL", "the spoken answer", "and its follow-ups", "grep the label")
  cdraw.rect((0.8, 1.3), (22.5, 2.5), stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((11.65, 1.9), [a question with no row: the gap is visible], size: 6pt)
})

== the workspaces behind the labels

#table(
  columns: (auto, 1fr, auto, auto),
  inset: 5pt,
  align: (left, left, center, center),
  table.header[*workspace*][*contents*][*runner*][*tests*],
  [ch02-go, ch02-cs], [paradigms in go and c\#], [go test, dotnet], [7, 12],
  [ch03-go, ch03-cs], [the seven structures], [go test, dotnet], [25, 22],
  [ch04-go], [graph traversal and topo sort], [go test], [10],
  [ch05-go, ch05-cs], [classics part 1], [go test, dotnet], [17, 29],
  [ch06-go, ch06-cs], [classics part 2], [go test, dotnet], [10, 13],
  [ch07-js], [js core demos], [node \-\-test], [22],
  [ch08-js], [js dom demos, styles, the centering choice], [node \-\-test], [16],
  [ch09-js], [from-scratch implementables and the combinator ladder], [node \-\-test], [40],
  [ch10-js], [csv to mongo migration], [node \-\-test], [10],
  [ch12-react], [react workspace, react 19 + router 7], [node \-\-test], [37],
  [ch15-go], [runtime, patterns, singleton], [go test], [16],
  [ch16-go], [four-layer testing on sqlite, golden master], [go test], [8],
  [ch17-go], [db answers on sqlite 3.53, geo], [go test], [9],
  [ch18-go], [tcp, udp, http, ws echo servers], [go test], [9],
  [ch20-go], [fetcher, rest api, schema, client limiter], [go test], [15],
  [ch21-go], [storefront, sse feed, deploys], [go test], [8],
  [ch22-go], [jetstream pipeline over embedded nats], [go test], [3],
  [ch23-go], [window, pointers, search, greedy, backtracking, bits], [go test], [13],
  [ch24-go], [dijkstra, union-find, kruskal, prim], [go test], [12],
  [ch27-go], [exact binomial, midranks, auc, bootstrap, holm and bh], [go test], [26],
  [ch28-go], [cosine neighbors, naive bayes, the levelwise pass], [go test], [22],
  [ch32-js], [css engine models and styles], [node \-\-test], [14],
  [ch33-js], [pipeline, a11y, contrast models], [node \-\-test], [10],
  [ch34-js], [security answer models, xss csrf cors sql headers], [node \-\-test], [14],
  [ch36-go], [base62 codec, windowed counter allocator], [go test], [11],
)

#diagram([29 workspaces under three runners, one verify gate], length: 13pt, {
  // the three runner families with their workspace and test counts
  let col(cx, runner, ws, tests) = {
    cdraw.rect((cx - 3.4, 5.4), (cx + 3.4, 8.6), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((cx, 8.1), [#runner], size: 6.5pt)
    cdraw.content((cx, 7.05), [#ws], size: 6pt)
    cdraw.content((cx, 6.05), [#tests], size: 6pt)
  }
  col(4.2, "go test", "17 workspaces", "221 tests")
  col(12.0, "dotnet test", "4 workspaces", "76 tests")
  col(19.8, "node --test", "8 workspaces", "163 tests")
  cdraw.content((12.0, 3.4), [29 workspaces, 460 tests, one gate], size: 6pt)
  cdraw.content((12.0, 2.4), [every suite runs in make verify], size: 6pt)
})

== pinned sources

Every online claim this book makes, with the access date it was
verified:

#table(
  columns: (1.7fr, 2.3fr, auto),
  inset: 5pt,
  align: (left, left, center),
  table.header[*claim*][*url*][*accessed*],
  ..sources.map(s => (table.cell[#s.topic], table.cell[#link(s.url)[#s.url]], table.cell[#s.accessed])).flatten(),
)

#diagram([claims pinned with urls and access dates, 2026-09-09/10/29], length: 13pt, {
  // the three verification dates with what each batch pinned
  cdraw.content((11.5, 7.9), [every online claim carries its url], size: 6pt)
  cdraw.content((11.5, 6.9), [and the date it was verified], size: 6pt)
  cdraw.content((4.6, 5.6), [5 rows: sqlite, go 1.26,], size: 6pt)
  cdraw.content((4.6, 4.6), [react, signals, jetstream], size: 6pt)
  cdraw.content((12.0, 5.6), [10 rows: the 2026 meta,], size: 6pt)
  cdraw.content((12.0, 4.6), [interview ai claims], size: 6pt)
  cdraw.content((19.4, 5.6), [12 rows: wcag, mdn, the security], size: 6pt)
  cdraw.content((19.4, 4.6), [wave, jep, the rust book], size: 6pt)
  cdraw.line((1.5, 3.4), (22.5, 3.4), stroke: luma(100), mark: (end: ">"))
  for x in (4.6, 12.0, 19.4) {
    cdraw.circle((x, 3.4), radius: 0.1, fill: luma(60))
  }
  cdraw.content((4.6, 2.8), [2026-09-09], size: 6.5pt)
  cdraw.content((12.0, 2.8), [2026-09-10], size: 6.5pt)
  cdraw.content((19.4, 2.8), [2026-09-29], size: 6.5pt)
  cdraw.content((11.5, 1.5), [27 rows, one per claim, all grep-able], size: 6pt)
})
