# Skill: MetricKit Privacy Manifest

**Slug:** `metrickit-privacy-manifest`
**Author:** Hopper
**Date:** 2026-05-20T18:50:53-07:00
**Applies to:** iOS apps using MetricKit (`import MetricKit`)

---

## When to use this skill

Any iOS app target that subscribes to `MXMetricManager` for performance/crash analytics
must ship a `PrivacyInfo.xcprivacy` manifest. Use this skill to author the manifest and
verify no required-reason API declarations are missed.

---

## Reusable pattern

### 1. Required NSPrivacyCollectedDataTypes for MetricKit

MetricKit consumers must declare these three data type entries (all not-linked,
not-tracking, purposes: AppFunctionality + Analytics):

| `NSPrivacyCollectedDataType` | Covers |
|---|---|
| `NSPrivacyCollectedDataTypeCrashData` | `MXCrashDiagnostic` |
| `NSPrivacyCollectedDataTypePerformanceData` | All `MXMetric` subclasses + `MXSignpostMetric` |
| `NSPrivacyCollectedDataTypeOtherDiagnosticData` | `MXHangDiagnostic`, `MXCPUExceptionDiagnostic`, `MXDiskWriteExceptionDiagnostic`, `MXAppLaunchDiagnostic` |

### 2. NSPrivacyAccessedAPITypes: empty for plain subscriber

MetricKit is passive — the OS delivers pre-aggregated payloads. Our subscriber code does
NOT call UserDefaults, file-timestamp APIs, `statfs`, system boot time APIs, or active
keyboard APIs. Therefore `NSPrivacyAccessedAPITypes` is an empty array.

**Exception:** If the subscriber implementation writes to `UserDefaults` (e.g., to persist
the last seen payload date), add:
```xml
<dict>
  <key>NSPrivacyAccessedAPIType</key>
  <string>NSPrivacyAccessedAPITypeUserDefaults</string>
  <key>NSPrivacyAccessedAPITypeReasons</key>
  <array>
    <string>CA92.1</string>  <!-- store app-specific data; no tracking -->
  </array>
</dict>
```

### 3. NSPrivacyTracking: always false for MetricKit

MetricKit data never crosses to ad networks or data brokers. The OS delivers to App Store
Connect only. `NSPrivacyTracking` must be `false`.

### 4. File location

```
app/__APP_NAME__/PrivacyInfo.xcprivacy
```

The file must be added to the app target's **Resources** build phase in Xcode. Without
this step, Xcode will not include it in the app bundle and will not generate a correct
privacy report.

### 5. build.sh guards

Two gates enforce MetricKit-only telemetry at build time:

**Gate 1 — Package.resolved (all modes):**
```bash
_PKG_RESOLVED="$PROJECT_DIR/app.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ -f "$_PKG_RESOLVED" ]]; then
  _TELEMETRY_PATTERN='swift-metrics|firebase|sentry-cocoa|datadog|amplitude|mixpanel|segment|braze|newrelic|instana|bugsnag'
  if grep -Eiq "$_TELEMETRY_PATTERN" "$_PKG_RESOLVED"; then
    echo "error: Package.resolved references a third-party telemetry SDK" >&2; exit 65
  fi
fi
```

**Gate 2 — otool -L (release mode only):**
```bash
_NON_SYS="$(otool -L "$_RELEASE_BIN" | awk 'NR>1 {print $1}' \
  | grep -Ev '^(/usr/lib/|/System/Library/|@rpath/|@executable_path/|@loader_path/)' || true)"
[[ -n "$_NON_SYS" ]] && { echo "error: non-system dylib linked" >&2; exit 65; }
```

---

## References

- Apple MetricKit docs: https://developer.apple.com/documentation/metrickit
- Privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Required reason API: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
