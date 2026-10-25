# Shared helpers for install.sh / uninstall.sh. Sourced, not executed.

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) echo "Usage: $(basename "$0") [--dry-run]"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

HOOK_BIN="$HOME/.local/bin/agent-notch-hook"
PI_EXT="$HOME/.pi/agent/extensions/agent-notch.ts"
# gentle-shell and Gentle Dot run Pi with their own isolated homes, so each needs its own copy of the extension.
GENTLE_SHELL_HOME="$HOME/.gentle-shell/agent"
GENTLE_SHELL_EXT="$GENTLE_SHELL_HOME/extensions/agent-notch.ts"
GENTLE_DOT_HOME="$HOME/.gentle-dot/agent"
GENTLE_DOT_EXT="$GENTLE_DOT_HOME/extensions/agent-notch.ts"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CODEX_HOOKS="$HOME/.codex/hooks.json"

need_jq() { command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }; }

# Print the pretty-printed JSON of $1, or $2 if the file does not exist.
read_json() {
  if [ -f "$1" ]; then jq . "$1"; else printf '%s\n' "$2" | jq .; fi
}

# Write or (in dry-run) diff a new JSON document against file $1.
# $2 = new JSON text, $3 = default JSON when the file is missing.
apply_json() {
  local file="$1" new="$2" default="$3" old
  old="$(read_json "$file" "$default")"
  if [ "$DRY_RUN" = 1 ]; then
    echo "--- $file (dry-run, nothing written)"
    if [ "$old" = "$new" ]; then echo "(no changes)"; else diff -u <(printf '%s\n' "$old") <(printf '%s\n' "$new") || true; fi
    return 0
  fi
  [ "$old" = "$new" ] && { echo "unchanged: $file"; return 0; }
  mkdir -p "$(dirname "$file")"
  if [ -f "$file" ] && [ ! -e "$file.bak-agent-notch" ]; then cp -p "$file" "$file.bak-agent-notch"; fi
  local tmp; tmp="$(mktemp "$file.XXXXXX")"
  printf '%s\n' "$new" > "$tmp"
  mv "$tmp" "$file"
  echo "updated: $file"
}
