#!/usr/bin/env bash
set -euo pipefail

TASK_ID="${TASK_ID:-TASK-135}"
PREFIX="${PREFIX:-TASK135_HISTORY_LIVE_$(date +%Y%m%d_%H%M%S)_}"

if [[ "${MC_ALLOW_LIVE:-}" != "1" ]]; then
  echo "history_fixture_live: refusing live mutation without MC_ALLOW_LIVE=1" >&2
  exit 4
fi

exec ./tools/agent/mc-agent.sh live mutation-near-realtime --task "$TASK_ID" --prefix "$PREFIX"
