---
name: "xcode-project-path"
description: "Rename Xcode project bundles without changing targets or schemes unnecessarily"
domain: "build"
confidence: "high"
source: "earned"
---

## Context
Use this when an iOS app's `.xcodeproj` bundle path changes but the product, target, and scheme names should remain stable.

## Patterns
- Move `.xcodeproj` bundles with `git mv` so the bundle directory rename is tracked correctly.
- Update build scripts and loop/docs references to the project path separately from target/scheme names.
- Validate with `bash -n` for scripts, `xcodebuild -list -project <path>` for project readability, and the repo's existing build/test command when practical.

## Examples
- Canonical project path: `app/__APP_NAME__.xcodeproj`
- Preserved scheme: `__APP_NAME__`
- Build invocation pattern: `xcodebuild -project app/__APP_NAME__.xcodeproj -scheme __APP_NAME__ ...`

## Anti-Patterns
- Renaming schemes or targets just because the `.xcodeproj` bundle was renamed.
- Editing historical/project references partially and leaving stale literals in tooling.
