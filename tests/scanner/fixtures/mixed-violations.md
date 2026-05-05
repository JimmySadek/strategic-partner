# Mixed Violations — Cross-Class Trigger Fixture

A purpose-built fixture exercising multiple rule classes simultaneously:
S1 (size) + S2 (layer violation: Decisions Log) + S3 (broken paths) +
B5 (rule without worked example) + B6 (enforceability catalog) +
B7 (rule duplication). Used to verify the scanner's cross-class
behavior end-to-end. Sized into the warn band (~25K-30K chars).

## Project Facts

- A test project demonstrating mixed-class scanner detections.
- Multiple sub-systems with distinct concerns.
- Every rule below is intentionally engineered to fire one or more rules.

## Decisions Log

A long decision-log shape section that fires S2 layer-violation
detection because of dated entries with `**Decision N:**` headers.

### **Decision 1: Adopt YAML configs**

[2025-01-15] Decided to migrate from XML to YAML. Rationale: YAML's
indentation-based syntax is easier for engineers to read and write,
and the existing parser ecosystem in our stack is more mature for
YAML than for XML. Trade-off: YAML's whitespace sensitivity can
create subtle bugs that engineers must learn to recognize.

### **Decision 2: Single primary database**

[2025-02-22] Decided to use a single Postgres primary instead of
multi-master replication. Rationale: multi-master adds operational
complexity that doesn't pay off at our scale. Trade-off: write
throughput is bounded by primary capacity until we shard.

### **Decision 3: Adopt the saga pattern**

[2025-03-08] Decided to use sagas for cross-service workflows.
Rationale: distributed transactions don't work across our service
boundaries; sagas give us recoverable workflows. Trade-off: every
saga step needs an explicit compensating action.

### **Decision 4: Standardize on TypeScript**

[2025-04-19] Decided to migrate the platform team's Node.js services
from JavaScript to TypeScript. Rationale: type safety catches
classes of bugs at compile time. Trade-off: build pipeline complexity.

### **Decision 5: Consolidate logging**

[2025-05-30] Decided to ship all logs to a single observability
backend. Rationale: split logs slow down incident triage. Trade-off:
single-vendor dependency for a critical capability.

### **Decision 6: Adopt feature flags**

[2025-06-12] Decided to gate all user-facing changes behind feature
flags. Rationale: faster recovery from bad changes via flag flip
instead of code rollback. Trade-off: feature-flag debt accumulates
if we don't actively retire flags.

## Broken Path References (S3 Part A trigger)

This section references files that intentionally don't exist in the
project, demonstrating S3 broken-path detection. Each entry should
fire S3 because the path resolves to nothing.

See [`claudedocs/nonexistent-architecture.md`](claudedocs/nonexistent-architecture.md)
for the architecture overview.

See [`claudedocs/missing-runbook.md`](claudedocs/missing-runbook.md) for
operational procedures.

See [`./removed-doc.md`](./removed-doc.md) for the rationale behind
the recent migration.

## Removed Features (S3 Part B trigger)

These references describe features that the project once had but no
longer implements anywhere. S3 Part B should detect each as a removed
feature with no corresponding implementation.

The `legacy-xml-parser` was removed in v3 — see CHANGELOG entry from
March 2025. We previously supported `xml-config-bridge` for
backward compatibility, but that's also been retired.

The deprecated `magic-debug-flag` env var no longer activates anything.
The `experimental-quic-transport` experiment was retired without
graduating to general availability.

## Behavioral Guardrails

When editing source files in this project:

  1. **Surgical Changes** → touch only what was asked
  2. **Verification, not Specification** → declarative outcomes

### Surgical Changes

Touch only what the user asked for. Don't refactor adjacent code while
fixing a specific bug. Match the file's existing style. Diff
discipline at every changed line. (Note: this rule is duplicated
below to trigger B7 cross-rule duplication detection.)

### Surgical Changes

Touch only what was asked. No drive-by edits. Match the existing
style of the file even if it's not your preference. (Same rule name
as above; triggers B7 cross-rule deduplication detection within the
same file.)

### No `console.log` in production

No `console.log` calls in production code. No `print()` calls either.
Max line length 100. (B6 lint-detectable category trigger.)

### Pre-commit safety

Never commit secrets. No `.env` files in commits. All commits must
pass tests. Block commit if linter fails. (B6 pre-commit-hook-detectable
category trigger.)

### Always use prettier for JS

Always use prettier for JS and TS files. Tabs vs spaces: 2-space indent.
Consistent spacing across files. (B6 format-style-enforcement category
trigger.)

### Rule Without Example

This rule is named here but has no worked example, no anti-pattern,
no corrected approach. The body is just descriptive prose without
the canonical example structure. B5 should fire because the rule
declares intent without showing how to apply it.

The principle behind this rule is that all rules need worked examples
to be actionable. Without an example, the rule is just words.

## Long Narrative Section

A multi-paragraph narrative that pads file size into the S1 warn band.
The content is intentionally verbose so the file's char count exceeds
the soft band threshold and triggers a size-breach finding.

Distributed systems present operational challenges that are unfamiliar
to engineers coming from monolithic architectures. The complexity
arises from the need for multiple processes to coordinate over an
unreliable network where messages can be lost, delayed, or duplicated
in arbitrary ways. Engineers must reason about partial failures, where
some components are healthy and others are not, and design their
systems to remain functional in those degraded states.

Consensus algorithms like Raft and Paxos provide a foundation for
coordinating state across multiple nodes. These algorithms are
notoriously subtle, and most teams should use battle-tested
implementations rather than building their own. The cost of a subtle
consensus bug is high — silent data corruption, split-brain scenarios,
or service unavailability under specific failure modes that take
weeks to diagnose. The trade-off when using a third-party
implementation is loss of fine-grained control over the algorithm's
behavior; teams must understand the implementation's assumptions and
operational requirements deeply.

Replication strategies fall into several categories: synchronous
replication, where the primary waits for replicas to acknowledge
before confirming a write; asynchronous replication, where the
primary responds immediately and replicas catch up later; and
quorum-based replication, where a write is confirmed once a majority
of replicas have acknowledged. Each strategy trades off latency,
durability, and availability differently. Synchronous replication
gives the strongest durability but adds latency proportional to the
slowest replica; asynchronous replication gives the lowest latency
but tolerates data loss on primary failure; quorum-based replication
strikes a middle ground but requires careful capacity planning.

Partitioning is the process of dividing data across multiple machines
to scale beyond a single machine's capacity. The choice of partition
key determines query patterns, hot-spot behavior, and resharding
flexibility. A poor partition key leads to skewed loads where one
partition becomes the bottleneck while others are idle. A good
partition key distributes load evenly and aligns with the most
common query patterns so that queries hit a single partition rather
than fanning out across all partitions.

Consistency models describe what guarantees a system makes about the
ordering and visibility of operations. Strong consistency models like
linearizability provide the most intuitive semantics — operations
appear to happen in a single global order — but they require
coordination that limits scalability. Weaker models like eventual
consistency give up on global ordering in exchange for higher
throughput and availability. Most real-world systems use a mix:
strong consistency for critical paths like payments, weaker models
for less critical paths like recommendation feeds.

The CAP theorem asserts that in the presence of network partitions,
a distributed system cannot simultaneously guarantee both consistency
and availability. The theorem is often misunderstood as saying
systems are either CP or AP; in reality, systems make different
trade-offs along the spectrum based on which operations they're
performing and what guarantees those operations need. A system can
be CP for some queries and AP for others, depending on how its
designers prioritized requirements for each query.

Failure detection is harder than it sounds. The fundamental problem
is that you cannot distinguish a slow node from a dead node by
looking at it from the outside. Heartbeat-based detection has
parameters — the heartbeat interval and the timeout threshold — that
trade off detection latency against false-positive rate. Quorum-based
failure detection improves on simple heartbeats by requiring multiple
observers to agree on a node's health, reducing false positives at
the cost of increased complexity. Phi-accrual failure detectors
adapt their thresholds based on observed network conditions.

Time is another source of subtlety in distributed systems. Wall
clocks across machines are not synchronized to high precision; even
with NTP, clocks can skew by tens of milliseconds. Logical clocks
like vector clocks or hybrid logical clocks give a partial ordering
that's robust to clock skew but doesn't correspond to wall-clock
time. Many distributed systems bugs come from assuming wall-clock
time can be used for ordering when it can't.

Idempotency is a key property for handling retries. An idempotent
operation produces the same result whether it's applied once or many
times. In a distributed system where retries are unavoidable, every
operation that crosses a network boundary should be idempotent so
that retries are safe. Achieving idempotency often requires the
operation to carry a unique identifier so that downstream systems
can deduplicate.

The end-to-end principle suggests that reliability should be
implemented at the highest layer where it makes sense. Lower-layer
reliability mechanisms are often unnecessary because higher layers
must implement their own end-to-end checks anyway. This principle
informs choices like whether to use TCP or UDP, whether to require
HTTPS or rely on application-level encryption, and how much
durability to require from intermediate services.

Observability is a meta-concern that cuts across all of the above.
A distributed system that cannot be observed cannot be debugged.
Logs, metrics, and traces are the three pillars; each provides a
different view of system behavior, and a mature observability
practice combines all three. Distributed tracing is particularly
valuable because it shows the causal chain of operations across
services, making it possible to diagnose latency issues that span
multiple service hops.

Capacity planning in distributed systems requires forecasting both
average load and peak load, plus headroom for unexpected spikes.
The headroom percentage depends on the cost of running excess
capacity versus the cost of running out. For latency-sensitive user-
facing services, the headroom is typically larger; for batch
processing where queue depth is acceptable, the headroom can be
smaller. The forecast itself should be based on actual measured
growth rather than business projections, with a validation cycle
that compares forecast to reality each quarter.

Cost optimization is a constant tension in distributed systems.
Every reliability improvement adds cost — additional replicas, more
sophisticated load balancing, larger error budgets. The team must
make explicit trade-offs based on the business value of each
nine of reliability. The marginal cost increases superlinearly as
reliability targets approach 100%; the team must understand at what
point the marginal cost exceeds the marginal value.

## Extra Padding for S1 Size Band

Additional content to push the file size above the S1 warn threshold
so the size-breach rule fires alongside the other class triggers.

### Section A — extended text

Engineers often underestimate how much complexity hides in
distributed systems. The naive view is that a system either works
or it doesn't, and when it doesn't work, you fix the bug and move
on. The reality is that distributed systems exist in a continuous
spectrum of partial functionality where some operations succeed
and others fail in ways that are difficult to predict. The team
operates in this spectrum constantly, making decisions about which
failure modes to tolerate and which to harden against.

Resilience comes from a combination of redundancy, isolation, and
graceful degradation. Redundancy ensures that the failure of any
single component doesn't take down the system. Isolation ensures
that a failure in one component doesn't cascade into others.
Graceful degradation ensures that when partial failures occur, the
system continues to deliver value at reduced capacity rather than
shutting down entirely. Each of these patterns has implementation
costs that the team must weigh against the value of resilience.

### Section B — extended text

Observability is more than dashboards and alerts. A truly observable
system lets engineers ask new questions about its behavior without
deploying new code. This requires structured logging with rich
context, metrics that capture business-level outcomes alongside
infrastructure health, and distributed tracing that connects the
dots across service boundaries. The team has invested heavily in
observability infrastructure because it pays dividends every time
an incident occurs and the on-call engineer can find the root
cause within minutes instead of hours.

The combination of high-cardinality metrics, structured logs, and
end-to-end traces gives the team visibility into specific user
journeys, request paths, and business workflows. When something
goes wrong, the engineer can pinpoint the exact failure mode, the
affected user segments, and the upstream cause. This is the
difference between flailing in the dark and surgical incident
response.

### Section C — extended text

Capacity planning is a discipline that combines forecasting,
measurement, and engineering judgment. The team forecasts traffic
growth quarterly, measures actual load against the forecast, and
adjusts capacity as needed. The forecast accounts for known
business events — product launches, marketing campaigns, seasonal
patterns — and includes headroom for unexpected spikes. The
measurement cadence is daily; the headroom is sized so the team
can respond to surprises without paging on-call engineers.

The capacity model includes not just compute and storage but also
network bandwidth, database connections, queue depth, and other
resource dimensions. Each dimension has its own bottleneck behavior
and recovery characteristics. The team has built dashboards that
show projected utilization across all dimensions, making it easy
to spot upcoming pressure points and intervene before they cause
incidents.

### Section D — extended text

Incident response is a team-wide capability, not just an on-call
function. When a major incident occurs, the team mobilizes the
right combination of expertise — a platform engineer, an
application engineer, a data engineer, and an incident commander —
to coordinate the response. The incident commander focuses on
communication and decision-making while the other engineers focus
on diagnosis and remediation. After the incident, the team conducts
a blameless post-mortem to extract lessons and identify systemic
improvements.

The post-mortem process is structured around a few key questions:
what happened, what was the impact, what was the root cause, what
went well, what didn't go well, and what should change going
forward. The output is a document that gets shared widely so the
whole team learns from the incident. Action items get assigned
owners and target dates. Repeated themes across incidents trigger
architecture-level work to address systemic issues.
