#!/usr/bin/env node
// Verification CLI: the lever agents use to check their own work.
// Every command supports --json. Exit 0 on success, 1 on failure.
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, relative, isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const argv = process.argv.slice(2);
const json = argv.includes("--json");
const args = argv.filter((a) => a !== "--json");

// Filled by create-verification-skill, e.g. { start: ["npm", "run", "dev"], url: "http://localhost:5173", expect: "<title>My App</title>" }
// `expect`: exact, case-sensitive text only this app's HTML contains (its <title>), so another app on the port is never captured.
// Generic dev-server text like "/@vite/client" is not enough: any other Vite project on the same port has it too.
const APP = { start: null, url: null, expect: null };

const HELP = `Usage: node scripts/control.mjs <command> [--json]

Commands:
  doctor    Check the environment is ready (node, deps, git hooks, branch)
  verify    Run check-strings, bash -n, swift build, swift test and the Worker tests; report each step
            Each step is cut after 10 minutes; set CONTROL_VERIFY_TIMEOUT_MS (milliseconds) to change it

  screenshot [route] [--out <file.png>] [--wait <ms>] [--full-page] [--port <n>]
            Headless screenshot of a route of the app, "/" by default (needs APP set and Playwright installed in the project)
            Without --out it writes $TMPDIR/<project>-screenshot.png, overwritten on every run
            --port replaces the port of APP.url (default is APP.url's); use it for a worktree's own dev server, which you start first
            Example: node scripts/control.mjs screenshot /settings --full-page

  app start|stop [--port <n>] [--dry-run]
            Start/stop the debug app (AGENT_NOTCH_DEBUG=1) on a dedicated port, default 47899 (never the real app's 47823)
            start shows a notch panel (GUI side effect); stop kills only the pid it started, --dry-run just prints it
            Example: node scripts/control.mjs app start
  health [--port <n>]            GET /health
            Example: node scripts/control.mjs health
  event <agent> <EventName> [--session <id>] [--cwd <path>] [--port <n>]
            POST a hook event to /event/<agent>, expects 204
            Example: node scripts/control.mjs event claude Stop --session t1
  state [--port <n>]             List sessions from /debug/state (debug app only)
            Example: node scripts/control.mjs state
  vercel <building|ready|failed> [--port <n>]
            Fake a Vercel deployment status in the debug app
            Example: node scripts/control.mjs vercel building
  hook <claude|codex|gentle> [EventName] [--port <n>]
            Send a payload through bridge/agent-notch-hook, then assert the session shows in /debug/state
            Example: node scripts/control.mjs hook claude Stop
  install [--dry-run] | uninstall [--dry-run]
            Run scripts/install.sh / uninstall.sh with HOME set to a throwaway temp dir (the real HOME is never touched; needs jq)
            Example: node scripts/control.mjs install --dry-run
  strings   Run scripts/check-strings.py (L("...") keys vs the en/es/de locales)
  worker-test  Run the Vercel Worker tests (node --test)

Every command exits 0 on success and 1 on failure. Add --json for machine-readable output.`;

function run(cmd, cmdArgs) {
  const start = Date.now();
  const r = spawnSync(cmd, cmdArgs, { cwd: root, encoding: "utf8" });
  return { ok: r.status === 0, ms: Date.now() - start, output: `${r.stdout ?? ""}${r.stderr ?? ""}`.trim() };
}

// Async run with a timeout: detached so the step leads a process group and the kill reaches npm's shell and node grandchildren.
function runStep(cmd, cmdArgs, timeoutMs) {
  const start = Date.now();
  return new Promise((done) => {
    const child = spawn(cmd, cmdArgs, { cwd: root, detached: true, stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    let timedOut = false;
    const collect = (d) => (output += d);
    child.stdout.on("data", collect);
    child.stderr.on("data", collect);
    const timer = setTimeout(() => {
      timedOut = true;
      try { process.kill(-child.pid, "SIGKILL"); } catch {}
      // A grandchild that escaped the group could keep the pipes open: do not wait for them.
      setTimeout(() => finish(null), 1000);
    }, timeoutMs);
    let finished = false;
    const finish = (code) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      child.stdout.destroy();
      child.stderr.destroy();
      const text = output.trim();
      done({ ok: !timedOut && code === 0, ms: Date.now() - start, output: timedOut ? `timed out after ${Math.round(timeoutMs / 1000)}s\n${text}`.trim() : text, timedOut });
    };
    child.on("error", (e) => { output += e.message; finish(1); });
    child.on("close", finish);
  });
}

function report(ok, data, text) {
  process.stdout.write(json ? `${JSON.stringify({ ok, ...data }, null, 2)}\n` : `${text}\n`);
  process.exit(ok ? 0 : 1);
}

// The Node major the project pins (.nvmrc, .node-version or package.json engines.node), or null.
// Returns { file, min, exact }: `exact` for a fixed major ("24", "v24.1", "^24", "24.x"), `min` for ">=24".
function nodePin() {
  for (const file of [".nvmrc", ".node-version"]) {
    const major = existsSync(join(root, file)) && readFileSync(join(root, file), "utf8").trim().match(/^v?(\d+)/)?.[1];
    if (major) return { file, exact: Number(major) };
  }
  let range = "";
  try {
    range = JSON.parse(readFileSync(join(root, "package.json"), "utf8")).engines?.node ?? "";
  } catch {}
  const min = range.match(/^>=\s*v?(\d+)/)?.[1];
  if (min) return { file: "package.json engines.node", min: Number(min) };
  const exact = range.match(/^[\^~]?v?(\d+)(\.[\dx*]+)*$/)?.[1];
  return exact ? { file: "package.json engines.node", exact: Number(exact) } : null;
}

// First .githooks stub that is missing, not executable or does not run its guard, else null.
function hookProblem() {
  const guards = { "pre-commit": "branch-guard.mjs", "pre-merge-commit": "branch-guard.mjs", "pre-push": "branch-guard.mjs", "commit-msg": "attribution-guard.mjs" };
  for (const [name, guard] of Object.entries(guards)) {
    const file = join(root, ".githooks", name);
    if (!existsSync(file)) return `.githooks/${name} is missing. Copy it from the skuizops plugin templates/githooks`;
    if (!(statSync(file).mode & 0o111)) return `.githooks/${name} is not executable. Run: chmod +x .githooks/${name}`;
    if (!readFileSync(file, "utf8").includes(guard)) return `.githooks/${name} does not run ${guard}. Restore it from the skuizops plugin templates/githooks`;
  }
  return null;
}

async function doctor() {
  const [major, minor] = process.versions.node.split(".").map(Number);
  const pin = nodePin();
  const hooksPath = run("git", ["config", "--get", "core.hooksPath"]);
  const branch = run("git", ["symbolic-ref", "--short", "-q", "HEAD"]);
  const isRepo = run("git", ["rev-parse", "--is-inside-work-tree"]).ok;

  let branchProblem = null;
  try {
    const { commitViolation } = await import("./guard/branch-guard.mjs");
    branchProblem = commitViolation(branch.ok ? branch.output : null);
  } catch {
    branchProblem = "scripts/guard/branch-guard.mjs is missing. Copy it from the skuizops plugin (see the create-verification-skill skill)";
  }

  const checks = [
    { name: "node", ok: major > 22 || (major === 22 && minor >= 18), fix: "Install Node 22.18+" },
    ...(pin
      ? [{
          name: `node matches project pin (${pin.file})`,
          ok: pin.exact ? major === pin.exact : major >= pin.min,
          fix: `the project pins Node ${pin.exact ?? `>=${pin.min}`} but this shell runs ${process.versions.node}. Switch with: nvm use (or fnm use)`,
        }]
      : []),
    ...(existsSync(join(root, "package.json"))
      ? [{ name: "dependencies", ok: existsSync(join(root, "node_modules")), fix: "npm install" }]
      : []),
    { name: "git repository", ok: isRepo, fix: "git init" },
    { name: "git hooks", ok: hooksPath.output === ".githooks" && !hookProblem(), fix: hooksPath.output === ".githooks" ? hookProblem() : "git config core.hooksPath .githooks" },
    { name: "work branch (feat/, fix/, hotfix/)", ok: isRepo && !branchProblem, fix: branchProblem ?? "git init" },
  ];
  const ok = checks.every((c) => c.ok);
  const text = checks.map((c) => `${c.ok ? "ok  " : "FAIL"} ${c.name}${c.ok ? "" : `  ->  ${c.fix}`}`).join("\n");
  report(ok, { checks }, text);
}

async function verify() {
  const timeoutEnv = process.env.CONTROL_VERIFY_TIMEOUT_MS;
  if (timeoutEnv !== undefined && !/^[1-9]\d*$/.test(timeoutEnv)) {
    const error = `CONTROL_VERIFY_TIMEOUT_MS must be a positive number of milliseconds, got "${timeoutEnv}"`;
    report(false, { error }, `FAIL ${error}`);
  }
  const timeoutMs = Number(timeoutEnv ?? 600000);
  // Swift project with no package.json: the same gates CI runs (.github/workflows), plus the Swift and Worker tests.
  const STEPS = [
    ["strings", "python3", ["scripts/check-strings.py"]],
    ["shell-syntax", "bash", ["-c", "bash -n bridge/agent-notch-hook scripts/*.sh"]],
    ["build", "swift", ["build"]],
    ["test", "swift", ["test"]],
    ["worker-test", "node", ["--test", "integrations/vercel-worker/index.test.mjs"]],
  ];
  const steps = [];
  for (const [step, cmd, cmdArgs] of STEPS) steps.push({ step, ...(await runStep(cmd, cmdArgs, timeoutMs)) });
  const ok = steps.every((s) => s.ok);
  const text = steps
    .map((s) => `${s.ok ? "ok  " : "FAIL"} ${s.step} ${s.timedOut ? `timed out after ${Math.round(timeoutMs / 1000)}s` : `(${s.ms}ms)`}${s.ok ? "" : `\n${s.output.split("\n").slice(-20).join("\n")}`}`)
    .join("\n");
  report(ok, { steps: steps.map(({ output, ...s }) => (s.ok ? s : { ...s, output })) }, text);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const answers = (url) => fetch(url, { signal: AbortSignal.timeout(2000) }).then(() => true, () => false);

// { status, text } of a page, or null if it fails to load. Long timeout: SSR streams the body after the headers.
const page = (url) => fetch(url, { signal: AbortSignal.timeout(15000) }).then(async (r) => ({ status: r.status, text: await r.text() }), () => null);
const isApp = (p) => Boolean(p?.text.includes(APP.expect));
const got = (p) => (p ? `HTTP ${p.status}` : "no page within 15s");

const PW_HINT = "npm i -D playwright && npx playwright install chromium";
const SIGNALS = { SIGINT: 130, SIGTERM: 143, SIGHUP: 129 };

// Directories of the processes listening on `port` (via lsof), or null when it cannot tell.
function servedFrom(port) {
  const ls = (a) => spawnSync("lsof", a, { encoding: "utf8", timeout: 5000 });
  const pids = (ls(["-nP", `-iTCP:${port}`, "-sTCP:LISTEN", "-t"]).stdout ?? "").split("\n").filter(Boolean);
  const dirs = pids.flatMap((pid) => (ls(["-a", "-p", pid, "-d", "cwd", "-Fn"]).stdout ?? "").split("\n").filter((l) => l.startsWith("n")).map((l) => l.slice(1)));
  return dirs.length ? dirs : null;
}

async function screenshot(lineArgs) {
  const flag = (name) => (lineArgs.includes(name) ? lineArgs[lineArgs.indexOf(name) + 1] : undefined);
  const route = lineArgs.find((a, i) => !a.startsWith("--") && !["--out", "--wait", "--port"].includes(lineArgs[i - 1])) ?? "/";
  if (!APP.url) {
    report(false, { error: "APP not set" }, "FAIL APP is not set  ->  set APP = { start, url, expect } in scripts/control.mjs (see the create-verification-skill skill)");
  }
  if (!APP.expect) {
    report(false, { error: "APP.expect not set" }, "FAIL APP.expect is not set  ->  set it to text the app's HTML always contains (e.g. \"/@vite/client\" or its <title>) in scripts/control.mjs");
  }
  const invalid = (error) => report(false, { error }, `FAIL ${error}`);
  const wait = flag("--wait");
  // Capped below the 120 s Playwright timeout; huge values also overflow Node timers.
  const outArg = flag("--out");
  if (lineArgs.includes("--out") && (!outArg || outArg.startsWith("--"))) invalid(`--out needs a file path, got "${outArg ?? ""}"`);
  if (lineArgs.includes("--wait") && !/^\d{1,5}$/.test(wait ?? "")) invalid(`--wait needs a number of milliseconds up to 99999, got "${wait ?? ""}"`);
  const portArg = flag("--port");
  if (lineArgs.includes("--port") && (!/^\d{1,5}$/.test(portArg ?? "") || Number(portArg) < 1 || Number(portArg) > 65535)) invalid(`--port needs a port number from 1 to 65535, got "${portArg ?? ""}"`);
  const url = portArg ? Object.assign(new URL(APP.url), { port: portArg }).href : APP.url;
  // The origin check also catches "//host" and "/\host", which URL parsing sends to another host.
  if (!route.startsWith("/") || new URL(route, url).origin !== new URL(url).origin) invalid(`route must be a path starting with a single "/", got "${route}"`);
  const timeoutEnv = process.env.CONTROL_START_TIMEOUT_MS;
  if (timeoutEnv !== undefined && !/^[1-9]\d*$/.test(timeoutEnv)) invalid(`CONTROL_START_TIMEOUT_MS must be a positive number of milliseconds, got "${timeoutEnv}"`);
  // The project's own binary: npx would silently fall back to a global Playwright.
  const pwBin = join(root, "node_modules", ".bin", "playwright");
  if (!existsSync(pwBin)) {
    report(false, { error: "Playwright is not installed in this project", fix: PW_HINT }, `FAIL Playwright is not installed in this project  ->  ${PW_HINT}`);
  }
  const target = new URL(route, url).href;
  // Resolved from the caller's cwd (Playwright runs from the project root); absolute, so "-x.png" is never read as a flag.
  // One fixed file per project, so repeated runs never pile up temp directories.
  const out = outArg ? resolve(outArg) : join(tmpdir(), `${basename(root)}-screenshot.png`);
  let server = null;
  let pwChild = null;
  let exited = false;
  let warning = null;
  let log = "";
  const tail = () => log.trim().split("\n").slice(-10).join("\n");
  // Only ever kills a server this run started.
  const stop = () => {
    if (pwChild?.pid && pwChild.exitCode === null) try { process.kill(-pwChild.pid, "SIGKILL"); } catch {}
    if (server?.pid && !exited) try { process.kill(-server.pid, "SIGKILL"); } catch {}
  };
  const fail = (error, text) => {
    stop();
    report(false, { error, detail: text }, `FAIL ${text}`);
  };
  for (const [sig, code] of Object.entries(SIGNALS)) process.on(sig, () => { stop(); process.exit(code); });
  const { port, protocol } = new URL(url);
  const home = (await answers(url)) ? await page(url) : null;
  if (home && !isApp(home)) {
    fail("port taken", `${url} answers (${got(home)}) but its page does not contain APP.expect ("${APP.expect}"): another app holds the port, or the app is failing  ->  check what listens (lsof -nP -iTCP:${port || (protocol === "https:" ? 443 : 80)} -sTCP:LISTEN), stop it if it is not this app, then retry`);
  }
  if (home) {
    // A second checkout of the same app passes isApp, so check the server runs from this project.
    const dirs = servedFrom(new URL(url).port || (protocol === "https:" ? 443 : 80));
    const rootReal = realpathSync(root);
    const inside = (d) => { const r = relative(rootReal, d); return !r.startsWith("..") && !isAbsolute(r); };
    if (dirs && !dirs.some(inside)) fail("other checkout", `${url} is served from ${dirs.join(", ")}, not from this project (${rootReal}): another checkout holds the port  ->  stop it, or run this checkout's server on another port and pass --port <n>`);
    if (!dirs) warning = `could not confirm that ${url} is served from this checkout (lsof missing or no listener found)`;
  }
  if (!home) {
    if (portArg) fail("app not running", `${url} does not answer and --port was given  ->  start this checkout's dev server on port ${portArg} first, then retry`);
    if (!APP.start) fail("app not running", `${url} does not answer and APP.start is not set  ->  start the app or set APP.start in scripts/control.mjs`);
    server = spawn(APP.start[0], APP.start.slice(1), { cwd: root, detached: true, stdio: ["ignore", "pipe", "pipe"] });
    server.on("error", (e) => { log += `${e.message}\n`; exited = true; });
    server.on("exit", () => (exited = true));
    for (const stream of [server.stdout, server.stderr]) stream.on("data", (d) => (log += d));
    const deadline = Date.now() + Number(timeoutEnv ?? 60000);
    let up = false;
    while (!up && !exited && Date.now() < deadline) {
      await sleep(500);
      up = await answers(url);
    }
    if (!up && exited) fail("app did not start", `"${APP.start.join(" ")}" exited before ${url} answered  ->  last output:\n${tail()}`);
    if (!up) fail("app did not start", `${url} did not answer after starting "${APP.start.join(" ")}"  ->  last output:\n${tail()}`);
    const started = await page(url);
    if (!isApp(started)) fail("not the app", `"${APP.start.join(" ")}" started but ${url} (${got(started)}) does not contain APP.expect ("${APP.expect}")  ->  fix APP.expect or url in scripts/control.mjs`);
  }
  const pw = await new Promise((resolve) => {
    // Own process group so an interrupt can kill Playwright and its browser together.
    const child = (pwChild = spawn(pwBin, ["screenshot", ...(lineArgs.includes("--full-page") ? ["--full-page"] : []), ...(wait ? ["--wait-for-timeout", wait] : []), target, out], { cwd: root, detached: true }));
    let output = "";
    let timedOut = false;
    const timer = setTimeout(() => { timedOut = true; try { process.kill(-child.pid, "SIGKILL"); } catch {} }, 120000);
    for (const stream of [child.stdout, child.stderr]) stream.on("data", (d) => (output += d));
    child.on("error", (e) => { output += e.message; });
    child.on("close", (status) => { clearTimeout(timer); resolve({ ok: status === 0, output: timedOut ? `${output}\nPlaywright timed out after 120s` : output }); });
  });
  stop();
  if (!pw.ok) {
    const msg = pw.output.trim();
    const missing = /Executable doesn't exist|playwright install/i.test(msg);
    report(false, { error: msg, ...(missing ? { fix: PW_HINT } : {}) }, `FAIL screenshot of ${target}  ->  ${missing ? `Playwright browser is missing: ${PW_HINT}` : msg.split("\n").slice(-10).join("\n")}`);
  }
  report(true, { url: target, file: out, ...(warning ? { warning } : {}) }, `ok screenshot ${target} -> ${out}${warning ? `\nwarning: ${warning}` : ""}`);
}

// ---- Feature commands (Agent Notch). App-talking commands use a dedicated debug port, never the user's real app on 47823.
const PID_FILE = join(tmpdir(), "agent-notch-control.pid");
const BIN = join(root, ".build", "debug", "AgentNotch");
const START_HINT = "start the app with: node scripts/control.mjs app start";
const flagOf = (lineArgs, name) => (lineArgs.includes(name) ? lineArgs[lineArgs.indexOf(name) + 1] : undefined);
const positional = (lineArgs) => lineArgs.filter((a, i) => !a.startsWith("--") && !["--port", "--session", "--cwd"].includes(lineArgs[i - 1]));
const fail = (error) => report(false, { error }, `FAIL ${error}`);

function portOf(lineArgs) {
  const p = flagOf(lineArgs, "--port") ?? "47899";
  if (!/^\d{1,5}$/.test(p) || Number(p) < 1 || Number(p) > 65535) fail(`--port needs a port number from 1 to 65535, got "${p}"`);
  return Number(p);
}

// { status, text } or null when nothing answers.
const call = (port, method, path, body) =>
  fetch(`http://127.0.0.1:${port}${path}`, { method, body, signal: AbortSignal.timeout(5000) }).then(async (r) => ({ status: r.status, text: await r.text() }), () => null);

const noAnswer = (port) => fail(`nothing answers on 127.0.0.1:${port}  ->  ${START_HINT}${port === 47899 ? "" : ` --port ${port}`}`);

async function app(lineArgs) {
  const [sub] = positional(lineArgs);
  const port = portOf(lineArgs);
  if (sub === "start") {
    if (!existsSync(BIN)) fail("no debug binary at .build/debug/AgentNotch  ->  run swift build first");
    if (await call(port, "GET", "/health")) fail(`port ${port} already answers: another app holds it  ->  run: node scripts/control.mjs app stop, or pass --port <n>`);
    // Launching shows the notch panel and may show the ConnectAgents dialog (GUI side effect).
    const child = spawn(BIN, [], { cwd: root, detached: true, stdio: "ignore", env: { ...process.env, AGENT_NOTCH_DEBUG: "1", AGENT_NOTCH_PORT: String(port) } });
    child.unref();
    writeFileSync(PID_FILE, String(child.pid));
    for (let i = 0; i < 30; i++) {
      await sleep(500);
      if ((await call(port, "GET", "/health"))?.text.trim() === "ok") report(true, { pid: child.pid, port }, `ok app started pid ${child.pid} on port ${port}`);
    }
    try { process.kill(child.pid); } catch {}
    rmSync(PID_FILE, { force: true });
    fail(`app did not answer /health on port ${port} within 15s  ->  run the binary by hand to see why: AGENT_NOTCH_DEBUG=1 AGENT_NOTCH_PORT=${port} .build/debug/AgentNotch`);
  }
  if (sub === "stop") {
    const pid = existsSync(PID_FILE) ? readFileSync(PID_FILE, "utf8").trim() : "";
    if (!/^\d+$/.test(pid)) fail(`no pid file at ${PID_FILE}: nothing started by this tool  ->  node scripts/control.mjs app start`);
    const comm = run("ps", ["-p", pid, "-o", "comm="]).output;
    if (!comm.endsWith("AgentNotch")) {
      rmSync(PID_FILE, { force: true });
      fail(`pid ${pid} is not AgentNotch (${comm || "not running"}): removed the stale pid file, killed nothing`);
    }
    if (lineArgs.includes("--dry-run")) report(true, { pid: Number(pid), dryRun: true }, `dry-run: would kill pid ${pid} (${comm}) and remove ${PID_FILE}`);
    process.kill(Number(pid));
    rmSync(PID_FILE, { force: true });
    report(true, { pid: Number(pid) }, `ok killed pid ${pid}`);
  }
  fail("usage: app <start|stop> [--port <n>] [--dry-run]");
}

async function health(lineArgs) {
  const port = portOf(lineArgs);
  const r = await call(port, "GET", "/health");
  if (!r) noAnswer(port);
  report(r.status === 200 && r.text.trim() === "ok", { status: r.status, body: r.text }, `${r.status === 200 ? "ok" : "FAIL"} /health -> HTTP ${r.status} "${r.text.trim()}"`);
}

async function event(lineArgs) {
  const [agent, name] = positional(lineArgs);
  if (!agent || !name) fail("usage: event <agent> <EventName> [--session <id>] [--cwd <path>], e.g. event claude Stop --session t1");
  const port = portOf(lineArgs);
  const body = JSON.stringify({ hook_event_name: name, session_id: flagOf(lineArgs, "--session") ?? "control-test", cwd: flagOf(lineArgs, "--cwd") ?? "/tmp/control-test" });
  const r = await call(port, "POST", `/event/${encodeURIComponent(agent)}`, body);
  if (!r) noAnswer(port);
  report(r.status === 204, { status: r.status }, `${r.status === 204 ? "ok" : "FAIL"} POST /event/${agent} ${name} -> HTTP ${r.status}`);
}

async function state(lineArgs) {
  const port = portOf(lineArgs);
  const r = await call(port, "GET", "/debug/state");
  if (!r) noAnswer(port);
  if (r.status === 404) fail(`/debug/state is 404: the app on ${port} was not started in debug mode  ->  ${START_HINT}`);
  let sessions;
  try { sessions = JSON.parse(r.text); } catch { fail(`/debug/state returned non-JSON: ${r.text.slice(0, 200)}`); }
  const list = Array.isArray(sessions) ? sessions : sessions.sessions ?? [];
  report(r.status === 200, { sessions: list }, list.length ? list.map((s) => `${s.id}  ${s.agent}  ${s.status}  ${s.project ?? ""}  ${(s.message ?? "").slice(0, 80)}`).join("\n") : "ok no sessions");
}

async function vercel(lineArgs) {
  const [status] = positional(lineArgs);
  if (!["building", "ready", "failed"].includes(status)) fail(`status must be building, ready or failed, got "${status ?? ""}"`);
  const port = portOf(lineArgs);
  const r = await call(port, "POST", `/debug/vercel/${status}`);
  if (!r) noAnswer(port);
  if (r.status === 404) fail(`/debug/vercel is 404: the app on ${port} was not started in debug mode  ->  ${START_HINT}`);
  report(r.status === 200, { status: r.status, body: r.text }, `${r.status === 200 ? "ok" : "FAIL"} vercel ${status} -> HTTP ${r.status} ${r.text.trim()}`);
}

// Sends a sample payload through the real bridge script, then checks the app registered the session.
async function hook(lineArgs) {
  const [agent, name = "UserPromptSubmit"] = positional(lineArgs);
  if (!["claude", "codex", "gentle"].includes(agent)) fail("usage: hook <claude|codex|gentle> [EventName], e.g. hook claude Stop");
  const port = portOf(lineArgs);
  if (!(await call(port, "GET", "/health"))) noAnswer(port);
  const id = `control-hook-${Date.now()}`;
  const payload = JSON.stringify({ hook_event_name: name, session_id: id, cwd: "/tmp/control-hook", prompt: "control test" });
  const b = spawnSync(join(root, "bridge", "agent-notch-hook"), [agent, "event"], { input: payload, encoding: "utf8", env: { ...process.env, AGENT_NOTCH_PORT: String(port) }, timeout: 15000 });
  let seen = false;
  for (let i = 0; i < 6 && !seen; i++) {
    if (i) await sleep(500);
    seen = (await call(port, "GET", "/debug/state"))?.text.includes(id) ?? false;
  }
  report(seen, { session: id, bridgeExit: b.status, seen }, seen ? `ok bridge ${agent} ${name} -> session ${id} is in /debug/state` : `FAIL session ${id} not in /debug/state after the bridge ran (exit ${b.status})  ->  is the app a debug build started with app start?`);
}

// Always sandboxed: HOME is a fresh temp dir, so the real ~/.claude, ~/.codex and ~/.local are never touched.
function sandbox(script, lineArgs) {
  if (!run("jq", ["--version"]).ok) fail("jq is required by the install scripts  ->  brew install jq");
  const dry = lineArgs.includes("--dry-run");
  const home = mkdtempSync(join(tmpdir(), "agent-notch-home-"));
  const r = spawnSync("bash", [join("scripts", script), ...(dry ? ["--dry-run"] : [])], { cwd: root, encoding: "utf8", env: { ...process.env, HOME: home } });
  const files = dry ? [] : readdirSync(home, { recursive: true, withFileTypes: true }).filter((e) => e.isFile()).map((e) => relative(home, join(e.parentPath, e.name))).sort();
  rmSync(home, { recursive: true, force: true });
  const out = `${r.stdout ?? ""}${r.stderr ?? ""}`.trim();
  report(r.status === 0, { exitCode: r.status, dryRun: dry, files, output: out }, `${r.status === 0 ? "ok" : "FAIL"} ${script}${dry ? " --dry-run" : ""} exit ${r.status} (sandboxed HOME, deleted)\n${out}${dry ? "" : `\nfiles created:\n${files.join("\n") || "(none)"}`}`);
}

function check(cmd, cmdArgs) {
  const r = run(cmd, cmdArgs);
  report(r.ok, { output: r.output }, `${r.ok ? "ok" : "FAIL"} ${cmd} ${cmdArgs.join(" ")}\n${r.output.split("\n").slice(-20).join("\n")}`);
}

const [command, ...rest] = args;
if (command === "doctor") await doctor();
else if (command === "verify") await verify();
else if (command === "screenshot") await screenshot(rest);
else if (command === "app") await app(rest);
else if (command === "health") await health(rest);
else if (command === "event") await event(rest);
else if (command === "state") await state(rest);
else if (command === "vercel") await vercel(rest);
else if (command === "hook") await hook(rest);
else if (command === "install") sandbox("install.sh", rest);
else if (command === "uninstall") sandbox("uninstall.sh", rest);
else if (command === "strings") check("python3", ["scripts/check-strings.py"]);
else if (command === "worker-test") check("node", ["--test", "integrations/vercel-worker/index.test.mjs"]);
else {
  process.stdout.write(`${HELP}\n`);
  process.exit(command && command !== "--help" && command !== "help" ? 1 : 0);
}
