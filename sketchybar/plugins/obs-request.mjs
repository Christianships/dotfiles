#!/usr/bin/env node
// One-shot OBS actions for click handlers: connect, fire, exit.
//
//   obs-request.mjs scene "01 BUILD"
//   obs-request.mjs record-toggle | record-pause-toggle
//   obs-request.mjs stream-toggle | cam-toggle

import { ObsClient, loadObsConfig, isObsRunning } from "./obs-lib.mjs";

const [action, ...rest] = process.argv.slice(2);

const ACTIONS = {
  scene: (obs) =>
    obs.request("SetCurrentProgramScene", { sceneName: rest.join(" ") }),
  "record-toggle": (obs) => obs.request("ToggleRecord"),
  "record-pause-toggle": (obs) => obs.request("ToggleRecordPause"),
  "stream-toggle": (obs) => obs.request("ToggleStream"),
  "cam-toggle": (obs) => obs.request("ToggleVirtualCam"),
};

const run = ACTIONS[action];
if (!run) {
  console.error(`unknown action: ${action}`);
  console.error(`expected one of: ${Object.keys(ACTIONS).join(", ")}`);
  process.exit(2);
}

if (!(await isObsRunning())) {
  console.error("OBS is not running");
  process.exit(1);
}

let obs;
try {
  obs = await new ObsClient(await loadObsConfig()).connect();
  await run(obs);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  obs?.close();
}
