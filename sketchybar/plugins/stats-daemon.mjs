#!/usr/bin/env node
//
//  CPU + RAM -> SketchyBar, pushed once a second.
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
import { execFile } from "node:child_process";
import { writeFileSync, unlinkSync } from "node:fs";

const SKETCHYBAR = process.env.SKETCHYBAR_BIN || "/opt/homebrew/bin/sketchybar";
const PID_FILE = "/tmp/sketchybar-stats-daemon.pid";
const INTERVAL_MS = 1000;

// Monotone white ramp, mirroring colors.sh. Load reads as brightness.
const W50 = "0x80ffffff";
const W65 = "0xa6ffffff";
const W80 = "0xccffffff";
const W95 = "0xf2ffffff";

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

let last = null;

async function tick() {
  const cpu = cpuPercent();
  const mem = await readMemory();
  const args = [];

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
    process.exit(0);
  });
}

// First diff needs a baseline interval, so wait one tick before reporting.
setTimeout(() => {
  tick();
  setInterval(tick, INTERVAL_MS);
}, INTERVAL_MS);
