#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= aws essentials through terraform

Chapter 23 read the language and chapter 24 composed modules. This chapter
builds the smallest honest slice of one provider: one role, one network, one
instance, one bucket, one function, in seven files under `Ch25/`. The
verification mode stays the one chapters 23 and 24 set: the files are real,
pinned terraform and nothing ever runs them, no terraform binary exists in
this corpus, nothing is initialized, planned, or applied. Every behavioral
sentence below is quoted from the provider documentation at tag v6.64.0 or
the AWS service documentation, all fetched 2026-09-12, and the resource
argument names are read from those pages, not remembered from training
data. Two provider habits drove the sample's shape before a line was
written: the role's `inline_policy` and `managed_policy_arns` arguments and
the security group's inline `ingress` and `egress` arguments are deprecated
on the pages that define them, and the S3 bucket shed its versioning and
encryption arguments into separate resources. The sample uses the shapes
the pages recommend.

== iam: users, roles, and the boundary of trust

The IAM guide fixes the two identity kinds in two sentences. A role is "an
IAM identity that you can create in your account that has specific
permissions", and where a user is "uniquely associated with one person, a
role is intended to be assumable by anyone who needs it". The credential
model is the real divide: "a role does not have standard long-term
credentials such as a password or access keys associated with it. Instead,
when you assume a role, it provides you with temporary security
credentials for your role session." The guide's advice for users is to
avoid them: "We recommend you only use IAM users for use cases not
supported by identity federation." The best practices page states what a
workload gets instead: "When you're building on an AWS compute service,
such as Amazon EC2 or Lambda, AWS delivers the temporary credentials of an
IAM role to that compute resource."

Delegation is the model that ties the two policy kinds together. To
delegate, "you create an IAM role in the trusting account that has two
policies attached. The permissions policy grants the user of the role the
needed permissions to carry out the intended tasks on the resource. The
trust policy specifies which trusted account members are allowed to assume
the role." The trust policy is defined precisely: "A JSON policy document
in which you define the principals that you trust to assume the role. A
role trust policy is a required resource-based policy that is attached to
a role in IAM." The provider resource mirrors that structure with one
required argument: `assume_role_policy` is "Policy that grants an entity
permission to assume the role", and the page suggests building it with
`jsonencode()` or the `aws_iam_policy_document` data source. The sample
takes the data source route:

#listing("c-os-cloud/samples/src/Ch25/iam.tf", first: 9, last: 24, caption: [the trust half: a service principal, one action, wired into the role's one required argument])

The trust statement names the `ec2.amazonaws.com` service principal and
grants exactly one action, `sts:AssumeRole`. The instance profile below it
is the delivery vehicle for EC2: the instance resource takes
`iam_instance_profile` as "the name of the Instance Profile", and the
profile carries the role. The permission half follows the best practices
page verbatim: "grant only the permissions required to perform a task. You
do this by defining the actions that can be taken on specific resources
under specific conditions, also known as least-privilege permissions."

#listing("c-os-cloud/samples/src/Ch25/iam.tf", first: 31, last: 49, caption: [the permission half: two actions, one bucket arn, no wildcard])

The `resources` list is the whole discipline in one expression: the bucket
arn and the bucket arn with `/*`, nothing else. The policy document lives
in an `aws_iam_role_policy` resource, whose `policy` argument is "The
inline policy document. This is a JSON formatted string", and whose `role`
argument is "The name of the IAM role to attach to the policy". This
separate resource is not a style choice. The role page marks the in-body
alternatives deprecated and warns what exclusive management would cost:
configuring `inline_policy` or `managed_policy_arns` on `aws_iam_role`
"will take over exclusive management of the role's respective policy
types", which "are incompatible with other ways of managing a role's
policies" and end in "resource cycling and/or errors". The lambda section
uses the other recommended carrier, `aws_iam_role_policy_attachment`, for
a managed policy.

#callout("pitfall", "least privilege is a resource list, not a feeling", [
  The lazy pattern writes `Resource = "*"`, the wildcard. The page's own
  definition refuses that shortcut: permissions are "the actions that can
  be taken on specific resources under specific conditions". In the sample
  the statement names two actions and one bucket, the one bucket this
  chapter creates, so the role can read the uploads and nothing else.
  Widening it is a one-line diff in one file, visible in every plan
  review, which is the point.
])

#diagram([iam in one view: the two identity kinds, and the two-policy anatomy every role carries], length: 13pt, {
  let box(x, y, w, h, lines, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    for (i, t) in lines.enumerate() {
      cdraw.content((x + w / 2, y + h - 0.55 - i * 0.65), t, wrap: text.with(size: 6pt))
    }
  }
  cdraw.content((4.0, 8.9), [iam user], wrap: text.with(size: 6.5pt))
  cdraw.content((12.8, 8.9), [iam role], wrap: text.with(size: 6.5pt))
  cdraw.content((20.4, 8.9), [the sample's role], wrap: text.with(size: 6.5pt))
  box(0.8, 4.4, 6.4, 2.9, ([one person or workload], [long-term access keys], [where federation fails]))
  box(9.6, 4.4, 6.4, 2.9, ([assumable by anyone], [who needs it], [temporary credentials]))
  box(17.0, 6.5, 6.8, 2.0, ([trust: who may assume], [principal ec2.amazonaws.com]), fill: luma(215))
  box(17.0, 3.5, 6.8, 2.9, ([permissions: what it may do], [s3:GetObject, s3:ListBucket,], [one bucket, no wildcard]), fill: luma(215))
  cdraw.line((16.0, 6.6), (17.0, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, 5.3), (17.0, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.2, 5.35), (9.6, 5.35), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((8.4, 6.35), [similar,], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((8.4, 5.8), [no keys], wrap: text.with(size: 6pt, fill: luma(100)))
  box(0.8, 0.8, 9.4, 1.5, ([aws\_iam\_role\_policy: inline, this section],))
  box(11.4, 0.8, 13.0, 1.5, ([aws\_iam\_role\_policy\_attachment: managed, the lambda section],))
  cdraw.content((12.6, 0.1), [both replace the role's deprecated inline\_policy and managed\_policy\_arns arguments], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== vpc: cidrs, subnets, route tables, firewalls

A VPC is "a logically isolated virtual network that you've defined" that
"closely resembles a traditional network that you'd operate in your own
data center". The address plan starts with CIDR notation, and the VPC
addressing page works the arithmetic: "10.0.0.0/16 represents 65,536 IPv4
addresses from 10.0.0.0 to 10.0.255.255". The sample spends that budget
one zone at a time: a /24 per subnet, 256 addresses each, 10.0.0.0/24 in
one zone and 10.0.1.0/24 in the other, out of the /16 the VPC holds.

The zone assignment is structural, not cosmetic: "Each subnet must reside
entirely within one Availability Zone and cannot span zones", and the page
gives the reason: "By launching AWS resources in separate Availability
Zones, you can protect your applications from the failure of a single
Availability Zone." Chapter 22 carries the caveat that zone codes are
per-account names for accounts created before November 2025, so
`${var.region}a` and `${var.region}b` name zones by code, which is the
convention the provider's `availability_zone` argument, "AZ for the
subnet", is written around.

#listing("c-os-cloud/samples/src/Ch25/vpc.tf", first: 7, last: 14, caption: [the vpc: one cidr_block argument, the /16 the whole network carves from])

#listing("c-os-cloud/samples/src/Ch25/vpc.tf", first: 15, last: 34, caption: [the two subnets: one cidr carved per zone, public ip on launch only in the public one])

What makes a subnet public or private is nothing in the subnet itself:
"The subnet type is determined by how you configure routing for your
subnets." A public subnet "has a direct route to an internet gateway", a
private one does not. The routing page defines the object that decides:
"A route table serves as the traffic controller for your virtual private
cloud (VPC). Each route table contains a set of rules, called routes, that
determine where network traffic from your subnet or gateway is directed."
Every VPC starts with one: "When you create a VPC, we also create the main
route table for the VPC", and "Every subnet that you create is
automatically associated with the main route table for the VPC." The
provider exposes that default as an attribute, `default_route_table_id`,
"ID of the route table created by default on VPC creation", and the sample
declines to edit it, building two named tables instead and associating
each subnet explicitly:

#listing("c-os-cloud/samples/src/Ch25/vpc.tf", first: 44, last: 60, caption: [the public route table: the default route to the internet gateway, and the association that binds the public subnet to it])

The public table carries one route, 0.0.0.0/0 to the internet gateway.
The private table, lines 62 through 73 of the same file, carries none:
the AWS-created local route for the VPC range is not something the
configuration has to state, and no destination outside the VPC is
reachable from that subnet.

The firewall layer is the security group: it "controls the traffic that is
allowed to reach and leave the resources that it is associated with" and
"acts as a virtual firewall". Its statefulness is the property to
internalize: "Security groups are stateful. For example, if you send a
request from an instance, the response traffic for that request is allowed
to reach the instance regardless of the inbound security group rules.
Responses to allowed inbound traffic are allowed to leave the instance,
regardless of the outbound rules." The subnet-level counterpart is
stateless and open by default: "Network ACLs allow or deny inbound and
outbound traffic at the subnet level", and "The default network ACL allows
all inbound and outbound traffic."

#listing("c-os-cloud/samples/src/Ch25/vpc.tf", first: 75, last: 97, caption: [the security group and its rules as separate resources: one ingress, one egress, one cidr each])

The rules live outside the group on purpose. The group page says to
"avoid" the inline `ingress` and `egress` arguments and "use the current
best practice of the `aws_vpc_security_group_egress_rule` and
`aws_vpc_security_group_ingress_rule` resources with one CIDR block per
rule". One more provider fact shapes the pair: "By default, AWS creates an
`ALLOW ALL` egress rule when creating a new Security Group inside of a
VPC", and "Terraform will remove this default rule", so the egress rule in
the listing is not paranoia, it is the re-creation the removal requires.
The ingress rule names `ip_protocol = "tcp"`, ports 443 through 443, and
the VPC's own CIDR as the source. The egress rule uses `-1`, which the
rule page defines as all protocols.

#callout("note", "the main route table is a default you inherit", [
  Every subnet lands in the main route table without being asked. The
  sample's two explicit `aws_route_table_association` resources exist so
  that no subnet's routing is implied: the day someone edits the main
  table to add a default route, subnets that were private by accident of
  association would follow it. Explicit tables plus explicit associations
  make the network's shape a fact of the configuration, not of the order
  resources happened to be created in.
])

#diagram([the sample's network in one stack: vpc, two zones, two route tables, one stateful firewall], length: 13pt, {
  cdraw.rect((0.6, 0.8), (15.0, 9.0), stroke: luma(100), radius: 0.05)
  cdraw.content((11.0, 8.55), [vpc main, 10.0.0.0/16], wrap: text.with(size: 6pt))
  cdraw.rect((1.6, 7.5), (6.0, 8.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 8.0), [internet gateway], wrap: text.with(size: 6pt))
  cdraw.line((3.8, 7.5), (3.8, 7.1), stroke: luma(100), mark: (end: ">"))
  let inner(x, y, w, lines) = {
    cdraw.rect((x, y), (x + w, y + 2.6), fill: luma(215), radius: 0.02)
    for (i, t) in lines.enumerate() {
      cdraw.content((x + w / 2, y + 2.05 - i * 0.65), t, wrap: text.with(size: 6pt))
    }
  }
  inner(1.6, 5.2, 6.0, ([route table public], [0.0.0.0/0 to the igw], [associates zone a]))
  inner(9.0, 5.2, 5.0, ([route table private], [no routes of its own], [associates zone b]))
  inner(1.6, 2.2, 6.0, ([subnet public], [10.0.0.0/24, zone a], [public ip on launch]))
  inner(9.0, 2.2, 5.0, ([subnet private], [10.0.1.0/24, zone b], [no auto public ip]))
  cdraw.line((4.6, 4.8), (4.6, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.5, 4.8), (11.5, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((1.6, 0.9), (15.0, 2.0), fill: luma(205), radius: 0.02)
  cdraw.content((8.3, 1.75), [security group web, stateful, at the instance], wrap: text.with(size: 6pt))
  cdraw.content((8.3, 1.2), [https in from 10.0.0.0/16, everything out], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 7.6), [subnets never span zones,], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 7.05), [so two zones cost two subnets], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 5.6), [network acls: subnet level,], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 5.05), [stateless, default allow], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 3.6), [security groups filter], wrap: text.with(size: 6pt))
  cdraw.content((19.0, 3.05), [at the instance, stateful], wrap: text.with(size: 6pt))
  cdraw.content((8.5, 0.25), [public is a routing fact: the igw route makes zone a public,], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((8.5, -0.45), [its absence makes zone b private], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== ec2: one instance, end to end

The instance resource is where the previous two sections meet, and its
first argument is the one with the strongest pinning story. "An Amazon
Machine Image (AMI) is an image that provides the software that is
required to set up and boot an Amazon EC2 instance", and "You must specify
an AMI when you launch an instance." The page then lists what an AMI is
specific to: region, operating system, processor architecture, root volume
type, virtualization type. Region is first: an AMI id names an image in
one region, which is why the sample takes it from a variable with no
default instead of baking a literal into the file.

The provider accepts three spellings for that argument, and its own
examples show all three:

#snippet("ami = \"ami-0aaaaaaaaaaaaaaa1\"\n\nami = data.aws_ami.ubuntu.id        # most_recent = true\n\nami = \"resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64\"\n", lang: "tf")

A literal id is a pin, visible in every plan. The data source with
`most_recent = true` follows the newest match, which means the instance's
image can change under a configuration that did not. The `resolve:ssm:`
alias names an image by public parameter, which the provider resolves at
apply time. The sample takes the first form through a variable, the same
shape chapter 23 used, so the pin is the caller's decision and the file
records it. The shape argument decodes by rule: "Instance types are named
based on their instance family and instance size", the first family
position is the series, the second the generation, the third the options,
and "After the period (`.`) is the instance size". The table lists T as
burstable performance, so `t3.micro` reads as third-generation burstable,
micro size.

#listing("c-os-cloud/samples/src/Ch25/ec2.tf", first: 7, last: 23, caption: [the instance: pinned ami, decoded shape, subnet placement, profile, group, and opaque user data])

Every argument but the first two is a reference into the earlier files:
`subnet_id` picks the zone, `vpc_security_group_ids` is "List of security
group IDs to associate with", `iam_instance_profile` carries the role from
the iam section by profile name. User data is the launch-time channel:
with it you "perform automated configuration tasks, or to run scripts
after the instance starts", and the contract is deliberately loose,
because "User data is treated as opaque data: what you give is what you
get back. It is up to the instance to interpret it." The raw payload is
bounded: "User data is limited to 16 KB, in raw form, before it is
base64-encoded."

The lifecycle rules come from the argument docs, and they differ by field.
An `instance_type` change "will trigger a stop/start of the EC2 instance",
and so will a `user_data` change "by default". The sample sets
`user_data_replace_on_change`, which "will trigger a destroy and recreate
of the EC2 instance when set to `true`", turning a script edit into
replacement, the honest semantics for a field that only runs at boot.
After launch the resource reports back `id`, `public_ip`, and
`instance_state`, whose values the provider page enumerates as pending,
running, shutting-down, terminated, stopping, or stopped.

#diagram([the instance resource as a junction: six inputs on the left, one resource, the reported attributes on the right], length: 13pt, {
  let small(x, y, t) = {
    cdraw.rect((x, y), (x + 7.2, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.6, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  small(0.4, 7.4, [var.ami, caller-pinned])
  small(0.4, 6.1, [var.instance\_type, t3.micro])
  small(0.4, 4.8, [aws\_subnet.public.id])
  small(0.4, 3.5, [aws\_security\_group.web.id])
  small(0.4, 2.2, [aws\_iam\_instance\_profile.web])
  small(0.4, 0.9, [user\_data, a 3-line script])
  cdraw.rect((10.4, 3.8), (17.0, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((13.7, 6.05), [aws\_instance.web], wrap: text.with(size: 6pt))
  cdraw.content((13.7, 5.4), [six references,], wrap: text.with(size: 6pt))
  cdraw.content((13.7, 4.75), [zero local computation], wrap: text.with(size: 6pt))
  cdraw.line((7.6, 7.9), (10.4, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.6, 6.6), (10.4, 5.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.6, 5.3), (10.4, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.6, 4.0), (10.4, 4.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.6, 2.7), (10.4, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.6, 1.4), (10.4, 4.05), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.4, 6.2), (23.6, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((21.0, 7.85), [reported back:], wrap: text.with(size: 6pt))
  cdraw.content((21.0, 7.2), [id, public\_ip, state], wrap: text.with(size: 6pt))
  cdraw.line((17.0, 6.4), (18.4, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.4, 3.4), (24.6, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((21.5, 5.05), [edits stop and start:], wrap: text.with(size: 6pt))
  cdraw.content((21.5, 4.4), [instance\_type, user\_data], wrap: text.with(size: 6pt))
  cdraw.line((17.0, 4.4), (18.4, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((21.5, 2.5), [replace\_on\_change turns], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((21.5, 1.95), [a script edit into replacement], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((12.0, 0.2), [every argument is a reference: the resource is where they meet], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== s3: the object model against the block model

The EC2 chapter's root volume is a block device. S3 is the other model:
"Amazon S3 is an object storage service that stores data as objects,
hierarchical data, or tabular data within buckets. An object is a file and
any metadata that describes the file. A bucket is a container for
objects." The address of an object is its name, nothing else: "Each object
has a key (or key name), which is the unique identifier for the object
within the bucket." There are no offsets and no filesystem geometry, and
reads are consistent: "Amazon S3 provides strong read-after-write
consistency for PUT and DELETE requests of objects in your Amazon S3
bucket in all AWS Regions."

The name of the container is itself a managed resource, because general
purpose buckets "exist in a global namespace, which means that each bucket
name must be unique across all AWS accounts in all the AWS Regions within
a partition". The character rules are short: names "must be between 3
(min) and 63 (max) characters long", "can consist only of lowercase
letters, numbers, periods (.), and hyphens (-)", and "must begin and end
with a letter or number". The sample encodes those rules as a validation
block on the input, so a bad name fails at plan time rather than at the
API:

#listing("c-os-cloud/samples/src/Ch25/variables.tf", first: 18, last: 26, caption: [the naming rules as a validation block: the character set, the bounds, the first and last character])

The provider's bucket resource has narrowed to the name plus housekeeping.
Its `versioning` and `server_side_encryption_configuration` arguments are
marked deprecated with pointers to the split resources, and the sample
follows the pointers:

#listing("c-os-cloud/samples/src/Ch25/s3.tf", first: 8, last: 22, caption: [the bucket and its versioning resource: one name argument, one status])

Versioning is off unless asked: "By default, S3 Versioning is disabled on
buckets, and you must explicitly enable it." Once on, it changes the
delete and overwrite semantics: "if you delete an object, Amazon S3
inserts a delete marker instead of removing the object permanently", and
an overwrite "results in a new object version in the bucket". The state
machine only runs one way: "After you version-enable a bucket, it can
never return to an unversioned state", only suspend. And the cost model
is blunt: "Each version of an object is the entire object; it is not just
a diff from the previous version." The provider page adds one operational
warning with a clock in it: "AWS recommends that you wait for 15 minutes
after enabling versioning before issuing write operations (PUT or DELETE)
on objects in the bucket."

#listing("c-os-cloud/samples/src/Ch25/s3.tf", first: 24, last: 32, caption: [the encryption resource: AES256 written down, the algorithm the service already applies by default])

Encryption is the one place the configuration states a default. The
service page: "Amazon S3 now applies server-side encryption with Amazon
S3 managed keys (SSE-S3) as the base level of encryption for every bucket
in Amazon S3", and "Starting January 5, 2023, all new object uploads to
Amazon S3 are automatically encrypted at no additional cost and with no
impact on performance." The FAQ closes the exit: "You can no longer
disable encryption for new object uploads." So the resource's `AES256`,
one of the three `sse_algorithm` values the page lists alongside
`aws:kms` and `aws:kms:dsse`, records the default rather than creating
one. The provider note matters for teardown: "Destroying an
`aws_s3_bucket_server_side_encryption_configuration` resource resets the
bucket to Amazon S3 bucket default encryption."

#callout("pitfall", "a deleted bucket name can be inherited", [
  The global namespace is a queue with no lock. After a bucket is
  deleted, "another AWS account in the same partition can use the same
  bucket name for a new bucket and can therefore potentially receive
  requests intended for the deleted bucket." A name retired by destroy is
  not a name reserved. The sample takes the name from a variable, the
  same as the ami, so the choice is deliberate and reviewable, and the
  naming rules are enforced before any request leaves the plan.
])

#diagram([the same bytes in two shapes: blocks at fixed offsets on the left, keys and whole-object versions on the right], length: 13pt, {
  cdraw.content((4.4, 8.5), [block storage, the ec2 root volume], wrap: text.with(size: 6.5pt))
  for i in range(5) {
    cdraw.rect((0.8 + i * 1.5, 6.9), (2.1 + i * 1.5, 8.1), fill: luma(235), radius: 0.02)
    cdraw.content((1.45 + i * 1.5, 7.5), str(i), wrap: text.with(size: 6pt))
  }
  cdraw.content((4.4, 6.15), [a file is split into blocks], wrap: text.with(size: 6pt))
  cdraw.content((4.4, 5.55), [at fixed offsets, by the volume], wrap: text.with(size: 6pt))
  cdraw.content((4.4, 3.9), [no name survives the split:], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((4.4, 3.3), [addressing is offset plus length], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((17.2, 8.5), [object storage, the s3 bucket], wrap: text.with(size: 6.5pt))
  cdraw.rect((11.2, 4.2), (22.6, 8.1), stroke: luma(100), radius: 0.05)
  cdraw.content((13.4, 7.9), [bucket uploads], wrap: text.with(size: 6pt))
  cdraw.rect((11.8, 6.7), (16.6, 7.7), fill: luma(245), radius: 0.02)
  cdraw.content((14.2, 7.2), [version 1, oldest], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.rect((11.8, 5.5), (16.6, 6.5), fill: luma(215), radius: 0.02)
  cdraw.content((14.2, 6.0), [version 2, current], wrap: text.with(size: 6pt))
  cdraw.rect((11.8, 4.3), (16.6, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((14.2, 4.8), [reports/june], wrap: text.with(size: 6pt))
  cdraw.rect((17.4, 5.5), (22.2, 6.5), fill: luma(215), radius: 0.02)
  cdraw.content((19.8, 6.0), [one version, current], wrap: text.with(size: 6pt))
  cdraw.rect((17.4, 4.3), (22.2, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((19.8, 4.8), [reports/july], wrap: text.with(size: 6pt))
  cdraw.content((17.2, 3.5), [the key is the whole address,], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((17.2, 2.9), [each version is a whole object], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 1.9), [strong read-after-write consistency for PUT and DELETE, in every region], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.5, 1.15), [a delete inserts a marker, and versioning never un-enables], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== lambda: the execution role and the cold start

The last resource is the smallest and the one with the strangest runtime
model. Its identity is an IAM role again, but a different one: "A Lambda
function's execution role is an AWS Identity and Access Management (IAM)
role that grants the function permission to access AWS services and
resources." The provider's `aws_lambda_function` makes the same statement
from the configuration side: the `role` argument is the "ARN of the
function's execution role. The role provides the function's identity and
access to AWS services and resources." The assume happens without your
code: "Lambda automatically assumes your execution role when you invoke
your function", and the trust policy has one hard requirement: "In order
for Lambda to properly assume your execution role, the role's trust policy
must specify the Lambda service principal (`lambda.amazonaws.com`) as a
trusted service."

#listing("c-os-cloud/samples/src/Ch25/lambda.tf", first: 8, last: 28, caption: [the execution role: same trust shape as the ec2 role, different principal, and a managed policy through the attachment resource])

The permission half rides an AWS managed policy this time.
`AWSLambdaBasicExecutionRole` is the one the console uses by default,
giving "basic permissions to log events to Amazon CloudWatch Logs", and
its policy document grants exactly three actions, `logs:CreateLogGroup`,
`logs:CreateLogStream`, and `logs:PutLogEvents`. It attaches through
`aws_iam_role_policy_attachment`, whose two required arguments are the
role name and the policy arn, the resource the role page recommends over
its deprecated `managed_policy_arns` argument.

#listing("c-os-cloud/samples/src/Ch25/lambda.tf", first: 30, last: 48, caption: [the function: pinned runtime, one handler, the documented defaults for memory and timeout written out])

The handler is the entry point: "The Lambda function handler is the method
in your function code that processes events. When your function is
invoked, Lambda runs the handler method. Your function runs until the
handler returns a response, exits, or times out." `index.handler` names
the file and the exported method. The runtime is pinned like everything
else in this book, and the runtimes page makes pinning a scheduling
problem: nodejs 24 is `nodejs24.x`, deprecated April 30, 2028, with
function creation blocked June 1, 2028 and updates blocked July 1, 2028,
while "After a runtime is deprecated, you're still able to create and
update functions for a limited period." The newer `nodejs26.x` is public
preview, and the page is direct about that state: "Preview runtimes are
not covered by the Lambda SLA or Technical Support, and should not be
used for production workloads." The deprecation rule itself is quoted
once and remembered: "Lambda's standard deprecation policy is to deprecate
a runtime when any major component of the runtime reaches the end of
community long-term support (LTS) and security updates are no longer
available." `memory_size` and `timeout` sit at their documented defaults,
128 MB and 3 seconds, written out so the limits are visible where they
are chosen.

The runtime model is the part no other chapter has. "Lambda invokes your
function in an execution environment, which provides a secure and
isolated runtime environment", and the environment has a lifecycle with
phases: "In the `Init` phase, Lambda performs three tasks", starting all
extensions, bootstrapping the runtime, and running the function's static
code, and "The `Init` phase is limited to 10 seconds." Then invocation,
then suspension: "Lambda freezes the execution environment when the
runtime and each extension have completed and there are no pending
events." The freeze is what makes the next request cheap: "During this
time, if another request arrives for the same function, Lambda can reuse
the environment. This second request typically finishes more quickly,
since the execution environment is already fully set up. This is called a
'warm start'." The cold path is the named cost: "the first two steps of
downloading the code and setting up the environment are frequently
referred to as a 'cold start'. You are charged for this time, and it adds
latency to your overall invocation duration." The page even sizes it:
"Cold starts typically occur in under 1% of invocations. The duration of
a cold start varies from under 100 ms to over 1 second."

#diagram([the execution environment as a state machine: cold path through init, warm path around it, freeze and reuse between requests], length: 13pt, {
  let box(x, y, w, h, lines, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    for (i, t) in lines.enumerate() {
      cdraw.content((x + w / 2, y + h - 0.55 - i * 0.65), t, wrap: text.with(size: 6pt))
    }
  }
  box(0.6, 4.4, 3.8, 2.0, ([a request], [arrives at the api]))
  box(6.4, 6.0, 7.4, 2.7, ([init phase, capped at 10 s], [ext init, runtime init,], [function init, downloads code]), fill: luma(215))
  box(15.4, 4.4, 4.4, 2.0, ([invoke], [handler runs]))
  box(15.4, 1.1, 4.4, 2.0, ([frozen], [and retained]))
  box(20.8, 1.1, 3.0, 2.0, ([shutdown], [after idle]), fill: luma(215))
  cdraw.line((4.4, 5.9), (6.4, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.8, 6.9), (15.4, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.4, 4.7), (15.4, 4.7), stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  cdraw.content((9.9, 5.1), [warm start, init already done], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((17.6, 4.4), (17.6, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.2, 3.75), [freeze], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((19.8, 2.1), (20.8, 2.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 1.8), (13.4, 1.8), (13.4, 4.0), (15.6, 4.4), stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  cdraw.content((10.8, 2.9), [next request reuses], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((12.5, 0.2), [cold starts: under 1 percent of invocations, 100 ms to over 1 second, and init time is billed], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.5, 9.4), [role assumed by lambda, not by your code: the trust names lambda.amazonaws.com], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

sources: hashicorp/terraform-provider-aws resource documentation at tag
v6.64.0 on raw.githubusercontent.com, `iam_role`, `iam_role_policy`,
`iam_role_policy_attachment`, `iam_instance_profile`, `vpc`, `subnet`,
`internet_gateway`, `route_table`, `route_table_association`,
`security_group`, `vpc_security_group_ingress_rule`,
`vpc_security_group_egress_rule`, `instance`, `s3_bucket`,
`s3_bucket_versioning`, `s3_bucket_server_side_encryption_configuration`,
and `lambda_function`. docs.aws.amazon.com IAM User Guide roles and
security best practices, VPC User Guide what-is, configure-subnets,
create-subnets, route tables, security groups, and ip addressing, EC2
User Guide amis, user data, and instance type naming conventions, S3
User Guide welcome, bucket naming rules, versioning, and the default
encryption faq, Lambda developer guide execution role, runtimes, nodejs
handler, and execution environment lifecycle, plus the
AWSLambdaBasicExecutionRole managed policy reference.
All accessed 2026-09-12, the access date the version pins in
`Ch25/versions.tf` freeze. Documentation-verified only: no terraform
binary in this corpus, nothing initialized, planned, or applied. The pins
are terraform 1.16.2 and hashicorp/aws 6.64.0, both published 2026-09-09
and both marked Latest on the release pages when chapter 23 recorded them
the same day.
