// ISOLATED world. Only job: ferry config from chrome.storage into the page's MAIN world.
const EVT_CFG = '__helium_geo_cfg__';
const EVT_REQ = '__helium_geo_req__';

function send(cfg) {
  try {
    document.dispatchEvent(new CustomEvent(EVT_CFG, { detail: JSON.stringify(cfg ?? null) }));
  } catch (_) { /* page went away */ }
}

function push() {
  try {
    chrome.storage.local.get('cfg').then(r => send(r.cfg ?? null)).catch(() => send(null));
  } catch (_) {
    send(null); // extension context invalidated (reload) -> fail open, real geolocation
  }
}

// inject.js asks for config as soon as it installs, in case it loaded after our first push.
document.addEventListener(EVT_REQ, push);
push();

try {
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === 'local' && changes.cfg) send(changes.cfg.newValue ?? null);
  });
} catch (_) {}
