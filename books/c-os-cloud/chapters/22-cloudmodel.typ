#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the cloud model

Chapters 2 through 18 owned one machine. The chapters from here on
rent machines by the hour from two providers, and this chapter owns no
compiler, no sample, and no check count to lean on: every factual
sentence ties to a canonical page fetched on 2026-09-12 and quoted as
fetched, because provider pages drift and training data remembers the
old wording. Four vocabularies carry the rest of the book: the service
models that grade how much of the stack you rent, the geography model
that decides where data lives and what fails together, the
responsibility line that moves with every managed upgrade, and the two
review frameworks the providers publish for judging the result.

== iaas, paas, faas, saas

The definitions are older than every service this book provisions.
NIST Special Publication 800-145, dated September 2011, defines cloud
computing as "a model for enabling ubiquitous, convenient, on-demand
network access to a shared pool of configurable computing resources"
that can "be rapidly provisioned and released with minimal management
effort or service provider interaction", decomposed into "five
essential characteristics, three service models, and four deployment
models". The characteristics are on-demand self-service, broad network
access, resource pooling, rapid elasticity, and measured service, the
last one the reason a cost chapter exists at the end of this book. The
deployment models are private, community, public, and hybrid; the
public one is what chapters 23 through 24 rent.

Each service model is one capability sentence plus a list of what the
consumer stops controlling. Infrastructure as a service gives the
consumer the capability to "provision processing, storage, networks,
and other fundamental computing resources where the consumer is able
to deploy and run arbitrary software, which can include operating
systems and applications", keeping "control over operating systems,
storage, and deployed applications; and possibly limited control of
select networking components (e.g., host firewalls)". Platform as a
service gives the capability to "deploy onto the cloud infrastructure
consumer-created or acquired applications created using programming
languages, libraries, services, and tools supported by the provider",
with control over "the deployed applications and possibly
configuration settings for the application-hosting environment" and
nothing below. Software as a service gives the capability to "use the
provider's applications running on a cloud infrastructure", where the
consumer "does not manage or control the underlying cloud
infrastructure including network, servers, operating systems, storage,
or even individual application capabilities, with the possible
exception of limited user-specific application configuration
settings". Read as a gradient, the sentences agree on the mechanism:
the same stack, with the handover point climbing one band at a time.

#callout("note", "nist named three, the market rents four", [
  800-145 lists exactly three service models and has no word for
  functions. The fourth rung postdates the definition: the Lambda
  page opens "AWS Lambda is a serverless compute service. With
  Lambda, you can run code without provisioning or managing
  servers", and Google's responsibility page treats faas as a
  category of its own, saying "FaaS has a similar shared
  responsibility list as SaaS". In NIST terms a function platform
  is a paas with the deployment unit shrunk to one handler, the
  capability sentence unchanged, while the provider also takes
  "capacity provisioning, scaling, and patching" per the Lambda
  page. The gradient gains a rung without gaining an architecture.
])

Where the book's services sit follows from the same sentences,
applied when chapters 25 and 26 write their terraform. A vpc plus an
ec2 instance or a compute engine machine hands you a network and a
box whose guest operating system you patch, which is the iaas
sentence exactly, and the AWS responsibility page names ec2 as its
iaas example with "the guest operating system (including updates and
security patches)" on the customer's side. Lambda and cloud run are
the faas rung: code in, endpoint out, no server visible. S3 and
cloud storage are managed storage, off the compute gradient
entirely, no operating system and no runtime, just buckets and
objects. Iam and the project model sit under every rung, because
identity and billing are not on the stack at all.

#diagram([the responsibility gradient, one stack per rung, the customer bands shrink as the rung climbs], length: 13pt, {
  let rows = ("data", "application", "runtime", "guest os", "virtualization", "servers", "power, network")
  let ys = (8.6, 7.6, 6.6, 5.6, 4.6, 3.6, 2.6)
  for (i, name) in rows.enumerate() {
    cdraw.content((2.2, ys.at(i)), name, wrap: text.with(size: 6pt))
  }
  // customer rows per rung: iaas 0-3, paas and faas 0-1, saas 0
  let cols = (("iaas", 4.6, 4), ("paas", 9.3, 2), ("faas", 14.0, 2), ("saas", 18.7, 1))
  for (name, x0, own) in cols {
    cdraw.content((x0 + 2.0, 9.6), name, wrap: text.with(size: 6.5pt))
    for i in range(7) {
      let f = if i < own { luma(205) } else { luma(235) }
      cdraw.rect((x0, ys.at(i) - 0.4), (x0 + 4.0, ys.at(i) + 0.4), fill: f, radius: 0.02)
    }
    // the responsibility line, between the last customer band and the first provider band
    let ly = if own == 4 { 5.1 } else if own == 2 { 7.1 } else { 8.1 }
    cdraw.line((x0 - 0.2, ly), (x0 + 4.2, ly), stroke: 1.4pt + luma(100))
  }
  let subs = (("you patch the", 6.6), ("you bring code,", 11.3), ("one function,", 16.0), ("settings only,", 20.7))
  for (t, x) in subs {
    let second = if x == 6.6 { [guest os] } else if x == 11.3 { [they run it] } else if x == 16.0 { [they scale it] } else { [no code] }
    cdraw.content((x, 1.7), t, wrap: text.with(size: 6pt, fill: luma(100)))
    cdraw.content((x, 1.05), second, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  cdraw.content((11.9, 0.4), [the line climbs, each rung hands its lower bands to the provider], wrap: text.with(size: 6.5pt))
})

== regions, zones, failure domains

AWS regions are "separate geographic areas", each "designed to be
isolated from the other Regions", which "achieves the greatest
possible fault tolerance and stability". The isolation is literal:
"You can replicate some types of resources across Regions, but we
don't automatically replicate them for you." Each region "has
multiple, independent locations known as Availability Zones", and
"Each Availability Zone consists of one or more discrete data
centers, each with redundant power, networking, and connectivity, and
housed in separate facilities. Because they are physically separate,
only a single Availability Zone would be affected in the unlikely
event of a fire, tornado, or flooding." The guide's practice line is
plain: "It is a best practice to deploy your application in multiple
Availability Zones, so that your application remains available even
if one Availability Zone fails."

The fault isolation whitepaper pins the numbers the guide leaves
out. Zones in a region are "meaningfully distant from each other, up
to 60 miles" (about 100 km) "to prevent correlated failures, but
close enough to use synchronous replication with single-digit
millisecond latency". They are "designed not to be simultaneously
impacted by a shared fate scenario like utility power, water
disruption, fiber isolation, earthquakes, fires, tornadoes, or
floods"; generators and cooling "are not shared across Availability
Zones and are designed to be supplied by different power substations";
and even AWS's own service deployments "to Availability Zones in the
same Region are separated in time to prevent correlated failure". The
whitepaper names the property AZI, Availability Zone Independence,
and describes the interconnect as "high-bandwidth, low-latency
networking, over fully redundant, dedicated metro fiber". Counts:
"Each Region has at least three Availability Zones", the regions
table shows most at three with us-east-1 at six and us-west-2, Tokyo,
Seoul, and London at four, and the global infrastructure page counted
"124 Availability Zones within 39 Geographic Regions" on access day.

Google's page is worded more cautiously, and the caution is content.
"Regions are independent geographic areas that consist of zones", "A
zone is a deployment area for Google Cloud resources within a
region", and the operating rule is stated flatly: "Zones should be
considered a single failure domain within a region." The physical
claim is softer than AWS's: "A region consists of three or more zones
housed in three or more physical data centers", with named
exceptions, Stockholm, Mexico, Osaka, and Montreal, whose three zones
are housed in one or two physical data centers, and the page says
outright that "Zones and regions are logical abstractions of
underlying physical resources". No distance and no inter-zone latency
figure appears anywhere on it. Both providers sell the same
operating discipline, spread across zones for availability, across
regions for geography, but they document it differently: AWS
publishes the mileage, Google publishes the abstraction.

That difference is the latency budget. Zone redundancy costs
single-digit milliseconds per replication hop inside a region, the
AWS whitepaper number, cheap enough to spend on a request path.
Region redundancy has no published number on either page; what
Google's page does say is that multi-region services, "managed by
Google to be redundant and distributed within and across regions",
"require a trade-off between either latency or the consistency
model", and AWS's page says regions never replicate for you. The
budget rule the terraform chapters follow: cross-zone calls are a
per-request cost, cross-region calls are a data policy.

#diagram([placing a workload, one region choice, three failure-domain budgets], length: 13pt, {
  cdraw.rect((0.6, 8.4), (5.0, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((2.8, 9.45), [a workload], wrap: text.with(size: 6pt))
  cdraw.content((2.8, 8.75), [needs a home], wrap: text.with(size: 6pt))
  cdraw.line((5.0, 9.1), (6.2, 9.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.2, 8.4), (13.4, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((9.8, 9.45), [choose the region:], wrap: text.with(size: 6pt))
  cdraw.content((9.8, 8.75), [users, services, law], wrap: text.with(size: 6pt))
  cdraw.line((9.8, 8.4), (9.8, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.2, 5.8), (13.4, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((9.8, 6.85), [how wide is the], wrap: text.with(size: 6pt))
  cdraw.content((9.8, 6.15), [failure domain?], wrap: text.with(size: 6pt))
  cdraw.line((6.2, 6.0), (3.1, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.8, 5.8), (9.6, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.4, 6.0), (17.1, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.6, 2.6), (5.6, 5.0), fill: luma(205), radius: 0.02)
  cdraw.content((3.1, 4.45), [one zone: zonal], wrap: text.with(size: 6pt))
  cdraw.content((3.1, 3.8), [resource, dies], wrap: text.with(size: 6pt))
  cdraw.content((3.1, 3.15), [with the zone], wrap: text.with(size: 6pt))
  cdraw.rect((6.6, 2.6), (12.6, 5.0), fill: luma(215), radius: 0.02)
  cdraw.content((9.6, 4.45), [across zones:], wrap: text.with(size: 6pt))
  cdraw.content((9.6, 3.8), [one zone fails,], wrap: text.with(size: 6pt))
  cdraw.content((9.6, 3.15), [the rest answer], wrap: text.with(size: 6pt))
  cdraw.rect((13.6, 2.6), (20.6, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 4.45), [across regions:], wrap: text.with(size: 6pt))
  cdraw.content((17.1, 3.8), [one region fails,], wrap: text.with(size: 6pt))
  cdraw.content((17.1, 3.15), [data survives], wrap: text.with(size: 6pt))
  cdraw.content((10.6, 1.9), [aws: zones up to 60 miles apart, single-digit ms links], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.6, 1.15), [google: each zone is one logical failure domain], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.6, 0.45), [no resource replicates itself across regions], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("pitfall", "us-east-1a is not a place", [
  "For accounts created before November 2025, in our oldest Regions,
  we independently map Availability Zones to codes for each AWS
  account", so the same code can denote a different physical zone in
  another account. The stable identity is the AZ ID, "the same
  physical location in every AWS account", shaped like use2-az1. The
  page also admits constrained zones exist, so "your account might
  have a different number of available Availability Zones in a Region
  than another account does". Terraform that reasons about physical
  separation from zone codes alone is guessing across account
  boundaries; AZ IDs are the coordinate system.
])

== shared responsibility

AWS states the split in one sentence: "Security and Compliance is a
shared responsibility between AWS and the customer", a division the
page calls Security "of" the Cloud versus Security "in" the Cloud.
Of the cloud is AWS's side, "protecting the infrastructure that runs
all of the services offered in the AWS Cloud", infrastructure
"composed of the hardware, software, networking, and facilities that
run AWS Cloud services". In the cloud is yours, and its size is not
fixed: "Customer responsibility will be determined by the AWS Cloud
services that a customer selects." The page's two examples are the
gradient in miniature. For iaas like ec2 the customer manages "the
guest operating system (including updates and security patches)";
for abstracted services like s3 and dynamodb, "Customers are
responsible for managing their data (including encryption options),
classifying their assets", and their iam permissions. The line moves
with every managed upgrade: adopting a managed service hands the
patching to the provider and keeps the configuration mistakes for
you.

Google's page starts from the same table and then renames the
relationship. In iaas "the bulk of the security responsibilities are
yours", in saas "we own the bulk of the security responsibilities",
and two rows never move: "the cloud provider always remains
responsible for the underlying network and infrastructure", and
"customers always remain responsible for their access policies and
data". Then the turn: "Instead of shared responsibility, we believe
in shared fate", which "builds on the shared responsibility model"
and "focuses on how all parties can better interact to continuously
improve security". The stated motive is blunt: "Most cloud security
breaches are the direct result of misconfiguration", so Google
commits to secure defaults and shared tooling rather than a clean
liability boundary. Marketing or engineering, the two fixed rows are
the operational truth for the terraform chapters: the provider never
takes your access policy and never takes your data.

That is why the cloud chapters spend more ink on identity than on
compute. Chapter 25's iam role and chapter 26's bindings sit on the
customer side of every row, and so do the bucket policy and the
firewall rules. Identity is the part of the stack no rung ever
absorbs, the one band that survives every managed upgrade on the
customer side of the line.

#diagram([the same stack one managed step apart, and where the responsibility line sits in each], length: 13pt, {
  cdraw.content((4.6, 8.5), [iaas: ec2, chapter 25], wrap: text.with(size: 6.5pt))
  cdraw.content((16.4, 8.5), [managed: s3, chapter 25], wrap: text.with(size: 6.5pt))
  let left = (("your application", 7.4, true), ("guest os you patch", 6.4, true), ("virtualization", 5.4, false), ("servers", 4.4, false), ("network", 3.4, false), ("power, facilities", 2.4, false))
  for (t, y, mine) in left {
    let f = if mine { luma(205) } else { luma(235) }
    cdraw.rect((0.8, y - 0.4), (8.4, y + 0.4), fill: f, radius: 0.02)
    cdraw.content((4.6, y), t, wrap: text.with(size: 6pt))
  }
  cdraw.line((0.6, 4.9), (8.6, 4.9), stroke: 1.4pt + luma(100))
  let right = (("your data and policy", 7.4, true), ("the storage service", 6.4, false), ("servers", 5.4, false), ("network", 4.4, false), ("power, facilities", 3.4, false))
  for (t, y, mine) in right {
    let f = if mine { luma(205) } else { luma(235) }
    cdraw.rect((12.6, y - 0.4), (20.2, y + 0.4), fill: f, radius: 0.02)
    cdraw.content((16.4, y), t, wrap: text.with(size: 6pt))
  }
  cdraw.line((12.4, 6.9), (20.4, 6.9), stroke: 1.4pt + luma(100))
  cdraw.line((8.9, 5.4), (12.1, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.5, 4.6), [one managed], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((10.5, 3.95), [step up], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((10.5, 1.9), [aws: security of the cloud versus in the cloud], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.5, 1.15), [google: access policies and data always stay yours], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.5, 0.45), [the line moves with every managed upgrade], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== well-architected pillars

AWS frames its framework as a decision aid, not a scorecard: it
"helps you understand the pros and cons of decisions you make while
building systems on AWS", and "The process for reviewing an
architecture is a constructive conversation about architectural
decisions, and is not an audit mechanism." The framework document is
dated November 6, 2024, and the pillars page says it is "Built
around six pillars": operational excellence, "running and monitoring
systems, and continually improving processes and procedures";
security, "protecting information and systems"; reliability,
workloads "performing their intended functions and how to recover
quickly from failure to meet demands"; performance efficiency,
"structured and streamlined allocation of IT and computing
resources"; cost optimization, "avoiding unnecessary costs"; and
sustainability, "minimizing the environmental impacts of running
cloud workloads".

Google's framework lives at the architecture framework URL, but the
page as fetched is titled Google Cloud Well-Architected Framework,
and the rebrand is itself a fact: it recommends how to "design and
operate a cloud topology that's secure, efficient, resilient,
high-performing, cost-effective, and sustainable". It also counts
six pillars: operational excellence, to "efficiently deploy,
operate, monitor, and manage your cloud workloads"; security,
privacy, and compliance, to "maximize the security of your data and
workloads in the cloud, design for privacy, and align with
regulatory requirements"; reliability, to "design and operate
resilient and highly available workloads in the cloud"; cost
optimization, to "maximize the business value of your investment in
Google Cloud"; performance optimization, to "design and tune your
cloud resources for optimal performance"; and sustainability, to
"build and manage cloud workloads that are environmentally
sustainable". Two cross-pillar perspectives sit beside them, ai and
ml plus financial services, and the page adds five core principles:
design for change, document your architecture, simplify by
preferring managed services, decouple the architecture, and keep it
stateless.

Side by side the lists rhyme: same first pillar, same last pillar,
the same six topics wearing two names. The differences are naming
and order. Google's security pillar is "security, privacy, and
compliance" where AWS stops at "security"; Google says performance
"optimization" where AWS says performance "efficiency"; and the
middle two swap, AWS runs performance before cost, Google runs cost
before performance. For a book that provisions both clouds from one
terraform tree the rhyming is the useful part: the checklist is one
checklist, and chapter 27 grades both providers against it.

#diagram([the two six-pillar frameworks side by side, connectors pairing shared topics, the crossing pair marking the order swap], length: 13pt, {
  cdraw.content((11.4, 9.6), [same six topics, two names differ, the middle pair swaps order], wrap: text.with(size: 6.5pt))
  cdraw.content((5.4, 9.05), [aws well-architected], wrap: text.with(size: 6.5pt))
  cdraw.content((16.4, 9.05), [google cloud well-architected], wrap: text.with(size: 6.5pt))
  let aws = (("operational excellence", 8.0), ("security", 6.75), ("reliability", 5.5), ("performance efficiency", 4.25), ("cost optimization", 3.0), ("sustainability", 1.75))
  for (t, y) in aws {
    cdraw.rect((1.0, y - 0.45), (9.8, y + 0.45), fill: luma(235), radius: 0.02)
    cdraw.content((5.4, y), t, wrap: text.with(size: 6pt))
  }
  cdraw.rect((12.0, 7.55), (20.8, 8.45), fill: luma(235), radius: 0.02)
  cdraw.content((16.4, 8.0), [operational excellence], wrap: text.with(size: 6pt))
  cdraw.rect((12.0, 5.75), (20.8, 7.45), fill: luma(245), radius: 0.02)
  cdraw.content((16.4, 6.93), [security, privacy,], wrap: text.with(size: 6pt))
  cdraw.content((16.4, 6.28), [and compliance], wrap: text.with(size: 6pt))
  let singles = (("reliability", 4.85), ("cost optimization", 3.55), ("performance optimization", 2.25), ("sustainability", 0.95))
  for (t, y) in singles {
    cdraw.rect((12.0, y - 0.45), (20.8, y + 0.45), fill: luma(235), radius: 0.02)
    cdraw.content((16.4, y), t, wrap: text.with(size: 6pt))
  }
  cdraw.line((9.8, 8.0), (12.0, 8.0), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((9.8, 6.75), (12.0, 6.6), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((9.8, 5.5), (12.0, 4.85), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((9.8, 4.25), (12.0, 2.25), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((9.8, 3.0), (12.0, 3.55), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((9.8, 1.75), (12.0, 0.95), stroke: (paint: luma(140), dash: "dashed"))
})

sources: NIST SP 800-145 (September 2011), full text from the
nvlpubs.nist.gov PDF; the AWS Well-Architected Framework welcome
page (framework document dated 2024-11-06) and the pillars page at
aws.amazon.com/architecture/well-architected; the AWS Regions and
Availability Zones guide (aws-regions-availability-zones,
aws-regions, aws-availability-zones under docs.aws.amazon.com
global-infrastructure), the AWS Fault Isolation Boundaries
whitepaper, the AWS Global Infrastructure page (the 124 zones, 39
regions count), the AWS shared responsibility model page, and "What
is AWS Lambda"; Google Cloud "Geography and regions", the Google
Cloud Well-Architected Framework overview at
cloud.google.com/architecture/framework, its security pillar page,
and "Shared responsibilities and shared fate on Google Cloud". All
accessed 2026-09-12. Documentation-verified only: this chapter ships
no samples, no terraform binary exists in this corpus, and nothing
was initialized, planned, or applied.
