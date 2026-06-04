# Skill: MetricKit `MXMetricPayload` Protocol-Wrap Mock

**Slug:** `metrickit-protocol-wrap-mock`  
**Author:** Curie  
**Date:** 2026-05-20T18:50:53-07:00  
**Confidence:** medium (pattern successfully applied in MetricKitSubscriberTests — 2026-05-20T19:26:30-07:00)

---

## Problem

`MXMetricPayload` is a sealed system class with no public initialiser. You
cannot subclass it portably (NSCoding internals, no public `init`), and you
cannot instantiate it in tests. Any subscriber that depends directly on
`MXMetricPayload` is untestable in isolation.

## Solution: protocol wrapping

1. **Define a minimal protocol** in the app target that mirrors only the
   fields your subscriber actually reads. Keep it small — add fields only
   when consumed.

   ```swift
   // MetricPayloadProtocol.swift  (app target)
   import Foundation

   protocol MetricPayloadProtocol {
       var timeStampBegin: Date { get }
       var timeStampEnd: Date   { get }
       // Add more fields here as needed, never speculatively.
   }

   extension MXMetricPayload: MetricPayloadProtocol {}
   ```

2. **Change the subscriber's internal handler** to accept the protocol.
   Bridge from the system delegate method so production code is unaffected.

   ```swift
   // MetricKitSubscriber.swift  (app target)
   import MetricKit

   final class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
       // System delegate entry point — bridges to the testable handler:
       func didReceive(_ payloads: [MXMetricPayload]) {
           receive(payloads)
       }

       // Testable handler — depends on the protocol, not the concrete class:
       func receive(_ payloads: [any MetricPayloadProtocol]) {
           for payload in payloads {
               print("[MetricKit] \(payload.timeStampBegin) – \(payload.timeStampEnd)")
           }
       }
   }
   ```

3. **Define a mock struct** in the test target only.

   ```swift
   // MockMetricPayload.swift  (test target only)
   import Foundation
   @testable import YourAppModule

   struct MockMetricPayload: MetricPayloadProtocol {
       var timeStampBegin: Date = .distantPast
       var timeStampEnd: Date   = .distantFuture
   }
   ```

4. **Write tests** against `receive(_:)` using `MockMetricPayload`.

   ```swift
   @Test func subscriberLogsPayloadFields() {
       let subscriber = MetricKitSubscriber()
       let payload = MockMetricPayload(
           timeStampBegin: Date(timeIntervalSince1970: 0),
           timeStampEnd:   Date(timeIntervalSince1970: 86400)
       )
       // No crash, no assertion error — side effects are observable via
       // dependency injection if the subscriber writes to an injectable sink.
       subscriber.receive([payload])
   }

   @Test func subscriberHandlesEmptyPayloadArray() {
       let subscriber = MetricKitSubscriber()
       subscriber.receive([])   // must not crash
   }
   ```

## Applied example

Successfully used in `app/__APP_NAME__Tests/MetricKitSubscriberTests.swift`
(2026-05-20T19:26:30-07:00). Edison's `MetricPayloadProtocol` had a third method
`func jsonRepresentation() -> Data` beyond the two timestamp fields in this spec.
Key lesson: **check the actual protocol surface before writing the mock** — the
spec and the implementation can diverge. Keep `MockMetricPayload.jsonRepresentation()`
returning a minimal JSON blob via `JSONSerialization` to avoid any decoding surprises.

```swift
func jsonRepresentation() -> Data {
    let dict: [String: String] = [
        "timeStampBegin": timeStampBegin.description,
        "timeStampEnd":   timeStampEnd.description,
    ]
    return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
}
```


This pattern works for any sealed Apple system class with no public `init`:
- `MXMetricPayload` and its subclasses (`MXCPUMetric`, `MXMemoryMetric`, …)
- `MXDiagnosticPayload`
- `SKProduct`, `SKPayment`, `CNContact`
- Any `NSObject` subclass where subclassing is impractical

## Constraints

- Keep the protocol surface **minimal** — only what is consumed. A large
  protocol surface is expensive to mock and brittle to evolve.
- The `extension MXMetricPayload: MetricPayloadProtocol {}` conformance
  must live in the **app target**, not the test target, so production code
  can use the protocol type without importing test code.
- Do **not** expose `MockMetricPayload` to the app target. Use
  `@testable import` in the test target only.
