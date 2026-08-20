// Lists every online display as JSON, with the CoreGraphics UUID that OBS's
// screen_capture source uses in its display_uuid setting.
//
// OBS does not expose the display list over obs-websocket (the property is
// not enumerable via GetInputPropertiesListPropertyItems), so this supplies
// it instead.

import AppKit
import CoreGraphics

var count: UInt32 = 0
CGGetOnlineDisplayList(0, nil, &count)
var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
CGGetOnlineDisplayList(count, &ids, &count)

// NSScreen carries the human-readable name; match it back by display ID.
var names: [CGDirectDisplayID: String] = [:]
for screen in NSScreen.screens {
    if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
        names[CGDirectDisplayID(n.uint32Value)] = screen.localizedName
    }
}

var out: [[String: Any]] = []
for id in ids.prefix(Int(count)) {
    guard let cf = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { continue }
    out.append([
        "uuid": CFUUIDCreateString(nil, cf) as String,
        "name": names[id] ?? "Display \(id)",
        "builtin": CGDisplayIsBuiltin(id) != 0,
        "main": CGDisplayIsMain(id) != 0,
        "active": CGDisplayIsActive(id) != 0,
        "width": CGDisplayPixelsWide(id),
        "height": CGDisplayPixelsHigh(id),
    ])
}

let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
