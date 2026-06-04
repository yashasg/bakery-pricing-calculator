# App Store Connect Privacy Nutrition Label Setup

**For:** __APP_NAME__  
**Author:** Hopper (Tooling Dev)  
**Date:** 2026-05-20T19:26:30-07:00  
**Related manifest:** `app/__APP_NAME__/PrivacyInfo.xcprivacy`

---

## Background

MetricKit delivers pre-aggregated diagnostic and performance data to the app once per day
(iOS 13+; diagnostics: iOS 14+; immediate delivery: iOS 15+). No personally identifiable
information is included — no user account ID, no IP address, no advertising identifier, no
input values. All aggregation is performed by the OS before delivery.

Apple requires both:
1. A `PrivacyInfo.xcprivacy` manifest bundled in the app (already wired into the
   `__APP_NAME__` target's Resources phase).
2. A matching **App Privacy nutrition label** in App Store Connect, declared before submission.

---

## Data Types to Declare

All three types map directly to the `NSPrivacyCollectedDataTypes` array in `PrivacyInfo.xcprivacy`.
Declare each with **Not Linked to User** and **Not Used for Tracking**.

| Category in App Store Connect | MetricKit payload source | Linked to User | Used for Tracking |
|-------------------------------|--------------------------|----------------|-------------------|
| Diagnostics → **Crash Data** | `MXCrashDiagnostic` | No | No |
| Diagnostics → **Performance Data** | `MXCPUMetric`, `MXMemoryMetric`, `MXAppLaunchMetric`, `MXAppRunTimeMetric`, `MXDiskIOMetric`, `MXNetworkTransferMetric`, `MXAppExitMetric`, `MXAnimationMetric`, `MXAppResponsivenessMetric`, `MXSignpostMetric` | No | No |
| Diagnostics → **Other Diagnostic Data** | `MXHangDiagnostic`, `MXCPUExceptionDiagnostic`, `MXDiskWriteExceptionDiagnostic`, `MXAppLaunchDiagnostic` | No | No |

Purpose for all three: **App Functionality** (improving stability) + **Analytics** (aggregate quality signals).

---

## Step-by-Step: App Store Connect Navigation

```
App Store Connect
  └── My Apps
        └── __APP_NAME__
              └── [Select any App Store version / 1.0 Prepare for Submission]
                    └── App Privacy   (left sidebar, under "General Information")
                          └── [Edit] → "Get Started" (first time) or "Edit Data Types"
```

### Step 1 — Open App Privacy

1. Sign in at [appstoreconnect.apple.com](https://appstoreconnect.apple.com).
2. Click **My Apps** → **__APP_NAME__**.
3. In the left sidebar under your app version, click **App Privacy**.
4. Click **Edit** (or **Get Started** on first visit).

### Step 2 — Declare data collection

When asked "Do you collect data from this app?", select **Yes**.

### Step 3 — Add Crash Data

1. Click **Add Data Type**.
2. Under **Diagnostics**, check **Crash Data**.
3. Click **Next** / **Continue**.
4. **Linked to your identity?** → Select **No, this data is not linked to the user's identity**.
5. **Used for tracking?** → Select **No**.
6. **Purposes:** Check both:
   - **App Functionality**
   - **Analytics**
7. Click **Save**.

### Step 4 — Add Performance Data

1. Click **Add Data Type** again.
2. Under **Diagnostics**, check **Performance Data**.
3. Click **Next** / **Continue**.
4. **Linked to your identity?** → **No**.
5. **Used for tracking?** → **No**.
6. **Purposes:** Check both:
   - **App Functionality**
   - **Analytics**
7. Click **Save**.

### Step 5 — Add Other Diagnostic Data

1. Click **Add Data Type** again.
2. Under **Diagnostics**, check **Other Diagnostic Data**.
3. Click **Next** / **Continue**.
4. **Linked to your identity?** → **No**.
5. **Used for tracking?** → **No**.
6. **Purposes:** Check both:
   - **App Functionality**
   - **Analytics**
7. Click **Save**.

### Step 6 — Publish

Click **Publish** to save the nutrition label. It takes effect when you submit the next
build for review; it does not require an immediate app update.

---

## User Opt-Out Path (for App Review)

Apple reviewers may ask how users can opt out of data collection. The answer:

> MetricKit data collection is governed entirely by the OS. Users control it at:
> **iOS Settings → Privacy & Security → Analytics & Improvements → Share With App Developers**
>
> When this toggle is OFF, the OS stops delivering `MXMetricPayload` and `MXDiagnosticPayload`
> objects to all apps, including __APP_NAME__. No in-app control is needed or
> appropriate — this is an OS-level opt-out, consistent with Apple's own privacy model for
> diagnostic data.

There is **no in-app privacy disclosure card** for MetricKit; the OS-level consent mechanism
is sufficient. This posture was confirmed by [your-username] on 2026-05-20T19:22:50-07:00.

---

## TestFlight Verification

After distributing a TestFlight build with MetricKit wired in (`MXMetricManager.shared.add(self)`
called on app launch):

1. **Install** the TestFlight build on a physical device.
2. **Use the app** for at least one meaningful session (open, compute a gauge, close normally).
3. **Wait ~24 hours.** MetricKit delivers the previous 24 hours of data at most once per day.
   Diagnostic payloads (`MXDiagnosticPayload`) arrive immediately on iOS 15+ after a
   triggering event (crash, hang, CPU exception).
4. **Check delivery:** In Xcode → Organizer → Crashes, symbolicated `MXCrashDiagnostic` and
   `MXHangDiagnostic` reports appear. In App Store Connect → Analytics, aggregate performance
   metrics appear after sufficient volume.
5. **Signpost events** (`MXSignpostMetric`) for the 9 named signposts (`compute`, `share.invoked`,
   `share.fallback`, `reset.tapped`, `verdict.improved`, `verdict.degraded`,
   `sheet.verdictHelp.opened`, `sheet.aboutHelp.opened`, `cast_on.driftBandShown`) appear in
   App Store Connect Analytics after aggregation.

---

## Notes for Submission

- `PrivacyInfo.xcprivacy` is already bundled (confirmed in `.app` build output at
  `__APP_NAME__.app/PrivacyInfo.xcprivacy`).
- MetricKit is auto-linked (system framework; `import MetricKit` in Swift is sufficient).
  No explicit `MetricKit.framework` entry in the Frameworks build phase is required with
  modern Xcode / iOS 17.0 deployment target.
- No entitlements changes needed.
- No Info.plist keys needed.
- Zero SPM dependencies added.
