// Agent Notch extension for Pi (gentle-shell).
// Reports lifecycle events to the Agent Notch app and gates risky bash commands on it.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// ---- Configuration -------------------------------------------------------
const PORT = process.env.AGENT_NOTCH_PORT ?? "47823";
const BASE = `http://127.0.0.1:${PORT}`;

/** Bash commands matching any of these ask for approval in the notch. */
const RISKY_PATTERNS: RegExp[] = [
  /\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\b/, // rm -rf / -fr
  /\bsudo\b/,
  /\bgit\s+push\b.*(--force\b|--force-with-lease\b|\s-f\b)/,
  /\b(chmod|chown)\b.*\b777\b/,
  /\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba|z)?sh\b/,
  /\bdd\b\s+.*\bof=/,
  /\bmkfs(\.\w+)?\b/,
];
// --------------------------------------------------------------------------

type Json = Record<string, unknown>;

function post(path: string, body: Json, timeoutMs: number): Promise<Response> {
  return fetch(`${BASE}${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      // Lets a click on the notch focus the terminal this agent runs in.
      ...(process.env.__CFBundleIdentifier ? { "x-an-bundle": process.env.__CFBundleIdentifier } : {}),
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
}

export default function (pi: ExtensionAPI) {
  let sessionId: string | undefined;
  const sid = () => (sessionId ??= crypto.randomUUID());

  const base = (): Json => ({ session_id: sid(), cwd: process.cwd() });

  /** Fire-and-forget lifecycle event; never throws, never blocks the agent. */
  const emit = (hook_event_name: string, extra: Json = {}) => {
    post("/event/gentle", { ...base(), hook_event_name, ...extra }, 1000).catch(() => {});
  };

  pi.on("session_start", async () => {
    sessionId = crypto.randomUUID();
    emit("SessionStart");
  });

  pi.on("agent_start", async () => {
    emit("UserPromptSubmit");
  });

  pi.on("agent_end", async (event) => {
    const last = [...event.messages].reverse().find((m) => m.role === "assistant") as
      | { stopReason?: string; errorMessage?: string }
      | undefined;
    if (last?.stopReason === "error") emit("StopFailure", { message: last.errorMessage });
    else emit("Stop");
  });

  pi.on("session_shutdown", async () => {
    emit("Stop");
  });

  pi.on("tool_call", async (event, ctx) => {
    const input = (event.input ?? {}) as Json;
    emit("PreToolUse", { tool_name: event.toolName, tool_input: input });

    if (event.toolName !== "bash") return undefined;
    const command = String(input.command ?? "");
    if (!RISKY_PATTERNS.some((pattern) => pattern.test(command))) return undefined;

    let decision: string = "terminal";
    try {
      const res = await post(
        "/approve/gentle",
        { ...base(), hook_event_name: "PermissionRequest", tool_name: "Bash", tool_input: { command } },
        115_000,
      );
      decision = ((await res.json()) as { decision?: string }).decision ?? "terminal";
    } catch {
      decision = "terminal"; // app not running or timed out
    }

    if (decision === "allow") return undefined;
    if (decision === "deny") return { block: true, reason: "Denied from Agent Notch" };

    // Fall back to Pi's own prompt, like the permission-gate example.
    if (ctx.hasUI) {
      const choice = await ctx.ui.select(`Dangerous command:\n\n  ${command}\n\nAllow?`, ["Yes", "No"]);
      if (choice === "Yes") return undefined;
      return { block: true, reason: "Blocked by user" };
    }
    return { block: true, reason: "Dangerous command blocked (no UI for confirmation)" };
  });
}
