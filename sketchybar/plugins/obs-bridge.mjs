#!/usr/bin/env node
//
//  OBS -> SketchyBar bridge.
//
//  Holds one long-lived obs-websocket connection and pushes state into the
//  bar as events arrive, so scene switches and record start/stop land
//  instantly instead of on a poll interval. Reconnects on its own, and
//  hides the whole OBS group whenever OBS is not running.
//
//  Glyphs are written as \u{...} escapes so this file stays pure ASCII.

import { execFile } from "node:child_process";
import { writeFileSync, unlinkSync, existsSync, readFileSync } from "node:fs";
import { ObsClient, loadObsConfig, isObsRunning, SUB } from "./obs-lib.mjs";
import { repairCameras, applyCameraLayout, activeCameraName } from "./obs-camera.mjs";
import {
  repairDisplay,
  listDisplays,
  displaySignature,
  focusedMonitorName,
} from "./obs-display.mjs";

const SKETCHYBAR = process.env.SKETCHYBAR_BIN || "/opt/homebrew/bin/sketchybar";
const SELF_DIR = new URL(".", import.meta.url).pathname;
const OBS_REQUEST = `${SELF_DIR}obs-request.mjs`;
// process.execPath is the version-pinned Cellar path (.../node/25.9.0_3/...),
// which would rot in generated click scripts the next time node upgrades.
// Prefer the stable Homebrew symlink when it exists.
const NODE = existsSync("/opt/homebrew/bin/node")
  ? "/opt/homebrew/bin/node"
  : process.execPath;
const PID_FILE = "/tmp/sketchybar-obs-bridge.pid";

// Mirrors colors.sh. Kept as literals because this process never sources shell.
const C = {
  ink: "0xff0e0e10",
  text: "0xf2ffffff",
  dim: "0x59ffffff",
  soft: "0xccffffff",
  glass: "0x14ffffff",
  glassStrong: "0xe60e0e10",
  transparent: "0x00000000",
  edgeSoft: "0x1fffffff",
  // The only colour left in the bar. Recording state must never be
  // misread at a glance, so it keeps a hue while everything else is white.
  live: "0xffff453a",
  liveDim: "0x59ff453a",
  edgeLive: "0xaaff453a",
  // Mouse-follow indicator.
  follow: "0xff32d74b",
  followDim: "0x4032d74b",
};

const ICON = {
  scene: "\u{F03D}",
  rec: "\u{F111}",
  recIdle: "\u{F10C}",
  pause: "\u{F04C}",
  live: "\u{F0459}",
  vcam: "\u{F05A0}",
  cursor: "\u{F245}",
  dot: "\u{F09DE}",
};

// Monotone: every scene icon is the same soft white. The scene name sits
// right next to it, so hue was redundant identity.
const SCENE_ICON_COLOR = C.soft;

function hhmmss(ms) {
  const total = Math.max(0, Math.floor((ms ?? 0) / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
}

// Sorted by name, not sceneIndex. The scenes are deliberately numbered
// ("00 START", "01 CAMERA", ...) and that numbering is the intended order,
// whereas sceneIndex reflects however they happen to be stacked in the OBS
// UI -- currently "00 START" sits at index 3, so index order would list them
// out of sequence.
function orderScenes(scenes) {
  return [...(scenes ?? [])]
    .map((s) => s.sceneName)
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
}

const shq = (s) => `'${String(s).replace(/'/g, `'\\''`)}'`;

// ── State ──────────────────────────────────────────────────────────
const state = {
  connected: false,
  scene: null,
  scenes: [],
  recording: false,
  recordPaused: false,
  recordMs: 0,
  streaming: false,
  streamMs: 0,
  streamBytes: 0,
  streamSkipped: 0,
  streamTotalFrames: 0,
  congestion: 0,
  reconnecting: false,
  streamService: null,
  virtualCam: false,
};

let pulseOn = true;
let popupItems = [];
let streamPopupItems = [];
let lastStreamPopup = null;
let lastPayload = null;

function sb(args) {
  if (!args.length) return;
  execFile(SKETCHYBAR, args, () => {});
}

// ── Rendering ──────────────────────────────────────────────────────
function buildArgs() {
  const off = (name) => ["--set", name, "drawing=off"];

  if (!state.connected) {
    return [
      ...off("obs.scene"),
      ...off("obs.rec"),
      ...off("obs.stream"),
      ...off("obs.cam"),
      ...off("obs.follow"),
    ];
  }

  const args = [];

  // Scene
  args.push(
    "--set", "obs.scene", "drawing=on",
    `icon=${ICON.scene}`,
    `icon.color=${SCENE_ICON_COLOR}`,
    "label.drawing=on",
    `label=${state.scene ?? "no scene"}`,
    `label.color=${C.text}`,
  );

  // Record. Idle still draws a dim hollow dot: it doubles as the
  // click target for starting a recording.
  if (state.recording && state.recordPaused) {
    args.push(
      "--set", "obs.rec", "drawing=on",
      "icon=PAUSED",
      `icon.color=${C.soft}`,
      "label.drawing=on",
      `label=${ICON.pause}`,
      `label.color=${C.soft}`,
    );
  } else if (state.recording) {
    // Reads "REC" beside a blinking red dot, mirroring the LIVE badge, so
    // the two tallies are identical in form. No elapsed time: a tally is
    // glanced at, not read, and dropping it keeps the badge narrow enough
    // that record + live + cam together still clear the notch.
    args.push(
      "--set", "obs.rec", "drawing=on",
      "icon=REC",
      `icon.color=${C.text}`,
      "label.drawing=on",
      `label=${ICON.dot}`,
      `label.color=${pulseOn ? C.live : C.liveDim}`,
    );
  } else {
    // Hidden when not recording, exactly like the LIVE badge. An idle tally
    // is just a dead black chip taking up space.
    args.push(...off("obs.rec"));
  }

  // LIVE tally. Deliberately no elapsed time: the record item already
  // carries a clock, and the point of this badge is to be unmissable at a
  // glance, not to be read. The dot blinks off the same pulse as the record
  // dot, which the duration timer drives once per second.
  if (state.streaming) {
    args.push(
      "--set", "obs.stream", "drawing=on",
      "icon=LIVE",
      `icon.color=${C.text}`,
      "label.drawing=on",
      `label=${ICON.dot}`,
      `label.color=${pulseOn ? C.live : C.liveDim}`,
    );
  } else {
    args.push(...off("obs.stream"));
  }

  // Virtual camera
  if (state.virtualCam) {
    args.push(
      "--set", "obs.cam", "drawing=on",
      `icon=${ICON.vcam}`,
      `icon.color=${C.soft}`,
      "label.drawing=off",
    );
  } else {
    args.push(...off("obs.cam"));
  }

  return args;
}

function render() {
  const args = buildArgs();
  const payload = JSON.stringify(args);
  if (payload === lastPayload) return; // nothing changed, skip the fork
  lastPayload = payload;
  sb(args);
}

// Popup menu listing every scene, rebuilt only when the scene list changes.
function rebuildPopup() {
  const args = [];
  for (const item of popupItems) args.push("--remove", item);
  popupItems = [];

  state.scenes.forEach((name, i) => {
    const item = `obs.scene.popup.${i}`;
    popupItems.push(item);
    const click =
      `${shq(NODE)} ${shq(OBS_REQUEST)} scene ${shq(name)}; ` +
      `${shq(SKETCHYBAR)} --set obs.scene popup.drawing=off`;
    args.push(
      "--add", "item", item, "popup.obs.scene",
      "--set", item,
      `icon=${ICON.scene}`,
      `icon.color=${SCENE_ICON_COLOR}`,
      "icon.padding_left=10",
      "icon.padding_right=8",
      `label=${name}`,
      `label.color=${C.text}`,
      "label.padding_right=14",
      "background.padding_left=0",
      "background.padding_right=0",
      `click_script=${click}`,
    );
  });

  if (args.length) sb(args);
}


// Stream health popup, from OBS's own numbers. Deliberately not per-platform:
// OBS knows about exactly one RTMP target, so claiming per-service status
// would be inventing data. See notes in the README of this config.
function streamPopupRows() {
  const kbps = state.streamMs > 0
    ? Math.round((state.streamBytes * 8) / state.streamMs)
    : 0;
  const dropped = state.streamTotalFrames > 0
    ? ((state.streamSkipped / state.streamTotalFrames) * 100).toFixed(1)
    : "0.0";

  const rows = [["Service", state.streamService || "not configured"]];
  if (state.streaming) {
    rows.push(["Status", state.reconnecting ? "RECONNECTING" : "LIVE"]);
    rows.push(["Uptime", hhmmss(state.streamMs)]);
    rows.push(["Bitrate", `${kbps} kbps`]);
    rows.push(["Dropped", `${state.streamSkipped} (${dropped}%)`]);
    if (state.congestion > 0.05) rows.push(["Congestion", `${Math.round(state.congestion * 100)}%`]);
  } else {
    rows.push(["Status", "offline"]);
  }
  return rows;
}

function rebuildStreamPopup() {
  const rows = streamPopupRows();
  const signature = JSON.stringify(rows);
  if (signature === lastStreamPopup) return;
  lastStreamPopup = signature;

  const args = [];
  for (const item of streamPopupItems) args.push("--remove", item);
  streamPopupItems = [];

  rows.forEach(([key, value], i) => {
    const item = `obs.stream.popup.${i}`;
    streamPopupItems.push(item);
    const hot = value === "LIVE" || value === "RECONNECTING";
    args.push(
      "--add", "item", item, "popup.obs.stream",
      "--set", item,
      `icon=${key}`,
      `icon.color=${C.dim}`,
      "icon.font=JetBrainsMono Nerd Font:SemiBold:11.0",
      "icon.padding_left=10",
      "icon.padding_right=10",
      `label=${value}`,
      `label.color=${hot ? C.live : C.text}`,
      "label.font=JetBrainsMono Nerd Font:Bold:11.0",
      "label.padding_right=12",
    );
  });
  if (args.length) sb(args);
}

// ── OBS wiring ─────────────────────────────────────────────────────
let durationTimer = null;
let deviceTimer = null;
let lastDisplaySig = null;
let cameraTick = 0;
let lastCameraName = null;

// A capture source pinned to a device that has gone away silently produces
// nothing -- OBS keeps the dead reference. This watches both:
//
//   displays  enumerating them is a ~10ms local call, so poll often and only
//             touch OBS when a monitor was actually plugged or unplugged.
//   cameras   availability has to be asked of OBS, so check less often.
//
// Camera repair never overrides a camera that is connected. Display capture
// always follows the preferred screen, because plugging a monitor in is
// itself the signal that you moved to it.

// ── Mouse-follow indicator ────────────────────────────────────────
// cTrack's obs-smooth-follow.mjs writes its PID here while running and
// removes the file on exit, so PID-file-plus-liveness is an accurate probe.
// Hidden entirely when the follower is not running.
const FOLLOW_PID = "/tmp/ctrack-obs-smooth-follow.pid";

let followTimer = null;
let followPulse = true;
let lastFollowPayload = null;

function followIsActive() {
  try {
    const pid = Number(readFileSync(FOLLOW_PID, "utf8").trim());
    if (!pid) return false;
    process.kill(pid, 0); // signal 0 only tests existence
    return true;
  } catch {
    return false;
  }
}

function renderFollow() {
  let args;
  if (followIsActive()) {
    followPulse = !followPulse;
    args = [
      "--set", "obs.follow", "drawing=on",
      `icon=${ICON.cursor}`,
      `icon.color=${C.soft}`,
      "label.drawing=on",
      `label=${ICON.dot}`,
      `label.color=${followPulse ? C.follow : C.followDim}`,
    ];
  } else {
    args = ["--set", "obs.follow", "drawing=off"];
  }
  const payload = JSON.stringify(args);
  // While inactive the payload never changes, so this stops forking; while
  // active the pulse flips every tick, which is the blink.
  if (payload === lastFollowPayload) return;
  lastFollowPayload = payload;
  sb(args);
}

function stopFollowWatch() {
  if (followTimer) {
    clearInterval(followTimer);
    followTimer = null;
  }
  lastFollowPayload = null;
}

function startFollowWatch() {
  stopFollowWatch();
  renderFollow();
  followTimer = setInterval(renderFollow, 1000);
}

function stopDeviceWatch() {
  if (deviceTimer) {
    clearInterval(deviceTimer);
    deviceTimer = null;
  }
  lastDisplaySig = null;
  lastCameraName = null;
}

function startDeviceWatch(obs) {
  stopDeviceWatch();
  startFollowWatch();
  const logLine = (m) => console.log(`[${new Date().toISOString()}] ${m}`);

  const tick = async () => {
    const periodic = cameraTick % 6 === 0; // every 6th 5s tick == 30s
    try {
      const displays = await listDisplays();
      // Keyed on both the connected set AND which monitor has focus, so
      // simply moving between two already-connected screens retargets the
      // capture too -- not just plugging one in or out.
      const sig = `${displaySignature(displays)}|${await focusedMonitorName()}`;
      const changed = sig !== lastDisplaySig;
      lastDisplaySig = sig;
      // Also re-check on the slow cadence so a UUID that went stale some
      // other way (an OBS restart, a profile switch) still converges
      // instead of sitting wrong.
      if (changed || periodic) {
        await repairDisplay(obs, { log: logLine });
      }
    } catch {}

    // Full availability check is comparatively expensive (it enumerates
    // device properties), so keep it on the slow cadence.
    if (periodic) {
      try {
        await repairCameras(obs, { log: logLine });
      } catch {}
    }

    // Re-framing only needs the selected device name, which is one cheap
    // request, so check it every tick. Applying ONLY on change is what
    // makes this safe: it catches a camera swapped by hand in the OBS UI
    // and the first connect, without fighting you while you drag the
    // source around to reposition it.
    try {
      const cam = await activeCameraName(obs);
      if (cam && cam !== lastCameraName) {
        lastCameraName = cam;
        await applyCameraLayout(obs, cam, { log: logLine });
      }
    } catch {}

    cameraTick++;
  };

  cameraTick = 0;
  tick();
  deviceTimer = setInterval(tick, 5000);
}

function stopDurationTimer() {
  if (durationTimer) {
    clearInterval(durationTimer);
    durationTimer = null;
  }
}

function syncDurationTimer(obs) {
  const needed = state.recording || state.streaming;
  if (!needed) {
    stopDurationTimer();
    pulseOn = true;
    return;
  }
  if (durationTimer) return;
  durationTimer = setInterval(async () => {
    pulseOn = !pulseOn; // gentle blink on the record dot
    if (state.recording) {
      const r = await obs.tryRequest("GetRecordStatus");
      if (r) {
        state.recordMs = r.outputDuration ?? 0;
        state.recordPaused = Boolean(r.outputPaused);
      }
    }
    if (state.streaming) {
      const st = await obs.tryRequest("GetStreamStatus");
      if (st) {
        state.streamMs = st.outputDuration ?? 0;
        state.streamBytes = st.outputBytes ?? 0;
        state.streamSkipped = st.outputSkippedFrames ?? 0;
        state.streamTotalFrames = st.outputTotalFrames ?? 0;
        state.congestion = st.outputCongestion ?? 0;
        state.reconnecting = Boolean(st.outputReconnecting);
      }
      rebuildStreamPopup();
    }
    render();
  }, 1000);
}

async function hydrate(obs) {
  const [sceneList, rec, stream, cam] = await Promise.all([
    obs.tryRequest("GetSceneList"),
    obs.tryRequest("GetRecordStatus"),
    obs.tryRequest("GetStreamStatus"),
    obs.tryRequest("GetVirtualCamStatus"),
  ]);

  if (sceneList) {
    state.scene = sceneList.currentProgramSceneName ?? null;
    // OBS returns scenes bottom-up; flip to match the order shown in the UI.
    state.scenes = orderScenes(sceneList.scenes);
    rebuildPopup();
  }
  if (rec) {
    state.recording = Boolean(rec.outputActive);
    state.recordPaused = Boolean(rec.outputPaused);
    state.recordMs = rec.outputDuration ?? 0;
  }
  if (stream) {
    state.streaming = Boolean(stream.outputActive);
    state.streamMs = stream.outputDuration ?? 0;
    state.streamBytes = stream.outputBytes ?? 0;
    state.streamSkipped = stream.outputSkippedFrames ?? 0;
    state.streamTotalFrames = stream.outputTotalFrames ?? 0;
    state.congestion = stream.outputCongestion ?? 0;
    state.reconnecting = Boolean(stream.outputReconnecting);
  }
  const svc = await obs.tryRequest("GetStreamServiceSettings");
  state.streamService =
    svc?.streamServiceSettings?.service ??
    (svc?.streamServiceType === "rtmp_custom" ? "Custom RTMP" : null);
  rebuildStreamPopup();
  state.virtualCam = Boolean(cam?.outputActive);

  state.connected = true;
  render();
  syncDurationTimer(obs);
  startDeviceWatch(obs);
}

function handleEvent(obs, type, data) {
  switch (type) {
    case "CurrentProgramSceneChanged":
      state.scene = data.sceneName;
      break;
    case "SceneListChanged":
      state.scenes = orderScenes(data.scenes);
      rebuildPopup();
      break;
    case "SceneNameChanged":
      hydrate(obs).catch(() => {});
      return;
    case "RecordStateChanged":
      state.recording = Boolean(data.outputActive);
      if (!state.recording) {
        state.recordMs = 0;
        state.recordPaused = false;
      }
      if (data.outputState === "OBS_WEBSOCKET_OUTPUT_PAUSED") state.recordPaused = true;
      if (data.outputState === "OBS_WEBSOCKET_OUTPUT_RESUMED") state.recordPaused = false;
      syncDurationTimer(obs);
      break;
    case "StreamStateChanged":
      state.streaming = Boolean(data.outputActive);
      if (!state.streaming) state.streamMs = 0;
      syncDurationTimer(obs);
      rebuildStreamPopup();
      break;
    case "VirtualcamStateChanged":
      state.virtualCam = Boolean(data.outputActive);
      break;
    case "ExitStarted":
      markDisconnected();
      return;
    default:
      return;
  }
  render();
}

function markDisconnected() {
  stopDurationTimer();
  stopDeviceWatch();
  stopFollowWatch();
  state.connected = false;
  state.recording = false;
  state.streaming = false;
  state.virtualCam = false;
  render();
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  writeFileSync(PID_FILE, String(process.pid));
  render(); // start hidden until proven otherwise

  for (;;) {
    if (!(await isObsRunning())) {
      markDisconnected();
      await sleep(4000);
      continue;
    }

    let obs;
    try {
      const config = await loadObsConfig();
      const closed = new Promise((resolve) => {
        obs = new ObsClient(config, {
          subscriptions: SUB.General | SUB.Scenes | SUB.Outputs,
          onEvent: (type, data) => handleEvent(obs, type, data),
          onClose: resolve,
        });
      });
      await obs.connect();
      await hydrate(obs);
      await closed; // park here until OBS goes away
    } catch {
      // fall through to the retry delay
    } finally {
      obs?.close();
      markDisconnected();
    }

    await sleep(2000);
  }
}

for (const sig of ["SIGTERM", "SIGINT", "SIGHUP"]) {
  process.on(sig, () => {
    try {
      unlinkSync(PID_FILE);
    } catch {}
    process.exit(0);
  });
}

main();
