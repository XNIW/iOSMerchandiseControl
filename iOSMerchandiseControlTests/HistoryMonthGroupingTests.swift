import XCTest
@testable import iOSMerchandiseControl

final class HistoryMonthGroupingTests: XCTestCase {
    func testGroupsByMonthNewestFirstAndSortsEntriesDescending() throws {
        let calendar = Calendar(identifier: .gregorian)
        let juneEarly = Fixture(
            id: "june-early",
            timestamp: try date(2026, 6, 2),
            updatedAt: try date(2026, 6, 3)
        )
        let juneLate = Fixture(
            id: "june-late",
            timestamp: try date(2026, 6, 20),
            updatedAt: try date(2026, 6, 21)
        )
        let may = Fixture(
            id: "may",
            timestamp: try date(2026, 5, 19),
            updatedAt: try date(2026, 5, 20)
        )
        let noDate = Fixture(id: "no-date", timestamp: nil, updatedAt: nil)

        let sections = HistoryMonthGrouping.groupedEntries(
            [may, juneEarly, noDate, juneLate],
            locale: Locale(identifier: "en_US"),
            calendar: calendar,
            noDateTitle: "No date",
            timestamp: \.timestamp,
            updatedAt: \.updatedAt,
            stableID: \.id
        )

        XCTAssertEqual(sections.map(\.title), ["June 2026", "May 2026", "No date"])
        XCTAssertEqual(sections[0].entries.map(\.id), ["june-late", "june-early"])
        XCTAssertTrue(sections.allSatisfy { !$0.entries.isEmpty })
    }

    func testMonthTitleUsesAppLocale() throws {
        let calendar = Calendar(identifier: .gregorian)
        let sections = HistoryMonthGrouping.groupedEntries(
            [Fixture(id: "june", timestamp: try date(2026, 6, 1), updatedAt: nil)],
            locale: Locale(identifier: "it_IT"),
            calendar: calendar,
            noDateTitle: "Senza data",
            timestamp: \.timestamp,
            updatedAt: \.updatedAt,
            stableID: \.id
        )

        XCTAssertEqual(sections.map(\.title), ["giugno 2026"])
    }

    private struct Fixture {
        let id: String
        let timestamp: Date?
        let updatedAt: Date?
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return try XCTUnwrap(
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        )
    }
}
