# OBS overlays

Three browser sources that read Twitch and YouTube, sharing one event stream
and one look. Plain HTML/CSS/JS - no build, no server required in OBS, no
third-party overlay service.

| file | what it is | size that fits |
|---|---|---|
| `chat.html` | Twitch chat, rendered the way the site renders it | 400 x 640 |
| `alerts.html` | transparent alert: art, then the name highlighted + what they did | 560 x 300 |
| `viewers.html` | red outlined eye + Twitch viewer count, no container | 210 x 78 |
| `sim.html` | drive all of it live over a still of your camera | open in a browser |
| `token.html` | one-page Twitch token grabber (optional) | open in a browser |
| `install.mjs` | drops all three into an OBS scene over obs-websocket | `node install.mjs` |

## Simulate it

    ~/.config/obs/overlays/serve.sh

Then open <http://127.0.0.1:7799/sim.html>. It draws the real 1920x1080 canvas
at 2/3, with every source exactly where `layout.json` puts it in OBS, over a
still of your own camera. The buttons fire a real follow, sub, resub, gift sub,
gift bomb, raid, cheer, YouTube member or Super Chat, and roll chat traffic, so
you can watch the whole thing behave before you go live. `guides` outlines the
source boxes; `sim.html?demo=1` starts on its own.

The simulator needs the local server (its panels talk over `BroadcastChannel`,
which needs a real origin). **OBS does not** - point it at the files directly.

To refresh the backdrop after moving your camera, re-grab a still into
`img/backdrop.jpg`.

## Adding them in OBS

    node ~/.config/obs/overlays/install.mjs                 # into "01 CAMERA"
    node ~/.config/obs/overlays/install.mjs "02 SCREEN"     # any other scene
    node ~/.config/obs/overlays/install.mjs "01 CAMERA" --remove
    node ~/.config/obs/overlays/install.mjs --sync         # drag in OBS, then sync

Talks to OBS over obs-websocket while it stays open, reading the password from
OBS's own plugin config, so there is nothing to type in. Re-running it updates
the existing sources instead of duplicating them. Layout it applies on a
1920x1080 canvas:

Positions come from `layout.json`, which the simulator reads too, so the two
can never drift apart. Drag a source around in OBS and run `--sync` to write
where you put it back into the file; otherwise the next plain run snaps it home.



That keeps clear of the widget column on the right (`website`, `users`,
`revenue`, `countdown`). Drag them anywhere afterwards, OBS remembers.

### Or by hand

Sources -> **+** -> Browser, then:

- URL: `file:///Users/christianaguilar/.config/obs/overlays/chat.html?channel=YOUR_LOGIN`
- Width / Height: from the table above
- Leave **Shutdown source when not visible** off, so chat is already populated
  when you cut to the scene
- Custom CSS: leave the default alone, the pages are already transparent

Same for `alerts.html` and `viewers.html`. Set your channel once in
`config.js` instead and the `?channel=` part is not needed.

## Testing it in OBS

No channel, no token and no stream needed - these drive the real browser
sources, so what you see is exactly what viewers would get.

    node ~/.config/obs/overlays/install.mjs --demo      # steady chat + every alert on a reel
    node ~/.config/obs/overlays/install.mjs --fire=raid # one event, then back to normal
    node ~/.config/obs/overlays/install.mjs --fire=sub,giftbomb,follow
    node ~/.config/obs/overlays/install.mjs --live      # stop, back to the real feeds

`--demo` leaves it running until you stop it: chat fills at about one line a
second with subs, raids and cheers mixed in, alerts cycle through every event
type on a four second reel, and the viewer count drifts.

`--fire` plays the events you name once - in chat and as an alert at the same
time, the way they arrive for real - keeps chat rolling underneath, then puts
every source back. Event names: `follow` `sub` `resub` `subgift` `giftbomb`
`raid` `cheer`, and `member:youtube` `superchat:youtube`. Add a third part to
set the amount: `--fire=cheer:twitch:500` or `--fire=superchat:youtube:500`.

`sim.html` does the same thing in a browser if you would rather click buttons
than type, but only OBS shows you the real compositing over your camera.

## What needs credentials

Fill in `config.js`. Nothing here is required to get started.

| you want | you need |
|---|---|
| Twitch chat, emotes | nothing |
| Twitch subs, resubs, gift subs, gift bombs, raids, cheers, announcements | nothing - they arrive over IRC |
| 7TV / BTTV / FFZ emotes | nothing |
| Twitch **follows**, viewer count, follower count, sub count | `twitch.clientId` + `twitch.token` |
| the viewer count badge | `twitch.clientId` + `twitch.token` |
| YouTube subscriber count + concurrent viewers | `youtube.channelId` + `youtube.apiKey` |
| YouTube chat, new members, milestones, super chats | the above **+** `youtube.accessToken` |

EventSub (the follow feed) runs in **`alerts.html` only**. Twitch allows just
three live subscriptions per type, and three browser sources would sit exactly
on that cap and start failing after a reload. Add `?eventsub=1` to another
source if you want follows there instead.

Badge artwork comes from Helix - `badges.twitch.tv` no longer answers. Without
a token chat falls back to the icons in `img/badges/`, drawn to match Twitch's
badge shapes: red camera for the broadcaster, green sword for mods, purple star
for subs, pink gem for VIPs, blue crown for Prime, and so on. Replace any of
them by overwriting the file.

### Twitch token

Run `serve.sh`, open <http://127.0.0.1:7799/token.html> and follow the three
steps. It uses the implicit flow, so register a **Public** client at
<https://dev.twitch.tv/console/apps> - the existing `stream-title` app is
Confidential and Twitch rejects that flow for it. Scopes requested:
`moderator:read:followers`, `channel:read:subscriptions`, `bits:read`.
Tokens last around 60 days.

### YouTube key

<https://console.cloud.google.com/> -> your project -> APIs & Services ->
Credentials -> Create credentials -> **API key**, with YouTube Data API v3
enabled. `channelId` is the `UC...` id from
<https://www.youtube.com/account_advanced>.

Live chat is the one endpoint Google requires OAuth for. The `stream-title`
dock next door already runs that flow with the `youtube` scope - once it holds
tokens, copy the access token into `youtube.accessToken`. Counts work without it.

Quota note: finding the live video costs 100 units and runs every 10 minutes;
everything else costs 1. Well inside the free 10,000/day.

## Query params

Anything in `config.js` can be overridden per source, so one file can serve
several scenes.

    chat.html?channel=lirik&size=26&fade=90&plain=1&platform=0
    alerts.html?anchor=top-right&duration=5000&only=sub,giftbomb,raid
    viewers.html?layout=stack&subgoal=250

| param | applies to | does |
|---|---|---|
| `channel` | all | Twitch channel to read |
| `demo=1` | all | fake traffic, connects to nothing |
| `eventsub=1` | chat, viewers | also take the follow feed here |
| `size` | chat | base font px |
| `fade` | chat | seconds until a message fades out, `0` = never |
| `theme` | chat | `panel` solid Twitch column, `scrim` text scrim, `shadow` bare |
| `style` | alerts | `image` art + name, or `native` / `bar` / `type` boxed variants |
| `badges=0` `platform=0` `events=0` | chat | strip badges / the TW-YT tag / inline event cards |
| `max` | chat | messages kept on screen |
| `anchor` | alerts | `top` `bottom` `left` `right`, combine with `-` |
| `duration` | alerts | ms an alert stays up |
| `only` | alerts | comma list of event types to allow |
| `show` | alerts | play exactly these, in order: `show=sub,raid,member:youtube` |
| `hold` | alerts | seconds to keep each `show` alert up |
| `minbits` | alerts | ignore cheers under this |
| `eyecolor` `numcolor` | viewers | eye stroke colour, number colour |
| `stroke` | viewers | eye stroke weight on a 24 grid, default 1.8 |
| `num` `eye` `gap` | viewers | number size px, eye size px, space between |
| `border` `bordercolor` `radius` `fill` | viewers | container box, all off by default |
| `every` | viewers | ms between count refreshes, default 20000 |

## The look

Chat is Twitch's own rendering: Inter (bundled in `fonts/`, so it works with no
network), `#18181b` / `#efeff1` / `#adadb8` / `#9147ff`, one line per message,
badges at 1.3em, emotes at 2em, bold user-coloured name, and subs/gifts/raids
as the grey system sentence in a tinted row. No cards, no accent stripes.

Alerts have no container at all: the art from `img/<event>.svg`, then one line
with the username in the event colour and what they did after it. Drop your own
`img/sub.gif` in and point `config.alerts.art` at it to replace any of them:

    art: { sub: "img/my-sub.gif", raid: "img/raid.png" }

`?style=native|bar|type` swaps in the boxed variants if you ever want them.

## Sounds

On by default, master level `0.42`. Replace any file in `sounds/` and keep the
name; everything is loudness matched to -16 LUFS so no single one jumps out.
The synthesised originals for anything you have overwritten are in
`sounds/chime/`.

A number in the event beats the per-event sound - `config.alerts.numberSounds`
maps a number to a clip, so 500 bits, a $500 Super Chat, a 500 gift bomb and a
500 viewer raid all land on the same one. Add more numbers the same way.

`config.alerts.sounds` maps event to file, level and rate limit. Set a `file`
to `null` to silence that event. Three rules are built in because they are the
ones that turn alerts into noise:

- a **gift bomb** silences the individual gift subs that follow it for 15s,
  otherwise a 20-sub bomb plays 21 sounds
- **cheers** under `minBits` (100) stay quiet
- **follows** have an 8s cooldown, since follows are what gets botted

What has a sound, loudest to quietest: gift bomb and raid, sub, Super Chat,
resub, YouTube member, cheer, gift sub, follow. Chat messages, announcements
and first-time-chatter highlights make no sound at all, on purpose.

### Routing

The `alerts` source has **Control audio via OBS** on, so it appears in the
mixer as its own channel and the stream carries it. Its monitoring is set to
**Monitor and Output** so you hear it too. Ride the level from the mixer, not
from the config - alerts want to sit 6-10 dB under your voice.

### Where to get better ones

All of these are free and safe on a monetised VOD. Avoid music and meme clips:
they are the usual source of muted VODs and blocked clips.

| source | licence | good for |
|---|---|---|
| [Pixabay](https://pixabay.com/sound-effects/) | free, no attribution, commercial ok | the broadest single library |
| [Mixkit](https://mixkit.co/free-sound-effects/) | free, no attribution | clean UI and notification sets |
| [Kenney](https://kenney.nl/assets?q=audio) | CC0 | short game-UI blips, great for follows |
| [Freesound](https://freesound.org) | per file, check it | everything, but filter to CC0 |
| [OpenGameArt](https://opengameart.org/art-search?keys=sound) | mostly CC0 | fanfares and stingers |
| [Zapsplat](https://www.zapsplat.com) | free with credit, or paid | huge, well tagged |
| [Uppbeat](https://uppbeat.io/sfx) | free tier, paid clears music | if you also want stream-safe music |

Search terms that land on the right thing: `notification chime`, `ui confirm`,
`magic sparkle` (subs), `coin` `reward` (bits), `whoosh impact` `riser`
(raids), `fanfare short` (gift bombs), `soft pop` `blip` (follows).

Keep them **under 2 seconds** and normalise to about -16 LUFS so one alert is
not twice as loud as the next.

## How it fits together

    twitch-irc.js ─┐
    twitch-helix.js├─> bus.js ─> chat-app.js / alerts-app.js / viewers-app.js
    youtube.js    ─┘            (labels.js writes the wording for all three)

Every client normalises to one event shape, so anything one source can see the
others can too - that is why chat can show alert cards and the stats strip can
name your newest sub without a second connection.

Each browser source opens its own connection. That is deliberate: one source
crashing or being hidden never takes the others down with it.
