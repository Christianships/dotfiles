// Prints "<x> <y> <width> <height>" (points) for a CoreGraphics window id.
//
// AeroSpace's %{window-id} is the CGWindowID, so the two line up directly.
// kCGWindowBounds is readable without Screen Recording or Accessibility
// permission -- only kCGWindowName is gated -- so this stays prompt-free.
import CoreGraphics
import Foundation

guard CommandLine.arguments.count > 1,
      let target = UInt32(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: window-size <cg-window-id>\n".utf8))
    exit(2)
}

guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements],
                                            kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

for window in list {
    guard let number = window[kCGWindowNumber as String] as? UInt32, number == target,
          let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
          let x = bounds["X"], let y = bounds["Y"],
          let width = bounds["Width"], let height = bounds["Height"] else { continue }
    print("\(Int(x)) \(Int(y)) \(Int(width)) \(Int(height))")
    exit(0)
}

exit(1)
