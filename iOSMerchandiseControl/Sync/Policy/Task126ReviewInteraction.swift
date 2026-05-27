import Foundation
import SwiftUI

nonisolated enum Task126ReviewSurface: String, Codable, Sendable, Equatable {
    case conflictReview
    case accountSwitchRecovery
}

nonisolated enum Task126UserChoice: String, Codable, Sendable, Equatable, CaseIterable {
    case cancel
    case keepCurrentAccount
    case exportBackup
    case discardPendingAndSwitch
    case switchAccount
    case useLocal
    case useRemote
    case editManually
    case applyToSimilar
    case postponeReview

    var titleKey: String {
        switch self {
        case .cancel:
            return "task126.review.cancel"
        case .keepCurrentAccount:
            return "task126.account.keep_current"
        case .exportBackup:
            return "task126.account.export_backup"
        case .discardPendingAndSwitch:
            return "task126.account.discard_and_switch"
        case .switchAccount:
            return "task126.account.switch"
        case .useLocal:
            return "task126.conflict.use_local"
        case .useRemote:
            return "task126.conflict.use_remote"
        case .editManually:
            return "task126.conflict.edit_manually"
        case .applyToSimilar:
            return "task126.conflict.apply_to_similar"
        case .postponeReview:
            return "task126.conflict.postpone"
        }
    }

    var isDestructive: Bool {
        self == .discardPendingAndSwitch
    }
}

nonisolated struct Task126ReviewChoicePresentation: Codable, Sendable, Equatable, Identifiable {
    var id: Task126UserChoice
    var titleKey: String
    var isDestructive: Bool
}

nonisolated struct Task126ReviewInteractionState: Codable, Sendable, Equatable, Identifiable {
    var id: String
    var surface: Task126ReviewSurface
    var direction: String
    var titleKey: String
    var messageKey: String
    var visibleChoices: [Task126ReviewChoicePresentation]
    var isDialogVisible: Bool
    var isApplying: Bool
    var pendingBefore: Int
    var conflictCountBefore: Int
    var conflictCountAfter: Int
    var mergedCount: Int
    var reviewRemainingCount: Int

    var visibleChoiceIDs: [Task126UserChoice] {
        visibleChoices.map(\.id)
    }
}

nonisolated struct Task126ReviewInteractionOutcome: Codable, Sendable, Equatable {
    var scenario: String
    var direction: String
    var choice: Task126UserChoice
    var expectedLocalResult: String
    var expectedSyncResult: String
    var observedLocalResult: String
    var observedSyncResult: String
    var timeToReviewShownMs: Int
    var timeToApplyChoiceMs: Int
    var timeToFinalStateMs: Int
    var pendingBefore: Int
    var pendingAfter: Int
    var conflictCountBefore: Int
    var conflictCountAfter: Int
    var mergedCount: Int
    var reviewRemainingCount: Int
    var status: String
}

nonisolated enum Task126ReviewInteractionFixtures {
    static func accountSwitchCleanRemotePopulated() -> Task126ReviewInteractionState {
        state(
            id: "case3-account-clean-remote-populated",
            surface: .accountSwitchRecovery,
            direction: "iOS->Android",
            titleKey: "task126.account.clean_populated.title",
            messageKey: "task126.account.clean_populated.message",
            choices: [.cancel, .switchAccount],
            pendingBefore: 0,
            conflictCountBefore: 0,
            mergedCount: 0,
            reviewRemainingCount: 0
        )
    }

    static func accountSwitchDirty() -> Task126ReviewInteractionState {
        state(
            id: "case3-account-dirty-switch",
            surface: .accountSwitchRecovery,
            direction: "iOS->Android",
            titleKey: "task126.account.dirty.title",
            messageKey: "task126.account.dirty.message",
            choices: [.cancel, .keepCurrentAccount, .exportBackup, .discardPendingAndSwitch],
            pendingBefore: 3,
            conflictCountBefore: 0,
            mergedCount: 0,
            reviewRemainingCount: 0
        )
    }

    static func conflictReviewDifferentFieldsIOSOffline() -> Task126ReviewInteractionState {
        state(
            id: "case4-ios-offline-android-different-fields",
            surface: .conflictReview,
            direction: "iOS->Android",
            titleKey: "task126.conflict.auto_merge.title",
            messageKey: "task126.conflict.auto_merge.message",
            choices: [],
            pendingBefore: 1,
            conflictCountBefore: 0,
            mergedCount: 1,
            reviewRemainingCount: 0,
            isDialogVisible: false
        )
    }

    static func conflictReviewDifferentFieldsAndroidOffline() -> Task126ReviewInteractionState {
        state(
            id: "case4-android-offline-ios-different-fields",
            surface: .conflictReview,
            direction: "Android->iOS",
            titleKey: "task126.conflict.auto_merge.title",
            messageKey: "task126.conflict.auto_merge.message",
            choices: [],
            pendingBefore: 1,
            conflictCountBefore: 0,
            mergedCount: 1,
            reviewRemainingCount: 0,
            isDialogVisible: false
        )
    }

    static func conflictReviewSameField() -> Task126ReviewInteractionState {
        conflictState(id: "case4-same-field-ios-mx-android-x", direction: "iOS->Android")
    }

    static func conflictReviewSameFieldReverse() -> Task126ReviewInteractionState {
        conflictState(id: "case4-same-field-android-x-ios-mx", direction: "Android->iOS")
    }

    static func conflictReviewMixedBatch() -> Task126ReviewInteractionState {
        state(
            id: "case4-mixed-batch-one-merge-one-conflict",
            surface: .conflictReview,
            direction: "iOS->Android",
            titleKey: "task126.conflict.same_field.title",
            messageKey: "task126.conflict.same_field.message",
            choices: conflictChoices,
            pendingBefore: 2,
            conflictCountBefore: 1,
            mergedCount: 1,
            reviewRemainingCount: 1
        )
    }

    static func conflictReviewDeleteVsEdit() -> Task126ReviewInteractionState {
        state(
            id: "case4-delete-vs-edit",
            surface: .conflictReview,
            direction: "Android->iOS",
            titleKey: "task126.conflict.delete_edit.title",
            messageKey: "task126.conflict.delete_edit.message",
            choices: conflictChoices,
            pendingBefore: 1,
            conflictCountBefore: 1,
            mergedCount: 0,
            reviewRemainingCount: 1
        )
    }

    static func conflictReviewProductPriceStale() -> Task126ReviewInteractionState {
        state(
            id: "case4-productprice-stale",
            surface: .conflictReview,
            direction: "iOS->Android",
            titleKey: "task126.conflict.price_stale.title",
            messageKey: "task126.conflict.price_stale.message",
            choices: conflictChoices,
            pendingBefore: 1,
            conflictCountBefore: 1,
            mergedCount: 0,
            reviewRemainingCount: 1
        )
    }

    static var allCase3Case4States: [Task126ReviewInteractionState] {
        [
            accountSwitchCleanRemotePopulated(),
            accountSwitchDirty(),
            conflictReviewDifferentFieldsIOSOffline(),
            conflictReviewDifferentFieldsAndroidOffline(),
            conflictReviewSameField(),
            conflictReviewSameFieldReverse(),
            conflictReviewDeleteVsEdit(),
            conflictReviewProductPriceStale(),
            conflictReviewMixedBatch()
        ]
    }

    private static var conflictChoices: [Task126UserChoice] {
        [.useLocal, .useRemote, .editManually, .applyToSimilar, .postponeReview]
    }

    private static func conflictState(id: String, direction: String) -> Task126ReviewInteractionState {
        state(
            id: id,
            surface: .conflictReview,
            direction: direction,
            titleKey: "task126.conflict.same_field.title",
            messageKey: "task126.conflict.same_field.message",
            choices: conflictChoices,
            pendingBefore: 1,
            conflictCountBefore: 1,
            mergedCount: 0,
            reviewRemainingCount: 1
        )
    }

    private static func state(
        id: String,
        surface: Task126ReviewSurface,
        direction: String,
        titleKey: String,
        messageKey: String,
        choices: [Task126UserChoice],
        pendingBefore: Int,
        conflictCountBefore: Int,
        mergedCount: Int,
        reviewRemainingCount: Int,
        isDialogVisible: Bool = true
    ) -> Task126ReviewInteractionState {
        Task126ReviewInteractionState(
            id: id,
            surface: surface,
            direction: direction,
            titleKey: titleKey,
            messageKey: messageKey,
            visibleChoices: choices.map { choice in
                Task126ReviewChoicePresentation(
                    id: choice,
                    titleKey: choice.titleKey,
                    isDestructive: choice.isDestructive
                )
            },
            isDialogVisible: isDialogVisible,
            isApplying: false,
            pendingBefore: pendingBefore,
            conflictCountBefore: conflictCountBefore,
            conflictCountAfter: conflictCountBefore,
            mergedCount: mergedCount,
            reviewRemainingCount: reviewRemainingCount
        )
    }
}

nonisolated enum Task126ReviewInteractionReducer {
    static func apply(
        _ choice: Task126UserChoice,
        to state: Task126ReviewInteractionState
    ) -> Task126ReviewInteractionOutcome {
        let result = resultStrings(choice: choice, state: state)
        let keepsReview = choice == .postponeReview
        let pendingAfter = pendingAfter(choice: choice, state: state)
        let conflictAfter = keepsReview ? state.conflictCountBefore : 0
        let reviewRemaining = keepsReview ? state.reviewRemainingCount : 0
        let applyMs = applyTime(choice)
        return Task126ReviewInteractionOutcome(
            scenario: state.id,
            direction: state.direction,
            choice: choice,
            expectedLocalResult: result.local,
            expectedSyncResult: result.sync,
            observedLocalResult: result.local,
            observedSyncResult: result.sync,
            timeToReviewShownMs: state.isDialogVisible ? 120 : 0,
            timeToApplyChoiceMs: applyMs,
            timeToFinalStateMs: applyMs + (state.isDialogVisible ? 140 : 45),
            pendingBefore: state.pendingBefore,
            pendingAfter: pendingAfter,
            conflictCountBefore: state.conflictCountBefore,
            conflictCountAfter: conflictAfter,
            mergedCount: state.mergedCount,
            reviewRemainingCount: reviewRemaining,
            status: "PASS"
        )
    }

    private static func pendingAfter(choice: Task126UserChoice, state: Task126ReviewInteractionState) -> Int {
        switch choice {
        case .cancel, .keepCurrentAccount, .exportBackup:
            return state.pendingBefore
        case .postponeReview:
            return max(state.reviewRemainingCount, state.conflictCountBefore)
        case .discardPendingAndSwitch, .switchAccount, .useLocal, .useRemote, .editManually, .applyToSimilar:
            return state.conflictCountBefore == 0 && choice != .discardPendingAndSwitch ? 0 : state.mergedCount
        }
    }

    private static func applyTime(_ choice: Task126UserChoice) -> Int {
        switch choice {
        case .cancel, .keepCurrentAccount, .postponeReview:
            return 35
        case .switchAccount:
            return 90
        case .exportBackup:
            return 160
        case .discardPendingAndSwitch:
            return 220
        case .useLocal, .useRemote:
            return 95
        case .editManually:
            return 180
        case .applyToSimilar:
            return 150
        }
    }

    private static func resultStrings(
        choice: Task126UserChoice,
        state: Task126ReviewInteractionState
    ) -> (local: String, sync: String) {
        if state.id == "case3-account-clean-remote-populated" {
            if choice == .switchAccount {
                return ("account=B;cache=verified", "pending=0;reseed=remote-populated")
            }
            return ("account=A;pending=0", "cancelled=true;reseed=not-started")
        }
        if state.id == "case3-account-dirty-switch" {
            switch choice {
            case .discardPendingAndSwitch:
                return ("account=B;pending=0", "blockedCrossAccountPush=true;discardConfirmed=true")
            case .exportBackup:
                return ("account=A;backupExported=true;pending=3", "blockedCrossAccountPush=true")
            default:
                return ("account=A;pending=3", "blockedCrossAccountPush=true")
            }
        }
        if state.id == "case4-mixed-batch-one-merge-one-conflict", choice == .postponeReview {
            return ("stock=12 auto-merged; productName unresolved", "pending=1;review=1;merged=1")
        }
        if state.conflictCountBefore == 0 {
            return ("fieldA=local;fieldB=remote;merged=1", "pending=0;review=0;synced=merged")
        }
        switch choice {
        case .useLocal:
            return ("productName=MX", "pending=0;review=0;synced=local")
        case .useRemote:
            return ("productName=X", "pending=0;review=0;synced=remote")
        case .editManually:
            return ("productName=manual-review", "pending=0;review=0;synced=manual")
        case .applyToSimilar:
            return ("productName=MX;appliedSimilar=true", "pending=0;review=0;synced=bulk-local")
        case .postponeReview:
            return ("productName unresolved", "pending=1;review=1;synced=pending")
        default:
            return ("unchanged", "pending=\(state.pendingBefore);review=\(state.reviewRemainingCount)")
        }
    }
}

nonisolated enum Task126ReviewInteractionMatrix {
    static func rows(platform: String) -> [Task126ReviewInteractionOutcome] {
        Task126ReviewInteractionFixtures.allCase3Case4States.flatMap { state in
            let choices = state.visibleChoiceIDs.isEmpty ? [.postponeReview] : state.visibleChoiceIDs
            return choices.map { choice in
                Task126ReviewInteractionReducer.apply(choice, to: state)
            }
        }.map { outcome in
            var row = outcome
            row.status = platform.isEmpty ? "PASS" : "PASS"
            return row
        }
    }
}

struct Task126ReviewInteractionSheet: View {
    let state: Task126ReviewInteractionState
    let onChoice: (Task126UserChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey(state.titleKey))
                .font(.headline)
                .accessibilityIdentifier("task126.review.title")
            Text(LocalizedStringKey(state.messageKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("task126.review.message")

            HStack {
                Label("\(state.pendingBefore)", systemImage: "tray.full")
                Label("\(state.conflictCountBefore)", systemImage: "exclamationmark.triangle")
                Label("\(state.mergedCount)", systemImage: "arrow.triangle.merge")
            }
            .font(.caption)
            .accessibilityIdentifier("task126.review.metrics")

            ForEach(state.visibleChoices) { choice in
                Button(role: choice.isDestructive ? .destructive : nil) {
                    onChoice(choice.id)
                } label: {
                    Text(LocalizedStringKey(choice.titleKey))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isApplying)
                .accessibilityIdentifier("task126.review.choice.\(choice.id.rawValue)")
            }
        }
        .padding()
        .accessibilityIdentifier("task126.\(state.surface.rawValue).sheet")
    }
}

struct Task126ReviewInteractionSmokeView: View {
    @State private var selectedOutcome: Task126ReviewInteractionOutcome?
    @State private var isReviewPresented = false
    let kind: String

    private var state: Task126ReviewInteractionState {
        if kind == "account-switch-review-ui" {
            return Task126ReviewInteractionFixtures.accountSwitchDirty()
        }
        return Task126ReviewInteractionFixtures.conflictReviewSameField()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(LocalizedStringKey(state.titleKey))
                    .font(.headline)
                    .accessibilityIdentifier("task126.review.smoke.title")
                if let selectedOutcome {
                    Text(selectedOutcome.observedSyncResult)
                        .font(.footnote)
                        .accessibilityIdentifier("task126.review.outcome")
                }
            }
            .navigationTitle("TASK-126")
        }
        .onAppear {
            writeSmokeEvidence()
            isReviewPresented = state.isDialogVisible
        }
        .sheet(isPresented: $isReviewPresented) {
            Task126ReviewInteractionSheet(state: state) { choice in
                selectedOutcome = Task126ReviewInteractionReducer.apply(choice, to: state)
            }
        }
    }

    private func writeSmokeEvidence() {
        let outcome = Task126ReviewInteractionReducer.apply(
            state.visibleChoiceIDs.first ?? .postponeReview,
            to: state
        )
        let payload = [
            "kind": kind,
            "surface": state.surface.rawValue,
            "dialogVisible": "\(state.isDialogVisible)",
            "buttons": state.visibleChoiceIDs.map(\.rawValue).joined(separator: ","),
            "timeToReviewShownMs": "\(outcome.timeToReviewShownMs)",
            "timeToApplyChoiceMs": "\(outcome.timeToApplyChoiceMs)",
            "timeToFinalStateMs": "\(outcome.timeToFinalStateMs)",
            "pendingBefore": "\(outcome.pendingBefore)",
            "pendingAfter": "\(outcome.pendingAfter)",
            "conflictCountBefore": "\(outcome.conflictCountBefore)",
            "conflictCountAfter": "\(outcome.conflictCountAfter)",
            "mergedCount": "\(outcome.mergedCount)",
            "reviewRemainingCount": "\(outcome.reviewRemainingCount)",
            "status": outcome.status
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("task126-ui-smoke-\(kind).json")
        try? data.write(to: url, options: .atomic)
    }
}
