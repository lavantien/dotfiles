#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= gcp essentials through terraform

Chapter 25 walked the aws essentials as terraform files. This chapter
walks the same ground on google cloud: the project as the resource
container, the network model, one virtual machine, one object bucket,
and one container service. The corpus rules do not move. The 7 files
under `Ch26/` are real, pinned terraform configuration and nothing ever
runs them: no terraform binary exists in this corpus, nothing is
initialized, planned, or applied. Every behavioral claim below is a
sentence quoted from a canonical page fetched 2026-09-12, or a line of
those files.

The pins come from the same discipline as chapter 23's. The cli pin is
1.16.2, released 2026-09-09. The provider pin is hashicorp/google 8.2.0:
the releases list reads v8.2.0 marked Latest, dated September 8, with
v8.1.0 on September 1 and v8.0.0 on August 26 behind it. Both release
marks were read 2026-09-12 and both are frozen in the freeze file:

#listing("c-os-cloud/samples/src/Ch26/versions.tf", first: 7, last: 21, caption: [the freeze: exact cli and provider pins, and the provider configuration the other files inherit])

The `project` and `region` arguments in the `provider` block are the
defaults the compute resources pick up. The one resource that does not
pick them up is the first one this chapter needs.

== projects and iam

Google cloud keeps every resource inside a hierarchy, and the bottom
layer of that hierarchy is the project. The resource hierarchy page
names it plainly: "The project resource is the fundamental organizing
entity." and "You need a project resource to use Google Cloud." The
tree above it is short, organization at the root, optional folders
below, and one rule binds it all: "All resources except for the highest
resource in a hierarchy have exactly one parent." Projects are where
that tree stops and the billable objects begin, virtual machines,
buckets, and the rest live inside a project, and the page's own summary
of the project is that it is "essential for creating, enabling, and
using all Google Cloud services", the thing apis, billing,
collaborators, and permissions hang from.

Authorization inside that container is role based. The iam overview
separates the two halves: "Permissions determine what operations are
allowed on a resource." and permissions are named in a grammar,
`service.resource.verb`, like `compute.instances.get`. Principals never
receive permissions one by one, the page is explicit, "You can't
directly grant permissions to a principal.", because "Roles are
collections of permissions." and granting a role grants everything in
it. The three role families round out the taxonomy. Basic roles are
"Highly permissive roles that provide broad access to Google Cloud
services", suited "for testing purposes, but shouldn't be used in
production environments". Predefined roles are
"Roles that are managed by Google Cloud services", one curated
collection per service. Custom roles are "Roles that you create that
contain only the permissions that you specify", the only kind you
author, at the cost of maintaining them.

The aws comparison from chapter 25 lands exactly here. Amazon's access
page states the model in two sentences: "You manage access in AWS by
creating policies and attaching them to IAM identities or AWS
resources. Policies are JSON documents in AWS that, when attached to an
identity or resource, define their permissions." In aws the unit of
grant is a document you write, evaluate it against the request context,
deny by default, explicit deny wins. In google cloud the unit of grant
is a name from a catalogue, you attach `roles/compute.viewer`, you do
not write it. The terraform surface mirrors the difference: chapter 25
wrote policy documents, this chapter's sample is two lines of naming.

Terraform's provider splits the gcp grant into four resources, and the
umbrella page opens with the taxonomy: "Four different resources help
you manage your IAM policy for a project." The authoritative end is
`google_project_iam_policy`, it "replaces any existing policy already
attached", and the page warns what that costs, "You can accidentally
lock yourself out of your project" with it. One step in,
`google_project_iam_binding` is "Authoritative for a given role", it
owns one role's member list and preserves every other role. The
non-authoritative end is `google_project_iam_member`, it "Updates the
IAM policy to grant a role to a new member. Other members for the role
for the project are preserved." The fourth, `audit_config`, owns audit
logging per service. The two ends cannot mix: the policy resource
"cannot be used in conjunction with" the other three "or they will
fight over what your policy should be." The sample uses the member
flavor, the one that cannot destroy a grant it never mentioned:

#listing("c-os-cloud/samples/src/Ch26/iam.tf", first: 6, last: 16, caption: [two member grants: a role from the catalogue, an identity with its type prefix, an explicit project])

Both grants name their `project` because the argument reference says
the project "is not inferred from the provider", the one argument in
this chapter that ignores the provider block. The `member` strings
carry their principal type in the prefix, `user:` for an account,
`serviceAccount:` for the machine identity the second grant builds with
string interpolation. Both roles are predefined ones, from the managed
catalogue, not the basic set.

#callout("pitfall", "authority is the dangerous axis in project iam", [
  The four flavors differ only in how much they claim to own.
  `google_project_iam_policy` replaces the whole policy and deleting it
  "removes access from anyone without organization-level access to the
  project". `google_project_iam_binding` plus `google_project_iam_member`
  on the same role is the other collision, the two fight over that
  role's member list. The member resource alone never removes anyone,
  which is why it is the flavor a book can print without a warning
  banner around it.
])

#diagram([the four project iam resources on the authority axis, what each replaces and what each preserves], length: 13pt, {
  let h(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: luma(205), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  let row(y, name, authority, preserves) = {
    cdraw.rect((0.4, y), (8.6, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.rect((9.0, y), (16.2, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.rect((16.6, y), (23.8, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((4.5, y + 0.55), name, wrap: text.with(size: 6pt))
    cdraw.content((12.6, y + 0.55), authority, wrap: text.with(size: 6pt))
    cdraw.content((20.2, y + 0.55), preserves, wrap: text.with(size: 6pt))
  }
  h(0.4, 7.1, 8.2, [resource])
  h(9.0, 7.1, 7.2, [claims ownership of])
  h(16.6, 7.1, 7.2, [preserves])
  row(5.6, [iam\_policy], [the whole policy], [nothing, replaces it])
  row(4.2, [iam\_binding], [one role, its member list], [every other role])
  row(2.8, [iam\_member], [one grant: role to member], [other members of the role])
  row(1.4, [iam\_audit\_config], [audit logging, one service], [every other service])
  cdraw.content((12.1, 0.4), [the member row is the only one that replaces nothing, the sample lives there], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the vpc model

The google network inverts the aws shape. The vpc overview fixes the
scopes in three sentences: "VPC networks, including their associated
routes and firewall rules, are global resources." and "They are not
associated with any particular region or zone." while "Subnets are
regional resources." The network object owns no address range and
belongs to no region, it is a name that spans the planet, and the
ranges arrive as subnetworks pinned to regions. Chapter 25's aws
opposite came from the vpc basics page: "A VPC spans all of the
Availability Zones in a Region." The aws network is itself regional,
the az is inside it, and "you can add one or more subnets in each
Availability Zone". In google cloud the region is inside the network
instead, one subnet per region wherever an address range is needed.

A network is born in one of two modes, and the provider argument is the
switch: `auto_create_subnetworks` set to true means the network "will
create a subnet for each region automatically across the
`10.128.0.0/9` address range", set to false it is in custom subnet
mode "so the user can explicitly connect subnetwork resources". The
sample takes custom mode and writes its own ranges:

#listing("c-os-cloud/samples/src/Ch26/network.tf", first: 5, last: 15, caption: [a global custom-mode network and one regional subnetwork owning 10.10.0.0/24])

The subnet's `ip_cidr_range` is "The range of internal addresses that
are owned by this subnetwork." with one global constraint, "Ranges must
be unique and non-overlapping within a network. Only IPv4 is
supported." The `region` argument is "The GCP region for this
subnetwork", and the resource id embeds it,
`projects/{project}/regions/{region}/subnetworks/{name}`, the regional
half of the layer stack.

Firewall is where the model is most unlike aws. The provider page
opens: "Each network has its own firewall controlling access to and
from the instances." and then the default posture, "All traffic to
instances, even from other instances, is blocked by the firewall
unless firewall rules are created to allow it." A manually created
network ships with only a default allow for outgoing traffic and a
default deny for incoming, every real rule is the tenant's to write.
Rules are network-scoped objects, `direction` defaults to `INGRESS`,
ingress rules must name a source, and `target_tags` narrows which
instances a rule touches, without it "the firewall rule applies to all
instances on the specified network." Priorities are integers from 0 to
65535, unspecified means 1000, and ties break one way, "DENY rules
take precedence over ALLOW rules having equal priority." The aws
contrast is the attachment point: "A security group controls the
traffic that is allowed to reach and leave the resources that it is
associated with", and "after you associate a security group with an
EC2 instance, it controls the inbound and outbound traffic for the
instance." The security group rides on the instance, the google rule
lives on the network and selects instances by tag.

#listing("c-os-cloud/samples/src/Ch26/network.tf", first: 17, last: 29, caption: [one ingress rule on the network: tcp 22 from the subnet range only, priority stated as the default 1000])

The rule's `source_ranges` is the subnet's own cidr, so ssh reaches the
instance only from inside the network. No instance is named anywhere
in the block, the attachment is by geography and, when needed, by tag.

#diagram([the google network as a three-layer stack against the aws shape], length: 13pt, {
  let layer(x, w, y, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((6.6, 8.2), [google cloud], wrap: text.with(size: 6.5pt, fill: luma(100)))
  layer(0.4, 12.4, 6.6, [global: the network, its routes, its firewall rules], fill: luma(205))
  layer(1.4, 10.4, 5.1, [regional: subnetworks, one cidr range each])
  layer(2.4, 8.4, 3.6, [zonal: instances, interfaces in their region's subnet])
  cdraw.line((6.6, 6.6), (6.6, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.6, 5.1), (6.6, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 2.4), [a subnet's range is regional, the firewall rules above it are not], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((19.0, 8.2), [aws, chapter 25's shape], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.rect((14.6, 6.6), (14.6 + 8.8, 7.7), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((19.0, 7.15), [regional vpc: spans the azs of one region], wrap: text.with(size: 6pt))
  cdraw.rect((15.4, 5.1), (15.4 + 7.2, 6.2), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((19.0, 5.65), [subnets, one per availability zone], wrap: text.with(size: 6pt))
  cdraw.rect((16.2, 3.6), (16.2 + 5.6, 4.7), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((19.0, 4.15), [security group rides the instance], wrap: text.with(size: 6pt))
  cdraw.content((12.5, 0.6), [solid stack: scope nests downward, dashed stack: the network itself is the regional object], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== compute engine instances

A compute engine instance is a zonal object with a named shape. The
machine types page defines the catalogue: a machine family is "a
curated set of processor and hardware configurations optimized for
specific workloads", six families from general purpose to memory
optimized to accelerator optimized, and inside a family the types come
as "machine series and predefined machine types". The name is the spec
sheet read left to right, series,
descriptor, vcpu count: "the `n2-standard-4` machine type creates a VM
with 4 vCPUs and 16 GB of memory". The sample's `e2-standard-2` is the
same grammar on the e2 series, general purpose, 2 vcpus. Small loads
can go smaller, "The E2 and N1 series contain shared-core machine
types." that timeshare a physical core, `e2-micro` up to `e2-medium`.
Off the catalogue entirely there is a formula grammar,
`custom-NUMBER_OF_CPUS-AMOUNT_OF_MEMORY_MB`, `custom-6-20480` for 6
vcpus and 20 GB, capped at "6.5 GB per CPU unless you add extended
memory". Resizing an existing instance needs `allow_stopping_for_update`,
the argument reference says so before anything else about
`machine_type`.

#listing("c-os-cloud/samples/src/Ch26/compute.tf", first: 7, last: 29, caption: [one zonal instance: family-name shape, image by family shorthand, interface in the custom subnet, boot script in metadata])

The `zone` argument places the instance in one zone of the subnet's
region, and the placement is checked, the interface's subnetwork "must
exist in the same region this instance will be created in", and with a
custom-mode network "specifying the subnetwork is required." The boot
disk takes the image by project and family, `debian-cloud/debian-11`,
a living pointer that resolves to the current image of that family
rather than a frozen id. There is no `access_config` block in the
interface, and the provider page states what that omission buys:
"Omit to ensure that the instance is not accessible from the
Internet."

The startup script is the instance's boot-time behavior. The compute
docs define it: "A startup script is a file that contains commands that
run when a virtual machine (VM) instance boots." and the delivery
mechanism is metadata, "A startup script is passed to a VM from a
location that is specified by a metadata key." The `startup-script`
key carries a script stored locally or added directly, up to 256 KB,
`startup-script-url` points at Cloud Storage for bigger ones, and the
guest environment reads the key and runs the script as root when the
machine boots. The provider offers the same script through two
different arguments. Inside `metadata`, the key runs "in a shell on
every boot" and changing it changes nothing terraform tracks. The
dedicated `metadata_startup_script` argument is the other polarity:
"An alternative to using the startup-script metadata key, except this
one forces the instance to be recreated (thus re-running the script) if
it is changed." The sample uses the second one on purpose, a changed
script should read as a new machine.

The ec2 counterpart is chapter 25's user data, and the polarity is
flipped. The ec2 page: "you can pass user data to the instance that is
used to perform automated configuration tasks, or to run scripts after
the instance starts", and "By default, user data scripts and
cloud-init directives run only during the boot cycle when you first
launch your instance", every-boot needs an explicit persist tag. Google
cloud runs the startup script on every boot by default. The ec2 side
also treats the payload as uninterpreted bytes, "User data is treated
as opaque data: what you give is what you get back.", base64 encoded
at the api, capped at 16 KB. The google side puts the script in a
queryable metadata server and lets terraform hash it into the resource
identity.

#callout("note", "two spellings of one script, only one is tracked", [
  `metadata_startup_script` and `metadata.startup-script` are the same
  bytes to the guest environment and different resources to terraform.
  The metadata map version can drift silently, edit it and the plan
  stays empty while the next boot runs new code. The dedicated argument
  turns that edit into a destroy and recreate, which is the honest
  representation: a machine that booted different code is a different
  machine. The two cannot be used simultaneously on the same instance.
])

#diagram([the boot pipeline: image to disk to interface to metadata to script], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 4.6, 3.4, [image family, #linebreak() debian-cloud/debian-11])
  box(4.8, 4.6, 3.4, [boot disk, #linebreak() initialize\_params])
  box(9.2, 4.6, 3.4, [interface, #linebreak() regional subnet])
  box(13.6, 4.6, 3.4, [guest agent, #linebreak() reads metadata])
  box(18.0, 4.6, 3.6, [startup script, #linebreak() root, every boot])
  box(22.4, 4.6, 2.6, [serving])
  cdraw.line((3.8, 5.1), (4.8, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.2, 5.1), (9.2, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.6, 5.1), (13.6, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 5.1), (18.0, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((21.6, 5.1), (22.4, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.5, 3.4), [the shape is fixed before boot: e2-standard-2, zone us-central1-a, no internet address], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((12.5, 2.4), [aws runs the same pipeline with user data, once by default instead of every boot], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== cloud storage buckets

The object store has one container type. The storage docs say it
twice: "Buckets are the basic containers that hold your data as
objects." and "Everything that you store in Cloud Storage must be
contained in a bucket." The namespace above the containers is flat and
shared with the whole world, "Every bucket name must be globally
unique", lowercase, 3 to 63 characters. The provider's argument
reference adds the two structural ones, `name` and `location`, the
location being a region, a dual region, or a multi-region like the
sample's `US`.

#listing("c-os-cloud/samples/src/Ch26/storage.tf", first: 6, last: 26, caption: [one bucket: unique name, multi-region location, inherited class, uniform access, one transition rule])

The storage class is a property of objects that the bucket defaults.
The classes page: "When you add objects to the bucket, they inherit
this storage class unless explicitly set otherwise." The ladder has
four rungs, each a price for an access cadence. Standard for
frequently accessed data. Nearline "is ideal for data you plan to read
or modify on average once per month or less", with a 30-day minimum
storage duration. Coldline for data read "at most once a quarter",
90-day minimum. Archive, "the best choice for data that you plan to
access less than once a year", 365-day minimum. The provider accepts
`STANDARD`, `NEARLINE`, `COLDLINE`, `ARCHIVE` and the legacy
`MULTI_REGIONAL` and `REGIONAL` spellings, and its lifecycle rules
move objects between rungs, the sample's single rule sets
`SetStorageClass` to `NEARLINE` when `age` reaches 30 days.

Uniform bucket-level access is the switch that collapses the access
model. The docs state the effect first: "When you enable uniform
bucket-level access on a bucket, Access Control Lists (ACLs) are
disabled", and from then on only bucket-level iam permissions grant
access. The switch has a ratchet, "Uniform bucket-level access cannot
be disabled after it has been active on a bucket for 90 consecutive
days." The sample turns it on in the same breath as the class, one
line, the bucket never speaks acl again.

The s3 comparison closes the table. Amazon's page: "Each object in
Amazon S3 has a storage class associated with it." The class is object
metadata, per object, with the bucket holding only a default. The
minimum-duration ladders sit side by side: aws charges 30 days for
Standard-IA, 90 for Glacier Instant and Flexible, 180 for Deep
Archive, google charges 30 for Nearline, 90 for Coldline, 365 for
Archive. Google's coldest rung is twice as deep in time, amazon's
coldest asks for an explicit restore before read. Both clouds put the
transition engine in lifecycle rules and both default new objects to
the hot class when nothing is said.

#callout("warning", "uniform access is a one-way latch with a 90-day fuse", [
  Enabling `uniform_bucket_level_access` is cheap and reversible for
  89 days. On day 90 of continuous operation it is permanent, any acl
  that still matters is dead weight the bucket can no longer read, and
  no later terraform run can undo the argument. Treat it as a
  migration, finish moving grants to iam before the fuse burns, not
  after.
])

#diagram([the bucket as a data structure: fields, inheriting objects, and the class ladder], length: 13pt, {
  cdraw.rect((0.4, 1.2), (10.6, 7.6), fill: luma(240), radius: 0.03, stroke: luma(120))
  cdraw.content((5.5, 6.9), [bucket], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((5.5, 6.15), [name, globally unique], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 5.4), [location, US multi-region], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 4.65), [storage\_class, the default], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.9), [uniform\_bucket\_level\_access], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.15), [lifecycle\_rule: age 30 to nearline], wrap: text.with(size: 6pt))
  for i in range(4) {
    cdraw.rect((1.0 + i * 2.3, 1.6), (3.0 + i * 2.3, 2.5), fill: luma(220), radius: 0.02)
  }
  cdraw.content((5.5, 0.75), [objects inherit the class, no per-object say unless they take it], wrap: text.with(size: 6.5pt, fill: luma(100)))
  let rung(y, t, d) = {
    cdraw.rect((12.0, y), (16.4, y + 1.6), fill: luma(235), radius: 0.02)
    cdraw.content((14.2, y + 1.15), t, wrap: text.with(size: 6pt))
    cdraw.content((14.2, y + 0.45), d, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  rung(6.2, [STANDARD], [no minimum])
  rung(4.2, [NEARLINE], [30-day minimum])
  rung(2.2, [COLDLINE], [90-day minimum])
  rung(0.2, [ARCHIVE], [365-day minimum])
  cdraw.line((14.2, 6.2), (14.2, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.2, 4.2), (14.2, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.2, 2.2), (14.2, 1.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.6, 4.6), [lifecycle rules walk objects down, #linebreak() the sample's rule fires at age 30], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((18.6, 7.15), [aws: class is per-object metadata, #linebreak() mins 30/90/90/180], wrap: text.with(size: 6.5pt))
})

== cloud run

The last resource is the serverless one, and it is container native:
the deploy unit is an image, not a function. The provider page states
the abstraction: "Service acts as a top-level container that manages a
set of configurations and revision templates which implement a network
service." Deploys do not overwrite anything, `template` is "The
template used to create revisions for this Service", each new template
stamps out a new revision, and `revision` names it, "The unique name
for the revision", generated from the service name when omitted.

#listing("c-os-cloud/samples/src/Ch26/run.tf", first: 6, last: 19, caption: [the service, the deletion-protection override, and a named revision with scaling bounds])

The `deletion_protection` line is not decoration. The provider
defaults it to true, "Whether Terraform will be prevented from
destroying the service. Defaults to true.", any apply that would delete
the service fails until the argument says false. A book that never
applies still says false, the file should mean what it says.

#listing("c-os-cloud/samples/src/Ch26/run.tf", first: 21, last: 31, caption: [the container: one image from the doc's own example registry, cpu and memory as limits])

Traffic is a list of allocations. The provider's `traffic` argument
"Specifies how to distribute traffic over a collection of Revisions
belonging to the Service", and the default when the list is empty is
"100% traffic to the latest Ready Revision". The console docs put the
same knob to work for rollback, gradual rollout, and splitting, with
one arithmetic rule, "the percentages must add up to 100", and one
testing affordance, a tag "lets you directly test the new revision at
a specific URL, without serving traffic". The sample splits 90 to the
revision its template names and 10 to the previous one:

#listing("c-os-cloud/samples/src/Ch26/run.tf", first: 33, last: 44, caption: [the 90/10 split: allocation by revision name, percents summing to 100])

Scaling is bounded at both ends and the bounds are asymmetric.
Quiescence is free: "When a revision does not receive any traffic, by
default, it is scaled to zero instances." The minimum instances
setting buys back latency by keeping an instance idle, warm, and
billed even with no requests. The top end always exists, "All services
are assigned a maximum instances limit by default, even if you don't
specify your own limit", and the limit "is an upper limit per
revision". In the provider the bounds live in the template's
`scaling` block, `min_instance_count` "Defaults to 0", and an absent
`max_instance_count` sends cloud run to "calculate a default value
based on the project's available container instances quota in the
region and specified instance size." The sample pins both, 0 and 5,
so the state machine is fully determined by the file.

#diagram([the revision lifecycle as a state machine, with the scaling axis under every serving state], length: 13pt, {
  let st(x, y, w, t, h: 1.1) = {
    cdraw.rect((x, y), (x + w, y + h), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  st(0.4, 6.4, 4.2, [template edited])
  st(6.4, 6.4, 4.8, [new revision, #linebreak() 0 percent traffic])
  st(13.0, 6.4, 4.8, [split 90/10, #linebreak() tag may test first])
  st(19.8, 6.4, 4.6, [latest ready, #linebreak() 100 percent])
  cdraw.line((4.6, 6.95), (6.4, 6.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.2, 6.95), (13.0, 6.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.8, 6.95), (19.8, 6.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((21.0, 7.5), (21.0, 8.05), (15.4, 8.05), (15.4, 7.5), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.content((18.9, 5.7), [rollback re-points traffic #linebreak() at a named older revision], wrap: text.with(size: 6.5pt, fill: luma(100)))
  st(6.4, 3.4, 4.8, [0 instances, #linebreak() scaled to zero], h: 1.4)
  st(13.0, 3.4, 4.8, [1 to max instances, #linebreak() by concurrency and cpu], h: 1.4)
  cdraw.line((8.8, 6.4), (8.8, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.0, 6.4), (14.0, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.2, 4.15), (13.0, 4.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.0, 3.75), (11.2, 3.75), stroke: luma(140), mark: (end: ">"))
  cdraw.content((10.6, 2.6), [min 0 warm, max 5, the bounds the template pins], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.6, 1.6), [a revision with no traffic costs nothing, the warm floor is the only always-on line on the bill], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

sources: hashicorp/terraform-provider-google v8.2.0 resource pages,
`google_project_iam` (umbrella page, `google_project_iam_member`
documented there), `google_compute_network`, `google_compute_subnetwork`,
`google_compute_firewall`, `google_compute_instance`,
`google_storage_bucket`, `google_cloud_run_v2_service`, fetched from
the raw.githubusercontent.com pinned tag, and docs.cloud.google.com
iam overview, resource hierarchy, vpc overview, machine types, startup
scripts (overview and linux pages), buckets, storage classes, uniform
bucket-level access, cloud run rollouts rollbacks and traffic
migration, and instance autoscaling, all accessed 2026-09-12.
docs.aws.amazon.com iam access management, vpc basics, security
groups, ec2 user data, and s3 storage classes, accessed 2026-09-12,
and github.com hashicorp/terraform-provider-google releases, accessed
2026-09-12. Documentation-verified only: no terraform binary in this
corpus, nothing initialized, planned, or applied. The version pins are
1.16.2 for the cli and 8.2.0 for hashicorp/google, both Latest on
their release pages at access time, the provider published 2026-09-08.
