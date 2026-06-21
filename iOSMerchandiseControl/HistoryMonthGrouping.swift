import Foundation

struct HistorySectionKey: Hashable, Comparable {
    let year: Int?
    let month: Int?

    static let noDate = HistorySectionKey(year: nil, month: nil)

    init(date: Date?, calendar: Calendar = .current) {
        guard let date,
              date.timeIntervalSinceReferenceDate.isFinite else {
            self = .noDate
            return
        }
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year,
              let month = components.month else {
            self = .noDate
            return
        }
        self.year = year
        self.month = month
    }

    init(year: Int?, month: Int?) {
        self.year = year
        self.month = month
    }

    var isNoDate: Bool {
        year == nil || month == nil
    }

    private var sortValue: Int {
        guard let year, let month else { return Int.min }
        return year * 12 + month
    }

    static func < (lhs: HistorySectionKey, rhs: HistorySectionKey) -> Bool {
        lhs.sortValue < rhs.sortValue
    }

    func title(
        locale: Locale,
        calendar: Calendar = .current,
        noDateTitle: String
    ) -> String {
        guard let year, let month else {
            return noDateTitle
        }
        var localizedCalendar = calendar
        localizedCalendar.locale = locale
        let components = DateComponents(calendar: localizedCalendar, year: year, month: month, day: 1)
        guard let date = components.date else {
            return noDateTitle
        }

        let formatter = DateFormatter()
        formatter.calendar = localizedCalendar
        formatter.locale = locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

struct HistoryMonthSection<Item>: Identifiable {
    let key: HistorySectionKey
    let title: String
    let entries: [Item]

    var id: HistorySectionKey { key }
}

enum HistoryMonthGrouping {
    static func groupedEntries<Item>(
        _ entries: [Item],
        locale: Locale,
        calendar: Calendar = .current,
        noDateTitle: String,
        timestamp: (Item) -> Date?,
        updatedAt: (Item) -> Date?,
        stableID: (Item) -> String
    ) -> [HistoryMonthSection<Item>] {
        let sortedEntries = entries.sorted { lhs, rhs in
            let lhsTimestamp = timestamp(lhs)
            let rhsTimestamp = timestamp(rhs)
            if let ordered = descending(lhsTimestamp, rhsTimestamp) {
                return ordered
            }
            if let ordered = descending(updatedAt(lhs), updatedAt(rhs)) {
                return ordered
            }
            return stableID(lhs) < stableID(rhs)
        }

        let grouped = Dictionary(grouping: sortedEntries) { entry in
            HistorySectionKey(date: timestamp(entry), calendar: calendar)
        }

        return grouped.keys
            .sorted(by: >)
            .compactMap { key in
                guard let entries = grouped[key],
                      !entries.isEmpty else {
                    return nil
                }
                return HistoryMonthSection(
                    key: key,
                    title: key.title(locale: locale, calendar: calendar, noDateTitle: noDateTitle),
                    entries: entries
                )
            }
    }

    private static func descending(_ lhs: Date?, _ rhs: Date?) -> Bool? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            guard lhs != rhs else { return nil }
            return lhs > rhs
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return nil
        }
    }
}
