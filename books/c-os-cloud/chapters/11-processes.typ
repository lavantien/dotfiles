#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= processes and program lifecycle

A C program never runs alone. The moment its `main` begins, the operating
system has already built a container around it, and the moment `main`
returns, a documented sequence of events tears that container down. This
chapter pins both halves on windows: what a process is, how one process
creates another with `CreateProcessW`, how the parent observes the child
through handles and exit codes, and how the C standard's termination
machinery, `atexit`, `exit`, `quick_exit`, behaves inside one process.
The posix model, `fork` plus `exec`, sits beside it as the comparison the
rest of the literature assumes. Every behavioral claim below is a CHECK
in the two samples, 33 in total, or a sentence quoted from a canonical
page fetched 2026-09-12.

== the process abstraction

The CreateProcessW page states the whole creation contract in one line:
it "Creates a new process and its primary thread." Three things come
into existence together. A kernel object, owned by the system, holding
the process identifier and, later, the exit code. A private virtual
address space. And a primary thread, itself a kernel object, whose
suspend count this chapter will manipulate directly. The program never
touches these objects by pointer: it holds handles, table entries in
its own process that refer to the objects, and the discipline of the
entire win32 process model is which handles you hold and when you close
them.

The gate's own exe is itself somebody's child, and the process can read
the paper trail of its own creation. `GetStartupInfoW` "Retrieves the
contents of the STARTUPINFO structure that was specified when the
calling process was created", and the remarks name the author: "The
STARTUPINFO structure was specified by the process that created the
calling process."

#listing("c-os-cloud/samples/src/Ch11/lifecycle.c", first: 62, last: 70, caption: [getstartupinfow proves this process was itself created])

The check compares the structure's size field against `sizeof`:
`si.cb` is 104 on x64, probed on this box, and it equals the size the
sample declared, which means the crt and the kernel agree on the layout
the creator filled in. The same structure is the `lpStartupInfo`
parameter of `CreateProcessW` itself, so the parent's input and the
child's self-knowledge are one type.

Two of the handles in play are not table entries at all.
`GetCurrentProcess` returns a pseudo handle, and its page defines the
term: "A pseudo handle is a special constant, currently (HANDLE)-1,
that is interpreted as the current process handle." The page adds two
facts the sample leans on: "Pseudo handles are not inherited by child
processes", and closing a pseudo handle "has no effect". The thread
twin behaves the same way; its page states the mechanism without the
constant, and on this box the value arrives as (HANDLE)-2, probed. The
handle table itself is countable from inside through the pseudo
handle: `GetProcessHandleCount` "Retrieves the number of open handles
that belong to the specified process." Its page documents the count
parameter as a pointer to `DWORD` while the SDK header declares
`PULONG`, the same unsigned 32 bits either way, a small drift between
page and header worth knowing when the compiler is pedantic.

#listing("c-os-cloud/samples/src/Ch11/lifecycle.c", first: 72, last: 93, caption: [pseudo handles, the duplicate, and the exact handle table audit])

The audit walks the table one entry at a time. `DuplicateHandle`
converts the pseudo handle into a real one, its page states it: "If
hSourceHandle is a pseudo handle returned by GetCurrentProcess or
GetCurrentThread, DuplicateHandle converts it to a real handle to a
process or thread, respectively." The count rises by exactly one, the
close succeeds, the count falls back to the baseline by exactly the
one entry. A real handle, unlike the pseudo constant, is a table entry,
and `CloseHandle` "invalidates the specified object handle, decrements
the object's handle count, and performs object retention checks. After
the last handle to an object is closed, the object is removed from the
system." That last sentence is the lifetime rule the whole chapter
turns on.

#listing("c-os-cloud/samples/src/Ch11/lifecycle.c", first: 95, last: 99, caption: [closing the same handle twice fails with error invalid handle])

The double close fails with `ERROR_INVALID_HANDLE`, and the page
explains why this must stay a bug and not a habit: under a debugger the
same call "will throw an exception if it receives either a handle value
that is not valid or a pseudo-handle value", and the freed entry's
value can be reused by an unrelated object at any time.

#diagram([one process as five layers, what each layer holds, and who owns it], length: 13pt, {
  let layer(y, t, fill: luma(235)) = {
    cdraw.rect((1.0, y), (15.6, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((8.3, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  layer(6.8, [your program: crt startup, main, exit handlers], fill: luma(205))
  layer(5.5, [virtual address space: code, data, heap, stack])
  layer(4.2, [kernel objects: process, primary thread, exit code])
  layer(2.9, [handle table: references to kernel objects])
  layer(1.6, [the kernel: creates, signals, retires objects], fill: luma(205))
  cdraw.content((18.4, 7.1), [handles are references, #linebreak() never the objects], wrap: text.with(size: 6pt))
  cdraw.content((18.4, 4.9), [pseudo handles are constants, #linebreak() they never enter the table], wrap: text.with(size: 6pt))
  cdraw.content((18.4, 2.4), [the object lives until the #linebreak() last handle to it closes], wrap: text.with(size: 6pt))
  cdraw.content((8.3, 0.6), [one CreateProcessW call builds all five layers at once], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The other half of the chapter title is the program lifecycle inside one
process, and that is the C standard's territory, not windows'. The
final draft n3220 makes `main` special at 5.1.2.3.4: "a return from
the initial call to the main function is equivalent to calling the exit
function with the value returned by the main function as its argument;
reaching the } that terminates the main function returns a value of 0."
What `exit` then does is enumerated at 7.24.4.4: "First, all functions
registered by the atexit function are called, in the reverse order of
their registration", then "all open streams with unwritten buffered
data are flushed, all open streams are closed, and all files created by
the tmpfile function are removed." The order matters to the gate
itself: a handler's output reaches the captured stdout only because the
flush happens after the handlers, not before them.

#listing("c-os-cloud/samples/src/Ch11/lifecycle.c", first: 24, last: 54, caption: [the exit time recorder, the verifier that runs last, and the quick exit decoy])

#listing("c-os-cloud/samples/src/Ch11/lifecycle.c", first: 101, last: 110, caption: [exit vocabulary and the four registrations])

The design problem in the listing is that a check which runs after
`main` returned cannot fail the run by returning nonzero: the exit code
is already settled. The verifier therefore flushes and calls
`_Exit(1)` on the failure path, which 7.24.4.5 permits, no handlers,
immediate termination, while calling `exit` from inside `exit` is
undefined by 7.24.4.4 outright. The decoy `quick_mark` is registered
with `at_quick_exit`, and the verifier's assertion is the exact string
`abc`: reverse order for the three markers, and no `Q`, because
`exit` "causes normal program termination" while "No functions
registered by the at\_quick\_exit function are called." The quick path
itself is the asymmetric sibling: `quick_exit` at 7.24.4.7 runs its own
registrations in reverse order and then "control is returned to the
host environment by means of the function call \_Exit(status)", and
whether
streams get flushed on that path is implementation-defined. One
process gets one termination, so the sample executes the `exit` side
and cites the rest.

== CreateProcess end to end

The call takes ten parameters, and the sample names every one of them.
`STARTUPINFOW` travels in, with `cb` set to its own size so the kernel
knows which revision it received. `PROCESS_INFORMATION` travels out,
24 bytes on x64, probed: two handles and two identifiers, and the page
is explicit about ownership: "Handles in PROCESS\_INFORMATION must be
closed with CloseHandle when they are no longer needed."

#callout("pitfall", "the command line must live in writable memory", [
  The CreateProcessW page states it: the Unicode version "can modify
  the contents of this string. Therefore, this parameter cannot be a
  pointer to read-only memory (such as a const variable or a literal
  string). If this parameter is a constant string, the function may
  cause an access violation." A wide string literal lands in read-only
  data, so both samples build the command line with `swprintf` into a
  stack array. The same page's security remarks tell the second half:
  when `lpApplicationName` is NULL and the path contains spaces, quote
  it, or the parser may resolve a different executable than you meant.
])

#listing("c-os-cloud/samples/src/Ch11/spawn.c", first: 61, last: 71, caption: [the wide self path and the absolute cmd.exe path])

CreateProcessW speaks UTF-16, so the self-spawn path comes from
converting `argv[0]` with `MultiByteToWideChar`; on the gate's ASCII
paths the conversion returns exactly the narrow length plus the
terminator, probed. The cmd.exe path avoids the documented six-step
executable search altogether by expanding `%SystemRoot%` to an absolute
path, quoted because the system directory is allowed to move under
paths with spaces.

#listing("c-os-cloud/samples/src/Ch11/spawn.c", first: 73, last: 97, caption: [first spawn end to end with the handle table audited])

Line by line: the structures are zeroed, `cb` is set, the parent's
handle count is taken, and `CreateProcessW` runs with
`bInheritHandles` FALSE, so the child starts with a clean table, the
pseudo handle rule above working in the parent's favor. The function
returns true before the child has done anything: "the function returns
before the process has finished initialization." The pid check ties to
the page's remark that "The process is assigned a process identifier.
The identifier is valid until the process terminates." The wait blocks
on the process handle until it is signaled, `WaitForSingleObject`
returning `WAIT_OBJECT_0`, and `GetExitCodeProcess` reads back the 7
that `cmd.exe /c exit 7` wrote. Then both handles close.

The handle audit around the spawn is deliberately asymmetric, because
the probe found an asymmetry. The create adds at least the process and
thread handles, asserted as a lower bound, while the close side is
exact, the table shrinks by exactly 2. Probed 2026-09-12: the first
spawn in a process also opens console plumbing in the parent, 5
handles that stay open for the process lifetime, so the create delta
was 7, not 2, and 5 remained after both closes. On the fifth spawn of
the same process the delta was exactly 2 back to baseline. The robust
pair, at least plus 2 on create and exactly minus 2 on close, held in
both legs, plain and address-sanitizer build.

#diagram([a child from creation to object retirement, the calls that drive each step], length: 13pt, {
  let box(x, y, t) = {
    cdraw.rect((x, y), (x + 6.5, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.25, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.2, [CreateProcessW call])
  box(7.9, 6.2, [objects exist, pid assigned])
  box(15.2, 6.2, [child runs: crt, main])
  box(22.5, 6.2, [main returns, code set])
  box(22.5, 2.6, [object signaled])
  box(15.2, 2.6, [wait returns, code read])
  box(7.9, 2.6, [CloseHandle twice])
  box(0.6, 2.6, [last handle: freed])
  cdraw.line((7.1, 6.7), (7.9, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.4, 6.7), (15.2, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((21.7, 6.7), (22.5, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((25.75, 6.2), (25.75, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((22.5, 3.1), (21.7, 3.1), stroke: luma(100), mark: (end: "<"))
  cdraw.line((15.2, 3.1), (14.4, 3.1), stroke: luma(100), mark: (end: "<"))
  cdraw.line((7.9, 3.1), (7.1, 3.1), stroke: luma(100), mark: (end: "<"))
  cdraw.content((27.1, 4.9), [child exits], wrap: text.with(size: 6pt))
  cdraw.content((15.0, 4.5), [the parent races ahead: create returns before the child initializes], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((15.0, 1.2), [the object outlives the child until the last handle to it closes], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== fork/exec versus CreateProcess

The posix model this section compares against is two system calls.
POSIX `fork` "shall create a new process", and "The new process (child
process) shall be an exact copy of the calling process (parent
process) except as detailed below." One call, two returns: "Upon
successful completion, fork() shall return 0 to the child process and
shall return the process ID of the child process to the parent
process." The copy is a fiction the kernel maintains cheaply; the
linux man page states the mechanism: "Under Linux, fork() is
implemented using copy-on-write pages, so the only penalty that it
incurs is the time and memory required to duplicate the parent's page
tables and to create a unique task structure for the child." Then
`execve` replaces the image: it causes "the program that is currently
being run by the calling process to be replaced with a new program", with
"newly initialized stack, heap, and (initialized and uninitialized)
data segments", while "many attributes of the calling process remain
unchanged (in particular, its PID)", file descriptors stay open unless
marked close-on-exec, and "On success, execve() does not return."

Windows has neither call, and on this box that is a probed fact, not a
porting complaint: compiled through the same flags as the gate, a bare
`fork()` call dies with `use of undeclared identifier 'fork'`, no
header in the msvc crt or the windows sdk declares it, and no import
library resolves it. The one-step model does the same work
differently. `CreateProcessW` builds the new process and its primary
thread directly from an executable file, no parental copy, no image
replacement, a fresh private address space, and hands the parent two
handles instead of one doubled control flow. What fork-plus-exec buys
that plain creation seems to lose, the window between the child
existing and the child running, exists here as a flag: "The primary
thread of the new process is created in a suspended state, and does
not run until the ResumeThread function is called."

#listing("c-os-cloud/samples/src/Ch11/spawn.c", first: 109, last: 129, caption: [the suspended self spawn, create frozen, resume, reap])

The sample spawns a copy of itself with `CREATE_SUSPENDED` and
negotiates the exit code on the command line. While the child hangs
suspended, `GetExitCodeProcess` reports `STILL_ACTIVE` and a zero
timeout wait returns `WAIT_TIMEOUT`, both asserted, so the child
provably exists and provably has not run. `ResumeThread` returns the
previous suspend count, 1, matching the page's reading: "If the return
value is 1, the specified thread was suspended but was restarted."
Then the wait, the code 42, the closes. Create frozen, start on
command, observe, reap: the same four verbs as fork, exec, waitpid,
close, with the copy step deleted.

#diagram([two creation models, the same parent verbs at the bottom], length: 13pt, {
  let col(x, title) = {
    cdraw.rect((x, 6.5), (x + 9.8, 7.6), fill: luma(205), radius: 0.02)
    cdraw.content((x + 4.9, 7.05), title, wrap: text.with(size: 6.5pt))
    cdraw.rect((x, 4.6), (x + 9.8, 6.3), fill: luma(235), radius: 0.02)
    cdraw.rect((x, 2.7), (x + 9.8, 4.4), fill: luma(235), radius: 0.02)
    cdraw.rect((x, 0.8), (x + 9.8, 2.5), fill: luma(235), radius: 0.02)
  }
  col(0.6, [posix: fork + exec])
  cdraw.content((5.5, 5.85), [fork: exact copy of the parent,], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 5.25), [copy-on-write pages, two returns], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.95), [execve: new image in the old pid,], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.35), [fds stay open, does not return], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 2.05), [waitpid, then WEXITSTATUS:], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 1.45), [the low 8 bits of the status], wrap: text.with(size: 6pt))
  col(13.2, [windows: CreateProcessW])
  cdraw.content((18.1, 5.85), [CreateProcessW: new process plus], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 5.25), [primary thread, one return], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 3.95), [no copy: fresh address space,], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 3.35), [two handles come back to the parent], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 2.05), [wait on the handle, then], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 1.45), [GetExitCodeProcess: all 32 bits], wrap: text.with(size: 6pt))
  cdraw.content((11.8, -0.6), [both parents end the same way: they observe the child, then drop their reference], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== waiting, exit codes, cleanup

`WaitForSingleObject` is the parent's only blocking verb, and its page
fixes the vocabulary the checks use. A zero timeout "does not enter a
wait state if the object is not signaled; it always returns
immediately", `INFINITE` "will return only when the object is
signaled", and the return values are constants: `WAIT_OBJECT_0`,
0x00000000, the object is signaled; `WAIT_TIMEOUT`, 0x00000102, 258,
the interval elapsed; `WAIT_FAILED` for an error. Process handles are
in the waitable list, and one caution belongs with the cleanup theme
of this section: "If this handle is closed while the wait is still
pending, the function's behavior is undefined."

#listing("c-os-cloud/samples/src/Ch11/spawn.c", first: 32, last: 49, caption: [one cmd.exe round trip, closes on every path])

#listing("c-os-cloud/samples/src/Ch11/spawn.c", first: 51, last: 59, caption: [the child role, one role line and a negotiated exit code])

The helper exists so the width probes read as one-liners, and its shape
is the chapter's cleanup rule in miniature: both handles close on
every path, including the failure path. The child role prints one line
with no `ok` prefix, so the gate's check count stays the parent's 19,
and exits with the negotiated code, the only child fact the parent
asserts through the kernel. `GetExitCodeProcess` defines what comes
back: "If the
process has not terminated and the function succeeds, the status
returned is STILL\_ACTIVE (a macro for STATUS_PENDING)", and after
termination the status is "The return value from the main or WinMain
function of the process", or the value given to `ExitProcess`, or the
exception value of a fatal crash.

#listing("c-os-cloud/samples/src/Ch11/spawn.c", first: 99, last: 107, caption: [32 bit exit codes and the 259 collision])

The three probes pin the width and one trap. `exit 300` arrives as
300, where the posix parent would fish the same child status out with
`WEXITSTATUS`, which "consists of the least significant 8 bits", 44
for 300. `exit -1` arrives as 4294967295, every bit carried. And
`exit 259` arrives as 259, indistinguishable from `STILL_ACTIVE`,
which is why the page's warning exists: "an application should not use
STILL\_ACTIVE (259) as an error code", because a caller polling for it
"could interpret it to mean that the thread is still running... which
could put the application into an infinite loop." The correct
termination test is the signaled wait, never the code value, and the
suspended-self-spawn checks earlier in the sample are exactly that
discipline executed.

What termination itself does is documented as a six-step sequence:
remaining threads are marked, the process's resources are freed, all
its kernel objects are closed, its code is removed from memory, the
exit code is set, and the process object is signaled. Two sentences
from the same page carry the cleanup half of this chapter: "While open
handles to kernel objects are closed automatically when a process
terminates, the objects themselves exist until all open handles to
them are closed", and "When a process terminates, the state of the
process object becomes signaled, releasing any threads that had been
waiting for the process to terminate." The child dying therefore costs
the parent nothing until the parent lets go, and killing a parent
costs the children nothing at all: "the system... does not terminate
any child processes that the process has created."

#diagram([the reap pipeline, wait, read, close, and what a skipped close keeps alive], length: 13pt, {
  let box(x, t) = {
    cdraw.rect((x, 5.6), (x + 6.6, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.3, 6.1), t, wrap: text.with(size: 6pt))
  }
  box(0.6, [WaitForSingleObject])
  box(8.0, [GetExitCodeProcess])
  box(15.4, [CloseHandle twice])
  box(22.8, [kernel object freed])
  cdraw.line((7.2, 6.1), (8.0, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 6.1), (15.4, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((22.0, 6.1), (22.8, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.9, 5.1), [signaled at exit], wrap: text.with(size: 6pt))
  cdraw.content((11.3, 5.1), [32 bit status, 259 pending], wrap: text.with(size: 6pt))
  cdraw.content((18.7, 5.1), [process handle, thread handle], wrap: text.with(size: 6pt))
  cdraw.content((26.1, 5.1), [last reference gone], wrap: text.with(size: 6pt))
  cdraw.rect((1.2, 1.4), (28.8, 4.0), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((15.0, 3.5), [the leak: skip the closes and the parent's table keeps], wrap: text.with(size: 6pt))
  cdraw.content((15.0, 2.9), [the entries, and the kernel keeps the child's process], wrap: text.with(size: 6pt))
  cdraw.content((15.0, 2.3), [object alive after the child is gone], wrap: text.with(size: 6pt))
  cdraw.content((15.0, 0.5), [the asan leg of the gate runs this sample: every handle accounted for], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The gate's own enforcement of the cleanup rule is the
address-sanitizer leg introduced in chapter 5, which recompiles and
runs `spawn.c` instrumented. The sample allocates no heap memory, so
the leg's real subject here is discipline: the self spawn's child runs
the same instrumented binary and finds the staged runtime through the
inherited working directory, and the parent's handle accounting stays
exact under instrumentation, probed. The address space half of the
process, the second layer of the opening figure, is chapter 12's
subject, and the thread object that `CreateProcessW` builds beside the
process is chapter 15's.

sources: learn.microsoft.com, CreateProcessW, GetExitCodeProcess,
WaitForSingleObject, CloseHandle, GetCurrentProcess, GetCurrentThread,
ResumeThread, GetProcessHandleCount, DuplicateHandle, GetStartupInfoW,
Process Creation Flags, and Terminating a Process pages, accessed
2026-09-12; pubs.opengroup.org Issue 8 fork and exec pages and man7.org
fork(2), execve(2), wait(2), accessed 2026-09-12; open-std.org n3220
(5.1.2.3.4 program termination, 7.24.4.2 atexit, 7.24.4.3
`at_quick_exit`, 7.24.4.4 exit, 7.24.4.5 `_Exit`, 7.24.4.7 `quick_exit`),
accessed 2026-09-12; the first-spawn handle delta, the -2 thread
pseudo handle, the 104 and 24 byte structures, the fork link failure,
and the asan handle accounting probed on this machine the same day.
Sample behavior verified by `make verify-c`, 33 checks in chapter 11
of the samples suite.
