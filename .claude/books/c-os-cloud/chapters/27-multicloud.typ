#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= multi-cloud practice

Chapter 25 walked one provider, chapter 26 walked the other. This chapter
is about what changes when both are in the room at once: the money, the
metadata, the rules, the truth about what exists, and the spelling. The
6 files under `Ch27/` are real, pinned terraform configuration and
nothing ever runs them: no terraform binary exists in this corpus,
nothing is initialized, planned, or applied. Every behavioral claim
below is a sentence quoted from a canonical page fetched 2026-09-12 or
a line of those files.

The freeze now carries both providers in one block. The cli pin is
1.16.2, released 2026-09-09. The aws pin is hashicorp/aws 6.64.0,
released 2026-09-09. The google pin is hashicorp/google 8.2.0,
released 2026-09-08. All three were the releases marked Latest when
read 2026-09-12:

#listing("c-os-cloud/samples/src/Ch27/versions.tf", first: 11, last: 24, caption: [the freeze: both providers, one required\_providers block, exact pins with dates in the header comment])

The provider blocks in the same file set up the chapter's first
asymmetry before any resource exists. The aws provider carries a
`default_tags` block, the provider-level half of the tagging model.
The google provider has no label equivalent at that level, an
asymmetry the tagging section pays for in full.

== cost models

Both clouds bill compute by the second, and both pages say so within
one sentence of each other. Amazon's on-demand page: "On-Demand
Instances let you pay for compute capacity by the hour or second
(minimum of 60 seconds) with no long-term commitments." The
partial-hour rule follows: "Each partial instance-hour consumed will
be billed per-second for Linux", with Windows, RHEL, and Ubuntu Pro
on the same list and SUSE as the one billed by the full hour. Google's
compute FAQ states the shape on the other side: "VMs are charged on a
per-second basis with a 1 minute minimum." The units rhyme, per
second with a floor of about a minute, and the floor is where the
billing model stops being a metronome: a cron job that runs for 5
seconds pays for a full minute on both platforms.

The tax is egress. Compute is cheap and getting cheaper, but bytes
leaving a building are billed by distance, and both price lists draw
the same ladder. On aws the ladder is documented across two pricing
pages. Within one zone: "There was no charge for the data transfer
between the NAT gateway and the EC2 instance since the traffic stays
in the same Availability Zone using private IP addresses." Across
zones: "Data sent over VPC peering connections that crosses an
Availability Zone within the same AWS Region is charged at \$0.01/GB
in both "In" and "Out" direction." Out to the internet the rate in
the page's own worked example is \$0.09 per GB, with one allowance in
front of it: "AWS customers receive 100 GB of free data transfer out
to the internet free each month, aggregated across all AWS Services
and Regions (except China and GovCloud)." The aggregation is its own
rule: the rate tiers "take into account your aggregate usage for Data
Transfer Out to the Internet across Amazon EC2", S3, RDS, and the
rest of a long list, so the discount ladder counts the whole account,
not one service.

Google's VPC pricing page draws the same ladder with its own numbers.
Same zone, internal addresses, is the same free rung, a row reading
"No charge". One rung up: "Data transfer to a different Google Cloud
zone in the same Google Cloud region when using the internal or
external IP addresses within the same VPC network" costs \$0.01 per
GiB, the twin of the aws cross-zone penny. Between regions the page
switches to a matrix, "All prices are per GiB in USD", that runs from
\$0.02 inside a continent pair to \$0.14 for anything into or out of
South America. Inbound is free on both sides, the page states
"Ingress pricing is still free.", but with the fine print that
matters for anyone who thought a request was free: "Responses to
requests count as data transfer out and are charged."

Budgets are the console-side answer, and both consoles build them the
same way: an amount, thresholds against it, and alerts when spend
crosses a line. The aws page opens "You can use AWS Budgets to track
and take action on your AWS costs and usage.", and its worked example
is the chapter's model: "Setting a monthly cost budget with a fixed
target amount to track all costs associated with your account. You
can choose to be alerted for both actual (after accruing) and
forecasted (before accruing) spends." Notifications go out through
the same two channels on both platforms, "You can have notifications
sent to an Amazon SNS topic, to an email address, or to both." The
gcp page names the same object: "Avoid surprises on your bill by
creating Cloud Billing budgets to monitor all of your Google Cloud
charges in one place.", with the amount being a "Specified amount
lets you set a fixed budget amount that your actual spend is compared
against." and the thresholds defaulted: "the default alert thresholds
are set at 50%, 90%, and 100% of the budget amount, calculated
against Actual spend."

Neither console stops anything. The gcp page says so plainly:
"Setting an alerts-only budget doesn't automatically cap Google Cloud
or Google Maps Platform usage or spending." The aws page's note is
the same warning from the timing side: "You might incur additional
costs or usage that exceed your budget notification threshold before
AWS Budgets can notify you", because "AWS Budgets information is
updated up to three times a day." The one set of teeth on either page
is the aws budget action, which can, in the page's example,
"automatically apply a custom IAM policy that denies you the ability
to provision additional resources within an account", a budget that
escalates into a guardrail, the subject of section 3.

#callout("pitfall", "budgets observe, they do not brake", [
  An alert threshold is a thermometer reading. By the time the 90
  percent email arrives, the spend it describes already happened, and
  on aws the reading itself can be a third of a day old. Treat
  budgets as the feedback loop for forecast review, and put the
  actual brake in policy: a deny in an scp, an organization policy
  constraint, or a budget action that applies an IAM deny. Those are
  the mechanisms that answer no before the dollar is spent.
])

#diagram([the egress ladder as a plot: per-gb price against distance traveled, the two clouds on the same axes], length: 13pt, {
  let y0 = 1.3
  let sc = 38.0
  let p(v) = (y0 + v * sc,)
  // axes
  cdraw.line((4.2, y0), (22.8, y0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.2, y0), (4.2, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.9, 4.4), [usd, #linebreak() per gb], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((13.5, 0.6), [distance the bytes travel], wrap: text.with(size: 6pt, fill: luma(100)))
  // x group labels
  cdraw.content((6.4, 0.82), [same zone], wrap: text.with(size: 6pt))
  cdraw.content((11.0, 0.82), [cross zone], wrap: text.with(size: 6pt))
  cdraw.content((15.6, 0.82), [cross region], wrap: text.with(size: 6pt))
  cdraw.content((20.2, 0.82), [internet out], wrap: text.with(size: 6pt))
  // y ticks for the quoted rates
  cdraw.line((4.0, p(0.01).first()), (4.4, p(0.01).first()), stroke: luma(100))
  cdraw.content((3.4, p(0.01).first()), [0.01], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((4.0, p(0.09).first()), (4.4, p(0.09).first()), stroke: luma(100))
  cdraw.content((3.4, p(0.09).first()), [0.09], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((4.0, p(0.14).first()), (4.4, p(0.14).first()), stroke: luma(100))
  cdraw.content((3.4, p(0.14).first()), [0.14], wrap: text.with(size: 6pt, fill: luma(100)))
  // aws series: same zone 0, cross zone 0.01, dashed to internet 0.09
  cdraw.circle((6.4, p(0).first()), radius: 0.14, fill: luma(60), stroke: luma(60))
  cdraw.line((6.4, p(0).first()), (11.0, p(0.01).first()), stroke: luma(60))
  cdraw.circle((11.0, p(0.01).first()), radius: 0.14, fill: luma(60), stroke: luma(60))
  cdraw.line((11.0, p(0.01).first()), (20.2, p(0.09).first()), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.circle((20.2, p(0.09).first()), radius: 0.14, fill: luma(60), stroke: luma(60))
  cdraw.content((15.6, 2.5), [aws cross-region rates, #linebreak() not plotted here], wrap: text.with(size: 6pt, fill: luma(60)))
  cdraw.content((21.3, p(0.09).first() + 0.55), [after 100 gb free, #linebreak() aggregated account-wide], wrap: text.with(size: 6pt, fill: luma(60)))
  // gcp series: same zone 0, cross zone 0.01, band 0.02 to 0.14, premium unquoted
  cdraw.circle((6.4, p(0).first() + 0.26), radius: 0.14, fill: luma(160), stroke: luma(120))
  cdraw.line((6.4, p(0).first() + 0.26), (11.0, p(0.01).first() + 0.26), stroke: luma(120))
  cdraw.circle((11.0, p(0.01).first() + 0.26), radius: 0.14, fill: luma(160), stroke: luma(120))
  cdraw.line((11.0, p(0.01).first() + 0.26), (14.6, p(0.02).first() + 0.1), stroke: luma(120))
  cdraw.rect((14.6, p(0.02).first()), (16.6, p(0.14).first()), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((15.6, 4.9), [inter-region, #linebreak() matrix by, #linebreak() continent pair], wrap: text.with(size: 6pt))
  cdraw.line((16.6, p(0.10).first()), (20.2, 6.9), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((18.9, 7.15), [premium tier, #linebreak() volume-banded], wrap: text.with(size: 6pt, fill: luma(100)))
  // shared rung annotations
  cdraw.content((8.4, 2.45), [no charge in-zone, #linebreak() one penny cross-zone], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((13.5, 8.35), [only the rates quoted on the pages are drawn: dark is aws, grey is google, dashed means the page names the charge but not the number here], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== tagging, a data model with two spellings

The aws definition is one sentence on the tag editor page: "Tags are
key and value pairs that act as metadata for organizing your AWS
resources." The work they do is enumeration: "You can create tags to
categorize resources by purpose, owner, environment, or other
criteria." The whitepaper makes the structural argument this section
is named for. It opens by calling each tag "a simple label consisting
of a key and an optional value to store information about the
resource or data retained on that resource", and it dismisses the
alternative with "a resource name can only hold a limited amount of
information." A resource name is one string. A tag set is a schema:
typed columns, allowed values, a primary key for the bill. That is
why tagging belongs in the configuration language and not in a
console afterthought, and why the tag policy later in this section is
a schema enforcement tool, not a naming suggestion.

Aws tags are case sensitive on both halves, "Tag keys are case
sensitive." and "Like tag keys, tag values are case sensitive.", and
the page bars the obvious abuse: "Do not store personally identifiable
information (PII) or other confidential or sensitive information in
tags." because aws itself reads them for billing and administration.
Terraform's aws provider mirrors the schema at two levels. The
provider level takes a `default_tags` block, "Configuration block
with resource tag settings to apply across all resources handled by
this provider", the injection point for the organization-wide keys.
The override rule is stated as a prohibition: "Provider tags can be
overridden with new values, but not excluded from specific
resources.", and a resource overrides with its own `tags`, "Map of
tags to assign to the resource.", where "tags with matching keys will
overwrite those defined at the provider-level". The merged result is
visible as the computed `tags_all`, "Map of tags assigned to the
resource, including those inherited from the provider". The sample
carries the whole mechanism:

#listing("c-os-cloud/samples/src/Ch27/versions.tf", first: 26, last: 37, caption: [the provider-level half: default\_tags injects four keys into every aws resource this provider touches])

#listing("c-os-cloud/samples/src/Ch27/tags.tf", first: 19, last: 26, caption: [the resource-level half: owner overwrites the injected key, chapter exists only on this bucket])

The google spelling is labels, and the rules are stricter because the
use is stricter. The overview defines the object: "A label is a
key-value pair that you can assign to Google Cloud resources." The
limits read like a column definition: "Each resource can have up to
64 labels.", "Keys have a minimum length of 1 character and a maximum
length of 63 characters, and cannot be empty.", "Values can be empty,
and have a maximum length of 63 characters.", and "Keys and values
can contain only lowercase letters, numeric characters, underscores,
and dashes." Keys are unique per resource, "The key portion of a
label must be unique within a single resource." The payoff is on the
bill: "Information about labels is forwarded to the billing system
that lets you break down your billed charges by label." The provider
takes them per resource, the bucket page calls `labels` "A map of
key/value label pairs to assign to the bucket.", and there is no
provider-level injection to lean on, so the corpus builds its own:

#listing("c-os-cloud/samples/src/Ch27/tags.tf", first: 10, last: 17, caption: [the injection point this corpus builds itself: one schema, satisfied to the stricter cloud's rules])

#listing("c-os-cloud/samples/src/Ch27/tags.tf", first: 28, last: 34, caption: [the google half: the same four keys arrive as labels on the bucket])

Two label behaviors have no aws counterpart. The instance page warns
that its `labels` field "will only manage the labels present in your
configuration" and points at `effective_labels` for everything
actually on the resource, terraform owns the keys it names and coexists
with the rest. And projects do not cascade: "Labels attached to a
project don't automatically propagate to child resources within the
project." The vocabulary also forks inside google itself, the overview
separates the pair: "Labels can be used as queryable annotations for
resources, but can't be used to set conditions on policies.", while
"Tags provide a way to conditionally allow or deny policies based on
whether a resource has a specific tag". Google labels are for
questions, google tags are for gates, and the aws word "tag" covers
both jobs at once, which is the single largest naming trap in the
multi-cloud room.

The aws tag policy is the schema enforcement. The organizations page
opens: "Tag policies allow you to standardize the tags attached to the
AWS resources in your organization's accounts." The mechanism is
declarative: "In a tag policy, you specify tagging rules applicable to
resources when they are tagged.", case treatment included. Enforcement
is per resource type and opt-in: "A tag policy can also specify that
noncompliant tagging operations on specified resource types are
enforced. In other words, noncompliant tagging requests on specified
resource types are prevented from completing." The blind spot is
documented in the same breath: "Untagged resources or tags that aren't
defined in the tag policy aren't evaluated for compliance with the
tag policy." A tag policy can reject a wrong value for a known key,
it cannot notice a resource that carries no keys at all.

#callout("pitfall", "write the schema once, to the stricter cloud", [
  A cross-cloud tag schema has to survive both validators, so it
  inherits google's rules wholesale: lowercase keys and values, 63
  characters, underscores and dashes, no spaces, no capitals, even
  though aws would happily accept all of those. The reverse shortcut,
  an aws-shaped schema with `CostCenter` and `Application Owner`,
  bills cleanly on one cloud and silently splits its breakdowns on
  the other. The intersection is the only stable vocabulary, and it
  is exactly what `label_schema` in the sample pins down.
])

#diagram([the tag taxonomy as a matrix: the aws word against the google word across four properties], length: 13pt, {
  let h(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: luma(205), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  let row(y, lines) = {
    for (i, cell) in lines.enumerate() {
      let x = 0.4 + i * 6.1
      cdraw.rect((x, y), (x + 5.7, y + 3.0), fill: luma(235), radius: 0.02)
      for (j, t) in cell.enumerate() {
        cdraw.content((x + 2.85, y + 2.4 - j * 0.68), t, wrap: text.with(size: 6pt))
      }
    }
  }
  h(0.4, 7.6, 5.7, [the rules])
  h(6.5, 7.6, 5.7, [where it is set])
  h(12.6, 7.6, 5.7, [billing reach])
  h(18.7, 7.6, 5.7, [policy power])
  row(4.2, (
    ([aws: tags], [case sensitive], [keys and values]),
    ([provider, #linebreak() default\_tags, #linebreak() resource, #linebreak() can override], [merged into, #linebreak() tags\_all]),
    ([cost allocation, #linebreak() after activation], [tiers count it, #linebreak() account-wide]),
    ([iam conditions, #linebreak() read tags], [tag policy, #linebreak() enforces them]),
  ))
  row(0.8, (
    ([google: labels], [up to 64, #linebreak() per resource], [63 chars,, #linebreak() lowercase only]),
    ([per resource, #linebreak() no injection], [instances are, #linebreak() non-authoritative]),
    ([forwarded to, #linebreak() billing], [breakdown by, #linebreak() label]),
    ([annotations, #linebreak() only], [cannot gate, #linebreak() a policy]),
  ))
  cdraw.content((12.4, 0.15), [google's own tags are the conditional kind, labels cannot gate a policy], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== guardrails, policy as code

Every guardrail answers one question at one moment. The aws scp is
the organization-wide ceiling: "SCPs are a type of organization
policy that you can use to manage permissions in your organization."
The page spends its most important sentences on what an scp is not:
"SCPs do not grant permissions to the IAM users and IAM roles in your
organization.", they only cap, "An SCP defines a permission guardrail,
or sets limits, on the actions that the IAM users and IAM roles in
your organization can perform." The inheritance is strict and
one-directional, "Any account has only those permissions permitted by
every parent above it.", the cap reaches everyone under it, "SCPs
affect all users and roles in attached accounts, including the root
user.", and stops at the top: "SCPs don't affect users or roles in
the management account."

Google's organization policy is the same instrument pointed at
resources instead of principals. The overview grants "centralized and
programmatic control over your organization's Google Cloud
resources", its stated purpose to "Define and establish guardrails
for your development teams to stay within compliance boundaries."
The unit is the constraint, "An organization policy configures a
single constraint that restricts one or more Google Cloud
services.", and the page offers the mental model this chapter keeps:
"Think of the constraint as a blueprint that defines what behaviors
are controlled." Attachment follows the resource hierarchy, the
policy is "set on an organization, folder, or project resource to
enforce the constraint on that resource and any child resources",
and "all descendants of that resource inherit the organization
policy by default". The worked examples are concrete gates, from
limiting domain-wide sharing to the placement rule "Restrict the
physical location of newly created resources". Both of these
mechanisms answer at the api, at deploy time, after a plan has
already been approved by whoever is running the apply.

Policy as code moves the question earlier, onto the plan itself.
Sentinel is the integrated form: "HCP Terraform checks the Terraform
plan against the policy set during each run.", and a failure has
consequences proportioned to its level, "failed policies can stop
the run. You can override failed policies with the right
permissions." The policy reaches everything the run can see: "HCP
Terraform provides four imports to define policy rules for the plan,
configuration, state, and run associated with a policy check." OPA is
the decoupled form, "an open source, general-purpose policy engine
that unifies policy enforcement across the stack", with policies in
a language of its own, "OPA policies are expressed in a high-level
declarative language called Rego." The terraform integration is two
commands and a decision: "OPA makes it possible to write policies
that check the changes Terraform is about to make before it makes
them.", "Use the command terraform show to convert the Terraform
plan into JSON so that OPA can read the plan.", then "you hand OPA
the policy, the Terraform plan as input, and ask it to evaluate":

#snippet("terraform show -json tfplan.binary > tfplan.json\nopa exec --decision terraform/analysis/authz --bundle policy/ tfplan.json\n", lang: "bash")

The plan json is the whole interface, and its limits are documented
on the same page: "OPA policies operate on the JSON plan generated by
Terraform, which has certain limitations." A policy engine outside
the tool can deny a change, comment on it, or score it, and the
corpus runs neither command.

The smallest policy-as-code is inside the language itself. A `check`
block is "the check block to validate your infrastructure outside of
the typical resource lifecycle", it "executes as the last step of
plan or apply operation" and so runs "after Terraform has planned or
provisioned your infrastructure", and its failure mode is a warning:
"When a check block's assertion fails, Terraform reports a warning
and continues executing the current operation.", because "check
blocks do not block operations." The sample's three checks hold the
tag
schema from section 2 to the stricter cloud's rules, key grammar,
value length, and override target, so a schema drift shows up as a
warning line in every future plan instead of a rejected apply on one
provider:

#listing("c-os-cloud/samples/src/Ch27/checks.tf", first: 9, last: 16, caption: [one check in full: a for expression over the schema, an assert with condition and error\_message])

#listing("c-os-cloud/samples/src/Ch27/checks.tf", first: 27, last: 32, caption: [the third check: the aws override must target a key the shared schema defines])

The assert halves are fixed by the same page that defines the block,
"Input variable validations, preconditions, postconditions, and
checks all must include the `error_message` argument.", a `condition`
that returns a boolean and one message for the human reading the
warning.

#diagram([one change, three moments of refusal: plan time, apply time, and the api gate], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  let deny = (paint: luma(80))
  let dash = (paint: luma(140), dash: "dashed")
  box(0.4, 5.0, 3.6, 1.2, [the change, #linebreak() a .tf edit])
  box(4.8, 5.0, 4.0, 1.2, [terraform plan])
  box(14.4, 5.0, 4.0, 1.2, [terraform apply])
  box(19.6, 5.0, 4.0, 1.2, [resource, #linebreak() created])
  box(4.8, 6.7, 8.4, 1.7, [policy as code, #linebreak() sentinel: each run, #linebreak() opa: the plan json], fill: luma(215))
  box(16.8, 6.7, 6.8, 1.7, [stopped, #linebreak() before any apply], fill: luma(245))
  cdraw.rect((0.4, 6.7), (4.4, 8.4), stroke: dash, radius: 0.02)
  cdraw.content((2.4, 7.55), [check blocks, #linebreak() warn only], wrap: text.with(size: 6pt))
  box(14.4, 2.6, 6.4, 1.7, [deploy-time gates, #linebreak() scp, aws api, #linebreak() org policy, google], fill: luma(215))
  box(14.4, 0.4, 6.4, 1.4, [apply fails, #linebreak() at the provider api], fill: luma(245))
  cdraw.line((4.0, 5.6), (4.8, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.8, 5.6), (14.4, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.4, 5.6), (19.6, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.4, 6.7), (2.4, 6.35), (5.8, 6.35), stroke: dash)
  cdraw.line((5.8, 6.35), (5.8, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.4, 6.2), (8.4, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.2, 7.55), (16.8, 7.55), stroke: deny, mark: (end: "x"))
  cdraw.line((16.4, 5.0), (16.4, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 2.6), (16.4, 1.8), stroke: deny, mark: (end: "x"))
  cdraw.content((9.0, 4.4), [every plan-time gate, #linebreak() reads the same plan], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((6.8, 1.3), [an x is a refusal. cheapest at, #linebreak() plan time, a failed apply at the, #linebreak() api gate, a warning from checks], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== drift, the plan as detector

Drift is the gap between the record and the world. The terraform
tutorial names it from the state's side: manual changes leave the
state "out of sync, or 'drift,' from the real infrastructure." The
detector is not a separate tool, it is the plan: "By default,
Terraform compares your state file to real infrastructure whenever
you invoke" `terraform plan` or `terraform apply`. The same page is
candid about the danger of that default, because the diff cuts both
ways: "Terraform will attempt to reconcile your infrastructure,
which may unintentionally destroy or recreate resources." The safe
direction exists as a flag: "you can use a `-refresh-only` flag to
inspect what the changes to your state file would be", and the page
pins its semantics: "This is a refresh-only plan, so Terraform will
not take any actions to undo these."

Both platforms also keep their own recorders, and neither needs
terraform to run. Aws config is the timeline: "AWS Config provides a
detailed view of the configuration of AWS resources in your AWS
account.", "how they were configured in the past so that you can see
how the configurations and relationships change over time", with
change notification built in: "You can use AWS Config to notify you
whenever resources are created, modified, or deleted without having
to monitor these changes by polling the calls made to each
resource." Rules add the compliance half, "When AWS Config detects
that a resource violates the conditions in one of your rules, AWS
Config flags the resource as noncompliant and sends a notification."
Google's infrastructure manager is the newer, narrower instrument,
and its drift page says where the answer comes from: "You can use
previews to view resource drift for your deployment.", because
"Infra Manager resource drifts are structured versions of
`resource_drift` in the terraform plan JSON representation." Even
the managed service reads drift out of the plan json, the same
artifact the opa gate consumed in section 3. The honest diff is the
plan, everywhere.

The state itself should live in the cloud it describes, one backend
per configuration, and the backend page fixes the rule: "A
configuration can only provide one backend block." The sample ships
the aws and google shapes as a pair the reader picks between, the
same either/or a real checkout makes:

#listing("c-os-cloud/samples/src/Ch27/backend-aws.tf", first: 10, last: 18, caption: [the aws backend: s3 state, native lockfile opted in, encryption on])

#listing("c-os-cloud/samples/src/Ch27/backend-gcp.tf", first: 9, last: 14, caption: [the google backend: gcs state under a prefix, locking with no flag to set])

The s3 page "Stores the state as a given key in a given bucket on
Amazon S3." with locking off by default: `use_lockfile` is "Whether
to use a lockfile for locking the state file. Defaults to false.",
"State locking is an opt-in feature of the S3 backend.", and the old
mechanism is on its way out, "DynamoDB-based locking is deprecated
and will be removed in a future minor version." The gcs page "Stores
the state as an object in a configurable prefix in a pre-existing
bucket on Google Cloud Storage (GCS).", the bucket "must exist prior
to configuring the backend", and locking is unconditional: "This
backend supports state locking." Both blocks obey the same
limitation chapter 24 already quoted, the backend block cannot refer
to named values, which is why both bucket names are literals.

#callout("warning", "refresh before you reconcile", [
  A stale plan is worse than no plan. The default compare-and-reconcile
  will "unintentionally destroy or recreate" against a world it never
  read. Point `terraform plan -refresh-only` at the drifted workspace
  first, read the diff it prints, and only then decide which side is
  right: the configuration, the console edit, or a resource that
  learned something the file does not know yet.
])

#diagram([drift as a before and after: one recorded field, one console edit, one honest diff], length: 13pt, {
  let box(x, y, w, h, lines, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    for (i, t) in lines.enumerate() {
      cdraw.content((x + w / 2, y + h - 0.55 - i * 0.65), t, wrap: text.with(size: 6pt))
    }
  }
  cdraw.content((4.8, 8.35), [before: the record matches the world], wrap: text.with(size: 6pt, fill: luma(100)))
  box(0.4, 6.6, 6.4, 1.5, ([state file], [environment: dev]))
  cdraw.line((6.8, 7.35), (8.6, 7.35), stroke: luma(100), mark: (end: ">"))
  box(9.0, 6.6, 6.4, 1.5, ([live bucket], [environment: dev]))
  cdraw.content((7.8, 5.95), [an operator edits the tag, #linebreak() outside terraform], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((12.2, 6.6), (12.2, 6.0), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.content((14.0, 6.25), [a console edit], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((4.8, 5.35), [after: the same two boxes, one field apart], wrap: text.with(size: 6pt, fill: luma(100)))
  box(0.4, 3.6, 6.4, 1.5, ([state file], [environment: dev]))
  cdraw.line((6.8, 4.35), (8.6, 4.35), stroke: luma(100), mark: (end: ">"))
  box(9.0, 3.6, 6.4, 1.5, ([live bucket], [environment: prod]), fill: luma(220))
  cdraw.content((12.2, 3.05), [the drift: one field], wrap: text.with(size: 6pt, fill: luma(100)))
  box(16.6, 3.6, 7.4, 3.5, ([terraform plan], [-refresh-only], [prints the diff:], [environment:], [dev to prod]), fill: luma(245))
  cdraw.line((15.4, 4.35), (16.6, 4.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((20.3, 2.9), [reconcile, or accept, #linebreak() the edit into state], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((9.4, 1.0), [aws config keeps the timeline and flags rule violations, #linebreak() infra manager reads resource\_drift from the plan json], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the provider mapping

The closing view is the lattice the last three chapters built. Every
capability row names the aws resource chapter 25 verified at 6.64.0
and the google resource chapter 26 verified at 8.2.0, plus the two
backends this chapter pinned, with the scope difference that keeps
biting: chapter 25 quoted "A VPC spans all of the Availability Zones
in a Region." while chapter 26 quoted "VPC networks, including their
associated routes and firewall rules, are global resources.", the
regional network against the global one, and the subnet rows invert
with them. The firewall row carries the attachment flip: the security
group rides the instance, while the google rule is a network object
whose `network` argument is "The name or `self_link` of the network
to attach this firewall to." The vm row carries the boot polarity,
user data once by default against the startup script on every boot.
The object store row carries the class model, per-object metadata
against the bucket default the sample writes down as `STANDARD`:

#diagram([the mapping lattice: one capability spine, the aws and google spellings hung off it], length: 13pt, {
  let row(y, aws, cap, gcp) = {
    cdraw.rect((1.0, y), (8.8, y + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((4.9, y + 0.45), aws, wrap: text.with(size: 6pt))
    cdraw.rect((10.2, y), (14.2, y + 0.9), fill: luma(205), radius: 0.02)
    cdraw.content((12.2, y + 0.45), cap, wrap: text.with(size: 6pt))
    cdraw.rect((15.6, y), (23.4, y + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((19.5, y + 0.45), gcp, wrap: text.with(size: 6pt))
    cdraw.line((8.8, y + 0.45), (10.2, y + 0.45), stroke: luma(100))
    cdraw.line((14.2, y + 0.45), (15.6, y + 0.45), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((4.9, 9.1), [aws, chapter 25], wrap: text.with(size: 6.5pt))
  cdraw.content((12.2, 9.1), [the capability], wrap: text.with(size: 6.5pt))
  cdraw.content((19.5, 9.1), [google, chapter 26], wrap: text.with(size: 6.5pt))
  row(7.9, [aws\_iam\_role\_policy], [grant], [google\_project\_iam\_member])
  row(6.8, [aws\_vpc], [network], [google\_compute\_network])
  row(5.7, [aws\_subnet], [subnet], [google\_compute\_subnetwork])
  row(4.6, [aws\_security\_group\_rule], [firewall], [google\_compute\_firewall])
  row(3.5, [aws\_instance], [vm], [google\_compute\_instance])
  row(2.4, [aws\_s3\_bucket], [object store], [google\_storage\_bucket])
  row(1.3, [aws\_lambda\_function], [container], [google\_cloud\_run\_v2\_service])
  row(0.2, [s3 backend], [state backend], [gcs backend])
})

The table adds what the lattice cannot hold, the scope note and the
behavioral difference each row hides:

#table(
  columns: (1.7fr, 2.2fr, 2.2fr, 2.6fr),
  inset: 5pt,
  stroke: 0.5pt + luma(200),
  table.header(
    text(size: 8pt, weight: 700)[capability],
    text(size: 8pt, weight: 700)[aws resource],
    text(size: 8pt, weight: 700)[google resource],
    text(size: 8pt, weight: 700)[the difference],
  ),
  ..(
    ("grant", "`aws_iam_role_policy`", "`google_project_iam_member`", "a policy document you write against a role name from the catalogue"),
    ("network", "`aws_vpc`", "`google_compute_network`", "regional, spans the azs, against global, owns no range"),
    ("address range", "`aws_subnet`", "`google_compute_subnetwork`", "one per az against one per region"),
    ("firewall", "`aws_security_group_rule`", "`google_compute_firewall`", "stateful group rides the instance against network rule selecting by tag"),
    ("virtual machine", "`aws_instance`", "`google_compute_instance`", "user data runs once by default against startup script on every boot"),
    ("object store", "`aws_s3_bucket`", "`google_storage_bucket`", "class is per-object metadata against the bucket default"),
    ("container service", "`aws_lambda_function`", "`google_cloud_run_v2_service`", "function against revision, traffic split lives in the template"),
    ("state backend", "s3 backend", "gcs backend", "locking opt-in through `use_lockfile` against locking always on"),
  ).flatten().map(v => text(size: 8pt)[#v]),
)

Read down the difference column and the chapter list reappears: the
cost ladder sits under the placement choices, the tag schema rides
every row, the guardrails gate each column at a different moment,
and the plan is the one diff that reads both. Multi-cloud is not 2
clouds, it is one discipline, configuration as the record, policy as
the gate, and the plan as the proof, executed twice with different
nouns.

sources: aws.amazon.com ec2 on-demand pricing and vpc pricing.
docs.aws.amazon.com cost management budgets (budgets-managing-costs),
tag editor tagging, the tagging best practices whitepaper
(publication date March 30, 2023), organizations tag policies and
service control policies, and the aws config guide.
docs.cloud.google.com compute faq, billing budgets, resource manager
labels overview and label creation, organization policy overview,
and infrastructure manager preview results. The vpc pricing page
serves from cloud.google.com, which is the cited form.
developer.hashicorp.com terraform backend configuration, the s3 and
gcs backend pages, the checks page, and the resource drift tutorial.
hcp terraform policy enforcement pages for sentinel.
openpolicyagent.org docs and the terraform integration page. All
accessed 2026-09-12. Provider resource pages at the pinned tags,
raw.githubusercontent.com hashicorp/terraform-provider-aws v6.64.0
(index, instance, security group) and hashicorp/terraform-provider-
google v8.2.0 (storage bucket, compute instance, compute firewall),
accessed 2026-09-12. Documentation-verified only: no terraform
binary in this corpus, nothing initialized, planned, or applied.
The version pins are 1.16.2 for the cli, 6.64.0 for hashicorp/aws,
and 8.2.0 for hashicorp/google, all Latest at access time.
