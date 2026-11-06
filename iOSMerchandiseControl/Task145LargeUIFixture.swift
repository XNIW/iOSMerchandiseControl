#if DEBUG
import Foundation

/// TASK145_PERF shares the existing T20 deterministic rows. Only the separate
/// seed process creates these files. Measured launches never generate rows.
@MainActor
final class Task145LargeUITransport {
    let directory: URL
    private(set) var checkpointValue: ShopSyncRecoveryCheckpoint
    private var priceCursorIndices: [String: Int]
    var holdNextProducts = Task145PerformanceConfiguration.recovery
    private(set) var held = false
    private(set) var heldAt: UInt64?
    private var hold: CheckedContinuation<Void, Error>?
    private var deadline: Task<Void, Never>?
    var onRecoveryHeld: (() -> Void)?
    private var businessReleasedForSample = false
    struct RequestObservation {
        let sequence: Int
        let kind: String
        let startedNS: UInt64
        let requestDeadlineNS: UInt64
        let resourceDeadlineNS: UInt64
    }
    private(set) var activeRequest: RequestObservation?
    private(set) var lastRequestTerminalNS: UInt64?
    private(set) var lastFailedRequestTerminalNS: UInt64?
    private(set) var longestRequestNS: UInt64 = 0
    private(set) var requestDeadlineExpired = false
    private(set) var requests = 0
    private(set) var bytes = 0
    init(directory: URL) throws {
        self.directory = directory
        checkpointValue = try JSONDecoder().decode(ShopSyncRecoveryCheckpoint.self,
            from: Data(contentsOf: directory.appendingPathComponent("checkpoint.json")))
        priceCursorIndices = try JSONDecoder().decode([String: Int].self,
            from: Data(contentsOf: directory.appendingPathComponent("price-cursors.json")))
    }
    static func seed(directory: URL, base: ShopSyncRecoveryCheckpoint, owner: UUID) throws {
        // Only a fresh fixture-owned directory is allowed; never replace evidence.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let timestamp = "2026-07-21T12:00:00.000000Z"
        var products: [RemoteInventoryProductRow] = []
        var prices: [RemoteInventoryProductPriceRow] = []
        products.reserveCapacity(20_000); prices.reserveCapacity(40_000)
        let suppliers = (0...1).map { i in RemoteInventorySupplierRow(id: Task145PerformanceConfiguration.supplierIDs[i],
            ownerUserID: owner, shopID: base.shopId, name: Task145PerformanceConfiguration.supplierNames[i], updatedAt: timestamp, deletedAt: nil) }
        let categories = (0...1).map { i in RemoteInventoryCategoryRow(id: Task145PerformanceConfiguration.categoryIDs[i],
            ownerUserID: owner, shopID: base.shopId, name: Task145PerformanceConfiguration.categoryNames[i], updatedAt: timestamp, deletedAt: nil) }
        var supplierAccumulator = ShopSyncRecoveryDigestAccumulator(), categoryAccumulator = ShopSyncRecoveryDigestAccumulator()
        for row in suppliers {
            let record = try ShopSyncRecoveryRowContract.supplier(row, checkpoint: base)
            try supplierAccumulator.append(orderingID: record.orderingID, idLine: record.idLine,
                versionLine: record.versionLine, identityLine: record.identityLine, isTombstone: record.isTombstone)
        }
        for row in categories {
            let record = try ShopSyncRecoveryRowContract.category(row, checkpoint: base)
            try categoryAccumulator.append(orderingID: record.orderingID, idLine: record.idLine,
                versionLine: record.versionLine, identityLine: record.identityLine, isTombstone: record.isTombstone)
        }
        let supplierDigest = supplierAccumulator.finalize(), categoryDigest = categoryAccumulator.finalize()
        var productDigest = ShopSyncRecoveryDigestAccumulator(hasIdentity: true)
        var priceDigest = ShopSyncRecoveryDigestAccumulator()
        for index in 1...20_000 {
            let product = RemoteInventoryProductRow(
                id: UUID(uuidString: String(format: "20000000-0000-4000-8000-%012d", index))!,
                ownerUserID: owner, shopID: base.shopId, barcode: String(format: "T20-%06d", index),
                itemNumber: "T20-\(index)", productName: "Synthetic T20 \(index)", secondProductName: nil,
                purchasePrice: 10, retailPrice: 20,
                supplierID: index == 20_000 ? Task145PerformanceConfiguration.supplierIDs[0] : nil,
                categoryID: index == 20_000 ? Task145PerformanceConfiguration.categoryIDs[0] : nil,
                stockQuantity: 0, updatedAt: timestamp, deletedAt: nil)
            products.append(product)
            let record = try ShopSyncRecoveryRowContract.product(product, checkpoint: base)
            try productDigest.append(orderingID: record.orderingID, idLine: record.idLine,
                versionLine: record.versionLine, identityLine: record.identityLine, isTombstone: record.isTombstone)
            for type in 0...1 {
                let price = RemoteInventoryProductPriceRow(
                    id: UUID(uuidString: String(format: "30000000-0000-4000-8000-%012d", (index - 1) * 2 + type + 1))!,
                    ownerUserID: owner, shopID: base.shopId, productID: product.id,
                    type: type == 0 ? "PURCHASE" : "RETAIL", price: type == 0 ? 10 : 20,
                    priceCanonical: type == 0 ? "10" : "20", effectiveAt: "2026-07-21 12:00:00",
                    source: "T20_SYNTHETIC", note: nil, createdAt: "2026-07-21 12:00:00", updatedAt: timestamp)
                prices.append(price)
                let row = try ShopSyncRecoveryRowContract.price(price, checkpoint: base)
                try priceDigest.append(orderingID: row.orderingID, idLine: row.idLine,
                    versionLine: row.versionLine, identityLine: row.identityLine, isTombstone: row.isTombstone)
            }
        }
        let p = productDigest.finalize(), pp = priceDigest.finalize()
        let checkpoint = ShopSyncRecoveryCheckpoint(schemaVersion: base.schemaVersion,
            shopId: base.shopId, scope: base.scope, syncEvents: base.syncEvents,
            catalog: .init(suppliers: supplierDigest, categories: categoryDigest,
                products: p, digest: ShopSyncRecoveryCanonical.sha256(supplierDigest.versionDigest + "\n"
                    + categoryDigest.versionDigest + "\n" + p.versionDigest)),
            prices: pp, history: base.history, images: base.images, integrity: base.integrity,
            checkpointDigest: ShopSyncRecoveryCanonical.sha256("T20-20261016-v1-relations-2x2"))
        func write<T: Encodable>(_ value: T, _ name: String) throws {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(value).write(to: directory.appendingPathComponent(name), options: .withoutOverwriting)
        }
        for start in stride(from: 0, to: products.count, by: 250) {
            try write(Array(products[start..<min(start + 250, products.count)]), "products-\(start).json")
        }
        for start in stride(from: 0, to: prices.count, by: 250) {
            try write(Array(prices[start..<min(start + 250, prices.count)]), "prices-\(start).json")
        }
        try write(suppliers, "suppliers.json"); try write(categories, "categories.json")
        var priceCursors: [String: Int] = [:]
        for end in stride(from: 250, to: prices.count, by: 250) { priceCursors[prices[end - 1].id.uuidString.lowercased()] = end }
        try write(priceCursors, "price-cursors.json")
        try write(checkpoint, "checkpoint.json")
        try write(["seed": "T20-20261016-v1-relations-2x2", "products": "20000", "prices": "40000",
            "priceProductRelations": "40000", "productSupplierRelations": "1", "productCategoryRelations": "1",
            "suppliers": "2", "categories": "2", "history": "0",
            "productVersionDigest": p.versionDigest, "priceVersionDigest": pp.versionDigest,
            "supplierVersionDigest": supplierDigest.versionDigest, "categoryVersionDigest": categoryDigest.versionDigest,
            "historyVersionDigest": base.history.versionDigest], "manifest.json")
    }
    func beginRequest(_ kind: String) throws {
        if Task145PerformanceConfiguration.offline { throw URLError(.notConnectedToInternet) }
        guard activeRequest == nil else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        requests += 1
        let now = DispatchTime.now().uptimeNanoseconds
        activeRequest = .init(sequence: requests, kind: kind, startedNS: now,
            requestDeadlineNS: now + 45_000_000_000, resourceDeadlineNS: now + 60_000_000_000)
        requestDeadlineExpired = false
        Task144RootObservation.performanceMetadata(["activeRequest": kind, "activeRequestStartedNS": String(now),
            "activeRequestDeadlineNS": String(now + 45_000_000_000), "activeResourceDeadlineNS": String(now + 60_000_000_000)])
    }
    func finishRequest(success: Bool) {
        guard let request = activeRequest else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        activeRequest = nil; deadline?.cancel(); deadline = nil
        lastRequestTerminalNS = now
        longestRequestNS = max(longestRequestNS, now - request.startedNS)
        if !success || requestDeadlineExpired { lastFailedRequestTerminalNS = now }
        Task144RootObservation.performanceMetadata([
            "activeRequest": "none", "lastRequestSequence": String(request.sequence), "lastRequestKind": request.kind,
            "lastRequestTerminalNS": String(now), "longestRequestNS": String(longestRequestNS),
            "requestCount": String(requests), "pageResponseBytes": String(bytes)])
    }
    private func startHeldRequestDeadline() {
        guard let request = activeRequest else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        let remaining = request.requestDeadlineNS > now ? request.requestDeadlineNS - now : 0
        deadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: remaining) } catch { return }
            guard let self, activeRequest?.sequence == request.sequence else { return }
            requestDeadlineExpired = true
            endHold(error: URLError(.timedOut))
        }
    }
    func validateRequestDeadline() throws {
        guard let request = activeRequest else { return }
        if requestDeadlineExpired || DispatchTime.now().uptimeNanoseconds > request.requestDeadlineNS {
            throw URLError(.timedOut)
        }
    }
    func checkpoint(_ parameters: ShopSyncRecoveryCheckpointParameters) throws -> Data {
        try beginRequest("checkpoint")
        var succeeded = false; defer { finishRequest(success: succeeded) }
        let c = checkpointValue
        let data = try JSONEncoder().encode(ShopSyncRecoveryCheckpoint(schemaVersion: c.schemaVersion,
            shopId: c.shopId, scope: c.scope,
            syncEvents: .init(maxId: c.syncEvents.maxId, verifiedBaselineId: parameters.verifiedBaselineID,
                requiresFullRecovery: true, domainMaxIds: c.syncEvents.domainMaxIds), catalog: c.catalog,
            prices: c.prices, history: c.history, images: c.images, integrity: c.integrity,
            checkpointDigest: c.checkpointDigest))
        succeeded = true; return data
    }
    func page(_ parameters: ShopSyncRecoveryPageParameters) async throws -> Data {
        try beginRequest("recovery-page." + parameters.domain)
        var succeeded = false; defer { finishRequest(success: succeeded) }
        if parameters.domain == "products", holdNextProducts {
            holdNextProducts = false; held = true; heldAt = DispatchTime.now().uptimeNanoseconds
            Task144RootObservation.performanceMark("requestHeld", facts: "real-facade-products-request;deadline45s")
            Task144RootObservation.performanceMetadata(["responseHeld": "true"])
            onRecoveryHeld?()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    hold = continuation
                    startHeldRequestDeadline()
                }
            } onCancel: { Task { @MainActor [weak self] in self?.endHold(error: CancellationError()) } }
            try Task.checkCancellation()
        }
        try validateRequestDeadline()
        guard let domain = ShopSyncRecoveryDomain(rawValue: parameters.domain),
              parameters.limit == min(250, ShopSyncRecoveryLimits.maximumPageRows(for: domain)) else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
        let start: Int
        if let after = parameters.afterID, domain == .prices {
            if let index = priceCursorIndices[after.lowercased()] { start = index }
            else {
                // Files remain the original 250-row seed chunks. The caller's
                // bounded page may finish inside a chunk, including after a
                // controlled price insert has changed UUID ordering.
                let boundary = priceCursorIndices.keys.sorted().first { $0 >= after.lowercased() }
                let chunkStart = boundary.flatMap { priceCursorIndices[$0].map { $0 - 250 } }
                    ?? ((checkpointValue.prices.activeCount - 1) / 250) * 250
                let rows = try JSONDecoder().decode([RemoteInventoryProductPriceRow].self,
                    from: Data(contentsOf: directory.appendingPathComponent("prices-\(chunkStart).json")))
                guard let offset = rows.firstIndex(where: { $0.id.uuidString.lowercased() == after.lowercased() }) else {
                    throw ShopSyncRecoveryContractError.invalidCursor
                }
                start = chunkStart + offset + 1
            }
        } else if let after = parameters.afterID {
            guard domain == .products, let suffix = after.split(separator: "-").last,
                  let number = Int(suffix), number > 0, number < 20_000,
                  after.lowercased() == String(format: "20000000-0000-4000-8000-%012d", number) else {
                throw ShopSyncRecoveryContractError.invalidCursor
            }
            start = number
        } else { start = 0 }
        func readPage<Row: Decodable>(_ type: Row.Type, prefix: String, count: Int) throws -> [Row] {
            guard start < count else { throw ShopSyncRecoveryContractError.invalidCursor }
            var rows: [Row] = []
            let end = min(start + parameters.limit, count)
            var offset = start
            while offset < end {
                let chunkStart = (offset / 250) * 250
                let chunk = try JSONDecoder().decode([Row].self,
                    from: Data(contentsOf: directory.appendingPathComponent("\(prefix)-\(chunkStart).json")))
                let first = offset - chunkStart
                let last = min(chunk.count, end - chunkStart)
                guard first < last else { throw ShopSyncRecoveryContractError.invalidPage(domain: domain) }
                rows.append(contentsOf: chunk[first..<last])
                offset += last - first
            }
            return rows
        }
        func encoded<Row: Codable>(_ rows: [Row], count: Int, prefix: String, nextID: String? = nil) throws -> Data {
            let end = start + rows.count, more = end < count
            let c = checkpointValue
            let data = try JSONEncoder().encode(Task145LargePage(schemaVersion: "shop-sync-recovery-page-v1",
                shopId: c.shopId, scope: c.scope, domain: domain, snapshotEventMaxId: c.syncEvents.maxId,
                currentScopeEventMaxId: c.syncEvents.maxId, baselineDomainEventMaxId: parameters.expectedDomainEventMaxID,
                pageDomainEventMaxId: c.syncEvents.domainMaxID(for: domain),
                domainScope: domain == .history ? c.scope.historyKind : c.scope.kind, pageLimit: parameters.limit, rows: rows,
                nextAfterId: more ? (nextID ?? String(format: prefix + "-%012d", end)) : nil, hasMore: more))
            bytes += data.count; succeeded = true; return data
        }
        switch domain {
        case .products:
            let rows = try readPage(RemoteInventoryProductRow.self, prefix: "products", count: 20_000)
            return try encoded(rows, count: 20_000, prefix: "20000000-0000-4000-8000")
        case .prices:
            let rows = try readPage(RemoteInventoryProductPriceRow.self, prefix: "prices", count: checkpointValue.prices.activeCount)
            return try encoded(rows, count: checkpointValue.prices.activeCount, prefix: "30000000-0000-4000-8000",
                nextID: rows.last?.id.uuidString.lowercased())
        case .suppliers:
            let rows = try JSONDecoder().decode([RemoteInventorySupplierRow].self, from: Data(contentsOf: directory.appendingPathComponent("suppliers.json")))
            return try encoded(rows, count: rows.count, prefix: "")
        case .categories:
            let rows = try JSONDecoder().decode([RemoteInventoryCategoryRow].self, from: Data(contentsOf: directory.appendingPathComponent("categories.json")))
            return try encoded(rows, count: rows.count, prefix: "")
        default: return try encoded([RemoteInventoryProductRow](), count: 0, prefix: "")
        }
    }
    func marker(_ parameters: ShopSyncConvergenceMarkerParameters) throws -> Data {
        try beginRequest("marker")
        var succeeded = false; defer { finishRequest(success: succeeded) }
        let c = checkpointValue
        let data = try JSONEncoder().encode(ShopSyncRecoveryConvergenceMarker(schemaVersion: "shop-sync-convergence-marker-v1",
            status: "ready", shopId: c.shopId, scope: c.scope,
            syncEvents: .init(maxId: c.syncEvents.maxId, verifiedBaselineId: parameters.verifiedBaselineID,
                requiresFullRecovery: false, domainMaxIds: c.syncEvents.domainMaxIds), catalog: c.catalog,
            prices: c.prices, history: c.history, images: c.images, integrity: .init(totalViolationCount: 0),
            checkpointDigest: c.checkpointDigest, serverNoWorkEligible: true,
            markerDigest: ShopSyncRecoveryCanonical.sha256("task145-large-marker")))
        succeeded = true; return data
    }
    func armBusinessHold() { businessReleasedForSample = false }
    func waitForBusinessRelease() async throws {
        try beginRequest("catalog-updateProduct")
        guard !businessReleasedForSample else { return }
        guard hold == nil else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        Task144RootObservation.performanceMark("businessRequestHeld", facts: "real-CatalogPushService-updateProduct;deadline45s")
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                hold = continuation
                startHeldRequestDeadline()
            }
        } onCancel: { Task { @MainActor [weak self] in self?.endHold(error: CancellationError()) } }
        try Task.checkCancellation()
    }
    // Controlled server commit, after the UI window released the actual request.
    // Recompute the canonical ordered product digest; prices/history are unchanged.
    // Persistence belongs to the fixture server, never the app's local generation.
    func recordServerProduct(_ product: RemoteInventoryProductRow, extraPrices: [RemoteInventoryProductPriceRow],
                             eventMaxID: Int64, catalogMaxID: Int64, pricesMaxID: Int64) async throws {
        let directory = directory, priorCheckpoint = checkpointValue
        checkpointValue = try await Task.detached(priority: .utility) {
            try Self.updateServerProduct(product, extraPrices: extraPrices, eventMaxID: eventMaxID, catalogMaxID: catalogMaxID,
                pricesMaxID: pricesMaxID, directory: directory, checkpointValue: priorCheckpoint)
        }.value
        priceCursorIndices = try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: directory.appendingPathComponent("price-cursors.json")))
    }
    private nonisolated static func updateServerProduct(_ product: RemoteInventoryProductRow, extraPrices: [RemoteInventoryProductPriceRow],
                                                        eventMaxID: Int64, catalogMaxID: Int64, pricesMaxID: Int64,
                                                        directory: URL, checkpointValue: ShopSyncRecoveryCheckpoint) throws -> ShopSyncRecoveryCheckpoint {
        guard product.id == Task145PerformanceConfiguration.targetID else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        let pageURL = directory.appendingPathComponent("products-19750.json")
        var lastPage = try JSONDecoder().decode([RemoteInventoryProductRow].self, from: Data(contentsOf: pageURL))
        guard let index = lastPage.firstIndex(where: { $0.id == product.id }) else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        lastPage[index] = product
        try JSONEncoder().encode(lastPage).write(to: pageURL, options: .atomic)
        var accumulator = ShopSyncRecoveryDigestAccumulator(hasIdentity: true)
        for start in stride(from: 0, to: 20_000, by: 250) {
            let rows = try JSONDecoder().decode([RemoteInventoryProductRow].self,
                from: Data(contentsOf: directory.appendingPathComponent("products-\(start).json")))
            for row in rows {
                let record = try ShopSyncRecoveryRowContract.product(row, checkpoint: checkpointValue)
                try accumulator.append(orderingID: record.orderingID, idLine: record.idLine,
                    versionLine: record.versionLine, identityLine: record.identityLine, isTombstone: record.isTombstone)
            }
        }
        var allPrices: [UUID: RemoteInventoryProductPriceRow] = [:]
        for start in stride(from: 0, to: checkpointValue.prices.activeCount, by: 250) {
            let rows = try JSONDecoder().decode([RemoteInventoryProductPriceRow].self,
                from: Data(contentsOf: directory.appendingPathComponent("prices-\(start).json")))
            for row in rows { allPrices[row.id] = row }
        }
        for row in extraPrices { allPrices[row.id] = row }
        let orderedPrices = allPrices.values.sorted { $0.id.uuidString.lowercased() < $1.id.uuidString.lowercased() }
        var priceAccumulator = ShopSyncRecoveryDigestAccumulator(), priceCursors: [String: Int] = [:]
        for row in orderedPrices {
            let record = try ShopSyncRecoveryRowContract.price(row, checkpoint: checkpointValue)
            try priceAccumulator.append(orderingID: record.orderingID, idLine: record.idLine,
                versionLine: record.versionLine, identityLine: record.identityLine, isTombstone: record.isTombstone)
        }
        for start in stride(from: 0, to: orderedPrices.count, by: 250) {
            let end = min(start + 250, orderedPrices.count)
            try JSONEncoder().encode(Array(orderedPrices[start..<end])).write(to: directory.appendingPathComponent("prices-\(start).json"), options: .atomic)
            if end < orderedPrices.count { priceCursors[orderedPrices[end - 1].id.uuidString.lowercased()] = end }
        }
        try JSONEncoder().encode(priceCursors).write(to: directory.appendingPathComponent("price-cursors.json"), options: .atomic)
        let products = accumulator.finalize(), old = checkpointValue
        let catalog = ShopSyncRecoveryCatalogDigest(suppliers: old.catalog.suppliers, categories: old.catalog.categories,
            products: products, digest: ShopSyncRecoveryCanonical.sha256(old.catalog.suppliers.versionDigest + "\n"
                + old.catalog.categories.versionDigest + "\n" + products.versionDigest))
        let updated = ShopSyncRecoveryCheckpoint(schemaVersion: old.schemaVersion, shopId: old.shopId, scope: old.scope,
            syncEvents: .init(maxId: String(eventMaxID), verifiedBaselineId: "0", requiresFullRecovery: true,
                domainMaxIds: .init(catalog: String(catalogMaxID), prices: String(pricesMaxID), history: "41")), catalog: catalog,
            prices: priceAccumulator.finalize(), history: old.history, images: old.images, integrity: old.integrity,
            checkpointDigest: ShopSyncRecoveryCanonical.sha256("T20-20261016-v1\n" + String(eventMaxID) + "\n" + catalog.digest))
        try JSONEncoder().encode(updated).write(to: directory.appendingPathComponent("checkpoint.json"), options: .atomic)
        return updated
    }
    func release() { businessReleasedForSample = true; endHold(error: nil) }
    func cancelPending() { endHold(error: CancellationError()) }
    private func endHold(error: Error?) {
        guard let continuation = hold else { return }
        hold = nil; held = false
        Task144RootObservation.performanceMetadata(["responseHeld": "false"])
        // This only releases the artificial response hold. The actual request
        // terminal is recorded by the public method's defer after it returns.
        Task144RootObservation.performanceMark("controlledHoldReleased", facts: error == nil ? "response-released" : "cancel-requested")
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }
}
private nonisolated struct Task145LargePage<Row: Encodable>: Encodable {
    let schemaVersion: String; let shopId: UUID; let scope: ShopSyncRecoveryScope; let domain: ShopSyncRecoveryDomain
    let snapshotEventMaxId: String; let currentScopeEventMaxId: String
    let baselineDomainEventMaxId: String; let pageDomainEventMaxId: String; let domainScope: String
    let pageLimit: Int; let rows: [Row]; let nextAfterId: String?; let hasMore: Bool
}
#endif
