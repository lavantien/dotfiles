#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= terraform modules and workflows

Chapter 23 read the terraform language one block at a time and never
assembled the parts. This chapter assembles them. A module is the unit
of assembly, a directory of `.tf` files with a declared interface, and
around that unit sit the workflows that make it operable: version pins
that keep its sources stable, a backend that decides where its state
lives, workspaces that give one configuration several state instances,
and the three commands that check a module without touching a cloud.
The sample is one root module composing one local network module, plus
the backend, test, and version files around them.

The verification mode is chapter 23's, unchanged. The nine files under
`Ch24/` are real, pinned terraform configuration and nothing ever runs
them: no terraform binary exists in this corpus, nothing is
initialized, planned, or applied. Every behavioral claim below is a
sentence quoted from a canonical page fetched 2026-09-12 or a line of
those files. The version freeze is chapter 23's, terraform 1.16.2 and
hashicorp/aws 6.64.0, both published 2026-09-09 and both marked Latest
at access time.

== variables, outputs, locals

The variables page states the contract in its first sentence: "You can
add `variable` blocks to your configuration to define input interface
for your module." The rest of the sentence gives the direction: "This
lets users pass custom values to your module at runtime." Inputs flow
in, and the block reference fixes the vocabulary of what may flow: a
variable block supports `type`, `default`, `description`, `validation`,
`sensitive`, `nullable`, `ephemeral`, `const`, and `deprecated`, every
one of them optional, and its name label "must be unique among all
variables in the same module." A variable without a default is a
required input, and the page says what that costs the caller:
"Terraform prompts the user to supply a value for that variable before
it generates a plan." The network module's interface opens with one of
each kind:

#listing("c-os-cloud/samples/src/Ch24/modules/network/variables.tf", first: 5, last: 14, caption: [the interface so far: a required string and a defaulted list, two type constraints])

The `type` argument is where the contract becomes checkable. The block
reference: "The `type` argument in a `variable` block constrains the
type of value that you can assign to that variable", and without one
"the variable accepts a value of any type." Anything the language can
express is allowed: "You can use any valid primitive, complex, or
structural type as a constraint in a variable block", and the
reference's own example of a structural constraint is
`list(object({ internal = number, external = number, protocol = string }))`.
The sample keeps to three kinds, `string`, `list(string)`, and
`map(string)`, enough to make every value the module accepts carry a
type the caller can read off the file. Validation closes the contract.
A `validation` block carries two required arguments, `condition`,
"Expression that must evaluate to `true` for Terraform to proceed with
an operation", and `error_message`, "Message to display if the
condition evaluates to false." Its timing is plan time, not apply
time: "Terraform evaluates variable validations while it creates a
plan", and on failure Terraform "throws an error, displays the
`error_message`, and stops the current operation." Two more arguments
round out the reference: `nullable`, where "If `nullable` is `false`
in a variable block, then that variable must have a value that is not
null", and `ephemeral`, "available in Terraform v1.10 and later",
which keeps a value out of state and plan files entirely:

#listing("c-os-cloud/samples/src/Ch24/modules/network/variables.tf", first: 16, last: 31, caption: [a validated environment and a map of caller tags, the plan time gate in the middle])

Outputs are the other side of the interface. The outputs page: "Add
`output` blocks to your configuration to expose information about your
infrastructure", and for modules specifically, "Defining an `output`
block in a child module exposes that value to the parent module."
Inside the block, `value` is the one obligation: "You must include a
`value` argument in each `output` block", and Terraform "evaluates the
`value` argument's expression and exposes the result as the return
value of an output and stores that value in state." Root module
outputs get their own stage: "Terraform displays root module output
values in the CLI after you apply your configuration." Outputs also
carry a precondition block, "a condition to validate before computing
the output or storing it in state", with the same two arguments as a
variable validation and the same timing, "Terraform evaluates
preconditions on outputs when creating or applying a plan":

#listing("c-os-cloud/samples/src/Ch24/modules/network/outputs.tf", first: 4, last: 17, caption: [three outputs: a plain attribute, a splat over the count list, the cidrs known from configuration alone])

Locals are the module's private scratch, and the locals page keeps
them small on purpose: "Local values assign names to expressions" and
"Local values are similar to function-scoped variables in other
programming languages." Their scope is the module and nothing wider:
"You can access local values in the module where you define them, but
not in other modules", reached with `local.<NAME>`. The page's warning
is the design constraint this sample obeys, two locals, each used
twice: "However, they can make configuration harder to read because
they obscure where values originate." The body reads them the way a
function body reads its own locals:

#listing("c-os-cloud/samples/src/Ch24/modules/network/main.tf", first: 4, last: 11, caption: [locals: the tag merge and the subnet count, named once, read twice])

#listing("c-os-cloud/samples/src/Ch24/modules/network/main.tf", first: 13, last: 17, caption: [the vpc: one argument from the interface, one tag merge through the local])

The subnet resource is the one place the module computes rather than
passes through. `cidrsubnet` "calculates a subnet address within given
IP network address prefix" with the signature
`cidrsubnet(prefix, newbits, netnum)`, where "`newbits` is the number
of additional bits with which to extend the prefix." The page's
arithmetic example is `cidrsubnet("10.1.2.0/24", 4, 15)`, which
returns `10.1.2.240/28`, and its rule covers the sample's case
directly: "if given a prefix ending in `/16` and a `newbits` value of
`4`, the resulting subnet address will have length `/20`." So
`cidrsubnet(var.vpc_cidr, 4, count.index)` turns one `/16` into a
`/20` per subnet, `10.0.0.0/20` then `10.0.16.0/20`, derived from the
interface with no second input:

#listing("c-os-cloud/samples/src/Ch24/modules/network/main.tf", first: 19, last: 29, caption: [count over the zone list, one computed cidr per index, tags merged last])

#diagram([the module as a data structure: variables enter left, outputs leave right, locals never leave], length: 13pt, {
  let inp(y, t) = {
    cdraw.rect((0.6, y), (6.8, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((3.7, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  let out(y, t) = {
    cdraw.rect((17.2, y), (22.8, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((20.0, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  cdraw.rect((8.8, 2.6), (14.8, 7.6), fill: luma(215), radius: 0.02)
  cdraw.content((11.8, 7.0), [locals: module\_tags, subnet\_count], wrap: text.with(size: 6pt))
  cdraw.content((11.8, 6.0), [aws\_vpc.main], wrap: text.with(size: 6pt))
  cdraw.content((11.8, 5.0), [aws\_subnet.main, one per zone], wrap: text.with(size: 6pt))
  cdraw.content((11.8, 4.0), [cidrsubnet per count.index], wrap: text.with(size: 6pt))
  cdraw.content((11.8, 8.2), [the module body, replaceable behind the interface], wrap: text.with(size: 6.5pt, fill: luma(100)))
  inp(6.8, [vpc\_cidr: string, no default])
  inp(5.5, [availability\_zones: list(string)])
  inp(4.2, [environment: string, validation])
  inp(2.9, [extra\_tags: map(string)])
  out(6.8, [vpc\_id: aws\_vpc.main.id])
  out(5.5, [subnet\_ids: splat over count list])
  out(4.2, [subnet\_cidrs: the cidrsubnet results])
  cdraw.line((6.8, 7.3), (8.8, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.8, 6.0), (8.8, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.8, 4.7), (8.8, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.8, 3.4), (8.8, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.8, 7.3), (17.2, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.8, 6.0), (17.2, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.8, 4.7), (17.2, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.8, 1.5), [the interface is the contract: variables in, outputs out, locals never leave the box], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.8, 0.6), [variable validations run while terraform creates a plan, output preconditions before the value is stored], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== modules and versioning

The modules page fixes the vocabulary this chapter has been borrowing:
"A module is a collection of resources that Terraform manages
together." Every configuration is one already, because "Every
Terraform workspace includes configuration files in its root
directory" and "Terraform refers to this configuration as the root
module." The blocks that call other directories are the children:
"Modules you configure using `module` blocks are called child
modules", and at apply time "the root module calls the child module."
The calling side is one block: "The `module` block instructs Terraform
to create resources defined in a local or remote module", with "The
`source` argument specifies where Terraform retrieves the module
source code." The sample's root module is the whole of it:

#listing("c-os-cloud/samples/src/Ch24/main.tf", first: 6, last: 11, caption: [the root module's entire body: one module block, two interface arguments])

Sources come in families. The modules page lists them, "including the
local file system, a Terraform registry, and VCS repositories", and
the block reference fixes the local spelling: "Use the `./` or `../`
prefix followed by the path to local module source code." The registry
spelling is an address, `source = "<NAMESPACE>/<NAME>/<PROVIDER>"`,
and the sources page shows the form this book's registry pin would
take, the `terraform-aws-modules/vpc/aws` module at `version =
"6.0.1"`. The `source` value itself is rigid on purpose: "You must
specify a literal string for the `source` value. This argument does
not support template sequences or arbitrary expressions."

#snippet("module \"vpc\" {\n  source  = \"terraform-aws-modules/vpc/aws\"\n  version = \"6.0.1\"\n}\n", lang: "tf")

The `version` argument is the axis the audit row names, and the block
reference draws its boundary in two sentences: "The `version`
argument specifies which version of the module to use. This argument
only applies when installing modules from a registry", and "Modules
sourced from local file paths do not support `version`." Selection is
constraint-driven: "When an acceptable version isn't installed,
Terraform downloads the newest version that meets the constraint", and
the recommendation runs the same direction as chapter 23's provider
pins, "We recommend explicitly constraining the acceptable version
numbers to avoid unexpected or unwanted changes."

What crosses the boundary in the other direction is only outputs:
"When the child module you are calling exposes output values, you can
use the `module.<label>.<output>` syntax to reference them." The root
re-exposes two of the network module's three, which is the whole
difference between a root module and a reusable one:

#listing("c-os-cloud/samples/src/Ch24/outputs.tf", first: 4, last: 12, caption: [child outputs re-exposed at the root, the only syntax that crosses the boundary])

The child module's shape is the structure page's recommendation
verbatim: "`main.tf`, `variables.tf`, `outputs.tf`" are "the
recommended filenames for a minimal module, even if they're empty",
"`main.tf` should be the primary entrypoint", "variables.tf and
outputs.tf should contain the declarations for variables and outputs,
respectively", and "All variables and outputs should have one or two
sentence descriptions that explain their purpose." The develop pages
grade the design choices around that shape. Depth: "we recommend
keeping the module tree relatively flat and using module composition"
rather than "a deeply-nested tree of modules", because flat trees
reuse better. Size: "A good module should raise the level of
abstraction by describing a new concept in your architecture", while
the docs "do not recommend writing modules that are just thin wrappers
around single other resource types", and moderation wins overall,
since "over-using modules can make your overall Terraform
configuration harder to understand and maintain." One requirement
lives inside every module regardless of shape: "Each Terraform module
must declare which providers it requires, so that Terraform can
install and use them", which is why the child carries its own pin:

#listing("c-os-cloud/samples/src/Ch24/modules/network/versions.tf", first: 4, last: 11, caption: [the child's provider requirement, the same pin the root declares])

#listing("c-os-cloud/samples/src/Ch24/versions.tf", first: 7, last: 16, caption: [the root's freeze, identical to chapter 23's: cli and provider, exact and dated])

Installation is init's job, and the block reference ties it to the one
argument that moves: "You must run `terraform init` after modifying
the `source` argument so that Terraform can update the local code."
The sources page says where the bytes land: "Terraform clones the
module source configurations into a hidden subdirectory of the
workspace's working directory", and `-upgrade` is the flag that lifts
a module "to the latest version allowed by the version constraint."

#callout("pitfall", "a local module has no version to pin", [
  The pin and the path are mutually exclusive. Registry sources take
  `version`, local sources cannot, so `./modules/network` is read as
  the bytes currently in the tree and nothing records which bytes an
  earlier run saw. The version discipline a local module gets is the
  repository around it: the module is pinned by commit, not by
  terraform. Registry composition trades that for the argument this
  sample cannot use, an explicit constraint like the snippet's
  `6.0.1`, selected once and recorded by init.
])

#diagram([the module stack: root on top, sources below it, init below them, pins at the bottom], length: 13pt, {
  let layer(y, x0, x1, t, fill: luma(235)) = {
    cdraw.rect((x0, y), (x1, y + 1.1), fill: fill, radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  layer(6.7, 1.0, 22.6, [root module: one module block composes .\/modules\/network, outputs re-expose two of three], fill: luma(205))
  layer(5.4, 1.0, 11.6, [local source: .\/ or ..\/ prefix, no version argument])
  layer(5.4, 12.0, 22.6, [registry source: NAMESPACE\/NAME\/PROVIDER, version pin])
  layer(4.1, 1.0, 22.6, [terraform init: clones sources into a hidden subdirectory, downloads the newest version meeting the constraint])
  layer(2.8, 1.0, 22.6, [every module declares its providers: hashicorp\/aws 6.64.0 in root and child])
  layer(1.5, 1.0, 22.6, [required\_version = "1.16.2" gates the cli, chapter 23's freeze unchanged])
  cdraw.line((6.0, 6.7), (6.0, 6.55), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 5.4), (17.0, 5.25), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 4.1), (11.8, 3.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.8, 0.5), [the version argument rides only the registry branch, local bytes travel unpinned], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== backends and workspaces

Chapter 23 established state as terraform's binding record and left it
in a local file. The backends page names the knob that moves it: "The
`backend` defines where Terraform stores its state data files", and
"Terraform uses a backend called `local` by default", where "The
`local` backend type stores state as a local file on disk." The
configuration is one nested block: "To configure a backend, add a
nested `backend` block within the top-level `terraform` block", with
the backend type as the block label and "A configuration can only
provide one backend block." The block is also sealed: "A backend block
cannot refer to named values (like input variables, locals, or data
source attributes)", and nothing read back out either, "You cannot
reference values declared within backend blocks elsewhere in the
configuration." That seal is why the sample's bucket name is a literal
and not `var.state_bucket`.

The s3 backend page opens with what it does: "Stores the state as a
given key in a given bucket on Amazon S3." Three arguments are
required, `bucket`, "Name of the S3 Bucket", `key`, "Path to the state
file inside the S3 Bucket", and `region`, the "AWS Region of the S3
Bucket and DynamoDB Table (if used)". Locking is the reason to prefer
it over a bare disk, and the page grades it honestly: "State locking
is an opt-in feature of the S3 backend", though "Locking can be
enabled via S3 or DynamoDB", and the old path is on its way out,
"DynamoDB-based locking is deprecated and will be removed in a future
minor version." The current spelling is `use_lockfile`, "Whether to
use a lockfile for locking the state file. Defaults to `false`", which
the sample opts into, alongside `encrypt`, "Enable server side
encryption of the state and lock files":

#listing("c-os-cloud/samples/src/Ch24/backend.tf", first: 7, last: 15, caption: [the backend block: three required arguments, the lockfile opt in, encryption on])

The deprecation carries detail worth keeping. The legacy route is the
`dynamodb_table` argument, marked deprecated on the page, and its
table has one hard requirement: "The table must have a partition key
named `LockID` with a type of `String`." The bucket itself earns the
page's one emphatic recommendation, "It is highly recommended that you
enable Bucket Versioning on the S3 bucket" for "state recovery in the
case of accidental deletions and human error." Backend changes are an
init event: after changing the block "you must run `terraform init`
again to validate and configure the backend" before any "plans,
applies, or state operations", and "When you change backends, Terraform
gives you the option to migrate your state to the new backend."
Secrets stay out of the file the usual way, partial configuration:
omitted arguments are supplied "as part of the initialization process"
through `-backend-config=PATH` or `-backend-config="KEY=VALUE"`, with
"`*.backendname.tfbackend`" as "the recommended naming pattern."

Workspaces multiply the state without multiplying the configuration.
The language page: "Some backends support multiple named workspaces,
allowing multiple states to be associated with a single
configuration", and the starting point is fixed, "Terraform starts
with a single, default workspace named `default` that you cannot
delete." The isolation is at the state layer and nowhere else: "When
you run `terraform plan` in a new workspace, Terraform does not access
existing resources in other workspaces", and "These resources still
physically exist, but you must switch workspaces to manage them." The
cli page grounds the same idea in the working directory: "Workspaces
in the Terraform CLI refer to separate instances of state data inside
the same Terraform working directory." For local state "Terraform
stores the workspace states in a directory called
`terraform.tfstate.d`", and the current selection is machine-local,
"Terraform stores the current workspace name locally in the ignored
`.terraform` directory."

The name a workspace carries is a real constraint with a quiet edge.
The cli page's rule is short: "the name must be valid to use in a URL
path segment without escaping." But the language page also documents
the `terraform.workspace` interpolation, "the name of the current
workspace", which "can be used anywhere interpolations are allowed",
so the same string that names the state slot is available to every
expression in the configuration, and a workspace name chosen casually
becomes part of every name built from it. The naming questions the
page answers outright are the structural ones: workspaces suit
parallel copies of one configuration, and "Non-default workspaces are
often related to feature branches in version control", but
"Workspaces are not appropriate for system decomposition or
deployments requiring separate credentials and access controls", those
want separate root modules with separate backends. Switching is three
commands, `workspace list` where "The current workspace is indicated
using an asterisk marker", `workspace select`, whose `-or-create`
flag will "If the workspace that is being selected does not exist,
create it", and `workspace new`.

#diagram([workspace selection as a state machine: which state slot the next plan reads, and where the slot lives], length: 13pt, {
  let ws(y, t, fill: luma(235)) = {
    cdraw.rect((0.6, y), (6.0, y + 1.0), fill: fill, radius: 0.3)
    cdraw.content((3.3, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  ws(6.8, [workspace default, cannot be deleted], fill: luma(205))
  ws(5.2, [workspace staging])
  ws(3.6, [workspace prod])
  cdraw.content((3.3, 2.3), [workspace new, select, delete], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((2.0, 6.8), (2.0, 6.2), stroke: luma(140), mark: (end: ">"), )
  cdraw.line((4.6, 5.2), (4.6, 4.6), stroke: luma(140), mark: (end: ">"))
  cdraw.rect((7.6, 4.4), (12.8, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((10.2, 5.2), [one state per workspace], wrap: text.with(size: 6pt))
  cdraw.content((10.2, 3.5), [local: terraform.tfstate.d], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((10.2, 2.6), [remote: the backend's key], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((6.0, 7.3), (7.6, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 5.7), (7.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 4.1), (7.6, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.0, 4.4), (18.4, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.2, 5.2), [backend block: bucket, key, use\_lockfile], wrap: text.with(size: 6pt))
  cdraw.line((12.8, 5.2), (14.0, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((19.0, 4.4), (22.6, 6.0), fill: luma(215), radius: 0.02)
  cdraw.content((20.8, 5.2), [lock], wrap: text.with(size: 6pt))
  cdraw.line((18.4, 5.2), (19.0, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((19.0, 2.2), (22.6, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((20.8, 3.0), [plan or apply], wrap: text.with(size: 6pt))
  cdraw.line((20.8, 4.4), (20.8, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.0, 3.0), (10.2, 3.0), (10.2, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 1.2), [init configures the backend, changing it offers state migration], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.5, 0.4), [names must be valid url path segments, \${terraform.workspace} reaches any interpolation], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== fmt, validate, terraform test

Three commands check a module without provisioning anything, and they
are the closest a cloud chapter gets to the c chapters' gate. The first
is purely textual: "The `terraform fmt` command formats Terraform
configuration file contents so that it matches the canonical format
and style." It "applies a subset of the Terraform language style
conventions" with "other minor adjustments for readability", and it is
unalterable: "This command is intentionally opinionated and has no
customization options." In a check rather than rewrite, `-check`
"Checks if the input is formatted", and the exit contract is what a
gate consumes: "The exit status is `0` if the command's input is
properly formatted", and "Otherwise, the exit status is non-zero, and
the command outputs a list of improperly formatted file names."
`-diff` "Displays the diffs of formatting changes", and `-recursive`
"Processes files in subdirectories in addition to the current
directory", which matters here, the module lives in one.

The second command reads the configuration's shape. "The `terraform
validate` command validates the configuration files in a directory",
with checks that "verify whether a configuration is syntactically
valid and internally consistent", including "correctness of attribute
names and value types." It has one precondition: "Validation requires
an initialized working directory with any referenced plugins and
modules installed", and the page provides the bootstrapping pair for
exactly this chapter's situation, initialize "without accessing any
configured backend" with `terraform init -backend=false`. The boundary
is stated flatly: "It does not validate remote services, such as
remote state or provider APIs", which is why "It is safe to run this
command automatically, for example as a post-save check in a text
editor or as a test step."

The third command executes the configuration's own test files. "The
`terraform test` command loads and executes Terraform testing files",
discovered "based on their file extension: `.tftest.hcl` or
`.tftest.json`", with `tests` as the default directory, and run blocks
"by default" executing sequentially. Each run block is a plan or an
apply: "Terraform then executes a series of Terraform plan or apply
commands according to the test files' specifications" and "also
validates the relevant plan and state files according to the test
files' specifications", with "each `run` block" defaulting to
`command = apply`. The sample's first run opts into the cheaper
default and points the run at the child module directly, since within
test files the `module` block "only supports the `source` attribute
and the `version` attribute", and test sources may be "local and
registry modules":

#listing("c-os-cloud/samples/src/Ch24/network.tftest.hcl", first: 6, last: 27, caption: [the first run block: command = plan, the child module as source, two asserts on plan known values])

Assertions are the checks themselves: "Each `assert` block contains a
`condition` argument and an `error_message` argument", and both of
the sample's assert on values a plan can know, the vpc's
`cidr_block`, which comes straight from a variable, and the length of
the subnet list, which `count` fixes before any resource exists.
Variable inputs ride "variables blocks at both the root level and
within `run` blocks", so the run sets `vpc_cidr` itself. The second
run exercises the failure path. `expect_failures` "can provide a list
of checkable objects", "resources, data sources, check blocks, input
variables, and outputs", "that should fail their custom conditions",
and `var.environment` with its validation block is exactly such an
object, so the run feeds it `production` and expects the rejection:

#listing("c-os-cloud/samples/src/Ch24/network.tftest.hcl", first: 29, last: 44, caption: [the failure path: a validation block expected to reject its input])

#callout("warning", "the gate this book honestly does not run", [
  `fmt` and `validate` need no cloud account, `validate` after
  `terraform init -backend=false` installs plugins and modules while
  touching no backend. `test` is different in kind: "The Terraform
  `terraform test` command creates real infrastructure", the page
  recommends "dedicated testing accounts within the target providers
  that you can routinely and safely purge", and the escape is mocks,
  which let you test "without creating infrastructure or requiring
  credentials". This corpus stops one step earlier: the
  `.tftest.hcl` file is real, never executed, like every file under
  `Ch24/`.
])

#diagram([the no cloud gate: three commands, what each touches, what none of it touches], length: 13pt, {
  let stage(x, t1, t2) = {
    cdraw.rect((x, 5.4), (x + 6.8, 7.2), fill: luma(205), radius: 0.02)
    cdraw.content((x + 3.4, 6.6), t1, wrap: text.with(size: 6pt))
    cdraw.content((x + 3.4, 5.9), t2, wrap: text.with(size: 6pt))
  }
  stage(0.6, [terraform fmt], [-check -recursive, exit 0 or a file list])
  stage(8.4, [terraform validate], [after init -backend=false, no remote services])
  stage(16.2, [terraform test], [run blocks: plan or apply, asserts])
  cdraw.line((7.4, 6.3), (8.4, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.2, 6.3), (16.2, 6.3), stroke: luma(100), mark: (end: ">"))
  let note(x, t) = {
    cdraw.rect((x, 2.8), (x + 6.8, 4.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.4, 3.6), t, wrap: text.with(size: 6pt))
  }
  note(0.6, [pure text: no providers, no state, no apis])
  note(8.4, [plugins and modules installed, attributes and types checked])
  note(16.2, [plans or applies: real infrastructure unless mocked])
  cdraw.line((4.0, 5.4), (4.0, 4.4), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((11.8, 5.4), (11.8, 4.4), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((19.6, 5.4), (19.6, 4.4), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((11.6, 1.6), [none of it runs in this corpus, the files and the fetched pages are the whole evidence], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

sources: developer.hashicorp.com terraform pages, input variables,
variable block, output values, output block, local values, modules
overview, module block, module sources, develop modules, standard
module structure, provider requirements, backends configuration, s3
backend, workspaces language and cli pages, workspace subcommands,
fmt, validate, test, tests, mocking, and cidrsubnet, all accessed
2026-09-12. Documentation-verified only: no terraform binary in this
corpus, nothing initialized, planned, or applied. The version pins
are 1.16.2 for the cli and 6.64.0 for hashicorp/aws, chapter 23's
freeze unchanged, both Latest on the release pages at access time.
