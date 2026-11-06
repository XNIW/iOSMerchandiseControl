import Foundation

// Internal, RAM-only wire contract for frozen mobile_sales_read_v1 (4ebcc9b7).
nonisolated enum POSReadError: Error, Equatable, Sendable {
    case invalidPayload, incompatibleContract, staleScope, offline, deadline, cancelled, stalled
    case denied(String)
    case http(Int, retryAfter: TimeInterval?)
    case unavailable, cacheLimit
}

nonisolated struct POSAmount: Codable, Hashable, Sendable {
    let value: Int64
    init(_ raw: String) throws {
        guard let exact = Int64(raw), String(exact) == raw else { throw POSReadError.invalidPayload }
        value = exact
    }
    init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer(); try c.encode(String(value))
    }
    func formatted(locale: Locale) -> String {
        let f = NumberFormatter(); f.locale = locale; f.numberStyle = .currency
        f.currencyCode = "CLP"; f.minimumFractionDigits = 0; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "CLP \(value)"
    }
}

nonisolated struct POSQuantity: Codable, Hashable, Sendable {
    let raw: String
    let decimal: Decimal
    init(_ raw: String) throws {
        let significant = raw.filter(\.isNumber).drop(while: { $0 == "0" })
        guard raw.range(of: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?$"#, options: .regularExpression) != nil,
              significant.count <= 38, raw.count <= 80,
              let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else {
            throw POSReadError.invalidPayload
        }
        self.raw = raw; decimal = value
    }
    init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(raw) }
    func formatted(locale: Locale) -> String {
        let f = NumberFormatter(); f.locale = locale; f.numberStyle = .decimal; f.maximumFractionDigits = 38
        return f.string(from: NSDecimalNumber(decimal: decimal)) ?? raw
    }
}

nonisolated struct POSBusinessDate: Codable, Hashable, Comparable, Sendable {
    let raw: String
    init(_ raw: String) throws {
        guard raw.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else {
            throw POSReadError.invalidPayload
        }
        let pieces = raw.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: pieces[0], month: pieces[1], day: pieces[2])
        guard pieces[0] >= 1, let date = calendar.date(from: components),
              calendar.component(.year, from: date) == pieces[0],
              calendar.component(.month, from: date) == pieces[1], calendar.component(.day, from: date) == pieces[2] else {
            throw POSReadError.invalidPayload
        }
        self.raw = raw
    }
    init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(raw) }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.raw < rhs.raw }
    var utcDate: Date {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let p = raw.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))!
    }
}

nonisolated struct POSRawTimestamp: Codable, Hashable, Sendable {
    let raw: String
    private let second: Int64
    private let microsecond: Int
    init(_ raw: String) throws {
        guard raw.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})$"#,
                        options: .regularExpression) != nil else { throw POSReadError.invalidPayload }
        let bytes = Array(raw.utf8)
        func number(_ start: Int, _ count: Int) -> Int { Int(String(decoding: bytes[start..<(start + count)], as: UTF8.self))! }
        let date = try POSBusinessDate(String(raw.prefix(10)))
        let hour = number(11, 2), minute = number(14, 2), seconds = number(17, 2)
        guard hour < 24, minute < 60, seconds < 60 else { throw POSReadError.invalidPayload }
        let zoneStart = raw.hasSuffix("Z") ? bytes.count - 1 : bytes.count - 6
        var offset = 0
        if !raw.hasSuffix("Z") {
            let h = number(zoneStart + 1, 2), m = number(zoneStart + 4, 2)
            guard h < 24, m < 60 else { throw POSReadError.invalidPayload }
            offset = (h * 3_600 + m * 60) * (bytes[zoneStart] == 45 ? -1 : 1)
        }
        let fraction = zoneStart > 19 ? String(decoding: bytes[20..<zoneStart], as: UTF8.self) : ""
        microsecond = Int(fraction + String(repeating: "0", count: 6 - fraction.count)) ?? 0
        second = Int64(date.utcDate.timeIntervalSince1970) + Int64(hour * 3_600 + minute * 60 + seconds - offset)
        self.raw = raw
    }
    init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(raw) }
    // Date/Double are presentation-only; cursor comparison/encoding are exact integer microseconds/raw.
    var displayDate: Date? { Date(timeIntervalSince1970: Double(second) + Double(microsecond) / 1_000_000) }
    func precedes(_ other: Self, id: UUID, otherID: UUID) -> Bool {
        if second != other.second { return second < other.second }
        if microsecond != other.microsecond { return microsecond < other.microsecond }
        return id.uuidString.lowercased() < otherID.uuidString.lowercased()
    }
}

nonisolated struct POSPeriod: Codable, Hashable, Sendable {
    let fromDate: POSBusinessDate
    let toDate: POSBusinessDate
    init(from: POSBusinessDate, to: POSBusinessDate) throws {
        guard from <= to, to.utcDate.timeIntervalSince(from.utcDate) <= 365 * 86_400 else {
            throw POSReadError.invalidPayload
        }
        fromDate = from; toDate = to
    }
    var dayCount: Int { Int(toDate.utcDate.timeIntervalSince(fromDate.utcDate) / 86_400) + 1 }
}

nonisolated struct POSReadScope: Hashable, Sendable {
    let ownerID: UUID
    let shopID: UUID
    let deviceIdentifier: String
    let authGeneration: UUID
    let authorizationEpoch: UUID
    init(ownerID: UUID, shopID: UUID, deviceIdentifier: String, authGeneration: UUID, authorizationEpoch: UUID) throws {
        let trimmed = deviceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, deviceIdentifier.utf8.count <= 160 else { throw POSReadError.staleScope }
        self.ownerID = ownerID; self.shopID = shopID; self.deviceIdentifier = trimmed
        self.authGeneration = authGeneration; self.authorizationEpoch = authorizationEpoch
    }
}

nonisolated enum POSSaleStatus: String, CaseIterable, Codable, Sendable { case accepted, duplicate, conflict, rejected }
nonisolated enum POSBusinessKind: String, CaseIterable, Codable, Sendable { case sale, refund, void }
nonisolated struct POSFilters: Codable, Hashable, Sendable {
    var status: POSSaleStatus?
    var businessKind: POSBusinessKind?
    var paymentMethod: String?
    var staffID: UUID?
    var deviceID: UUID?
    var saleNumber: String?
    static let empty = Self()
    func validate() throws {
        if let paymentMethod, !(1...40).contains(paymentMethod.count) { throw POSReadError.invalidPayload }
        if let saleNumber, !(1...80).contains(saleNumber.count) { throw POSReadError.invalidPayload }
    }
}
nonisolated struct POSCursor: Codable, Equatable, Sendable {
    let beforeOccurredAt: POSRawTimestamp
    let beforeSaleId: UUID
}
nonisolated enum POSAction: String, Sendable { case summary, page, detail, filter }
nonisolated struct POSReadRequest: Encodable, Sendable {
    let action: POSAction
    let period: POSPeriod?
    let filters: POSFilters
    let cursor: POSCursor?
    let saleID: UUID?
    let limit: Int
    init(action: POSAction, period: POSPeriod? = nil, filters: POSFilters = .empty,
         cursor: POSCursor? = nil, saleID: UUID? = nil, limit: Int = 50) throws {
        try filters.validate()
        guard (1...100).contains(limit), (action != .page || period != nil),
              (action != .filter || period != nil),
              ((action == .detail) == (saleID != nil)),
              (action == .page || cursor == nil),
              (!([.detail, .filter].contains(action)) || (filters == .empty && cursor == nil && limit == 50)),
              (action != .detail || period == nil) else { throw POSReadError.invalidPayload }
        self.action = action; self.period = period; self.filters = filters
        self.cursor = cursor; self.saleID = saleID; self.limit = limit
    }
    func encode(to encoder: Encoder) throws {
        // Scope is supplied by POSRPCParameters; encoding a naked request is forbidden.
        throw POSReadError.staleScope
    }
}
nonisolated struct POSRPCParameters: Encodable, Sendable {
    let scope: POSReadScope
    let request: POSReadRequest
    enum Keys: String, CodingKey {
        case shop = "p_shop_id", device = "p_device_identifier", action = "p_action"
        case from = "p_from_date", to = "p_to_date", limit = "p_limit"
        case beforeAt = "p_before_occurred_at", beforeID = "p_before_sale_id"
        case status = "p_status", kind = "p_business_kind", payment = "p_payment_method"
        case staff = "p_staff_id", filterDevice = "p_device_id", number = "p_sale_number", sale = "p_pos_sale_id"
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(scope.shopID, forKey: .shop); try c.encode(scope.deviceIdentifier, forKey: .device)
        try c.encode(request.action.rawValue, forKey: .action); try c.encode(request.limit, forKey: .limit)
        try c.encodeIfPresent(request.period?.fromDate, forKey: .from); try c.encodeIfPresent(request.period?.toDate, forKey: .to)
        try c.encodeIfPresent(request.cursor?.beforeOccurredAt, forKey: .beforeAt)
        try c.encodeIfPresent(request.cursor?.beforeSaleId, forKey: .beforeID)
        try c.encodeIfPresent(request.filters.status, forKey: .status); try c.encodeIfPresent(request.filters.businessKind, forKey: .kind)
        try c.encodeIfPresent(request.filters.paymentMethod, forKey: .payment); try c.encodeIfPresent(request.filters.staffID, forKey: .staff)
        try c.encodeIfPresent(request.filters.deviceID, forKey: .filterDevice); try c.encodeIfPresent(request.filters.saleNumber, forKey: .number)
        try c.encodeIfPresent(request.saleID, forKey: .sale)
    }
}

nonisolated struct POSDaySummary: Codable, Equatable, Sendable, Identifiable {
    let shopId: UUID
    let businessDate: POSBusinessDate
    let currencyCode: String
    let timeZone: String
    let grossSalesClp: POSAmount
    let discountsClp: POSAmount
    let refundsClp: POSAmount
    let netRevenueClp: POSAmount
    let saleCount: Int
    let refundCount: Int
    let voidCount: Int
    let transactionCount: Int
    let latestLedgerAt: POSRawTimestamp?
    let serverTime: POSRawTimestamp
    var id: String { businessDate.raw }
}
nonisolated struct POSSale: Codable, Equatable, Sendable, Identifiable {
    let posSaleId: UUID
    let saleNumber: String
    let occurredAt: POSRawTimestamp
    let businessDate: POSBusinessDate
    let businessKind: POSBusinessKind
    let saleStatus: POSSaleStatus
    let fiscalStatus: String
    let grossAmountClp: POSAmount
    let discountAmountClp: POSAmount
    let netAmountClp: POSAmount
    let paymentMethods: [String]
    let staffName: String?
    let deviceName: String?
    let currencyCode: String
    let timeZone: String?
    let latestUpdateAt: POSRawTimestamp?
    let updatedAt: POSRawTimestamp?
    var id: UUID { posSaleId }
}
nonisolated struct POSLine: Codable, Equatable, Sendable, Identifiable {
    let linePosition: Int
    let lineType: String
    let productId: UUID?
    let itemNumber: String?
    let barcode: String?
    let productName: String?
    let quantity: POSQuantity
    let unitAmountClp: POSAmount
    let lineAmountClp: POSAmount
    var id: Int { linePosition }
}
nonisolated struct POSSummaryData: Codable, Equatable, Sendable {
    let summaryDays: [POSDaySummary]
    let sales: [POSSale]
    let nextCursor: POSCursor?
}
nonisolated struct POSPageData: Codable, Equatable, Sendable {
    let sales: [POSSale]
    let nextCursor: POSCursor?
}
nonisolated struct POSDetailData: Codable, Equatable, Sendable {
    let sale: POSSale
    let lines: [POSLine]
}
nonisolated struct POSNamedOption: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
}
nonisolated struct POSFilterData: Codable, Equatable, Sendable {
    let canFilterOperationalMetadata: Bool
    let paymentMethods: [String]
    let staff: [POSNamedOption]
    let devices: [POSNamedOption]
}
nonisolated struct POSAuthorization: Equatable, Sendable {
    let shopDeviceID: UUID
    let metadataRead: Bool
    let period: POSPeriod?
    let serverTime: POSRawTimestamp
    let timeZone: String
}
nonisolated enum POSPayload: Equatable, Sendable {
    case summary(POSSummaryData), page(POSPageData), detail(POSDetailData), filter(POSFilterData)
}
nonisolated struct POSReadReply: Equatable, Sendable {
    let authorization: POSAuthorization
    let payload: POSPayload
    let receivedBytes: Int
}

nonisolated enum POSReadDecoder {
    private struct Scope: Decodable { let principalKind: String; let principalId: UUID; let shopId: UUID; let shopDeviceId: UUID }
    private struct Capability: Decodable { let salesRead: Bool; let operationalMetadataRead: Bool; let accessPolicy: String }
    private struct Period: Decodable { let fromDate: POSBusinessDate?; let toDate: POSBusinessDate? }
    private struct Header: Decodable {
        let contractVersion: Int; let ok: Bool; let code: String; let serverTime: POSRawTimestamp
        let scope: Scope?; let capability: Capability?; let period: Period?; let currencyCode: String?; let timeZone: String?
    }
    private struct Body<T: Decodable>: Decodable { let data: T }
    static func decode(_ bytes: Data, request: POSReadRequest, scope: POSReadScope) throws -> POSReadReply {
        guard bytes.count <= POSReadLimits.maximumResponseBytes else { throw POSReadError.invalidPayload }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let h = try decoder.decode(Header.self, from: bytes)
        guard h.contractVersion == 1 else { throw POSReadError.incompatibleContract }
        if !h.ok {
            let denied = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
            guard denied?["data"] is NSNull,
                  ["unauthenticated", "invalid_request", "permission_denied", "device_not_authorized",
                   "metadata_filter_not_allowed", "currency_unsupported", "not_found"].contains(h.code) else {
                throw POSReadError.invalidPayload
            }
            throw POSReadError.denied(h.code)
        }
        guard h.code == "ok", let s = h.scope, s.principalKind == "personal_account",
              s.principalId == scope.ownerID, s.shopId == scope.shopID,
              let cap = h.capability, cap.salesRead, cap.accessPolicy == "online_only",
              h.currencyCode == "CLP", let zone = h.timeZone, TimeZone(identifier: zone) != nil,
              let wirePeriod = h.period else { throw POSReadError.invalidPayload }
        let period: POSPeriod?
        if let from = wirePeriod.fromDate, let to = wirePeriod.toDate { period = try POSPeriod(from: from, to: to) }
        else { guard wirePeriod.fromDate == nil && wirePeriod.toDate == nil else { throw POSReadError.invalidPayload }; period = nil }
        guard (request.action == .detail ? period == nil : period != nil) else { throw POSReadError.invalidPayload }
        if let requested = request.period { guard period == requested else { throw POSReadError.invalidPayload } }
        else if request.action == .summary { guard period?.dayCount == 1 else { throw POSReadError.invalidPayload } }
        guard cap.operationalMetadataRead || (request.filters.staffID == nil && request.filters.deviceID == nil) else {
            throw POSReadError.invalidPayload
        }
        let auth = POSAuthorization(shopDeviceID: s.shopDeviceId, metadataRead: cap.operationalMetadataRead,
                                    period: period, serverTime: h.serverTime, timeZone: zone)
        let payload: POSPayload
        switch request.action {
        case .summary:
            let v = try decoder.decode(Body<POSSummaryData>.self, from: bytes).data
            guard let period, v.summaryDays.count == period.dayCount,
                  Set(v.summaryDays.map(\.businessDate)).count == v.summaryDays.count,
                  v.summaryDays.allSatisfy({ $0.shopId == scope.shopID && $0.currencyCode == "CLP" && $0.timeZone == zone
                      && period.fromDate <= $0.businessDate && $0.businessDate <= period.toDate
                      && [$0.saleCount, $0.refundCount, $0.voidCount, $0.transactionCount].allSatisfy({ $0 >= 0 }) }) else {
                throw POSReadError.invalidPayload
            }
            try validatePage(v.sales, cursor: v.nextCursor, request: request, auth: auth); payload = .summary(v)
        case .page:
            let v = try decoder.decode(Body<POSPageData>.self, from: bytes).data
            try validatePage(v.sales, cursor: v.nextCursor, request: request, auth: auth); payload = .page(v)
        case .detail:
            let v = try decoder.decode(Body<POSDetailData>.self, from: bytes).data
            guard v.sale.id == request.saleID, v.sale.currencyCode == "CLP", v.sale.updatedAt != nil,
                  v.lines.count <= 5_000, Set(v.lines.map(\.id)).count == v.lines.count,
                  v.lines.allSatisfy({ ["item", "discount", "tax", "adjustment"].contains($0.lineType) }),
                  cap.operationalMetadataRead || (v.sale.staffName == nil && v.sale.deviceName == nil) else {
                throw POSReadError.invalidPayload
            }
            payload = .detail(v)
        case .filter:
            let v = try decoder.decode(Body<POSFilterData>.self, from: bytes).data
            guard v.canFilterOperationalMetadata == cap.operationalMetadataRead, v.paymentMethods.count <= 40,
                  v.staff.count <= 100, v.devices.count <= 100,
                  cap.operationalMetadataRead || (v.staff.isEmpty && v.devices.isEmpty) else { throw POSReadError.invalidPayload }
            payload = .filter(v)
        }
        return POSReadReply(authorization: auth, payload: payload, receivedBytes: bytes.count)
    }
    private static func validatePage(_ rows: [POSSale], cursor: POSCursor?, request: POSReadRequest, auth: POSAuthorization) throws {
        guard rows.count <= request.limit, Set(rows.map(\.id)).count == rows.count, let period = auth.period,
              rows.allSatisfy({ $0.currencyCode == "CLP" && $0.timeZone == auth.timeZone && $0.latestUpdateAt != nil
                  && period.fromDate <= $0.businessDate && $0.businessDate <= period.toDate
                  && (auth.metadataRead || ($0.staffName == nil && $0.deviceName == nil))
                  && (request.filters.status == nil || $0.saleStatus == request.filters.status)
                  && (request.filters.businessKind == nil || $0.businessKind == request.filters.businessKind) }) else {
            throw POSReadError.invalidPayload
        }
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let previous = rows[index - 1]
                guard row.occurredAt.precedes(previous.occurredAt, id: row.id, otherID: previous.id) else { throw POSReadError.invalidPayload }
            }
            if let before = request.cursor {
                guard row.occurredAt.precedes(before.beforeOccurredAt, id: row.id, otherID: before.beforeSaleId) else { throw POSReadError.invalidPayload }
            }
        }
        if let last = rows.last {
            guard cursor?.beforeSaleId == last.id, cursor?.beforeOccurredAt == last.occurredAt,
                  cursor != request.cursor else { throw POSReadError.invalidPayload }
        } else { guard cursor == nil else { throw POSReadError.invalidPayload }; return }
    }
}

nonisolated enum POSReadLimits {
    static let maximumResponseBytes = 1_048_576
    static let maximumPeriods = 5
    static let maximumSales = 500
    static let maximumCacheCharge = 5 * 1_024 * 1_024
}
