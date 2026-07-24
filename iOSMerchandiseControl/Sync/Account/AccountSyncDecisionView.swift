import SwiftUI

enum AccountSyncUserChoice: Equatable, Sendable {
    case merge
    case replaceLocalWithCloud
    case uploadLocalToCloud
    case exportAndCancel
    case switchStore
    case createStoreAndPull
    case keepLocalData
    case discardLocalAndBind
    case cancel
}

nonisolated enum AccountSyncDecisionDialogPolicy {
    static func authenticatedUserID(
        isSignedIn: Bool,
        isTransitioning: Bool,
        sessionInfo: SupabaseAuthSessionInfo?
    ) -> UUID? {
        guard isSignedIn,
              !isTransitioning,
              let sessionInfo,
              !sessionInfo.isExpired else {
            return nil
        }
        return sessionInfo.userID
    }

    static func allowsCloudReplacement(for decision: AccountSyncDecision) -> Bool {
        guard case .promptOwnerStoreReview(let reason) = decision.action else {
            return false
        }
        switch reason {
        case .unboundDirty,
             .accountMismatch,
             .shopMismatch,
             .bindingMetadataMismatch,
             .replacementInterrupted:
            return true
        case .localStateUnavailable,
             .shopContextUnavailable:
            return false
        }
    }

    static func presentationIdentity(
        decision: AccountSyncDecision,
        currentAccountHash: String?,
        activeStoreIdentity: LocalStoreIdentity,
        currentBinding: AccountBinding?,
        pendingReplacement: AccountBinding?
    ) -> String {
        let components = [
            decision.testID,
            currentAccountHash ?? "signed-out",
            storeIdentityComponent(activeStoreIdentity),
            bindingComponent(currentBinding),
            bindingComponent(pendingReplacement)
        ]
        return AccountBindingStore.redactedAccountHash(for: components.joined(separator: "|"))
    }

    static func shouldPresentAutomatically(
        identity: String?,
        alreadyPresented: Set<String>
    ) -> Bool {
        guard let identity else { return false }
        return !alreadyPresented.contains(identity)
    }

    static func canPresentManually(identity: String?) -> Bool {
        identity != nil
    }

    static func replacementTarget(
        for decision: AccountSyncDecision,
        isShopResolutionReady: Bool,
        selectedStoreIdentity: LocalStoreIdentity?
    ) -> LocalStoreIdentity? {
        guard allowsCloudReplacement(for: decision),
              isShopResolutionReady,
              let selectedStoreIdentity,
              selectedStoreIdentity != .anonymous else {
            return nil
        }
        return selectedStoreIdentity
    }

    static func isCloudReplacementEnabled(
        for decision: AccountSyncDecision,
        hasAuthenticatedAccount: Bool,
        isShopResolutionReady: Bool,
        selectedStoreIdentity: LocalStoreIdentity?
    ) -> Bool {
        guard hasAuthenticatedAccount else { return false }
        return replacementTarget(
            for: decision,
            isShopResolutionReady: isShopResolutionReady,
            selectedStoreIdentity: selectedStoreIdentity
        ) != nil
    }

    private static func bindingComponent(_ binding: AccountBinding?) -> String {
        guard let binding else { return "none" }
        return "\(binding.accountHash):\(storeIdentityComponent(binding.storeIdentity))"
    }

    private static func storeIdentityComponent(_ identity: LocalStoreIdentity) -> String {
        [
            identity.storeId,
            identity.localStoreId,
            String(identity.schemaVersion),
            String(identity.syncProtocolVersion),
            String(identity.storeEpoch)
        ].joined(separator: ":")
    }
}

private struct AccountSyncDecisionDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let decision: AccountSyncDecision?
    let isCloudReplacementEnabled: Bool
    let onChoose: (AccountSyncUserChoice) -> Void

    func body(content: Content) -> some View {
        content.alert(
            L("options.accountDecision.choice.title"),
            isPresented: $isPresented,
            presenting: decision
        ) { decision in
            Button(L("options.accountDecision.choice.keepLocal"), role: .cancel) {
                onChoose(.keepLocalData)
            }
            Button(L("options.accountDecision.choice.replaceWithCloud"), role: .destructive) {
                onChoose(.discardLocalAndBind)
            }
            .disabled(!isCloudReplacementEnabled)
        } message: { _ in
            Text(L("options.accountDecision.choice.detail"))
        }
    }
}

extension View {
    func accountSyncDecisionDialog(
        isPresented: Binding<Bool>,
        decision: AccountSyncDecision?,
        isCloudReplacementEnabled: Bool,
        onChoose: @escaping (AccountSyncUserChoice) -> Void
    ) -> some View {
        modifier(AccountSyncDecisionDialogModifier(
            isPresented: isPresented,
            decision: decision,
            isCloudReplacementEnabled: isCloudReplacementEnabled,
            onChoose: onChoose
        ))
    }
}
