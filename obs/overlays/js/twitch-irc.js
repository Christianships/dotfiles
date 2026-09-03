/* Anonymous Twitch chat + event reader.
   Zero credentials: subs, resubs, gift subs, gift bombs, raids, cheers and
   announcements all arrive over IRC as USERNOTICE / PRIVMSG tags.
   (Follows are the one thing IRC cannot see - that needs EventSub, see twitch-helix.js) */
const TwitchIRC = {
  ws: null, channel: "", roomId: null, tries: 0, stopped: false,

  connect(channel) {
    this.channel = String(channel || "").toLowerCase().replace(/^#/, "");
    if (!this.channel) { Bus.status("twitch", "off", "no channel set"); return; }
    this._open();
  },

  stop() { this.stopped = true; if (this.ws) this.ws.close(); },

  _open() {
    Bus.status("twitch", "connecting", this.channel);
    const ws = this.ws = new WebSocket("wss://irc-ws.chat.twitch.tv:443");

    ws.onopen = () => {
      ws.send("CAP REQ :twitch.tv/tags twitch.tv/commands");
      ws.send("NICK justinfan" + Math.floor(Math.random() * 80000 + 1000));
      ws.send("JOIN #" + this.channel);
      this.tries = 0;
      Bus.status("twitch", "live", "#" + this.channel);
      /* Twitch accepts a JOIN for a channel that does not exist and then just
         never speaks, which looks exactly like a quiet channel. Real ones send
         ROOMSTATE within a second. */
      clearTimeout(this._roomTimer);
      this._roomTimer = setTimeout(() => {
        if (!this.roomId) {
          Bus.status("twitch", "error", `no such channel: ${this.channel}`);
          console.warn(`[chat] joined #${this.channel} but Twitch never sent ROOMSTATE - ` +
                       "check the login name, it is not always the display name");
        }
      }, 8000);
    };

    ws.onmessage = e => {
      for (const line of e.data.split(LINE_SEP)) if (line) this._line(line);
    };

    ws.onclose = () => {
      Bus.status("twitch", "down", "reconnecting");
      if (this.stopped) return;
      const wait = Math.min(30000, 1000 * Math.pow(2, this.tries++));
      setTimeout(() => this._open(), wait);
    };

    ws.onerror = () => { try { ws.close(); } catch {} };
  },

  _tags(raw) {
    const out = {};
    for (const kv of raw.split(";")) {
      const i = kv.indexOf("=");
      out[kv.slice(0, i)] = unescapeTag(kv.slice(i + 1));
    }
    return out;
  },

  _line(line) {
    if (line.startsWith("PING")) { this.ws.send("PONG :tmi.twitch.tv"); return; }

    let tags = {}, rest = line;
    if (line[0] === "@") {
      const sp = line.indexOf(" ");
      tags = this._tags(line.slice(1, sp));
      rest = line.slice(sp + 1);
    }
    const m = rest.match(/^:(\S+) ([A-Z0-9]+) (\S+)(?: :?([\s\S]*))?$/);
    if (!m) return;
    const [, prefix, cmd, , trailing] = m;
    const nick = prefix.split("!")[0];

    if (cmd === "ROOMSTATE" && tags["room-id"] && !this.roomId) {
      this.roomId = tags["room-id"];
      Emotes.load(this.roomId, U.cfg("twitch", "thirdPartyEmotes", "emotes"));
      return;
    }

    if (cmd === "PRIVMSG") return this._privmsg(tags, nick, trailing || "");
    if (cmd === "USERNOTICE") return this._usernotice(tags, nick, trailing || "");
    if (cmd === "CLEARCHAT") return Bus.emit({ platform: "twitch", type: "clear", meta: { user: trailing || null } });
    if (cmd === "CLEARMSG") return Bus.emit({ platform: "twitch", type: "delete", meta: { target: tags["target-msg-id"] } });
  },

  _user(tags, nick) {
    const name = tags["display-name"] || nick;
    return {
      name,
      login: nick,
      color: tags.color || U.colorFor(name),
      badges: (tags.badges || "").split(",").filter(Boolean),
      mod: tags.mod === "1",
      sub: /subscriber/.test(tags.badges || ""),
      broadcaster: /broadcaster/.test(tags.badges || "")
    };
  },

  _privmsg(tags, nick, text) {
    let body = text, action = false;
    const act = text.match(/^ACTION ([\s\S]*)?$/);
    if (act) { body = act[1]; action = true; }

    if (tags.bits) {
      Bus.emit({
        platform: "twitch", type: "cheer", user: this._user(tags, nick),
        text: body, parts: Emotes.parse(body, tags.emotes),
        meta: { bits: Number(tags.bits) }
      });
      return;
    }
    Bus.emit({
      platform: "twitch", type: "chat", msgId: tags.id,
      user: this._user(tags, nick),
      text: body, parts: Emotes.parse(body, tags.emotes),
      meta: { action, firstMsg: tags["first-msg"] === "1", reply: tags["reply-parent-display-name"] || null }
    });
  },

  _usernotice(tags, nick, text) {
    const user = this._user(tags, nick);
    const id = tags["msg-id"];
    const tier = ({ Prime: "prime", 1000: "1", 2000: "2", 3000: "3" })[tags["msg-param-sub-plan"]] || "1";
    const sys = (tags["system-msg"] || "").trim();
    const base = {
      platform: "twitch", user, text,
      parts: text ? Emotes.parse(text, tags.emotes) : [],
      meta: { tier, sys }
    };

    switch (id) {
      case "sub":
        return Bus.emit({ ...base, type: "sub", meta: { ...base.meta, months: 1 } });
      case "resub":
        return Bus.emit({ ...base, type: "resub",
          meta: { ...base.meta, months: Number(tags["msg-param-cumulative-months"] || 1),
                  streak: Number(tags["msg-param-streak-months"] || 0) } });
      case "subgift":
        return Bus.emit({ ...base, type: "subgift",
          meta: { ...base.meta,
                  to: tags["msg-param-recipient-display-name"] || tags["msg-param-recipient-user-name"],
                  total: Number(tags["msg-param-sender-count"] || 0) } });
      case "submysterygift":
        return Bus.emit({ ...base, type: "giftbomb",
          meta: { ...base.meta, count: Number(tags["msg-param-mass-gift-count"] || 1),
                  total: Number(tags["msg-param-sender-count"] || 0) } });
      case "giftpaidupgrade": case "anongiftpaidupgrade":
        return Bus.emit({ ...base, type: "sub", meta: { ...base.meta, months: 1, upgrade: true } });
      case "raid":
        return Bus.emit({ ...base, type: "raid",
          user: { ...user, name: tags["msg-param-displayName"] || user.name },
          meta: { ...base.meta, viewers: Number(tags["msg-param-viewerCount"] || 0),
                  avatar: tags["msg-param-profileImageURL"] || null } });
      case "announcement":
        return Bus.emit({ ...base, type: "announcement",
          meta: { ...base.meta, color: tags["msg-param-color"] || "PRIMARY" } });
      default:
        if (sys) Bus.emit({ ...base, type: "notice" });
    }
  }
};

const LINE_SEP = String.fromCharCode(13, 10);

function unescapeTag(v) {
  let out = "";
  for (let i = 0; i < v.length; i++) {
    if (v[i] !== "\\") { out += v[i]; continue; }
    const n = v[++i];
    out += n === "s" ? " " : n === "n" ? "\n" : n === "r" ? "\r" : n === ":" ? ";" : n === undefined ? "" : n;
  }
  return out;
}
