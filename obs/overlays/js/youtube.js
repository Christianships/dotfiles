/* YouTube side.
   Two tiers, because Google splits them:
     apiKey only  -> subscriber count + concurrent viewers on the live stream
     + accessToken -> live chat messages, new members, milestones, super chats
   The chat endpoint (liveChatMessages.list) is the only part Google requires
   OAuth for. Without a token the counts still tick and nothing errors out. */
const YouTube = {
  key: "", token: "", channelId: "", videoId: null, chatId: null,
  page: null, timer: null, statTimer: null, stopped: false, seenBoot: false,

  async init(channelId, apiKey, accessToken) {
    this.channelId = channelId || "";
    this.key = apiKey || "";
    this.token = accessToken || "";
    if (!this.channelId || !this.key) { Bus.status("youtube", "off", "no channelId / apiKey"); return; }
    Bus.status("youtube", "connecting", this.channelId);
    await this.findLive();
    if (this.token && this.chatId) this._pollChat();
  },

  stop() { this.stopped = true; clearTimeout(this.timer); clearInterval(this.statTimer); },

  async _get(path, params, auth) {
    const url = new URL("https://www.googleapis.com/youtube/v3/" + path);
    url.searchParams.set("key", this.key);
    for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
    const headers = auth && this.token ? { Authorization: "Bearer " + this.token } : {};
    const r = await fetch(url, { headers });
    if (!r.ok) throw new Error(path + " " + r.status);
    return r.json();
  },

  /* search costs 100 quota units, so this is called sparingly (see viewers-app) */
  async findLive() {
    try {
      const s = await this._get("search", {
        part: "snippet", channelId: this.channelId, eventType: "live", type: "video", maxResults: 1
      });
      const item = s.items && s.items[0];
      this.videoId = item ? item.id.videoId : null;
      if (!this.videoId) { this.chatId = null; Bus.status("youtube", "idle", "not live"); return null; }
      const v = await this._get("videos", { part: "liveStreamingDetails", id: this.videoId });
      const d = v.items[0] && v.items[0].liveStreamingDetails;
      this.chatId = (d && d.activeLiveChatId) || null;
      Bus.status("youtube", "live", this.chatId ? "chat + stats" : "stats only");
      return this.videoId;
    } catch (e) {
      Bus.status("youtube", "error", String(e.message || e));
      return null;
    }
  },

  async stats() {
    if (!this.channelId || !this.key) return null;
    const out = { platform: "youtube", live: !!this.videoId };
    try {
      const c = await this._get("channels", { part: "statistics", id: this.channelId });
      const st = c.items[0] && c.items[0].statistics;
      out.subs = st ? Number(st.subscriberCount) : null;   // YouTube rounds this publicly
      out.views = st ? Number(st.viewCount) : null;
    } catch {}
    if (this.videoId) {
      try {
        const v = await this._get("videos", { part: "liveStreamingDetails,snippet", id: this.videoId });
        const it = v.items[0];
        out.viewers = it ? Number(it.liveStreamingDetails.concurrentViewers || 0) : 0;
        out.title = it && it.snippet.title;
      } catch {}
    } else out.viewers = 0;
    return out;
  },

  async _pollChat() {
    if (this.stopped || !this.chatId) return;
    let wait = U.cfg("youtube", "pollMs", "ytpoll") || 6000;
    try {
      const params = { liveChatId: this.chatId, part: "snippet,authorDetails", maxResults: 200 };
      if (this.page) params.pageToken = this.page;
      const d = await this._get("liveChat/messages", params, true);
      this.page = d.nextPageToken;
      wait = Math.max(d.pollingIntervalMillis || wait, 2000);
      /* the first page replays chat history - drop it so old messages do not
         all fire as alerts the moment the overlay loads */
      if (this.seenBoot) (d.items || []).forEach(i => this._msg(i));
      this.seenBoot = true;
    } catch (e) {
      Bus.status("youtube", "error", String(e.message || e));
      wait = 15000;
      if (String(e.message).includes("403") || String(e.message).includes("404")) {
        this.chatId = null;
        await this.findLive();
        if (!this.chatId) return;
      }
    }
    this.timer = setTimeout(() => this._pollChat(), wait);
  },

  _msg(item) {
    const s = item.snippet, a = item.authorDetails || {};
    const user = {
      name: a.displayName || "viewer",
      color: U.colorFor(a.displayName || "viewer"),
      avatar: a.profileImageUrl,
      badges: [
        a.isChatOwner && "broadcaster",
        a.isChatModerator && "moderator",
        a.isChatSponsor && "member"
      ].filter(Boolean)
    };
    const base = { platform: "youtube", user, ts: Date.parse(s.publishedAt) || Date.now() };
    const text = s.displayMessage || "";
    const parts = text ? [{ t: "text", v: text }] : [];

    switch (s.type) {
      case "textMessageEvent":
        return Bus.emit({ ...base, type: "chat", text, parts, meta: {} });
      case "superChatEvent":
        return Bus.emit({ ...base, type: "superchat", text: s.superChatDetails.userComment || "", parts,
          meta: { amount: s.superChatDetails.amountDisplayString, tier: s.superChatDetails.tier } });
      case "superStickerEvent":
        return Bus.emit({ ...base, type: "supersticker", text: "", parts: [],
          meta: { amount: s.superStickerDetails.amountDisplayString } });
      case "newSponsorEvent":
        return Bus.emit({ ...base, type: "member", text: "", parts: [],
          meta: { level: s.newSponsorDetails && s.newSponsorDetails.memberLevelName, upgrade: s.newSponsorDetails && s.newSponsorDetails.isUpgrade } });
      case "memberMilestoneChatEvent":
        return Bus.emit({ ...base, type: "membermilestone", text: s.memberMilestoneChatDetails.userComment || "", parts,
          meta: { months: s.memberMilestoneChatDetails.memberMonth, level: s.memberMilestoneChatDetails.memberLevelName } });
      case "membershipGiftingEvent":
        return Bus.emit({ ...base, type: "giftbomb", text: "", parts: [],
          meta: { count: s.membershipGiftingDetails.giftMembershipsCount, level: s.membershipGiftingDetails.giftMembershipsLevelName } });
      case "giftMembershipReceivedEvent":
        return Bus.emit({ ...base, type: "member", text: "", parts: [],
          meta: { gifted: true, from: s.giftMembershipReceivedDetails.gifterChannelId } });
      case "messageDeletedEvent": case "chatEndedEvent": case "sponsorOnlyModeStartedEvent":
        return;
      default:
        return;
    }
  }
};
