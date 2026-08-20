#!/usr/bin/env node
//
//  Point every OBS video capture source at a camera that actually exists.
//
//  OBS pins a capture source to a specific device UUID. When that device is
//  unplugged the source keeps the dead reference and silently produces no
//  video -- OBS still lists it, but flagged itemEnabled=false. This walks
//  every macos-avcapture input, and if its current device is gone, moves it
//  to the best camera that is currently connected.
//
//    obs-camera.mjs            report what it sees, change nothing
//    obs-camera.mjs --apply    repair any source whose device is missing
//    obs-camera.mjs --force    repoint even sources that are working
//
//  Deliberately conservative: without --force it never touches a source
//  whose camera is present, so it cannot override a deliberate choice.

import { readFile, writeFile } from "node:fs/promises";
import { ObsClient, loadObsConfig, isObsRunning } from "./obs-lib.mjs";

const PRESET_FILE = `${process.env.HOME}/.config/sketchybar/camera-presets.json`;

const CAPTURE_KINDS = /avcapture|av_capture/i;

// Never auto-select these.
//   OBS Virtual Camera is OBS's own output -- selecting it feeds OBS back
//   into itself. Desk View is the downward-angled derived view, never the
//   face camera someone means by "my camera".
//   iPhone / Continuity is excluded on purpose: it is a manual choice, not
//   a fallback. Auto-grabbing it would hijack the phone whenever it came
//   into range. Selecting it by hand still sticks, because a source whose
//   camera is connected is never touched.
const NEVER = /virtual\s*camera|desk\s*view|iphone|ipad|continuity/i;

// Lower rank wins: external webcam (PC-LM1E) first, then the built-in
// MacBook camera. Nothing else is auto-selected.
function rank(name) {
  if (/macbook|built-?in|facetime/i.test(name)) return 2;
  return 1;
}

function pickCamera(items) {
  return items
    .filter((i) => i.itemEnabled && i.itemValue && !NEVER.test(i.itemName))
    .map((i, idx) => ({ ...i, rank: rank(i.itemName), idx }))
    .sort((a, b) => a.rank - b.rank || a.idx - b.idx)[0];
}


// ── Per-camera framing ────────────────────────────────────────────
// Different webcams have different fields of view, so one crop/position
// does not suit all of them. camera-presets.json holds a transform per
// camera; the key is matched against the OBS device name as a
// case-insensitive substring, falling back to `default`.

async function loadPresets() {
  try {
    return JSON.parse(await readFile(PRESET_FILE, "utf8"));
  } catch {
    return null;
  }
}

function presetKeyFor(cameraName, presets) {
  const keys = Object.keys(presets).filter((k) => k !== "default");
  const hit = keys.find((k) => cameraName.toLowerCase().includes(k.toLowerCase()));
  return hit ?? "default";
}

const TRANSFORM_FIELDS = [
  "positionX", "positionY", "scaleX", "scaleY", "rotation",
  "cropLeft", "cropRight", "cropTop", "cropBottom", "alignment",
];

export async function applyCameraLayout(obs, cameraName, { log = () => {} } = {}) {
  const file = await loadPresets();
  if (!file?.presets) return null;

  const scene = file._scene;
  const sourceName = file._sourceName;
  const key = presetKeyFor(cameraName, file.presets);
  const preset = file.presets[key];
  if (!preset) return null;

  const found = await obs.tryRequest("GetSceneItemId", { sceneName: scene, sourceName });
  if (!found) return null;

  const transform = {};
  for (const f of TRANSFORM_FIELDS) {
    if (preset[f] !== undefined) transform[f] = preset[f];
  }

  await obs.request("SetSceneItemTransform", {
    sceneName: scene,
    sceneItemId: found.sceneItemId,
    sceneItemTransform: transform,
  });
  log(`layout: ${scene} framed with "${key}" preset (x=${preset.positionX})`);
  return key;
}

export async function saveCameraLayout(obs) {
  const file = await loadPresets();
  if (!file?.presets) throw new Error(`no preset file at ${PRESET_FILE}`);

  const scene = file._scene;
  const sourceName = file._sourceName;
  const { inputSettings } = await obs.request("GetInputSettings", { inputName: sourceName });
  const cameraName = inputSettings.device_name || "";
  const key = presetKeyFor(cameraName, file.presets);

  const found = await obs.request("GetSceneItemId", { sceneName: scene, sourceName });
  const { sceneItemTransform: t } = await obs.request("GetSceneItemTransform", {
    sceneName: scene,
    sceneItemId: found.sceneItemId,
  });

  const saved = {};
  for (const f of TRANSFORM_FIELDS) saved[f] = t[f];
  file.presets[key] = saved;

  await writeFile(PRESET_FILE, JSON.stringify(file, null, 2) + "\n");
  return { key, cameraName, saved };
}

// "Which camera is selected right now", resolved from the device UUID
// rather than the stored device_name.
//
// device_name is only a cached label and can desync from the actual device
// (OBS rewrites it on source reload, and anything that writes settings can
// leave it stale) -- which would silently select the wrong framing preset.
// The UUID is authoritative, so it is mapped back to a real device name via
// the property list. That enumeration is comparatively expensive, so the
// result is cached and only re-fetched when the UUID actually changes.
let uuidNameCache = { uuid: null, name: "" };

export async function activeCameraName(obs) {
  const file = await loadPresets();
  const sourceName = file?._sourceName ?? "Video Capture Device";
  const res = await obs.tryRequest("GetInputSettings", { inputName: sourceName });
  const settings = res?.inputSettings;
  if (!settings) return "";

  const uuid = settings.device;
  if (!uuid) return settings.device_name ?? "";
  if (uuid === uuidNameCache.uuid) return uuidNameCache.name;

  const props = await obs.tryRequest("GetInputPropertiesListPropertyItems", {
    inputName: sourceName,
    propertyName: "device",
  });
  const match = props?.propertyItems?.find((i) => i.itemValue === uuid);
  const name = match?.itemName ?? settings.device_name ?? "";
  uuidNameCache = { uuid, name };

  // Heal a stale label so the OBS UI agrees with reality.
  if (match && settings.device_name !== match.itemName) {
    await obs.tryRequest("SetInputSettings", {
      inputName: sourceName,
      inputSettings: { ...settings, device_name: match.itemName },
      overlay: true,
    });
  }
  return name;
}

export async function repairCameras(obs, { force = false, log = () => {} } = {}) {
  const { inputs } = await obs.request("GetInputList");
  const captures = inputs.filter((i) => CAPTURE_KINDS.test(i.inputKind));
  const report = [];

  for (const input of captures) {
    const name = input.inputName;
    const { inputSettings } = await obs.request("GetInputSettings", { inputName: name });
    const props = await obs.tryRequest("GetInputPropertiesListPropertyItems", {
      inputName: name,
      propertyName: "device",
    });
    const items = props?.propertyItems ?? [];

    const current = items.find((i) => i.itemValue === inputSettings.device);
    const currentName = inputSettings.device_name || current?.itemName || "(unset)";
    const alive = Boolean(current?.itemEnabled);
    const available = items.filter(
      (i) => i.itemEnabled && i.itemValue && !NEVER.test(i.itemName),
    );

    const entry = { name, currentName, alive, available: available.map((i) => i.itemName) };

    if (alive && !force) { entry.action = "none, camera is connected"; report.push(entry); continue; }
    if (!available.length) { entry.action = "none, no camera is connected"; report.push(entry); continue; }

    const pick = pickCamera(items);
    if (pick.itemValue === inputSettings.device) {
      entry.action = "none, already on the best camera";
      report.push(entry);
      continue;
    }

    // supported_format is encoded per-device and is meaningless once the
    // device changes; use_preset makes OBS negotiate a format itself.
    const next = { ...inputSettings, device: pick.itemValue, device_name: pick.itemName };
    delete next.supported_format;
    next.use_preset = true;
    next.preset = inputSettings.preset || "AVCaptureSessionPresetHigh";

    await obs.request("SetInputSettings", { inputName: name, inputSettings: next, overlay: false });
    entry.action = `switched to ${pick.itemName}`;
    entry.changed = true;
    log(`camera: ${name} was ${currentName} [missing] -> ${pick.itemName}`);
    // Different camera, different field of view: re-frame to match.
    try {
      entry.layout = await applyCameraLayout(obs, pick.itemName, { log });
    } catch {}
    report.push(entry);
  }
  return report;
}

// ── CLI ───────────────────────────────────────────────────────────
const invokedDirectly =
  process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href;

if (invokedDirectly) {
  const args = new Set(process.argv.slice(2));
  const force = args.has("--force");
  const save = args.has("--save");
  const layoutOnly = args.has("--layout");
  const apply = args.has("--apply") || force;

  if (!(await isObsRunning())) {
    console.error("OBS is not running.");
    process.exit(1);
  }
  const obs = await new ObsClient(await loadObsConfig()).connect();
  try {
    if (save) {
      const { key, cameraName, saved } = await saveCameraLayout(obs);
      console.log(`Saved current framing as preset "${key}" (camera: ${cameraName})`);
      console.log(`  x=${saved.positionX} y=${saved.positionY} ` +
                  `scale=${saved.scaleX.toFixed(4)} crop=L${saved.cropLeft} R${saved.cropRight}`);
    } else if (layoutOnly) {
      const { inputSettings } = await obs.request("GetInputSettings", { inputName: "Video Capture Device" });
      const key = await applyCameraLayout(obs, inputSettings.device_name || "", {
        log: (m) => console.log(m),
      });
      console.log(key ? `Applied "${key}" preset.` : "No preset matched.");
    } else if (!apply) {
      // Dry run: report without writing.
      const { inputs } = await obs.request("GetInputList");
      for (const input of inputs.filter((i) => CAPTURE_KINDS.test(i.inputKind))) {
        const { inputSettings } = await obs.request("GetInputSettings", { inputName: input.inputName });
        const props = await obs.tryRequest("GetInputPropertiesListPropertyItems", {
          inputName: input.inputName, propertyName: "device",
        });
        const items = props?.propertyItems ?? [];
        const current = items.find((i) => i.itemValue === inputSettings.device);
        const available = items.filter((i) => i.itemEnabled && i.itemValue && !NEVER.test(i.itemName));
        const pick = pickCamera(items);
        console.log(`\n${input.inputName}`);
        console.log(`  current   : ${inputSettings.device_name || "(unset)"} ${current?.itemEnabled ? "[connected]" : "[MISSING]"}`);
        console.log(`  available : ${available.map((i) => i.itemName).join(", ") || "(none)"}`);
        console.log(current?.itemEnabled
          ? "  action    : none, camera is connected"
          : `  would set : ${pick ? pick.itemName : "(nothing available)"}   (dry run, pass --apply)`);
      }
    } else {
      for (const r of await repairCameras(obs, { force })) {
        console.log(`\n${r.name}`);
        console.log(`  current   : ${r.currentName} ${r.alive ? "[connected]" : "[MISSING]"}`);
        console.log(`  available : ${r.available.join(", ") || "(none)"}`);
        console.log(`  action    : ${r.action}`);
      }
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  } finally {
    obs.close();
  }
}
