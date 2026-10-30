import XCTest
import Foundation

/// Source-only oracle regression. This suite cannot establish visibility or a native clock.
final class PilotB6VisibleOracleTests: XCTestCase {
    private func binding(_ values: [String:Any] = [:]) throws -> PilotNameObserverTests.B6VisibleBinding {
        var data: [String:Any] = ["operationID":UUID().uuidString,"sampleID":"T20-G02-04","category":"update",
            "initialNonce":UUID().uuidString,"finalNonce":UUID().uuidString,
            "scopeHash":String(repeating:"a",count:64),"targetDeviceHash":String(repeating:"b",count:64),
            "targetArtifactHash":String(repeating:"c",count:64),"observerArtifactHash":String(repeating:"d",count:64),
            "targetRuntimeHash":String(repeating:"e",count:64),"fixtureProofHash":String(repeating:"f",count:64),
            "ordinaryPreflightHash":String(repeating:"a",count:64),"route":"database.products",
            "routeAnchor":"Database","rowIdentity":"CODEX_B6_123","baselineAnchor":"CODEX_B6_123",
            "beforeFields":["Before"],"afterFields":["After"],"absentAfterFields":["Before"],"priceSheet":false]
        data.merge(values) { _,new in new }
        return try JSONDecoder().decode(PilotNameObserverTests.B6VisibleBinding.self,
            from:JSONSerialization.data(withJSONObject:data))
    }
    func testChangedVisibleFieldsAndDistinctNoncesRequired() throws {
        XCTAssertTrue(PilotNameObserverTests.b6Validate(try binding()))
        XCTAssertFalse(PilotNameObserverTests.b6Validate(try binding(["afterFields":["Before"]])))
        let nonce=UUID().uuidString
        XCTAssertFalse(PilotNameObserverTests.b6Validate(try binding(["initialNonce":nonce,"finalNonce":nonce])))
    }
    func testDeleteNeedsExactVisibleQueryAndEmptyLabel() throws {
        XCTAssertFalse(PilotNameObserverTests.b6Validate(try binding(["category":"delete","route":"database.products.exact-query"])))
        XCTAssertTrue(PilotNameObserverTests.b6Validate(try binding(["category":"delete","route":"database.products.exact-query",
            "expectedSearchValue":"CODEX_B6_123","emptyResultLabel":"No matching products"])))
    }
    func testPriceRequiresItsRealSheetRoute() throws {
        XCTAssertFalse(PilotNameObserverTests.b6Validate(try binding(["category":"price"])))
        XCTAssertTrue(PilotNameObserverTests.b6Validate(try binding(["category":"price","route":"database.product-prices.10000000-0000-4000-8000-000000000003.purchase","priceSheet":true])))
    }
    func testMissingVisibleAfterFieldCannotCount() throws {
        XCTAssertFalse(PilotNameObserverTests.b6Validate(try binding(["afterFields":[]])))
    }
    func testPriceOrIdentitySubstringCannotMatchDifferentValue() {
        XCTAssertFalse(PilotNameObserverTests.b6Contains("112,50 USD","12,50"))
        XCTAssertFalse(PilotNameObserverTests.b6Contains("CODEX_B6_1234","CODEX_B6_123"))
        XCTAssertTrue(PilotNameObserverTests.b6Contains("Price: 12,50 USD","12,50"))
        XCTAssertTrue(PilotNameObserverTests.b6Contains("Name, CODEX_B6_123, quantity 2","CODEX_B6_123"))
    }
    func testHistoryRequiresItsVisibleRoute() throws {
        XCTAssertFalse(PilotNameObserverTests.b6Validate(try binding(["category":"history"])))
        XCTAssertTrue(PilotNameObserverTests.b6Validate(try binding(["category":"history","route":"history.sessions"])))
    }
}
