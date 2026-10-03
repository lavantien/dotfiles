#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= os, subprocess, and signals

A python process is a process, and on windows it is a windows
process. This chapter is the stdlib's process layer from the inside
out: `subprocess.run` for the common case of "run this and give me
the output", `Popen` and pipes for the streaming cases, the `os`
surfaces for environment, arguments, directory, and exit codes, and
the signal module's small windows reality, where seven signal names
exist, an external kill is an unconditional `TerminateProcess`, and
graceful shutdown is something a process does to itself. Every child
in the samples is `sys.executable` with `-X utf8`, the same
interpreter this book pins in #xref-to("python", "toolchain"), so
the whole chapter is python watching python. The gate runs the four
samples under `Ch16/`, 47 `ok` lines in total.

== subprocess run and check

`run` is one function covering the common case, and the page states
its contract: "Run the command described by args. Wait for command to
complete, then return a CompletedProcess instance." Capture is a
flag: "If `capture_output` is true, stdout and stderr will be
captured", and the sample's first check pins what that means on this
machine, a `bytes` stdout holding `hello\r\n`, the carriage return
included, because the child wrote through a console-ish pipe and
nobody translated anything. Exit status is a field, and `check`
turns it into control flow, the page again: "If `check` is true, and
the process exits with a non-zero exit code, a `CalledProcessError`
exception will be raised":

#listing("python/samples/src/Ch16/run_check.py", first: 19, last: 46, caption: [capture, the cr lf bytes on windows, returncode, and check=True raising])

Timeouts are enforced, not advisory: "If the timeout expires, the
child process will be killed and waited for. The `TimeoutExpired`
exception will be re-raised after the child process has terminated."
The sample parks a child in `time.sleep(30)` with `timeout=2` and
asserts both halves, the exception with its `.timeout` intact and no
orphan left behind. Text versus bytes is the other axis: `text=True`
decodes with `locale.getpreferredencoding(False)` unless `encoding`
says otherwise, and the sample runs the same utf-8 child both ways,
one check reading `café` and one reading the raw `\xc3\xa9` bytes:

#listing("python/samples/src/Ch16/run_check.py", first: 67, last: 105, caption: [text plus encoding against raw bytes, and the timeout that kills the child])

`shell=True` deserves its own paragraph rather than a check. The
security page states the default posture: "Unlike some popen
functions, this library will not implicitly choose to call a system
shell. This means that all characters, including shell
metacharacters, can safely be passed to child processes. If the
shell is invoked explicitly, via `shell=True`, it is the
application's responsibility to ensure that all whitespace and
metacharacters are quoted appropriately." On windows the 3.12 change
closed the classic hunt: the shell search now uses "`%COMSPEC%` and
`%SystemRoot%\System32\cmd.exe`", so "dropping a malicious program
named cmd.exe into a current directory no longer works." The batch
file caveat runs the other way: a `.bat` or `.cmd` target "may be
launched by the operating system in a system shell regardless of the
arguments passed to this library." None of this book's children use
a shell, and the samples never pass `shell=True`.

#callout("pitfall", "list form, no shell, still quote nothing", [
  The rule this book follows: build the command as a list, pass it
  without a shell, and let the metacharacters be data. The moment
  string concatenation builds a command line, quoting becomes the
  program's job and the program is bad at it. The one windows
  exception in the docs is deliberate batch file launch with
  untrusted arguments, where passing `shell=True` actually lets
  python add the escaping. Everything else is a bug wearing a
  convenience.
])

#diagram([run as a pipeline: one call, four fates for the result], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.8, 5.2, [subprocess.run(args)], fill: luma(205))
  box(7.8, 6.8, 4.6, [child runs to completion])
  box(14.4, 7.6, 4.6, [CompletedProcess])
  box(14.4, 6.0, 4.6, [bytes or text fields], fill: luma(215))
  box(14.4, 4.2, 4.6, [CalledProcessError])
  box(14.4, 2.6, 4.6, [TimeoutExpired])
  box(7.8, 4.2, 4.6, [check=True and rc != 0])
  box(7.8, 2.6, 4.6, [timeout expires])
  cdraw.line((5.8, 7.3), (7.8, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 7.3), (14.4, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 7.1), (14.4, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.1, 6.8), (10.1, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 4.7), (14.4, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.1, 4.2), (10.1, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 3.1), (14.4, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.1, 1.2), [timeout kills and waits for the child: no orphans, checked], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.1, 0.3), [no shell anywhere in this chapter: the command list is data], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== popen and pipes

`run` is a wrapper, and the class under it is `Popen`. A `Popen`
object exists the moment the child is created and the parent is free
to keep working, which the sample checks with `poll()` returning
`None` while the child has not exited. The page names the method
that does the waiting: "`Interact with process`: Send data to stdin.
Read data from stdout and stderr, until end-of-file is reached. Wait
for process to terminate and set the `returncode` attribute", and
adds the two conditions people miss: "if you want to send data to
the process's stdin, you need to create the `Popen` object with
`stdin=PIPE`. Similarly, to get anything other than `None` in the
result tuple, you need to give `stdout=PIPE` and/or `stderr=PIPE`
too":

#listing("python/samples/src/Ch16/pipes.py", first: 20, last: 45, caption: [the popen lifecycle: create ahead, communicate once, returncode set])

The pipe deadlock is the reason `communicate` exists. An os pipe
holds a bounded amount, on the order of kilobytes, and a parent that
writes everything to a child's stdin before reading the child's
stdout deadlocks in both directions: the child blocks writing a full
pipe, the parent blocks writing its own. `communicate` threads the
transfer, draining while it writes. The sample proves the property
by volume, pushing 4 mb through a child that uppercases and returns
it, far past any pipe buffer:

#listing("python/samples/src/Ch16/pipes.py", first: 47, last: 78, caption: [4 mb through the pipes, and line-by-line reads while the child runs])

The timeout contract differs between the two layers, and the sample
pins the asymmetry. `run(timeout=...)` kills the child, quoted
above. `Popen.communicate(timeout=...)` does not: "The child process
is not killed if the timeout expires", so the caller cleans up, and
the sample catches the expiry, asserts the child is still alive,
then `kill()` and `wait()`. An explicit `env=` replaces the whole
environment rather than updating it, which the sample demonstrates
with a two-variable environment, one value of its own and
`SYSTEMROOT`, which a python child on this machine still needs:

#listing("python/samples/src/Ch16/pipes.py", first: 92, last: 112, caption: [the popen timeout leaves the child alive, cleanup is kill then wait, env replaces])

#diagram([two pipes and one bounded buffer: where the naive write blocks], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 7.0, 5.0, [parent], fill: luma(205))
  box(16.4, 7.0, 5.0, [child], fill: luma(205))
  cdraw.rect((7.0, 7.2), (15.0, 8.0), fill: luma(240), radius: 0.02)
  cdraw.content((11.0, 7.6), [stdin pipe, bounded], wrap: text.with(size: 6pt))
  cdraw.rect((7.0, 5.8), (15.0, 6.6), fill: luma(240), radius: 0.02)
  cdraw.content((11.0, 6.2), [stdout pipe, bounded], wrap: text.with(size: 6pt))
  cdraw.line((5.6, 7.6), (7.0, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 6.2), (16.4, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 4.9), [write-all-then-read: both ends block, the deadlock], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 3.9), [communicate: writes and drains in one threaded call, 4 mb checked], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 2.9), [readline loop: consume while the child produces, unbuffered child], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 1.9), [popen timeout raises and leaves the child: kill, then wait], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 0.9), [env= replaces the environment whole, keep SYSTEMROOT on windows], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== os interfaces

The `os` module's process surfaces are the ones a program uses
before and after any child exists. `os.environ` is a mapping of the
live environment: assignment and deletion really change what a later
child inherits, the sample sets a variable, spawns a child that
prints it, then deletes it, and snapshots with `dict(os.environ)`
because iteration over the live object while mutating it is exactly
as fragile as it sounds. `sys.argv` belongs to the same boundary,
and the sample hands a child three arguments and asserts the list
it sees:

#listing("python/samples/src/Ch16/os_faces.py", first: 21, last: 54, caption: [environ inherited by children, mutated in place, and argv handed through])

The working directory is process state, not a parameter. `chdir`
moves the whole process, every relative path and every later child
with an inherited `cwd`, and the sample does the round trip inside a
`try/finally` because a failed restore poisons the rest of any real
program. Exit codes close the loop. `os._exit` is the abrupt form,
it sets the code and skips cleanup, and the sample shows what that
costs on a pipe: a child that prints without flushing loses the line
entirely, while `flush=True` survives. A `SystemExit` carrying a
string prints the string to stderr and codes 1, which is why error
messages belong in exceptions and codes stay integers:

#listing("python/samples/src/Ch16/os_faces.py", first: 56, last: 99, caption: [chdir with a finally, os\_exit dropping unflushed output, string exits coding 1])

The boundary this book states rather than runs is the exec family.
The functions exist on this build, the sample asserts `execv` and
`spawnv` are present, but nothing here calls them: `os.exec*`
replaces the calling process, which on windows interacts with
console ownership and waiting in ways a gate run has no business
provoking, and the posix wait macros are absent, `WIFEXITED` does
not exist here, the sample checks that too. The general truth
stands as a map: #xref-to("c-os-cloud", "processes") built the same
parent verbs, wait, read the code, drop the reference, out of
`CreateProcessW`, and this chapter's `Popen.wait` is the same
discipline one abstraction lower.

#diagram([the os layer as a stack around one running python], length: 13pt, {
  let layer(y, t, fill: luma(235)) = {
    cdraw.rect((1.0, y), (14.6, y + 1.1), fill: fill, radius: 0.02)
    cdraw.content((7.8, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  layer(6.9, [sys.argv, exit codes, sys.\_getframe territory], fill: luma(215))
  layer(5.6, [os.environ: the live environment mapping])
  layer(4.3, [os.getcwd and chdir: process-wide state])
  layer(3.0, [subprocess and Popen: children and pipes])
  layer(1.7, [the windows kernel objects underneath], fill: luma(205))
  cdraw.content((17.6, 7.2), [argv is read-only, #linebreak() environ is live], wrap: text.with(size: 6pt))
  cdraw.content((17.6, 4.9), [chdir is global, #linebreak() restore in finally], wrap: text.with(size: 6pt))
  cdraw.content((17.6, 3.5), [kill and wait live here, #linebreak] + [ the windows semantics below], wrap: text.with(size: 6pt))
  cdraw.content((7.8, 0.5), [exec family present but a stated boundary: nothing in this book replaces itself], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== signals on windows

The signal module exists on windows and its surface is small. The
page says which: "On Windows, `signal()` can only be called with
`SIGABRT`, `SIGFPE`, `SIGILL`, `SIGINT`, `SIGSEGV`, `SIGTERM`, or
`SIGBREAK`. A `ValueError` will be raised in any other case", and
`SIGBREAK` itself is the windows-only extra, "Interrupt from
keyboard (CTRL + BREAK)". The sample counts the seven names, checks
the two console control event values, 0 and 1, and finds `NSIG` at
23. Defaults are real: "SIGINT is translated into a `KeyboardInterrupt`
exception if the parent process has not changed it", and
`getsignal(SIGINT) is signal.default_int_handler` asserts the
translator is installed:

#listing("python/samples/src/Ch16/signals_win.py", first: 22, last: 53, caption: [the seven names, the console event values, and the sigint default])

Then the windows truth about external kills, from the `os.kill`
page: "The `signal.CTRL_C_EVENT` and `signal.CTRL_BREAK_EVENT`
signals are special signals which can only be sent to console
processes which share a common console window, e.g., some
subprocesses. Any other value for `sig` will cause the process to be
unconditionally killed by the `TerminateProcess` API, and the exit
code will be set to `sig`." Every clause of that is a check. The
sample arms a child with a `SIGTERM` handler, confirms it is
running, kills it with `os.kill(pid, SIGTERM)`, and observes: the
return code is 15, `sig` itself, and the handler never ran. There is
no negotiation, because there is no signal, only termination:

#listing("python/samples/src/Ch16/signals_win.py", first: 86, last: 119, caption: [the armed child, the kill, exit code 15, and a handler that never ran])

What does work is in-process delivery. `signal.raise_signal` runs
the installed handler synchronously in the main thread, the sample
checks that directly, and the shutdown pattern the book teaches is
built on it: install a handler that finishes work and exits with an
intentional code, raise the signal from the process's own control
flow, and the exit is orderly. One probed fact sharpens the
boundary: in a child with piped stdio, which has no console, a
`raise_signal` from a worker thread did not wake a sleeping main
thread in this build, so the sample raises from the main thread and
stays deterministic:

#listing("python/samples/src/Ch16/signals_win.py", first: 121, last: 152, caption: [the graceful pattern: handler in the main thread, intentional exit code])

#callout("note", "what ctrl+c would do to this gate", [
  A real ctrl+c reaches every process attached to the console,
  the gate runner included, which is why no sample in this chapter
  sends `CTRL_C_EVENT`. The keyboard path is still the everyday one:
  sigint becomes `KeyboardInterrupt`, the exception chapters'
  `finally` blocks run, and the process exits non-zero. The
  difference from posix is the delivery vehicle: there, a kill
  signal can carry intent from outside, here the intent has to
  already be inside the process as a handler.
])

#diagram([signal delivery on windows as a decision: who sent it decides what happens], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 7.4, 6.6, [something wants this process to stop], fill: luma(215))
  box(1.0, 5.6, 5.8, [ctrl+c on the console])
  box(1.0, 3.8, 5.8, [os.kill(pid, sig), sig > 1])
  box(1.0, 2.0, 5.8, [raise\_signal in-process])
  cdraw.line((3.9, 7.4), (3.9, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.9, 5.6), (3.9, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.9, 3.8), (3.9, 3.0), stroke: luma(100), mark: (end: ">"))
  box(8.4, 5.6, 6.2, [sigint handler: KeyboardInterrupt])
  box(8.4, 3.8, 6.2, [TerminateProcess, rc = sig])
  box(8.4, 2.0, 6.2, [the handler runs, main thread])
  cdraw.line((6.8, 6.1), (8.4, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.8, 4.3), (8.4, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.8, 2.5), (8.4, 2.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.8, 3.4), (18.4, 4.6), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((18.4, 4.0), [no handler ever runs], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((3.9, 0.9), [graceful shutdown is in-process by construction: raise, handle, exit with intent], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((12.0, 0.2), [checked: armed child killed with sigterm, rc 15, handler silent], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "what a green run of this chapter proves", [
  The four samples print 47 `ok` lines: run's capture, exit codes,
  check, timeout, and encoding behavior, the popen lifecycle with a
  4 mb threaded pipe transfer and the kill-then-wait cleanup, the
  os surfaces with the unflushed-output demonstration, and the
  signal truth table: seven names, the sigint default, the
  TerminateProcess kill with its exit code, and the in-process
  graceful pattern. All children were cpython 3.14.7 run with
  `-X utf8` on this machine.
])

sources: docs.python.org/3.14 library/subprocess (run, popen,
communicate, frequently used arguments, security considerations,
the 3.12 windows shell search change), library/os (os.kill windows
paragraph), library/signal (windows signal list, SIGBREAK, default
handlers), all accessed 2026-09-12. Sample behavior
verified by `make verify-py`, 47 checks in chapter 16.
