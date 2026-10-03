#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= ship it

The solution ends as a directory of tests unless it also ships. This
chapter turns the service into an artifact and a lane: a multi-stage
image, one compose command that brings it up healthy, a make gate
replaying the contract over that stack, a CI workflow running the
same legs on every push, and the two envelopes platforms ask for, a
helm chart and a terraform slice. Everything leans on machinery the
earlier chapters built, and on the composition table this chapter
moved into `Deploy/Wire.cs`. One rule disciplines the whole chapter:
the compose lane is the only thing that executes, and the chart, the
terraform, and the workflow ship as taught copies.

== the image

Two stages, one boundary. The builder is the sdk image pinned to the
book's exact rc version, `sdk:11.0.100-rc.1`, which exists only to
run the compiler, and the runtime is the matching
`aspnet:11.0.0-rc.1`, which exists only to run the app. The copy
across the boundary is the publish output. Go's chapter crossed with
one static file into scratch, legal because its store engine was pure
go. This service's store is sqlite through the native bundle, a
shared library the runtime must carry, so scratch is not available
and the aspnet base is the floor.

Four decisions earn a second look. The csproj copy precedes the
source copy so the restore layer caches independently of code edits.
The `/data` directory is created in the builder and copied with an
owner, because a named volume inherits image ownership on first mount
and a volume over a root-owned directory would deny the container
user its database. The user is numeric, 1654, the uid the base image
ships as `app`. And the `GOAPI_` names carry over from the go lane
deliberately: the contract pins the `goapi_` metric series and the
token issuer, so one parameter family and one frozen contract serve both
lanes, each with its own compose file:

#listing("csharp-net/api/Dockerfile", first: 4, last: 27, caption: [the whole image: sdk builder, aspnet runtime, user 1654, the version arg])

The healthcheck has the shape problem the go chapter met in reverse:
the aspnet image carries no curl and no wget, so the answer is the one
executable that does exist, the service itself. `ShipProbe` accepts
`--ready-probe`, resolves the address from `ASPNETCORE_URLS`, or the
image default `ASPNETCORE_HTTP_PORTS`, rewrites the host to loopback,
and asks its own `/readyz`. Ready is 200 and only 200, a 503 still
means do not route traffic here. The build context keeps one honest
difference: this vehicle has bin and obj trees that would overwrite
the container's restore, so a minimal `.dockerignore` excludes them
and the non-service trees, the trade the go chapter stated instead
of paying because a go module has no build outputs.

#diagram([two stages, one boundary: the builder dies with the build, aspnet runs the app], length: 13pt, {
  cdraw.rect((1.0, 6.2), (21.9, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.2), [#"sdk:11.0.100-rc.1 builder"], size: 6.5pt)
  cdraw.line((11.5, 5.9), (11.5, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((3.4, 1.2), (19.6, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 3.6), [#"aspnet:11.0.0-rc.1 runtime"], size: 6.5pt)
})

== compose one command

The compose file is one service and its volume, and the contract it
enforces is the return value of one command. `docker compose up -d
--build --wait` builds, creates, starts, and blocks until the
healthcheck passes, so a green up means the image compiled, the
migrations ran as a hosted startup step against a fresh volume, and
the listener answers probes. `down -v` removes the volume in the same
breath, so every lane run starts from migration zero:

#listing("csharp-net/api/compose.yml", first: 14, last: 36, caption: [the whole system: env, both listeners, the volume, the probe, host ports off 8080])

The environment block carries exactly what construction demands. The
jwt secret must be present or the composition refuses to start in
production, loudly: a missing secret is a crash the orchestrator
restarts and an operator reads, never a running service signing
tokens with an empty key. The value in the file is a development
constant, and both platform envelopes exist partly to replace it. The
second listener is the same discipline for the observability surface,
`GOAPI_METRICS_ADDR` binds a second kestrel endpoint for the
exposition, unpublished by every production shape, and the host side
of both mappings sits on 18080 and 16090, because shared dev machines
carry loopback shadows on 8080 and a lane must be the only thing
under its ports. Compose up is the only command that touches the
schema:

#diagram([what a green up proves, in order], length: 13pt, {
  let step(x, w, top, sub) = {
    cdraw.rect((x, 4.6), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), sub, size: 6pt)
  }
  step(0.8, 4.4, [build], [image compiles])
  step(6.2, 4.4, [create + start], [env and volume mount])
  step(11.6, 4.4, [migrations], [hosted step, version records])
  step(17.0, 4.4, [probe passes], [--wait returns 0])
  cdraw.line((5.3, 5.8), (6.1, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 5.8), (11.5, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.1, 5.8), (16.9, 5.8), stroke: luma(100), mark: (end: ">>"))
})

== the docker lane as a gate

The lane is one make target, mirroring the go lane's two-gate rule:
the plain solution gate never needs a daemon, and the docker lane
never runs silently, a missing daemon a loud red:

#snippet(
  "verify-csapi-docker:\n"
  + "\t@docker info >/dev/null 2>&1 || { echo \"docker daemon not reachable.\" >&2; exit 1; }\n"
  + "\t@cd books/csharp-net/api && docker compose down -v >/dev/null 2>&1 || true && \\\n"
  + "\t\ttrap 'docker compose down -v' EXIT && \\\n"
  + "\t\tdocker compose up -d --build --wait && \\\n"
  + "\t\tCSHARPAPI_URL=http://127.0.0.1:18080 \\\n"
  + "\t\tCSHARPAPI_METRICS_URL=http://127.0.0.1:16090 \\\n"
  + "\t\tdotnet test integration/CsharpBook.Api.IntegrationTests.csproj; rc=$$?; exit $$rc",
  lang: "makefile",
)

Two environment families live in this lane and never mix. The
`GOAPI_` names are the vehicle's config surface, the same keys in
compose, the chart, and the terraform slice, kept for go-lane
parity. The `CSHARPAPI_URL` and `CSHARPAPI_METRICS_URL` names are
the lane's own probe coordinates, read by the integration suite and
set by the make target and the ci job, never by the service. The
split guards a failure mode: renaming one family without the other
makes the lane silently probe its defaults, a green suite pointed at
nothing, so the two lists change together or not at all.

The integration project lives outside `Api.slnx`, the faithful
mirror of go's docker build tag: plain `dotnet test Api.slnx` never
sees these files, and the CI module job compiles the project every
push so the suite cannot rot behind its lane. The suite replays the
contract's golden scenarios over the real listener with a real clock,
real uuids, and real wiring, asserting the layer under the frozen
bytes. The ETag rule is the sharpest example, a strong ETag is the
sha256 of the exact response body, so the suite recomputes the hash
over the wire bytes and compares:

#listing("csharp-net/api/integration/ApiLaneTests.cs", first: 111, last: 124, caption: [the etag check recomputed over live bytes, not frozen ones])

Six tests cover the contract's scenarios: both probes and the two
routing envelopes, the register replay login walk, the etag duel with
its one 200 and one 412, the rate limit drain to a 429, the reports
idempotent pair, and the metrics exposition off the internal listener.
The lane also taught two platform facts the in-process suites could
not see: kestrel disallows synchronous io by default, and the
in-memory test host polices it just the same, a synchronous read of
the request body and a synchronous write of the response both throw
at its default. The tests had stayed green only because the sync read
ran over `DefaultHttpContext`, the bare unit recorder with no body
control feature, and the harness had not yet mounted the gate, so the
exposition's synchronous write and the login bucket's synchronous
body read died on the real listener, fixed with scoped
`AllowSynchronousIO` flips both hosts honor, and `Uri` has no plus
operator on this runtime, so a base plus
a path string concatenates into a double slash the router answers
with a route miss:

#diagram([the gate: one lane, one trap, no skips], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.5), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.6), sub, size: 6pt)
  }
  box(0.8, 3.8, [preflight], [docker info or loud red])
  box(5.2, 4.2, [compose up], [build, wait for health])
  box(9.9, 4.2, [lane tests], [six replays on 18080])
  box(14.6, 3.8, [trap fires], [down -v on any exit])
  cdraw.line((4.7, 6.0), (5.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.5, 6.0), (9.8, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.2, 6.0), (14.5, 6.0), stroke: luma(100), mark: (end: ">>"))
})

== ci on GitHub Actions

The workflow is the same gate wearing a badge: the solution legs
exactly as the repository runs them locally, format verification, the
full suite, the integration compile check. The path filter keeps it
out of commits touching nothing under the service tree, and the setup
action pins the same rc sdk the book builds under:

#listing("csharp-net/api/deploy/ci/ci.yml", first: 13, last: 29, caption: [the module job: the local legs plus the lane-project compile check])

The image job proves the artifact builds clean, one docker build
with the commit sha as the `VERSION` argument. It pushes nowhere: a
registry and a release policy are a repository decision.

#diagram([push to ci to image: three jobs, one dependency edge], length: 13pt, {
  cdraw.rect((0.8, 5.2), (5.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.1, 6.9), [push or pr], size: 6.5pt)
  cdraw.content((3.1, 6.0), [paths under the service], size: 6pt)
  cdraw.rect((8.6, 5.2), (14.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 6.9), [module job], size: 6.5pt)
  cdraw.line((5.6, 6.4), (8.4, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.8, 6.5), (22.2, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.0, 7.7), [lane job], size: 6.5pt)
  cdraw.content((19.0, 6.9), [compose + six tests], size: 6pt)
  cdraw.line((14.6, 7.4), (15.6, 7.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.8, 3.4), (22.2, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.0, 4.7), [image job], size: 6.5pt)
  cdraw.content((19.0, 3.9), [docker build, sha as version], size: 6pt)
  cdraw.line((14.6, 4.4), (15.6, 4.4), stroke: luma(100), mark: (end: ">>"))
})

#callout("note", "why a taught copy", [
  The workflow lives at `api/deploy/ci/ci.yml`, not
  `.github/workflows/`, because this repository keeps no `.github`
  directory and corpus ci is not ratified. The file is byte for byte
  what a service repository would carry, and the make lane runs.
])

== helm the service envelope

The chart is the service wearing kubernetes. `Chart.yaml` declares
the name and version pair, `values.yaml` is the entire configuration
surface a reviewer diffs, and the templates render the four objects
the platform needs. The deployment carries the service's own
contracts: the probes split along the line chapter 32 drew, liveness
on `/healthz` gets a restart, readiness on `/readyz` gets a pull from
the endpoints list, which is how a draining pod cooperates with a
rolling deploy:

#listing("csharp-net/api/deploy/helm/csharpapi/templates/deployment.yaml", first: 20, last: 43, caption: [the container: numeric user matching the image, the secret by reference, both probes])

Three details match the image on purpose. The securityContext
repeats the numeric uid, 1654. The jwt secret arrives through a
`secretKeyRef`, never a values entry, keeping the reviewable file
free of credentials. And the resources block is templated from values
because the scheduler and the autoscaler both read it, and a service
without requests is one the cluster cannot schedule honestly. The
chart publishes only the main port, the kubernetes shape of the
internal-listener ruling:

#diagram([the chart's layers: values flow down, objects render out], length: 13pt, {
  cdraw.rect((3.6, 6.6), (19.4, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.1), [values.yaml], size: 6.5pt)
  cdraw.rect((3.6, 4.0), (19.4, 6.0), fill: luma(222), radius: 0.02)
})

== terraform for this service

Terraform the language, module structure, and the provider catalog
belong to the cloud book. This file is the service's slice of that
practice, one fargate service behind one load balancer, one alarm on
the tail, a decision record more than a lesson in the tool:

#listing("csharp-net/api/deploy/terraform/ecs.tf", first: 88, last: 107, caption: [the container definition: image, env, the secret by reference])

The task definition runs the same image compose runs, with awsvpc
networking and the secret pulled from ssm at container start. The
target group probes `/healthz` with a deregistration delay of 30
seconds, the drain window chapter 32's shutdown owns the inside of,
and `desired_count` defaults to 1 because the store is one file set
on the task's volume and two tasks would be two databases wearing
one name. The alarm reads the tail off the platform: cloudwatch
computes the p99 extended statistic for target response time, so the
pager watches the same number the load chapter defends:

#diagram([apply to ecs to alb: the service's aws slice in one line], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.6), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.5), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.6), sub, size: 6pt)
  }
  box(0.8, 4.0, [terraform], [module, state, plan])
  box(5.4, 4.2, [ecs fargate], [task from the image])
  box(10.2, 4.6, [alb + target group], [probe /healthz, delay 30])
  box(15.4, 3.6, [cloudwatch], [p99 alarm, 3 periods])
  cdraw.line((4.9, 5.9), (5.3, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.7, 5.9), (10.1, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.9, 5.9), (15.3, 5.9), stroke: luma(100), mark: (end: ">>"))
})

== the shipped checklist

The lane ends where it started, with each chapter's property, and
the fold added one artifact: the composition table, `Deploy/Wire.cs`,
one writer, chapter order, every family in one file the way go's
`wire.go` is, `Program.cs` naming it twice and holding nothing else.
The listing is the table's second half, every route wired:

#listing("csharp-net/api/src/CsharpBook.Api/Deploy/Wire.cs", first: 107, last: 125, caption: [every route wired, chapter labeled, one table])

#diagram([the readiness table: twelve chapters, twelve properties, all proven], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [22 kernel: one envelope], [on every failure, over the wire])
  cell(17.1, 8.3, 10.0, [23 middleware: the stack], [ids, log, deadline, recover])
  cell(5.9, 6.9, 10.0, [24 users: validation], [plus keyset pagination])
  cell(17.1, 6.9, 10.0, [25 authn: pbkdf2], [sessions and rotating jwt])
  cell(5.9, 5.5, 10.0, [26 authz: rbac], [owner checks, audited routes])
  cell(17.1, 5.5, 10.0, [27 store: migrations], [transactions, wal isolation])
  cell(5.9, 4.1, 10.0, [28 conc: the duel], [etag plus idempotent replay])
  cell(17.1, 4.1, 10.0, [29 cache: lru with ttl], [and the stampede guard])
  cell(5.9, 2.7, 10.0, [30 limit: token bucket], [429 with Retry-After])
  cell(17.1, 2.7, 10.0, [31 obs: the exposition], [on the internal listener])
  cell(5.9, 1.3, 10.0, [32 load: drain], [admission and no leaks])
  cell(17.1, 1.3, 10.0, [33 ship: the lane], [proving all of the above])
})

The chapter declares what it does not teach again: docker's storage
model, the runtime, and networking are the infrastructure book's, and
the terraform workflow lives in the cloud book. What this chapter
owns is the narrow band between a green solution and a running
service: the image, the command, the gate, and the two envelopes.

sources: the container tags verified against the registry itself,
sdk 11.0.100-rc.1 and aspnet 11.0.0-rc.1, the base image's app user
at uid 1654 and its ASPNETCORE_HTTP_PORTS default read off the pulled
image, docker docs at docs.docker.com, the setup-dotnet releases at
github.com/actions/setup-dotnet where v6 is current, the kubernetes
api reference, and the aws provider 6 docs, all accessed 2026-09-26.
Verified by `make verify-csapi-docker` end to end, all six wire
tests green over the real image, the plain suite green at 379.
