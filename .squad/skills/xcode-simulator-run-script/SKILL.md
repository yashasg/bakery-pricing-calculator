---
name: "xcode-simulator-run-script"
description: "Build an iOS app with the existing build script, then install and launch it on the matching simulator"
domain: "build"
confidence: "high"
source: "earned"
---

## Context

Use this when adding a local run command for an Xcode iOS app that already has a build script controlling project, scheme, DerivedData, warnings, and simulator defaults.

## Patterns

- Delegate compilation to the existing build script instead of duplicating `xcodebuild` flags.
- Preserve simulator overrides (`SIMULATOR_NAME`, `SIMULATOR_UDID`, `DESTINATION`) and resolve a UDID for `simctl` install/launch.
- For interactive launch scripts, point the delegated build at an isolated workspace (for example `.build/run-build`) instead of the shared test/build DerivedData root; shared `Index.noindex` trees can make the next `rm -rf DerivedData` look hung.
- Set `COMPILER_INDEX_STORE_ENABLE=NO` on the delegated run-build when you do not need Xcode indexing artifacts; this keeps the isolated run workspace small enough for repeat invocations.
- Locate the built simulator `.app` under the same DerivedData products path used by the delegated build.
- Read `CFBundleIdentifier` from the built app's `Info.plist` with `PlistBuddy`; do not hardcode it.
- Stage the `.app` outside DerivedData before `simctl install` if other build/test jobs may clean DerivedData concurrently.
- Open `Simulator.app` before the `simctl boot/install/launch` sequence (`open -a Simulator`) so a successful `simctl launch` is visible to the user instead of running headlessly.
- Validate with two consecutive run-script executions; the first proves build/install/launch, the second catches DerivedData cleanup regressions.
- For run-script verification, treat visible GUI state as part of success: confirm the Simulator process is running and capture a simulator screenshot after launch instead of trusting only the PID returned by `simctl launch`.

## Examples

- Build: `DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID" ./app/build.sh build`
- Product path: `app/.build/derived-data/Build/Products/Debug-iphonesimulator/*.app`
- Launch: `xcrun simctl install "$SIMULATOR_UDID" "$STAGED_APP"` then `xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID"`

## Anti-Patterns

- Duplicating project, scheme, warning, or DerivedData build policy in the run script.
- Hardcoding bundle identifiers when the built app metadata is available.
- Installing directly from DerivedData in a repo where parallel build/test jobs clean DerivedData.
