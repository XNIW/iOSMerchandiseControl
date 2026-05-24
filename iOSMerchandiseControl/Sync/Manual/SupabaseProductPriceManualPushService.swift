import CryptoKit
import Foundation
import SwiftData

protocol SupabaseProductPriceManualPushRemoteAccessing: Sendable {
    func insertProductPriceManualPushPayloads(_ payloads: [ProductPriceManualPushPayload]) async throws -> [RemoteInventoryProductPriceRow]
    func fetchProductPricesForManualPushVerificationPage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow]
    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow
}

nonisolated struct ProductPriceManualPushPayload: Encodable, Sendable, Equatable, Identifiable {
    let id: UUID
    let ownerUserID: UUID
    let productID: UUID
    let type: String
    let price: Double
    let priceCanonical: String
    let effectiveAt: String
    let source: String?
    let note: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case productID = "product_id"
        case type
        case price
        case effectiveAt = "effective_at"
        case source
        case note
        case createdAt = "created_at"
    }
}

nonisolated struct ProductPriceManualPushSnapshot: Sendable, Equatable {
    let ownerUserID: UUID
    let dryRunGeneratedAt: Date
    let candidateCount: Int
    let fingerprint: String
    let payloads: [ProductPriceManualPushPayload]

    var abbreviatedFingerprint: String {
        guard fingerprint.count > 12 else {
            return fingerprint
        }
        return "\(fingerprint.prefix(6))...\(fingerprint.suffix(6))"
    }
}

nonisolated struct ProductPriceManualPushResult: Sendable, Equatable {
    let insertedCount: Int
    let verification: ProductPriceManualPushVerificationResult
    let fingerprint: String
    let confirmedRemoteIDs: [UUID]
    let needsTechnicalFollowUp: Bool

    var isVerifiedSuccess: Bool {
        if case .exactMatch = verification {
            return true
        }
        return false
    }

    init(
        insertedCount: Int,
        verification: ProductPriceManualPushVerificationResult,
        fingerprint: String,
        confirmedRemoteIDs: [UUID] = [],
        needsTechnicalFollowUp: Bool = false
    ) {
        self.insertedCount = insertedCount
        self.verification = verification
        self.fingerprint = fingerprint
        self.confirmedRemoteIDs = confirmedRemoteIDs
        self.needsTechnicalFollowUp = needsTechnicalFollowUp
    }
}

nonisolated enum ProductPriceManualPushVerificationResult: Sendable, Equatable {
    case exactMatch(verifiedCount: Int)
    case missingRows([UUID])
    case mismatchedRows([ProductPriceManualPushMismatch])
    case unknown(message: String?)
}

nonisolated struct ProductPriceManualPushMismatch: Sendable, Equatable {
    let id: UUID
    let reason: String
}

nonisolated enum ProductPriceManualPushError: Error, Sendable, Equatable {
    case unsafeDryRun
    case noCandidates
    case overBatchLimit(limit: Int, actual: Int)
    case staleSnapshot
    case invalidPayload
    case uniqueConflict(message: String?)
    case network(message: String?)
    case cancelled
}

nonisolated struct ProductPriceManualPushOptions: Sendable, Equatable {
    static let defaultBatchLimit = 100
    static let defaultReadBackPageSize = 1_000
    static let defaultReadBackMaxPages = 20

    let batchLimit: Int
    let readBackPageSize: Int
    let readBackMaxPages: Int

    init(
        batchLimit: Int = Self.defaultBatchLimit,
        readBackPageSize: Int = Self.defaultReadBackPageSize,
        readBackMaxPages: Int = Self.defaultReadBackMaxPages
    ) {
        self.batchLimit = max(1, min(batchLimit, 100))
        self.readBackPageSize = max(1, min(readBackPageSize, 1_000))
        self.readBackMaxPages = max(1, readBackMaxPages)
    }
}

nonisolated enum ProductPriceManualPushSnapshotFactory {
    private static let namespace = UUID(uuidString: "51000000-0000-4000-8000-000000000051")!

    static func makeSnapshot(
        from plan: ProductPricePushDryRunPlan,
        options: ProductPriceManualPushOptions = ProductPriceManualPushOptions()
    ) throws -> ProductPriceManualPushSnapshot {
        guard plan.isRemoteDedupeSafe,
              plan.summary.blockedTotal == 0,
              plan.summary.conflictSameKeyDifferentPrice == 0,
              plan.summary.localConflictSameKeyDifferentPrice == 0,
              plan.summary.excludedInvalidLocal == 0 else {
            throw ProductPriceManualPushError.unsafeDryRun
        }

        guard !plan.candidates.isEmpty else {
            throw ProductPriceManualPushError.noCandidates
        }

        guard plan.candidates.count <= options.batchLimit else {
            throw ProductPriceManualPushError.overBatchLimit(
                limit: options.batchLimit,
                actual: plan.candidates.count
            )
        }

        let payloads = try plan.candidates.map(makePayload)
            .sorted { lhs, rhs in
                (lhs.productID.uuidString, lhs.type, lhs.effectiveAt, lhs.priceCanonical, lhs.id.uuidString)
                    < (rhs.productID.uuidString, rhs.type, rhs.effectiveAt, rhs.priceCanonical, rhs.id.uuidString)
            }
        let ownerIDs = Set(payloads.map(\.ownerUserID))
        guard ownerIDs.count == 1, let ownerUserID = ownerIDs.first else {
            throw ProductPriceManualPushError.invalidPayload
        }

        return ProductPriceManualPushSnapshot(
            ownerUserID: ownerUserID,
            dryRunGeneratedAt: plan.generatedAt,
            candidateCount: payloads.count,
            fingerprint: fingerprint(payloads: payloads),
            payloads: payloads
        )
    }

    static func isSnapshot(_ snapshot: ProductPriceManualPushSnapshot, currentFor plan: ProductPricePushDryRunPlan) -> Bool {
        guard let current = try? makeSnapshot(from: plan) else {
            return false
        }
        return snapshot.ownerUserID == current.ownerUserID
            && snapshot.dryRunGeneratedAt == current.dryRunGeneratedAt
            && snapshot.candidateCount == current.candidateCount
            && snapshot.fingerprint == current.fingerprint
            && snapshot.payloads == current.payloads
    }

    static func fingerprint(payloads: [ProductPriceManualPushPayload]) -> String {
        let canonical = payloads
            .sorted {
                ($0.productID.uuidString, $0.type, $0.effectiveAt, $0.priceCanonical)
                    < ($1.productID.uuidString, $1.type, $1.effectiveAt, $1.priceCanonical)
            }
            .map {
                [
                    $0.productID.uuidString.lowercased(),
                    $0.type,
                    $0.effectiveAt,
                    $0.priceCanonical
                ].joined(separator: "|")
            }
            .joined(separator: "\n")

        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func makePayload(from line: ProductPricePushDryRunLine) throws -> ProductPriceManualPushPayload {
        guard line.reason == .candidate,
              let payload = line.payload,
              let key = line.key else {
            throw ProductPriceManualPushError.invalidPayload
        }

        let remoteType = payload.remoteType.uppercased()
        guard remoteType == "PURCHASE" || remoteType == "RETAIL" else {
            throw ProductPriceManualPushError.invalidPayload
        }

        let id = deterministicID(
            ownerUserID: payload.ownerUserID,
            productID: payload.productID,
            type: remoteType,
            effectiveAt: payload.effectiveAt
        )
        guard key.ownerUserID == payload.ownerUserID,
              key.productID == payload.productID,
              key.effectiveAt == payload.effectiveAt else {
            throw ProductPriceManualPushError.invalidPayload
        }

        return ProductPriceManualPushPayload(
            id: id,
            ownerUserID: payload.ownerUserID,
            productID: payload.productID,
            type: remoteType,
            price: payload.canonicalPrice.doubleValue,
            priceCanonical: payload.canonicalPrice.value,
            effectiveAt: payload.effectiveAt,
            source: payload.source,
            note: payload.note,
            createdAt: payload.createdAt
        )
    }

    private static func deterministicID(ownerUserID: UUID, productID: UUID, type: String, effectiveAt: String) -> UUID {
        let name = [
            "TASK-051",
            ownerUserID.uuidString.lowercased(),
            productID.uuidString.lowercased(),
            type,
            effectiveAt
        ].joined(separator: "|")
        let namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        var source = Data(namespaceBytes)
        source.append(Data(name.utf8))
        let digest = Insecure.SHA1.hash(data: source)
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            bytes[0],
            bytes[1],
            bytes[2],
            bytes[3],
            bytes[4],
            bytes[5],
            bytes[6],
            bytes[7],
            bytes[8],
            bytes[9],
            bytes[10],
            bytes[11],
            bytes[12],
            bytes[13],
            bytes[14],
            bytes[15]
        ))
    }
}

struct SupabaseProductPriceManualPushService: Sendable {
    private let remote: any SupabaseProductPriceManualPushRemoteAccessing
    private let options: ProductPriceManualPushOptions

    nonisolated init(
        remote: any SupabaseProductPriceManualPushRemoteAccessing,
        options: ProductPriceManualPushOptions = ProductPriceManualPushOptions()
    ) {
        self.remote = remote
        self.options = options
    }

    func push(snapshot: ProductPriceManualPushSnapshot) async throws -> ProductPriceManualPushResult {
        let insertedCount: Int
        do {
            insertedCount = try await insert(snapshot: snapshot)
        } catch let error as ProductPriceManualPushError {
            if case .uniqueConflict = error {
                let verification = try await verify(snapshot: snapshot)
                if case .exactMatch = verification {
                    return ProductPriceManualPushResult(
                        insertedCount: 0,
                        verification: verification,
                        fingerprint: snapshot.fingerprint,
                        confirmedRemoteIDs: Self.confirmedRemoteIDs(for: verification, snapshot: snapshot)
                    )
                }
            }
            throw error
        }
        let verification = try await verify(snapshot: snapshot)
        return ProductPriceManualPushResult(
            insertedCount: insertedCount,
            verification: verification,
            fingerprint: snapshot.fingerprint,
            confirmedRemoteIDs: Self.confirmedRemoteIDs(for: verification, snapshot: snapshot)
        )
    }

    func insert(snapshot: ProductPriceManualPushSnapshot) async throws -> Int {
        try Task.checkCancellation()
        guard snapshot.candidateCount > 0 else {
            throw ProductPriceManualPushError.noCandidates
        }
        guard snapshot.candidateCount <= options.batchLimit else {
            throw ProductPriceManualPushError.overBatchLimit(
                limit: options.batchLimit,
                actual: snapshot.candidateCount
            )
        }

        do {
            _ = try await remote.insertProductPriceManualPushPayloads(snapshot.payloads)
        } catch is CancellationError {
            throw ProductPriceManualPushError.cancelled
        } catch let error as ProductPriceManualPushError {
            throw error
        } catch {
            throw ProductPriceManualPushError.network(message: safeDiagnosticDetail(for: error))
        }

        try Task.checkCancellation()
        return snapshot.payloads.count
    }

    func verify(snapshot: ProductPriceManualPushSnapshot) async throws -> ProductPriceManualPushVerificationResult {
        let productIDs = Array(Set(snapshot.payloads.map(\.productID))).sorted { $0.uuidString < $1.uuidString }
        let expectedIDs = Set(snapshot.payloads.map(\.id))
        var rows: [RemoteInventoryProductPriceRow] = []
        var offset = 0

        do {
            for _ in 0..<options.readBackMaxPages {
                try Task.checkCancellation()
                let page = try await remote.fetchProductPricesForManualPushVerificationPage(
                    ownerUserID: snapshot.ownerUserID,
                    productIDs: productIDs,
                    from: offset,
                    to: offset + options.readBackPageSize - 1
                )
                try Task.checkCancellation()
                rows.append(contentsOf: page)

                if page.count < options.readBackPageSize {
                    return exactMatch(snapshot: snapshot, rows: rows)
                }
                if expectedIDs.isSubset(of: Set(rows.map(\.id))) {
                    return exactMatch(snapshot: snapshot, rows: rows)
                }
                offset += options.readBackPageSize
            }

            return .unknown(message: "read-back page budget exceeded")
        } catch is CancellationError {
            throw ProductPriceManualPushError.cancelled
        } catch {
            return .unknown(message: safeDiagnosticDetail(for: error))
        }
    }

    private func exactMatch(
        snapshot: ProductPriceManualPushSnapshot,
        rows: [RemoteInventoryProductPriceRow]
    ) -> ProductPriceManualPushVerificationResult {
        let rowsByID = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var missing: [UUID] = []
        var mismatches: [ProductPriceManualPushMismatch] = []

        for payload in snapshot.payloads {
            guard let row = rowsByID[payload.id] else {
                missing.append(payload.id)
                continue
            }

            mismatches.append(contentsOf: mismatchesFor(payload: payload, row: row))
        }

        if !missing.isEmpty {
            return .missingRows(missing.sorted { $0.uuidString < $1.uuidString })
        }
        if !mismatches.isEmpty {
            return .mismatchedRows(mismatches)
        }
        return .exactMatch(verifiedCount: snapshot.payloads.count)
    }

    private static func confirmedRemoteIDs(
        for verification: ProductPriceManualPushVerificationResult,
        snapshot: ProductPriceManualPushSnapshot
    ) -> [UUID] {
        guard case .exactMatch = verification else { return [] }
        return snapshot.payloads.map(\.id)
    }

    private func mismatchesFor(
        payload: ProductPriceManualPushPayload,
        row: RemoteInventoryProductPriceRow
    ) -> [ProductPriceManualPushMismatch] {
        var mismatches: [ProductPriceManualPushMismatch] = []
        let normalizedRemoteType = SupabasePullPreviewNormalizer.normalizedPriceType(row.type)?.uppercased()
        let remotePrice = PriceCanonicalizer.canonicalAmount(from: row.price)
        let remoteEffectiveAt = ProductPriceEffectiveAtCanonicalizer
            .canonicalDate(from: row.effectiveAt)
            .map(ProductPriceEffectiveAtCanonicalizer.canonicalString)
        let remoteCreatedAt = ProductPriceEffectiveAtCanonicalizer
            .canonicalDate(from: row.createdAt)
            .map(ProductPriceEffectiveAtCanonicalizer.canonicalString)
        let remoteSource = SupabasePullPreviewNormalizer.semanticString(row.source)
        let remoteNote = SupabasePullPreviewNormalizer.semanticString(row.note)

        func append(_ condition: Bool, _ reason: String) {
            if !condition {
                mismatches.append(ProductPriceManualPushMismatch(id: payload.id, reason: reason))
            }
        }

        append(row.ownerUserID == payload.ownerUserID, "owner_user_id")
        append(row.productID == payload.productID, "product_id")
        append(normalizedRemoteType == payload.type, "type")
        append(remotePrice?.value == payload.priceCanonical, "price")
        append(remoteEffectiveAt == payload.effectiveAt, "effective_at")
        append(remoteCreatedAt == payload.createdAt, "created_at")
        append(remoteSource == payload.source, "source")
        append(remoteNote == payload.note, "note")

        return mismatches
    }

    private func safeDiagnosticDetail(for error: Error) -> String? {
        if let serviceError = error as? SupabaseTransportClientError {
            return serviceError.safeDiagnosticDetail
        }
        return SupabaseTransportClientError.sanitizedDiagnosticDetail(String(describing: error))
            ?? "inventory_product_prices"
    }
}

@MainActor
struct ProductPriceCoveredProductChangeReconciler {
    private static let productPriceFieldNames: Set<String> = [
        "purchaseprice",
        "retailprice"
    ]

    func syncRemoteProductsAndAcknowledgeCoveredProductPriceFieldChanges(
        payloads: [ProductPriceManualPushPayload],
        ownerUserID: UUID,
        remote: any SupabaseProductPriceManualPushRemoteAccessing,
        context: ModelContext
    ) async throws -> Int {
        guard !payloads.isEmpty else { return 0 }

        let owner = ownerUserID.uuidString.lowercased()
        let productIDs = Set(payloads.map { $0.productID.uuidString.lowercased() })
        let productsByRemoteID = Dictionary(
            try context.fetch(FetchDescriptor<Product>())
                .compactMap { product -> (String, Product)? in
                    guard let remoteID = product.remoteID?.uuidString.lowercased() else { return nil }
                    return (remoteID, product)
                },
            uniquingKeysWith: { first, _ in first }
        )
        let timestamp = Date()
        var acknowledged = 0

        for change in try pendingProductPriceOnlyChanges(owner: owner, context: context) {
            guard isProductPriceOnlyChange(change),
                  let remoteID = change.entityRemoteID?.uuidString.lowercased(),
                  productIDs.contains(remoteID),
                  let product = productsByRemoteID[remoteID],
                  let productRemoteID = product.remoteID,
                  isCoveredByLinkedProductPrice(change, product: product),
                  let payload = productUpdatePayload(for: change, product: product) else {
                continue
            }
            let updated = try await remote.updateProduct(id: productRemoteID, payload: payload)
            guard updated.id == productRemoteID,
                  updated.ownerUserID == ownerUserID,
                  remoteProductMatchesPriceFields(updated, change: change, product: product) else {
                throw ProductPriceManualPushError.network(message: "product price mirror verification failed")
            }
            product.remoteUpdatedAt = SupabaseRemoteDateParser.parse(updated.updatedAt)
            product.remoteDeletedAt = SupabaseRemoteDateParser.parse(updated.deletedAt)
            change.status = .acknowledged
            change.updatedAt = timestamp
            acknowledged += 1
        }

        if acknowledged > 0 {
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
        return acknowledged
    }

    private func pendingProductPriceOnlyChanges(
        owner: String,
        context: ModelContext
    ) throws -> [LocalPendingChange] {
        let productKind = LocalPendingChangeEntityKind.product.rawValue
        let pendingStatus = LocalPendingChangeStatus.pending.rawValue
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
                    && change.entityKindRaw == productKind
                    && change.statusRaw == pendingStatus
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
        )
        return try context.fetch(descriptor).filter(isProductPriceOnlyChange)
    }

    private func isProductPriceOnlyChange(_ change: LocalPendingChange) -> Bool {
        let fields = change.changedFields.map {
            $0.replacingOccurrences(of: "_", with: "").lowercased()
        }
        guard !fields.isEmpty else { return false }
        return fields.allSatisfy { field in
            Self.productPriceFieldNames.contains(field)
        }
    }

    private func isCoveredByLinkedProductPrice(_ change: LocalPendingChange, product: Product) -> Bool {
        let fields = Set(change.changedFields.map {
            $0.replacingOccurrences(of: "_", with: "").lowercased()
        })
        if fields.contains("purchaseprice"),
           !isLatestLinkedPrice(product: product, type: .purchase, amount: product.purchasePrice) {
            return false
        }
        if fields.contains("retailprice"),
           !isLatestLinkedPrice(product: product, type: .retail, amount: product.retailPrice) {
            return false
        }
        return true
    }

    private func productUpdatePayload(
        for change: LocalPendingChange,
        product: Product
    ) -> SupabaseManualPushProductUpdatePayload? {
        let fields = Set(change.changedFields.map {
            $0.replacingOccurrences(of: "_", with: "").lowercased()
        })
        let purchasePrice = fields.contains("purchaseprice") ? product.purchasePrice : nil
        let retailPrice = fields.contains("retailprice") ? product.retailPrice : nil
        guard purchasePrice != nil || retailPrice != nil else { return nil }
        return SupabaseManualPushProductUpdatePayload(
            barcode: nil,
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil
        )
    }

    private func remoteProductMatchesPriceFields(
        _ row: RemoteInventoryProductRow,
        change: LocalPendingChange,
        product: Product
    ) -> Bool {
        let fields = Set(change.changedFields.map {
            $0.replacingOccurrences(of: "_", with: "").lowercased()
        })
        if fields.contains("purchaseprice"),
           !canonicalAmountsMatch(row.purchasePrice, product.purchasePrice) {
            return false
        }
        if fields.contains("retailprice"),
           !canonicalAmountsMatch(row.retailPrice, product.retailPrice) {
            return false
        }
        return true
    }

    private func canonicalAmountsMatch(_ lhs: Double?, _ rhs: Double?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        return PriceCanonicalizer.canonicalAmount(from: lhs)?.value
            == PriceCanonicalizer.canonicalAmount(from: rhs)?.value
    }

    private func isLatestLinkedPrice(product: Product, type: PriceType, amount: Double?) -> Bool {
        guard let amount,
              let expected = PriceCanonicalizer.canonicalAmount(from: amount)?.value else {
            return false
        }
        let latest = product.priceHistory
            .filter { $0.type == type }
            .sorted {
                if $0.effectiveAt != $1.effectiveAt {
                    return $0.effectiveAt > $1.effectiveAt
                }
                return $0.createdAt > $1.createdAt
            }
            .first
        guard let latest,
              latest.remoteID != nil,
              let actual = PriceCanonicalizer.canonicalAmount(from: latest.price)?.value else {
            return false
        }
        return actual == expected
    }
}

@MainActor
struct ProductPriceManualPushIdentityReconciler {
    func linkVerifiedPayloads(
        _ payloads: [ProductPriceManualPushPayload],
        context: ModelContext
    ) throws -> Int {
        guard !payloads.isEmpty else {
            return 0
        }

        let keyedPayloads = payloads.map { (key(for: $0), $0) }
        guard Set(keyedPayloads.map(\.0)).count == payloads.count else {
            throw ProductPriceManualPushError.invalidPayload
        }
        let payloadsByKey = Dictionary(uniqueKeysWithValues: keyedPayloads)
        let prices = try context.fetch(
            FetchDescriptor<ProductPrice>(
                sortBy: [
                    SortDescriptor(\ProductPrice.effectiveAt),
                    SortDescriptor(\ProductPrice.createdAt)
                ]
            )
        )
        var candidatesByKey: [PayloadKey: [ProductPrice]] = [:]

        for price in prices where price.remoteID == nil {
            guard let key = key(for: price),
                  payloadsByKey[key] != nil else {
                continue
            }
            candidatesByKey[key, default: []].append(price)
        }

        var links: [(price: ProductPrice, remoteID: UUID)] = []
        for key in payloadsByKey.keys.sorted() {
            guard let payload = payloadsByKey[key],
                  let matches = candidatesByKey[key],
                  matches.count == 1,
                  let price = matches.first else {
                throw ProductPriceManualPushError.network(
                    message: "product price identity reconciliation incomplete"
                )
            }
            links.append((price, payload.id))
        }

        for link in links {
            link.price.remoteID = link.remoteID
        }

        if !links.isEmpty {
            do {
                try context.save()
            } catch {
                context.rollback()
                throw ProductPriceManualPushError.network(
                    message: SupabaseTransportClientError.sanitizedDiagnosticDetail(String(describing: error))
                        ?? "product price identity"
                )
            }
        }

        return links.count
    }

    private func key(for payload: ProductPriceManualPushPayload) -> PayloadKey {
        PayloadKey(
            productID: payload.productID,
            type: payload.type.lowercased(),
            priceCanonical: payload.priceCanonical,
            effectiveAt: payload.effectiveAt,
            source: payload.source,
            note: payload.note
        )
    }

    private func key(for price: ProductPrice) -> PayloadKey? {
        guard let productID = price.product?.remoteID,
              let type = SupabasePullPreviewNormalizer.normalizedPriceType(price.type.rawValue),
              let priceCanonical = PriceCanonicalizer.canonicalAmount(from: price.price)?.value else {
            return nil
        }
        return PayloadKey(
            productID: productID,
            type: type,
            priceCanonical: priceCanonical,
            effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt),
            source: SupabasePullPreviewNormalizer.semanticString(price.source),
            note: SupabasePullPreviewNormalizer.semanticString(price.note)
        )
    }

    private struct PayloadKey: Hashable, Comparable {
        let productID: UUID
        let type: String
        let priceCanonical: String
        let effectiveAt: String
        let source: String?
        let note: String?

        var stableID: String {
            [
                productID.uuidString.lowercased(),
                type,
                priceCanonical,
                effectiveAt,
                source ?? "",
                note ?? ""
            ].joined(separator: "|")
        }

        static func < (lhs: PayloadKey, rhs: PayloadKey) -> Bool {
            lhs.stableID < rhs.stableID
        }
    }
}
