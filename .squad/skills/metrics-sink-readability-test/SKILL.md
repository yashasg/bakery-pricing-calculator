# SKILL: metrics-sink-readability-test

**Slug:** `metrics-sink-readability-test`
**Author:** Mendel (User Researcher)
**Date:** 2026-05-20T18:42:54-07:00
**Applicable to:** Any project scoping on-device instrumentation signals
(counters, timers, gauges) for an app with no off-device upload and an
ephemeral (in-process-only) metrics sink.

---

## Pattern

Before calling a signal a "research question worth instrumenting," apply the
**sink readability test**. Ask: given the actual storage architecture for
the metrics sink, can this signal be read and acted on?

### Two signal classes

**Class A — Developer-session signals** (answerable from a single attached
session without cross-session aggregation):
- Timer/latency checks (e.g., first-use time-to-result)
- Regression alarms with a clear numerical pass/fail criterion
- "Did this code path fire at all?" (one session, yes/no)

These are meaningful even in an ephemeral in-process-only sink. A developer
attaches Xcode, runs the app, reads the counter/timer in MetricsStore. One
session is enough.

**Class B — Cross-session behavioral signals** (require accumulation across
multiple launches to draw a conclusion):
- Frequency distributions (which scenario branch is most common?)
- Engagement rates (how often does the user open help?)
- Labelling confusion (which field gets re-edited across sessions?)
- Persona hypothesis validation (does this user path exist at all?)

These are NOT meaningful in an ephemeral sink that clears state on every
launch. They require either: (a) a persistent local store, or (b) a
developer-initiated diagnostics export action, or (c) a cross-device
aggregation backend (usually out of scope for privacy reasons).

### Application

1. List proposed signals.
2. Classify each as Class A or Class B.
3. For Class A: the signal is research-grade in the current architecture.
   Ship it.
4. For Class B: the signal is a vocabulary placeholder and dogfooding hint
   only. Label it explicitly as "deferred pending a read path." Do not claim
   it answers a research question until a persistent store or diagnostics
   export exists.
5. Document the gap in the decision record so it is not silently forgotten.

### Example classification (BakeryPricingCalculator issue #9)

| Signal | Class | Meaningful without persistent store? |
|---|---|---|
| First-use latency timer (Q3) | A | YES |
| Scenario distribution (Q1) | B | NO — needs cross-session counts |
| Cast-on path reach (Q2) | B | NO — needs cross-session counts |
| Field churn (Q4) | B | NO — needs cross-session counts |
| Verdict-help opens by state (Q5) | B | NO — needs cross-session counts |

### Recommended framing in decision records

For Class B signals in ephemeral sinks, write:
> "This counter instruments the `X` event. It is a vocabulary placeholder
> and developer dogfooding signal. It becomes a research signal when a
> diagnostics export or persistent local store exists. Do not cite this
> counter as evidence of user behavior until that read path is in place."

---

## Anti-patterns

- Calling all instrumented counters "research signals" regardless of
  whether the sink makes them readable.
- Treating dogfooding (developer = subject) as equivalent to user research.
- Claiming behavioral conclusions from a sample of 1 (developer's own
  device, single session).
- Adding a persistent store "just for metrics" without an explicit privacy
  decision — the moment metrics survive process death, the privacy posture
  changes and the decision record must reflect it.

---

## Related skills

- `swift-debug-double-gate` — compile-time and runtime gating of metrics
  call sites to ensure release builds contain no instrumentation.
