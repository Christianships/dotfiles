#!/usr/bin/env node
//
//  Keep OBS's screen capture pointed at the screen you're actually using.
//
//  OBS pins display capture to a CoreGraphics display UUID. Plug in an
//  external monitor and the source keeps capturing the built-in panel;
//  unplug it and the source is left holding a UUID that no longer exists.
//
//  Rule: follow the monitor AeroSpace says is focused -- that is the screen
//  you are actually working on. A static "prefer external" rule was wrong:
//  with both screens connected it could never follow you back to the laptop
//  panel. When focus cannot be resolved, the built-in MacBook panel is the
//  default; an external is only picked if the built-in is inactive (lid
//  shut, clamshell).
//
//    obs-display.mjs           report what it sees, change nothing
//    obs-display.mjs --apply   move capture to the preferred display

import { execFile } from "node:child_process";
import { ObsClient, loadObsConfig, isObsRunning } from "./obs-lib.mjs";

const HELPER = new URL("../helpers/display-info", import.meta.url).pathname;

// OBS screen_capture `type`: 0 = display, 1 = window, 2 = application.
// Only display capture is ours to retarget.
const TYPE_DISPLAY = 0;

export function listDisplays() {
  return new Promise((resolve) => {
    execFile(HELPER, (err, stdout) => {
      if (err) return resolve([]);
      try {
        resolve(JSON.parse(stdout));
      } catch {
        resolve([]);
      }
    });
  });
}

// AeroSpace names monitors identically to CoreGraphics ("Built-in Retina
// Display", "HP P24h G4"), so the focused monitor maps straight onto a
// display UUID.
export function focusedMonitorName() {
  return new Promise((resolve) => {
    execFile(
      "/opt/homebrew/bin/aerospace",
      ["list-monitors", "--focused", "--format", "%{monitor-name}"],
      (err, stdout) => resolve(err ? "" : stdout.trim()),
    );
  });
}

// Whichever screen you are working on wins.
//
// When that cannot be determined -- AeroSpace not running, or it names a
// monitor CoreGraphics does not know -- fall back to the built-in MacBook
// panel, which is the default screen. An external is only chosen if the
// built-in is inactive, i.e. the lid is shut in clamshell.
export function pickDisplay(displays, focusedName = "") {
  const active = displays.filter((d) => d.active);

  if (focusedName) {
    const hit = active.find((d) => d.name === focusedName);
    if (hit) return hit;
  }

  const builtin = active.find((d) => d.builtin);
  if (builtin) return builtin;

  const externals = active.filter((d) => !d.builtin);
  if (externals.length) {
    return externals.sort(
      (a, b) =>
        Number(b.main) - Number(a.main) ||
        b.width * b.height - a.width * a.height,
    )[0];
  }
  return active[0] ?? displays[0];
}

// A stable signature of the connected set, so a caller can skip the OBS
// round-trip entirely while nothing has been plugged or unplugged.
export function displaySignature(displays) {
  return displays
    .filter((d) => d.active)
    .map((d) => d.uuid)
    .sort()
    .join(",");
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Rebuilding drops a frame or two, so never do it while live.
async function isBroadcasting(obs) {
  const rec = await obs.tryRequest("GetRecordStatus");
  const st = await obs.tryRequest("GetStreamStatus");
  return Boolean(rec?.outputActive || st?.outputActive);
}

// Every scene item referencing a source, with enough state to rebuild it.
async function collectItems(obs, sourceName) {
  const { scenes } = await obs.request("GetSceneList");
  const out = [];
  for (const s of scenes) {
    const { sceneItems } = await obs.request("GetSceneItemList", { sceneName: s.sceneName });
    for (const it of sceneItems) {
      if (it.sourceName !== sourceName) continue;
      out.push({
        scene: s.sceneName,
        index: it.sceneItemIndex,
        enabled: it.sceneItemEnabled,
        locked: it.sceneItemLocked,
        blendMode: it.sceneItemBlendMode,
        transform: it.sceneItemTransform,
      });
    }
  }
  return out;
}

// True when the capture is producing no frames. OBS reports a live screen
// capture at the display's pixel size; a stuck one sits at 0x0.
export async function captureIsDead(obs, sourceName) {
  const items = await collectItems(obs, sourceName);
  if (!items.length) return false;
  return items.every((i) => i.transform.sourceWidth === 0);
}

// Destroy and recreate the capture source.
//
// After a display is attached or removed, OBS's macOS screen capture can end
// up holding a ScreenCaptureKit stream it never restarts -- the source
// reports 0x0 forever. Updating settings, flipping capture type and toggling
// visibility were all verified to do nothing; only a fresh source captures
// again, which is why restarting OBS "fixed" it.
//
// Order matters and is the whole trick: OBS refuses to destroy an input
// while any scene item still references it, and a half-removed input becomes
// a zombie that cannot be re-added to a scene. So every scene item is removed
// FIRST, then the input is polled until it is really gone, and only then is
// it recreated.
export async function rebuildCapture(obs, { sourceName, settings, log = () => {} } = {}) {
  const items = await collectItems(obs, sourceName);
  if (!items.length) return false;

  const filters = (await obs.tryRequest("GetSourceFilterList", { sourceName }))?.filters ?? [];
  if (filters.length) {
    log(`display: refusing to rebuild ${sourceName}, it has ${filters.length} filter(s)`);
    return false;
  }

  // Release every reference so the input can actually be destroyed.
  for (const it of items) {
    const found = await obs.tryRequest("GetSceneItemId", { sceneName: it.scene, sourceName });
    if (!found) continue;
    await obs.tryRequest("SetSceneItemLocked", {
      sceneName: it.scene, sceneItemId: found.sceneItemId, sceneItemLocked: false,
    });
    await obs.tryRequest("RemoveSceneItem", { sceneName: it.scene, sceneItemId: found.sceneItemId });
  }
  await obs.tryRequest("RemoveInput", { inputName: sourceName });

  const stillThere = async () =>
    (await obs.request("GetInputList")).inputs.some((i) => i.inputName === sourceName);

  let gone = false;
  for (let i = 0; i < 20; i++) {
    await sleep(500);
    if (!(await stillThere())) { gone = true; break; }
  }
  if (!gone) {
    log(`display: ABORT, ${sourceName} would not release; scenes left without it`);
    return false;
  }

  const first = items[0];
  const created = await obs.request("CreateInput", {
    sceneName: first.scene, inputName: sourceName, inputKind: "screen_capture",
    inputSettings: settings, sceneItemEnabled: first.enabled,
  });
  const ids = { [first.scene]: created.sceneItemId };
  for (const it of items.slice(1)) {
    const r = await obs.request("CreateSceneItem", {
      sceneName: it.scene, sourceName, sceneItemEnabled: it.enabled,
    });
    ids[it.scene] = r.sceneItemId;
  }

  await sleep(1800); // let the stream start before restoring layout

  for (const it of items) {
    const id = ids[it.scene];
    const t = it.transform;
    await obs.tryRequest("SetSceneItemTransform", {
      sceneName: it.scene, sceneItemId: id,
      sceneItemTransform: {
        positionX: t.positionX, positionY: t.positionY,
        scaleX: t.scaleX, scaleY: t.scaleY,
        rotation: t.rotation, alignment: t.alignment,
        boundsType: t.boundsType, boundsAlignment: t.boundsAlignment,
        boundsWidth: t.boundsWidth, boundsHeight: t.boundsHeight,
        cropLeft: t.cropLeft, cropRight: t.cropRight,
        cropTop: t.cropTop, cropBottom: t.cropBottom,
      },
    });
    await obs.tryRequest("SetSceneItemIndex", { sceneName: it.scene, sceneItemId: id, sceneItemIndex: it.index });
    await obs.tryRequest("SetSceneItemBlendMode", { sceneName: it.scene, sceneItemId: id, sceneItemBlendMode: it.blendMode });
    if (it.locked) {
      await obs.tryRequest("SetSceneItemLocked", { sceneName: it.scene, sceneItemId: id, sceneItemLocked: true });
    }
  }

  log(`display: rebuilt ${sourceName}, ${items.length} scene item(s) restored`);
  return true;
}

export async function repairDisplay(obs, { log = () => {} } = {}) {
  const displays = await listDisplays();
  if (!displays.length) return [];

  const target = pickDisplay(displays, await focusedMonitorName());
  if (!target) return [];

  const { inputs } = await obs.request("GetInputList");
  const captures = inputs.filter((i) => i.inputKind === "screen_capture");
  const report = [];

  for (const input of captures) {
    const name = input.inputName;
    const { inputSettings } = await obs.request("GetInputSettings", { inputName: name });

    if ((inputSettings.type ?? TYPE_DISPLAY) !== TYPE_DISPLAY) continue;

    const current = inputSettings.display_uuid;
    const currentDisplay = displays.find((d) => d.uuid === current);
    const entry = {
      name,
      currentName: currentDisplay?.name ?? "(disconnected)",
      alive: Boolean(currentDisplay),
      target: target.name,
      available: displays.filter((d) => d.active).map((d) => d.name),
    };

    if (current === target.uuid) {
      entry.action = `none, already on ${target.name}`;
      report.push(entry);
      continue;
    }

    // overlay:false replaces the settings wholesale rather than merging.
    // A merged update can leave the capture engine holding its old stream,
    // which is why the display only appeared to change after an OBS restart.
    await obs.request("SetInputSettings", {
      inputName: name,
      inputSettings: { ...inputSettings, display_uuid: target.uuid },
      overlay: false,
    });
    entry.action = `switched to ${target.name}`;
    entry.changed = true;
    log(`display: ${name} ${entry.currentName} -> ${target.name}`);

    // Setting the UUID is not proof the capture restarted. Verify frames
    // are flowing and rebuild the source if they are not.
    await sleep(1200);
    if ((await captureIsDead(obs, name)) && !(await isBroadcasting(obs))) {
      await rebuildCapture(obs, {
        sourceName: name,
        settings: { ...inputSettings, display_uuid: target.uuid },
        log,
      });
      entry.rebuilt = true;
    }
    report.push(entry);
  }

  // A capture can also be dead without the display having changed at all,
  // e.g. it died on undock and the UUID happened to still be correct.
  for (const input of captures) {
    if (report.find((r) => r.name === input.inputName)?.rebuilt) continue;
    if (!(await captureIsDead(obs, input.inputName))) continue;
    if (await isBroadcasting(obs)) continue;
    const { inputSettings } = await obs.request("GetInputSettings", { inputName: input.inputName });
    if ((inputSettings.type ?? TYPE_DISPLAY) !== TYPE_DISPLAY) continue;
    await rebuildCapture(obs, {
      sourceName: input.inputName,
      settings: { ...inputSettings, display_uuid: target.uuid },
      log,
    });
  }

  return report;
}

// ── CLI ───────────────────────────────────────────────────────────
const invokedDirectly =
  process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href;

if (invokedDirectly) {
  const apply = process.argv.includes("--apply");
  const displays = await listDisplays();

  console.log("displays:");
  for (const d of displays) {
    console.log(
      `  ${d.name}  ${d.width}x${d.height}  ${d.builtin ? "built-in" : "EXTERNAL"}${d.main ? " (main)" : ""}`,
    );
  }
  const target = pickDisplay(displays, await focusedMonitorName());
  console.log(`\npreferred : ${target?.name ?? "(none)"}`);

  if (!(await isObsRunning())) {
    console.error("\nOBS is not running.");
    process.exit(1);
  }
  const obs = await new ObsClient(await loadObsConfig()).connect();
  try {
    if (!apply) {
      const { inputs } = await obs.request("GetInputList");
      for (const i of inputs.filter((x) => x.inputKind === "screen_capture")) {
        const { inputSettings } = await obs.request("GetInputSettings", { inputName: i.inputName });
        const cur = displays.find((d) => d.uuid === inputSettings.display_uuid);
        console.log(`\n${i.inputName}`);
        console.log(`  current   : ${cur?.name ?? "(disconnected)"}`);
        console.log(
          inputSettings.display_uuid === target?.uuid
            ? `  action    : none, already on ${target.name}`
            : `  would set : ${target?.name}   (dry run, pass --apply)`,
        );
      }
    } else {
      for (const r of await repairDisplay(obs)) {
        console.log(`\n${r.name}`);
        console.log(`  current   : ${r.currentName}`);
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
