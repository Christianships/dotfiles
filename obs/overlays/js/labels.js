/* Wording, in one place.

   sentence()  the grey system line Twitch prints in chat, same phrasing
   alert()     the three fields an alert card needs: label, name, detail   */
const Labels = {
  tier(t) { return t === "prime" ? "Prime" : "Tier " + (t || 1); },

  isEvent(type) { return type !== "chat" && type !== "clear" && type !== "delete" && type !== "notice"; },

  b(s) { return `<b>${U.esc(s)}</b>`; },

  sentence(ev) {
    const n = this.b((ev.user && ev.user.name) || "Someone");
    const m = ev.meta || {};
    const yt = ev.platform === "youtube";
    switch (ev.type) {
      case "sub":
        return yt ? `${n} became a member.` : `${n} subscribed at ${this.tier(m.tier)}.`;
      case "resub":
        return `${n} subscribed at ${this.tier(m.tier)}. They've subscribed for ${m.months || 1} months!`;
      case "subgift":
        return `${n} gifted a ${this.tier(m.tier)} sub to ${this.b(m.to || "a viewer")}!`;
      case "giftbomb":
        return yt ? `${n} is gifting ${m.count || 1} memberships to the community!`
                  : `${n} is gifting ${m.count || 1} ${this.tier(m.tier)} subs to the community!`;
      case "raid":
        return `${n} is raiding with a party of ${U.num(m.viewers || 0)}.`;
      case "cheer":
        return `${n} cheered ${U.num(m.bits || 0)} bits.`;
      case "follow":
        return `${n} followed.`;
      case "member":
        return m.gifted ? `${n} was gifted a membership.` : `${n} became a member.`;
      case "membermilestone":
        return `${n} has been a member for ${m.months || 1} months.`;
      case "superchat":
        return `${n} sent ${U.esc(m.amount || "a Super Chat")}.`;
      case "supersticker":
        return `${n} sent a ${U.esc(m.amount || "")} sticker.`;
      case "announcement":
        return `${n} made an announcement.`;
      default:
        return `${n} ${U.esc(ev.type)}.`;
    }
  },

  /* label is a single small word above the name - one per alert, not a
     decoration sprinkled on every element */
  alert(ev) {
    const name = (ev.user && ev.user.name) || "Someone";
    const m = ev.meta || {};
    const yt = ev.platform === "youtube";
    switch (ev.type) {
      case "sub":     return { label: yt ? "New member" : "New subscriber", name,
                               detail: yt ? (m.level || "Membership") : this.tier(m.tier), glyph: "star" };
      case "resub":   return { label: "Resubscribed", name,
                               detail: `${m.months || 1} months · ${this.tier(m.tier)}`, glyph: "star" };
      case "subgift": return { label: "Gifted a sub", name, detail: `to ${m.to || "a viewer"}`, glyph: "gift" };
      case "giftbomb":return { label: "Gifted subs", name,
                               detail: `${m.count || 1} ${yt ? "memberships" : "subs"} to the community`, glyph: "gift" };
      case "raid":    return { label: "Raid", name, detail: `${U.num(m.viewers || 0)} viewers`, glyph: "raid" };
      case "cheer":   return { label: "Cheered", name, detail: `${U.num(m.bits || 0)} bits`, glyph: "bits" };
      case "follow":  return { label: "New follower", name, detail: "", glyph: "heart" };
      case "member":  return { label: m.gifted ? "Gifted membership" : "New member", name,
                               detail: m.level || "", glyph: "star" };
      case "membermilestone":
                      return { label: "Member", name, detail: `${m.months || 1} months`, glyph: "star" };
      case "superchat":
                      return { label: "Super Chat", name, detail: m.amount || "", glyph: "bits" };
      case "supersticker":
                      return { label: "Super Sticker", name, detail: m.amount || "", glyph: "bits" };
      case "announcement":
                      return { label: "Announcement", name, detail: "", glyph: "mega" };
      default:        return { label: ev.type, name, detail: "", glyph: "star" };
    }
  },

  /* the phrase after the highlighted username on an image alert */
  did(ev) {
    const m = ev.meta || {};
    const yt = ev.platform === "youtube";
    switch (ev.type) {
      case "sub":      return yt ? "became a member" : `subscribed · ${this.tier(m.tier)}`;
      case "resub":    return `resubscribed · ${m.months || 1} months`;
      case "subgift":  return `gifted a sub to ${m.to || "a viewer"}`;
      case "giftbomb": return `gifted ${m.count || 1} ${yt ? "memberships" : "subs"}`;
      case "raid":     return `raided with ${U.num(m.viewers || 0)}`;
      case "cheer":    return `cheered ${U.num(m.bits || 0)} bits`;
      case "follow":   return "followed";
      case "member":   return m.gifted ? "was gifted a membership" : "became a member";
      case "membermilestone": return `member for ${m.months || 1} months`;
      case "superchat":       return `sent ${m.amount || "a Super Chat"}`;
      case "supersticker":    return `sent a sticker`;
      case "announcement":    return "made an announcement";
      default: return ev.type;
    }
  },

  /* art file for an event, overridable by dropping your own png/gif in img/ */
  art(ev) {
    const name = (window.OVERLAY_CONFIG.alerts.art || {})[ev.type];
    return name || `img/${ev.type}.svg`;
  },

  accent(ev) {
    if (ev.platform === "youtube") return "var(--red)";
    return ev.type === "follow" ? "#eb0400" : "var(--purple)";
  },

  /* the noun for "newest ___" on the stats strip */
  noun(ev) {
    return {
      sub: "subscriber", resub: "subscriber", subgift: "gifter", giftbomb: "gifter",
      cheer: "cheer", follow: "follower", raid: "raid",
      member: "member", membermilestone: "member",
      superchat: "Super Chat", supersticker: "Super Sticker"
    }[ev.type] || ev.type;
  },

  icon(name, size) {
    const s = size || 1;
    const p = {
      star: "M12 2.6l2.9 6.1 6.6.9-4.8 4.6 1.2 6.6L12 17.7 6.1 20.8l1.2-6.6L2.5 9.6l6.6-.9z",
      gift: "M3 11h18v10H3zM2 6h20v4H2zm10 0v15M8.5 6C6.5 6 5.5 3 8 3c1.8 0 3 1.5 4 3-1.6 0-2.6 0-3.5 0zm7 0c2 0 3-3 .5-3-1.8 0-3 1.5-4 3 1.6 0 2.6 0 3.5 0z",
      raid: "M4 20V6l8 5 8-5v14l-8-5z",
      bits: "M12 2l8 6-8 14-8-14z",
      heart: "M12 21S3 14.7 3 8.9C3 5.6 5.6 3 8.8 3c1.9 0 3.2 1 3.2 1s1.3-1 3.2-1C18.4 3 21 5.6 21 8.9 21 14.7 12 21 12 21z",
      mega: "M4 10v4h3l7 4V6l-7 4zM17 8a5 5 0 010 8"
    }[name] || "";
    return `<svg class="ico" viewBox="0 0 24 24" width="${s}em" height="${s}em" fill="currentColor" aria-hidden="true"><path d="${p}"/></svg>`;
  }
};
