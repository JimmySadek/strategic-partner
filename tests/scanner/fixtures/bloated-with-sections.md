# Bloated With Sections

A fixture that exceeds the S1 size band AND has clear H2/H3 section
structure (vs. `bloated-no-sections.md` which lacks structural
divisions). Used to verify S1 + B-class behaviors on a realistically
sized but well-organized CLAUDE.md.

## 🎯 Project Facts

- A reasonably mature project with multiple subsystems.
- Several teams contribute concurrently.
- Built on Bash 3.2 minimum compatibility.
- Targets macOS, Linux, and WSL.

## 📍 Where to Look

| When | Resource |
|---|---|
| Past incidents | `claudedocs/INCIDENTS.md` — full archaeology per incident ID |
| Recent decisions | `claudedocs/DECISIONS.md` — quarterly review log |
| Release history | `CHANGELOG.md` — every released version since v1 |
| Architecture overview | `claudedocs/ARCHITECTURE.md` — system diagrams + component map |

## 🧠 Behavioral Guardrails

When editing source files, follow these principles:

  1. **Think Before Coding** → surface assumptions; reject sycophancy
  2. **Simplicity First** → minimum that solves; nothing speculative
  3. **Surgical Changes** → every line traces directly to the request
  4. **Verification, not Specification** → declarative outcomes

📁 Full rules: [`.claude/rules/source-editing.md`](.claude/rules/source-editing.md)

## ⚙️ Workflows

### Daily build cycle

The team runs the full test suite three times a day. Failures must be
investigated within 4 hours of detection. No commits land while the
suite is red. Build status surfaces in the team Slack channel.

### Weekly release cycle

Every Friday, the release engineer cuts a new tag. The release notes
are auto-generated from the CHANGELOG and posted to the GitHub
Releases page. Communication goes out to all subscribed users.

### Quarterly retrospective

Once a quarter, the team gathers for a half-day retrospective. Topics
include incident learnings, process improvements, technical debt
priorities, and team health. Action items get assigned owners and
target dates, tracked in the next quarter's planning doc.

## 🚧 Provisional Guards

Bug-driven rules. Each guard names the pattern, the past incident
that motivated it, and a date to revisit.

### Don't use legacy XML configs

Instead: use the YAML config schema introduced in v3.

- **Scope**: Configuration files in `config/`.
- **Source**: claudedocs/INCIDENTS.md § INC-2025-04-12 — XML parser bug.
- **Review**: 2026-08-01.

### Don't depend on system clock for ordering

Instead: use monotonic counters.

- **Scope**: Event ordering in the queue subsystem.
- **Source**: claudedocs/INCIDENTS.md § INC-2025-09-22 — clock skew.
- **Review**: 2026-09-15.

## 📋 Detailed Checklist (extra ballast for size)

A long enumerated checklist that pads file size into the S1 warn band.
Each item adds context without restructuring the file.

  1. Verify environment variables are set correctly.
  2. Check that the database connection string points to the right host.
  3. Ensure the cache layer is warm before running performance tests.
  4. Run the linter on any modified files before committing.
  5. Update the CHANGELOG with a one-line entry per release.
  6. Push the release tag to origin so CI picks it up.
  7. Monitor the release dashboard for the first hour post-deploy.
  8. Subscribe to the on-call rotation for the week of the release.
  9. Document any post-release hotfixes in the relevant incident file.
  10. Schedule a release retro within two weeks of every major release.
  11. Ensure all dependencies have CVE scans run within the last 30 days.
  12. Verify the build is reproducible from a clean checkout.
  13. Smoke-test the upgrade path from the previous minor version.
  14. Confirm the rollback playbook has been exercised in the staging environment.
  15. Tag the release artifact with the canonical version string.
  16. Cross-reference the release with the relevant Linear ticket.
  17. Notify the customer success team a week before any breaking changes ship.
  18. Coordinate with the support team for FAQ updates ahead of release.
  19. Validate documentation builds and renders correctly on the docs site.
  20. Archive the previous release artifacts to long-term storage.
  21. Verify metrics dashboards still report correct values post-deploy.
  22. Run a dry-run of the rollback procedure on a recent staging snapshot.
  23. Inspect the deployment logs for warning-level messages worth investigating.
  24. Audit access control for any newly added external endpoints.
  25. Refresh the runbook table of contents if any new procedures landed.
  26. Validate that all third-party integrations still authenticate cleanly.
  27. Review error budgets and decide whether to tighten or relax SLOs.
  28. Pair-review any deletions to shared infrastructure scripts.
  29. Update the post-mortem template if any new failure categories surfaced.
  30. File feedback to the platform team if any tooling bottlenecks were hit.

## 📚 Glossary (extended ballast)

A long-form glossary that expands the file into the S1 warn band.
Each term has a short definition followed by a worked example so the
section is well-structured but takes real space.

### Idempotency

A property of operations such that applying them N times produces the
same result as applying them once. In our queue subsystem, every
message handler is idempotent because retries are unavoidable in
distributed environments. Idempotency keys are derived from the message
content hash plus a logical clock, ensuring uniqueness across retries
even when network conditions cause apparent duplicates.

### Tombstone

A marker indicating a record has been deleted but its identifier must
remain reserved. Tombstones live in a separate index from active
records and are garbage-collected after a quiet period. The quiet
period is calibrated against worst-case clock skew across the fleet
plus a generous safety margin for cross-region replication delays.

### Eventual consistency

A consistency model where reads may temporarily return stale data but
will converge to the correct value within a bounded time window. We
use eventual consistency for non-critical caches and strong consistency
for billing-relevant data paths. The boundary is documented in the
architecture overview and revisited every quarter.

### Saga pattern

A long-running transaction implemented as a sequence of local
transactions, each with a compensating action. Used for cross-service
workflows where a single distributed transaction is impractical.
Saga failures unwind through compensating actions in reverse order.

### Circuit breaker

A protection mechanism that trips after N consecutive failures and
prevents cascading failures by short-circuiting subsequent calls.
Recovery is automatic after a cooldown period and is gated by a
small number of probe requests to confirm health restoration.

### Bulkhead

An isolation boundary that contains failures to a specific subset of
the system. Like ship bulkheads, it prevents one flooded compartment
from sinking the whole vessel. Implemented via thread-pool isolation
in our request handling layer.

### Backpressure

A signal flowing upstream from a slow consumer to indicate that
production should slow down. Without backpressure, fast producers
overwhelm slow consumers and the system collapses under queue depth.
Our pipelines use reactive backpressure throughout.

### Retry budget

A bounded allowance of retries within a time window, preventing
retry storms when downstream services are degraded. Each service
gets its own retry budget calibrated to its expected baseline
failure rate plus headroom.

## 📖 Reading List (more ballast for size band)

Curated readings that contextualize the architectural choices in
this project. Each entry summarizes the work and links to the
canonical source. Useful for new team members getting up to speed.

### Designing Data-Intensive Applications

Foundational reference for distributed systems thinking. Chapters
on consistency, replication, and partitioning shape the design of
our storage layer. The chapter on stream processing aligns with our
event-driven architecture.

### Site Reliability Engineering (the Google book)

Defines SLOs, error budgets, and the practice of balancing reliability
work against feature work. Our on-call rotation derives directly from
this playbook with adjustments for our team size and incident rate.

### Release It! by Michael Nygard

Catalogs failure patterns and stability patterns. Our circuit-breaker
and bulkhead implementations follow the patterns described here.
Required reading before joining the on-call rotation.

### Principles by Ray Dalio

Less technical, more cultural. Frames our team rituals around
radical transparency, idea meritocracy, and weighted-believability
decisions. Influences how we run retrospectives and design reviews.

### Accelerate by Forsgren, Humble, Kim

DORA metrics origin. Drives our deployment frequency, lead time,
change failure rate, and mean time to restore. Quarterly health
checks measure our team against these baselines.

## 📝 Long-Form Notes (ballast)

Free-form notes from the team's working sessions. Kept inline rather
than in a separate file because they cross-reference too many parts
of the system to live somewhere self-contained.

The team has converged on a few key practices over the years. First,
every change must be reviewed by at least one other engineer before
landing. This review is not just for correctness but also for
consistency with team conventions. The reviewer is encouraged to ask
questions, push back, and propose alternatives. The author is
encouraged to defend their choices, but ultimately the bar is "is
this the right change for this codebase right now."

Second, every change must include a test. Tests demonstrate intent
and prevent regressions. The team has internalized that "untested
code is broken code." The exception is genuine experimental work,
where tests would be premature, but those changes don't ship to
production until they're tested.

Third, every change should leave the codebase a little better than
it was found. This doesn't mean refactoring everything in sight —
it means small, surgical improvements that compound over time. Dead
code gets removed. Confusing names get clearer. Implicit invariants
get explicit assertions. The codebase improves by accretion, not by
big-bang rewrites.

Fourth, the team values written communication highly. Decision
documents, design proposals, and retrospective notes all live in a
shared location and are searchable. Future team members benefit
from the trail of reasoning that produced the current state. This
slows things down in the short term but pays off in the long term.

Fifth, the team operates with a strong norm against heroics. If a
problem requires staying up all night to fix, that's a process
failure, not a virtue. The on-call rotation is bounded; nobody is
expected to be reachable 24/7 outside of their on-call window. This
norm protects the team from burnout and forces the system itself to
become more resilient.

Sixth, retrospectives are sacred. Once a quarter the team gathers
to discuss what went well, what didn't, and what to change. The
output is a small number of action items with owners and target
dates. The retro itself is rotated through facilitators so no one
person owns the team's introspection.

Seventh, the team invests in tooling. A 10-minute task that gets
run daily is worth a one-day automation effort. The goal is to
keep the team in flow and minimize context switches between the
problem at hand and the supporting infrastructure.

Eighth, the team prioritizes hiring fit over speed. A bad hire
costs much more than a slow hire. The bar is intentionally high
and consistent. New team members get a structured onboarding that
ramps them up over the first quarter.

Ninth, the team values diversity of thought. Disagreement is not
conflict; it's signal. The norm is to disagree publicly, decide
clearly, then commit fully. Once a decision is made, the team rows
together regardless of individual preferences.

Tenth, the team practices radical candor. Feedback is delivered
directly and respectfully. The goal is to help people grow, not
to win arguments. Public praise, private correction.

## 🔧 Operational Runbooks

A collection of operational procedures covering common maintenance
scenarios. Each runbook is self-contained but cross-references the
relevant architecture section for deeper context.

### Database failover

Failover proceeds in three stages. First, the load balancer is updated
to drain traffic from the primary. Second, the standby is promoted
to primary via the orchestrator's failover command. Third, the new
primary's replication target is reconfigured to point at the now-demoted
old primary. Throughout the procedure, the on-call engineer monitors
the application's error rate and tail latency dashboards. Any anomaly
above the predefined thresholds triggers an immediate rollback.

The rollback procedure mirrors the failover steps in reverse order.
Rollback is always rehearsed during regular failover drills so the
team is comfortable executing it under pressure. The rollback target
is the most recent known-good state of the cluster, captured by the
orchestrator's snapshot system.

After every failover (planned or unplanned), the team conducts a
brief retrospective. The output is captured in the incident log
under the relevant incident ID. Patterns that emerge across multiple
incidents trigger architecture-level work to address root causes.

### Cache invalidation

Cache invalidation is one of the hardest problems in distributed
systems, second only to naming. Our cache layer uses tag-based
invalidation: every cached entry is tagged with one or more semantic
labels, and invalidation operates on tags rather than individual keys.
This decouples the producer of the invalidation signal from knowledge
of every key that might be affected.

The trade-off is that tag-based invalidation can be too coarse — a
single tag invalidation can purge thousands of entries. We mitigate
this with hierarchical tags and a regeneration cost budget.

### Deployment rollback

Rollback is a first-class operation, exercised regularly so it never
atrophies. Every deploy publishes a manifest of the previous version's
artifacts, allowing one-command rollback for any deployment within the
last 30 days. The rollback procedure is documented inline with the
deploy command's help text so on-call engineers can find it under
pressure.

### Secret rotation

Secrets rotate on a 90-day schedule with a 14-day overlap window
allowing both old and new secrets to be valid simultaneously. The
rotation is automated via the secret manager's rotation policy.
Manual rotation is available for emergency response when a leak
is suspected.

## 📊 Metrics & Observability

Our observability stack covers four layers: infrastructure, platform,
application, and business. Each layer has its own dashboards, alerting
thresholds, and ownership.

### Infrastructure metrics

CPU, memory, disk, network — the classic four. Collected at one-second
resolution and downsampled to one-minute over time. Alerts trigger
on thresholds calibrated against historical baselines. The alert noise
is regularly tuned to keep signal-to-noise above the team's tolerance.

### Platform metrics

Container metrics, orchestrator events, network policies. These
metrics surface platform-level issues before they cascade into
application-level outages. The platform team owns these dashboards
and alerts.

### Application metrics

Request rate, error rate, latency percentiles. The RED method (Rate,
Errors, Duration) covers the most important signals for service
health. Alerts trigger on burn rate against the SLO budget.

### Business metrics

Conversion rates, revenue, user engagement. These metrics are owned
by product, not engineering, but engineering ensures the data
pipeline is reliable.

## 🛡️ Security Posture

A summary of the project's security baseline, threat model, and
mitigation strategies. The full threat model lives in
`claudedocs/threat-model.md`; this section is a high-level overview
intended to orient new team members during onboarding.

### Authentication

We use OAuth 2.0 with PKCE for user-facing authentication. Service-to-
service calls use mutual TLS with short-lived certificates rotated
hourly. Internal admin tooling uses hardware security keys for
multi-factor authentication; passwords alone are not accepted for
admin access.

### Authorization

Authorization is policy-based using a centralized policy decision
point. Policies are defined in declarative form and version-controlled
alongside code. Every authorization decision is logged for audit
purposes. The audit log is immutable and ships to a separate
security-owned data store.

### Secrets management

All secrets live in a dedicated secret manager with role-based
access control. No secrets are checked into version control. The
build pipeline injects secrets at deploy time only. Local development
uses dummy secrets generated by a developer-friendly seed script.

### Vulnerability management

Dependency vulnerabilities are scanned daily by the supply-chain
security tool. Critical vulnerabilities trigger immediate patches.
High-severity vulnerabilities have a 7-day SLA for remediation.
Medium and low vulnerabilities are batched into the next regular
release cycle.

### Incident response

Security incidents follow a defined playbook with clear escalation
paths and communication templates. The on-call rotation includes
security-specialist coverage during business hours. Outside business
hours, the standard on-call rotation handles initial triage and
escalates to security as needed.

## 🚀 Performance Engineering

Performance is treated as a first-class concern. Every release is
load-tested against a production-traffic-shaped workload before
shipping. Regression budgets are enforced via CI gates.

### Latency budgets

Each service has a documented latency budget. The budget is broken
down by percentile (p50, p95, p99) and across geographic regions.
Budget violations trigger investigation; persistent violations
trigger architecture-level work to address root causes.

### Capacity planning

Capacity planning is quarterly. The team forecasts traffic growth
based on business projections and provisions infrastructure with a
30% headroom over expected peak. Quarterly reviews adjust the
forecast based on actual growth.

### Profiling cadence

Production profiling runs continuously with a low-overhead sampling
profiler. Profile data is aggregated into flame graphs that are
inspected weekly. Hot paths above a CPU usage threshold trigger
deeper investigation.

## 🎓 Onboarding

New team members get a structured first quarter. Week one focuses
on environment setup and reading the architecture documents. Weeks
two through four pair the new team member with an experienced
engineer for shadowed work. The remaining nine weeks ramp into
independent work with regular check-ins.

## 🌍 Multi-Region Considerations

Operating across regions adds latency and consistency challenges.
Our approach is region-aware routing for read traffic and a
single-writer-per-shard model for writes. Cross-region replication
is asynchronous with bounded staleness commitments.

### Region selection

Users are routed to the nearest region with healthy capacity. If
the nearest region is degraded, traffic shifts to the next nearest
region. The shift is graceful — connections are drained, not
abruptly terminated.

### Cross-region latency

P99 cross-region latency is around 80-120ms depending on the
specific region pair. We design APIs assuming this latency floor
and avoid synchronous cross-region calls in hot paths.

### Replication lag

Replication lag is monitored continuously. Lag above 500ms triggers
a warning; above 5s triggers a page. The team's playbook for high
replication lag is documented in `claudedocs/replication-runbook.md`.

### Disaster recovery

Each region runs as a hot standby for at least one other region.
Annual disaster recovery drills exercise the failover procedure
including data loss assessment, application reconfiguration, and
client redirection.

## 📐 Coding Standards

The team has converged on a small set of coding standards over time.
These standards are not enforced by automated tooling alone; they're
enforced by review culture. New team members internalize them through
the review process during onboarding.

### Naming conventions

Files: kebab-case. Variables: camelCase in JS, snake_case in Python.
Constants: SCREAMING_SNAKE_CASE. Types/classes: PascalCase. The
team has standardized on these even when the language community
allows other choices.

### Comment policy

Comments explain WHY, not WHAT. The code itself should make WHAT
self-evident. Comments are reserved for non-obvious design decisions,
references to external context (RFCs, papers, incidents), and
warning future maintainers about subtle invariants.

### Error handling

Errors are values, not exceptions. Even in languages that support
exceptions, we prefer error-as-value patterns where they fit.
Callers must explicitly handle or propagate errors. Catch-all
handlers are forbidden outside well-defined boundaries.
