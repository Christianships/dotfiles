/* tiny helpers shared by every source */
const U = {
  qs: new URLSearchParams(location.search),

  /* config with query-param overrides. cfg("chat","size") -> ?size=26 wins */
  cfg(section, key, alias) {
    const raw = this.qs.get(alias || key);
    const base = (window.OVERLAY_CONFIG[section] || {})[key];
    if (raw === null) return base;
    if (typeof base === "boolean") return raw !== "0" && raw !== "false";
    if (typeof base === "number") return Number(raw);
    if (Array.isArray(base)) return raw.split(",").map(s => s.trim()).filter(Boolean);
    return raw;
  },

  esc(s) {
    return String(s).replace(/[&<>"']/g, c =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  },

  /* deterministic readable color for users with no color set */
  colorFor(name) {
    let h = 0;
    for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
    return `hsl(${h % 360} 78% 68%)`;
  },

  num(n) {
    if (n === null || n === undefined || Number.isNaN(n)) return "--";
    if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1).replace(/\.0$/, "") + "M";
    if (n >= 1e4) return (n / 1e3).toFixed(0) + "K";
    if (n >= 1e3) return (n / 1e3).toFixed(1).replace(/\.0$/, "") + "K";
    return String(n);
  },

  id() {
    return (crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2) + Date.now());
  },

  /* linkify + emote splice already handled upstream; this only escapes runs of text */
  el(tag, cls, html) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html !== undefined) n.innerHTML = html;
    return n;
  },

  sleep: ms => new Promise(r => setTimeout(r, ms))
};
