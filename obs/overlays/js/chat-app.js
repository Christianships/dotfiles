/* Transparent chat source. Twitch is live with no credentials at all;
   YouTube messages join the same list when a token is configured. */
const Chat = {
  root: null, cfg: {},

  /* drawn to match Twitch's badge shapes - rounded square, white glyph.
     Used until a Helix token lets the real artwork load. */
  LOCAL_BADGES: Object.fromEntries([
    "broadcaster", "moderator", "subscriber", "founder", "vip", "premium",
    "turbo", "partner", "verified", "artist-badge", "member", "owner"
  ].map(n => [n, `img/badges/${n}.svg`])),

  boot() {
    this.root = document.getElementById("chat");
    this.cfg = {
      max: U.cfg("chat", "max"),
      fade: U.cfg("chat", "fade"),
      size: U.cfg("chat", "size"),
      badges: U.cfg("chat", "showBadges", "badges"),
      plat: U.cfg("chat", "showPlatform", "platform"),
      events: U.cfg("chat", "showEvents", "events"),
      hideCommands: U.cfg("chat", "hideCommands", "nocmd"),
      ignore: (U.cfg("chat", "ignore") || []).map(s => s.toLowerCase())
    };
    document.documentElement.style.setProperty("--fs", this.cfg.size + "px");
    /* panel = solid Twitch sidebar, scrim = dark box hugging the text,
       shadow = nothing behind it at all */
    const theme = U.cfg("chat", "theme", "theme");
    document.body.classList.add(theme);

    Bus.init().on(ev => this.on(ev));

    /* ?demo=1 rolls steady chatter, ?show=sub,raid replays those events in
       order - both stay offline, nothing connects to Twitch */
    const show = U.qs.get("show");
    const demo = U.qs.get("demo") === "1";
    if (show) {
      show.split(",").map(x => x.trim()).filter(Boolean).forEach((spec, i) => {
        const [type, plat, amount] = spec.split(":");
        setTimeout(() => Demo.fire(type, plat || "twitch", amount), 900 + i * 5400);
      });
    }
    if (demo) Demo.start(1500);
    if (demo || show) return;

    const ch = U.cfg("twitch", "channel", "channel");
    TwitchIRC.connect(ch);
    /* only for badge artwork by default - EventSub (follows) is opt-in with
       ?eventsub=1, see the note in README about Twitch's 3-subscription cap */
    TwitchAPI.init(ch, U.cfg("twitch", "clientId", "clientid"), U.cfg("twitch", "token", "token"),
                   { eventsub: U.qs.get("eventsub") === "1" });
    YouTube.init(U.cfg("youtube", "channelId", "yt"),
                 U.cfg("youtube", "apiKey", "ytkey"),
                 U.cfg("youtube", "accessToken", "yttoken"));
  },

  on(ev) {
    if (ev.type === "clear") return this.root.replaceChildren();
    if (ev.type === "delete") return this.remove(ev.meta && ev.meta.target);
    if (ev.type === "chat") return this.message(ev);
    if (Labels.isEvent(ev.type) && this.cfg.events) return this.event(ev);
  },

  remove(msgId) {
    if (!msgId) return;
    const n = this.root.querySelector(`[data-msg="${CSS.escape(msgId)}"]`);
    if (n) n.remove();
  },

  push(node) {
    this.root.appendChild(node);
    const rows = this.root.querySelectorAll(".msg");
    for (let i = 0; i < rows.length - this.cfg.max; i++) rows[i].remove();
    if (this.cfg.fade > 0) {
      setTimeout(() => {
        node.classList.add("gone");
        setTimeout(() => node.remove(), 600);
      }, this.cfg.fade * 1000);
    }
  },

  /* Real badge artwork from Helix when a token is set, otherwise the drawn
     icons in img/badges. Never text chips - a badge is a badge. */
  badges(user) {
    if (!this.cfg.badges || !user.badges || !user.badges.length) return "";
    const out = user.badges.map(b => {
      const url = Emotes.badgeUrl(b) || Chat.LOCAL_BADGES[b.split("/")[0]];
      return url ? `<img src="${url}" alt="">` : "";
    }).filter(Boolean);
    return out.length ? `<span class="badges">${out.join("")}</span>` : "";
  },

  parts(ev) {
    const parts = ev.parts && ev.parts.length ? ev.parts
                : ev.text ? [{ t: "text", v: ev.text }] : [];
    return parts.map(p => {
      if (p.t !== "emote") return U.esc(p.v);
      const img = `<img class="emote" src="${p.url}" alt="${U.esc(p.alt || "")}">`;
      return p.zwUrl
        ? `<span class="emote-stack">${img}<img class="emote zw" src="${p.zwUrl}" alt=""></span>`
        : img;
    }).join("");
  },

  message(ev) {
    const u = ev.user || {};
    const name = u.name || "viewer";
    if (this.cfg.ignore.includes((u.login || name).toLowerCase())) return;
    if (this.cfg.hideCommands && /^\s*!/.test(ev.text || "")) return;

    const n = U.el("div", "msg" + (ev.meta && ev.meta.action ? " action" : "") +
                          (ev.meta && ev.meta.firstMsg ? " first" : ""));
    n.style.setProperty("--uc", u.color || U.colorFor(name));
    if (ev.msgId) n.dataset.msg = ev.msgId;

    const reply = ev.meta && ev.meta.reply ? `<span class="re">Replying to @${U.esc(ev.meta.reply)}</span>` : "";
    const colon = ev.meta && ev.meta.action ? " " : ":";
    n.innerHTML = reply +
      `<span class="ln">${this.badges(u)}<span class="name">${U.esc(name)}</span>` +
      `<span class="sep">${colon}</span> <span class="body">${this.parts(ev)}</span></span>`;
    this.push(n);
  },

  event(ev) {
    const a = Labels.alert(ev);
    const quiet = ev.type === "follow" || ev.type === "cheer";
    const n = U.el("div", "msg notice" + (ev.platform === "youtube" ? " yt" : "") + (quiet ? " quiet" : ""));
    const body = this.parts(ev);
    const glyph = quiet ? "" : Labels.icon(a.glyph, .95);
    n.innerHTML = `<span class="ln"><span class="sys">${glyph}${Labels.sentence(ev)}</span>` +
                  (body ? `<span class="body">${body}</span>` : "") + `</span>`;
    this.push(n);
  }
};

document.addEventListener("DOMContentLoaded", () => Chat.boot());
