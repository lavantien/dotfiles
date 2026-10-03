#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= fastapi

The web framework of this book is a pinned third party, taught in full here
and used later: #xref-to("python", "capstone1") builds its fetch side on
stdlib urllib, and #xref-to("python", "capstone2") serves the finished report
over fastapi with pydantic response models and a TestClient suite. Nothing
before this chapter imports the package. Every sample below asserts the exact
pin, fastapi 0.141.1, the same way chapter 1 asserts the interpreter, and the
chapter walks the machine in four steps: what a fastapi app actually is down
at the protocol, the typed request pipeline with dependency injection, the
async half plus lifespan and the in-process client, and the boundaries of
what the pin installs and what it deliberately does not. Every behavioral
claim is an `ok` line in the four samples, 45 in total, or a sentence quoted
from a page at fastapi.tiangolo.com fetched 2026-09-12. The models are the
#xref-to("python", "pydantic") `BaseModel` in its serving role, and the event
loop under the async endpoints is the one #xref-to("python", "asyncio")
documented.

== the asgi model

The docs' first-steps page defines the object in one sentence, "`FastAPI` is
a Python class that provides all the functionality for your API", and the
technical note under it names the base: "`FastAPI` is a class that inherits
directly from `Starlette`. You can use all the Starlette functionality with
`FastAPI` too." Under this pin the base is starlette 1.6.0, and the
inheritance is the whole architecture in one fact, because starlette speaks
asgi, the python protocol with exactly three moving parts: an app is an async
callable that takes a `scope` dict describing one request, a `receive`
coroutine that yields incoming messages, and a `send` coroutine that accepts
outgoing ones. The sample pins the stack from inside before doing anything
else, the fastapi version, the starlette version, the subclass relation, and
the callable's parameter names:

#listing("python/samples/src/Ch22/model.py", first: 57, last: 72, caption: [the pin, the base class, and the interface: a fastapi app is a `scope, receive, send` callable])

The signature check is the chapter's thesis as an assertion. A server never
imports endpoint functions, it awaits the app callable and trades messages,
which means the protocol can be exercised with no server and no client at
all. The sample builds a scope dict by hand, `receive` answering an empty
http request body, `send` recording into a list, and drives the app with
plain `asyncio.run`:

#listing("python/samples/src/Ch22/model.py", first: 85, last: 100, caption: [the raw asgi call: a hand built scope in, two protocol messages out, json bytes included])

Exactly two messages come back, and their shapes are the protocol. The first
is `http.response.start`, status 200 and the headers as byte pairs, the
second `http.response.body` carrying `{"item_id": 7, "double": 14, ...}` as
raw bytes. The `double` value is the quiet proof of typed routing: the path
segment arrived as the string `"7"` and the endpoint multiplied it as the
integer 7, because the annotation on the path parameter is `int` and fastapi
converted before the function ran. The conversion is validation too, the
docs' query-params page states the rule generally, parameters "are converted
to that type and validated against it", and an unparseable path parameter is
rejected with the pydantic error shape rather than reaching the function.

Routing is the layer above the protocol. The first-steps page again: "The
`@app.get("/")` tells `FastAPI` that the function right below is in charge of
handling requests that go to: the path `/`, using a `get` operation." Each
decorator registers one `APIRoute` holding the path verbatim, and a fresh app
already carries four routes it never wrote, `/openapi.json`, `/docs`, the
docs' oauth redirect, and `/redoc`, the documentation surface the page
describes as "the automatic
interactive API documentation", powered by "the OpenAPI schema". The samples
build every app inside a factory function:

#listing("python/samples/src/Ch22/model.py", first: 24, last: 54, caption: [the request as a dict, and the factory: routes registered by decorator, state closed over per build])

#callout("note", "why the samples build apps with a factory, not a module global", [
  The tutorial examples put `app = FastAPI()` at module level, which is fine
  for one app per process. A factory that closes over its own `store` gives
  every test a fresh app with fresh state, and the sample proves the
  isolation the direct way, two builds of the same factory serve different
  stock counts after a write to one of them. The capstone reuses this shape,
  one `build_app()` over the finished pipeline, so its suite can construct
  independent instances per test.
])

Through a client, the same callable answers as http. Unknown paths are 404,
a known path under the wrong verb is 405, the query half appears only when
the name is not bound by the path template:

#listing("python/samples/src/Ch22/model.py", first: 102, last: 120, caption: [client facts: int conversion, query defaulting, 404 against 405])

#diagram([what each layer of a served request owns, and what it never touches], length: 13pt, {
  let xs = ((0.4, 4.8), (4.8, 12.0), (12.0, 18.6), (18.6, 21.8))
  let cell = (c, r, s, head) => {
    let (x0, x1) = xs.at(c)
    let y1 = 9.4 - r * 1.15
    cdraw.rect((x0, y1 - 1.15), (x1, y1), fill: if head { luma(235) } else if calc.even(r) { luma(245) } else { none }, stroke: luma(180))
    cdraw.content(((x0 + x1) / 2, y1 - 0.575), s, wrap: text.with(size: 6pt))
  }
  cell(0, 0, [layer], true)
  cell(1, 0, [owns], true)
  cell(2, 0, [never sees], true)
  cell(3, 0, [pinned by], true)
  cell(0, 1, [uvicorn, #linebreak() the server], false)
  cell(1, 1, [sockets, http parsing, #linebreak() worker processes], false)
  cell(2, 1, [your endpoint code], false)
  cell(3, 1, [prose only, #linebreak() not installed], false)
  cell(0, 2, [the app #linebreak() callable], false)
  cell(1, 2, [the asgi protocol: #linebreak() scope, receive, send], false)
  cell(2, 2, [a socket], false)
  cell(3, 2, [starlette 1.6.0, #linebreak() asserted], false)
  cell(0, 3, [fastapi #linebreak() on top], false)
  cell(1, 3, [routing, validation, #linebreak() dependencies, docs routes], false)
  cell(2, 3, [the socket byte stream], false)
  cell(3, 3, [fastapi 0.141.1, #linebreak() asserted], false)
  cell(0, 4, [your #linebreak() endpoint], false)
  cell(1, 4, [the work: models in, #linebreak() json out], false)
  cell(2, 4, [protocol plumbing], false)
  cell(3, 4, [the sample, #linebreak() in the factory], false)
  cdraw.content((11.0, 1.6), [each layer calls down by awaiting, never by importing the one below], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== validation and dependency injection

The request pipeline is typed end to end, and the types are pydantic models,
the same `BaseModel` of #xref-to("python", "pydantic") in its serving role.
A parameter annotated with a model is the request body, parsed and validated
before the endpoint runs. A parameter annotated `int` or `str | None` and not
bound by the path template is a query parameter, the docs: "When you declare
other function parameters that are not part of the path parameters, they are
automatically interpreted as 'query' parameters." The sample's app is small
and carries both models, a guarding dependency, and the status codes that
make the contract explicit:

#listing("python/samples/src/Ch22/validate.py", first: 24, last: 43, caption: [the pipeline endpoints: a body model in, a response model out, a dependency taking its own query parameter])

The dependency is the second half of the section. The docs define one from
below: "It is just a function that can take all the same parameters that a
_path operation function_ can take", and per request fastapi resolves the
tree, "Calling your dependency ('dependable') function with the correct
parameters", getting the result and assigning it to the endpoint's parameter.
The `authorize` dependency reads a query `key` exactly the way an endpoint
would, rejects with `HTTPException` before the endpoint is reached, and its
return value travels into the payload:

#listing("python/samples/src/Ch22/validate.py", first: 65, last: 95, caption: [the guarantees checked: 201 by declaration, the model stripped, extra keys ignored, the 422 shape pinned])

The 422 body is worth reading closely because it is a pydantic error list
wearing a detail key. The docs' query page shows the same shape for a missing
parameter, `{"type": "missing", "loc": ["query", "needy"], "msg": "Field
required"}`, and the sample pins all three fields for a missing body member,
type `missing`, `loc` naming `["body", "grams"]`, `msg` `Field required`.
Wrong types get their own tag, `float_parsing`, and the `loc` list is the
address of the failure, body or path or query, field name last. The other
error surface is deliberately different: `HTTPException` answers with a
string detail, so a 422 is always a list of validation findings and a raised
exception is always prose:

#listing("python/samples/src/Ch22/validate.py", first: 105, last: 118, caption: [query validation and the exception surface: a list for 422, a string for a raised 404])

`response_model` is a guarantee, not a comment. The `create` endpoint has no
response model, so everything it returns ships, including the internal auth
marker. The `read` endpoint declares `response_model=PartOut` and returns a
dict carrying the same kind of internal field, and the filter removes it:
only `name` and `bin` cross. The two checks side by side are the whole
argument, the identical leak attempted twice, one filtered and one not:

#listing("python/samples/src/Ch22/validate.py", first: 120, last: 132, caption: [204 with an empty body, and a dependency that answers 401 leaving no state behind])

The cache rule comes from the sub-dependencies page: "If one of your
dependencies is declared multiple times for the same _path operation_, for
example, multiple dependencies have a common sub-dependency, `FastAPI` will
know to call that sub-dependency only once per request", saving the value
"and pass it to all the 'dependants' that need it in that specific request".
The `stamped` endpoint takes the same dependency twice, and the call log says
`stamp` once per request, once more for the next request, a per-request cache
rather than a global one. The last check is an ordering fact the pipeline
figure owes: on a request whose body is then rejected, the dependency log
still shows `authorize`, the front half of the pipeline runs before the body
verdict lands:

#listing("python/samples/src/Ch22/validate.py", first: 134, last: 147, caption: [the dependency cache per request, and the dependency that ran before a rejected body])

#callout("pitfall", "no response_model means no filter, and the docs will not warn you", [
  An endpoint returning a dict of internal fields with no `response_model`
  ships every key, the sample's first check carries an `internal` auth marker
  straight to the client as json. The tutorial flow builds small dicts where
  that is harmless, so the habit transfers silently to the endpoint that
  returns a user record with a password hash inside. Declare the response
  model on every endpoint that returns structured data, and let the check
  pattern of this sample, assert the exact payload key set, fail loudly when
  a new field leaks.
])

#diagram([the typed request pipeline with its two early exits], length: 13pt, {
  let stage(x, t) = {
    cdraw.rect((x, 6.4), (x + 3.0, 7.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.5, 7.0), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((1.9, 8.4), [request], wrap: text.with(size: 6pt))
  cdraw.line((1.9, 8.1), (1.9, 7.6), stroke: luma(100), mark: (end: ">"))
  stage(0.4, [route #linebreak() match])
  stage(4.1, [dependencies #linebreak() solved])
  stage(7.8, [parameters #linebreak() validated])
  stage(11.5, [endpoint #linebreak() runs])
  stage(15.2, [response_model #linebreak() filter])
  stage(18.9, [json #linebreak() out])
  for x in (3.4, 7.1, 10.8, 14.5, 18.2) {
    cdraw.line((x, 7.0), (x + 0.7, 7.0), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.rect((6.0, 3.9), (11.0, 5.1), fill: luma(215), radius: 0.02)
  cdraw.content((8.5, 4.5), [422: the pydantic #linebreak() error list], wrap: text.with(size: 6pt))
  cdraw.line((10.2, 6.4), (8.5, 5.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.rect((13.5, 3.9), (18.5, 5.1), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((16.0, 4.5), [exception raised: #linebreak() status plus string], wrap: text.with(size: 6pt))
  cdraw.line((14.3, 6.4), (16.0, 5.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((11.0, 2.6), [the call log shows the dependency ran even when the body verdict was 422, #linebreak() the front half of the pipe is not skipped on a late rejection], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 1.4), [the cache is per request: same dependency twice in one tree, one call, #linebreak() the next request pays again], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== async endpoints, lifespan, and the testclient

An `async def` endpoint is a coroutine the framework awaits, on the same kind
of loop #xref-to("python", "asyncio") spent its chapter on. The sample's
`ping` endpoint captures `asyncio.get_running_loop()` from inside, awaits a
suspension, and returns, so the checks can see what actually carried it: a
live loop, and on this machine the `ProactorEventLoop`, the windows default
chapter 21 asserted for `asyncio.run`. Lifespan is the startup and shutdown
contract, an async context manager passed as `FastAPI(lifespan=...)`, the
docs: "The first part of the function, before the `yield`, will be executed
before the application starts", and "the part after the `yield` will be
executed after the application has finished", with the older
`startup`/`shutdown` handlers set aside, "It's all `lifespan` or all events,
not both":

#listing("python/samples/src/Ch22/serve.py", first: 14, last: 38, caption: [the async half: a lifespan context manager and two async endpoints, one queuing a background task])

The client that drives all of it never opens a port. `TestClient` is
starlette's, the testing page says so plainly, "`FastAPI` provides the same
`starlette.testclient` as `fastapi.testclient` just as a convenience for
you, the developer. But it comes directly from Starlette", and "It is based
on HTTPX, which in turn is designed based on Requests". The sample checks
both facts as identities, the re-export is the same class object, and the
class's own method resolution order names `httpx2.Client` as a base, which
is why httpx2 2.12.0 sits in the requirements file as a test-only pin that
no sample imports:

#listing("python/samples/src/Ch22/serve.py", first: 102, last: 109, caption: [the two engine identities: the re-export is one class, and its base is the httpx2 engine])

The loop facts came out of the probes and are worth the ink. A bare request
through a plain `TestClient(app)` builds a fresh portal loop for that one
request and discards it, two requests, two distinct loop objects. Inside
`with TestClient(app) as held` one portal lives for the whole session, the
same loop object serving both requests, and that is also the only mode in
which lifespan runs, startup on enter, shutdown on exit, exactly bracketing
the session:

#listing("python/samples/src/Ch22/serve.py", first: 41, last: 62, caption: [the async round trip, the loop class from inside, and the fresh portal a bare request builds])

#listing("python/samples/src/Ch22/serve.py", first: 64, last: 83, caption: [one loop per session under the context manager, and the exact lifespan bracket asserted])

Background tasks are the small end of async work. The docs: "You can define
background tasks to be run *after* returning a response", and the class
"comes directly from `starlette.background`". The endpoint queues
`EVENTS.append` and returns; the event log then shows the endpoint body
first, the task second, before the shutdown that ends the session. A bare
client, the last check says, runs no lifespan at all, which is the default
worth knowing, tests that never enter the context manager never pay startup
and never see the state it builds:

#listing("python/samples/src/Ch22/serve.py", first: 85, last: 100, caption: [background task ordering, and the bare client that never runs lifespan])

#callout("pitfall", "in process does not mean no socket object, and a monkeypatch will find the difference", [
  While proving the no-network claim, a draft sample replaced
  `socket.socket` with a raising stub and ran a request through the client.
  The request failed inside `asyncio` itself: the portal's fresh
  `ProactorEventLoop` builds its wakeup self-pipe as a socketpair, so
  constructing a loop touches the socket module without ever touching a
  network. The honest claim, and the one this chapter makes, is narrower and
  true: no listener is opened, no connection is made, the windows firewall
  never asks, and the request is served by an in-process call. Assert what
  the machine proves, not the slogan.
])

#diagram([the client's two modes as state machines: a fresh loop per request, or one held session with lifespan brackets], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((5.4, 9.4), [bare: TestClient(app), one request at a time], wrap: text.with(size: 6.5pt))
  box(0.4, 7.4, 3.4, 1.2, [request #linebreak() arrives])
  box(4.6, 7.4, 4.2, 1.2, [portal builds #linebreak() a fresh loop])
  box(9.2, 7.4, 4.0, 1.2, [app awaited #linebreak() on that loop])
  box(13.6, 7.4, 4.0, 1.2, [response #linebreak() returns])
  box(18.0, 7.4, 3.8, 1.2, [loop #linebreak() discarded], fill: luma(215))
  cdraw.line((3.8, 8.0), (4.6, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.8, 8.0), (9.2, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.2, 8.0), (13.6, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.6, 8.0), (18.0, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.4, 5.2), [with TestClient(app) as held: one session], wrap: text.with(size: 6.5pt))
  box(0.4, 3.2, 4.4, 1.2, [enter the with: #linebreak() lifespan startup])
  box(5.6, 3.2, 5.0, 1.2, [one portal kept #linebreak() for the session])
  box(11.4, 3.2, 4.6, 1.2, [requests share #linebreak() the same loop])
  box(16.8, 3.2, 5.0, 1.2, [exit the with: #linebreak() lifespan shutdown], fill: luma(215))
  cdraw.line((4.8, 3.8), (5.6, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.6, 3.8), (11.4, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, 3.8), (16.8, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.9, 7.4), (19.9, 6.8), stroke: luma(140), dash: "dashed")
  cdraw.line((19.9, 6.8), (2.1, 6.8), stroke: luma(140), dash: "dashed")
  cdraw.line((2.1, 6.8), (2.1, 7.4), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  box(0.4, 1.0, 10.4, 1.4, [background tasks ride the request cycle: #linebreak() endpoint body first, task second])
  box(11.4, 1.0, 10.4, 1.4, [lifespan is the with block's privilege: #linebreak() a bare client skips startup and shutdown], fill: luma(245))
  cdraw.content((11.0, 0.3), [the engine is httpx2 over an anyio portal, the app is called, never dialed], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== boundaries

The version line is 0.x, and the project's own numbering says so before any
commentary does, the version string starts with 0, and the docs treat pre-1.0
as the reason to pin, the deployment pages open with the advice to "pin" the
version to "the specific latest version that you know works correctly". The
chapter does what the book always does, the exact pin in
`books/python/requirements.txt` and the assert in-sample, and 0.141.1 sits
above the release that made this book's interpreter legal, release notes
0.118.3, 2025-10-10, "Add support for Python 3.14":

#listing("python/samples/src/Ch22/boundary.py", first: 17, last: 41, caption: [the pin agreed between metadata and import, the 0.x line, and the standard extra's nine members counted])

What the pin installs is deliberately thin. The base requirement list holds
starlette, pydantic, and three typing helpers, nothing else, so a bare
`pip install fastapi==0.141.1` ships no server and no client. The kitchen
sink lives one bracket away, `pip install "fastapi[standard]"`, and the
sample reads the installed metadata to count it, nine packages including
`uvicorn[standard]`, `httpx`, jinja2, python-multipart, email-validator,
pydantic-settings, pydantic-extra-types, the fastapi cli, and fastar. The
docs' serving story rides that extra, the deployment pages describe "using
the `fastapi` command, that runs Uvicorn, running a single process", with
`--workers` for more, and this book stops at the prose. No sample serves a
socket, and the venv makes that a checked fact rather than a promise:

#listing("python/samples/src/Ch22/boundary.py", first: 43, last: 76, caption: [uvicorn absent, the engine pin agreed at httpx2 2.12.0, the warning-free load, and the 3.14 support line])

The engine choice is the last boundary, and starlette 1.6.0 makes it in
import order: the installed testclient tries `import httpx2 as httpx`
first, and only when httpx2 is missing does it fall back to plain httpx,
warning while it does, ``Using `httpx` with `starlette.testclient` is
deprecated; install `httpx2` instead.`` This venv installs httpx2 2.12.0 as
the test-only pin, so the first import wins, the deprecated name is gone
from the venv entirely, and the sample proves the clean load the direct way,
reloading the module under a recording filter and counting zero
deprecation warnings. One wrinkle worth knowing before reading any stack
trace: fastapi's own metadata still lists httpx in its standard extra, so
the client the docs install for you and the engine starlette actually loads
are two different names on this line. And when a future starlette drops the
httpx fallback outright, nothing here changes, the pin already sits on the
preferred side.

The client side of the capstone keeps its own boundary.
#xref-to("python", "capstone1") fetches over stdlib urllib in worker
threads, so the httpx2 pin never migrates from test-only to runtime, and
#xref-to("python", "capstone2") serves the report api over fastapi with the
TestClient suite from this chapter. What this chapter's api does not do is
the rest of the list: no database, no authentication beyond a query key, no
middleware, no websockets, no openapi customization, all of it fastapi
surface the docs cover and the capstone does not need. The chapter's job was
the machine under the decorators, and every layer of it is pinned.

#diagram([the two installs, before and after the extra], length: 13pt, {
  let left(y, t, fill: luma(235), stroke: none) = {
    cdraw.rect((0.4, y), (9.0, y + 1.1), fill: fill, stroke: stroke, radius: 0.02)
    cdraw.content((4.7, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  let right(y, t) = {
    cdraw.rect((12.8, y), (21.4, y + 1.1), fill: luma(205), radius: 0.02)
    cdraw.content((17.1, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((4.7, 9.6), [pip install fastapi==0.141.1], wrap: text.with(size: 6.5pt))
  cdraw.content((17.1, 9.6), [pip install fastapi[standard]], wrap: text.with(size: 6.5pt))
  left(8.2, [starlette>=0.46.0, the asgi layer])
  left(6.8, [pydantic>=2.9.0, the validation layer])
  left(5.4, [typing-extensions, typing-inspection, #linebreak() annotated-doc])
  left(4.0, [no server, no client, no templates], fill: none, stroke: (paint: luma(160), dash: "dashed"))
  right(8.2, [uvicorn[standard], the server])
  right(6.8, [httpx, the client])
  right(5.4, [jinja2, python-multipart, #linebreak() email-validator])
  right(4.0, [pydantic-settings, pydantic-extra-types, #linebreak() fastapi-cli, fastar])
  cdraw.line((9.0, 6.4), (12.8, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.9, 6.9), [the extra], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.4, 1.6), (21.4, 3.0), fill: luma(245), radius: 0.02)
  cdraw.content((10.9, 2.3), [this book's venv: the base pin, plus httpx2 2.12.0 test-only, #linebreak() plus ruff tools-only, uvicorn absent and checked, the capstone fetches over stdlib urllib], wrap: text.with(size: 6pt))
  cdraw.content((10.9, 0.7), [serving under uvicorn stays prose: the deployment pages' fastapi command runs uvicorn], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "45 checks, every one deterministic on this box", [
  A scoped run, `pwsh tools/run-py-samples.ps1 -Chapter Ch22`, resolves the
  toolchain and the hashed venv, then walks this chapter's four samples
  through the run, format, and dis legs and reports: 4 files, 45
  checks, 0 dis assertions, format clean. `model.py` contributes 14, the pin,
  the subclass and signature facts, the raw asgi call, routing, the default
  documentation routes, and factory isolation. `validate.py` adds 11, the
  201 and 204 contracts, the response model filter, the 422 shapes for body,
  path, and query, the two error surfaces, the rejecting dependency, the
  per-request cache, and the dependency that ran before a rejected body.
  `serve.py` adds 10, the async round trip, the proactor loop from inside,
  the portal contrast between bare and context managed clients, the lifespan
  bracket, background task ordering, and the two engine identities.
  `boundary.py` adds 10, the metadata agreement, the 0.x line, the standard
  extra counted at nine, uvicorn absent, the engine pin agreed at httpx2
  2.12.0 with the deprecated name gone, the warning-free engine load, and
  the 3.14 support line. No sample opens a socket, installs a package, or
  runs a server. The scoped run leaves the capstone leg to the unscoped
  gate by design, and the dis leg is fully live with no bytecode rows
  pinned in this chapter.
])

sources: fastapi.tiangolo.com/tutorial/first-steps (the FastAPI class, the
Starlette inheritance note, the path operation decorator, the docs and
openapi routes), fastapi.tiangolo.com/tutorial/query-params (non path
parameters read as query, conversion and validation, the 422 example shape),
fastapi.tiangolo.com/tutorial/dependencies (a dependency takes the same
parameters as a path operation, what fastapi does on each request),
fastapi.tiangolo.com/tutorial/dependencies/sub-dependencies (the
sub-dependency called once per request, the cache, use_cache),
fastapi.tiangolo.com/tutorial/testing (the docs' httpx basis for
TestClient, the starlette re-export), fastapi.tiangolo.com/advanced/events (the lifespan parameter,
before and after the yield, all lifespan or all events),
fastapi.tiangolo.com/tutorial/background-tasks (tasks after the response,
the starlette origin of the class),
fastapi.tiangolo.com/deployment/server-workers (the fastapi command running
uvicorn, single process, workers), fastapi.tiangolo.com/deployment/versions
(the advice to pin), fastapi.tiangolo.com/release-notes (0.118.3, add
support for Python 3.14), and pypi.org/project/fastapi (the 0.141.1 pin and
its metadata), accessed 2026-09-12. The engine facts are probed in the book
venv the same day: starlette 1.6.0 beneath, the `import httpx2 as httpx`
engine order read out of the installed starlette's testclient source with
its httpx fallback warning, the standard extra's nine members, and the
portal's `ProactorEventLoop` observed from inside an async endpoint. Sample
behavior verified by `make verify-py`, 45 checks in chapter 22 of the
samples suite.
