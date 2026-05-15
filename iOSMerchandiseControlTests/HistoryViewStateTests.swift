import XCTest

final class HistoryViewStateTests: XCTestCase {
    func testHistoryViewDefaultsToAllSessionsWithoutDatePredicate() throws {
        let source = try historyViewSource()

        XCTAssertTrue(source.contains("@Query(\n        sort: \\HistoryEntry.timestamp,\n        order: .reverse\n    )"))
        XCTAssertTrue(source.contains("@State private var selectedDateFilter: DateFilter = .all"))
        XCTAssertFalse(source.contains("@Query(filter:"))
    }

    private func historyViewSource() throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repositoryURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryURL
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent("HistoryView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
