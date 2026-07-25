import Foundation
import Supabase
import XCTest
@testable import iOSMerchandiseControl

final class SupabaseAuthSignOutScopeTests: XCTestCase {
    func testUserFacingMobileSignOutIsLocalToCurrentDevice() throws {
        XCTAssertEqual(SupabaseAuthService.mobileSignOutScope.rawValue, SignOutScope.local.rawValue)

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("iOSMerchandiseControl/SupabaseAuthService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("auth.signOut(scope: Self.mobileSignOutScope)"))
        XCTAssertFalse(source.contains("provider.client.auth.signOut()"))
        XCTAssertFalse(source.contains("mobileSignOutScope: SignOutScope = .global"))
    }
}
