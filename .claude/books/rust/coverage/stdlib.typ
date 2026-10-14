// stdlib coverage matrix, component families against the chapters that
// teach them, counted from the manual and service arcs at the closeout,
// each row grepped against its chapter 2026-10-14: taught with checks
// means the chapter's own samples or lane tests exercise it, stated
// means the chapter names it without a demonstration
#let stdlib-coverage = (
  (component: "collections, Vec VecDeque HashMap BTreeMap", chapter: "stdlib", status: "taught with checks, hashbrown swap stated at 1.36"),
  (component: "str and String, the utf-8 boundary", chapter: "stdlib", status: "taught with checks, the kernel's parser rides it"),
  (component: "io, Read Write BufReader read_exact copy", chapter: "stdlib", status: "taught with checks, in memory and deterministic"),
  (component: "path, Path PathBuf components", chapter: "stdlib", status: "taught with checks, windows component walk measured"),
  (component: "time, Duration Instant SystemTime", chapter: "stdlib", status: "taught with checks, ns per iteration measured"),
  (component: "net, TcpListener TcpStream", chapter: "stdlib", status: "taught with checks, the kernel and the capstone reactor reuse it"),
  (component: "env, args vars set_var", chapter: "stdlib", status: "taught with checks, set_var unsafe in edition 2024"),
  (component: "process, Command ExitCode Termination", chapter: "stdlib", status: "taught with checks, self spawn exit codes measured"),
  (component: "thread and join, spawn Builder scope", chapter: "concurrency", status: "taught with checks, scoped threads 1.63"),
  (component: "sync, Mutex RwLock Condvar mpsc", chapter: "concurrency", status: "taught with checks, the capstone executor rides it"),
  (component: "atomics, the orderings", chapter: "concurrency", status: "taught with checks"),
  (component: "cell and refcell", chapter: "memory", status: "taught with checks"),
  (component: "pin", chapter: "memory", status: "taught in one section, chapter 14 and the capstone ride it"),
  (component: "future and task, Poll Wake", chapter: "async", status: "taught with checks, xref to the capstone"),
  (component: "box rc arc, Weak and cycle breaking", chapter: "memory", status: "taught with checks"),
  (component: "alloc", chapter: "memory", status: "stated, the allocator api named as an escape hatch, not demonstrated"),
  (component: "fs, File OpenOptions read create_dir_all rename", chapter: "store", status: "taught with checks, the wal and compaction lane"),
  (component: "ffi, CStr c_char extern C", chapter: "unsafe", status: "taught with checks, strlen and qsort on msvc"),
)
