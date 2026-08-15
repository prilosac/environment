---
name: audit-for-simplicity
description: Use when directly asked or when a change or area feels disproportionately large, verbose, defensive, layered, duplicated, hard to explain, or expensive to maintain. Related to code cleanup, first-principles audit, LOC reduction, test-harness simplification, or removal of overengineering.
---

# Audit for simplicity

Audit and simplify code, tests, tooling, or an entire subsystem while preserving member behavior, supported contracts, real trust boundaries, and useful evidence.

Treat code as an ongoing cost. Remove machinery that does not plainly earn its
place through shipped behavior, a real boundary, or evidence used to make a
decision. Do not turn the audit itself into a framework.

## Preserve the right things

Preserve:

- member-visible behavior and the simplest supported mental model;
- released compatibility and externally supported contracts;
- security, consent, authorization, permissions, cleanup, crash recovery,
  packaging, upgrades, and hard resource limits;
- measurements tied to an SLI, graph, gate, operator action, or engineering
  decision; and
- product primitives and ownership boundaries recorded by the repository.

Preserve outcomes, not historical implementation shapes. A strange-looking
file may protect a real boundary, while a polished abstraction may have no
production purpose. Trace both before judging them.

Apply defensive parsing and validation at untrusted boundaries: network input,
IPC, files, permissions, native processes, and durable data. Do not build a
shadow type system around values already typed or reasonably duck-typed
and constructed in-process.

Test each behavior once at the lowest boundary that proves it. Add a broader
test only when it proves a distinct integration, platform contract, or member
journey. Never change production code solely to expose an internal to E2E.

Delete before abstracting. Extract shared code only after two real callers and
a common invariant remain. Similar spelling is not a shared contract, and
future possibility does not justify unused implementation.

## Run the audit

### 1. Name the job and invariants

Before editing, record:

```text
User:
Job:
Supported behavior:
Trust and lifecycle boundaries:
Useful evidence:
Deliberate non-goals:
```

Read `AGENTS.md`, the product primitive that owns the behavior, and the
affected executable journey. Do not infer the system from filenames or the
diff alone.

### 2. Measure the real size

Inventory the requested scope before choosing targets:

- additions and deletions, not only the net diff;
- largest files and directories;
- recent growth and churn when history is relevant;
- test volume relative to the product behavior it proves;
- dependencies and generated code; and
- product, test, tooling, protocol, and documentation shares.

For a pull or change request, compare its base with its current head.
For a global audit, start with repository and subsystem totals, then choose
one bounded area at a time. Do not assume the largest area === the least justified.

### 3. Map the runtime path

Trace the behavior from its real entry point through its owners and side
effects. Identify:

- product and protocol entry points;
- runtime callers and consumers;
- state and lifecycle owners;
- trust boundaries;
- released or documented contracts; and
- tests and metrics that observe the behavior.

Use search as an inventory, then read the call sites. A matching symbol is not
proof of a meaningful caller.

### 4. Trace suspicious machinery

For every questionable export, hook, schema, validator, metric, helper,
feature flag, protocol message, report, field, and test utility, answer:

1. Who calls or consumes it outside its own file and tests?
2. What member behavior, boundary, or decision changes if it disappears?
3. Is that responsibility already owned elsewhere?
4. Is its complexity proportional to the failure it prevents?
5. Could the same proof come directly from an existing primitive or raw
   measurement?

Classify it as:

- shipped behavior;
- necessary trust, safety, compatibility, or lifecycle handling;
- evidence someone actually uses; or
- dead, duplicated, speculative, test-only, or ceremonial machinery.

Delete the fourth category unless current evidence reveals a real invariant.

### 5. Look for recurring smells

Investigate, rather than automatically delete:

- a production hook used only by tests;
- a source file consumed only by its own test;
- a helper advertised as reusable with one real caller;
- validators around locally constructed typed objects;
- string matching used as a shadow enum or type system;
- schemas, versions, hashes, or identity records for ephemeral internal data;
- metrics with no graph, gate, operator, or engineering decision attached;
- bundles, catalogs, lineage, comparison engines, or report formats layered
  over raw test results;
- parallel samplers, models, lifecycle owners, or representations of the same
  thing;
- E2E assertions that duplicate unit or boundary tests;
- broad suites that prove the same journey in multiple CI lanes;
- state machines for a one-shot lifecycle;
- compatibility paths for formats that were never released;
- extensive configuration without a supported use case;
- abstractions whose callers remain mostly ceremony or option plumbing;
- comments and names that describe a plan phase instead of the enduring
  behavior; and
- product code altered only to make internal state inspectable by a test.

### 6. Simplify in bounded passes

Delete dead and redundant machinery before rewriting what remains. Work one
coherent subsystem at a time so failures localize cleanly.

After deletion:

1. Collapse duplicate ownership.
2. Replace internal schemas and string protocols with existing types or direct
   values where no trust boundary exists.
3. Replace evidence packaging with stable scenarios and directly comparable
   raw metrics.
4. Remove tests that no longer prove a distinct fact.
5. Extract only the shared invariants that still have multiple real callers.

Do not exchange one bespoke framework for another. A cleanup that adds a large
new compatibility layer, registry, migration, report model, or generic engine
has probably missed the point.

### 7. Verify after every pass

Run the smallest checks that cover the edited boundary, then exercise the real
journey when behavior could have changed. Follow the repository's normal
verification rules and any task-specific skill.

After each pass:

- inspect the diff by hand;
- recount additions, deletions, files, and largest remaining additions;
- confirm every deleted test was redundant or replaced by stronger evidence;
- check that consent, authorization, cleanup, fallback, packaging, and crash
  behavior remain owned; and
- make sure a negative net diff is not hiding a large replacement system.

## Stop at the right boundary

Stop when every significant remaining piece maps plainly to:

1. shipped member behavior;
2. a real trust, safety, compatibility, or lifecycle boundary; or
3. evidence actively used to judge quality, cost, or operation.

Do not stop merely because the diff is net-negative or a target LOC number was
reached. If a substantial surviving area is awkward to justify in those terms,
audit it again.

## Hand off the result

Report:

```text
Scope and preserved invariants:
Gross additions / deletions / net:
Files removed or collapsed:
Product machinery retained and why:
Safety or compatibility machinery retained and why:
Evidence retained and who uses it:
Tests removed, retained, or moved to a lower boundary:
Verification run:
Known gaps or follow-up areas:
```

Keep the report concrete. Do not claim simplification from LOC alone, and do
not claim behavior or safety was preserved without matching evidence.
