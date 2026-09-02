/* Fake traffic so every source can be designed and previewed with nothing
   connected. Any overlay accepts ?demo=1; preview.html also fires these
   one at a time from its buttons. */
const Demo = {
  names: ["kaiwren", "pixelnoodle", "Mothlight", "dev_null", "Aster", "ochoa_", "grim__", "Nova",
          "tinyvolcano", "LagSwitch", "Bramble", "quietstorm", "hexbyte", "Fennec", "0xJuno"],
  lines: [
    "that transition was clean", "wait how did you do that", "chat we are so back",
    "LETSGOOO", "the audio is perfect now", "first time catching you live!",
    "o7", "is this the new overlay?", "monospace supremacy", "W stream",
    "kekw", "run it back", "brb making coffee", "the orange is a choice and i respect it",
    "you should try the other lut", "no way that worked first try"
  ],

  pick(a) { return a[Math.floor(Math.random() * a.length)]; },

  user(platform) {
    const name = this.pick(this.names);
    const roll = Math.random();
    return {
      name, login: name.toLowerCase(),
      color: U.colorFor(name),
      badges: roll > 0.85 ? ["moderator/1", "subscriber/12"] : roll > 0.55 ? ["subscriber/3"] : [],
      sub: roll > 0.55,
      platform
    };
  },

  chat(platform) {
    const p = platform || (Math.random() > 0.35 ? "twitch" : "youtube");
    const text = this.pick(this.lines);
    return Bus.emit({ test: true, platform: p, type: "chat", user: this.user(p),
                      text, parts: [{ t: "text", v: text }], meta: {} });
  },

  fire(type, platform, n) {
    const p = platform || "twitch";
    const u = this.user(p);
    const kit = {
      sub:        { meta: { tier: "1", months: 1 } },
      resub:      { meta: { tier: "2", months: 1 + Math.floor(Math.random() * 40), streak: 6 },
                    text: "still here, still watching", parts: [{ t: "text", v: "still here, still watching" }] },
      subgift:    { meta: { tier: "1", to: this.pick(this.names.filter(n => n !== u.name)), total: 12 } },
      giftbomb:   { meta: { tier: "1", count: this.pick([5, 10, 20, 50]), total: 61 } },
      raid:       { meta: { viewers: 20 + Math.floor(Math.random() * 900) } },
      cheer:      { meta: { bits: this.pick([100, 500, 1000, 5000]) },
                    text: "take my bits", parts: [{ t: "text", v: "take my bits" }] },
      follow:     { meta: {} },
      announcement: { text: "overlay test in progress", parts: [{ t: "text", v: "overlay test in progress" }], meta: {} },
      member:     { meta: { level: "Sidekick" } },
      membermilestone: { meta: { months: 9, level: "Sidekick" },
                    text: "9 months!", parts: [{ t: "text", v: "9 months!" }] },
      superchat:  { meta: { amount: this.pick(["$5.00", "$20.00", "$100.00"]), tier: 4 },
                    text: "keep it up", parts: [{ t: "text", v: "keep it up" }] }
    }[type] || { meta: {} };
    const ev = { test: true, platform: p, type, user: u, parts: [], ...kit };
    /* an explicit amount, so you can fire exactly 500 bits or a $500 tip
       instead of waiting for the random one */
    if (n !== undefined && n !== null && n !== "" && !Number.isNaN(Number(n))) {
      const v = Number(n);
      ev.meta = { ...ev.meta };
      if (type === "cheer") ev.meta.bits = v;
      else if (type === "raid") ev.meta.viewers = v;
      else if (type === "giftbomb") ev.meta.count = v;
      else if (type === "resub" || type === "membermilestone") ev.meta.months = v;
      else if (type === "superchat") ev.meta.amount = "$" + v.toFixed(2);
      else ev.meta.count = v;
    }
    return Bus.emit(ev);
  },

  /* rolling chatter + the occasional event */
  start(ms) {
    this.stop();
    this._t = setInterval(() => {
      if (Math.random() > 0.88) {
        const yt = Math.random() > 0.7;
        this.fire(this.pick(yt ? ["member", "membermilestone", "superchat"]
                               : ["sub", "resub", "cheer", "follow", "subgift"]),
                  yt ? "youtube" : "twitch");
      }
      else this.chat();
    }, ms || 1800);
  },

  stop() { clearInterval(this._t); }
};
