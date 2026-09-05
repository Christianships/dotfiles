// Centered, blurred, scrollable keybinding overlay for AeroSpace.
//
// Reads the JSON that cheatsheet.py parses out of aerospace.toml on stdin, so
// the panel always shows the bindings that are actually loaded. Borderless and
// .accessory, which keeps it out of the Dock and out of AeroSpace's tiling.
// Any key, or a click that takes focus elsewhere, dismisses it.
import AppKit
import Foundation

// MARK: - Input

struct Bind: Decodable {
    let chord: String
    let spoken: String
    let desc: String

    // Each bind arrives as ["⌃ B", "super + b", "Launch Helium"].
    init(from decoder: Decoder) throws {
        var row = try decoder.unkeyedContainer()
        chord = try row.decode(String.self)
        spoken = try row.decode(String.self)
        desc = try row.decode(String.self)
    }
}

struct Group: Decodable {
    let title: String
    let binds: [Bind]
}

struct Mode: Decodable {
    let mode: String
    let groups: [Group]
}

let modes: [Mode] = {
    let raw = FileHandle.standardInput.readDataToEndOfFile()
    return (try? JSONDecoder().decode([Mode].self, from: raw)) ?? []
}()

guard !modes.isEmpty else {
    FileHandle.standardError.write(Data("keys: no bindings on stdin\n".utf8))
    exit(1)
}

// MARK: - Style

// Graphite body text with a single soft-violet accent for headings -- no
// yellow, no blue. Keys render bright/bold since they're the lookup target;
// everything else steps down in brightness so the eye lands on them first.
let accent = NSColor(srgbRed: 0.78, green: 0.72, blue: 0.94, alpha: 1.0)
let keyColor = NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
let spokenColor = NSColor.white.withAlphaComponent(0.40)
let descColor = NSColor.white.withAlphaComponent(0.80)
let mutedColor = NSColor.white.withAlphaComponent(0.35)

let mono = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .medium)
let monoBold = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .bold)
let headFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
let modeFont = NSFont.systemFont(ofSize: 13, weight: .bold)

// A tab stop aligns every description into one column; headIndent keeps a
// wrapped description hanging under itself rather than under the chord.
let bindStyle: NSParagraphStyle = {
    let s = NSMutableParagraphStyle()
    s.tabStops = [
        NSTextTab(textAlignment: .left, location: 72, options: [:]),
        NSTextTab(textAlignment: .left, location: 280, options: [:]),
    ]
    s.headIndent = 280
    s.paragraphSpacing = 1
    return s
}()

let headStyle: NSParagraphStyle = {
    let s = NSMutableParagraphStyle()
    s.paragraphSpacingBefore = 14
    s.paragraphSpacing = 4
    return s
}()

func run(_ text: String, _ font: NSFont, _ color: NSColor, _ style: NSParagraphStyle) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: style,
    ])
}

// MARK: - Document

let doc = NSMutableAttributedString()
for mode in modes {
    if mode.mode != "main" {
        doc.append(run("\(mode.mode.uppercased()) MODE\n", modeFont, accent, headStyle))
    }
    for group in mode.groups {
        if !group.title.isEmpty {
            doc.append(run("\(group.title)\n", headFont, accent, headStyle))
        }
        for bind in group.binds {
            doc.append(run(bind.chord, monoBold, keyColor, bindStyle))
            doc.append(run("\t\(bind.spoken)", mono, spokenColor, bindStyle))
            doc.append(run("\t\(bind.desc)\n", mono, descColor, bindStyle))
        }
    }
}

// MARK: - Window

// Borderless windows refuse key status unless asked to accept it, and without
// key status there is no keyDown to dismiss on.
final class PanelWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) { NSApp.terminate(nil) }
    override func cancelOperation(_ sender: Any?) { NSApp.terminate(nil) }
}

final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: PanelWindow!

    func applicationDidFinishLaunching(_ note: Notification) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame
        let width: CGFloat = 780
        let height = min(720, frame.height - 120)

        window = PanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.delegate = self
        window.setFrameOrigin(NSPoint(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2))

        // .behindWindow is what actually samples the desktop; .hudWindow is the
        // heaviest of the dark materials.
        let blur = NSVisualEffectView(frame: window.contentView!.bounds)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 20
        blur.layer?.masksToBounds = true
        blur.layer?.borderWidth = 1
        blur.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        window.contentView = blur

        let title = NSTextField(labelWithString: "AeroSpace  ·  ⌃ is SUPER")
        title.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(title)

        let hint = NSTextField(labelWithString: "any key to close")
        hint.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hint.textColor = mutedColor
        hint.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(hint)

        let text = NSTextView()
        text.isEditable = false
        text.isSelectable = false
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 0, height: 4)
        text.textStorage?.setAttributedString(doc)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        scroll.documentView = text
        scroll.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(scroll)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: blur.leadingAnchor, constant: 28),
            title.topAnchor.constraint(equalTo: blur.topAnchor, constant: 22),
            hint.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -28),
            hint.firstBaselineAnchor.constraint(equalTo: title.firstBaselineAnchor),
            scroll.leadingAnchor.constraint(equalTo: blur.leadingAnchor, constant: 28),
            scroll.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            scroll.bottomAnchor.constraint(equalTo: blur.bottomAnchor, constant: -22),
        ])

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // Clicking through to anything else counts as dismissing the panel.
    func windowDidResignKey(_ note: Notification) { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
