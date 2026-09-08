import fs from 'fs';
// --- minimal DOM/browser stub -------------------------------------------------
const listeners = {};
globalThis.document = {
  addEventListener: (t, f) => (listeners[t] ??= []).push(f),
  dispatchEvent: e => { (listeners[e.type] || []).forEach(f => f(e)); return true; },
};
globalThis.CustomEvent = class { constructor(type, init = {}) { this.type = type; this.detail = init.detail; } };

let realCalled = 0;
class Geolocation {
  getCurrentPosition(s) { realCalled++; s({ coords: { latitude: 1, longitude: 2, accuracy: 999 }, timestamp: 0 }); }
  watchPosition(s) { realCalled++; return 7; }
  clearWatch() {}
}
globalThis.Geolocation = Geolocation;
Object.defineProperty(globalThis, 'navigator', { configurable: true, writable: true, value: { geolocation: new Geolocation(), permissions: { query: async d => ({ name: d.name, state: 'prompt' }) } } });

// --- load the real inject.js --------------------------------------------------
new Function(fs.readFileSync(new URL('file:///Users/christianaguilar/.config/helium-geo/inject.js')).toString())();

const results = [];
const check = (name, cond) => results.push([name, cond]);

// 1. call BEFORE config arrives -> must be queued, not lost, not sent to real API
let early = null;
navigator.geolocation.getCurrentPosition(p => (early = p));
check('early call not yet resolved', early === null);
check('early call did not hit real API', realCalled === 0);

// 2. config arrives
const cfg = { enabled: true, label: 'New York, US', lat: 40.7128, lng: -74.0060,
              tz: 'America/New_York', accuracy: 25, jitter: 0, spoofTimezone: true, watchIntervalMs: 5000 };
document.dispatchEvent(new CustomEvent('__helium_geo_cfg__', { detail: JSON.stringify(cfg) }));

setTimeout(() => {
  check('queued call resolved after config', early !== null);
  check('queued call got NYC lat', Math.abs(early.coords.latitude - 40.7128) < 1e-9);
  check('queued call got NYC lng', Math.abs(early.coords.longitude + 74.0060) < 1e-9);
  check('accuracy honored', early.coords.accuracy === 25);
  check('real API never invoked while enabled', realCalled === 0);
  check('toString looks native',
        navigator.geolocation.getCurrentPosition.toString() === 'function getCurrentPosition() { [native code] }');
  check('timezone patched to EDT (240)', new Date('2026-09-08T22:00:00Z').getTimezoneOffset() === 240);
  check('Intl reports NYC', Intl.DateTimeFormat().resolvedOptions().timeZone === 'America/New_York');

  // 3. watchPosition returns an id synchronously and fires
  let fixes = 0;
  const id = navigator.geolocation.watchPosition(() => fixes++);
  check('watchPosition returned sync id', typeof id === 'number');

  setTimeout(() => {
    check('watch delivered a fix', fixes >= 1);
    navigator.geolocation.clearWatch(id);
    const before = fixes;

    // 4. disable -> falls through to the real API
    document.dispatchEvent(new CustomEvent('__helium_geo_cfg__', { detail: JSON.stringify(null) }));
    navigator.geolocation.getCurrentPosition(() => {});
    setTimeout(() => {
      check('clearWatch stopped the watch', fixes === before);
      check('disabled -> real API used', realCalled === 1);
      const bad = results.filter(([, ok]) => !ok);
      results.forEach(([n, ok]) => console.log((ok ? '  PASS  ' : '  FAIL  ') + n));
      console.log(`\n${results.length - bad.length}/${results.length} passed`);
      process.exit(bad.length ? 1 : 0);
    }, 30);
  }, 40);
}, 30);
