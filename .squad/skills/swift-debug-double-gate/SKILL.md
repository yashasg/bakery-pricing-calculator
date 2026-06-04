# SKILL: swift-debug-double-gate

**Slug:** `swift-debug-double-gate`
**Author:** Edison
**Date:** 2026-05-20T18:42:54-07:00
**Applicable to:** Any Swift/SwiftUI project that needs on-device debug
instrumentation (counters, timers, signal handlers) to be completely absent
from release builds, and also inert by default in DEBUG builds (e.g. not
firing during automated UI tests).

---

## Pattern

Use a **double gate** at every metric call site and at the bootstrap site:

```
Gate 1 (compile-time): #if DEBUG
    Gate 2 (runtime):  env["KGR_METRICS_ENABLED"] == "1"
        → emit metric
```

### Bootstrap site (App init)

```swift
@main
struct YourApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["KGR_METRICS_ENABLED"] == "1" {
            MetricsSystem.bootstrap(InMemoryMetricsHandler())
        }
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

Place bootstrap in `App.init()`, not in `View.body` or `WindowGroup`. This
guarantees the handler is registered before any `.onChange` or action closure
can fire. The `@main` singleton ensures `init()` is called exactly once per
process — no additional idempotency guard required.

### Call site (action closure or .onChange)

```swift
Button("Reset", action: {
    doReset()
    #if DEBUG
    if ProcessInfo.processInfo.environment["KGR_METRICS_ENABLED"] == "1" {
        Counter(label: "reset.tapped").increment()
    }
    #endif
})
```

Or factor the check into a helper to avoid repetition:

```swift
// DebugMetrics.swift — compiled only in DEBUG
#if DEBUG
enum DebugMetrics {
    private static var enabled: Bool {
        ProcessInfo.processInfo.environment["KGR_METRICS_ENABLED"] == "1"
    }
    static func increment(_ label: String, dimensions: [(String, String)] = []) {
        guard enabled else { return }
        Counter(label: label, dimensions: dimensions).increment()
    }
    static func recordTimer(_ label: String, value: Duration) {
        guard enabled else { return }
        Timer(label: label).recordNanoseconds(Int64(value.components.seconds * 1_000_000_000 + value.components.attoseconds / 1_000_000_000))
    }
}
#endif
```

Usage at call sites:

```swift
#if DEBUG
DebugMetrics.increment("reset.tapped")
#endif
```

### Rules

1. **Release binary:** The `#if DEBUG` guard strips all metric call sites and
   the bootstrap call from the release build. No analytics surface in App Store
   binary, regardless of linker flags.

2. **DEBUG default (inert):** Without `KGR_METRICS_ENABLED=1`, all DEBUG runs
   (including CI UI test suites) are inert. UI tests must NOT set the env var.

3. **opt-in for engineers:** An engineer debugging locally sets
   `KGR_METRICS_ENABLED=1` in the Xcode scheme's environment variables, or
   passes it via `xcodebuild ... KGR_METRICS_ENABLED=1`.

4. **Prefix `KGR_`:** All project env vars use this prefix to avoid collisions
   with system or CI variables.

5. **No log statements outside DEBUG:** `print`, `os_log`, `Logger` in the
   metrics path are also `#if DEBUG`-gated (§2.12).

### Why two gates instead of one

| Risk | Gate 1 (`#if DEBUG`) | Gate 2 (env var) |
|------|--------------------|-----------------|
| Release binary carries analytics | ✓ prevents | — |
| DEBUG CI/UI tests fire metrics | — | ✓ prevents |
| Engineer noise in local DEBUG runs | — | ✓ prevents (opt-in) |

### Interaction with swift-metrics façade

The `swift-metrics` API package (Apple's `apple/swift-metrics`) is a thin
protocol; it ships a `NOOPMetricsHandler` as the default. If `MetricsSystem
.bootstrap` is never called in release, every metric call compiles to a noop.
This means the façade import itself is safe in all configurations. Only the
*backend* (e.g. `InMemoryMetricsHandler`, a Prometheus exporter) must be
gated.

### When to diverge

If even the `swift-metrics` API symbols must be absent from release (e.g.,
strict binary-size or supply-chain audit requirements), wrap all import sites
with `#if DEBUG` and declare the package as a debug-only SPM product dependency.
The double-gate at call sites still applies inside `#if DEBUG`.
