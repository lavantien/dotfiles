#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= ship it

The module ends as a directory of tests unless it also ships. This chapter turns the service into an artifact and a lane: a multi-stage image that runs anywhere, one compose command that brings it up healthy, a make gate that replays the contract over that stack, a CI workflow that runs the same legs on every push, and the two envelopes real platforms ask for, a helm chart and a terraform slice. Everything leans on machinery the earlier chapters already built: the health and ready routes chapter 18 owns, the strong ETags chapter 20 computes, the drain state chapter 28 wires, the metrics chapter 27 exposes. One rule disciplines the whole chapter: the compose lane is the only thing that executes, and the chart, the terraform, and the workflow ship as taught, documentation-verified copies.

== the image

Two stages, one boundary. The builder stage is the stock golang image, which exists only to run the compiler, and the runtime stage is scratch, which exists only to run the binary. The copy across the boundary is a single file, and every property of the service module conspired to make that legal: the store engine is pure go, so CGO_ENABLED=0 builds a static binary with no c runtime to carry, the schema versions live in the store's own snapshot header, so the history ships inside the store files, and the configuration is environment variables, so no file needs mounting to start:

#listing("go/api/Dockerfile", first: 1, last: 21, caption: [the whole image: builder, static binary, scratch runtime, non-root])

Four decisions in that file earn a second look. The go.mod copy precedes the source copy so the dependency download layer caches independently of code edits, the common multi-stage economy. The /data directory is created in the builder and copied with an owner, because a named volume inherits the image content's ownership on first mount, and a volume mounting onto a root-owned directory would deny the container user its database. The user is numeric, 65532, since scratch carries no /etc/passwd to resolve a name. And the build keeps its symbols: -trimpath strips local paths from the binary but -s -w, the size-shaving pair, is deliberately absent, because chapter 27 teaches profiling the live server and a stripped binary answers those profiles with addresses instead of function names.

The healthcheck has the same shape problem in reverse: scratch has no shell, no wget, no curl, so nothing exists in the image to probe with. The answer is the one executable that does exist, the service itself. The binary accepts a -health argument, probes /healthz on its configured address over the loopback interface, and exits 0 or 1, so the container orchestrator's probe command is the same binary, one flag apart from the server.

The build context is the whole module, tests and frozen vectors included, because the compiler only reaches what the package graph names and the rest rides the context without landing in the image. A .dockerignore would trim that upload and speed the build marginally, at the cost of one more file whose exclusions can silently drift from the module's shape, so the file here is none and the trade is stated instead of paid.

#diagram([two stages, one file crosses: the builder dies with the build, scratch runs the binary], length: 13pt, {
  cdraw.rect((1.0, 6.2), (21.9, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.2), [golang:1.27 builder], size: 6.5pt)
  cdraw.content((11.5, 7.3), [go mod download, then CGO_ENABLED=0 go build], size: 6pt)
  cdraw.content((11.5, 6.5), [the compiler's whole world, discarded at the end], size: 6pt)
  cdraw.line((11.5, 5.9), (11.5, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 5.1), [one static file crosses, /api], size: 6pt)
  cdraw.rect((3.4, 1.2), (19.6, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 3.6), [scratch runtime], size: 6.5pt)
  cdraw.content((11.5, 2.7), [the binary, empty /data, user 65532], size: 6pt)
  cdraw.content((11.5, 1.8), [no shell, no libc, no package manager], size: 6pt)
})

Distroless is the other honest choice: a minimal base with ca certificates, tzdata, and a non-root user baked in, at a few megabytes more. This service needs none of that, so scratch wins, but the moment the binary dials tls or formats local times, distroless is the smaller of the correct options rather than the larger of the fast ones.

== compose one command

The compose file is one service and its volume, and the contract it enforces is the return value of a single command. `docker compose up -d --build --wait` builds the image, creates the container, starts it, and then blocks until the healthcheck passes, so a green up means the image compiled, the migrations ran against a fresh volume, and the listener answers probes. `down -v` removes the volume in the same breath, so every lane run starts from migration zero, which is what keeps the suite behind it deterministic:

#listing("go/api/compose.yml", first: 8, last: 30, caption: [the whole system: probe timing anchors, one service, two listeners, the volume])

The environment block carries exactly what construction demands. The jwt secret must be present or the authn service refuses to start, loudly, which is the right failure mode for a container: a missing secret is a crash the orchestrator restarts and an operator reads, never a running service signing tokens with an empty key. The value in the file is a development constant, and both platform envelopes later in this chapter exist partly to replace it: the chart reads the secret from a kubernetes secret reference, the terraform slice from an ssm parameter, and neither carries the value in a file a reviewer diffs. The second listener is the same discipline for the observability surface, the metrics and pprof routes bind an internal address the guard never wraps, and the port mapping publishes it to the host so the lane can assert against it. The migrations rule from chapter 23 holds unchanged, `docker compose up -d` is the only command that touches the schema, because the version history arrives inside the store's snapshot and applies itself at startup under the migration registry.

#diagram([what a green up proves, in order], length: 13pt, {
  let step(x, w, top, sub) = {
    cdraw.rect((x, 4.6), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), sub, size: 6pt)
  }
  step(0.8, 4.4, [build], [image compiles])
  step(6.2, 4.4, [create + start], [env and volume mount])
  step(11.6, 4.4, [migrations], [version records apply])
  step(17.0, 4.4, [probe passes], [--wait returns 0])
  cdraw.line((5.3, 5.8), (6.1, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 5.8), (11.5, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.1, 5.8), (16.9, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.5), [any step failing leaves up non-zero], size: 6pt)
  cdraw.content((11.5, 2.6), [down -v wipes the volume, next run starts at zero], size: 6pt)
  cdraw.content((11.5, 1.7), [no manual schema step anywhere, ever], size: 6pt)
})

== the docker lane as a gate

The lane is one make target, and its shape mirrors the infrastructure book's two-gate rule, #xref-to("infrastructure", "compose") owns the compose depth and #xref-to("infrastructure", "containers") the pid 1 and signal story. The plain module gate never needs a docker daemon, and the docker lane never runs silently: a missing daemon is a loud red with the instruction to start it, never a skip:

#snippet(
  "verify-api-docker:\n"
  + "\t@docker info >/dev/null 2>&1 || { echo \"docker daemon not reachable.\" >&2; exit 1; }\n"
  + "\t@cd books/go/api && trap 'docker compose down -v' EXIT && \\\n"
  + "\t\tdocker compose up -d --build --wait && \\\n"
  + "\t\tgo test -tags docker ./integration/...",
  lang: "makefile",
)

The suite behind the tag replays the contract's golden scenarios over the real listener. The part's in-process suites replay fourteen of the sixteen vectors by file, where the clock and id source are injected; the remaining pair, the register replay and the reports pair, is held here over the wire, and this suite asserts the layer under the frozen bytes: with a real clock, real uuids, and real wiring, the statuses, the header relations, and the byte-identical guarantees must still hold. The ETag rule is the sharpest example, a strong ETag is the sha256 of the exact response body, so the suite recomputes the hash over the wire bytes and compares:

#listing("go/api/integration/api_test.go", first: 115, last: 126, caption: [the etag check recomputed over live bytes, not frozen ones])

Six tests cover the scenarios the contract names. Health and routing pins both probes and the two routing envelopes, including the ruling that a 405 carries the not_found code plus an Allow header. Register and login walks vectors 01, 02, 04, and 05: the 201 with Location and ETag, the idempotent replay returning the stored snapshot byte for byte, the login pair, and the two 401 shapes that must not differ enough to enumerate accounts. The patch duel releases two concurrent merge patches on one If-Match and demands exactly one 200 and one 412:

#listing("go/api/integration/api_test.go", first: 295, last: 305, caption: [the duel over the wire: barrier channel, two patchers, one winner])

The remaining three are the rate limit, five wrong passwords drain the bucket to zero and the sixth reads 429 with a Retry-After in seconds, the reports pair, a 202 that reads into a completed report and replays it as the sanctioned 200 with identical bytes while the same key under a different body reads 422, and the metrics exposition, read off the internal listener the wired service binds it to, both series present with the route label the pattern table produces. That last one is the wiring lesson of the lane: the deny-by-default guard wraps the public mux, so an exposition route registered there would answer 403 to everyone, and metrics belongs on the internal listener beside pprof, which is exactly where the observability chapter said production puts it. The build tag keeps all of it out of `go test ./...`; the tagged vet that keeps the suite from rotting behind its tag, `go vet -tags docker ./integration/...`, runs in the ci workflow copy under `deploy/ci/`, the lane that always has the daemon.

#diagram([the gate: one lane, one trap, no skips], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.5), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.6), sub, size: 6pt)
  }
  box(0.8, 3.8, [preflight], [docker info or loud red])
  box(5.2, 4.2, [compose up], [build, wait for health])
  box(9.9, 4.2, [tagged tests], [six replays on 8080])
  box(14.6, 3.8, [trap fires], [down -v on any exit])
  cdraw.line((4.7, 6.0), (5.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.5, 6.0), (9.8, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.2, 6.0), (14.5, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.6), [plain go test ./... never sees these files], size: 6pt)
  cdraw.content((11.5, 2.7), [vet with the tag keeps them compiling], size: 6pt)
  cdraw.content((11.5, 1.8), [the only executing lane in this chapter], size: 6pt)
})

== ci on GitHub Actions

The workflow is the same gate wearing a badge. It runs the module legs exactly as the repository runs them locally, format check, vet, tests with the race detector, the tagged vet, so a green check means the same thing a green make means, and the compose lane follows on a runner where the docker daemon is already listening. The path filter keeps the workflow out of every commit that touches nothing under the service module:

#listing("go/api/deploy/ci/ci.yml", first: 13, last: 28, caption: [the module job: the local legs, verbatim])

#listing("go/api/deploy/ci/ci.yml", first: 30, last: 43, caption: [the lane job: compose up, tagged tests, the trap])

The image job exists to prove the artifact builds in a clean environment, one checkout and one docker build, with the commit sha passed as the VERSION build argument so the binary reports its build on /healthz, the versioned health route chapter 18 pinned. The job does not push anywhere: a registry, credentials, and a release policy are a repository decision, not a service one, and the workflow stops at proving the build.

#diagram([push to ci to image: three jobs, one dependency edge], length: 13pt, {
  cdraw.rect((0.8, 5.2), (5.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.1, 6.9), [push or pr], size: 6.5pt)
  cdraw.content((3.1, 6.0), [paths under the module], size: 6pt)
  cdraw.content((3.1, 5.5), [else: nothing runs], size: 6pt)
  cdraw.rect((8.6, 5.2), (14.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 6.9), [module job], size: 6.5pt)
  cdraw.content((11.5, 6.0), [fmt, vet, race tests, tagged vet], size: 6pt)
  cdraw.line((5.6, 6.4), (8.4, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.8, 6.5), (22.2, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.0, 7.7), [lane job], size: 6.5pt)
  cdraw.content((19.0, 6.9), [compose + six tests], size: 6pt)
  cdraw.line((14.6, 7.4), (15.6, 7.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.8, 3.4), (22.2, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.0, 4.7), [image job], size: 6.5pt)
  cdraw.content((19.0, 3.9), [docker build, sha as version], size: 6pt)
  cdraw.line((14.6, 4.4), (15.6, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.0, 3.9), [both depend on module, not on each other], size: 6pt)
})

#callout("note", "why a taught copy", [
  The workflow lives at goapi/deploy/ci/ci.yml, not .github/workflows/. This repository keeps no .github directory, because a workflow there executes on push to the real remote, and corpus ci is not ratified. The file is byte for byte what a service repository would carry, taught line by line, and the make lane is what actually runs.
])

== helm the service envelope

The chart is the service wearing kubernetes. Chart.yaml declares the name and the version pair, values.yaml is the entire configuration surface a reviewer diffs, and the templates render it into the three objects the platform needs, a deployment, a service, and the autoscaler, plus an ingress behind a flag. The deployment is where the service's own contracts surface: the probes split exactly along the line chapter 28 drew, liveness on /healthz answers is this process alive and gets a restart, readiness on /readyz answers is this process accepting traffic and gets a pull from the endpoints list, which is how a draining pod cooperates with a rolling deploy instead of dropping requests into it:

#listing("go/api/deploy/helm/goapi/Chart.yaml", first: 1, last: 6, caption: [the chart header: name, type, the two versions])

#listing("go/api/deploy/helm/goapi/values.yaml", first: 5, last: 23, caption: [the reviewable surface: image, replicas, resources, probes])

#listing("go/api/deploy/helm/goapi/templates/deployment.yaml", first: 26, last: 48, caption: [the container: secret from the release, both probes, the resources block])

Three details match the image on purpose. The securityContext repeats user 65532, so the platform and the image agree on who runs the process even if the image changes. The jwt secret arrives through a secretKeyRef, never a values entry, keeping the reviewable file free of credentials. And the resources block is templated from values because the scheduler and the autoscaler both read it, cpu requests drive the horizontal pod autoscaler's utilization target, and a service without requests is a service the cluster cannot schedule honestly. The hpa template scales on that target between the min and max in values, the plain resource-metric answer, custom metrics being a platform decision rather than a service one.

#diagram([the chart's layers: values flow down, objects render out], length: 13pt, {
  cdraw.rect((3.6, 6.6), (19.4, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.1), [values.yaml], size: 6.5pt)
  cdraw.content((11.5, 7.2), [image, replicas, resources, probes, hpa], size: 6pt)
  cdraw.rect((3.6, 4.0), (19.4, 6.0), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 5.4), [templates], size: 6.5pt)
  cdraw.content((11.5, 4.5), [deployment, service, hpa, ingress], size: 6pt)
  cdraw.line((11.5, 6.5), (11.5, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.9, 2.6), [Deployment], size: 6pt)
  cdraw.content((9.4, 2.6), [Service], size: 6pt)
  cdraw.content((13.6, 2.6), [HPA], size: 6pt)
  cdraw.content((18.2, 2.6), [Ingress], size: 6pt)
  cdraw.line((11.5, 3.7), (11.5, 3.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 1.7), [helm install reads values, renders, applies], size: 6pt)
})

== terraform for this service

Terraform the language, module structure, and the provider catalog belong to the cloud book: #xref-to("c-os-cloud", "terraform") for the language and core workflow, #xref-to("c-os-cloud", "modules") for how this slice becomes a module others call, #xref-to("c-os-cloud", "aws") for the resource catalog and account layout. This file is the service's slice of that practice, one fargate service behind one load balancer, one alarm on the tail, and it reads as a decision record for the service more than as a lesson in the tool:

#listing("go/api/deploy/terraform/main.tf", first: 6, last: 19, caption: [the pin: terraform 1.17 plus the aws 6 provider])

The task definition runs the same image compose runs, with awsvpc networking and the secret pulled from ssm at container start. The secret's path is in the plan, its value never is beyond the one write, and the binary that receives it fails closed on an empty value, so the weakest link is the parameter store's own permissions rather than any copy of the value:

#listing("go/api/deploy/terraform/ecs.tf", first: 88, last: 101, caption: [the container definition: image, env, the secret by reference])

The load balancer carries two service decisions. The target group probes /healthz, the same liveness route from the other two envelopes, with a deregistration delay of 30 seconds, which is the drain window chapter 28's shutdown owns the inside of: a task leaving the pool gets half a minute to finish its in-flight requests, and the graceful drain inside the process is what makes that window sufficient rather than merely allocated. And desired_count defaults to 1, stated in the variable itself, because the store is one file set, snapshot plus log, on the task's volume and two tasks would be two databases wearing one name. That is the honest constraint of this service, and the fix is a store that moves off the local volume, not a count raised past the truth.

The alarm reads the tail off the platform instead of the service publishing a second copy: the load balancer already measures target response time, and cloudwatch computes the p99 extended statistic for it, so the pager watches the same number the load chapter defends, three one-minute periods above threshold, and pages the sns topic when the tail is a fact and not a spike.

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
  cdraw.content((11.5, 3.6), [secret written once to ssm, read at task start], size: 6pt)
  cdraw.content((11.5, 2.7), [desired count 1 while the store is volume-local], size: 6pt)
  cdraw.content((11.5, 1.8), [nothing initialized, planned, or applied here], size: 6pt)
})

== the shipped checklist

The ship lane ends where it started, with the property each chapter contributed. Every row is a behavior the lane or the module gate observes, not an aspiration, and every row names where it is proven, which is the difference between a readiness checklist and a slide. The suite chapter that follows hardens the whole set:

#diagram([the readiness table: twelve chapters, twelve properties, all proven], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [18 kernel: one envelope], [on every failure, over the wire])
  cell(17.1, 8.3, 10.0, [19 middleware: recover], [a panic never escapes])
  cell(5.9, 6.9, 10.0, [20 users: validation], [plus keyset pagination])
  cell(17.1, 6.9, 10.0, [21 authn: argon2id], [sessions and rotating jwt])
  cell(5.9, 5.5, 10.0, [22 authz: rbac], [owner checks, audited routes])
  cell(17.1, 5.5, 10.0, [23 store: migrations], [transactions, wal isolation])
  cell(5.9, 4.1, 10.0, [24 conc: the duel], [etag plus idempotent replay])
  cell(17.1, 4.1, 10.0, [25 cache: lru with ttl], [and the stampede guard])
  cell(5.9, 2.7, 10.0, [26 limit: token bucket], [429 with Retry-After])
  cell(17.1, 2.7, 10.0, [27 obs: slog and p99], [metrics, traces, profiles])
  cell(5.9, 1.3, 10.0, [28 load: drain], [admission and no leaks])
  cell(17.1, 1.3, 10.0, [29 ship: the lane], [proving all of the above])
})

The chapter also declares what it deliberately does not teach again. Docker's storage model, the container runtime, and networking are the infrastructure book's chapters, the compose internals and the one-click philosophy are #xref-to("infrastructure", "compose"), and the migration discipline the version records ride is #xref-to("infrastructure", "migrations"). The cloud side defers the same way, the terraform workflow and module design live in the cloud book's own chapters, and the aws resource catalog with it. What this chapter owns is the narrow band between a green module and a running service: the image, the command, the gate, and the two envelopes, each one small enough to read in a sitting and boring enough to trust.

sources: docker docs on multi-stage builds and `docker compose up --wait` semantics, at docs.docker.com; the GitHub Actions workflow syntax plus actions/checkout v6 and actions/setup-go v6, at docs.github.com/actions; the kubernetes api reference for probes, resources, and the autoscaling/v2 target types, at kubernetes.io/docs/reference/kubernetes-api; the aws provider 6 documentation for aws_ecs_service, aws_lb_target_group, and aws_cloudwatch_metric_alarm extended statistics, at registry.terraform.io; the terraform 1.17 language documentation, at developer.hashicorp.com/terraform. Accessed 2026-09-25. Verified by `go vet -tags docker` and a tagged compile of the integration suite, the lane itself run under `make verify-api-docker`; the helm chart and terraform are documentation-verified, the cloud contract inherited from the c-os-cloud book.
