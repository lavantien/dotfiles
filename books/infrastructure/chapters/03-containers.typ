#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= containers: processes, signals, pid 1

Strip the branding and a container is a process with walls: linux
namespaces give it its own view of the network stack, the process
tree, and the filesystem, and cgroups give it a resource ceiling. On
Windows the docker daemon runs these processes inside a small linux
vm, which is why `docker info` from git-bash talks to a named pipe and
why file mounts cross a vm boundary. The walls change what the process
can see. Nothing about it stops being a process, and that single fact
drives everything in this chapter.

== pid 1 and the signals that never came

Inside the container's pid namespace, the entrypoint process is pid 1.
Pid 1 is special in unix: the kernel will not deliver default-disposition
signals to it. If the shell is pid 1, because the dockerfile used
shell form `ENTRYPOINT /service`, then `docker stop` sends SIGTERM,
the shell catches it, does nothing, and the container dies only when
docker escalates to SIGKILL after the grace period. The process never
heard the polite knock.

The fix is two lines working together. Exec form in the dockerfile:

#listing("infrastructure/capstone/Dockerfile", first: 18, last: 18, caption: [exec form: the binary is pid 1, no shell in between])

and a signal handler in the binary:

#listing("infrastructure/capstone/internal/boot/boot.go", first: 64, last: 68, caption: [the two signals docker sends a stopping container])

#diagram([shell form versus exec form: one kernel rule, two opposite outcomes], length: 13pt, {
  cdraw.content((5.2, 10.4), [shell form entrypoint], size: 6.5pt)
  cdraw.rect((2.2, 8.7), (8.2, 9.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.2, 9.15), [shell, the pid 1], size: 6pt)
  cdraw.line((5.2, 8.7), (5.2, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.0, 8.05), [sigterm], size: 6pt)
  cdraw.rect((1.2, 6.4), (9.2, 7.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 6.95), [catches it, does nothing], size: 6pt)
  cdraw.line((5.2, 6.4), (5.2, 5.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.3, 5.85), [sigkill after 10s], size: 6pt)
  cdraw.rect((0.8, 4.2), (9.6, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 4.75), [dies, handler never ran], size: 6pt)

  cdraw.line((11.4, 4.0), (11.4, 10.6), stroke: luma(220))

  cdraw.content((17.4, 10.4), [exec form entrypoint], size: 6.5pt)
  cdraw.rect((14.4, 8.7), (20.4, 9.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 9.15), [/service, the pid 1], size: 6pt)
  cdraw.line((17.4, 8.7), (17.4, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((19.0, 8.05), [sigterm], size: 6pt)
  cdraw.rect((13.4, 6.4), (21.4, 7.5), fill: luma(235), radius: 0.02)
  cdraw.content((17.4, 6.95), [the binary receives it], size: 6pt)
  cdraw.line((17.4, 6.4), (17.4, 5.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((19.9, 5.85), [handler runs], size: 6pt)
  cdraw.rect((12.8, 4.2), (22.0, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((17.4, 4.75), [bounded close, clean exit], size: 6pt)

  cdraw.content((11.4, 3.3), [one kernel rule: pid 1 has no default signal dispositions], size: 6.5pt)
})

== shutdown in reverse startup order

Every service main in the capstone follows one shape: bring things up
in dependency order, park on the signal channel, then close in
reverse. The chat service, which owns both a database file and a
message connection, shows the full ladder:

#listing("infrastructure/capstone/cmd/chat/main.go", first: 14, last: 37, caption: [up, park, close in reverse: health server, responders, connection, file])

The order is the argument. The health endpoint goes first so compose
stops routing traffic to a container that is going away. The NATS
responders drop next, then `Drain` waits for in-flight requests to
finish before closing the connection, and the database closes last,
after nothing is left that could write to it. Reversing any pair
creates a window where a live request meets a closed resource.

#flow(
  [stop, in the order that leaves no stragglers],
  node((0, 0), [sigterm]),
  node((1.2, 0), [health off]),
  node((2.4, 0), [responders off]),
  node((3.6, 0), [drain]),
  node((4.8, 0), [db close]),
  edge((0, 0), (1.2, 0), "-|>"),
  edge((1.2, 0), (2.4, 0), "-|>"),
  edge((2.4, 0), (3.6, 0), "-|>"),
  edge((3.6, 0), (4.8, 0), "-|>"),
)

== what pid 1 owes, and what these processes owe instead

Classic pid 1 duty also includes reaping orphaned children, which is
why real init systems like tini exist. The capstone services never
fork child processes, so there is nothing to reap, and shipping an
init shim would be cargo cult. The honest checklist is: exec form so
the binary is pid 1, a handler for interrupt and terminate, and a
bounded close sequence. One subprocess does exist in this book, the
crash simulation in #xref-to("infrastructure", "sqlite-wal"), and it
is a test child, not a container entrypoint.

#diagram([what pid 1 owes here, and what these processes honestly decline], length: 13pt, {
  cdraw.rect((6.4, 7.6), (16.4, 9.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.4, 9.1), [the pid 1 rule], size: 6.5pt)
  cdraw.content((11.4, 8.0), [no default signal dispositions], size: 6pt)

  cdraw.line((9.4, 7.6), (5.2, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((13.4, 7.6), (17.5, 6.4), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((-0.4, 2.0), (10.8, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 5.9), [owed, and paid], size: 6.5pt)
  cdraw.content((5.2, 4.8), [exec form, binary is pid 1], size: 6pt)
  cdraw.content((5.2, 3.7), [interrupt and terminate handler], size: 6pt)
  cdraw.content((5.2, 2.6), [a bounded close sequence], size: 6pt)

  cdraw.rect((11.6, 2.0), (23.4, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.5, 5.9), [declined, honestly], size: 6.5pt)
  cdraw.content((17.5, 4.8), [reaping orphans: nothing to reap], size: 6pt)
  cdraw.content((17.5, 3.7), [no child processes exist], size: 6pt)
  cdraw.content((17.5, 2.6), [an init shim would be cargo cult], size: 6pt)
})

sources: docs.docker.com/reference/dockerfile for the shell versus
exec entrypoint behavior, accessed 2026-09-10, and the compose stop
grace period default of ten seconds from the compose reference,
accessed 2026-09-09. Verified by `make verify-infra-docker`, whose
teardown stops all six services through this path, run green
2026-09-20.
