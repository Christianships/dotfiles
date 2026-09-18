#!/usr/bin/env node
//
//  TEMP + GPU + CPU + RAM -> SketchyBar, pushed once a second.
//
//  Why a daemon instead of item scripts:
//
//  CPU has no instantaneous reading on macOS, only cumulative tick counters.
//  The old plugin shelled out to `top -l 2 -n 0 -s 1`, which BLOCKS for a
//  full second to take its own two samples, and it ran on update_freq=5 --
//  so the bar showed a one-second average from up to five seconds ago.
//
//  A long-lived process can just remember the previous tick counts and diff
//  them, which is instant and free. os.cpus() exposes exactly those counters
//  per core, so no shelling out at all.

import os from "node:os";
import { execFile, spawn } from "node:child_process";
import { writeFileSync, unlinkSync } from "node:fs";

const SKETCHYBAR = process.env.SKETCHYBAR_BIN || "/opt/homebrew/bin/sketchybar";
const PID_FILE = "/tmp/sketchybar-stats-daemon.pid";
const INTERVAL_MS = 1000;

// Monotone white ramp, mirroring colors.sh. Load reads as brightness.
const W50 = "0x80ffffff";
const W65 = "0xa6ffffff";
const W80 = "0xccffffff";
const W95 = "0xf2ffffff";
// The bar is otherwise monotone -- load reads as brightness. Heat is the one
// reading where brightness is not enough, so past the danger threshold it
// breaks out of the ramp into colour. This is CRITICAL from colors.sh (Apple's
// system red), reused rather than a new red invented for one item.
const RED = "0xffff453a";
const TEMP_HOT = 90;   // °C -- M-series throttles around 100-110

const TOTAL_BYTES = os.totalmem();

function cpuSnapshot() {
  let idle = 0, total = 0;
  for (const c of os.cpus()) {
    for (const [k, v] of Object.entries(c.times)) {
      total += v;
      if (k === "idle") idle += v;
    }
  }
  return { idle, total };
}

let prev = cpuSnapshot();

function cpuPercent() {
  const cur = cpuSnapshot();
  const dTotal = cur.total - prev.total;
  const dIdle = cur.idle - prev.idle;
  prev = cur;
  if (dTotal <= 0) return null;
  return Math.max(0, Math.min(100, Math.round(((dTotal - dIdle) * 100) / dTotal)));
}

// Activity Monitor's "Memory Used": app memory (anonymous - purgeable)
// + wired + compressed. os.freemem() does not match it.
function readMemory() {
  return new Promise((resolve) => {
    execFile("/usr/bin/vm_stat", (err, stdout) => {
      if (err) return resolve(null);
      const num = (re) => {
        const m = re.exec(stdout);
        return m ? Number(m[1]) : 0;
      };
      const pageSize = num(/page size of (\d+) bytes/);
      const anon = num(/Anonymous pages:\s+(\d+)/);
      const purge = num(/Pages purgeable:\s+(\d+)/);
      const wired = num(/Pages wired down:\s+(\d+)/);
      const comp = num(/Pages occupied by compressor:\s+(\d+)/);
      if (!pageSize) return resolve(null);
      const used = (anon - purge + wired + comp) * pageSize;
      resolve({
        gb: used / 1073741824,
        pct: Math.round((used * 100) / TOTAL_BYTES),
      });
    });
  });
}

// GPU utilisation. macOS exposes this through IOKit, and `ioreg` can read it
// without sudo -- unlike `powermetrics`, which needs root and would make the
// whole bar require a privileged helper. On Apple Silicon the GPU lives under
// AGXAccelerator; the generic IOAccelerator class also matches on this machine
// but resolves to a different node that reports a constant 0, so AGX is tried
// first and the generic class is only a fallback for other hardware.
let gpuClass = "AGXAccelerator";
let gpuFellBack = false;

function readGpu() {
  return new Promise((resolve) => {
    execFile(
      "/usr/sbin/ioreg",
      ["-r", "-d", "1", "-w", "0", "-c", gpuClass],
      { maxBuffer: 1 << 22 },
      (err, stdout) => {
        if (err) return resolve(null);
        const m = /"Device Utilization %"=(\d+)/.exec(stdout || "");
        if (m) return resolve(Math.max(0, Math.min(100, Number(m[1]))));
        // Nothing matched: try the generic class once, then give up quietly.
        if (!gpuFellBack) {
          gpuFellBack = true;
          gpuClass = "IOAccelerator";
        }
        resolve(null);
      },
    );
  });
}

// Die temperature. Apple Silicon does not expose SMC temperature keys to
// ioreg the way Intel Macs did, and `powermetrics` needs root -- so this uses
// macmon, which reads the sensors unprivileged.
//
// macmon is spawned ONCE and left streaming newline-delimited JSON, rather
// than exec'd every tick. A fresh macmon per second would pay process startup
// plus its own sampling window every time; a long-lived pipe costs one process
// total and hands us a fresh reading exactly as often as we need one.
const MACMON = process.env.MACMON_BIN || "/opt/homebrew/bin/macmon";
let temps = null;   // { cpu, gpu } in Celsius, or null until the first line
let macmon = null;

function startMacmon() {
  try {
    macmon = spawn(MACMON, ["pipe", "-i", String(INTERVAL_MS)], {
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return;                       // not installed: the bar just omits temp
  }
  macmon.on("error", () => { macmon = null; });
  macmon.on("exit", () => { macmon = null; });

  let buf = "";
  macmon.stdout.setEncoding("utf8");
  macmon.stdout.on("data", (chunk) => {
    buf += chunk;
    let nl;
    // Keep only the last complete line: if we ever fall behind, the newest
    // reading is the only one worth showing.
    while ((nl = buf.indexOf("\n")) !== -1) {
      const line = buf.slice(0, nl);
      buf = buf.slice(nl + 1);
      if (!line.trim()) continue;
      try {
        const t = JSON.parse(line).temp;
        if (t) temps = { cpu: t.cpu_temp_avg, gpu: t.gpu_temp_avg };
      } catch {}
    }
    if (buf.length > 1 << 20) buf = "";   // runaway guard
  });
}

let last = null;

async function tick() {
  const cpu = cpuPercent();
  const [mem, gpu] = await Promise.all([readMemory(), readGpu()]);
  const args = [];

  // CPU die temp is what people mean by "how hot is it"; the GPU sensor sits
  // a few degrees below it under normal load.
  if (temps && Number.isFinite(temps.cpu)) {
    const c = Math.round(temps.cpu);
    const hot = c >= TEMP_HOT;
    // When hot, the number goes red too, not just the icon -- a red glyph
    // beside a white number is easy to miss at a glance. label.color is set on
    // every tick, not only when hot, so it resets itself on the way back down.
    const color = hot ? RED : c >= 75 ? W80 : c >= 60 ? W65 : W50;
    args.push(
      "--set", "temp",
      `label=${c}°`,
      `icon.color=${color}`,
      `label.color=${hot ? RED : W95}`,
    );
  }
  if (gpu !== null) {
    const color = gpu >= 85 ? W95 : gpu >= 60 ? W80 : gpu >= 35 ? W65 : W50;
    args.push("--set", "gpu", `label=${gpu}%`, `icon.color=${color}`);
  }

  if (cpu !== null) {
    const color = cpu >= 85 ? W95 : cpu >= 60 ? W80 : cpu >= 35 ? W65 : W50;
    args.push("--set", "cpu", `label=${cpu}%`, `icon.color=${color}`);
  }
  if (mem) {
    const color = mem.pct >= 90 ? W95 : mem.pct >= 75 ? W80 : W50;
    args.push("--set", "mem", `label=${mem.gb.toFixed(1)}GB`, `icon.color=${color}`);
  }
  if (!args.length) return;

  const payload = JSON.stringify(args);
  if (payload === last) return; // nothing changed, skip the fork
  last = payload;
  execFile(SKETCHYBAR, args, () => {});
}

writeFileSync(PID_FILE, String(process.pid));
for (const sig of ["SIGTERM", "SIGINT", "SIGHUP"]) {
  process.on(sig, () => {
    try { unlinkSync(PID_FILE); } catch {}
    try { macmon?.kill(); } catch {}
    process.exit(0);
  });
}

// First diff needs a baseline interval, so wait one tick before reporting.
startMacmon();
setTimeout(() => {
  tick();
  setInterval(tick, INTERVAL_MS);
}, INTERVAL_MS);
