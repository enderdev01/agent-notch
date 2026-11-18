# Approval flow (manual verification)

POST /approve/{agent} blocks up to 115s waiting for a click in the notch GUI. No control.mjs command exercises it on purpose (it would hang), and it was not run by an agent.

Steps:
1. `node scripts/control.mjs app start`
2. Terminal A: `echo '{"hook_event_name":"PreToolUse","session_id":"ap1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"ls"}}' | AGENT_NOTCH_PORT=47899 bridge/agent-notch-hook claude approve`
3. Hover the notch and click Allow (or Deny) on the approval card. Terminal A returns the decision JSON.
4. Without clicking, `curl -X POST localhost:47899/debug/resolve-all/allow` resolves every pending approval and returns `{"resolved":n}` (observed `{"resolved":0}` with none pending).
5. `node scripts/control.mjs app stop`

Expected: the command in step 2 blocks until the click or the 115s timeout; the bridge always exits 0.
