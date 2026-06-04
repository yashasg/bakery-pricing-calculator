# Skill: xcodebuild test-runner env-var pass-through

**Slug:** `xcodebuild-test-runner-env`
**Author:** Hopper
**Date:** 2026-05-20T18:42:54-07:00

## Problem

`xcodebuild` does **not** forward the invoking shell's environment into the
launched test-runner process. An env var set in the shell (e.g.
`KGR_METRICS_BACKEND=inmemory ./app/build.sh test`) is swallowed at the
process boundary and never reaches `ProcessInfo.environment` inside the test.

## Solution

Prefix any env var you want forwarded with `TEST_RUNNER_` as an xcodebuild
build setting. xcodebuild strips the prefix at launch and injects the bare
name into the test runner's environment.

```bash
# In build.sh, after XCODEBUILD_ARGS is fully built, before run_xcodebuild():
while IFS='=' read -r _kgr_key _kgr_val; do
  case "$_kgr_key" in
    KGR_*) XCODEBUILD_ARGS+=("TEST_RUNNER_${_kgr_key}=${_kgr_val}") ;;
  esac
done < <(env)
```

- `IFS='='` + `read -r key val` splits on the **first** `=` only — values
  containing `=` (base64, connection strings) survive intact.
- The `case` guard is more reliable than `grep '^KGR_'` on the raw line
  because it operates on the already-split key.
- Adapt the `KGR_*` glob to whatever prefix your project uses.

## Usage in tests (Swift)

```swift
let backend = ProcessInfo.processInfo.environment["KGR_METRICS_BACKEND"] ?? "noop"
```

## References

- Apple TN: xcodebuild `TEST_RUNNER_` build setting prefix
- KGR issue #9 (swift-metrics), hopper-metrics-scope-v2.md
