import SwiftUI

enum AccountSyncUserChoice: Equatable, Sendable {
    case merge
    case replaceLocalWithCloud
    case uploadLocalToCloud
    case exportAndCancel
    case switchStore
    case createStoreAndPull
    case cancel
}

struct AccountSyncDecisionView: View {
    let decision: AccountSyncDecision
    let localSummary: LocalDatabasePublicSummary
    let onChoose: (AccountSyncUserChoice) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.headline)
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(.orange)
                    }
                }

                Section(L("options.accountDecision.local.header")) {
                    LabeledContent(L("options.localDatabase.products"), value: "\(localSummary.products)")
                    LabeledContent(L("options.localDatabase.suppliers"), value: "\(localSummary.suppliers)")
                    LabeledContent(L("options.localDatabase.categories"), value: "\(localSummary.categories)")
                    LabeledContent(L("options.localDatabase.prices"), value: "\(localSummary.productPrices)")
                    LabeledContent(L("options.localDatabase.historySessions"), value: "\(localSummary.historySessions)")
                }

                Section {
                    ForEach(actions, id: \.choice) { action in
                        Button {
                            onChoose(action.choice)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                        .disabled(action.isDisabled)
                    }
                } header: {
                    Text(L("options.accountDecision.actions.header"))
                } footer: {
                    Text(L("options.accountDecision.footer"))
                }
            }
            .navigationTitle(L("options.accountDecision.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) {
                        onChoose(.cancel)
                    }
                }
            }
        }
    }

    private var title: String {
        switch decision.action {
        case .promptBootstrapUpload:
            return L("options.accountDecision.bootstrap.title")
        case .promptMergeReplaceUploadExportCancel:
            return L("options.accountDecision.merge.title")
        case .promptRemoteVerification:
            return L("options.accountDecision.verify.title")
        case .promptSwitchStoreOrCreateStore:
            return L("options.accountDecision.switch.title")
        case .noOp,
             .pushPendingDrainEventsLightReconcile,
             .markConflictStale,
             .applyRemoteTombstone,
             .dedupeHistoryFingerprint,
             .useRemoteOrdering,
             .drainEventsLightReconcile,
             .keepAnonymousOrPreviousOwnerBound:
            return L("options.accountDecision.title")
        }
    }

    private var detail: String {
        switch decision.action {
        case .promptBootstrapUpload:
            return L("options.accountDecision.bootstrap.detail")
        case .promptMergeReplaceUploadExportCancel:
            return L("options.accountDecision.merge.detail")
        case .promptRemoteVerification:
            return L("options.accountDecision.verify.detail")
        case .promptSwitchStoreOrCreateStore:
            return L("options.accountDecision.switch.detail")
        case .noOp,
             .pushPendingDrainEventsLightReconcile,
             .markConflictStale,
             .applyRemoteTombstone,
             .dedupeHistoryFingerprint,
             .useRemoteOrdering,
             .drainEventsLightReconcile,
             .keepAnonymousOrPreviousOwnerBound:
            return L("options.accountDecision.generic.detail")
        }
    }

    private var actions: [ActionRow] {
        switch decision.action {
        case .promptBootstrapUpload:
            return [
                ActionRow(choice: .uploadLocalToCloud, title: L("options.accountDecision.action.upload"), systemImage: "icloud.and.arrow.up"),
                ActionRow(choice: .exportAndCancel, title: L("options.accountDecision.action.exportCancel"), systemImage: "square.and.arrow.up"),
                ActionRow(choice: .cancel, title: L("common.cancel"), systemImage: "xmark.circle")
            ]
        case .promptMergeReplaceUploadExportCancel:
            return [
                ActionRow(choice: .merge, title: L("options.accountDecision.action.merge"), systemImage: "arrow.triangle.merge"),
                ActionRow(choice: .replaceLocalWithCloud, title: L("options.accountDecision.action.replace"), systemImage: "icloud.and.arrow.down"),
                ActionRow(choice: .uploadLocalToCloud, title: L("options.accountDecision.action.upload"), systemImage: "icloud.and.arrow.up"),
                ActionRow(choice: .exportAndCancel, title: L("options.accountDecision.action.exportCancel"), systemImage: "square.and.arrow.up"),
                ActionRow(choice: .cancel, title: L("common.cancel"), systemImage: "xmark.circle")
            ]
        case .promptRemoteVerification:
            return [
                ActionRow(choice: .cancel, title: L("options.accountDecision.action.verifyFirst"), systemImage: "checkmark.shield", isDisabled: true),
                ActionRow(choice: .exportAndCancel, title: L("options.accountDecision.action.exportCancel"), systemImage: "square.and.arrow.up"),
                ActionRow(choice: .cancel, title: L("common.cancel"), systemImage: "xmark.circle")
            ]
        case .promptSwitchStoreOrCreateStore:
            return [
                ActionRow(choice: .switchStore, title: L("options.accountDecision.action.switchStore"), systemImage: "externaldrive.connected.to.line.below"),
                ActionRow(choice: .createStoreAndPull, title: L("options.accountDecision.action.createStore"), systemImage: "icloud.and.arrow.down"),
                ActionRow(choice: .cancel, title: L("common.cancel"), systemImage: "xmark.circle")
            ]
        case .noOp,
             .pushPendingDrainEventsLightReconcile,
             .markConflictStale,
             .applyRemoteTombstone,
             .dedupeHistoryFingerprint,
             .useRemoteOrdering,
             .drainEventsLightReconcile,
             .keepAnonymousOrPreviousOwnerBound:
            return [
                ActionRow(choice: .cancel, title: L("common.cancel"), systemImage: "xmark.circle")
            ]
        }
    }

    private struct ActionRow {
        let choice: AccountSyncUserChoice
        let title: String
        let systemImage: String
        var isDisabled: Bool = false
    }
}
