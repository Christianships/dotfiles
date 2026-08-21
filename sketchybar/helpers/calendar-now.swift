// Current calendar event, for the SketchyBar `calendar` item.
//
// EventKit is the only supported way to read the user's calendars on modern
// macOS: ~/Library/Calendars is TCC-protected and, on a machine where
// Calendar.app has never run, does not exist at all.
//
// Because this is a bare command-line tool rather than an .app bundle, the
// NSCalendarsUsageDescription string has to be linked into the binary as a
// __TEXT,__info_plist section or the TCC prompt is skipped and the process is
// killed outright. See the build recipe in the header of plugins/calendar.sh.
//
// Subcommands
//   now                      JSON for the event happening right now
//   add <minutes> <title>    create an event starting now, for testing
//
// `now` never fails loudly: every error path still prints a JSON object with
// a `state`, so the bar can render "grant access" instead of silently
// vanishing.

import EventKit
import Foundation

let store = EKEventStore()

// EventKit's access request is async and this process has no run loop, so
// block on a semaphore. Already-granted access resolves immediately.
func requestAccess() -> Bool {
    var granted = false
    let sem = DispatchSemaphore(value: 0)
    store.requestFullAccessToEvents { ok, _ in
        granted = ok
        sem.signal()
    }
    // A denied-and-remembered decision returns fast; a first-run prompt can
    // sit for as long as the user takes to answer it.
    _ = sem.wait(timeout: .now() + 30)
    return granted
}

func emit(_ object: [String: Any]) -> Never {
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
        ?? Data(#"{"state":"error"}"#.utf8)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

// A calendar we are allowed to write to. On a fresh machine there may be no
// default calendar at all, in which case one is created in the local ("On My
// Mac") source.
func writableCalendar() throws -> EKCalendar {
    if let cal = store.defaultCalendarForNewEvents, cal.allowsContentModifications {
        return cal
    }
    if let cal = store.calendars(for: .event).first(where: { $0.allowsContentModifications }) {
        return cal
    }
    guard let local = store.sources.first(where: { $0.sourceType == .local })
        ?? store.sources.first(where: { $0.sourceType == .subscribed }) else {
        throw NSError(domain: "calendar-now", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "no local calendar source to create a calendar in",
        ])
    }
    let cal = EKCalendar(for: .event, eventStore: store)
    cal.title = "SketchyBar"
    cal.source = local
    try store.saveCalendar(cal, commit: true)
    return cal
}

// ── now ───────────────────────────────────────────────────────────
// Returns the event in progress, or else the next one starting soon, so the
// item has something to say in the minutes before a meeting rather than
// popping into existence exactly on the hour.
func now() -> Never {
    guard requestAccess() else { emit(["state": "denied"]) }

    let calendars = store.calendars(for: .event)
    guard !calendars.isEmpty else { emit(["state": "none"]) }

    let clock = Date()
    let predicate = store.predicateForEvents(
        withStart: clock.addingTimeInterval(-12 * 3600),
        end: clock.addingTimeInterval(12 * 3600),
        calendars: calendars
    )

    // All-day events are dropped: they are true for the whole day, so they
    // would pin the item open permanently and drown out the thing that is
    // actually happening now. Declined invitations are dropped for the same
    // reason -- they are not on your plate.
    let events = store.events(matching: predicate).filter { event in
        guard !event.isAllDay, event.startDate != nil, event.endDate != nil else { return false }
        if event.status == .canceled { return false }
        let mine = event.attendees?.first(where: { $0.isCurrentUser })
        return mine?.participantStatus != .declined
    }

    func payload(_ event: EKEvent, state: String) -> [String: Any] {
        [
            "state": state,
            "title": event.title ?? "Busy",
            "start": event.startDate.timeIntervalSince1970,
            "end": event.endDate.timeIntervalSince1970,
        ]
    }

    // Shortest running event wins: a 15-minute stand-up nested inside a
    // 3-hour focus block is the one you need to see.
    let current = events
        .filter { $0.startDate <= clock && $0.endDate > clock }
        .min { $0.endDate.timeIntervalSince($0.startDate) < $1.endDate.timeIntervalSince($1.startDate) }
    if let current { emit(payload(current, state: "current")) }

    let upcoming = events
        .filter { $0.startDate > clock && $0.startDate < clock.addingTimeInterval(30 * 60) }
        .min { $0.startDate < $1.startDate }
    if let upcoming { emit(payload(upcoming, state: "upcoming")) }

    emit(["state": "none"])
}

// ── add ───────────────────────────────────────────────────────────
func add(minutes: Double, title: String) -> Never {
    guard requestAccess() else { fail("calendar access denied") }
    do {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(minutes * 60)
        event.calendar = try writableCalendar()
        try store.save(event, span: .thisEvent, commit: true)
        print("added \"\(title)\" for \(Int(minutes))m in \(event.calendar.title)")
        exit(0)
    } catch {
        fail("could not add event: \(error.localizedDescription)")
    }
}

// ── dispatch ──────────────────────────────────────────────────────
let args = Array(CommandLine.arguments.dropFirst())
switch args.first ?? "now" {
case "now":
    now()
case "add":
    guard args.count >= 2, let minutes = Double(args[1]), minutes > 0 else {
        fail("usage: calendar-now add <minutes> [title]")
    }
    let title = args.count >= 3 ? args[2...].joined(separator: " ") : "Mock event"
    add(minutes: minutes, title: title)
default:
    fail("usage: calendar-now [now | add <minutes> [title]]")
}
