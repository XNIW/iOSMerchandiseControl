import Foundation
import SwiftData

nonisolated struct AccountStoreReplacementResult: Equatable, Sendable {
    let deletedProducts: Int
    let deletedSuppliers: Int
    let deletedCategories: Int
    let deletedProductPrices: Int
    let deletedHistorySessions: Int
    let deletedOutboxEntries: Int
    let deletedBaselineRows: Int
}

nonisolated struct AccountStoreReplacementIntent: Equatable, Sendable {
    let accountHash: String
    let storeIdentity: LocalStoreIdentity
}

nonisolated enum AccountStoreReplacementError: LocalizedError, Equatable {
    case replacementJournalUnavailable

    var errorDescription: String? {
        switch self {
        case .replacementJournalUnavailable:
            return "The local replacement could not be prepared safely."
        }
    }
}

@MainActor
struct AccountStoreReplacementCoordinator {
    private let bindingStore: AccountBindingStore

    init(
        context _: ModelContext,
        bindingStore: AccountBindingStore = AccountBindingStore()
    ) {
        self.bindingStore = bindingStore
    }

    /// Call only after the dedicated owner/store native dialog has received
    /// the user's explicit cloud-replacement choice. The choice authorizes an
    /// atomic generation recovery; it does not mutate the active store here.
    func discardLocalDataAndBind(
        userID: UUID,
        storeIdentity: LocalStoreIdentity
    ) throws -> AccountStoreReplacementResult {
        let intent = try prepareReplacement(
            userID: userID,
            storeIdentity: storeIdentity
        )
        return try discardPreparedLocalDataAndBind(intent)
    }

    /// Writes the durable fail-closed marker while process-wide sync admission
    /// is quiesced. Download and validation happen in a separate generation.
    func prepareReplacement(
        userID: UUID,
        storeIdentity: LocalStoreIdentity
    ) throws -> AccountStoreReplacementIntent {
        let accountHash = AccountBindingStore.accountHash(for: userID)
        guard bindingStore.beginReplacement(
            accountHash: accountHash,
            storeIdentity: storeIdentity,
            allowsCorruptJournalRepair: true,
            allowsSameScopeDestructivePromotion: true
        ) else {
            throw AccountStoreReplacementError.replacementJournalUnavailable
        }
        return AccountStoreReplacementIntent(
            accountHash: accountHash,
            storeIdentity: storeIdentity
        )
    }

    func discardPreparedLocalDataAndBind(
        _ intent: AccountStoreReplacementIntent
    ) throws -> AccountStoreReplacementResult {
        guard let recovery = bindingStore.pendingRecoveryJournal,
              recovery.mode == .accountOrShopReplacement,
              recovery.phase == .prepared,
              recovery.replacement.accountHash == intent.accountHash,
              recovery.replacement.storeIdentity == intent.storeIdentity else {
            throw AccountStoreReplacementError.replacementJournalUnavailable
        }
        // The destructive tap authorizes the existing owner-safe recovery
        // transaction. No active SwiftData row, binding, watermark, outbox or
        // image is touched until a verified generation is atomically activated.
        return AccountStoreReplacementResult(
            deletedProducts: 0,
            deletedSuppliers: 0,
            deletedCategories: 0,
            deletedProductPrices: 0,
            deletedHistorySessions: 0,
            deletedOutboxEntries: 0,
            deletedBaselineRows: 0
        )
    }

}
