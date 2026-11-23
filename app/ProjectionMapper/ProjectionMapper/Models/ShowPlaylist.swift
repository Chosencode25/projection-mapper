import Foundation

struct ShowPlaylist: Codable, Identifiable, Equatable {
    struct Entry: Codable, Identifiable, Equatable {
        var id = UUID()
        var path: String
        var role: Role = .show
        var seconds = 0
        var url: URL { URL(fileURLWithPath: path) }

        enum Role: String, Codable, CaseIterable, Identifiable {
            case intro = "Intro", show = "Show", idle = "Intermission", outro = "Outro"
            var id: Self { self }
        }
    }
    var id = UUID()
    var name = "New Playlist"
    var entries: [Entry] = []
    var repeats = 1
    var shuffle = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 &&
        (1...100).contains(entries.count) && (1...20).contains(repeats) &&
        Set(entries.map(\.id)).count == entries.count &&
        entries.allSatisfy { $0.path.hasPrefix("/") && $0.url.pathExtension.lowercased() == "projectionmap" &&
            (0...3600).contains($0.seconds) }
    }

    func sequence() -> [Entry] {
        let intro = entries.filter { $0.role == .intro }
        let body = entries.filter { $0.role == .show || $0.role == .idle }
        let outro = entries.filter { $0.role == .outro }
        var ordered = intro
        var previous: String?
        for _ in 0..<repeats {
            var shows = body.filter { $0.role == .show }
            if shuffle {
                shows.shuffle()
                if shows.first?.path == previous, let index = shows.firstIndex(where: { $0.path != previous }) {
                    shows.swapAt(0, index)
                }
            }
            var iterator = shows.makeIterator()
            for entry in body { ordered.append(entry.role == .show ? (iterator.next() ?? entry) : entry) }
            previous = shows.last?.path
        }
        return ordered + outro
    }
}

struct ShowSchedule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "New Schedule"
    var playlistID: UUID
    var enabled = false
    var weekdays = Set(1...7)
    var timeZoneID = TimeZone.current.identifier
    var startMinute = 18 * 60
    var endMinute = 22 * 60
    var priority = 0
    var finishCurrent = true
    var firstDate = ""
    var lastDate = ""
    var excludedDates = ""

    struct Occurrence: Equatable {
        let id: String
        let starts: Date
        let ends: Date
    }

    private func dayKey(_ date: Date, calendar: Calendar) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 100,
              excludedDates.count <= 4096,
              let zone = TimeZone(identifier: timeZoneID), (0..<1440).contains(startMinute),
              (0..<1440).contains(endMinute), startMinute != endMinute,
              !weekdays.isEmpty, weekdays.isSubset(of: Set(1...7)), (-100...100).contains(priority) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        func validDate(_ text: String) -> Bool {
            let parts = text.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
                  let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
            return dayKey(date, calendar: calendar) == text
        }
        return (firstDate.isEmpty || validDate(firstDate)) && (lastDate.isEmpty || validDate(lastDate)) &&
            (firstDate.isEmpty || lastDate.isEmpty || firstDate <= lastDate) &&
            exceptions.allSatisfy(validDate)
    }

    private var exceptions: [String] {
        excludedDates.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
    }

    func occurrence(on date: Date) -> Occurrence? {
        guard enabled, isValid, let zone = TimeZone(identifier: timeZoneID) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.startOfDay(for: date)
        let key = dayKey(day, calendar: calendar)
        guard weekdays.contains(calendar.component(.weekday, from: day)),
              firstDate.isEmpty || key >= firstDate, lastDate.isEmpty || key <= lastDate,
              !exceptions.contains(key) else { return nil }
        func resolve(_ minute: Int, on day: Date) -> Date? {
            calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day,
                          matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .forward)
                .flatMap { calendar.isDate($0, inSameDayAs: day) ? $0 : nil }
        }
        guard let endDay = calendar.date(byAdding: .day, value: endMinute < startMinute ? 1 : 0, to: day),
              let start = resolve(startMinute, on: day), let end = resolve(endMinute, on: endDay), end > start else { return nil }
        return Occurrence(id: id.uuidString + ":" + key, starts: start, ends: end)
    }

    func occurrences(around now: Date, days: ClosedRange<Int>) -> [Occurrence] {
        guard let zone = TimeZone(identifier: timeZoneID) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let today = calendar.startOfDay(for: now)
        return days.compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).flatMap(occurrence(on:))
        }
    }

    func conflicts(with other: ShowSchedule, around now: Date) -> Bool {
        let windows = occurrences(around: now, days: -1...7)
        let peers = other.occurrences(around: now, days: -2...8)
        return windows.contains { a in peers.contains { b in a.starts < b.ends && b.starts < a.ends && a.ends > now && b.ends > now } }
    }

    static func due(_ rules: [Self], now: Date, armedAt: Date, seen: Set<String>) -> [(Self, Occurrence)] {
        guard now >= armedAt else { return [] }
        return rules.compactMap { rule -> (Self, Occurrence)? in
            guard let occurrence = rule.occurrences(around: now, days: -1...0).last(where: { $0.starts <= now }), occurrence.starts >= armedAt,
                  occurrence.starts <= now, now < occurrence.ends,
                  now.timeIntervalSince(occurrence.starts) <= 60, !seen.contains(occurrence.id) else { return nil }
            return (rule, occurrence)
        }.sorted { a, b in
            if a.0.priority != b.0.priority { return a.0.priority > b.0.priority }
            return a.0.id.uuidString < b.0.id.uuidString
        }
    }
}
