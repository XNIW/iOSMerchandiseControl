import Foundation

extension SyncEventOutboxProducerOutcome {
    static func catalogManualPush(
        result: SupabaseManualPushResult,
        ownerUserID: UUID?,
        currentOwnerUserID: UUID?,
        planFingerprint: String?,
        sourceDeviceID: String? = nil
    ) -> SyncEventOutboxProducerOutcome {
        .catalogManualPush(
            CatalogManualPush(
                ownerUserID: ownerUserID?.uuidString.lowercased(),
                currentOwnerUserID: currentOwnerUserID?.uuidString.lowercased(),
                terminalStatus: SyncEventOutboxProducerTerminalStatus(result.status),
                suppliersConfirmed: result.supplierCreates + result.supplierUpdates + result.supplierLinks,
                categoriesConfirmed: result.categoryCreates + result.categoryUpdates + result.categoryLinks,
                productsConfirmed: result.productCreates + result.productUpdates + result.productLinks,
                clientEventID: Self.clientEventID(prefix: "catalog-manual-push", fingerprint: planFingerprint),
                sourceDeviceID: sourceDeviceID,
                validationEntityIDs: result.touchedIDs.isEmpty ? nil : result.touchedIDs.syncEventEntityIDs
            )
        )
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
        let entityIDs: SyncEventJSONValue? = result.confirmedRemoteIDs.isEmpty ? nil : .object([
            "price_ids": .array(
                result.confirmedRemoteIDs
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
