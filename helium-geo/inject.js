// MAIN world, document_start. Replaces the Geolocation API before page scripts can grab it.
(() => {
  'use strict';

  const EVT_CFG = '__helium_geo_cfg__';
  const EVT_REQ = '__helium_geo_req__';

  let cfg = null;          // null / {enabled:false} => pass through to the real API
  let ready = false;
  const pending = [];

  // ---- capture originals before anything else touches them --------------------
  const G = navigator.geolocation;
  const origGet   = G ? G.getCurrentPosition.bind(G) : null;
  const origWatch = G ? G.watchPosition.bind(G)      : null;
  const origClear = G ? G.clearWatch.bind(G)         : null;
  const RealDTF   = Intl.DateTimeFormat;
  const realOffset = Date.prototype.getTimezoneOffset;

  const on = () => !!(cfg && cfg.enabled);

  // ---- config plumbing --------------------------------------------------------
  function run(fn) {
    if (ready) fn();
    else pending.push(fn);
  }

  function applyConfig(next) {
    cfg = next;
    ready = true;
    if (on() && cfg.spoofTimezone && cfg.tz) patchTimezone(cfg.tz);
    while (pending.length) {
      try { pending.shift()(); } catch (e) { /* keep draining */ }
    }
  }

  document.addEventListener(EVT_CFG, e => {
    let parsed = null;
    try { parsed = JSON.parse(e.detail); } catch (_) {}
    applyConfig(parsed);
  });
  document.dispatchEvent(new CustomEvent(EVT_REQ));
  // Fail open: if the bridge never answers (extension reloaded/disabled), use the real API.
  setTimeout(() => { if (!ready) applyConfig(null); }, 2000);

  // ---- fake position ----------------------------------------------------------
  const M_PER_DEG = 111320;

  function jitterDeg(meters, lat, isLng) {
    if (!meters) return 0;
    const perDeg = isLng ? (M_PER_DEG * Math.cos(lat * Math.PI / 180)) || 1 : M_PER_DEG;
    return ((Math.random() - 0.5) * 2 * meters) / perDeg;
  }

  function makePosition() {
    const lat = cfg.lat + jitterDeg(cfg.jitter, cfg.lat, false);
    const lng = cfg.lng + jitterDeg(cfg.jitter, cfg.lat, true);
    const coords = {
      latitude: lat,
      longitude: lng,
      accuracy: cfg.accuracy ?? 25,
      altitude: null,
      altitudeAccuracy: null,
      heading: null,
      speed: null,
      toJSON() { return { latitude: lat, longitude: lng, accuracy: cfg.accuracy ?? 25,
                          altitude: null, altitudeAccuracy: null, heading: null, speed: null }; }
    };
    const ts = Date.now();
    return { coords, timestamp: ts, toJSON() { return { coords: coords.toJSON(), timestamp: ts }; } };
  }

  // ---- getCurrentPosition -----------------------------------------------------
  function getCurrentPosition(success, error, options) {
    run(() => {
      if (!on()) { if (origGet) origGet(success, error, options); return; }
      if (typeof success !== 'function') return;
      setTimeout(() => { try { success(makePosition()); } catch (e) { reportAsync(e); } }, 0);
    });
  }

  // ---- watchPosition ----------------------------------------------------------
  let nextId = 1000000;
  const watchers = new Map();

  function watchPosition(success, error, options) {
    const id = nextId++;
    const w = { cancelled: false, realId: null, timer: null };
    watchers.set(id, w);
    run(() => {
      if (w.cancelled) return;
      if (!on()) { w.realId = origWatch ? origWatch(success, error, options) : null; return; }
      const emit = () => {
        if (w.cancelled || typeof success !== 'function') return;
        try { success(makePosition()); } catch (e) { reportAsync(e); }
      };
      setTimeout(emit, 0);
      w.timer = setInterval(emit, Math.max(1000, cfg.watchIntervalMs || 5000));
    });
    return id;
  }

  function clearWatch(id) {
    const w = watchers.get(id);
    if (!w) { if (origClear) origClear(id); return; }
    w.cancelled = true;
    if (w.timer) clearInterval(w.timer);
    if (w.realId != null && origClear) origClear(w.realId);
    watchers.delete(id);
  }

  function reportAsync(e) { setTimeout(() => { throw e; }, 0); }

  // ---- install ----------------------------------------------------------------
  const nativeNames = new WeakMap();
  function define(obj, name, fn) {
    nativeNames.set(fn, name);
    Object.defineProperty(fn, 'name', { value: name, configurable: true });
    Object.defineProperty(obj, name, { value: fn, writable: true, enumerable: false, configurable: true });
  }

  if (typeof Geolocation !== 'undefined') {
    define(Geolocation.prototype, 'getCurrentPosition', getCurrentPosition);
    define(Geolocation.prototype, 'watchPosition', watchPosition);
    define(Geolocation.prototype, 'clearWatch', clearWatch);
  }

  // Make our functions read as [native code] under Function.prototype.toString.
  const realFnToString = Function.prototype.toString;
  Function.prototype.toString = new Proxy(realFnToString, {
    apply(target, thisArg, args) {
      const n = nativeNames.get(thisArg);
      if (n) return 'function ' + n + '() { [native code] }';
      return Reflect.apply(target, thisArg, args);
    }
  });
  nativeNames.set(Function.prototype.toString, 'toString');

  // Report the permission as already granted so sites skip the prompt.
  if (navigator.permissions && navigator.permissions.query) {
    const origQuery = navigator.permissions.query.bind(navigator.permissions);
    const q = function query(desc) {
      if (on() && desc && desc.name === 'geolocation') {
        return Promise.resolve({
          name: 'geolocation', state: 'granted', status: 'granted', onchange: null,
          addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; }
        });
      }
      return origQuery(desc);
    };
    define(navigator.permissions, 'query', q);
  }

  // ---- timezone (best effort, opt-in) -----------------------------------------
  let tzPatched = false;
  function patchTimezone(tz) {
    if (tzPatched) return;
    try { new RealDTF('en-US', { timeZone: tz }); } catch (_) { return; } // invalid tz -> skip
    tzPatched = true;

    const offsetMinutes = date => {
      const parts = new RealDTF('en-US', {
        timeZone: tz, hour12: false,
        year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', second: '2-digit'
      }).formatToParts(date).reduce((a, p) => (a[p.type] = p.value, a), {});
      const asUTC = Date.UTC(+parts.year, +parts.month - 1, +parts.day,
                             (+parts.hour) % 24, +parts.minute, +parts.second);
      const local = date.getTime() - date.getMilliseconds();
      return -Math.round((asUTC - local) / 60000);
    };

    define(Date.prototype, 'getTimezoneOffset', function getTimezoneOffset() {
      try { return offsetMinutes(this); } catch (_) { return realOffset.call(this); }
    });

    const build = args => {
      const opts = Object.assign({}, args[1]);
      if (!opts.timeZone) opts.timeZone = tz;
      const inst = new RealDTF(args[0], opts);
      const resolved = inst.resolvedOptions.bind(inst);
      inst.resolvedOptions = () => Object.assign(resolved(), { timeZone: tz });
      return inst;
    };
    Intl.DateTimeFormat = new Proxy(RealDTF, {
      construct: (t, args) => build(args),
      apply: (t, thisArg, args) => build(args)
    });
  }
})();
