/* One gate before you go live.

     node ~/.config/obs/golive.mjs "I Think We Finally Found Product-Market Fit"
     node ~/.config/obs/golive.mjs --check          # preflight only, touches nothing
     node ~/.config/obs/golive.mjs "..." --yes      # skip the confirm
     node ~/.config/obs/golive.mjs "..." --no-stream  # set titles, do not start

   Order matters: titles go up BEFORE the stream starts, because the title at
   the moment you go live is the one that lands in every follower notification
   and in the YouTube feed. Renaming afterwards does not recall those. */
import fs from "node:fs";
import os from "node:os";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import readline from "node:readline/promises";

const HOME = os.homedir();
const TITLE_DIR = `${HOME}/.config/obs/stream-title`;
const OVERLAYS = `${HOME}/.config/obs/overlays`;

const args = process.argv.slice(2);
const flag = f => args.includes(f);
const CHECK = flag("--check");
const YES = flag("--yes");
const NO_STREAM = flag("--no-stream");
const DESC = args.find(a => !a.startsWith("--")) || "";

const ok = s => `  \x1b[32m✓\x1b[0m ${s}`;
const warn = s => `  \x1b[33m!\x1b[0m ${s}`;
const bad = s => `  \x1b[31m✗\x1b[0m ${s}`;

/* ---------- obs-websocket ---------- */
const cfg = JSON.parse(fs.readFileSync(
  `${HOME}/Library/Application Support/obs-studio/plugin_config/obs-websocket/config.json`, "utf8"));
const sha = b => crypto.createHash("sha256").update(b).digest("base64");
let seq = 0;
const pending = new Map();
let ws;

function send(requestType, requestData = {}) {
  const requestId = "r" + ++seq;
  ws.send(JSON.stringify({ op: 6, d: { requestType, requestId, requestData } }));
  return new Promise((res, rej) => pending.set(requestId, { res, rej }));
}

function connect() {
  return new Promise((resolve, reject) => {
    ws = new WebSocket(`ws://127.0.0.1:${cfg.server_port || 4455}`);
    ws.onerror = () => reject(new Error("obs-websocket unreachable - is OBS open?"));
    ws.onmessage = e => {
      const { op, d } = JSON.parse(e.data);
      if (op === 0) {
        const a = d.authentication;
        return ws.send(JSON.stringify({ op: 1, d: {
          rpcVersion: 1,
          authentication: a ? sha(sha(cfg.server_password + a.salt) + a.challenge) : undefined,
          eventSubscriptions: 0 } }));
      }
      if (op === 2) return resolve();
      if (op === 7) {
        const p = pending.get(d.requestId);
        if (!p) return;
        pending.delete(d.requestId);
        d.requestStatus.result ? p.res(d.responseData || {})
                               : p.rej(new Error(d.requestStatus.comment || d.requestStatus.code));
      }
    };
  });
}

/* ---------- checks ---------- */
async function preflight() {
  const notes = [];
  let blocking = 0;

  const stream = await send("GetStreamStatus");
  if (stream.outputActive) { notes.push(bad("already streaming")); blocking++; }
  else notes.push(ok("not currently live"));

  const scene = await send("GetCurrentProgramScene");
  notes.push(ok(`scene: ${scene.sceneName}`));

  /* overlays still pointed at demo traffic is the classic one - you go live
     with fake subs rolling past */
  try {
    const { inputs } = await send("GetInputList");
    const names = new Set(inputs.map(i => i.inputName));
    const demo = [];
    for (const n of ["chat", "alerts", "viewers"]) {
      if (!names.has(n)) continue;
      const s = await send("GetInputSettings", { inputName: n });
      if (/demo=1|show=/.test(s.inputSettings.url || "")) demo.push(n);
    }
    if (demo.length) { notes.push(bad(`still in demo mode: ${demo.join(", ")} - run install.mjs --live`)); blocking++; }
    else notes.push(ok("overlays on the live feeds"));
  } catch { notes.push(warn("could not read overlay sources")); }

  /* a chat overlay with no channel set shows nothing once you are live */
  try {
    const conf = fs.readFileSync(`${OVERLAYS}/config.js`, "utf8");
    const ch = (conf.match(/channel:\s*"([^"]*)"/) || [])[1];
    if (ch) notes.push(ok(`twitch channel: ${ch}`));
    else notes.push(warn("no twitch channel - chat will be empty (set it at :7788/panel)"));
  } catch {}

  /* audio: alerts should be audible and not muted */
  try {
    const m = await send("GetInputMute", { inputName: "alerts" });
    m.inputMuted ? notes.push(warn("alerts audio is muted in the mixer")) : notes.push(ok("alerts audio live"));
  } catch { notes.push(warn("no alerts audio channel")); }

  /* credentials for the title push */
  try {
    const c = JSON.parse(fs.readFileSync(`${TITLE_DIR}/config.json`, "utf8"));
    const missing = ["twitch", "youtube"].filter(p => !(c[p] || {}).client_id);
    if (missing.length) { notes.push(bad(`no ${missing.join(" + ")} credentials - titles cannot be set`)); blocking++; }
    else notes.push(ok("title credentials present"));
  } catch { notes.push(bad("stream-title/config.json unreadable")); blocking++; }

  return { notes, blocking };
}

/* ---------- run ---------- */
const title = (desc, extra = []) =>
  execFileSync("python3", [`${TITLE_DIR}/stream_title.py`, "set", desc, ...extra],
               { encoding: "utf8", cwd: TITLE_DIR });

(async () => {
  await connect().catch(e => { console.error(bad(e.message)); process.exit(1); });

  console.log("\npreflight");
  const { notes, blocking } = await preflight();
  notes.forEach(n => console.log(n));

  if (!CHECK && !DESC) {
    console.log(`\n${warn("no description given - pass one, or use --check")}`);
    process.exit(1);
  }

  if (DESC) {
    console.log("\ntitle");
    process.stdout.write(title(DESC, ["--dry"]).split("\n").map(l => "  " + l).join("\n") + "\n");
  }

  if (CHECK) { console.log("\ncheck only, nothing sent"); ws.close(); process.exit(0); }
  if (blocking) { console.log(`\n${bad(`${blocking} blocking issue(s) - fix and rerun`)}`); ws.close(); process.exit(1); }

  if (!YES) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const a = (await rl.question(`\npush titles${NO_STREAM ? "" : " and go live"}? [y/N] `)).trim().toLowerCase();
    rl.close();
    if (a !== "y" && a !== "yes") { console.log("cancelled"); ws.close(); process.exit(0); }
  }

  console.log("\npushing titles");
  process.stdout.write(title(DESC).split("\n").map(l => "  " + l).join("\n") + "\n");

  if (NO_STREAM) { console.log("\ntitles set, not starting the stream"); ws.close(); process.exit(0); }

  await send("StartStream");
  console.log(`\n${ok("streaming")}`);
  console.log(warn("obs-multi-rtmp targets start from its dock - this only starts the main output"));
  ws.close();
  process.exit(0);
})();
