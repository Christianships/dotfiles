/* Adds the three overlay browser sources to a scene over obs-websocket.
   OBS stays open - it writes the scene collection out itself.

     node install.mjs                 # add to "01 CAMERA"
     node install.mjs "02 SCREEN"     # or any other scene
     node install.mjs "01 CAMERA" --remove
     node install.mjs --sync           # pull positions back out of OBS
     node install.mjs --refresh        # reload the pages after editing them

   Testing without going live:
     node install.mjs --demo           # steady chat + every alert on a reel
     node install.mjs --fire=raid      # play one event, then go back to normal
     node install.mjs --fire=sub,giftbomb,follow
     node install.mjs --all            # every effect, one after another
     node install.mjs --live           # back to the real feeds

   The websocket password is read from OBS's own plugin config, so there is
   nothing to type in and no credential stored here. */
import fs from "node:fs";
import os from "node:os";
import crypto from "node:crypto";

const DIR = "/Users/christianaguilar/.config/obs/overlays";
const SCENE = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : "01 CAMERA";
const REMOVE = process.argv.includes("--remove");
const SYNC = process.argv.includes("--sync");
const REFRESH = process.argv.includes("--refresh");
const DEMO = process.argv.includes("--demo");
const LIVE = process.argv.includes("--live");
const FIRE = (process.argv.find(a => a.startsWith("--fire=")) || "").slice(7);
const HOLD = Number((process.argv.find(a => a.startsWith("--hold=")) || "").slice(7)) || 5;

/* Positions live in layout.json so the simulator and OBS never drift apart. */
const LAYOUT = JSON.parse(fs.readFileSync(DIR + "/layout.json", "utf8"));
const SOURCES = LAYOUT.sources;

const cfgPath = os.homedir() + "/Library/Application Support/obs-studio/plugin_config/obs-websocket/config.json";
const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
if (!cfg.server_enabled) {
  console.error("obs-websocket is off. OBS -> Tools -> WebSocket Server Settings -> Enable.");
  process.exit(1);
}

const sha = b => crypto.createHash("sha256").update(b).digest("base64");
const ws = new WebSocket(`ws://127.0.0.1:${cfg.server_port || 4455}`);
let seq = 0;
const pending = new Map();

function send(requestType, requestData = {}) {
  const requestId = "r" + ++seq;
  ws.send(JSON.stringify({ op: 6, d: { requestType, requestId, requestData } }));
  return new Promise((resolve, reject) => pending.set(requestId, { resolve, reject }));
}

ws.onmessage = async e => {
  const { op, d } = JSON.parse(e.data);

  if (op === 0) {
    const a = d.authentication;
    const auth = a ? sha(sha(cfg.server_password + a.salt) + a.challenge) : undefined;
    ws.send(JSON.stringify({ op: 1, d: { rpcVersion: 1, authentication: auth, eventSubscriptions: 0 } }));
    return;
  }

  if (op === 2) { run().catch(err => { console.error(err); process.exit(1); }); return; }

  if (op === 7) {
    const p = pending.get(d.requestId);
    if (!p) return;
    pending.delete(d.requestId);
    d.requestStatus.result ? p.resolve(d.responseData || {})
                           : p.reject(new Error(`${d.requestType}: ${d.requestStatus.comment || d.requestStatus.code}`));
  }
};

ws.onerror = () => { console.error("cannot reach obs-websocket - is OBS running?"); process.exit(1); };

async function run() {
  const { scenes } = await send("GetSceneList");
  const scene = scenes.find(s => s.sceneName === SCENE);
  if (!scene) {
    console.error(`no scene named "${SCENE}". have: ${scenes.map(s => s.sceneName).join(", ")}`);
    process.exit(1);
  }

  const url = (s, q) => `file://${DIR}/${s.file}${q ? "?" + q : ""}`;
  const setUrl = (s, q) =>
    send("SetInputSettings", { inputName: s.name, inputSettings: { url: url(s, q) }, overlay: true });

  /* --demo / --live: point every source at fake traffic and back again */
  if (DEMO || LIVE) {
    for (const s of SOURCES) await setUrl(s, DEMO ? "demo=1" : "");
    console.log(DEMO ? "demo running in OBS - chat rolls, alerts cycle every event"
                     : "back on the real feeds");
    ws.close(); process.exit(0);
  }

  /* --all: the full audition - every sound in the set, then every way the
     500 override can trigger. Gift subs run before the bomb on purpose, since
     a bomb mutes them for 15s afterwards. */
  if (process.argv.includes("--all")) {
    process.argv.push("--hold=8");
    return runFire([
      "follow", "sub", "resub", "subgift", "giftbomb", "raid",
      "cheer:twitch:100", "member:youtube", "membermilestone:youtube",
      "superchat:youtube:20", "announcement",
      "cheer:twitch:500", "superchat:youtube:500", "raid:twitch:500", "giftbomb:twitch:500"
    ], 8, setUrl);
  }

  /* --fire: play specific events once, in chat and as alerts at the same time,
     then put the sources back the way they were */
  if (FIRE) return runFire(FIRE.split(",").map(x => x.trim()).filter(Boolean), HOLD, setUrl);

  /* --refresh: OBS caches these pages hard, so editing a css or js file does
     not show up until the source is reloaded without cache */
  if (REFRESH) {
    for (const s of SOURCES) {
      try {
        await send("PressInputPropertiesButton", { inputName: s.name, propertyName: "refreshnocache" });
        console.log(`refreshed ${s.name}`);
      } catch (e) { console.log(`skipped   ${s.name} (${e.message})`); }
    }
    ws.close(); process.exit(0);
  }

  /* --sync: you dragged something in OBS, write that back into layout.json so
     the simulator matches and the next run does not snap it home again */
  if (SYNC) {
    const { sceneItems } = await send("GetSceneItemList", { sceneName: SCENE });
    for (const s of SOURCES) {
      const it = sceneItems.find(i => i.sourceName === s.name);
      if (!it) continue;
      const t = it.sceneItemTransform;
      s.x = Math.round(t.positionX); s.y = Math.round(t.positionY);
      s.w = Math.round(t.sourceWidth); s.h = Math.round(t.sourceHeight);
      /* scale is separate from source size - the simulator needs both or it
         draws a source you enlarged in OBS at its original size */
      s.scale = Number(t.scaleX.toFixed(3));
      console.log(`synced   ${s.name}  ${s.w}x${s.h} @ ${s.x},${s.y}` +
                  (s.scale !== 1 ? `  scaled ${s.scale}x` : ""));
    }
    fs.writeFileSync(DIR + "/layout.json", JSON.stringify(LAYOUT, null, 2) + "\n");
    console.log("\nlayout.json updated");
    ws.close(); process.exit(0);
  }

  const { inputs } = await send("GetInputList");
  const existing = new Set(inputs.map(i => i.inputName));

  for (const s of SOURCES) {
    if (REMOVE) {
      if (existing.has(s.name)) { await send("RemoveInput", { inputName: s.name }); console.log(`removed  ${s.name}`); }
      continue;
    }

    const settings = {
      url: `file://${DIR}/${s.file}`,
      width: s.w,
      height: s.h,
      /* alerts need to reach the mixer so OBS controls the level and the stream
         actually carries it; without this the sound only goes to your desktop */
      reroute_audio: s.name === "alerts",
      restart_when_active: false,   /* keep chat history across scene switches */
      shutdown: false,              /* stay connected while the scene is hidden */
      webpage_control_level: 0
    };

    let sceneItemId;
    if (existing.has(s.name)) {
      /* already there from a previous run - refresh the settings instead of duplicating */
      await send("SetInputSettings", { inputName: s.name, inputSettings: settings, overlay: true });
      const { sceneItems } = await send("GetSceneItemList", { sceneName: SCENE });
      const item = sceneItems.find(i => i.sourceName === s.name);
      sceneItemId = item ? item.sceneItemId
                         : (await send("CreateSceneItem", { sceneName: SCENE, sourceName: s.name })).sceneItemId;
      console.log(`updated  ${s.name}`);
    } else {
      ({ sceneItemId } = await send("CreateInput", {
        sceneName: SCENE, inputName: s.name, inputKind: "browser_source",
        inputSettings: settings, sceneItemEnabled: true
      }));
      console.log(`added    ${s.name}  ${s.w}x${s.h}`);
    }

    /* spell the whole transform out - a partial one lets OBS keep whatever
       alignment or bounds the item was created with, which moves it off canvas */
    await send("SetSceneItemTransform", {
      sceneName: SCENE, sceneItemId,
      sceneItemTransform: {
        positionX: s.x, positionY: s.y,
        scaleX: s.scale || 1, scaleY: s.scale || 1, rotation: 0,
        alignment: 5,                      /* top-left */
        boundsType: "OBS_BOUNDS_NONE",
        cropLeft: 0, cropRight: 0, cropTop: 0, cropBottom: 0
      }
    });
  }

  console.log(REMOVE ? `\ncleared from "${SCENE}"` : `\napplied to "${SCENE}"`);
  ws.close();
  process.exit(0);
}

async function runFire(list, hold, setUrl) {
  for (const s of SOURCES) {
    if (s.name === "alerts") await setUrl(s, `show=${list.join(",")}&hold=${hold}`);
    else if (s.name === "chat") await setUrl(s, `demo=1&show=${list.join(",")}`);
    else await setUrl(s, "demo=1");
  }
  const step = hold + 0.8;
  const secs = Math.ceil(2 + list.length * step);
  console.log(`${list.length} events, ${step}s apart - watch OBS for about ${secs}s\n`);
  list.forEach((e, i) => console.log(`  ${String(i + 1).padStart(2)}. +${String(Math.round(i * step)).padStart(3)}s  ${e}`));
  await new Promise(r => setTimeout(r, secs * 1000));
  for (const s of SOURCES) await setUrl(s, "");
  console.log("\ndone, sources restored");
  ws.close();
  process.exit(0);
}
