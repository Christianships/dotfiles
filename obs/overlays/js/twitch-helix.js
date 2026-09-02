/* Optional Twitch layer: everything IRC cannot give you.
   Needs clientId + a USER access token with:
     moderator:read:followers   -> follow alerts + follower count
     channel:read:subscriptions -> sub count / sub points
     bits:read                  -> cheer events (IRC already covers cheers in chat)
   With no token this stays quiet and the rest of the overlays keep working. */
const TwitchAPI = {
  clientId: "", token: "", userId: null, login: "", ws: null, stopped: false, tries: 0,

  get on() { return !!(this.clientId && this.token); },

  async init(login, clientId, token, opts) {
    this.login = String(login || "").toLowerCase();
    this.clientId = clientId || "";
    this.token = (token || "").replace(/^oauth:/, "");
    this.wantEventsub = !opts || opts.eventsub !== false;
    if (!this.on) { Bus.status("helix", "off", "no token - follows + counts disabled"); return false; }
    try {
      const u = await this.get("users", { login: this.login });
      this.userId = u.data[0] && u.data[0].id;
      if (!this.userId) throw new Error("channel not found");
      Bus.status("helix", "live", "id " + this.userId);
      Emotes.loadBadges(this.userId);
      if (this.wantEventsub) this._eventsub();
      return true;
    } catch (e) {
      Bus.status("helix", "error", String(e.message || e));
      return false;
    }
  },

  async get(path, params) {
    const url = new URL("https://api.twitch.tv/helix/" + path);
    for (const [k, v] of Object.entries(params || {})) url.searchParams.set(k, v);
    const r = await fetch(url, {
      headers: { "Client-Id": this.clientId, Authorization: "Bearer " + this.token }
    });
    if (!r.ok) throw new Error(path + " " + r.status);
    return r.json();
  },

  /* one call, everything the viewers overlay needs */
  async stats() {
    if (!this.on || !this.userId) return null;
    const out = { platform: "twitch" };
    const jobs = [
      this.get("streams", { user_id: this.userId })
        .then(d => { const s = d.data[0]; out.live = !!s; out.viewers = s ? s.viewer_count : 0;
                     out.title = s && s.title; out.game = s && s.game_name; out.since = s && s.started_at; }),
      this.get("channels/followers", { broadcaster_id: this.userId, first: 1 })
        .then(d => { out.followers = d.total; }),
      this.get("subscriptions", { broadcaster_id: this.userId, first: 1 })
        .then(d => { out.subs = d.total; out.points = d.points; })
    ];
    await Promise.allSettled(jobs);
    return out;
  },

  _eventsub() {
    const ws = this.ws = new WebSocket("wss://eventsub.wss.twitch.tv/ws");
    ws.onmessage = async e => {
      const msg = JSON.parse(e.data);
      const t = msg.metadata && msg.metadata.message_type;
      if (t === "session_welcome") return this._subscribe(msg.payload.session.id);
      if (t === "notification") return this._event(msg.payload.subscription.type, msg.payload.event);
      if (t === "session_reconnect") {
        const next = new WebSocket(msg.payload.session.reconnect_url);
        next.onmessage = ws.onmessage; next.onclose = ws.onclose;
        this.ws = next;
      }
    };
    ws.onclose = () => {
      if (this.stopped) return;
      setTimeout(() => this._eventsub(), Math.min(30000, 1000 * Math.pow(2, this.tries++)));
    };
  },

  async _subscribe(session) {
    const b = this.userId;
    /* Only follows by default. Everything else already arrives over IRC, and
       Twitch caps you at 3 live subscriptions per type+condition - no point
       spending them twice over. TwitchAPI.ircOff = true swaps IRC out for these. */
    const want = [["channel.follow", "2", { broadcaster_user_id: b, moderator_user_id: b }]];
    if (this.ircOff) want.push(
      ["channel.subscribe", "1", { broadcaster_user_id: b }],
      ["channel.subscription.gift", "1", { broadcaster_user_id: b }],
      ["channel.subscription.message", "1", { broadcaster_user_id: b }],
      ["channel.cheer", "1", { broadcaster_user_id: b }],
      ["channel.raid", "1", { to_broadcaster_user_id: b }]
    );
    let ok = 0;
    for (const [type, version, condition] of want) {
      try {
        const r = await fetch("https://api.twitch.tv/helix/eventsub/subscriptions", {
          method: "POST",
          headers: {
            "Client-Id": this.clientId,
            Authorization: "Bearer " + this.token,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({ type, version, condition, transport: { method: "websocket", session_id: session } })
        });
        if (r.ok) ok++;
      } catch {}
    }
    this.tries = 0;
    Bus.status("eventsub", ok ? "live" : "error", ok + "/" + want.length + " subscriptions");
  },

  /* EventSub payloads -> the same shape IRC produces.
     IRC already emits subs/gifts/raids/cheers, so only follows are emitted here
     unless ircOff is set - otherwise every sub would fire twice. */
  _event(type, ev) {
    const user = {
      name: ev.user_name || ev.from_broadcaster_user_name || "anonymous",
      login: ev.user_login || ev.from_broadcaster_user_login,
      color: U.colorFor(ev.user_name || "anonymous"),
      badges: []
    };
    if (type === "channel.follow") {
      return Bus.emit({ platform: "twitch", type: "follow", user, meta: {} });
    }
    if (!this.ircOff) return;
    const map = {
      "channel.subscribe": () => ({ type: "sub", meta: { tier: (ev.tier || "1000").slice(0, 1), months: 1 } }),
      "channel.subscription.message": () => ({ type: "resub", text: ev.message && ev.message.text,
        meta: { tier: (ev.tier || "1000").slice(0, 1), months: ev.cumulative_months } }),
      "channel.subscription.gift": () => ({ type: "giftbomb", meta: { count: ev.total, total: ev.cumulative_total } }),
      "channel.cheer": () => ({ type: "cheer", text: ev.message, meta: { bits: ev.bits } }),
      "channel.raid": () => ({ type: "raid", meta: { viewers: ev.viewers } })
    };
    const f = map[type];
    if (f) Bus.emit({ platform: "twitch", user, parts: [], ...f() });
  }
};
