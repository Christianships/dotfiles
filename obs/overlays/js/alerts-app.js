/* Full-screen alert source. One card at a time, queued, never overlapping.
   Same event stream as the chat source, so anything chat can see this can announce. */
const Alerts = {
  stage: null, queue: [], busy: false, cfg: {},

  boot() {
    this.stage = document.getElementById("stage");
    this.cfg = {
      duration: U.cfg("alerts", "duration"),
      gap: U.cfg("alerts", "gap"),
      minBits: U.cfg("alerts", "minBits", "minbits"),
      sound: U.cfg("alerts", "sound")
    };
    const style = U.cfg("alerts", "style", "style");
    this.style = ["image", "native", "bar", "type"].includes(style) ? style : "image";
    document.body.classList.add("style-" + this.style);
    for (const a of ["top", "bottom", "left", "right"]) {
      if ((U.qs.get("anchor") || "").split(/[-,]/).includes(a)) document.body.classList.add(a);
    }
    /* which events are allowed, e.g. ?only=sub,resub,giftbomb,raid */
    const only = U.qs.get("only");
    this.only = only ? only.split(",").map(s => s.trim()) : null;

    Bus.init().on(ev => this.on(ev));

    /* ?show=sub,raid,member:youtube - play exactly these, in order.
       ?hold=8 keeps each one up for 8s (for screenshots and showcases). */
    const show = U.qs.get("show");
    if (show) {
      this.hold = Number(U.qs.get("hold") || 0) * 1000;
      show.split(",").map(s => s.trim()).filter(Boolean).forEach((spec, i) => {
        const [type, plat, amount] = spec.split(":");
        setTimeout(() => Demo.fire(type, plat || "twitch", amount),
                   60 + i * ((this.hold || this.cfg.duration) + this.cfg.gap + 400));
      });
      return;
    }

    if (U.qs.get("demo") === "1") {
      const reel = [["sub", "twitch"], ["resub", "twitch"], ["subgift", "twitch"],
                    ["giftbomb", "twitch"], ["raid", "twitch"], ["cheer", "twitch"],
                    ["follow", "twitch"], ["member", "youtube"], ["superchat", "youtube"],
                    ["membermilestone", "youtube"]];
      let i = 0;
      setInterval(() => { const [t, p] = reel[i++ % reel.length]; Demo.fire(t, p); }, 4000);
      Demo.fire("sub", "twitch");
      return;
    }

    const ch = U.cfg("twitch", "channel", "channel");
    TwitchIRC.connect(ch);
    TwitchAPI.init(ch, U.cfg("twitch", "clientId", "clientid"), U.cfg("twitch", "token", "token"));
    YouTube.init(U.cfg("youtube", "channelId", "yt"),
                 U.cfg("youtube", "apiKey", "ytkey"),
                 U.cfg("youtube", "accessToken", "yttoken"));
  },

  on(ev) {
    if (!Labels.isEvent(ev.type)) return;
    if (this.only && !this.only.includes(ev.type)) return;
    if (ev.type === "cheer" && (ev.meta.bits || 0) < this.cfg.minBits) return;
    this.queue.push(ev);
    this.pump();
  },

  async pump() {
    if (this.busy) return;
    this.busy = true;
    while (this.queue.length) {
      await this.show(this.queue.shift());
      await U.sleep(this.cfg.gap);
    }
    this.busy = false;
  },

  async show(ev) {
    const a = Labels.alert(ev);
    const dur = this.hold || this.cfg.duration;
    const quote = this.quote(ev);

    const card = U.el("div", `alert ${this.style} in${ev.platform === "youtube" ? " yt" : ""}`);
    const label = U.esc(a.label);
    const name = U.esc(a.name);
    const detail = U.esc(a.detail);

    if (this.style === "bar") {
      card.innerHTML =
        `<span class="label">${label}</span><span class="name">${name}</span>` +
        (detail ? `<span class="detail">${detail}</span>` : "");
    } else if (this.style === "type") {
      card.innerHTML =
        `<div class="name">${name}</div><div class="rule"></div>` +
        `<div class="label">${label}${detail ? " · " + detail : ""}</div>` +
        (quote ? `<div class="quote">${quote}</div>` : "");
    } else if (this.style === "image") {
      /* nothing behind it: art, then the name highlighted in the event colour
         followed by what they did */
      card.style.setProperty("--accent", Labels.accent(ev));
      card.innerHTML =
        `<img class="art" src="${Labels.art(ev)}" alt="" ` +
        `onerror="this.style.display='none'">` +
        `<div class="line"><span class="who">${name}</span> ` +
        `<span class="did">${U.esc(Labels.did(ev))}</span>` +
        (quote ? `<div class="quote">${quote}</div>` : "") + `</div>`;
    } else {
      card.innerHTML =
        `<span class="glyph">${Labels.icon(a.glyph, 1.9)}</span>` +
        `<div class="txt"><div class="label">${label}</div><div class="name">${name}</div>` +
        (detail ? `<div class="detail">${detail}</div>` : "") +
        (quote ? `<div class="quote">${quote}</div>` : "") + `</div>`;
    }

    this.stage.replaceChildren(card);
    this.ping(ev);
    await U.sleep(dur);
    card.classList.remove("in");
    card.classList.add("out");
    await U.sleep(300);
    if (card.isConnected) card.remove();
  },

  quote(ev) {
    const parts = ev.parts && ev.parts.length ? ev.parts : (ev.text ? [{ t: "text", v: ev.text }] : []);
    if (!parts.length) return "";
    return parts.map(p => p.t === "emote"
      ? `<img class="emote" src="${p.url}" alt="">`
      : U.esc(p.v)).join("");
  },

  /* One sound per event, with the rules that stop it becoming noise:
       - a gift bomb silences the individual gift subs that follow it
       - small cheers stay quiet
       - follows are rate limited, since they are the one thing that gets
         botted and the one you least need to hear twice */
  /* every quantity an event carries, so a "500" of any kind can be spotted */
  numbers(ev) {
    const m = ev.meta || {};
    const out = [m.bits, m.count, m.viewers, m.months, m.total];
    if (m.amount) {
      const n = parseFloat(String(m.amount).replace(/[^0-9.]/g, ""));
      if (!Number.isNaN(n)) out.push(n);
    }
    return out.filter(v => typeof v === "number" && !Number.isNaN(v));
  },

  ping(ev) {
    if (!this.cfg.sound) return;
    const cfg = window.OVERLAY_CONFIG.alerts;
    const map = cfg.sounds || {};
    let rule = map[ev.type];

    /* a matching number wins over the event's own sound */
    const nums = cfg.numberSounds || {};
    const hit = this.numbers(ev).map(v => nums[v]).find(Boolean);
    if (hit) rule = typeof hit === "string" ? { file: hit } : hit;

    if (!rule || !rule.file) return;

    if (ev.type === "giftbomb") this.giftMuteUntil = Date.now() + (window.OVERLAY_CONFIG.alerts.giftMuteMs || 15000);
    if (ev.type === "subgift" && Date.now() < (this.giftMuteUntil || 0)) return;
    if (rule.minBits && (ev.meta.bits || 0) < rule.minBits) return;
    if (rule.cooldown) {
      this.last = this.last || {};
      if (Date.now() - (this.last[ev.type] || 0) < rule.cooldown) return;
      this.last[ev.type] = Date.now();
    }

    const a = new Audio(rule.file);
    a.volume = Math.min(1, (rule.volume ?? 1) * (window.OVERLAY_CONFIG.alerts.volume ?? 1));
    /* OBS autoplays; a plain browser tab blocks until you click something */
    a.play().catch(() => {});
  }
};

document.addEventListener("DOMContentLoaded", () => Alerts.boot());
