#!/usr/bin/env bash
set -euo pipefail

squad loop --execute --self-pull --two-pass --wave-dispatch --decision-hygiene --health --copilot-flags "--yolo" --state-backend git-notes
