/* Twitch viewer count: a white eye and the number, inside a thick red border.
   Needs clientId + token in config.js (Helix has no anonymous viewer count).
   Without them it shows a dash rather than lying about the number. */
const Viewers = {
  count: null,

  boot() {
    this.el = document.getElementById("badge");

    /* everything tweakable from the URL, so one file can serve several looks:
       viewers.html?eyecolor=%23eb0400&numcolor=%23000000&stroke=1.6&num=44&eye=48 */
    const set = (k, v, unit) => {
      const q = U.qs.get(k);
      if (q) this.el.style.setProperty(v, unit && /^[\d.]+$/.test(q) ? q + unit : q);
    };
    set("num", "--num", "px");   set("eye", "--eye", "px");   set("gap", "--gap", "px");
    set("border", "--bw", "px"); set("radius", "--br", "px"); set("stroke", "--sw");
    set("eyecolor", "--ec");     set("numcolor", "--nc");
    set("bordercolor", "--bc");  set("fill", "--bgfill");

    this.render();

    if (U.qs.get("demo") === "1") {
      this.count = 1243;
      this.render();
      setInterval(() => {
        this.count = Math.max(0, this.count + Math.round((Math.random() - 0.45) * 14));
        this.render();
      }, 2500);
      return;
    }

    Bus.init();
    const ch = U.cfg("twitch", "channel", "channel");
    TwitchAPI.init(ch, U.cfg("twitch", "clientId", "clientid"), U.cfg("twitch", "token", "token"),
                   { eventsub: false })
      .then(ok => {
        if (!ok) return;
        this.poll();
        setInterval(() => this.poll(), Number(U.qs.get("every") || 20000));
      });
  },

  async poll() {
    const s = await TwitchAPI.stats();
    if (!s) return;
    this.count = s.live ? s.viewers : null;
    this.render();
  },

  render() {
    const live = this.count !== null && this.count !== undefined;
    this.el.classList.toggle("off", !live);
    this.el.innerHTML =
      `<svg class="eye" viewBox="0 0 24 24" fill="none" stroke="currentColor"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
         <path d="M1.6 12S5.3 5 12 5s10.4 7 10.4 7-3.7 7-10.4 7S1.6 12 1.6 12z"/>
         <circle cx="12" cy="12" r="3.2"/>
       </svg>` +
      `<span class="n">${live ? U.num(this.count) : "--"}</span>`;
  }
};

document.addEventListener("DOMContentLoaded", () => Viewers.boot());
