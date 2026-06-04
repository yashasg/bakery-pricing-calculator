# Skill: Ask "Where Does the Data Go?" Before Choosing an Observability Architecture

**Author:** Tesla (Lead / Architect)
**Created:** 2026-05-20T18:50:53-07:00
**Trigger:** Any proposal to add metrics, analytics, telemetry, counters, timers, or observability infrastructure to a product.

---

## The Pattern

Before evaluating any observability *vocabulary* (which library, which API, which naming scheme), ask the data-sink question:

> **"If a user opted in and data flowed, where would it land — and who would read it?"**

If you cannot answer this question concretely, the architecture is incomplete regardless of how elegant the vocabulary layer is.

---

## Why This Matters

An observability vocabulary without a reachable sink is a development tool, not analytics. It can validate code paths locally, but it cannot answer product questions about real users. The sink is the purpose.

Common failure mode: teams design a clean façade (pluggable handlers, well-named counters, type-safe dimensions) but ship with a NoOp backend "for now." The counters run in production. Nobody ever reads them. The vocabulary investment is wasted, and the product never learns anything.

A secondary failure mode: teams bolt on the first available exporter (StatsD, Firebase, an OTel endpoint) without asking whether the data-at-rest location matches the product's privacy contract.

---

## How to Apply

When a new observability proposal arrives, answer four questions before proceeding to implementation:

| Question | What a good answer looks like |
|----------|-------------------------------|
| **1. Sink location** | A named, developer-accessible destination: "App Store Connect Analytics," "Grafana at analytics.example.com," "local lldb session only" |
| **2. Who reads it** | A named role with a concrete action: "the developer checks monthly for verdict-distribution drift; if `row-off-only` < 5%, de-emphasise the row-axis display" |
| **3. Who controls the upload** | "The OS, on its schedule (MetricKit)" vs. "our code, on every request (URLSession)" — these have different privacy and review implications |
| **4. What happens if the answer to 1 or 2 is 'nobody'** | If nobody reads the data, drop the signal. Don't instrument for the sake of instrumentation. |

---

## Decision Hierarchy

```
Does a real sink exist?
  └─ NO → Do not adopt the vocabulary yet. Define the sink first.
  └─ YES → Is the sink's data-at-rest contract compatible with the privacy posture?
       └─ NO → Amend the privacy posture (written decision) or choose a different sink.
       └─ YES → Is the upload path developer-initiated or system-mediated?
            └─ Developer-initiated → Requires explicit §2.3 carve-out + endpoint naming
            └─ System-mediated (OS controls upload) → Permitted under MetricKit carve-out
```

---

## Applied Example — KGR Issue #9

| Proposal | Sink | Verdict |
|---------|------|---------|
| swift-metrics V1/V2, NoOp default | None in production — counters count but never surface | REJECTED: vocabulary without a sink |
| swift-metrics + StatsD exporter | Developer-controlled UDP endpoint | REJECTED: violates §2.3 (developer code opens socket) |
| MetricKit (`MXSignpost` + `MXMetricPayload`) | App Store Connect Analytics (OS-mediated, user opt-in) | ACCEPTED: system-mediated, privacy-compliant, real developer-accessible destination |
| MetricKit + developer endpoint (optional v2) | Developer-operated HTTPS server | DEFERRED: requires named URL + retention policy amendment before implementation |

---

## Reuse Guidance

- **Works for:** Any "should we add metrics/telemetry/counters?" decision.
- **Works for:** Evaluating whether an existing metrics investment is delivering value.
- **Works for:** Choosing between competing observability frameworks (ask: which one has a sink I can actually use?).
- **Does not replace:** Privacy analysis, cardinality budgeting, naming conventions. Those are downstream of the sink decision.
