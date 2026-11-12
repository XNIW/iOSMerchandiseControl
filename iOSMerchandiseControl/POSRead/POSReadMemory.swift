import Foundation

nonisolated struct POSListSnapshot: Codable, Equatable, Sendable {
    let period: POSPeriod
    let filters: POSFilters
    let currencyCode: String
    let timeZone: String
    let metadataRead: Bool
    let shopDeviceID: UUID
    let summaryDays: [POSDaySummary]
    var sales: [POSSale]
    var cursor: POSCursor?
    let fetchedAt: Date
    let serverTime: POSRawTimestamp
    var limitReached = false

    init(summary: POSSummaryData, authorization: POSAuthorization, filters: POSFilters, fetchedAt: Date) throws {
        guard let period = authorization.period else { throw POSReadError.invalidPayload }
        self.period = period; self.filters = filters; currencyCode = "CLP"; timeZone = authorization.timeZone
        metadataRead = authorization.metadataRead; shopDeviceID = authorization.shopDeviceID
        summaryDays = summary.summaryDays; sales = summary.sales; cursor = summary.nextCursor
        self.fetchedAt = fetchedAt; serverTime = authorization.serverTime
    }
    mutating func append(_ page: POSPageData, authorization: POSAuthorization) throws {
        guard authorization.period == period, authorization.timeZone == timeZone,
              authorization.metadataRead == metadataRead, authorization.shopDeviceID == shopDeviceID,
              page.nextCursor != cursor || page.sales.isEmpty else { throw POSReadError.invalidPayload }
        var positions = Dictionary(uniqueKeysWithValues: sales.enumerated().map { ($0.element.id, $0.offset) })
        for row in page.sales {
            if let index = positions[row.id] { sales[index] = row }
            else { positions[row.id] = sales.count; sales.append(row) }
        }
        guard sales.count <= POSReadLimits.maximumSales else { throw POSReadError.invalidPayload }
        cursor = page.nextCursor
    }
    // A conservative payload charge, not an RSS measurement. No encoded copy is retained.
    var cacheCharge: Int {
        guard let bytes = try? JSONEncoder().encode(self).count else { return POSReadLimits.maximumCacheCharge + 1 }
        return bytes * 4 + sales.count * 512 + summaryDays.count * 256
    }
}

nonisolated struct POSRAMCache: Sendable {
    struct Entry: Sendable { let id: UUID; let scope: POSReadScope; var snapshot: POSListSnapshot; let charge: Int }
    private(set) var entries: [Entry] = []
    var saleCount: Int { entries.reduce(0) { $0 + $1.snapshot.sales.count } }
    var charge: Int { entries.reduce(0) { $0 + $1.charge } }
    subscript(_ id: UUID?) -> POSListSnapshot? { entries.first(where: { $0.id == id })?.snapshot }
    mutating func remove(_ id: UUID?) { entries.removeAll { $0.id == id } }
    mutating func clear() { entries.removeAll() }
    mutating func insert(_ snapshot: POSListSnapshot, scope: POSReadScope, replacing: UUID? = nil,
                         protecting: Set<UUID> = []) throws -> UUID {
        // Work on a value copy: rejected page/stage never advances the accepted cursor.
        var candidate = self; candidate.remove(replacing)
        let id = UUID(); candidate.entries.append(Entry(id: id, scope: scope, snapshot: snapshot, charge: snapshot.cacheCharge))
        while candidate.entries.count > POSReadLimits.maximumPeriods || candidate.saleCount > POSReadLimits.maximumSales
                || candidate.charge > POSReadLimits.maximumCacheCharge {
            guard let index = candidate.entries.firstIndex(where: { $0.id != id && !protecting.contains($0.id) }) else {
                throw POSReadError.cacheLimit
            }
            candidate.entries.remove(at: index)
        }
        self = candidate; return id
    }
    mutating func reserveForDetail(charge: Int) throws {
        guard charge <= POSReadLimits.maximumCacheCharge else { throw POSReadError.invalidPayload }
        while self.charge + charge > POSReadLimits.maximumCacheCharge || saleCount >= POSReadLimits.maximumSales {
            guard !entries.isEmpty else { throw POSReadError.invalidPayload }; entries.removeFirst()
        }
    }
}

nonisolated struct POSPollPolicy: Sendable {
    private(set) var lastStart: TimeInterval?
    private(set) var nextStart: TimeInterval = 0
    private(set) var failures = 0
    var stopped = false
    mutating func didStart(at now: TimeInterval) { lastStart = now; nextStart = now + 2 }
    mutating func succeeded(at now: TimeInterval, phaseJitter: TimeInterval) {
        failures = 0; nextStart = max((lastStart ?? now) + 2, now) + min(0.25, max(0, phaseJitter))
    }
    mutating func failed(at now: TimeInterval, jitterFraction: Double, retryAfter: TimeInterval?) {
        failures += 1
        let delay: TimeInterval = [4, 8, 16, 30][min(failures - 1, 3)]
        nextStart = max((lastStart ?? now) + 2, now + max(delay * (1 + min(0.2, max(0, jitterFraction))), retryAfter ?? 0))
    }
    func admits(at now: TimeInterval) -> Bool { !stopped && now >= nextStart }
}
