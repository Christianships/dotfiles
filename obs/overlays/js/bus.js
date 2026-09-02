/* One event stream that every source listens to.
   Live platform events stay local to the page that produced them (each source
   opens its own socket, so re-broadcasting would double them up).
   Test events from preview.html are broadcast so they reach every iframe. */
const Bus = {
  _subs: [],
  _seen: new Set(),
  _chan: (() => { try { return new BroadcastChannel("obs-overlays"); } catch { return null; } })(),

  init() {
    if (this._chan) this._chan.onmessage = e => {
      if (e.data && e.data.__status) return;   /* status pings are not events */
      this._deliver(e.data);
    };
    window.addEventListener("message", e => {
      if (e.data && e.data.__overlay) this._deliver(e.data.__overlay);
    });
    return this;
  },

  on(fn) { this._subs.push(fn); return this; },

  emit(ev) {
    ev.id = ev.id || U.id();
    ev.ts = ev.ts || Date.now();
    this._deliver(ev);
    if (ev.test && this._chan) this._chan.postMessage(ev);
    return ev;
  },

  _deliver(ev) {
    if (!ev || !ev.type || ev.__status || this._seen.has(ev.id)) return;
    this._seen.add(ev.id);
    if (this._seen.size > 500) this._seen = new Set([...this._seen].slice(-250));
    for (const fn of this._subs) { try { fn(ev); } catch (err) { console.error(err); } }
  },

  /* status pings so preview.html can show what is actually connected */
  status(source, state, detail) {
    const p = { __status: true, source, state, detail: detail || "" };
    if (this._chan) this._chan.postMessage(p);
    try { parent.postMessage({ __overlayStatus: p }, "*"); } catch {}
  }
};

/* Event shape produced by all clients:
   { id, ts, platform:"twitch"|"youtube", type, user:{name,color,badges[]},
     parts:[{t:"text"|"emote", v|url, alt}], text, meta:{...} }
   types: chat sub resub subgift giftbomb raid cheer follow announcement
          member membermilestone superchat supersticker                       */
