#!/usr/bin/env bash
# Generates mascot art through APIMart. The API key is read from the macOS Keychain at runtime
# and never printed.
#
#   scripts/gen-mascots.sh --sleep-only            # sleeping variants of every existing base image
#   scripts/gen-mascots.sh --sleep-only claude     # one agent
#   scripts/gen-mascots.sh --poses [agent]         # work / alert / done variants of the base image
#   scripts/gen-mascots.sh codex                   # base image + sleeping variant (overwrites base)
#   APIMART_KEYCHAIN_SERVICE=my-item scripts/gen-mascots.sh ...
#
# Output (transparent PNG): Sources/AgentNotch/Resources/mascots-raw/<agent>.png and <agent>-sleep.png
# Then run scripts/process-mascots.py to produce the app sprites.
set -euo pipefail

SERVICE="${APIMART_KEYCHAIN_SERVICE:-com.onilabs.oni.apimart}"
BASE="https://api.apimart.ai/v1"
MODEL="${APIMART_MODEL:-gpt-image-2.5-sunburst}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/Sources/AgentNotch/Resources/mascots-raw"
mkdir -p "$OUT"

command -v jq >/dev/null || { echo "jq is required (brew install jq)" >&2; exit 1; }
KEY="$(security find-generic-password -s "$SERVICE" -w 2>/dev/null)" \
  || { echo "No Keychain item with service '$SERVICE'. Set APIMART_KEYCHAIN_SERVICE." >&2; exit 1; }

STYLE="cute chunky pixel-art mascot, front-facing, full body centered, thick dark outline, limited 12-color palette, 3 pixel-art shading levels, transparent background, no text, no drop shadow, no gradient"
VARIANT_TAIL="Full body centered at the same scale and position as the reference, transparent background, no text, no letters, no drop shadow."
SAME="The exact same character as the reference image, identical pixel-art style, palette, outline color or glow, and proportions, but"

variant_prompt() {
  case "$1" in
    sleep) echo "$SAME fast asleep: eyes closed as peaceful curved lines, tiny relaxed smile, wearing a cute pajama nightcap with a small pompom drooping to one side. $VARIANT_TAIL" ;;
    work)  echo "$SAME deeply focused on work: determined narrowed eyes looking down, small concentrated frown, both arms forward as if typing quickly. $VARIANT_TAIL" ;;
    alert) echo "$SAME startled and asking for attention: wide open round eyes, small open mouth, both arms raised up in the air. $VARIANT_TAIL" ;;
    done)  echo "$SAME celebrating a finished task: happy closed ^ ^ eyes, big open smile, both arms raised high in victory, tiny pixel sparkles around. $VARIANT_TAIL" ;;
    error) echo "$SAME sad and upset because something failed: worried drooping eyebrows, wobbly frown, one small blue tear, shoulders slumped and arms hanging down. $VARIANT_TAIL" ;;
    work-explore) echo "$SAME exploring: curious wide eyes peering ahead, holding a small magnifying glass up in one arm, other arm relaxed. $VARIANT_TAIL" ;;
    work-think) echo "$SAME thinking hard: eyes looking up, one arm raised to the chin, a small empty thought bubble with a tiny pixel lightbulb floating above. $VARIANT_TAIL" ;;
    work-check) echo "$SAME reviewing carefully: focused narrowed eyes, holding a small clipboard with a checklist of tick marks (no letters) in both arms. $VARIANT_TAIL" ;;
    work-close) echo "$SAME wrapping up: calm satisfied smile, tying a small ribbon bow around a tiny closed gift box held in both arms. $VARIANT_TAIL" ;;
    blink) echo "$SAME blinking: both eyes fully closed as thin curved lines, everything else (expression, pose, no hat) identical to the reference. $VARIANT_TAIL" ;;
    drowsy) echo "$SAME very sleepy and drowsy: heavy half-closed eyelids, tired droopy eyes, a small yawning mouth, arms relaxed, no hat. Keep every feature of the head (stem, antenna, ears) exactly as in the reference. $VARIANT_TAIL" ;;
    *) echo "unknown variant: $1" >&2; return 1 ;;
  esac
}

prompt_for() {
  case "$1" in
    claude) echo "A small friendly orange creature with two short arms and little legs, warm terracotta color, simple dot eyes. $STYLE" ;;
    codex)  echo "A small friendly purple robot with a screen face showing a terminal prompt >_ and tiny antenna. $STYLE" ;;
    gentle) echo "A small friendly rose character: a blooming rose head in deep magenta-pink petals with bright neon-pink highlights and a calm closed-smile face, a short green stem body, two small dark-green leaves as arms and two leaf feet, a neon pink glow along the outline like a futuristic rose. $STYLE" ;;
    *) echo "unknown agent: $1" >&2; return 1 ;;
  esac
}

# submit <label> <json-body-file> <output-png>
submit() {
  local label="$1" body_file="$2" dest="$3" resp code body task status url
  resp="$(curl -sS -w '\n%{http_code}' "$BASE/images/generations" \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d @"$body_file")"
  code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
  if [[ "$code" != 2* ]]; then echo "[$label] submit failed (HTTP $code): $body" >&2; return 1; fi
  task="$(jq -r '.data[0].task_id' <<<"$body")"
  [[ "$task" != "null" && -n "$task" ]] || { echo "[$label] no task_id in: $body" >&2; return 1; }
  echo "[$label] task $task submitted"

  for _ in $(seq 1 60); do
    sleep 5
    resp="$(curl -fsS "$BASE/tasks/$task" -H "Authorization: Bearer $KEY")"
    status="$(jq -r '.data.status' <<<"$resp")"
    case "$status" in
      completed)
        url="$(jq -r '.data.result.images[0].url[0]' <<<"$resp")"
        curl -fsS "$url" -o "$dest"
        echo "[$label] saved $dest"
        return 0 ;;
      failed|cancelled)
        echo "[$label] $status: $(jq -r '.data.error.message // "no message"' <<<"$resp")" >&2
        return 1 ;;
    esac
  done
  echo "[$label] timed out" >&2
  return 1
}

generate_base() {
  local agent="$1" body_file
  body_file="$(mktemp)"
  jq -n --arg p "$(prompt_for "$agent")" --arg m "$MODEL" \
    '{model:$m,prompt:$p,size:"1:1",resolution:"1k",quality:"high",background:"transparent",output_format:"png",n:1}' \
    > "$body_file"
  submit "$agent" "$body_file" "$OUT/$agent.png"; rm -f "$body_file"
}

# generate_variant <agent> <sleep|work|alert|done>: edits the agent's base image
generate_variant() {
  local agent="$1" variant="$2" img_file body_file ref
  ref="$OUT/$agent.png"
  [[ -f "$ref" ]] || { echo "[$agent-$variant] missing base image $ref" >&2; return 1; }
  img_file="$(mktemp)"; body_file="$(mktemp)"
  { printf 'data:image/png;base64,'; base64 -i "$ref" | tr -d '\n'; } > "$img_file"
  jq -n --arg p "$(variant_prompt "$variant")" --arg m "$MODEL" --rawfile img "$img_file" \
    '{model:$m,prompt:$p,size:"1:1",resolution:"1k",quality:"high",background:"transparent",output_format:"png",n:1,image_urls:[$img]}' \
    > "$body_file"
  submit "$agent-$variant" "$body_file" "$OUT/$agent-$variant.png"; rm -f "$img_file" "$body_file"
}

# Modes: (default) base + sleep | --sleep-only | --poses (work, alert, done) | --idle (blink, drowsy) | --variant <name> [agent] (also work-explore|think|check|close)
mode=base
case "${1:-}" in
  --sleep-only) mode=sleep; shift ;;
  --poses) mode=poses; shift ;;
  --idle) mode=idle; shift ;;
  --variant) mode=one; one="$2"; shift 2 ;;
esac
agents=("$@")
[[ ${#agents[@]} -gt 0 ]] || agents=(claude codex gentle)

for a in "${agents[@]}"; do
  case "$mode" in
    base)  generate_base "$a"; generate_variant "$a" sleep ;;
    sleep) generate_variant "$a" sleep ;;
    poses) for v in work alert done; do generate_variant "$a" "$v"; done ;;
    idle)  for v in blink drowsy; do generate_variant "$a" "$v"; done ;;
    one)   generate_variant "$a" "$one" ;;
  esac
done
