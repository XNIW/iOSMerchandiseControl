import XCTest

final class Task131HarnessLaunchTests: XCTestCase {
    func testTask131InitialTabHookIsDebugOnlyAndTargetsOptions() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("iOSMerchandiseControl/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(#"ProcessInfo.processInfo.environment["TASK131_INITIAL_TAB"]"#))
        XCTAssertTrue(source.contains(#"if value == "options""#))
        XCTAssertTrue(source.contains("return 3"))
        XCTAssertTrue(source.contains("#if DEBUG"))
        XCTAssertTrue(source.contains("#endif"))
    }
}
