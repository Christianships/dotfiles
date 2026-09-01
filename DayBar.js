// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: deep-orange; icon-glyph: calendar;
//
// DayBar — one script, medium + large. Add it at either size.
//
// Black field that vanishes into a black home screen. A flat orange bar
// carries a dotted rail spanning the full day, 00:00 -> 24:00. Every
// calendar event is a thin solid mark on that rail at its true clock
// position; the one you're inside is white. A needle marks now.

const ORANGE   = new Color("#FE4A01")
const BLACK    = new Color("#000000")
const WHITE    = new Color("#FFFFFF")
const RAIL     = new Color("#000000", 0.42)
const HOUR_TXT = new Color("#000000", 0.45)
const DIM      = new Color("#585858")
const KICKER   = new Color("#3D3D3D")
const LIST_DIM = new Color("#6A6A6A")
const LIST_T   = new Color("#4A4A4A")

const now = new Date()

// ------------------------------------------------------------------ events
const dayStart = new Date(now); dayStart.setHours(0, 0, 0, 0)
const dayEnd   = new Date(dayStart.getTime() + 86400000)

let events = await CalendarEvent.between(dayStart, dayEnd, await Calendar.forEvents())
events = events
  .filter(e => !e.isAllDay && e.endDate > e.startDate)
  .sort((a, b) => a.startDate - b.startDate)

const active = events.find(e => e.startDate <= now && now < e.endDate) || null

// ---------------------------------------------------------------- geometry
// [medium, large] point sizes per screen size. Widgets are laid out in
// points, so the canvas must match exactly or iOS rescales and blurs it.
const SIZES = {
  "440x956": [[380, 170], [380, 382]],  // 16 Pro Max
  "430x932": [[364, 170], [364, 382]],  // 14/15 Pro Max
  "428x926": [[364, 170], [364, 382]],  // 12/13 Pro Max
  "414x896": [[360, 169], [360, 379]],  // 11 / XR / XS Max
  "414x736": [[348, 157], [348, 351]],  // Plus
  "402x874": [[348, 158], [348, 354]],  // 16 Pro
  "393x852": [[338, 158], [338, 354]],  // 14 Pro / 15 / 16
  "390x844": [[338, 158], [338, 354]],  // 12 / 13 / 14
  "375x812": [[329, 155], [329, 345]],  // X / XS / 13 mini
  "375x667": [[321, 148], [321, 324]],  // SE 2/3, 8
  "320x568": [[292, 141], [292, 311]],  // SE 1
}

const family = config.widgetFamily || "medium"
const isLarge = family === "large"

function canvasSize() {
  const s = Device.screenSize()
  const sw = Math.round(Math.min(s.width, s.height))
  const sh = Math.round(Math.max(s.width, s.height))
  const pair = SIZES[`${sw}x${sh}`]
  if (pair) {
    const [w, h] = isLarge ? pair[1] : pair[0]
    return new Size(w, h)
  }
  const w = Math.round(sw * 0.862)
  return new Size(w, isLarge ? Math.round(w * 1.047) : Math.round(sh * 0.185))
}

const SZ = canvasSize()
const W = SZ.width
const H = SZ.height
const s = W / 338                     // scale everything off the reference width

const ctx = new DrawContext()
ctx.size = new Size(W, H)
ctx.opaque = false
ctx.respectScreenScale = true

ctx.setFillColor(BLACK)
ctx.fillRect(new Rect(0, 0, W, H))

// -------------------------------------------------------------------- draw
if (isLarge) drawLarge()
else         drawMedium()

const widget = new ListWidget()
widget.setPadding(0, 0, 0, 0)
widget.backgroundColor = BLACK
widget.backgroundImage = ctx.getImage()
widget.refreshAfterDate = nextRefresh()

Script.setWidget(widget)
if (config.runsInApp) await (isLarge ? widget.presentLarge() : widget.presentMedium())
Script.complete()

// ----------------------------------------------------------------- layouts
function drawMedium() {
  const pad = 16 * s

  if (active) {
    // Countdown, right aligned. Task name gets whatever width is left.
    const cdSize = 18 * s
    const cd = countdown(active.endDate)
    const cdW = textWidth(cd, cdSize)
    text(cd, new Rect(W - pad - cdW, 16 * s, cdW, cdSize * 1.4), cdSize, ORANGE, "right", true)

    const taskSize = 25 * s
    const taskW = W - pad * 2 - cdW - 10 * s
    text(fit(active.title, taskSize, taskW), new Rect(pad, 9 * s, taskW, taskSize * 1.4),
         taskSize, WHITE, "left", true)

    const range = `${hhmm(active.startDate)} – ${hhmm(active.endDate)}`
    text(range, new Rect(pad + 1, 44 * s, W - pad * 2, 16 * s), 11 * s, DIM, "left", false, true)
  }

  const barH = 62 * s
  bar(8 * s, H - 8 * s - barH, W - 16 * s, barH, { railY: 27 * s })
}

function drawLarge() {
  const pad = 16 * s

  if (active) {
    text("CURRENT", new Rect(pad + 1, 18 * s, W, 14 * s), 9 * s, KICKER, "left", false, true)

    const taskSize = 30 * s
    text(fit(active.title, taskSize, W - pad * 2), new Rect(pad, 30 * s, W - pad * 2, taskSize * 1.4),
         taskSize, WHITE, "left", true)

    // Countdown, with "LEFT" set small and sitting to its right.
    const cdSize = 46 * s
    const cd = countdown(active.endDate)
    text(cd, new Rect(pad, 64 * s, W - pad * 2, cdSize * 1.4), cdSize, ORANGE, "left", true)
    text("LEFT", new Rect(pad + textWidth(cd, cdSize) + 6 * s, 96 * s, 60 * s, 16 * s),
         13 * s, DIM, "left", false, true)
  }

  bar(8 * s, 160 * s, W - 16 * s, 68 * s, { railY: 29 * s })

  // Today's blocks fill whatever is left under the bar.
  const listTop = 240 * s
  const rowTop  = listTop + 18 * s
  const rowH    = 21 * s
  const maxRows = Math.max(0, Math.floor((H - rowTop - 8 * s) / rowH))
  if (maxRows > 0 && events.length > 0) {
    text("TODAY", new Rect(pad + 1, listTop, W, 14 * s), 9 * s, KICKER, "left", false, true)

    // Window the list around the active block so it is always visible.
    let list = events
    if (events.length > maxRows) {
      const i = active ? events.indexOf(active) : events.findIndex(e => e.startDate > now)
      const anchor = i < 0 ? events.length - 1 : i
      const start = Math.min(Math.max(0, anchor - maxRows + 2), events.length - maxRows)
      list = events.slice(start, start + maxRows)
    }

    let y = rowTop
    for (const e of list) {
      const on = e === active
      text(hhmm(e.startDate), new Rect(pad + 1, y + 2 * s, 44 * s, 16 * s),
           11 * s, on ? ORANGE : LIST_T, "left", false, true)
      const nameX = pad + 54 * s
      const nameW = W - nameX - pad
      text(fit(e.title, 14 * s, nameW), new Rect(nameX, y, nameW, 18 * s),
           14 * s, on ? WHITE : LIST_DIM, "left", on)
      y += rowH
    }
  }
}

// --------------------------------------------------------------------- bar
// x,y,w,h = the orange plate. railY is measured from the plate's top.
function bar(x, y, w, h, opt) {
  fillRounded(new Rect(x, y, w, h), 14 * s, ORANGE)

  const inset  = 12 * s
  const left   = x + inset
  const width  = w - inset * 2
  const railY  = y + opt.railY
  const at     = frac => left + frac * width

  // Dotted rail across the whole day.
  const dot = 2.4 * s
  for (let dx = 0; dx <= width; dx += 5 * s) {
    ctx.setFillColor(RAIL)
    fillRounded(new Rect(left + dx, railY - dot / 2, dot, dot), dot / 2, RAIL)
  }

  // Event marks. Inactive first so the white one always sits on top.
  // Marks fill the plate's height rather than the plate growing to fit them.
  // Corner radius is fixed, so they read as rounded rectangles, not pills.
  const draw = (e, on) => {
    const x0 = at(dayFrac(e.startDate))
    const x1 = at(dayFrac(e.endDate))
    const th = h * (on ? 0.32 : 0.22)
    const mw = Math.max(8 * s, Math.min(x1, left + width) - x0)
    fillRounded(new Rect(x0, railY - th / 2, mw, th), 4 * s, on ? WHITE : BLACK)
  }
  for (const e of events) if (e !== active) draw(e, false)
  if (active) draw(active, true)

  // Now: needle plus a dot cap so it reads even over a white mark.
  const nx = at(dayFrac(now))
  const nh = h * 0.52
  fillRounded(new Rect(nx - 1.5 * s, railY - nh / 2, 3 * s, nh), 1.5 * s, BLACK)
  fillRounded(new Rect(nx - 4.5 * s, railY - nh / 2 - 7 * s, 9 * s, 9 * s), 4.5 * s, BLACK)

  // Hour ruler along the bottom of the plate.
  for (const hr of [0, 6, 12, 18, 24]) {
    const lw = 16 * s
    let rx = at(hr / 24) - lw / 2
    rx = Math.min(Math.max(rx, x + 4 * s), x + w - lw - 4 * s)
    text(String(hr).padStart(2, "0"), new Rect(rx, y + h - 16 * s, lw, 12 * s),
         9 * s, HOUR_TXT, "center", false, true)
  }
}

// ----------------------------------------------------------------- helpers
function dayFrac(d) {
  const f = (d.getTime() - dayStart.getTime()) / 86400000
  return Math.min(1, Math.max(0, f))
}

function hhmm(d) {
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`
}

function countdown(end) {
  const mins = Math.max(0, Math.ceil((end - now) / 60000))
  const h = Math.floor(mins / 60)
  const m = mins % 60
  return h > 0 ? `${h}h ${m}m` : `${m}m`
}

// DrawContext has no text measurement, so estimate from the glyph width
// ratios of SF (proportional) and the monospaced face.
function textWidth(str, size, mono) {
  return str.length * size * (mono ? 0.60 : 0.55)
}

function fit(str, size, maxW) {
  const max = Math.max(1, Math.floor(maxW / (size * 0.55)))
  return str.length > max ? str.slice(0, Math.max(1, max - 1)) + "…" : str
}

function text(str, rect, size, color, align, bold, mono) {
  ctx.setFont(mono
    ? (bold ? Font.boldMonospacedSystemFont(size) : Font.regularMonospacedSystemFont(size))
    : (bold ? Font.semiboldSystemFont(size) : Font.regularSystemFont(size)))
  ctx.setTextColor(color)
  if (align === "right")       ctx.setTextAlignedRight()
  else if (align === "center") ctx.setTextAlignedCenter()
  else                         ctx.setTextAlignedLeft()
  ctx.drawTextInRect(str, rect)
}

function fillRounded(rect, r, color) {
  const p = new Path()
  p.addRoundedRect(rect, r, r)
  ctx.addPath(p)
  ctx.setFillColor(color)
  ctx.fillPath()
}

// Tick on the minute, and exactly when a block starts or ends.
function nextRefresh() {
  const c = [new Date(Math.ceil((now.getTime() + 1) / 60000) * 60000)]
  if (active) c.push(active.endDate)
  const next = events.find(e => e.startDate > now)
  if (next) c.push(next.startDate)
  return new Date(Math.min(...c.map(d => d.getTime())))
}
