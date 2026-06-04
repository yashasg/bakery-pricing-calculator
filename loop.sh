#!/usr/bin/env bash
set -euo pipefail

squad loop --execute --self-pull --two-pass --wave-dispatch --decision-hygiene --board __GITLAB_BOARD_URL__ --health --copilot-flags "--yolo" --state-backend git-notes
