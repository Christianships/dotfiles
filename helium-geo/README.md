# Helium Geo

Spoofs `navigator.geolocation` (and optionally timezone) in the Helium browser.

## Install

1. Open `helium://extensions`
2. Toggle **Developer mode** (top right)
3. **Load unpacked** → select `~/.config/helium-geo`
4. Pin the extension, click it, pick a city, hit **Enable**
5. Reload any open tabs (the hook installs at document_start)

## How it works

- `inject.js` runs in the page's MAIN world at `document_start` and replaces
  `Geolocation.prototype.getCurrentPosition` / `watchPosition` / `clearWatch`
  before page scripts can capture references to the originals.
- `bridge.js` runs in the ISOLATED world and ferries config from
  `chrome.storage.local` into the page via a `CustomEvent`. Calls made before
  the config arrives are queued, not dropped.
- `navigator.permissions.query({name:'geolocation'})` reports `granted`, so
  sites skip the permission prompt entirely.
- `Function.prototype.toString` is proxied so the replacements still print
  `[native code]`.
- Disabled, or if the bridge fails to answer within 2s, everything falls
  through to the real API.

## Options

| Option | Meaning |
| --- | --- |
| Accuracy | The `coords.accuracy` value reported, in metres |
| Jitter | Randomise each fix within ±N metres, so repeat reads aren't pixel-identical |
| Spoof timezone | Also patch `Date.prototype.getTimezoneOffset` and `Intl.DateTimeFormat` |

## Limits (read these)

- **IP geolocation is not touched.** Most big sites (streaming, storefronts,
  search) locate you by IP, not this API. For those you need a VPN or proxy —
  this extension changes nothing there.
- **Timezone spoofing is partial.** `Date.prototype.toString`, `toLocaleString`
  and WebGL/font/locale signals still reflect the real machine. Good enough to
  keep a site's JS consistent with the fake city, not good enough to beat a
  dedicated fingerprinting service.
- The returned position is a plain object, not a real `GeolocationPosition`
  instance, so `pos instanceof GeolocationPosition` is `false`. Nearly nothing
  checks this.

## Cities

San Francisco, New York, London — plus **Custom…** for any lat/long.
To add more, append to the `CITIES` array at the top of `popup.js`:
`['Tokyo, JP', 35.6762, 139.6503, 'Asia/Tokyo']`

## Test

Headless logic test (queueing, overrides, watch/clear, timezone, fall-through):

```
node test.mjs
```

In-browser: open `test.html` from this folder in Helium (`file://` — allow file
access for the extension in `helium://extensions` if needed), or use any map site.
