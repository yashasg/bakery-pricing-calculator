# Skill: MetricKit Subscriber Bootstrap

**Slug:** `metrickit-subscriber-bootstrap`
**Author:** Edison
**Date:** 2026-05-20T18:50:53-07:00
**Applies to:** SwiftUI App protocol projects using MetricKit for on-device analytics

---

## Problem

You need to receive `MXMetricPayload` and `MXDiagnosticPayload` callbacks in a
SwiftUI `App`-protocol project (no `UIApplicationDelegate`). MetricKit requires
a subscriber to be added to `MXMetricManager.shared` before the first `Scene`
evaluates, and it must be retained for the app lifetime because `MXMetricManager`
holds only a **weak** reference to subscribers.

---

## Pattern

### 1. Create the subscriber class

```swift
// MetricsSubscriber.swift — in the app target
import MetricKit
import OSLog

final class MetricsSubscriber: NSObject, MXMetricManagerSubscriber {

    // Shared log handle; pass this to MXSignpost call sites.
    static let log: OSLog = MXMetricManager.makeLogHandle(category: "user_actions")

    func didReceive(_ payloads: [MXMetricPayload]) {
        #if DEBUG
        for payload in payloads {
            print("[MetricsSubscriber] MXMetricPayload:", payload.jsonRepresentation())
        }
        #endif
        // V1: rely on App Store Connect Analytics auto-flow.
        // V2: POST jsonRepresentation() to developer endpoint (Tesla call).
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        #if DEBUG
        for payload in payloads {
            print("[MetricsSubscriber] MXDiagnosticPayload:", payload.jsonRepresentation())
        }
        #endif
    }
}
```

### 2. Store and register in App.init()

```swift
// BakeryPricingCalculatorApp.swift (or YourApp.swift)
import SwiftUI
import MetricKit

@main
struct YourApp: App {

    // CRITICAL: stored `let` prevents deallocation.
    // MXMetricManager holds a weak reference; without this, subscriber
    // is immediately deallocated after init() returns.
    private let metricsSubscriber = MetricsSubscriber()

    init() {
        // Register before any Scene/View evaluates.
        MXMetricManager.shared.add(metricsSubscriber)
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### 3. Emit signposts from call sites

```swift
// In any View or function — import MetricKit not required if MetricsSubscriber
// exposes the static `log` handle.

// Count event (user action, state transition)
MXSignpost(.event, log: MetricsSubscriber.log, name: "share.invoked")

// Interval (timing distribution)
let spid = OSSignpostID(log: MetricsSubscriber.log)
MXSignpost(.begin, log: MetricsSubscriber.log, name: "compute", signpostID: spid)
let result = expensiveCompute()
MXSignpost(.end, log: MetricsSubscriber.log, name: "compute", signpostID: spid)
```

---

## Key Rules

| Rule | Rationale |
|------|-----------|
| Signpost name must be a **static string literal** | MetricKit aggregates by name; runtime interpolation produces unbucketed garbage |
| Signpost calls are **unconditional in release** | They're no-ops when the user has opted out in iOS Settings; `#if DEBUG` would kill production signals |
| `#if DEBUG` only in `didReceive` log statements | §2.12: no log statements in release |
| No app-level env gate for MetricKit | iOS Settings "Share with App Developers" is the gate |
| Subscriber stored as `let` on `@main` App struct | `@main` singleton = one init() call; `let` = app-lifetime retention |

---

## Idempotency

The `@main` App struct is instantiated exactly once per process by SwiftUI.
`init()` therefore calls `MXMetricManager.shared.add(subscriber)` exactly once.
No `static var bootstrapped` guard is needed.

---

## References

- Apple MetricKit docs: https://developer.apple.com/documentation/metrickit
- KGR decision: `.squad/decisions/inbox/edison-metrickit-scope.md` (V3)
- Coding standard §2.12: no logging outside `#if DEBUG`
- Coding standard §2.3: no network calls; MetricKit's own egress is system-mediated
