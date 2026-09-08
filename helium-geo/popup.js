const CITIES = [
  ['San Francisco, US',  37.7749, -122.4194, 'America/Los_Angeles'],
  ['New York, US',       40.7128,  -74.0060, 'America/New_York'],
  ['London, UK',         51.5074,   -0.1278, 'Europe/London'],
];

const DEFAULT = {
  enabled: false, label: 'San Francisco, US',
  lat: 37.7749, lng: -122.4194, tz: 'America/Los_Angeles',
  accuracy: 25, jitter: 0, spoofTimezone: false, watchIntervalMs: 5000,
};

const $ = id => document.getElementById(id);
const preset = $('preset');

preset.append(new Option('Custom…', 'custom'));
CITIES.forEach(([name], i) => preset.append(new Option(name, String(i))));

let cfg = { ...DEFAULT };

function render() {
  $('lat').value = cfg.lat;
  $('lng').value = cfg.lng;
  $('accuracy').value = cfg.accuracy;
  $('jitter').value = cfg.jitter;
  $('tz').value = cfg.tz || '';
  $('spoofTimezone').checked = !!cfg.spoofTimezone;
  $('tz').disabled = !cfg.spoofTimezone;
  const i = CITIES.findIndex(c => c[0] === cfg.label);
  preset.value = i >= 0 ? String(i) : 'custom';
  $('dot').classList.toggle('on', cfg.enabled);
  $('toggle').textContent = cfg.enabled ? 'Disable' : 'Enable';
  $('toggle').classList.toggle('off', cfg.enabled);
}

function readForm() {
  cfg.lat = parseFloat($('lat').value) || 0;
  cfg.lng = parseFloat($('lng').value) || 0;
  cfg.accuracy = Math.max(1, parseInt($('accuracy').value, 10) || 25);
  cfg.jitter = Math.max(0, parseInt($('jitter').value, 10) || 0);
  cfg.spoofTimezone = $('spoofTimezone').checked;
  cfg.tz = $('tz').value.trim();
  if (preset.value === 'custom') cfg.label = `${cfg.lat.toFixed(4)}, ${cfg.lng.toFixed(4)}`;
}

async function save() {
  readForm();
  await chrome.storage.local.set({ cfg });
  $('saved').classList.add('show');
  setTimeout(() => $('saved').classList.remove('show'), 1400);
}

preset.addEventListener('change', () => {
  if (preset.value === 'custom') return;
  const [label, lat, lng, tz] = CITIES[+preset.value];
  Object.assign(cfg, { label, lat, lng, tz });
  render();
  save();
});

$('spoofTimezone').addEventListener('change', () => { $('tz').disabled = !$('spoofTimezone').checked; save(); });
['lat', 'lng', 'accuracy', 'jitter', 'tz'].forEach(id => $(id).addEventListener('change', save));

$('toggle').addEventListener('click', async () => {
  readForm();
  cfg.enabled = !cfg.enabled;
  render();
  await save();
});

chrome.storage.local.get('cfg').then(r => {
  cfg = { ...DEFAULT, ...(r.cfg || {}) };
  render();
});
