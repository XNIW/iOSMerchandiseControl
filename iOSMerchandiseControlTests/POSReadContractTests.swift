import Foundation
import XCTest
@testable import iOSMerchandiseControl

final class POSReadContractTests: XCTestCase {
    func testMoneyPreservesTwoTo53AdjacentValuesAndInt64Boundaries() throws {
        for raw in ["0", "-1", "9007199254740991", "9007199254740992", "9007199254740993", "9223372036854775807", "-9223372036854775808"] {
            let value = try POSAmount(raw)
            XCTAssertEqual(String(value.value), raw)
            XCTAssertEqual(try JSONDecoder().decode(String.self, from: JSONEncoder().encode(value)), raw)
        }
    }
    func testMoneyRejectsOverflowNoncanonicalAndNumericJSON() {
        for raw in ["9223372036854775808", "-9223372036854775809", "-0", "+1", "01", "1.0", "1e2", "NaN", " 1"] {
            XCTAssertThrowsError(try POSAmount(raw), raw)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(POSAmount.self, from: Data("9007199254740993".utf8)))
    }
    func testNativeCurrencyFormattingRetainsAllIntegerDigitsInFourLocales() throws {
        let amount = try POSAmount("9223372036854775807")
        for code in ["it_IT", "en_US", "es_CL", "zh_CN"] {
            XCTAssertEqual(amount.formatted(locale: Locale(identifier: code)).filter(\.isNumber), "9223372036854775807", code)
        }
    }
    func testFractionalQuantityRoundtripsWithoutIntegerOrDoubleConversion() throws {
        let q = try POSQuantity("-12.125")
        XCTAssertEqual(q.decimal, Decimal(string: "-12.125"))
        XCTAssertEqual(try JSONDecoder().decode(String.self, from: JSONEncoder().encode(q)), "-12.125")
        XCTAssertThrowsError(try POSQuantity("NaN")); XCTAssertThrowsError(try POSQuantity("1e3"))
    }
    func testMicrosecondCursorEncodingRetainsOriginalRawBytes() throws {
        let scope = try POSReadFixtures.scope()
        let cursor = POSCursor(beforeOccurredAt: try POSRawTimestamp("2026-09-06T16:00:00.123456+00:00"), beforeSaleId: POSReadFixtures.id(1))
        let request = try POSReadRequest(action: .page, period: POSReadFixtures.period(), cursor: cursor)
        let raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(POSRPCParameters(scope: scope, request: request))) as! [String: Any]
        XCTAssertEqual(raw["p_before_occurred_at"] as? String, "2026-09-06T16:00:00.123456+00:00")
        XCTAssertEqual(raw["p_before_sale_id"] as? String, cursor.beforeSaleId.uuidString)
    }
    func testMicrosecondAndUUIDTieOrderingAreExact() throws {
        let earlier = try POSRawTimestamp("2026-09-06T16:00:00.123456Z")
        let later = try POSRawTimestamp("2026-09-06T16:00:00.123457+00:00")
        XCTAssertTrue(earlier.precedes(later, id: POSReadFixtures.id(9), otherID: POSReadFixtures.id(1)))
        XCTAssertTrue(earlier.precedes(earlier, id: POSReadFixtures.id(1), otherID: POSReadFixtures.id(2)))
        XCTAssertFalse(earlier.precedes(earlier, id: POSReadFixtures.id(2), otherID: POSReadFixtures.id(1)))
    }
    func testBusinessDateDSTAndMidnightRemainServerDates() throws {
        let range = try POSPeriod(from: POSBusinessDate("2026-09-05"), to: POSBusinessDate("2026-09-07"))
        XCTAssertEqual(range.dayCount, 3)
        XCTAssertThrowsError(try POSBusinessDate("2026-02-30"))
        XCTAssertThrowsError(try POSRawTimestamp("2026-09-06T24:00:00.123456Z"))
        XCTAssertThrowsError(try POSPeriod(from: POSBusinessDate("2026-01-01"), to: POSBusinessDate("2027-01-02")))
    }
    func testAllFifteenRequestFieldsUseExactSQLParameterNames() throws {
        let filters = POSFilters(status: .conflict, businessKind: .refund, paymentMethod: "cash", staffID: POSReadFixtures.id(3), deviceID: POSReadFixtures.id(4), saleNumber: "sale")
        let request = try POSReadRequest(action: .page, period: POSReadFixtures.period(), filters: filters,
                                         cursor: POSCursor(beforeOccurredAt: POSReadFixtures.timestamp(), beforeSaleId: POSReadFixtures.id(1)), limit: 100)
        let value = try JSONSerialization.jsonObject(with: JSONEncoder().encode(POSRPCParameters(scope: POSReadFixtures.scope(), request: request))) as! [String: Any]
        XCTAssertEqual(Set(value.keys), Set(["p_shop_id", "p_device_identifier", "p_action", "p_from_date", "p_to_date", "p_limit", "p_before_occurred_at", "p_before_sale_id", "p_status", "p_business_kind", "p_payment_method", "p_staff_id", "p_device_id", "p_sale_number"]))
        let detail = try POSReadRequest(action: .detail, saleID: POSReadFixtures.id(1))
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(POSRPCParameters(scope: POSReadFixtures.scope(), request: detail))) as! [String: Any]
        XCTAssertNotNil(encoded["p_pos_sale_id"]); XCTAssertNil(encoded["p_from_date"])
    }
    func testInvalidActionMatricesAndOversizeInputsFailBeforeDispatch() throws {
        XCTAssertThrowsError(try POSReadRequest(action: .page))
        XCTAssertThrowsError(try POSReadRequest(action: .detail, period: POSReadFixtures.period(), saleID: POSReadFixtures.id(1)))
        XCTAssertThrowsError(try POSReadRequest(action: .filter, period: POSReadFixtures.period(), filters: POSFilters(status: .accepted)))
        XCTAssertThrowsError(try POSReadRequest(action: .summary, limit: 101))
        XCTAssertThrowsError(try POSReadScope(ownerID: UUID(), shopID: UUID(), deviceIdentifier: String(repeating: "x", count: 161), authGeneration: UUID(), authorizationEpoch: UUID()))
    }
    func testSummaryAndFirstPagePublishOneServerEnvelopeNotLast50Total() throws {
        let reply = try POSReadFixtures.reply(action: .summary, indices: [0], total: "9007199254740993")
        guard case let .summary(data) = reply.payload else { return XCTFail("summary") }
        XCTAssertEqual(data.summaryDays[0].netRevenueClp.value, 9_007_199_254_740_993)
        XCTAssertEqual(data.sales[0].netAmountClp.value, 100)
    }
    func testDeniedEnvelopeCannotCarryDataOrRenewAuthority() throws {
        let request = try POSReadRequest(action: .summary)
        var envelope = POSReadFixtures.envelope(action: .summary)
        envelope["ok"] = false; envelope["code"] = "permission_denied"; envelope["data"] = NSNull()
        XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: request, scope: POSReadFixtures.scope())) {
            XCTAssertEqual($0 as? POSReadError, .denied("permission_denied"))
        }
        envelope["data"] = ["sales": []]
        XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: request, scope: POSReadFixtures.scope()))
    }
    func testWrongPrincipalShopVersionPolicyAndCurrencyReject() throws {
        for field in ["principal_kind", "principal_id", "shop_id"] {
            var envelope = POSReadFixtures.envelope(action: .summary)
            var scope = envelope["scope"] as! [String: Any]
            scope[field] = field == "principal_kind" ? "staff" : UUID().uuidString; envelope["scope"] = scope
            XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: POSReadRequest(action: .summary), scope: POSReadFixtures.scope()))
        }
        for (key, value) in [("contract_version", 2 as Any), ("currency_code", "USD" as Any)] {
            var envelope = POSReadFixtures.envelope(action: .summary); envelope[key] = value
            XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: POSReadRequest(action: .summary), scope: POSReadFixtures.scope()))
        }
        var envelope = POSReadFixtures.envelope(action: .summary)
        envelope["capability"] = ["sales_read": true, "operational_metadata_read": false, "access_policy": "offline_lease"]
        XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: POSReadRequest(action: .summary), scope: POSReadFixtures.scope()))
    }
    func testEmptyHTTP200AndUnknownContractDoNotAuthorize() throws {
        XCTAssertThrowsError(try POSReadDecoder.decode(Data(), request: POSReadRequest(action: .summary), scope: POSReadFixtures.scope()))
        XCTAssertThrowsError(try POSReadDecoder.decode(Data("{}".utf8), request: POSReadRequest(action: .summary), scope: POSReadFixtures.scope()))
    }
    func testViewerGetsFinanceButAnyOperationalNamesReject() throws {
        _ = try POSReadFixtures.reply(action: .summary)
        var envelope = POSReadFixtures.envelope(action: .summary)
        var data = envelope["data"] as! [String: Any]; var rows = data["sales"] as! [[String: Any]]
        rows[0]["staff_name"] = "not-authorized"; data["sales"] = rows; envelope["data"] = data
        XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: POSReadRequest(action: .summary), scope: POSReadFixtures.scope()))
    }
    func testPageCursorRequiredEvenWhenLastPageIsShort() throws {
        var envelope = POSReadFixtures.envelope(action: .page, indices: [1])
        let request = try POSReadRequest(action: .page, period: POSReadFixtures.period())
        _ = try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: request, scope: POSReadFixtures.scope())
        var data = envelope["data"] as! [String: Any]; data["next_cursor"] = NSNull(); envelope["data"] = data
        XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: request, scope: POSReadFixtures.scope()))
    }
    func testDuplicateIDsOutOfOrderAndCursorReplayReject() throws {
        for indices in [[0, 0], [1, 0]] {
            XCTAssertThrowsError(try POSReadFixtures.reply(action: .page, indices: indices))
        }
        let cursor = POSCursor(beforeOccurredAt: try POSRawTimestamp(POSReadFixtures.row(1)["occurred_at"] as! String), beforeSaleId: POSReadFixtures.id(1))
        XCTAssertThrowsError(try POSReadFixtures.reply(action: .page, indices: [0], cursor: cursor))
    }
    func testDailySummaryPreservesNegativeRefundAndZeroAmounts() throws {
        let reply = try POSReadFixtures.reply(action: .summary, total: "-5")
        guard case let .summary(data) = reply.payload else { return XCTFail() }
        XCTAssertEqual(data.summaryDays[0].refundsClp.value, -7)
        XCTAssertEqual(data.summaryDays[0].discountsClp.value, 0)
        XCTAssertEqual(data.summaryDays[0].netRevenueClp.value, -5)
    }
    func testDetailUsesUpdatedAtAndFractionalLinesWithoutCatalog() throws {
        let reply = try POSReadFixtures.reply(action: .detail)
        guard case let .detail(detail) = reply.payload else { return XCTFail() }
        XCTAssertNil(detail.sale.timeZone); XCTAssertNotNil(detail.sale.updatedAt)
        XCTAssertEqual(detail.lines[0].quantity.raw, "1.125")
        XCTAssertEqual(detail.lines[0].unitAmountClp.value, 9_007_199_254_740_993)
        XCTAssertEqual(detail.sale.fiscalStatus, "pending")
        XCTAssertEqual(detail.sale.saleStatus, .accepted)
    }
    func testDetailRequiredQuantityAndAmountsRejectSQLNullAndNaN() throws {
        for key in ["quantity", "unit_amount_clp", "line_amount_clp"] {
            var envelope = POSReadFixtures.envelope(action: .detail)
            var data = envelope["data"] as! [String: Any]; var lines = data["lines"] as! [[String: Any]]
            lines[0][key] = NSNull(); data["lines"] = lines; envelope["data"] = data
            XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: POSReadRequest(action: .detail, saleID: POSReadFixtures.id(0)), scope: POSReadFixtures.scope()))
        }
        XCTAssertThrowsError(try POSQuantity("NaN"))
    }
    func testViewerFilterOptionsAndMetadataCapabilityMustAgree() throws {
        var envelope = POSReadFixtures.envelope(action: .filter)
        var data = envelope["data"] as! [String: Any]; data["staff"] = [["id": UUID().uuidString, "name": "foreign"]]
        envelope["data"] = data
        XCTAssertThrowsError(try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: POSReadRequest(action: .filter, period: POSReadFixtures.period()), scope: POSReadFixtures.scope()))
    }
    func testRAMCacheEvictsSixthPeriodAndKeepsChargeBounded() throws {
        var cache = POSRAMCache()
        let snapshot = try POSReadFixtures.snapshot()
        var first: UUID?
        for index in 0..<6 {
            let id = try cache.insert(snapshot, scope: POSReadFixtures.scope())
            if index == 0 { first = id }
        }
        XCTAssertEqual(cache.entries.count, 5); XCTAssertNil(cache[first])
        XCTAssertLessThanOrEqual(cache.charge, POSReadLimits.maximumCacheCharge)
    }
    func testRAMCache500SalesAndProtectedFailureAreAtomic() throws {
        var cache = POSRAMCache()
        let snapshot = try POSReadFixtures.snapshot(indices: Array(0..<100))
        var protected = Set<UUID>()
        for _ in 0..<5 { protected.insert(try cache.insert(snapshot, scope: POSReadFixtures.scope())) }
        let before = cache.entries.map(\.id)
        XCTAssertThrowsError(try cache.insert(snapshot, scope: POSReadFixtures.scope(), protecting: protected))
        XCTAssertEqual(cache.entries.map(\.id), before); XCTAssertEqual(cache.saleCount, 500)
    }
    func testPaginationDeduplicatesBySaleIDAndRetainsAcceptedCursor() throws {
        var snapshot = try POSReadFixtures.snapshot(indices: [0, 1])
        let authorization = try POSReadFixtures.reply(action: .page, indices: [2]).authorization
        guard case let .page(page) = try POSReadFixtures.reply(action: .page, indices: [1, 2]).payload else { return XCTFail() }
        try snapshot.append(page, authorization: authorization)
        XCTAssertEqual(snapshot.sales.map(\.id), [0, 1, 2].map(POSReadFixtures.id))
        XCTAssertEqual(snapshot.cursor?.beforeSaleId, POSReadFixtures.id(2))
        let accepted = snapshot.cursor
        XCTAssertThrowsError(try snapshot.append(page, authorization: authorization))
        XCTAssertEqual(snapshot.cursor, accepted)
    }
    @MainActor
    func testFourLanguageResourcesContainAllPOSLabelsAndMatchingPlaceholders() throws {
        let keys = ["pos.title", "pos.history", "pos.filters", "pos.newData", "pos.periodSummary", "pos.quantity",
                    "pos.notice.offline", "pos.notice.denied", "pos.notice.stalled", "pos.updatedAt", "pos.transactionCount"]
        for code in ["it", "en", "es", "zh-Hans"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: code, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys { XCTAssertNotEqual(bundle.localizedString(forKey: key, value: key, table: nil), key, "\(code)/\(key)") }
            XCTAssertEqual(bundle.localizedString(forKey: "pos.updatedAt", value: nil, table: nil).components(separatedBy: "%@").count - 1, 2)
            XCTAssertTrue(bundle.localizedString(forKey: "pos.transactionCount", value: nil, table: nil).contains("%ld"))
        }
    }
    func testPollMinimumIntervalPhaseJitterAndBackoffRetryAfter() {
        var policy = POSPollPolicy(); policy.didStart(at: 10)
        policy.succeeded(at: 10.5, phaseJitter: 0.25)
        XCTAssertFalse(policy.admits(at: 12.249)); XCTAssertTrue(policy.admits(at: 12.25))
        for (index, delay) in [4.0, 8.0, 16.0, 30.0, 30.0].enumerated() {
            policy.didStart(at: 100); policy.failed(at: 100, jitterFraction: 0.2, retryAfter: nil)
            XCTAssertEqual(policy.failures, index + 1); XCTAssertEqual(policy.nextStart, 100 + delay * 1.2, accuracy: 0.001)
        }
        policy.failed(at: 200, jitterFraction: 0, retryAfter: 120)
        XCTAssertEqual(policy.nextStart, 320)
    }
}

nonisolated enum POSReadFixtures {
    static let owner = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let shop = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    static let device = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    static let generation = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    static let epoch = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
    static func id(_ index: Int) -> UUID { UUID(uuidString: String(format: "60000000-0000-0000-0000-%012d", index))! }
    static func scope(ownerID: UUID = owner) throws -> POSReadScope {
        try POSReadScope(ownerID: ownerID, shopID: shop, deviceIdentifier: "fixture-pos-device", authGeneration: generation, authorizationEpoch: epoch)
    }
    static func period() throws -> POSPeriod { try POSPeriod(from: POSBusinessDate("2026-09-06"), to: POSBusinessDate("2026-09-06")) }
    static func timestamp() throws -> POSRawTimestamp { try POSRawTimestamp("2026-09-06T16:00:00.123456+00:00") }
    static func row(_ index: Int) -> [String: Any] {
        ["pos_sale_id": id(index).uuidString, "sale_number": "fixture-\(index)",
         "occurred_at": String(format: "2026-09-06T16:%02d:%02d.123456+00:00", 59 - index / 60, 59 - index % 60),
         "business_date": "2026-09-06", "business_kind": "sale", "sale_status": "accepted", "fiscal_status": "pending",
         "gross_amount_clp": "100", "discount_amount_clp": "0", "net_amount_clp": "100", "payment_methods": ["cash"],
         "staff_name": NSNull(), "device_name": NSNull(), "currency_code": "CLP", "time_zone": "America/Santiago",
         "latest_update_at": "2026-09-06T17:00:00.123456+00:00"]
    }
    static func envelope(action: POSAction, indices: [Int] = [0], total: String = "100") -> [String: Any] {
        let rows = indices.map(row)
        let cursor: Any = rows.last.map { ["before_occurred_at": $0["occurred_at"]!, "before_sale_id": $0["pos_sale_id"]!] as Any } ?? NSNull()
        let day: [String: Any] = ["shop_id": shop.uuidString, "business_date": "2026-09-06", "currency_code": "CLP", "time_zone": "America/Santiago",
            "gross_sales_clp": "100", "discounts_clp": "0", "refunds_clp": "-7", "net_revenue_clp": total,
            "sale_count": 1, "refund_count": 1, "void_count": 0, "transaction_count": 2,
            "latest_ledger_at": NSNull(), "server_time": "2026-09-06T17:00:00.123456+00:00"]
        var data: [String: Any] = ["sales": rows, "next_cursor": cursor]
        if action == .summary { data["summary_days"] = [day] }
        if action == .detail {
            var sale = row(0); sale.removeValue(forKey: "time_zone"); sale["updated_at"] = sale.removeValue(forKey: "latest_update_at")
            data = ["sale": sale, "lines": [["line_position": 1, "line_type": "item", "product_id": NSNull(), "item_number": NSNull(),
                "barcode": "fixture-barcode", "product_name": "Fixture", "quantity": "1.125", "unit_amount_clp": "9007199254740993", "line_amount_clp": "100"]]]
        }
        if action == .filter { data = ["can_filter_operational_metadata": false, "payment_methods": ["cash"], "staff": [], "devices": []] }
        return ["contract_version": 1, "ok": true, "code": "ok", "server_time": "2026-09-06T17:00:00.123456+00:00",
            "scope": ["principal_kind": "personal_account", "principal_id": owner.uuidString, "shop_id": shop.uuidString, "shop_device_id": device.uuidString],
            "capability": ["sales_read": true, "operational_metadata_read": false, "access_policy": "online_only"],
            "period": action == .detail ? ["from_date": NSNull(), "to_date": NSNull()] : ["from_date": "2026-09-06", "to_date": "2026-09-06"],
            "currency_code": "CLP", "time_zone": "America/Santiago", "data": data]
    }
    static func bytes(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
    static func reply(action: POSAction, indices: [Int] = [0], total: String = "100", cursor: POSCursor? = nil) throws -> POSReadReply {
        let request = try POSReadRequest(action: action, period: action == .page || action == .filter ? period() : nil,
                                         cursor: cursor, saleID: action == .detail ? id(0) : nil, limit: action == .page ? 100 : 50)
        return try POSReadDecoder.decode(bytes(envelope(action: action, indices: indices, total: total)), request: request, scope: scope())
    }
    static func snapshot(indices: [Int] = [0]) throws -> POSListSnapshot {
        let request = try POSReadRequest(action: .summary, limit: 100)
        let reply = try POSReadDecoder.decode(bytes(envelope(action: .summary, indices: indices)), request: request, scope: scope())
        guard case let .summary(data) = reply.payload else { throw POSReadError.invalidPayload }
        return try POSListSnapshot(summary: data, authorization: reply.authorization, filters: .empty, fetchedAt: Date(timeIntervalSince1970: 1))
    }
}
