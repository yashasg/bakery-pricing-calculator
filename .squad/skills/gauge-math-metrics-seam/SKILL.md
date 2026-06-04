# SKILL: gauge-math-metrics-seam

**Slug:** `gauge-math-metrics-seam`
**Author:** Ada
**Date:** 2026-05-20T18:42:54-07:00
**Applicable to:** Any Swift project with a pure-math namespace that must remain
instrumentation-free while supporting caller-side metrics.

---

## Pattern

When you have a pure-function namespace (`enum [DomainMath]`) that must satisfy a
determinism contract, and you need to derive metric signals from its output,
use a **three-layer seam**:

```
[Caller site]
    ↓  clock.now before
[DomainMath].compute(inputs)   ← seam is here; math is pure
    ↓  clock.now after
[[DomainMath]Metrics classifier]  ← pure classifier, separate file
    ↓  bucket labels
[Metrics backend]              ← Counter/Timer increment; never inside math
```

### Rules

1. **Math layer:** `(values) -> values`. No imports for logging or metrics.
   No clock reads. No static mutable state. No closure/callback parameters.

2. **Classifier layer** (`[DomainMath]Metrics.swift`): pure functions over the
   result struct. Returns `enum` bucket labels. No `import Metrics`. Keeps
   observability thresholds separate from domain math.

3. **Caller layer:** owns timing, counting, and bucketing. Reads `ContinuousClock`
   before/after the math call. Passes bucket labels to metric handles.

### Test enforcement

Two tests, owned by the test-engineering role:

**Compile-time (file-scan):**
```swift
@Test func mathLayerImportsNoMetrics() throws {
    let source = try String(contentsOf: mathSourceURL, encoding: .utf8)
    #expect(!source.contains("import Metrics"))
    #expect(!source.contains("import os"))
}
```

**Runtime (MetricsSystem swap):**
```swift
@Test func computeEmitsNoSignals() {
    let factory = RecordingMetricsFactory()
    MetricsSystem.bootstrapInternal(factory)
    defer { MetricsSystem.bootstrapInternal(NOOPMetricsHandler.instance) }
    _ = MathNamespace.compute(inputs)
    #expect(factory.recordedCalls.isEmpty)
}
```

### Sendable note

Ensure input/output types are all-value-type structs. Primitive (`Double`, `Int`,
`String`) stored properties satisfy `Sendable` implicitly in Swift 6, allowing
result structs to cross actor boundaries (e.g. into a metrics `actor`) with no
annotation overhead.

### When to diverge

If the math function family is so hot that even the call-site overhead of
`ContinuousClock` is measurable, omit the timer entirely and rely only on
counters (invocations, bucket labels). The classifier layer and the "no import"
rule still apply.
