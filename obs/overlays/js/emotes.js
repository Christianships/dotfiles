/* Emote + badge resolution. All endpoints here are public, no token needed. */
const Emotes = {
  third: new Map(),      // name -> {url, zw}
  badges: new Map(),     // "set/version" -> image url
  ready: false,

  async load(roomId, useThird) {
    const jobs = [this.loadBadges(roomId)];
    if (useThird) jobs.push(this._seventv(roomId), this._bttv(roomId), this._ffz(roomId));
    await Promise.allSettled(jobs);
    this.ready = true;
  },

  async _get(url) {
    const r = await fetch(url);
    if (!r.ok) throw new Error(url + " " + r.status);
    return r.json();
  },

  async _seventv(roomId) {
    const sets = [this._get("https://7tv.io/v3/emote-sets/global")];
    if (roomId) sets.push(this._get(`https://7tv.io/v3/users/twitch/${roomId}`).then(u => u.emote_set));
    for (const p of await Promise.allSettled(sets)) {
      const set = p.status === "fulfilled" ? p.value : null;
      for (const e of (set && set.emotes) || []) {
        this.third.set(e.name, {
          url: `https://cdn.7tv.app/emote/${e.id}/2x.webp`,
          zw: !!(e.flags & 1) || !!(e.data && e.data.flags & 256)
        });
      }
    }
  },

  async _bttv(roomId) {
    const push = e => this.third.set(e.code, { url: `https://cdn.betterttv.net/emote/${e.id}/2x` });
    const jobs = [this._get("https://api.betterttv.net/3/cached/emotes/global").then(a => a.forEach(push))];
    if (roomId) jobs.push(this._get(`https://api.betterttv.net/3/cached/users/twitch/${roomId}`)
      .then(u => [...(u.channelEmotes || []), ...(u.sharedEmotes || [])].forEach(push)));
    await Promise.allSettled(jobs);
  },

  async _ffz(roomId) {
    const take = sets => {
      for (const k of Object.keys(sets || {})) {
        for (const e of sets[k].emoticons || []) {
          const u = e.urls[2] || e.urls[1] || e.urls[4];
          if (u) this.third.set(e.name, { url: u.startsWith("//") ? "https:" + u : u });
        }
      }
    };
    const jobs = [this._get("https://api.frankerfacez.com/v1/set/global").then(d => take(d.sets))];
    if (roomId) jobs.push(this._get(`https://api.frankerfacez.com/v1/room/id/${roomId}`).then(d => take(d.sets)));
    await Promise.allSettled(jobs);
  },

  /* Badge artwork only exists behind Helix now (the old badges.twitch.tv host is
     dead), so with no token chat falls back to the MOD / SUB text chips.
     Safe to call twice - the map dedupes. */
  async loadBadges(roomId) {
    if (!(window.TwitchAPI && TwitchAPI.on)) return;
    const take = d => {
      for (const set of d.data || []) {
        for (const v of set.versions || []) {
          this.badges.set(`${set.set_id}/${v.id}`, v.image_url_2x || v.image_url_1x);
        }
      }
    };
    const jobs = [TwitchAPI.get("chat/badges/global").then(take)];
    if (roomId) jobs.push(TwitchAPI.get("chat/badges", { broadcaster_id: roomId }).then(take));
    await Promise.allSettled(jobs);
  },

  badgeUrl(key) { return this.badges.get(key); },

  /* text + twitch `emotes` tag -> parts[]; then third-party pass over text runs */
  parse(text, emoteTag) {
    const cps = Array.from(text);
    const marks = [];
    if (emoteTag) {
      for (const chunk of emoteTag.split("/")) {
        const [id, ranges] = chunk.split(":");
        if (!ranges) continue;
        for (const r of ranges.split(",")) {
          const [a, b] = r.split("-").map(Number);
          if (Number.isFinite(a) && Number.isFinite(b)) marks.push({ a, b, id });
        }
      }
      marks.sort((x, y) => x.a - y.a);
    }
    const parts = [];
    let i = 0;
    const flushText = raw => { if (raw) parts.push(...this._third(raw)); };
    for (const m of marks) {
      flushText(cps.slice(i, m.a).join(""));
      parts.push({
        t: "emote",
        url: `https://static-cdn.jtvnw.net/emoticons/v2/${m.id}/default/dark/2.0`,
        alt: cps.slice(m.a, m.b + 1).join("")
      });
      i = m.b + 1;
    }
    flushText(cps.slice(i).join(""));
    return parts;
  },

  _third(raw) {
    const out = [];
    let buf = [];
    for (const w of raw.split(/(\s+)/)) {
      const hit = this.third.get(w.trim());
      if (hit && w.trim()) {
        if (buf.length) { out.push({ t: "text", v: buf.join("") }); buf = []; }
        if (hit.zw && out.length && out[out.length - 1].t === "emote") out[out.length - 1].zwUrl = hit.url;
        else out.push({ t: "emote", url: hit.url, alt: w.trim() });
      } else buf.push(w);
    }
    if (buf.length) out.push({ t: "text", v: buf.join("") });
    return out;
  }
};
