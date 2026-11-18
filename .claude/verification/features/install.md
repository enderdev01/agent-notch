# Install / uninstall

`install` and `uninstall` run scripts/install.sh / uninstall.sh with `HOME` set to a fresh `mkdtemp` dir (always sandboxed, deleted afterwards). The real HOME is never touched (mtimes of the real ~/.local/bin/agent-notch-hook, ~/.claude/settings.json, ~/.codex/hooks.json were identical before and after all runs). Needs `jq`; without it: `FAIL jq is required by the install scripts  ->  brew install jq` (not observed, jq is installed here).

| Input | Observed output | Exit |
|---|---|---|
| `install --dry-run` | `ok install.sh --dry-run exit 0 (sandboxed HOME, deleted)`, then `would copy .../bridge/agent-notch-hook -> <sandbox>/.local/bin/agent-notch-hook` and a diff of `<sandbox>/.claude/settings.json` | 0 |
| `install` | `ok install.sh exit 0 ...`; files created: `.claude/settings.json`, `.codex/hooks.json`, `.local/bin/agent-notch-hook`, `.pi/agent/extensions/agent-notch.ts` | 0 |
| `uninstall --dry-run` | six `skip (missing): <sandbox>/...` lines (claude, codex, hook bin, pi, gentle-shell, gentle-dot) | 0 |
| `uninstall` | same skip lines, `files created: (none)` | 0 |

Note: `uninstall` runs on an empty sandbox, so it only proves the skip path, not removal of an installed setup. The gentle-shell/gentle-dot extensions are not installed because those homes do not exist in the sandbox.
