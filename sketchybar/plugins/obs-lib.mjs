// Minimal obs-websocket v5 client, shared by the bridge daemon and the
// one-shot request CLI. No npm dependencies: Node's global WebSocket and
// node:crypto cover everything the v5 protocol needs.

import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { execFile } from "node:child_process";

const OBS_CONFIG = `${process.env.HOME}/Library/Application Support/obs-studio/plugin_config/obs-websocket/config.json`;

// obs-websocket EventSubscription bitmask.
export const SUB = {
  General: 1 << 0,
  Config: 1 << 1,
  Scenes: 1 << 2,
  Inputs: 1 << 3,
  Transitions: 1 << 4,
  Filters: 1 << 5,
  Outputs: 1 << 6,
};

const sha256b64 = (v) => createHash("sha256").update(v).digest("base64");

export async function loadObsConfig() {
  const config = JSON.parse(await readFile(OBS_CONFIG, "utf8"));
  if (!config.server_enabled) throw new Error("OBS WebSocket server is disabled");
  return config;
}

export function isObsRunning() {
  return new Promise((resolve) => {
    execFile("/usr/bin/pgrep", ["-x", "OBS"], (err) => resolve(!err));
  });
}

export class ObsClient {
  constructor(config, { subscriptions = 0, onEvent, onClose } = {}) {
    this.config = config;
    this.subscriptions = subscriptions;
    this.onEvent = onEvent;
    this.onClose = onClose;
    this.nextId = 1;
    this.pending = new Map();
    this.closed = false;
  }

  connect(timeoutMs = 5000) {
    return new Promise((resolve, reject) => {
      let settled = false;
      const done = (fn, arg) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        fn(arg);
      };
      const timer = setTimeout(
        () => done(reject, new Error("OBS connect timed out")),
        timeoutMs,
      );

      this.ws = new WebSocket(`ws://127.0.0.1:${this.config.server_port}`);

      this.ws.addEventListener("error", () =>
        done(reject, new Error("OBS WebSocket error")),
      );

      this.ws.addEventListener("close", () => {
        this.closed = true;
        // Fail any in-flight requests so callers never hang on a dead socket.
        for (const { reject: rej } of this.pending.values()) {
          rej(new Error("OBS connection closed"));
        }
        this.pending.clear();
        done(reject, new Error("OBS connection closed"));
        this.onClose?.();
      });

      this.ws.addEventListener("message", (event) => {
        const msg = JSON.parse(event.data);

        if (msg.op === 0) {
          // Hello: answer the auth challenge if the server requires one.
          const identify = {
            rpcVersion: 1,
            eventSubscriptions: this.subscriptions,
          };
          if (msg.d.authentication) {
            const { challenge, salt } = msg.d.authentication;
            const secret = sha256b64(`${this.config.server_password}${salt}`);
            identify.authentication = sha256b64(`${secret}${challenge}`);
          }
          this.ws.send(JSON.stringify({ op: 1, d: identify }));
        } else if (msg.op === 2) {
          done(resolve, this);
        } else if (msg.op === 5) {
          this.onEvent?.(msg.d.eventType, msg.d.eventData ?? {});
        } else if (msg.op === 7) {
          const p = this.pending.get(msg.d.requestId);
          if (!p) return;
          this.pending.delete(msg.d.requestId);
          if (msg.d.requestStatus.result) p.resolve(msg.d.responseData ?? {});
          else
            p.reject(
              new Error(
                msg.d.requestStatus.comment ||
                  `OBS error ${msg.d.requestStatus.code}`,
              ),
            );
        }
      });
    });
  }

  request(requestType, requestData = {}) {
    if (this.closed) return Promise.reject(new Error("OBS connection closed"));
    const requestId = String(this.nextId++);
    return new Promise((resolve, reject) => {
      this.pending.set(requestId, { resolve, reject });
      this.ws.send(JSON.stringify({ op: 6, d: { requestType, requestId, requestData } }));
    });
  }

  // Convenience for optional endpoints (virtual cam, older OBS builds).
  async tryRequest(requestType, requestData = {}) {
    try {
      return await this.request(requestType, requestData);
    } catch {
      return null;
    }
  }

  close() {
    try {
      this.ws?.close();
    } catch {}
  }
}
