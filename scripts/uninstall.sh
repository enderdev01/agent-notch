#!/usr/bin/env bash
# Removes only the Agent Notch hook entries and the files install.sh copied.
# Usage: scripts/uninstall.sh [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
need_jq

# jq program: drop every hook command containing agent-notch-hook, then prune empty groups/events.
STRIP='
if (.hooks | type) != "object" then . else
  .hooks |= (
    with_entries(
      .value |= (
        map(if has("hooks") then .hooks |= map(select(((.command // "") | contains("agent-notch-hook")) | not)) else . end)
        | map(select((has("hooks") | not) or (.hooks | length > 0)))
      )
    )
    | with_entries(select(.value | length > 0))
  )
end
'

strip_from() { # file default
  local file="$1" default="$2" new
  if [ ! -f "$file" ]; then echo "skip (missing): $file"; return 0; fi
  new="$(jq "$STRIP" "$file")"
  apply_json "$file" "$new" "$default"
}

strip_from "$CLAUDE_SETTINGS" '{}'
strip_from "$CODEX_HOOKS" '{"hooks":{}}'

for f in "$HOOK_BIN" "$PI_EXT" "$GENTLE_SHELL_EXT" "$GENTLE_DOT_EXT"; do
  if [ -e "$f" ]; then
    if [ "$DRY_RUN" = 1 ]; then echo "would remove $f"; else rm -f "$f"; echo "removed: $f"; fi
  else
    echo "skip (missing): $f"
  fi
done
