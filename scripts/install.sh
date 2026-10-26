#!/usr/bin/env bash
# Installs the Agent Notch hook bridge and wires Claude Code, Codex and Pi to it.
# Usage: scripts/install.sh [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
need_jq

# jq program: append a hook entry to .hooks[event] unless one already runs agent-notch-hook.
MERGE='
def add_hook($ev; $cmd; $t):
  .hooks //= {} | .hooks[$ev] //= []
  | if any(.hooks[$ev][]; any(.hooks[]?; ((.command // "") | contains("agent-notch-hook"))))
    then .
    else .hooks[$ev] += [{"hooks":[{"type":"command","command":$cmd,"timeout":$t}]}] end;
reduce $specs[] as $s (.; add_hook($s[0]; $s[1]; $s[2]))
'

spec() { # agent mode timeout events...
  local agent="$1" mode="$2" timeout="$3"; shift 3
  local ev out="[]"
  for ev in "$@"; do
    out="$(jq -c --arg e "$ev" --arg c "$HOOK_BIN $agent $mode" --argjson t "$timeout" '. + [[$e,$c,$t]]' <<<"$out")"
  done
  printf '%s' "$out"
}

merge_into() { # file default specs-json
  local file="$1" default="$2" specs="$3" current new
  current="$(read_json "$file" "$default")"
  new="$(jq --argjson specs "$specs" "$MERGE" <<<"$current")"
  apply_json "$file" "$new" "$default"
}

# 1. Bridge script
if [ "$DRY_RUN" = 1 ]; then
  echo "would copy $ROOT/bridge/agent-notch-hook -> $HOOK_BIN"
else
  mkdir -p "$(dirname "$HOOK_BIN")"
  install -m 0755 "$ROOT/bridge/agent-notch-hook" "$HOOK_BIN"
  echo "installed: $HOOK_BIN"
fi

# 2. Claude Code
claude_specs="$(jq -c -n \
  --argjson a "$(spec claude event 5 SessionStart UserPromptSubmit PreToolUse PostToolUse Notification Stop StopFailure)" \
  --argjson b "$(spec claude approve 120 PermissionRequest)" '$a + $b')"
merge_into "$CLAUDE_SETTINGS" '{}' "$claude_specs"

# 3. Codex
codex_specs="$(jq -c -n \
  --argjson a "$(spec codex event 5 SessionStart UserPromptSubmit PreToolUse PostToolUse Stop)" \
  --argjson b "$(spec codex approve 120 PermissionRequest)" \
  --argjson c "$(spec codex event 2 Interrupt)" '$a + $b + $c')"  # Interrupt timeout is capped at 3 s
merge_into "$CODEX_HOOKS" '{"hooks":{}}' "$codex_specs"

# 4. Pi (Gentle Shell)
if [ "$DRY_RUN" = 1 ]; then
  echo "would copy $ROOT/integrations/pi/agent-notch.ts -> $PI_EXT"
else
  mkdir -p "$(dirname "$PI_EXT")"
  install -m 0644 "$ROOT/integrations/pi/agent-notch.ts" "$PI_EXT"
  echo "installed: $PI_EXT"
fi

# 5. Isolated Pi homes (Gentle Shell, Gentle Dot), only for the apps that have been set up
for home in "$GENTLE_SHELL_HOME" "$GENTLE_DOT_HOME"; do
  [ -d "$home" ] || continue
  ext="$home/extensions/agent-notch.ts"
  if [ "$DRY_RUN" = 1 ]; then
    echo "would copy $ROOT/integrations/pi/agent-notch.ts -> $ext"
  else
    mkdir -p "$(dirname "$ext")"
    install -m 0644 "$ROOT/integrations/pi/agent-notch.ts" "$ext"
    echo "installed: $ext"
  fi
done

cat <<'MSG'

Next steps:
  - Codex: hooks may need to be trusted. Start Codex and review/approve the new
    hooks when prompted (or check your config.toml hook trust settings).
  - Restart running Claude Code / Codex / Pi sessions so they pick up the hooks.
  - Start Agent Notch (make run, or open "build/Agent Notch.app").
MSG
