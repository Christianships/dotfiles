const paint = async () => {
  const { cfg } = await chrome.storage.local.get('cfg');
  const on = !!(cfg && cfg.enabled);
  await chrome.action.setBadgeText({ text: on ? 'ON' : '' });
  await chrome.action.setBadgeBackgroundColor({ color: '#d4380d' });
  await chrome.action.setTitle({
    title: on ? `Helium Geo — ${cfg.label || cfg.lat + ', ' + cfg.lng}` : 'Helium Geo — off'
  });
};

chrome.runtime.onInstalled.addListener(paint);
chrome.runtime.onStartup.addListener(paint);
chrome.storage.onChanged.addListener((c, area) => { if (area === 'local' && c.cfg) paint(); });
