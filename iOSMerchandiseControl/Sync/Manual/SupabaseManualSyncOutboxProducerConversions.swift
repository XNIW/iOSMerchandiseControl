import Foundation

extension SyncEventOutboxProducerOutcome {
    static func catalogManualPush(
        result: SupabaseManualPushResult,
        ownerUserID: UUID?,
        currentOwnerUserID: UUID?,
        planFingerprint: String?,
        sourceDeviceID: String? = nil
    ) -> SyncEventOutboxProducerOutcome {
        catalogManualPushOutcomes(
            result: result,
            ownerUserID: ownerUserID,
            currentOwnerUserID: currentOwnerUserID,
            planFingerprint: planFingerprint,
            sourceDeviceID: sourceDeviceID
        ).first ?? .unsupported(source: "catalog_manual_push_empty")
    }

    static func catalogManualPushOutcomes(
        result: SupabaseManualPushResult,
        ownerUserID: UUID?,
        currentOwnerUserID: UUID?,
        planFingerprint: String?,
        sourceDeviceID: String? = nil
    ) -> [SyncEventOutboxProducerOutcome] {
        let terminalStatus = SyncEventOutboxProducerTerminalStatus(result.status)
        let changedIDs = SupabaseManualPushTouchedIDs(
            suppliers: result.touchedIDs.suppliers.subtracting(result.tombstoneIDs.suppliers),
            categories: result.touchedIDs.categories.subtracting(result.tombstoneIDs.categories),
            products: result.touchedIDs.products.subtracting(result.tombstoneIDs.products)
        )
        let changedCount = changedIDs.suppliers.count + changedIDs.categories.count + changedIDs.products.count
        let tombstoneCount = result.tombstoneIDs.suppliers.count
            + result.tombstoneIDs.categories.count
            + result.tombstoneIDs.products.count
        let baseClientEventID = Self.clientEventID(
            prefix: "catalog-manual-push",
            fingerprint: planFingerprint
        )
        let isMixed = changedCount > 0 && tombstoneCount > 0
        var outcomes: [SyncEventOutboxProducerOutcome] = []

        if changedCount > 0 {
            outcomes.append(.catalogManualPush(
                CatalogManualPush(
                    ownerUserID: ownerUserID?.uuidString.lowercased(),
                    currentOwnerUserID: currentOwnerUserID?.uuidString.lowercased(),
                    terminalStatus: terminalStatus,
                    eventType: "catalog_changed",
                    suppliersConfirmed: changedIDs.suppliers.count,
                    categoriesConfirmed: changedIDs.categories.count,
                    productsConfirmed: changedIDs.products.count,
                    clientEventID: isMixed ? baseClientEventID.map { "\($0):changed" } : baseClientEventID,
                    sourceDeviceID: sourceDeviceID,
                    validationEntityIDs: changedIDs.syncEventEntityIDs
                )
            ))
        }

        if tombstoneCount > 0 {
            outcomes.append(.catalogManualPush(
                CatalogManualPush(
                    ownerUserID: ownerUserID?.uuidString.lowercased(),
                    currentOwnerUserID: currentOwnerUserID?.uuidString.lowercased(),
                    terminalStatus: terminalStatus,
                    eventType: "catalog_tombstone",
                    suppliersConfirmed: result.tombstoneIDs.suppliers.count,
                    categoriesConfirmed: result.tombstoneIDs.categories.count,
                    productsConfirmed: result.tombstoneIDs.products.count,
                    clientEventID: isMixed ? baseClientEventID.map { "\($0):tombstone" } : baseClientEventID,
                    sourceDeviceID: sourceDeviceID,
                    validationEntityIDs: result.tombstoneIDs.syncEventEntityIDs
                )
            ))
        }

        if outcomes.isEmpty {
            outcomes.append(.catalogManualPush(
                CatalogManualPush(
                ownerUserID: ownerUserID?.uuidString.lowercased(),
                currentOwnerUserID: currentOwnerUserID?.uuidString.lowercased(),
                terminalStatus: terminalStatus,
                suppliersConfirmed: 0,
                categoriesConfirmed: 0,
                productsConfirmed: 0,
                clientEventID: baseClientEventID,
                sourceDeviceID: sourceDeviceID,
                validationEntityIDs: nil
            )
            ))
        }

        return outcomes
    }

    static func productPriceManualPush(
        result: ProductPriceManualPushResult,
        ownerUserID: UUID?,
        currentOwnerUserID: UUID?,
        sourceDeviceID: String? = nil
    ) -> SyncEventOutboxProducerOutcome {
        let terminalStatus: SyncEventOutboxProducerTerminalStatus
        let confirmedRows: Int
        switch result.verification {
        case .exactMatch(let verifiedCount):
            terminalStatus = .completed
            confirmedRows = verifiedCount
        case .missingRows, .mismatchedRows, .unknown:
            terminalStatus = .failedPreflight
            confirmedRows = 0
        }
        let entityIDs: SyncEventJSONValue = .object([
            "price_ids": .array(
                result.confirmedRemoteIDs
                    .sorted { $0.uuidString < $1.uuidString }
                    .map { .string($0.uuidString.lowercased()) }
            ),
            "product_ids": .array(
                result.confirmedProductIDs
                    .sorted { $0.uuidString < $1.uuidString }
                    .map { .string($0.uuidString.lowercased()) }
            )
        ])

        return .productPriceManualPush(
            ProductPriceManualPush(
                ownerUserID: ownerUserID?.uuidString.lowercased(),
                currentOwnerUserID: currentOwnerUserID?.uuidString.lowercased(),
                terminalStatus: terminalStatus,
                confirmedPriceRows: confirmedRows,
                clientEventID: Self.clientEventID(prefix: "prices-manual-push", fingerprint: result.fingerprint),
                sourceDeviceID: sourceDeviceID,
                validationEntityIDs: entityIDs
            )
        )
    }

    static func catalogGeneratedProductPrices(
        priceIDs: [UUID],
        productIDs: [UUID],
        ownerUserID: UUID?,
        currentOwnerUserID: UUID?,
        planFingerprint: String?,
        sourceDeviceID: String? = nil
    ) -> SyncEventOutboxProducerOutcome {
        let sortedPriceIDs = priceIDs
            .sorted { $0.uuidString < $1.uuidString }
        let sortedProductIDs = productIDs
            .sorted { $0.uuidString < $1.uuidString }
        let fingerprint = [
            planFingerprint ?? "",
            sortedPriceIDs.map { $0.uuidString.lowercased() }.joined(separator: ",")
        ].joined(separator: "|")

        return .catalogGeneratedProductPrices(
            CatalogGeneratedProductPrices(
                ownerUserID: ownerUserID?.uuidString.lowercased(),
                currentOwnerUserID: currentOwnerUserID?.uuidString.lowercased(),
                terminalStatus: .completed,
                confirmedPriceRows: sortedPriceIDs.count,
                productCount: sortedProductIDs.count,
                clientEventID: Self.clientEventID(prefix: "catalog-generated-prices", fingerprint: fingerprint),
                sourceDeviceID: sourceDeviceID,
                validationEntityIDs: .object([
                    "price_ids": .array(
                        sortedPriceIDs.map { .string($0.uuidString.lowercased()) }
                    ),
                    "product_ids": .array(
                        sortedProductIDs.map { .string($0.uuidString.lowercased()) }
                    )
                ]),
                validationMetadata: .object([
                    "source": .string("ios"),
                    "product_count": .number(Double(sortedProductIDs.count))
                ])
            )
        )
    }
}

private extension SyncEventOutboxProducerTerminalStatus {
    init(_ status: SupabaseManualPushTerminalStatus) {
        switch status {
        case .completed:
            self = .completed
        case .completedBaselineRefreshFailed:
            self = .completedBaselineRefreshFailed
        case .partial:
            self = .partial
        case .failedBeforeWrite, .blockedBeforeWrite:
            self = .failedPreflight
        }
    }
}
