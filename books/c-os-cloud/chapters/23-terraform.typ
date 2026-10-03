#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= terraform: language and core workflow

Chapter 22 drew the responsibility line between provider and tenant. Terraform
is how this book works the tenant side of that line, with code instead of a
console. Its deal is declarative: the author writes files that
describe desired infrastructure, and the tool reconciles real objects toward
the description. This chapter reads the language those files are written in,
the resource graph they imply, the state file that binds configuration to
real objects, the plan and apply loop that does the reconciling, and the
version pins that keep every one of those claims stable.

The verification mode changes here and stays changed through chapter 27. The
four files under `Ch23/` are real, pinned terraform configuration and nothing
ever runs them: no terraform binary exists in this corpus, nothing is
initialized, planned, or applied. Every behavioral claim below is a sentence
quoted from a canonical page fetched 2026-09-12 or a line of those files. The
c chapters proved their claims by executing them. The cloud chapters prove
theirs by quoting the documentation that defines the behavior and pinning
the versions the quotes were read against.

== hcl blocks, arguments, and expressions

The grammar under every `.tf` file is HCL's native syntax, and the
configuration syntax page fixes its anatomy in a few sentences: "A block is
a container for other content." A block has a type, each block type defines
how many labels must follow the type keyword, and "After the block type
keyword and any labels, the block body is delimited by the `{` and `}`
characters." Inside that body "further arguments and blocks may be nested,
creating a hierarchy of blocks and their associated arguments." A `variable`
block carries one label, a `resource` block carries two, and a `validation`
block nests inside a `variable` block with no labels of its own:

#listing("c-os-cloud/samples/src/Ch23/variables.tf", first: 13, last: 22, caption: [the variable block: one label, four arguments, one nested validation block])

The `environment` block and its nested `validation` block are exactly that
hierarchy. The page also fixes this book's vocabulary for `=` lines. "An
argument assigns a value to a particular name", and terraform's docs say
argument, not attribute, on purpose: HCL's own documentation "usually uses
the word 'attribute' instead of 'argument'", but terraform resources have
attributes like `id` "that can be referenced from expressions but can't be
assigned values in configuration." Arguments are the inputs the author
writes, attributes are the values the provider reports back, and the
boundary between them is the boundary between configuration and state.

Names follow the identifier rules: "Identifiers can contain letters, digits,
underscores (`_`), and hyphens (`-`)", and "The first character of an
identifier must not be a digit, to avoid ambiguity with literal numbers."
Comments have three spellings. `#` is "the default comment style" and
"should be used in most cases", `//` is the same single-line comment in a
less idiomatic dress, and `/*` with `*/` "are start and end delimiters for a
comment that might span over multiple lines."

The right side of `=` is an expression, and the expressions page states the
charter in one sentence: "Expressions refer to or compute values within a
configuration." The simplest expressions are just literal values, like
`"hello"` or `5`. References name values the configuration already knows,
`var.environment`, `local.common_tags`, `aws_instance.web.id`. The rest of
the expression grammar builds new values from old ones, and two forms carry
most of that weight in real configurations, the for expression and the
splat:

#listing("c-os-cloud/samples/src/Ch23/main.tf", first: 10, last: 19, caption: [locals: string interpolation, an object literal, and a for expression that builds a tuple])

`web_names` is the form the docs open with: `[for s in var.list :
upper(s)]`. The page pins the result rule: "The type of brackets around the
`for` expression decide what type of result it produces." Square brackets
produce a tuple, and `web_names` is a tuple of strings, one per instance.
Curly braces produce an object and require "two result expressions that are
separated by the `=>` symbol." An optional `if` clause filters, the page
calls it "an optional `if` clause to filter elements from the source
collection", and grouping mode is a symbol: "To activate grouping mode, add
the symbol `...` after the value expression." One limit the page states
plainly: "You can't dynamically generate nested blocks using `for`
expressions", dynamic blocks are the tool for that instead, which chapter 24
uses.

The splat is the shortcut over the same ground. The page defines it as an
expression that "provides a more concise way to express a common operation
that could otherwise be performed with a `for` expression": "The special
`[*]` symbol iterates over all of the elements of the list given to its
left" and "accesses from each one the attribute name given on its right."
So `var.list[*].id` is exactly `[for o in var.list : o.id]`. The legacy
`.*` spelling is "less useful than the modern form" and survives only "for
backward compatibility", and the docs "recommend always using the new-style
splat expressions, with `[*]`, to get the more consistent behavior." The
difference is real, not cosmetic:

#snippet("var.list.*.interfaces[0].name\n  equals [for o in var.list : o.interfaces][0].name\n\nvar.list[*].interfaces[0].name\n  equals [for o in var.list : o.interfaces[0].name]\n", lang: "tf")

The legacy form applies `[0]` once, after the iteration. The full splat
applies it per element. Two more edges round out the form: applied to a
value that is not a list, "the splat expression will transform it into a
single-element list, or more accurately a single-element tuple value", and
"If the value is null then the splat expression will return an empty
tuple", which is why `var.website_setting[*]` feeds `for_each` so neatly, one
instance when set, zero when null.

This is the declarative contract in miniature. `[for i in
range(var.instance_count) : "web-${i}"]` has no loop counter, no iteration
variable to misuse, no order of side effects: it is a value computed from
other values. The whole file is the same contract at larger scale, a
description of an end state, and the question of when anything actually
runs belongs to the next section's graph.

#diagram([a block taken apart on the left, the expression forms and what each produces on the right], length: 13pt, {
  let b(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  let r(y, a, c) = {
    b(9.4, y, 7.2, a)
    b(18.0, y, 6.0, c, fill: luma(215))
    cdraw.line((16.6, y + 0.5), (18.0, y + 0.5), stroke: luma(100), mark: (end: ">"))
  }
  b(0.4, 6.2, 2.0, [resource], fill: luma(205))
  b(2.6, 6.2, 2.6, [aws\_instance], fill: luma(205))
  b(5.4, 6.2, 1.8, [web], fill: luma(205))
  b(0.4, 4.4, 6.8, [body: arguments and nested blocks])
  b(0.4, 2.6, 6.8, [nested lifecycle block, zero labels])
  cdraw.line((3.8, 6.2), (3.8, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.8, 4.4), (3.8, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.4, 7.5), [type keyword], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((5.0, 7.5), [two labels], wrap: text.with(size: 6pt, fill: luma(100)))
  r(6.2, [literals: "hello", 5, true], [string, number, bool])
  r(4.9, [references: var.x, local.y, res.id], [the named value])
  r(3.6, [for expression in \[ \]], [a tuple])
  r(2.3, [for expression in \{ \}, key =\> value], [an object])
  r(1.0, [splat: var.list\[\*\].id], [a tuple, one attribute])
  cdraw.content((12.5, 0.1), [every right side is a value, no expression runs anything], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== resources, providers, and the graph

The resource page states what the block is for: "The `resource` block
defines a piece of infrastructure and specifies the settings for Terraform
to create it with." Two labels follow the keyword, the resource type and a
name the author picks. The name matters to terraform only: "Terraform uses
this label to track the resource in your state file" and "it does not
affect settings on the actual infrastructure resource." The pair forms the
resource address, and the page fixes its shape: "To reference the resource
in your configuration, you must refer to it using `<TYPE>.<LABEL>` syntax."
Five meta-arguments are "built into the Terraform language" and modify the
block from inside. The two repetition modes are `count`, which "instructs
Terraform to provision multiple instances of the same resource with
identical or similar configuration", and `for_each`, which "instructs
Terraform to provision similar resources without requiring separate
configuration blocks." The page bars mixing them: "You cannot use both a
`count` and `for_each` argument in the same block." The sample uses one of
each, on two instances of the same resource type:

#listing("c-os-cloud/samples/src/Ch23/main.tf", first: 21, last: 34, caption: [the count resource: instances indexed by number, references only, one lifecycle rule])

#listing("c-os-cloud/samples/src/Ch23/main.tf", first: 36, last: 48, caption: [the `for_each` resource: keyed instances, the aliased provider, one explicit dependency])

The other meta-arguments are visible in the same two listings. The
`lifecycle` block in the first resource carries the sample's one rule,
`ignore_changes`, which "Specifies a list of resource attributes that
Terraform ignores changes to", the drift valve that keeps terraform from
fighting a tag an operator sets by hand. `depends_on` closes the second
listing and "specifies an upstream resource that the resource depends on",
the explicit edge the graph picks up below.

The mode decides the shape of every later reference. The references page
states both halves: "If the resource has the `count` argument set, the
reference's value is a list of objects representing its instances", so
`aws_instance.web` is a list and `aws_instance.web[0].id` "returns just the
id of the first instance." Under `for_each` "the reference's value is a map
of objects representing its instances", and `aws_instance.admin["ops"].id`
returns the one keyed instance. One asymmetry the page calls out: "splat
expressions are not directly applicable to resources managed with
`for_each`", the page's own workaround is `values(aws_instance.admin)[*].id`,
values first, splat second. Both shapes leave their trace in the outputs:

#listing("c-os-cloud/samples/src/Ch23/outputs.tf", first: 1, last: 14, caption: [the two address shapes: a list splats directly, a map goes through values first])

Providers are the plugins that know a specific cloud's api, and the provider
page splits their declaration from their configuration: "Use the `provider`
block to declare and configure Terraform plugins, called providers", with
version requirements living in `required_providers` instead, section 5's
subject. "Define provider configurations in the root module of your
Terraform configuration." One provider can have several configurations:
"Optionally use the `alias` argument to define multiple configurations for
the same provider", the block without an alias is the default, and a
resource opts into an alternate with the `provider` meta-argument, which
"instructs Terraform to use an alternate provider configuration to
provision the resource." The sample carries both shapes:

#listing("c-os-cloud/samples/src/Ch23/main.tf", first: 1, last: 8, caption: [two provider configurations: the default and the aliased aws.west])

Nothing in these files says when anything runs. That is the graph's job,
and the internals page says so: "Terraform builds a dependency graph and
uses it to perform operations, such as generate plans and refresh state."
The edges come from two places: "Explicit dependencies from the `depends_on`
meta-parameter are used to create edges between resources", and
"Interpolations are parsed in resource and provider configurations to
determine dependencies", every `aws_instance.web[*].id` inside the outputs
is an implicit edge. The walk itself is ordered and parallel at once: "To
walk the graph, a standard depth-first traversal is done", but "Graph
walking is done in parallel: a node is walked as soon as all of its
dependencies are walked", and "By default, up to 10 nodes in the graph will
be processed concurrently." That number meets the apply page from the other
side: `-parallelism` exists to "Limit the number of concurrent operations
as Terraform walks the graph" and "Defaults to 10."

#callout("pitfall", "the repetition mode is visible in every reference", [
  Choosing `count` or `for_each` is not a style call. It fixes whether
  `aws_instance.web` is a list or a map, and every expression that touches
  the resource afterwards inherits that shape: an index for `count`, a key
  for `for_each`, a plain splat for the first, `values()` before the splat
  for the second. Renumbering a `count` fleet or renaming a `for_each` key
  reads as destroy and create to the graph, because the address, not the
  contents, is the identity.
])

#diagram([the graph implied by the sample: two provider configurations feed four resource instances, outputs read them all], length: 13pt, {
  let n(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.4), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.7), t, wrap: text.with(size: 6pt))
  }
  let solid = luma(100)
  let dashed = (paint: luma(120), dash: "dashed")
  n(0.4, 6.2, 5.2, [provider aws, #linebreak() default configuration], fill: luma(205))
  n(0.4, 2.6, 5.2, [provider aws, #linebreak() alias west], fill: luma(205))
  n(7.0, 6.2, 5.2, [aws\_instance.web, #linebreak() instance 0 of count 2])
  n(7.0, 3.8, 5.2, [aws\_instance.web, #linebreak() instance 1 of count 2])
  n(13.8, 6.2, 5.2, [admin instance, #linebreak() key ops of for\_each])
  n(13.8, 3.8, 5.2, [admin instance, #linebreak() key sec of for\_each])
  n(20.4, 5.0, 3.4, [outputs: #linebreak() ids and names])
  cdraw.line((5.6, 6.9), (7.0, 6.9), stroke: solid, mark: (end: ">"))
  cdraw.line((5.6, 6.4), (7.0, 4.6), stroke: solid, mark: (end: ">"))
  cdraw.line((5.6, 3.55), (13.0, 3.55), (13.0, 6.45), (13.8, 6.45), stroke: solid, mark: (end: ">"))
  cdraw.line((5.6, 3.0), (12.4, 3.0), (12.4, 4.1), (13.8, 4.1), stroke: solid, mark: (end: ">"))
  cdraw.line((12.2, 6.9), (13.8, 6.9), stroke: dashed, mark: (end: ">"))
  cdraw.line((9.6, 7.6), (9.6, 8.15), (22.0, 8.15), (22.0, 6.4), stroke: solid, mark: (end: ">"))
  cdraw.line((9.6, 3.8), (9.6, 2.2), (21.8, 2.2), (21.8, 5.0), stroke: solid, mark: (end: ">"))
  cdraw.line((19.0, 6.5), (20.4, 5.9), stroke: solid, mark: (end: ">"))
  cdraw.line((19.0, 4.6), (20.4, 5.1), stroke: solid, mark: (end: ">"))
  cdraw.content((12.0, 1.4), [solid edges are parsed from interpolations, the dashed edge is depends\_on, drawn once for all four pairs], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((12.0, 0.4), [a node walks the moment its dependencies finish, 10 nodes at once by default], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== state anatomy

The state page opens with the obligation: "Terraform must store state about
your workspace's managed infrastructure and configuration", and the purpose
page grades it "State is a necessary requirement for Terraform to function."
State does three jobs. Mapping first: "Terraform requires some sort of
database to map Terraform config to the real world", and the example is
concrete, a resource in configuration "represents a real world object with
the instance ID `i-abcd1234` on a remote system." The binding is exclusive:
"Terraform expects that each remote object is bound to only one resource
instance in the configuration", and "Terraform can guarantee a one-to-one
mapping when it creates objects and records their identities in the state."
Metadata second: "Terraform must also track metadata such as resource
dependencies." Performance third: "Terraform stores a cache of the
attribute values for all resources in the state", and the page is candid
about its rank, "This is the most optional feature of Terraform state and
is done only as a performance improvement", with "the cached state is
treated as the record of truth" on large infrastructures where querying
every resource would be too slow.

By default the record is local: state lives "in a local file named
`terraform.tfstate`" with "a backup of the previous state in
`terraform.tfstate.backup`", and "State snapshots are stored in JSON
format." The page recommends remote backends instead, and the sensitive
data page supplies the reason in the bluntest sentence in this chapter:
"Terraform stores your state in a plaintext file, which includes any secret
values you defined in your configuration." The `sensitive` argument changes
the display, never the storage: "Terraform stores values with the
`sensitive` argument in both state and plan files, and anyone who can
access those files can access your sensitive values." The sample carries
one of each, the input variable and the output, so the pair sits side by
side in one directory:

#listing("c-os-cloud/samples/src/Ch23/variables.tf", first: 44, last: 48, caption: [a sensitive input: redacted in cli output, stored in state regardless])

#listing("c-os-cloud/samples/src/Ch23/outputs.tf", first: 21, last: 25, caption: [a sensitive output: same redaction, same storage, both doc-stated])

Neither line protects anything. The page's practices do: "Treat your state
file as sensitive data by excluding it from Git workflows", store state
remotely, encrypt it at rest, control who reads it, audit the reads. Newer
than the redaction argument is the real omission mechanism, and the
variables page states it: "You can add the `ephemeral` argument to your
`variable` configuration to omit the variable from state and plan files",
the only tool on these pages that keeps a value out of the file rather
than out of the display.

Locking is the concurrency half of the same anatomy. The locking page
states the rule: "If supported by your backend, Terraform will lock your
state for all operations that could write state", which "prevents others
from acquiring the lock and potentially corrupting your state." The
qualification matters, "Not all backends support locking." Locking is
quiet, "State locking happens automatically on all operations that could
write state", and strict: "If state locking fails, Terraform does not
continue." The escape hatch is `force-unlock`, and the page's own warning
is the whole guidance: "Be very careful with this command", because "If
you unlock the state when someone else is holding the lock it could cause
multiple writers", and "the `force-unlock` command requires a unique lock
ID" as a nonce so the unlock targets the right lock. `-lock=false` exists
for most commands "but we do not recommend it."

Losing the file is the other disaster the anatomy explains. Local state
"risks losing workspace state if the local state file is lost", and what
is lost is the mapping: with the one-to-one record gone, no later plan can
find the remote object any resource refers to, so the plan reads as
creation while the real objects, and their bills, keep running under
addresses terraform no longer knows. The fix named on both pages is the
same, remote state with locking.

#callout("warning", "sensitive is display hygiene, not secrecy", [
  Marking a variable or output `sensitive` changes what the cli prints and
  nothing else. The value rides into `terraform.tfstate` and any saved plan
  file in cleartext, and `terraform output -json` prints it back out.
  Secrets belong in ephemeral values, which never reach the files, or in a
  provider-side secret manager whose state entry is a reference, not the
  secret.
])

#diagram([state anatomy in four columns: the record, the prohibition, the lock, the loss], length: 13pt, {
  let col(x, head, lines) = {
    cdraw.rect((x, 6.6), (x + 5.5, 7.6), fill: luma(205), radius: 0.02)
    cdraw.content((x + 2.75, 7.1), head, wrap: text.with(size: 6pt))
    cdraw.rect((x, 0.8), (x + 5.5, 6.3), fill: luma(235), radius: 0.02)
    for (i, t) in lines.enumerate() {
      cdraw.content((x + 2.75, 5.6 - i * 1.25), t, wrap: text.with(size: 6pt))
    }
  }
  col(0.4, [what it records], ([bindings: address to real object id], [metadata: resource dependencies], [cached attribute values], [root module outputs]))
  col(6.5, [what it never holds], ([secrets in cleartext], [sensitive redacts display only], [ephemeral values, omitted], [plan files carry them too]))
  col(12.6, [locking], ([locked on every write], [not all backends lock], [a failed lock halts the run], [force-unlock needs the lock id]))
  col(18.7, [a lost file], ([the one-to-one binding is gone], [the next plan proposes creates], [the old objects keep running], [remote state is the fix]))
  cdraw.content((12.4, 0.2), [four columns, four failure stories, one json file in the middle of all of them], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== plan and apply

The loop that reconciles the three-way match between configuration, state,
and the real world runs on two commands. Plan's page opens: it "creates an
execution plan, which lets you preview the changes that Terraform plans to
make to your infrastructure", and "The `plan` command alone does not
actually carry out the proposed changes." Every plan begins with a refresh,
plan "Reads the current state of any already-existing remote objects to
make sure that the Terraform state is up-to-date." Skipping it has a named
cost: `-refresh=false` "causes Terraform to ignore external changes, which
could result in an incomplete or incorrect plan." `-refresh-only` inverts
the goal and "creates a plan whose goal is only to update the Terraform
state and any root module output values", the drift-direction run.

A plan can be saved: "You can use the optional `-out=FILE` option to save
the generated plan to a file on disk" for apply to consume. A saved plan is
a promise with a timestamp, not a lock on the world: "other changes made
to the target system in the meantime might cause the final effect of a
configuration change" to differ from the preview, so "you should always
re-check the final non-speculative plan before applying." Plan files also
inherit state's transparency problem, values are "saved in cleartext in
the plan file", so the page says to "treat any saved plan files as
potentially-sensitive artifacts."

Apply's page returns the favor in one line: "The `terraform apply` command
executes the operations proposed in a Terraform plan." Given a saved plan
file, "Terraform performs the operations in the saved plan without
prompting you for confirmation." Given none, "Terraform automatically
creates a new execution plan as if you had run `terraform plan`", then
"prompts you to approve that plan, and performs the indicated operations."
`-auto-approve` "Skips interactive approval of the plan before applying",
is ignored with a saved plan because "Terraform interprets the act of
passing the plan file as the approval", and the page warns what skipping
covers, "this includes destructive operations such as deleting resources."
What apply actually does to each resource is a five-item list on the
create and manage page. It "Creates resources in the configuration that
do not yet exist as real infrastructure objects", "Updates any resources
in place if their arguments have changed", "Destroys and re-creates
resources whose arguments have changed but cannot be updated in-place due
to remote API limitations", "Destroys resources that exist in the state
but no longer exist in the configuration", and "Updates the state file so
that the configuration, real infrastructure, and state match." The
operations run as the graph walk from the previous section, in parallel up
to the same limit of 10. For automation, `-detailed-exitcode` gives plan
three answers: 0 "Succeeded with empty diff (no changes)", 1 "Error", 2
"Succeeded with non-empty diff (changes present)."

#snippet("terraform plan -refresh-only\nterraform plan -out=tfplan\nterraform apply tfplan\n", lang: "bash")

Those three commands are the loop in its automation dress, reconcile
state, freeze a decision, execute it, and this book never runs any of
them. The .tf files are the inputs the loop would consume, and the
documentation is the record of what it would do.

#diagram([the core loop as a ring: refresh reads, plan diffs, review gates, apply walks, state records], length: 13pt, {
  let n(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  n(9.6, 6.2, 5.6, [refresh: #linebreak() read every remote object])
  n(17.0, 3.6, 6.6, [plan: #linebreak() diff config, state, remote])
  n(12.8, 0.4, 6.0, [review: #linebreak() approve, or -out=file])
  n(5.0, 0.4, 5.4, [apply: #linebreak() walk the graph])
  n(1.4, 3.6, 5.4, [state: #linebreak() identities recorded])
  cdraw.line((15.2, 6.4), (18.6, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.3, 3.6), (18.5, 1.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.8, 0.9), (10.4, 0.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.5, 1.5), (5.0, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.1, 4.7), (9.6, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 3.4), [the ring this book never spins: #linebreak() nothing here is executed], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== version pinning

Every page quoted above carried a version selector reading "v1.16.x
(latest)", which is the document's own warning that its sentences move
with the tool. The dated source of truth is the release record. The
install page names the current release "1.16.2 (latest)" and lists every
release back to 1.0.11. The GitHub releases page gives the dates: 1.16.0
on August 26, 1.16.1 on September 2, "1.16.2 (September 9, 2026)" marked
Latest, and v1.17.0-beta1 above it marked Pre-release, which no constraint
here will pick up: "Terraform does not match pre-release versions on `>`,
`>=`, `<`, `<=`, or `~>` operators", and an exact pin never names it at
all.

The configuration enforces its own reader. `required_version` "Specifies
which version of the Terraform CLI is allowed to run the configuration",
and a mismatch stops the run before it starts, "Terraform prints an error
and exits without taking actions." The whole `terraform` block is
constant-only, "You can only use constant values in the `terraform`
block", no variables, no references, because these values gate everything
else. Providers pin through `required_providers`, which "must be nested
inside the top-level `terraform` block": `source` is "the global source
address for the provider you intend to use, such as `hashicorp/aws`", and
`version` is "a version constraint specifying which subset of available
provider versions the module is compatible with." The constraint grammar
is seven operators. A bare version with `=` "Allows only one exact version
number." The `~>` shorthand "Allows only the right-most version component
to increment", with the page's own pair of examples, "`~> 1.0.4`: Allows
Terraform to install `1.0.5` and `1.0.10` but not `1.1.0`" and "`~> 1.1`:
Allows Terraform to install `1.2` and `1.10` but not `2.0`."

#listing("c-os-cloud/samples/src/Ch23/versions.tf", first: 1, last: 15, caption: [the freeze: exact cli and provider pins, dated in the comment, nothing executed against them])

Both pins are exact, both carry their release date in the comment, and the
provider pin is the releases page's own current record: the
hashicorp/terraform-provider-aws releases list reads "6.64.0 (September
9, 2026)" marked Latest, with 6.63.0 on September 3 and 6.62.0 on August
26 behind it. The last piece of the discipline is the one file terraform
writes back: "The lock file is always named `.terraform.lock.hcl`" and
terraform "automatically creates or updates the dependency lock file each
time you run the `terraform init` command." It records "the exact version
that Terraform selected based on the version constraints in the
configuration", plus checksums in two schemes, `zh:` is "a mnemonic for
'zip hash'" and `h1:` is "a mnemonic for 'hash scheme 1'". Once recorded,
a selection sticks, "Terraform will always re-select that version for
installation, even if a newer version has become available", until
`-upgrade` says otherwise. The page's advice closes the loop: "you should
include this file in your version control repository." Global machine
state sits outside the repository by design, the cli configuration
overview notes the cli config file "configures provider installation and
security features" for the whole user, while the version discipline that
travels with the code lives in `versions.tf`, the lock file beside it, and
the access dates in the sources line below.

#diagram([two release tracks, one date axis, the pair this book pins], length: 13pt, {
  let tick(x, y, up, t, pinned: false) = {
    cdraw.circle((x, y), radius: 0.16, fill: if pinned { luma(120) } else { luma(235) }, stroke: luma(100))
    cdraw.content((x, y + if up { 0.75 } else { -0.75 }), t, wrap: text.with(size: 6pt))
  }
  cdraw.line((1.6, 5.6), (22.6, 5.6), stroke: luma(100))
  cdraw.line((1.6, 2.2), (22.6, 2.2), stroke: luma(100))
  cdraw.content((0.6, 6.9), [terraform cli], wrap: text.with(size: 6pt))
  cdraw.content((0.6, 3.5), [hashicorp/aws], wrap: text.with(size: 6pt))
  tick(3.4, 5.6, true, [1.16.0, #linebreak() Aug 26])
  tick(11.6, 5.6, true, [1.16.1, #linebreak() Sep 2])
  tick(20.4, 5.6, true, [1.16.2, #linebreak() Sep 9, the pin], pinned: true)
  tick(3.4, 2.2, false, [6.62.0, #linebreak() Aug 26])
  tick(11.6, 2.2, false, [6.63.0, #linebreak() Sep 3])
  tick(20.4, 2.2, false, [6.64.0, #linebreak() Sep 9, the pin], pinned: true)
  cdraw.content((12.0, 0.5), [v1.17.0-beta1 exists as a pre-release: no range operator matches it, an exact pin ignores it], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((12.0, 7.7), [both dark ticks are the exact pins in versions.tf, both dated 2026-09-09, both Latest on 2026-09-12], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

sources: developer.hashicorp.com terraform pages, configuration syntax,
expressions, for expressions, splat expressions, references to values,
resource block reference, provider block reference, terraform block
reference, provider requirements, version constraints, dependency lock
file, state, purpose of state, state locking, manage sensitive data,
create and manage resources overview, dependency graph, plan and apply
command references, cli configuration overview, and the install page, all
accessed 2026-09-12, github.com hashicorp/terraform and
hashicorp/terraform-provider-aws releases, accessed 2026-09-12.
Documentation-verified only: no terraform binary in this corpus, nothing
initialized, planned, or applied. The version pins are 1.16.2 for the cli
and 6.64.0 for hashicorp/aws, the Latest marks on both release pages at
access time.
