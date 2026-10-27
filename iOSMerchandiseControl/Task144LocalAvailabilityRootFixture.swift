#if DEBUG
import Auth
import CryptoKit
import Combine
import Foundation
import Supabase
import SwiftData
import SwiftUI
import UIKit
// TASK145_T19_INSERT_BEGIN imports
import SQLite3
import Darwin
// TASK145_T19_INSERT_END imports

/// Closed observations of the controlled gesture only. No observable state,
/// store access or view invalidation is introduced while a press is active.
@MainActor
private enum Task144ControlGestureObservation {
    private static var sequence = 0

    static func record(_ stage: String, control: String) {
        guard ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"]
            .flatMap(UUID.init(uuidString:)) != nil, sequence < 17 else { return }
        sequence += 1
        if sequence == 17 {
            print("TASK144_GESTURE_OBSERVATION pid.\(ProcessInfo.processInfo.processIdentifier).CAP16;later.NOT_RETAINED")
            return
        }
        print("TASK144_GESTURE_OBSERVATION seq.\(sequence).uptime.\(ProcessInfo.processInfo.systemUptime).pid.\(ProcessInfo.processInfo.processIdentifier).control.\(control).stage.\(stage)")
    }
}

/// Temporary observations scoped to the controlled empty/callback, physical-fence and related-save fixtures. This buffer is not ObservableObject and never
/// publishes, reads a model/store, submits work or changes an admission result.
nonisolated final class Task144RootObservation: @unchecked Sendable {
    private static let relatedSaveMode = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_RELATED_SAVE"] == "1"
    static let enabled = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"].flatMap(UUID.init(uuidString:)) != nil
        && ((ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_EMPTY_BOOTSTRAP"] == "1"
             && (ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_CALLBACK_ORDER"] == "1"
                 || ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_EMPTY_FENCE_REQUALIFICATION"] == "1"))
            || relatedSaveMode)
    static let observesRelatedInput = enabled && relatedSaveMode
    private static let observesScopeRevalidation = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"]
        .flatMap(UUID.init(uuidString:)) != nil
        && ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_OBSERVE_SCOPE"] == "1"
    private static let shared = Task144RootObservation()
    private let lock = NSLock()
    private var sequence = 0
    private var events: [String] = []
    private var lastByKind: [String: String] = [:]
    private var dropped = 0

    // TASK145_PERF: one closed sample in this existing observation owner.
    private var performance: Task145PerformanceSample?
    private var performanceWarmArmed = false
    private var performanceSawBackground = false
    private var performanceLastTouch: UInt64?

    static func performanceEntry() {
        let entryNS = DispatchTime.now().uptimeNanoseconds
        guard Task145PerformanceConfiguration.measures else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        guard shared.performance == nil else { return }
        shared.performance = makePerformanceSample(kind: "cold")
        shared.performance?.resources = Task145PerformanceResourceSnapshot.capture(prefix: "start_")
        appendPerformance("t0", facts: "first-App.init-entry", ns: entryNS)
    }
    private static func makePerformanceSample(kind: String) -> Task145PerformanceSample {
        .init(sampleID: (Task145PerformanceConfiguration.environment["TASK145_PERF_SAMPLE"] ?? "missing") + "-" + kind,
              launchKind: kind, group: Task145PerformanceConfiguration.recovery ? "recovery" : "idle",
              offline: Task145PerformanceConfiguration.offline)
    }
    static func performanceArmWarm() {
        guard Task145PerformanceConfiguration.measures else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        shared.performanceWarmArmed = true
        shared.performanceSawBackground = false
    }
    static func performanceBackground() {
        guard Task145PerformanceConfiguration.measures else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        if shared.performanceWarmArmed { shared.performanceSawBackground = true }
    }
    static func performanceActivate() {
        let entryNS = DispatchTime.now().uptimeNanoseconds
        guard Task145PerformanceConfiguration.measures else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        guard shared.performanceWarmArmed, shared.performanceSawBackground else { return }
        shared.performanceWarmArmed = false
        shared.performanceSawBackground = false
        let provenanceKeys = ["sourcePin", "artifactPin", "configPin", "targetStorage", "datasetSeed", "auth", "scopeKey", "accountKey", "deviceKey", "networkMode", "RTT", "requestCountCoverage"]
        let provenance = shared.performance?.metadata.filter { provenanceKeys.contains($0.key) } ?? [:]
        shared.performance = makePerformanceSample(kind: "warm")
        for (key, value) in provenance { shared.performance?.metadata[key] = value }
        shared.performance?.resources = Task145PerformanceResourceSnapshot.capture(prefix: "start_")
        shared.performanceLastTouch = nil
        appendPerformance("t0", facts: "current-SwiftUI-scenePhase-active", ns: entryNS)
        // Notification handlers only invalidate the observer view's own layout.
        NotificationCenter.default.post(name: .init("TASK145_PERF_WARM_T0"), object: nil)
    }
    static func performanceSampleID() -> String {
        shared.lock.lock(); defer { shared.lock.unlock() }
        return shared.performance?.sampleID ?? "disabled"
    }
    static func performanceTouch(_ ns: UInt64) {
        shared.lock.lock(); defer { shared.lock.unlock() }; shared.performanceLastTouch = ns
    }
    static func performanceAction(_ name: String) {
        guard Task145PerformanceConfiguration.measures else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        let now = DispatchTime.now().uptimeNanoseconds
        appendPerformance(name + "Handler", facts: "actual-handler-entry", ns: now)
        if let touch = shared.performanceLastTouch, touch <= now, now - touch < 2_000_000_000 {
            appendPerformance(name + "Tap", facts: "passive-window-touch-began", ns: touch)
        }
    }
    static func performanceMark(_ name: String, facts: String = "") {
        guard Task145PerformanceConfiguration.measures else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        appendPerformance(name, facts: facts, ns: DispatchTime.now().uptimeNanoseconds)
    }
    private static func appendPerformance(_ name: String, facts: String, ns: UInt64) {
        guard shared.performance?.status == "OPEN",
              shared.performance?.marks.contains(where: { $0.name == name }) == false else { return }
        let dependencies = ["searchRender": "searchInputComplete", "searchBroadRender": "searchBroadInputComplete",
                            "editorRender": "editorTap", "saveRender": "saveCommit"]
        if let prerequisite = dependencies[name], shared.performance?.marks.contains(where: { $0.name == prerequisite }) != true { return }
        if name == "saveRender", facts != "T20 edited " + (shared.performance?.sampleID ?? "missing") { return }
        if name == "cutoverReleased", shared.performance?.marks.contains(where: { $0.name == "cutoverEntered" }) == true {
            shared.performance?.lastDurableProgressNS = ns
        }
        if (shared.performance?.marks.count ?? 0) < 256 {
            shared.performance?.marks.append(.init(name: name, ns: ns, facts: String(facts.prefix(256))))
        } else { shared.performance?.dropped += 1 }
    }
    static func performanceMetadata(_ values: [String: String]) {
        guard Task145PerformanceConfiguration.measures else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        for (key, value) in values { shared.performance?.metadata[key] = value }
    }
    static func performanceDurableProgress(_ progress: SyncRecoveryProgress) {
        guard Task145PerformanceConfiguration.measures else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        shared.lock.lock(); defer { shared.lock.unlock() }
        guard shared.performance?.status == "OPEN" else { return }
        if let previous = shared.performance?.phase, previous != progress.stage.rawValue {
            for (key, value) in Task145PerformanceResourceSnapshot.capture(prefix: "phase_" + previous + "_end_") { shared.performance?.resources[key] = value }
            for (key, value) in Task145PerformanceResourceSnapshot.capture(prefix: "phase_" + progress.stage.rawValue + "_start_") { shared.performance?.resources[key] = value }
        }
        shared.performance?.phase = progress.stage.rawValue
        if shared.performance?.phaseFirstNS[progress.stage.rawValue] == nil { shared.performance?.phaseFirstNS[progress.stage.rawValue] = now }
        shared.performance?.phaseLastNS[progress.stage.rawValue] = now
        guard let domain = progress.domain else { return } // A stage label is NOT progress.
        guard var old = shared.performance?.durableDomains[domain.rawValue] else {
            // Initial resumed cursor counts are a baseline, not newly committed progress.
            var baseline = Task145DurableDomainProgress()
            baseline.pages = progress.pages; baseline.rows = progress.persistedRows; baseline.baselineNS = now
            shared.performance?.durableDomains[domain.rawValue] = baseline
            return
        }
        guard progress.pages > old.pages || progress.persistedRows > old.rows else { return }
        old.pages = max(old.pages, progress.pages); old.rows = max(old.rows, progress.persistedRows)
        if let preceding = old.lastAdvanceNS ?? old.baselineNS, now >= preceding {
            old.longestBetweenDurableAdvancesNS = max(old.longestBetweenDurableAdvancesNS, now - preceding)
        }
        old.advances += 1; old.lastAdvanceNS = now
        if old.firstAdvanceNS == nil { old.firstAdvanceNS = now }
        shared.performance?.durableDomains[domain.rawValue] = old
        shared.performance?.lastDurableProgressNS = now
    }
    static func performanceQueryResult(query: String, count: Int) {
        guard Task145PerformanceConfiguration.measures, ["", "T20-000", "T20-020000"].contains(query) else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        guard shared.performance?.status == "OPEN" else { return }
        let key = query.isEmpty ? "initialQuery" : query == "T20-000" ? "broadQuery" : "selectiveQuery"
        // Count of the existing filtered array; no additional fetch or full scan.
        shared.performance?.metadata[key + "Count"] = String(count)
        appendPerformance(key + "Completed", facts: "existing-product-filter;count=\(count)", ns: DispatchTime.now().uptimeNanoseconds)
    }
    static func performanceLastDurableProgressNS() -> UInt64? {
        shared.lock.lock(); defer { shared.lock.unlock() }; return shared.performance?.lastDurableProgressNS
    }
    static func performanceFrame(_ ns: UInt64) {
        shared.lock.lock(); defer { shared.lock.unlock() }
        guard shared.performance?.status == "OPEN" else { return }
        if let previous = shared.performance?.lastDisplayNS, ns >= previous {
            shared.performance?.displayIntervals += 1
            shared.performance?.maxDisplayIntervalNS = max(shared.performance?.maxDisplayIntervalNS ?? 0, ns - previous)
            if let entered = shared.performance?.marks.first(where: { $0.name == "cutoverEntered" })?.ns,
               let released = shared.performance?.marks.first(where: { $0.name == "cutoverReleased" })?.ns,
               previous <= released, ns >= entered {
                shared.performance?.maxCutoverDisplayIntervalNS = max(shared.performance?.maxCutoverDisplayIntervalNS ?? 0, ns - previous)
            }
        }
        shared.performance?.lastDisplayNS = ns
    }
    static func performanceCaptureResources(prefix: String) {
        shared.lock.lock(); defer { shared.lock.unlock() }
        guard shared.performance?.status == "OPEN" else { return }
        for (key, value) in Task145PerformanceResourceSnapshot.capture(prefix: prefix) { shared.performance?.resources[key] = value }
    }
    static func performanceSnapshot() -> String {
        shared.lock.lock(); defer { shared.lock.unlock() }
        guard var sample = shared.performance else { return "{}" }
        sample.observedAtNS = DispatchTime.now().uptimeNanoseconds // read time, never progress
        guard let data = try? JSONEncoder().encode(sample) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
    static func performanceSeal(status: String, reason: String) -> String {
        shared.lock.lock(); defer { shared.lock.unlock() }
        guard shared.performance != nil else { return "{}" }
        if let phase = shared.performance?.phase {
            for (key, value) in Task145PerformanceResourceSnapshot.capture(prefix: "phase_" + phase + "_end_") { shared.performance?.resources[key] = value }
        }
        shared.performance?.status = status; shared.performance?.reason = reason
        for (key, value) in Task145PerformanceResourceSnapshot.capture(prefix: "terminal_") { shared.performance?.resources[key] = value }
        // Exports only after the measured UI path has ended (or the first FAIL).
        let data = try? JSONEncoder().encode(shared.performance)
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func record(_ kind: String, _ closedFacts: String, callsite: String = #function) {
        guard enabled || (observesScopeRevalidation && kind == "scope-revalidate-denied") else { return }
        let buffer = shared
        buffer.lock.lock()
        let key = kind + ":" + callsite
        guard kind.hasPrefix("qualification-") || buffer.lastByKind[key] != closedFacts else { buffer.lock.unlock(); return }
        buffer.lastByKind[key] = closedFacts
        buffer.sequence += 1
        let event = "seq.\(buffer.sequence).uptime.\(ProcessInfo.processInfo.systemUptime).pid.\(ProcessInfo.processInfo.processIdentifier).source.\(callsite).\(kind).\(closedFacts)"
        if buffer.events.count < 128 { buffer.events.append(event) } else { buffer.dropped += 1 }
        let shouldPrint = buffer.sequence <= 128
        let firstDrop = buffer.sequence == 129
        buffer.lock.unlock()
        // Closed synthetic facts only. Whether app stdout reaches the runner's
        // raw log is a runtime observation, never an assumed export guarantee.
        if Task145PerformanceConfiguration.measures { return }
        if shouldPrint { print("TASK144_RAM_OBSERVATION \(event)") }
        else if firstDrop { print("TASK144_RAM_OBSERVATION CAP128;later.NOT_RETAINED") }
    }

    static func snapshotAtRealRender() -> String {
        guard enabled || observesScopeRevalidation else { return "" }
        let buffer = shared
        buffer.lock.lock(); defer { buffer.lock.unlock() }
        return ";task144.observation.cached-at-real-render;dropped.\(buffer.dropped);"
            + buffer.events.joined(separator: ";")
    }

    static func recordRelatedSupplierInput(_ stage: String, value: String, focusedField: String?) {
        guard observesRelatedInput else { return }
        let expected = "New related supplier"
        let valueClass = value.isEmpty ? "empty" : value == expected ? "full"
            : expected.hasPrefix(value) ? "prefix" : "other"
        let focus = focusedField.map { $0 == "supplierName" ? "supplier" : "other" } ?? "none"
        record("related-supplier-\(stage)",
            "value-class.\(valueClass).length-utf16.\(value.utf16.count).focus.\(focus)",
            callsite: "EditProductView.supplier-input")
    }

    static func errorCategory(_ error: Error) -> String {
        if let error = error as? Task126OwnerStoreGateError {
            switch error {
            case .cancelled: return "Task126OwnerStoreGateError.cancelled"
            case .activeAccountMismatch: return "Task126OwnerStoreGateError.activeAccountMismatch"
            case .shopContextUnavailable: return "Task126OwnerStoreGateError.shopContextUnavailable"
            case .bindingMismatch: return "Task126OwnerStoreGateError.bindingMismatch"
            case .replacementInterrupted: return "Task126OwnerStoreGateError.replacementInterrupted"
            case .scopeChanged: return "Task126OwnerStoreGateError.scopeChanged"
            case .retiredStoreGeneration: return "Task126OwnerStoreGateError.retiredStoreGeneration"
            case .localModelUnavailable: return "Task126OwnerStoreGateError.localModelUnavailable"
            case .localRemoteConflictRequiresReview: return "Task126OwnerStoreGateError.localRemoteConflictRequiresReview"
            }
        }
        if error is CancellationError { return "CancellationError" }
        if let error = error as? SyncStoreGenerationError {
            switch error {
            case .baseDirectoryUnavailable: return "SyncStoreGenerationError.baseDirectoryUnavailable"
            case .invalidManifest: return "SyncStoreGenerationError.invalidManifest"
            case .activeStoreMissing: return "SyncStoreGenerationError.activeStoreMissing"
            case .stagingAlreadyOpen: return "SyncStoreGenerationError.stagingAlreadyOpen"
            case .stagingScopeChanged: return "SyncStoreGenerationError.stagingScopeChanged"
            case .stagingStoreMissing: return "SyncStoreGenerationError.stagingStoreMissing"
            case .activationReadBackFailed: return "SyncStoreGenerationError.activationReadBackFailed"
            case .cleanupRequiresRelaunch: return "SyncStoreGenerationError.cleanupRequiresRelaunch"
            case .unavailable: return "SyncStoreGenerationError.unavailable"
            case .staleGenerationLease: return "SyncStoreGenerationError.staleGenerationLease"
            case .generationResourceBudgetExceeded: return "SyncStoreGenerationError.generationResourceBudgetExceeded"
            case .insufficientRecoveryDiskCapacity: return "SyncStoreGenerationError.insufficientRecoveryDiskCapacity"
            case .defaultsConfigurationMismatch: return "SyncStoreGenerationError.defaultsConfigurationMismatch"
            case .stagingChangedAfterVerification: return "SyncStoreGenerationError.stagingChangedAfterVerification"
            }
        }
        if let error = error as? ShopSyncRecoveryContractError {
            switch error {
            case .checkpointChanged: return "ShopSyncRecoveryContractError.checkpointChanged"
            case .authenticationChanged: return "ShopSyncRecoveryContractError.authenticationChanged"
            case .invalidCheckpoint: return "ShopSyncRecoveryContractError.invalidCheckpoint"
            case .invalidPage: return "ShopSyncRecoveryContractError.invalidPage"
            case .nonCanonicalTimestamp: return "ShopSyncRecoveryContractError.nonCanonicalTimestamp"
            case .nonMonotonicOrDuplicateID: return "ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID"
            case .rowOutsideScope: return "ShopSyncRecoveryContractError.rowOutsideScope"
            case .digestMismatch: return "ShopSyncRecoveryContractError.digestMismatch"
            case .countMismatch: return "ShopSyncRecoveryContractError.countMismatch"
            case .invalidCursor: return "ShopSyncRecoveryContractError.invalidCursor"
            case .scopeFenceMissing: return "ShopSyncRecoveryContractError.scopeFenceMissing"
            case .markerNotVerified: return "ShopSyncRecoveryContractError.markerNotVerified"
            case .fullRecoveryRequired: return "ShopSyncRecoveryContractError.fullRecoveryRequired"
            case .relationViolation: return "ShopSyncRecoveryContractError.relationViolation"
            case .pageBudgetExceeded: return "ShopSyncRecoveryContractError.pageBudgetExceeded"
            case .invalidImageMetadata: return "ShopSyncRecoveryContractError.invalidImageMetadata"
            case .persistedLedgerInvalid: return "ShopSyncRecoveryContractError.persistedLedgerInvalid"
            case .resourceBudgetExceeded: return "ShopSyncRecoveryContractError.resourceBudgetExceeded"
            case .totalResourceBudgetExceeded: return "ShopSyncRecoveryContractError.totalResourceBudgetExceeded"
            }
        }
        if let error = error as? DeviceInstallIDStoreError {
            switch error {
            case .durableStorageUnavailable: return "DeviceInstallIDStoreError.durableStorageUnavailable"
            case .invalidDurableIdentity: return "DeviceInstallIDStoreError.invalidDurableIdentity"
            }
        }
        if let error = error as? URLError {
            return error.code == .timedOut ? "URLError.timedOut" : "URLError.other"
        }
        return "other"
    }

    final class Evaluation {
        private let kind: String
        private let callsite: String
        private var operands: [String] = []
        private var firstFailed = "none"
        init(_ kind: String, callsite: String) { self.kind = kind; self.callsite = callsite }
        func check(_ value: Bool, _ name: String) -> Bool {
            operands.append("\(name).\(value)")
            if !value && firstFailed == "none" { firstFailed = name }
            return value
        }
        func optional<T>(_ value: T?, _ name: String) -> T? {
            _ = check(value != nil, name)
            return value
        }
        func attempt<T>(_ name: String, _ operation: () throws -> T) -> T? {
            do { return optional(try operation(), name) }
            catch {
                _ = check(false, name)
                operands.append("\(name)-error.\(Task144RootObservation.errorCategory(error))")
                return nil
            }
        }
        func required<T>(_ name: String, _ operation: () throws -> T) throws -> T {
            do { let value = try operation(); _ = check(true, name); return value }
            catch {
                _ = check(false, name)
                operands.append("\(name)-error.\(Task144RootObservation.errorCategory(error))")
                throw error
            }
        }
        func note(_ name: String, _ value: Bool) { operands.append("\(name).\(value)") }
        func finish(_ result: Bool, branch: String = "guard", firstFalseLabel: String = "first-failed") {
            Task144RootObservation.record(kind, "result.\(result).branch.\(branch).\(firstFalseLabel).\(firstFailed).later.NOT_EVALUATED;"
                + operands.joined(separator: ";"), callsite: callsite)
        }
    }
}

/// A fixture request consumes only a fresh revision after an observed denial.
/// Its deadline never moves, and readiness never grants production authority.
@MainActor
final class Task144EmptyFenceInitialRequest {
    enum Outcome: Equatable { case waiting, ready, aborted, expired, inactive }
    let deadline: ContinuousClock.Instant
    private let initialRevision: Int
    private let now: () -> ContinuousClock.Instant
    private var requiresNewRevision = false
    private(set) var isPending = true

    init(initialRevision: Int, now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }) {
        self.initialRevision = initialRevision
        self.now = now
        deadline = now().advanced(by: .seconds(5))
    }

    var isBeforeDeadline: Bool { now() < deadline }

    func evaluate(admitted: Bool, revisionSignal: Int?, anchorsUnchanged: Bool) -> Outcome {
        guard isPending else { return .inactive }
        guard isBeforeDeadline else { isPending = false; return .expired }
        guard anchorsUnchanged else { isPending = false; return .aborted }
        guard admitted else { requiresNewRevision = true; return .waiting }
        if requiresNewRevision, revisionSignal == nil || revisionSignal == initialRevision { return .waiting }
        isPending = false
        return .ready
    }

    func expire() -> Bool {
        guard isPending, !isBeforeDeadline else { return false }
        isPending = false
        return true
    }

    func cancel() { isPending = false }
}

/// An explicitly requested, isolated UI-test dependency boundary. The App,
/// ContentView, editor, recovery service and automatic queue remain production
/// implementations. No default/private Supabase configuration is loaded.
@MainActor
final class Task144LocalAvailabilityRootFixture: ObservableObject {
    static let current: Task144LocalAvailabilityRootFixture? = {
        guard let raw = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"] else { return nil }
        guard let runID = UUID(uuidString: raw) else { preconditionFailure("Invalid controlled fixture namespace") }
        do { return try Task144LocalAvailabilityRootFixture(runID: runID) }
        catch { preconditionFailure("Controlled root fixture could not establish its isolated store") }
    }()

    @Published private(set) var facts: Set<String> = []
    @Published private(set) var automaticReadback = ""
    @Published private(set) var rootPresentationObservation = ""
    private var rootPresentationObservationOrdinal = 0
    @Published private(set) var safeStoreFailureObservation = ""
    @Published private(set) var authStorageObservation = ""
    let provesTransientAuthStorageFailure = ProcessInfo.processInfo.environment["TASK145_AUTH_STORAGE_UI"] == "cached-read-failure"
    private var t13AuthStorage: Task144ControlledAuthStorage?
    private var t13AuthProvider: SupabaseClientProvider?
    private var t13AuthService: SupabaseAuthService?
    private var t13OriginalGeneration: UUID?
    private var t13OriginalStorageDigest: String?
    private var t13ObservationOrdinal = 0
    private var t13CatalogEntries = 0
    let provesSafeStoreLoadFailure = ProcessInfo.processInfo.environment["TASK145_SAFE_STORE_FAILURE_UI"] == "malformed-manifest"
    @Published private(set) var isPreparedForRoot = false
    let authViewModel: SupabaseAuthViewModel
    let controller: SyncStoreGenerationController
    let shopContextStore: ShopContextStore
    let stateStore: SyncStateStore
    private let owner = UUID(uuidString: "14400000-0000-4000-8000-000000000001")!
    private let shop = UUID(uuidString: "14400000-0000-4000-8000-000000000002")!
    private let transport: Task144ControlledRecoveryTransport
    private let catalogRemote: Task144ControlledCatalogRemote
    private var t10Control: Task145SavedRecoveryControl?
    private var r4Control: Task145R4ReviewControl?
    private var r4ObservationTask: Task<Void, Never>?
    private let interruptionControl: Task145InterruptionControl?
    private let isolationControl: Task145IsolationControl?
    private let saveBControl: Task145SaveBControl?
    private let restartControl: Task145RestartControl?
    private let domainControl: Task145DomainControl?
    private let retryControl: Task145RetryControl?
    private let seq6Control: Task145Seq6Control?
// TASK145_SCOPE_SWITCH_INSERT_BEGIN fixture-property
    private var scopeSwitchControl: Task145ScopeSwitchControl?
// TASK145_SCOPE_SWITCH_INSERT_END fixture-property
    private let shopFetcher: Task144ControlledShopFetcher
    private let session: URLSession
    private let emptyBootstrap: Bool
    @Published private(set) var performanceExport = ""
    @Published private(set) var performanceSeedManifest = ""
    @Published private(set) var performanceWarmReady = false
    private var performanceInvocations: [UUID: any SyncAutomaticRuntimeProviding] = [:]
    private var performanceResults: [UUID: SyncAutomaticRunResult] = [:]
    private var performanceSummaries: [UUID: SyncRecoverySnapshotPullSummary] = [:]
    private var performanceLastAllInvocationsFinishedNS: UInt64?
    private var performanceWarmRecoveryPending = false
    private var performanceWarmActivationPending = false
    private var performanceObservationCapacityExceeded = false
    private var performanceFinishInProgress = false
    private var performanceSaveReceipt: (sampleID: String, receipt: LocalProductSaveReceipt)?
    private var performanceHasActiveInvocation: Bool { !performanceInvocations.isEmpty }
    private func performanceCancelInvocations() { for runtime in performanceInvocations.values { runtime.cancel() } }
    let provesEmptyFenceRequalification = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_EMPTY_FENCE_REQUALIFICATION"] == "1"
    private let ownedRepository: SyncStoreGenerationRepository
    private let ownedLegacyStoreURL: URL
    private var emptyFenceQualificationSubscription: AnyCancellable?
    private struct EmptyFenceInitialAnchors {
        let scope: Task126VerifiedOwnerStoreScope
        let phase: SyncPhase
        let container: ModelContainer
    }
    private var emptyFenceInitialAnchors: EmptyFenceInitialAnchors?
    private var emptyFenceInitialRequest: Task144EmptyFenceInitialRequest?
    private var emptyFenceInitialSubscription: AnyCancellable?
    private var emptyFenceInitialExpiry: Task<Void, Never>?
    private var emptyFenceInitialRequestWasStarted = false
    private var task: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private let r23ShellMode = ProcessInfo.processInfo.environment["TASK144_R23_SHELL_PROBE"]
    private var r23QualificationReleased = false
    private var r23QualificationWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasPreparationStarted = false
    private var hasStarted = false
    private var domainOldContainer: ModelContainer?
    private var domainOldLease: SyncStoreGenerationLease?
    private var heldGenerationID: UUID?
    private var heldRecoveryScope: Task126VerifiedOwnerStoreScope?
    private var awaitingAutomaticResumeManifest: SyncStoreGenerationManifest?
    private var completedAutomaticRecoverySummary: SyncRecoverySnapshotPullSummary?
    private let provesShopCallbackOrder = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_CALLBACK_ORDER"] == "1"
    private let provesIndependentPending = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_INDEPENDENT_PENDING"] == "1"
    private let observesReplayScopeComponents = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_LOSE_FIRST_PRODUCT_RESPONSE"] == "1"
        || ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_OBSERVE_SCOPE"] == "1"
    private var independentPendingInserted = false
    let provesR23EditorConflict = ProcessInfo.processInfo.environment["TASK145_EDITOR_CONFLICT_PROBE"] == "1"
    let r23DraftReviewScenario = ProcessInfo.processInfo.environment["TASK145_DRAFT_REVIEW_UI"]
    var hasR23DraftReview: Bool { r23DraftReviewScenario != nil }
    @Published private(set) var r23DraftLedger = ""
    private var r23DraftPeerStep = 0
    private var r23DraftOperationInFlight = false
    private var r23DraftObservation = 0
    private var r23DraftPeerFingerprint: String?
    private var r23DraftSecondRecoveryComplete = false
    private var r23DraftProductWriteEntries = 0
    private var r23DraftEventEntries = 0
    private var r23EditorPeerApplyStarted = false
    private let provesRelatedSave = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_RELATED_SAVE"] == "1"
    private var lastAutomaticResult = "not-observed"
    private var lastAutomaticPresentationID: String?
    private var lastAutomaticInvocationID: UUID?
    private var lastAutomaticCallbackUptime: TimeInterval?
    private var lastObservationPayload = ""
    private var observationSequence = 0
    // Bounded value-only evidence for the existing independent-pending control.
    // These observations do not grant scope, submit work or alter its oracle.
    private struct ProductHTTPObservation {
        let id: UUID
        let payloadHash: String
        let scope: Task126VerifiedOwnerStoreScope
        let sealedToken: LocalPendingChangeCASToken?
        let sealedHash: String?
        let sealedBodyCorresponds: Bool
        let precedingACK: String
        let precedingCASMatches: String
        var providerReturned = false
    }
    private var productHTTPObservations: [ProductHTTPObservation] = []
    private var automaticCompletionObservations: [String] = []
    private var productHTTPObservationCapped = false
    private let namespace: UUID
// TASK145_T19_INSERT_BEGIN property
    private var t19Control: Task145T19Control?
// TASK145_T19_INSERT_END property
    private var callbackHeartbeatEntered = false
    private var callbackHeartbeatCompleted = false
    private var callbackHeartbeatContinuation: CheckedContinuation<Void, Never>?
    private var callbackCompletionContinuation: CheckedContinuation<Void, Never>?


    private enum SetupStage: String {
        case shopDiscovery = "shop-discovery"
        case reopen = "reopen"
        case initialRecovery = "initial-recovery"
        case postInitialScope = "post-initial-scope"
        case heldJournal = "held-journal"
        case heldRecovery = "held-recovery"
        case automaticTerminal = "automatic-terminal"
    }

    private init(runID: UUID) throws {
        namespace = runID
        emptyBootstrap = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_EMPTY_BOOTSTRAP"] == "1"
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw URLError(.cannotCreateFile)
        }
        let root = support.appendingPathComponent("task144-root-fixtures", isDirectory: true)
            .appendingPathComponent(runID.uuidString.lowercased(), isDirectory: true)
        if ProcessInfo.processInfo.environment["TASK145_AUTH_STORAGE_UI"] != nil {
            let environment = ProcessInfo.processInfo.environment
            let conflictingMode = environment.keys.contains { key in
                (key.hasPrefix("TASK145_") && key != "TASK145_AUTH_STORAGE_UI")
                    || (key.hasPrefix("TASK144_") && key != "TASK144_LOCAL_AVAILABILITY_FIXTURE")
            }
            guard provesTransientAuthStorageFailure, !conflictingMode,
                  !FileManager.default.fileExists(atPath: root.path) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        if ProcessInfo.processInfo.environment["TASK145_SAFE_STORE_FAILURE_UI"] != nil {
            let environment = ProcessInfo.processInfo.environment
            let conflictingMode = environment.keys.contains { key in
                (key.hasPrefix("TASK145_") && key != "TASK145_SAFE_STORE_FAILURE_UI")
                    || (key.hasPrefix("TASK144_") && key != "TASK144_LOCAL_AVAILABILITY_FIXTURE")
            }
            guard provesSafeStoreLoadFailure, !conflictingMode,
                  !FileManager.default.fileExists(atPath: root.path) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        let interruptionValue = ProcessInfo.processInfo.environment["TASK145_INTERRUPTION_UI"]
        let interruptionScenario = interruptionValue.flatMap(Task145InterruptionControl.Scenario.init(rawValue:))
        let interruptionAction = ProcessInfo.processInfo.environment["TASK145_INTERRUPTION_ACTION"] ?? "ui"
        guard interruptionValue == nil || (interruptionScenario != nil && ["ui", "crash"].contains(interruptionAction)) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let interruptionBoundary = interruptionScenario.flatMap { scenario in
            interruptionAction == "crash" ? Task145InterruptionBoundary(root: root, runID: runID, scenario: scenario) : nil
        }
        // Fail closed before repository/default-store construction or authority writes.
        if let interruptionScenario {
            try Task145InterruptionControl.validateInitialAdmission(root: root, runID: runID,
                scenario: interruptionScenario, action: interruptionAction)
        }
// TASK145_SCOPE_SWITCH_INSERT_BEGIN early-fresh-admission
        let scopeSwitchEnvironment = ProcessInfo.processInfo.environment
        let scopeSwitchValue = scopeSwitchEnvironment["TASK145_SCOPE_SWITCH_UI"]
        let scopeSwitchScenario = scopeSwitchValue.flatMap(Task145ScopeSwitchControl.Scenario.init(rawValue:))
        guard scopeSwitchValue == nil || scopeSwitchScenario != nil else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if scopeSwitchScenario != nil {
            let otherModes = ["TASK145_SCOPE_INCREMENTAL_UI", "TASK145_SAVE_B_UI", "TASK145_RESTART_UI",
                "TASK145_DOMAIN_UI", "TASK145_RETRY_UI", "TASK144_LOCAL_AVAILABILITY_EMPTY_BOOTSTRAP",
                "TASK144_LOCAL_AVAILABILITY_EMPTY_FENCE_REQUALIFICATION", "TASK144_LOCAL_AVAILABILITY_RELATED_SAVE",
                "TASK144_LOCAL_AVAILABILITY_INDEPENDENT_PENDING", "TASK144_LOCAL_AVAILABILITY_CALLBACK_ORDER",
                "TASK144_LOCAL_AVAILABILITY_LOSE_FIRST_PRODUCT_RESPONSE", "TASK144_LOCAL_AVAILABILITY_OBSERVE_SCOPE"]
            guard !FileManager.default.fileExists(atPath: root.path),
                  AccountBindingStore().currentBinding == nil,
                  !AccountBindingStore().hasPendingReplacementJournal,
                  otherModes.allSatisfy({ scopeSwitchEnvironment[$0] == nil }) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
// TASK145_SCOPE_SWITCH_INSERT_END early-fresh-admission
        let seq6Value = ProcessInfo.processInfo.environment["TASK145_SCOPE_INCREMENTAL_UI"]
        let seq6Scenario = seq6Value.flatMap(Task145Seq6Control.Scenario.init(rawValue:))
        guard seq6Value == nil || seq6Scenario != nil,
              seq6Scenario == nil || (!emptyBootstrap && !provesRelatedSave && !provesIndependentPending) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        // Reject an incomplete reopen before repository initialization or authority writes.
        if let seq6Scenario {
            try Task145Seq6Control.validateInitialAdmission(root: root, runID: runID,
                scenario: seq6Scenario, owner: owner, shop: shop)
        }
        let isolationValue = ProcessInfo.processInfo.environment["TASK145_ISOLATION_UI"]
        let isolationScenario = isolationValue.flatMap(Task145IsolationControl.Scenario.init(rawValue:))
        guard isolationValue == nil || isolationScenario != nil else { throw SyncStoreGenerationError.activationReadBackFailed }
        if let isolationScenario { try Task145IsolationControl.validateAdmission(root: root, runID: runID, scenario: isolationScenario) }
        // Configure the owned journal path before establishing this TEST scope.
        // Existing stores and persistent domains are neither reset nor removed.
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: root.appendingPathComponent("generation-root", isDirectory: true),
            legacyDefaultStoreURL: root.appendingPathComponent("legacy.store"),
            activationBoundaryProbe: { boundary in interruptionBoundary?.handle(boundary) })
        ownedRepository = repository
        ownedLegacyStoreURL = root.appendingPathComponent("legacy.store")
        let linkedShop = LinkedShop(shopID: shop, code: "TASK144", name: "Controlled local root",
            role: "owner", status: "active", selectable: true, canWrite: true)
        let hash = AccountBindingStore.accountHash(for: owner)
        let selected = SelectedShopStore()
        let r4Value = ProcessInfo.processInfo.environment["TASK145_R4_REVIEW_UI"]
        let t10Enabled = ProcessInfo.processInfo.environment["TASK145_SAVE_BEFORE_ACTIVATION_UI"] == "name-price"
        let r4Enabled = r4Value == "noop-price"
        guard r4Value == nil || r4Enabled else { throw SyncStoreGenerationError.activationReadBackFailed }
        let saveBEnabled = ProcessInfo.processInfo.environment["TASK145_SAVE_B_UI"] == "1"
        guard interruptionScenario == nil || (!saveBEnabled && !emptyBootstrap && !provesRelatedSave && !provesIndependentPending) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let restartValue = ProcessInfo.processInfo.environment["TASK145_RESTART_UI"]
        let restartScenario = restartValue.flatMap(Task145RestartControl.Scenario.init(rawValue:))
        guard restartValue == nil || restartScenario != nil,
              restartScenario == nil || (!saveBEnabled && !emptyBootstrap && !provesRelatedSave && !provesIndependentPending) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let historyFeedback = ProcessInfo.processInfo.environment["TASK145_HISTORY_FEEDBACK_UI"]
        guard historyFeedback == nil || historyFeedback == "1" else { throw SyncStoreGenerationError.activationReadBackFailed }
        let domainValue = ProcessInfo.processInfo.environment["TASK145_DOMAIN_UI"]
        let domain = domainValue.flatMap(Task145DomainControl.Domain.init(rawValue:))
        guard historyFeedback == nil || domain == .history else { throw SyncStoreGenerationError.activationReadBackFailed }
        guard domainValue == nil || domain != nil,
              domain == nil || (!saveBEnabled && !emptyBootstrap && !provesRelatedSave && !provesIndependentPending) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let retryEnabled = ProcessInfo.processInfo.environment["TASK145_RETRY_UI"] == "mixed-real-cooldown"
        guard !retryEnabled || (!saveBEnabled && !emptyBootstrap && !provesRelatedSave && !provesIndependentPending) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard [Task145PerformanceConfiguration.enabled, t10Enabled, r4Enabled, saveBEnabled, restartScenario != nil, domain != nil, retryEnabled, seq6Scenario != nil, scopeSwitchScenario != nil, isolationScenario != nil, interruptionScenario != nil].filter({ $0 }).count <= 1 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard isolationScenario == nil || (!saveBEnabled && !emptyBootstrap && !provesRelatedSave && !provesIndependentPending) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard !r4Enabled || (!emptyBootstrap && !provesRelatedSave && !provesIndependentPending && r23ShellMode == nil && !provesR23EditorConflict) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard r23DraftReviewScenario == nil || (["mixed", "use-current", "deleted-rebind"].contains(r23DraftReviewScenario!)
            && !t10Enabled && !r4Enabled && !saveBEnabled && restartScenario == nil && domain == nil
            && !retryEnabled && seq6Scenario == nil && scopeSwitchScenario == nil && isolationScenario == nil
            && interruptionScenario == nil && !emptyBootstrap && !provesRelatedSave && !provesIndependentPending
            && r23ShellMode == nil && !provesR23EditorConflict && !provesTransientAuthStorageFailure) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if Task145PerformanceConfiguration.enabled {
            guard !emptyBootstrap, !provesRelatedSave, !provesIndependentPending,
                  r23ShellMode == nil, !provesR23EditorConflict, r23DraftReviewScenario == nil,
                  !provesTransientAuthStorageFailure, !provesSafeStoreLoadFailure,
                  ProcessInfo.processInfo.environment["TASK145_T19_UI"] == nil,
                  !provesEmptyFenceRequalification, !provesShopCallbackOrder else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        let existingManifest = (Task145PerformanceConfiguration.measures || t10Enabled || r4Enabled || saveBEnabled || restartScenario != nil || domain != nil || retryEnabled || seq6Scenario != nil || isolationScenario != nil || interruptionScenario != nil)
            ? try repository.activeManifest() : nil
        if let existingManifest {
            // Reopen validates the original authority; it must not create a new
            // binding/selection to make a missing or foreign scope look valid.
            guard selected.selectedShop(accountHash: hash)?.shopID == shop,
                  AccountBindingStore().currentBinding?.accountHash == hash,
                  AccountBindingStore().currentBinding?.storeIdentity == existingManifest.storeIdentity,
                  existingManifest.accountHash == hash, existingManifest.shopID == shop,
                  (AccountBindingStore().pendingRecoveryJournal == nil || retryEnabled || interruptionScenario != nil || t10Enabled) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        } else {
            selected.noteActiveAccount(hash)
            guard selected.save(SelectedShop(linkedShop: linkedShop), accountHash: hash),
                  AccountBindingStore().saveBinding(accountHash: hash,
                    storeIdentity: LocalStoreIdentity(rawValue: shop.uuidString.lowercased())) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        let device = try DeviceInstallIDStore().requireDeviceInstallID()
        if provesSafeStoreLoadFailure {
            try Task145StoreLoadFailureObservation.malformedManifest.write(to: repository.manifestURL, options: .withoutOverwriting)
            controller = try SyncStoreGenerationController.openingControlledRepositoryForTesting(repository, runID: runID)
        } else {
            controller = try SyncStoreGenerationController(repository: repository)
        }
        let product = RemoteInventoryProductRow(
            id: Task145PerformanceConfiguration.enabled ? Task145PerformanceConfiguration.targetID : UUID(uuidString: "14400000-0000-4000-8000-000000000003")!,
            ownerUserID: owner, shopID: shop, barcode: Task145PerformanceConfiguration.enabled ? "T20-020000" : "LOCAL-ROOT",
            itemNumber: Task145PerformanceConfiguration.enabled ? "T20-20000" : "root fixture",
            productName: Task145PerformanceConfiguration.enabled ? "Synthetic T20 20000" : "Safe local baseline", secondProductName: nil,
            purchasePrice: Task145PerformanceConfiguration.enabled ? 10 : nil,
            retailPrice: Task145PerformanceConfiguration.enabled ? 20 : nil,
            supplierID: Task145PerformanceConfiguration.enabled ? Task145PerformanceConfiguration.supplierIDs[0] : nil,
            categoryID: Task145PerformanceConfiguration.enabled ? Task145PerformanceConfiguration.categoryIDs[0] : nil,
            stockQuantity: Task145PerformanceConfiguration.enabled ? 0 : (historyFeedback == "1" ? 1 : nil),
            updatedAt: "2026-07-21T12:00:00.000000Z", deletedAt: nil)
        isolationControl = try isolationScenario.map { try Task145IsolationControl(root: root, runID: runID, scenario: $0) }
        interruptionControl = try interruptionScenario.map { scenario in
            try Task145InterruptionControl(root: root, runID: runID, scenario: scenario, action: interruptionAction, initial: product)
        }
        transport = try Task144ControlledRecoveryTransport(owner: owner, shop: shop, device: device,
            product: emptyBootstrap ? nil : product)
        transport.interruptionControl = interruptionControl
        saveBControl = saveBEnabled ? try Task145SaveBControl(runID: runID,
            url: root.appendingPathComponent("save-b-remote-v1.json"), initial: product,
            reopening: existingManifest != nil) : nil
        restartControl = try restartScenario.map { scenario in
            try Task145RestartControl(runID: runID, scenario: scenario,
                url: root.appendingPathComponent("restart-remote-v1.json"), initial: product,
                reopening: existingManifest != nil)
        }
        domainControl = try domain.map { domain in
            try Task145DomainControl(runID: runID, domain: domain,
                url: root.appendingPathComponent("domain-remote-v1.json"), initial: product,
                reopening: existingManifest != nil)
        }
        retryControl = retryEnabled ? try Task145RetryControl(runID: runID,
            url: root.appendingPathComponent("retry-mixed-observation-v1.json"), reopening: existingManifest != nil) : nil
        seq6Control = try seq6Scenario.map { scenario in
            try Task145Seq6Control(runID: runID, scenario: scenario,
                url: root.appendingPathComponent("seq6-observation-v1.json"), reopening: existingManifest != nil)
        }
        guard !saveBEnabled || (!emptyBootstrap && !provesRelatedSave && !provesIndependentPending) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        catalogRemote = Task144ControlledCatalogRemote(initial: product,
            authoritativeScope: transport.baseline.scope, isEmpty: emptyBootstrap, allowsRelatedSave: provesRelatedSave,
            saveBControl: saveBControl, restartControl: restartControl, domainControl: domainControl, isolationControl: isolationControl, interruptionControl: interruptionControl)
        shopFetcher = Task144ControlledShopFetcher(shop: linkedShop)
        shopContextStore = ShopContextStore(fetcher: shopFetcher)
        stateStore = SyncStateStore(keyPrefix: "task144.controlled.\(runID.uuidString.lowercased())")

        let storage = Task144ControlledAuthStorage()
        let host = "task144-\(runID.uuidString.lowercased()).example.invalid"
        let user = User(id: owner, appMetadata: [:], userMetadata: [:], aud: "authenticated",
            email: "local-availability-fixture@long-account-domain.example.invalid", createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let authSession = Session(accessToken: "task144-controlled-access", tokenType: "bearer",
            expiresIn: 3600, expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "task144-controlled-refresh", user: user)
        try storage.store(key: "sb-\(host.split(separator: ".")[0])-auth-token",
            value: JSONEncoder().encode(authSession))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Task144ControlledNetworkBlocker.self]
        session = URLSession(configuration: configuration)
        let provider = SupabaseClientProvider(config: .init(projectURL: URL(string: "https://\(host)")!,
            publishableKey: "task144-controlled-public", productImageAPIBaseURL: nil),
            authStorage: storage, session: session, autoRefreshToken: false,
            authRegistry: SupabaseAuthClientRegistry())
        let authService = SupabaseAuthService(provider: provider)
        authViewModel = SupabaseAuthViewModel(authService: authService)
        if provesTransientAuthStorageFailure {
            t13AuthStorage = storage; t13AuthProvider = provider; t13AuthService = authService
            catalogRemote.observeRawProductEntry = { [weak self] in self?.t13CatalogEntries += 1 }
        }
        if Task145PerformanceConfiguration.enabled {
            let directory = root.appendingPathComponent("task145-large-dataset", isDirectory: true)
            if Task145PerformanceConfiguration.mode == "seed" {
                try Task145LargeUITransport.seed(directory: directory, base: transport.baseline, owner: owner)
            }
            transport.performance = try Task145LargeUITransport(directory: directory)
            try catalogRemote.configurePerformanceServer(directory: directory, transport: transport.performance!)
            if Task145PerformanceConfiguration.measures, let checkpoint = transport.performance?.checkpointValue {
                let environment = Task145PerformanceConfiguration.environment
                Task144RootObservation.performanceMetadata([
                    "sourcePin": environment["TASK145_PERF_SOURCE_PIN"] ?? "MISSING",
                    "artifactPin": environment["TASK145_PERF_ARTIFACT_PIN"] ?? "MISSING",
                    "configPin": environment["TASK145_PERF_CONFIG_PIN"] ?? "MISSING",
                    "targetStorage": environment["TASK145_PERF_TARGET_STORAGE"] ?? "MISSING",
                    "datasetSeed": "T20-20261016-v1-relations-2x2", "datasetCheckpointDigest": checkpoint.checkpointDigest,
                    "productVersionDigest": checkpoint.catalog.products.versionDigest, "priceVersionDigest": checkpoint.prices.versionDigest,
                    "auth": "synthetic authenticated fixture, no backend acceptance", "scopeKey": checkpoint.scope.key,
                    "accountKey": checkpoint.scope.accountKey, "deviceKey": checkpoint.scope.deviceKey,
                    "networkMode": Task145PerformanceConfiguration.offline ? "offline before measured launch" : "controlled in-process transport",
                    "RTT": "external network NOT_APPLICABLE; actual controlled request durations recorded including hold",
                    "requestCountCoverage": "recovery/checkpoint/marker/catalog-write/price-write/activity-registration; incremental reads not timed"])
            }
            transport.performance?.onRecoveryHeld = { [weak self] in self?.facts.insert("task145.perf.actual-recovery-request-held") }
            // Seed is outside every measured process; never hold seed transport.
            transport.performance?.holdNextProducts = Task145PerformanceConfiguration.measures && Task145PerformanceConfiguration.recovery
            if Task145PerformanceConfiguration.measures, controller.activeManifest != nil {
                if Task145PerformanceConfiguration.recovery {
                    guard let binding = AccountBindingStore().currentBinding,
                          AccountBindingStore().beginSameScopeRecovery(accountHash: binding.accountHash,
                            storeIdentity: binding.storeIdentity, reason: "TASK145_PERF_CONTROLLED_REQUEST",
                            deviceIdentityHash: DeviceInstallIDStore.identityHash(for: device)) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
                // Only the synthetic pre-gate is removed. Product root admission,
                // persisted qualification, privacy and navigation are untouched.
                hasStarted = true; isPreparedForRoot = true
            }
        }
        transport.remoteSnapshot = { [catalogRemote] in catalogRemote.recoverySnapshot }
        transport.onHeld = { [weak self] in
            self?.facts.insert("task144.controlled.held")
            Task144RootObservation.record("fixture-boundary", "branch.existing-transport-on-held", callsite: "Task144.onHeld")
        }
        transport.checkpointBoundary = { [weak self] in await self?.releasePreviousShopCallbackAtCheckpoint() }
        if r23ShellMode == "hold" {
            // Installed synchronously before the controller's qualification task
            // gets its first MainActor turn. Every current publication must wait.
            transport.holdsProducts = true
            controller.localBodyQualificationBeforePublicationForTesting = { [weak self] in
                guard let self, !self.r23QualificationReleased else { return }
                self.facts.insert("task144.r23.qualification-held")
                await withCheckedContinuation { self.r23QualificationWaiters.append($0) }
            }
        }
        if let saveBControl {
            saveBControl.captureEnvelope = { [weak self] id, payload, scope in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                return try self.saveBEnvelope(id: id, payload: payload, scope: scope)
            }
        }
        if let restartControl {
            restartControl.captureEnvelope = { [weak self] id, payload, scope in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                return try self.restartEnvelope(id: id, payload: payload, scope: scope)
            }
        }
        if let domainControl {
            domainControl.captureCatalog = { [weak self] id, payload, scope in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                return try self.domainCatalogEnvelope(id: id, payload: payload, scope: scope)
            }
            domainControl.capturePrices = { [weak self] payloads, scope in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                return try self.domainPriceTokens(payloads, scope: scope)
            }
            domainControl.captureHistory = { [weak self] row, scope in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                return try self.domainHistoryEnvelope(row, scope: scope)
            }
            domainControl.validateEvent = { [weak self] request, scope in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                try self.domainEventReadback(request, scope: scope)
            }
        }
        if let interruptionControl {
            transport.beforeCheckpoint = { try interruptionControl.note("checkpoint") }
            transport.beforeMarker = { try interruptionControl.note("marker") }
            catalogRemote.observeRawProductEntry = { try interruptionControl.note("business:catalog") }
            catalogRemote.observeRawEventEntry = { try interruptionControl.note("business:event") }
        }
        if let retryControl {
            transport.beforeCheckpoint = { [weak self] in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                try self.retryCheckpointEntry()
            }
            transport.beforePage = { try retryControl.noteRead("page:" + $0) }
            transport.beforeMarker = { try retryControl.noteRead("marker") }
            catalogRemote.observeRawProductEntry = { try retryControl.noteProductEntry() }
            catalogRemote.observeRawEventEntry = { try retryControl.noteEventEntry() }
        }
        if let seq6Control {
            catalogRemote.seq6Control = seq6Control
            shopFetcher.seq6Control = seq6Control
            transport.beforeCheckpoint = { [weak self] in
                guard let self, seq6Control.armed else { return }
                try seq6Control.note("checkpoint", ["generation": self.controller.activeManifest?.generationID.uuidString ?? "missing"])
                if seq6Control.state.scenario == .snapshotChanged, seq6Control.count("checkpoint").isMultiple(of: 2) {
                    let version = seq6Control.count("checkpoint") / 2
                    self.catalogRemote.moveSeq6Snapshot(version: version, name: "Seq6 changed snapshot \(version)")
                    try seq6Control.note("snapshot-moved-before-B", ["version": String(version)])
                }
            }
            transport.beforePage = { if seq6Control.armed { try seq6Control.note("page", ["domain": $0]) } }
            transport.beforeMarker = { if seq6Control.armed { try seq6Control.note("marker") } }
            catalogRemote.observeRawProductEntry = { if seq6Control.armed { try seq6Control.note("product-write") } }
            catalogRemote.observeRawEventEntry = { if seq6Control.armed { try seq6Control.note("event-write") } }
        }
// TASK145_T19_INSERT_BEGIN configuration
        if let mode = ProcessInfo.processInfo.environment["TASK145_T19_UI"] {
            guard restartScenario == .preSend, domain == nil, retryControl == nil, !saveBEnabled,
                  let stage = ProcessInfo.processInfo.environment["TASK145_T19_STAGE"], ["setup", "collect"].contains(stage) else {
                throw Task145T19Error(code: "t19_composition_admission")
            }
            let control = try Task145T19Control(parent: root, runID: runID, mode: mode, collecting: stage == "collect")
            t19Control = control
            catalogRemote.t19RPC = { [weak control] name, args in control?.rpc(name, args) ?? 0 }
            catalogRemote.t19RPCComplete = { [weak control] name, entry, errorType in control?.rpcComplete(name, entry: entry, errorType: errorType) }
            transport.beforeCheckpoint = { [weak control] in _ = control?.rpc("recovery_checkpoint") }
            transport.beforePage = { [weak control] domain in _ = control?.rpc("recovery_page", ["domain": domain]) }
            transport.beforeMarker = { [weak control] in _ = control?.rpc("recovery_marker") }
        }

// TASK145_T19_INSERT_END configuration
        if t10Enabled {
            guard !emptyBootstrap, !provesRelatedSave, !provesIndependentPending else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            let control = try Task145SavedRecoveryControl(url: root.appendingPathComponent("saved-recovery-v2.json"),
                runID: runID, initial: product, reopening: existingManifest != nil)
            t10Control = control; catalogRemote.configureT10(control)
            transport.t10EventPage = { [control] parameters, checkpoint in
                try control.eventPage(parameters, checkpoint: checkpoint)
            }
            control.capturePrice = { [weak self] payload, scope in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                return try self.t10PriceWitnessAtIngress(payload, scope: scope)
            }
        }
        if r4Enabled {
            let control = try Task145R4ReviewControl(url: root.appendingPathComponent("r4-remote-v1.json"),
                runID: runID, initial: product, reopening: existingManifest != nil)
            r4Control = control
            catalogRemote.configureR4(control)
            catalogRemote.observeRawProductEntry = { try control.noteCatalogEntry() }
            control.captureEnvelope = { [weak self] id, payload, scope in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                return try self.r4Envelope(id: id, payload: payload, scope: scope)
            }
            control.captureAdoption = { [weak self] in
                guard let self else { throw SyncStoreGenerationError.activationReadBackFailed }
                _ = try self.observeR4State()
            }
        }
        isolationControl?.verifyEventRequest = { [weak self] request in
            guard let self else { return false }
            return try self.isolationEventMatchesOutbox(request)
        }
        if hasR23DraftReview {
            catalogRemote.observeRawProductEntry = { [weak self] in self?.r23DraftProductWriteEntries += 1 }
            catalogRemote.observeRawEventEntry = { [weak self] in self?.r23DraftEventEntries += 1 }
        }
        if provesIndependentPending {
            // Explicit opt-in controlled counterexample: commit the first
            // typed Product body, lose only its response, then let the normal
            // runtime retry the durable sealed attempt. The oracle is unchanged.
            catalogRemote.losesFirstCommittedProductResponse = ProcessInfo.processInfo.environment[
                "TASK144_LOCAL_AVAILABILITY_LOSE_FIRST_PRODUCT_RESPONSE"] == "1"
            catalogRemote.observeProductAttempt = { [weak self] id, payload, scope, providerReturning in
                self?.observeProductHTTP(id: id, payload: payload, scope: scope, providerReturning: providerReturning)
            }
        }
// TASK145_SCOPE_SWITCH_INSERT_BEGIN configure-C-only
        if let scopeSwitchScenario {
            configureScopeSwitch(try Task145ScopeSwitchControl(runID: runID, scenario: scopeSwitchScenario,
                root: root, owner: owner, shopA: linkedShop, device: device))
        }
// TASK145_SCOPE_SWITCH_INSERT_END configure-C-only
    }

    // TASK145_T18_INSERT_BEGIN passive-snapshot
    /// Closed, on-demand reads for the existing UIKit AX observation control.
    /// No refresh, Task, sync request, persistence, mutation fence or authority grant.
    func t18PassiveSnapshot(traits: UITraitCollection) -> String {
        var result: [String: Any] = ["schema": 1, "status": "READ_FAILED",
            "runID": ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"] ?? "missing",
            "uptime": ProcessInfo.processInfo.systemUptime,
            "utc": Date().timeIntervalSince1970, "pid": ProcessInfo.processInfo.processIdentifier]
        func encode() -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
                  data.count <= 8192, let value = String(data: data, encoding: .utf8) else {
                return "{\"status\":\"ENCODING_OR_SIZE_FAILURE\"}"
            }
            return value
        }
        guard ProcessInfo.processInfo.environment["TASK145_T18_OBSERVATION"] == "1",
              isPreparedForRoot, let manifest = controller.activeManifest else {
            result["failure"] = "observation-not-admitted-or-root-not-qualified"
            return encode()
        }
        let state = stateStore.state
        let bindingStore = AccountBindingStore()
        let journal = bindingStore.pendingRecoveryJournal
        let journalPresent = bindingStore.hasPendingReplacementJournal
        guard !journalPresent || journal != nil else {
            result["failure"] = "present-journal-read-or-decode-unqualified"
            return encode()
        }
        result["phase"] = Self.phaseKind(state.phase)
        result["automaticWorkActive"] = state.phase.isAutomaticWorkActive
        switch state.lastOutcome {
        case .succeeded?: result["outcome"] = "succeeded"
        case .noWork?: result["outcome"] = "noWork"
        case .failed?: result["outcome"] = "failed"
        case .busy?: result["outcome"] = "busy"
        case .cancelled?: result["outcome"] = "cancelled"
        case .scheduledRetry?: result["outcome"] = "scheduledRetry"
        case .blocked(let reason)?: result["outcome"] = "blocked"; result["blockReason"] = String(describing: reason)
        case nil: result["outcome"] = "none"
        }
        result["generation"] = manifest.generationID.uuidString.lowercased()
        result["manifestShop"] = manifest.shopID.uuidString.lowercased()
        result["accountHash"] = manifest.accountHash
        result["scopeMatchesFixture"] = manifest.shopID == shop
            && manifest.accountHash == AccountBindingStore.accountHash(for: owner)
        result["bodyProof"] = Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer)
        result["localAccess"] = Task126OwnerStoreGate.permitsSameScopeLocalAccess(
            modelContainer: controller.modelContainer, ownerUserID: owner)
        result["sessionSignedIn"] = authViewModel.isSignedIn
        result["sessionOwnerMatches"] = authViewModel.localMutationOwnerUserID == owner
        result["selectedShop"] = shopContextStore.context.selectedShop?.shopID.uuidString.lowercased() ?? "none"
        result["syncAllowed"] = shopContextStore.context.syncAllowed
        result["journalPresent"] = journalPresent
        result["journalPhase"] = journal?.phase.rawValue ?? "none"
        result["heldPage"] = facts.contains("task144.controlled.held") && transport.holdsProducts && !transport.isReleased
        result["fixtureFailure"] = facts.contains("task144.controlled.failure")
        result["healthyTerminal"] = facts.contains("task145.seq6.automatic-terminal")
        result["membershipRefused"] = seq6Control?.state.facts["server-membership"] == "revoked"
        result["membershipTerminal"] = facts.contains("task145.seq6.safety-terminal")
        result["fontCategory"] = UIApplication.shared.preferredContentSizeCategory.rawValue
        result["observerFontCategory"] = traits.preferredContentSizeCategory.rawValue
        result["optionsSwiftUIAccessibility5"] = facts.contains("task144.controlled.swiftui-type.accessibility5")
        result["theme"] = traits.userInterfaceStyle == .dark ? "dark" : traits.userInterfaceStyle == .light ? "light" : "unspecified"
        result["appLanguage"] = UserDefaults.standard.string(forKey: "appLanguage") ?? "missing"
        if let control = retryControl {
            do {
                let budget = try control.decode(control.currentBudget())
                result["retryDeadlineUTC"] = budget.nextAllowedAt
                if let completed = budget.lastCompletedAt { result["retryCompletedUTC"] = completed }
                result["retryTotalAttempts"] = budget.totalAttempts
                result["retryWindowAttempts"] = budget.attemptsInWindow
                result["retryWindowIndex"] = budget.windowIndex
                result["retryEntries"] = control.state.entries.count
                result["retryCompletions"] = control.state.completions.count
            } catch {
                result["failure"] = "retry-budget-read-or-decode-failed"
                return encode()
            }
        }
        result["status"] = "CURRENT_READ_ONLY"
        return encode()
    }
    // TASK145_T18_INSERT_END passive-snapshot

    func noteOptionsAccountLayout(dynamicTypeSize: DynamicTypeSize, usesAccessibilityStack: Bool) {
        let typePrefix = "task144.controlled.swiftui-type."
        let layoutPrefix = "task144.controlled.account-layout."
        facts = facts.filter { !$0.hasPrefix(typePrefix) && !$0.hasPrefix(layoutPrefix) }
        facts.insert(typePrefix + (dynamicTypeSize == .accessibility5 ? "accessibility5" : "other"))
        facts.insert(layoutPrefix + (usesAccessibilityStack ? "accessibility-stack" : "ordinary-fit"))
    }

    func beginAuthStorageReadFailure() {
        guard provesTransientAuthStorageFailure, let storage = t13AuthStorage, let service = t13AuthService,
              authViewModel.isSignedIn, authViewModel.localMutationOwnerUserID == owner,
              facts.contains("task144.controlled.held"),
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                ownerUserID: authViewModel.localMutationOwnerUserID) else { return }
        t13OriginalGeneration = service.authGeneration
        t13OriginalStorageDigest = storage.rawDigest()
        storage.setReadFailure(true)
        // Genuine SDK SessionStorage.get catches this controlled read error.
        // No signedOut event or app session value is manufactured here.
        authViewModel.refreshCurrentSessionSnapshot()
        observeAuthStorageBoundary()
        facts.insert("task145.t13.storage-read-held")
    }

    func restoreAuthStorageRead() {
        guard provesTransientAuthStorageFailure, let storage = t13AuthStorage,
              storage.rawDigest() == t13OriginalStorageDigest else { return }
        storage.setReadFailure(false)
        authViewModel.refreshCurrentSessionSnapshot()
        observeAuthStorageBoundary()
    }

    func observeAuthStorageBoundary() {
        guard provesTransientAuthStorageFailure, let storage = t13AuthStorage,
              let provider = t13AuthProvider, let service = t13AuthService,
              let generation = t13OriginalGeneration else { return }
        let localOwner = authViewModel.localMutationOwnerUserID
        let admitted = Task126OwnerStoreGate.permitsSameScopeLocalAccess(
            modelContainer: controller.modelContainer, ownerUserID: localOwner)
        let generationAccepted = service.acceptsAuthGeneration(generation)
        var freshSavedProduct = false
        var freshPendingIntent = false
        var writerEntered = false
        var writerDenied = false
        var readFailure = false
        if admitted {
            do {
                let context = ModelContext(controller.modelContainer)
                let products = try context.fetch(FetchDescriptor<Product>())
                let intents = try context.fetch(FetchDescriptor<LocalPendingChange>())
                if products.count == 1, products[0].productName == "Saved before network release" {
                    freshSavedProduct = true
                    freshPendingIntent = intents.contains { intent in
                        intent.entityKind == .product && intent.status == .pending
                            && intent.ownerUserID == owner.uuidString.lowercased()
                            && intent.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(products[0])
                    }
                }
            } catch { readFailure = true }
        }
        if !generationAccepted {
            // The real production writer gate receives the app's actual owner.
            // The closure has no write; entering it after logout is a test failure.
            do {
                try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: controller.modelContainer,
                    ownerUserID: localOwner) { _ in writerEntered = true }
            } catch { writerDenied = true }
        }
        t13ObservationOrdinal += 1
        let values: [String: Any] = [
            "namespace": namespace.uuidString.lowercased(), "observation": t13ObservationOrdinal,
            "SDKSessionNil": provider.client.auth.currentSession == nil,
            "appSessionNil": authViewModel.sessionInfo == nil, "isSignedIn": authViewModel.isSignedIn,
            "sameGeneration": service.authGeneration == generation, "generationAccepted": generationAccepted,
            "storedBytesUnchanged": storage.rawDigest() == t13OriginalStorageDigest,
            "storageReadHeld": storage.readsFailing,
            "hasCurrentBodyProof": Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
            "hasLocalOwner": localOwner == owner, "localCapability": admitted,
            "freshSavedProduct": freshSavedProduct, "freshPendingIntent": freshPendingIntent,
            "readFailure": readFailure, "writerEnteredAfterLogout": writerEntered, "writerDeniedAfterLogout": writerDenied,
            "catalogEntries": t13CatalogEntries, "authHTTPEntries": Task144ControlledNetworkBlocker.t13RequestCount
        ]
        authStorageObservation = (try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]).base64EncodedString()) ?? "invalid"
    }

    func observeSafeStoreFailure() {
        guard provesSafeStoreLoadFailure else { return }
        let bytes = try? Data(contentsOf: ownedRepository.manifestURL)
        safeStoreFailureObservation = Task145StoreLoadFailureObservation.snapshot(
            namespace: namespace, failureCode: controller.loadFailureCode,
            malformedManifestPreserved: bytes == Task145StoreLoadFailureObservation.malformedManifest,
            manifestAbsent: controller.activeManifest == nil,
            signedIn: authViewModel.isSignedIn)
    }

    func prepareIfNeeded() {
        guard !hasPreparationStarted else { return }
        let actualCategory = UIApplication.shared.preferredContentSizeCategory
        facts.insert(actualCategory == .accessibilityExtraExtraExtraLarge
            ? "task144.controlled.content-size.accessibility-xxxl"
            : "task144.controlled.content-size.other")
        hasPreparationStarted = true
        if provesSafeStoreLoadFailure {
            // No baseline, readback, recovery or business query is submitted.
            // The real App failure branch receives the controller's actual catch.
            hasStarted = true
            isPreparedForRoot = true
            facts.insert("task145.safe-store-failure.actual-load-caught")
            observeSafeStoreFailure()
            return
        }
        if r23ShellMode == "hold", controller.activeManifest != nil {
            // Remove only the fixture's artificial pre-gate on a persisted store.
            // ContentView still owns all production privacy/capability decisions.
            hasStarted = true
            isPreparedForRoot = true
            facts.insert("task144.r23.persisted-root-mounted")
        }
        // Establish the fixture's real persisted baseline before mounting the
        // business root. Its normal startup must not race this setup recovery.
        preparationTask = Task { [weak self] in
            guard let self else { return }
            var setupStage = SetupStage.shopDiscovery
            do {
                for _ in 0..<200 {
                    if authViewModel.isSignedIn,
                       authViewModel.localMutationOwnerUserID == owner { break }
                    try await Task.sleep(for: .milliseconds(50))
                }
                guard authViewModel.isSignedIn,
                      authViewModel.localMutationOwnerUserID == owner else { throw URLError(.timedOut) }
                await shopContextStore.refresh(ownerUserID: owner)
                guard shopContextStore.context.syncAllowed else { throw URLError(.timedOut) }
                if controller.activeManifest != nil {
                    setupStage = .reopen
                    if r23ShellMode == "hold" {
                        // The production root owns qualification. Awaiting one task
                        // would observe a superseded cancellation rather than the
                        // current capability when root lifecycle requests coalesce.
                        let expectedManifest = controller.activeManifest
                        let expectedContainer = controller.modelContainer
                        if !r23QualificationReleased {
                            await withCheckedContinuation { self.r23QualificationWaiters.append($0) }
                        }
                        let deadline = ProcessInfo.processInfo.systemUptime + 10
                        while ProcessInfo.processInfo.systemUptime < deadline {
                            guard controller.activeManifest == expectedManifest,
                                  controller.modelContainer === expectedContainer,
                                  authViewModel.localMutationOwnerUserID == owner else {
                                throw SyncStoreGenerationError.activationReadBackFailed
                            }
                            if Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                                modelContainer: expectedContainer, ownerUserID: owner) {
                                let context = ModelContext(expectedContainer)
                                guard try context.fetchCount(FetchDescriptor<Product>()) == 1,
                                      try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0 else {
                                    throw SyncStoreGenerationError.activationReadBackFailed
                                }
                                facts.insert("task144.r23.qualification-observation.current-authority")
                                facts.insert("task144.r23.qualification-released-and-readback")
                                return
                            }
                            try await Task.sleep(for: .milliseconds(50))
                        }
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    controller.startLocalBodyQualification(ownerUserID: owner)
                    let qualified = await controller.awaitLocalBodyQualification()
                    facts.insert("task144.controlled.reopen-qualification.\(qualified)")
                    if let seq6Control {
                        guard seq6Control.reopening, seq6Control.state.scenario == .corruptBody, !qualified else {
                            throw SyncStoreGenerationError.activationReadBackFailed
                        }
                        seq6Control.armed = true
                        try seq6DeniedWriterReadback(reopening: true)
                        hasStarted = true
                        isPreparedForRoot = true
                        facts.insert("task145.seq6.corrupt-reopen-denied")
                        refreshAutomaticObservation()
                        return
                    }
                    guard qualified else {
                        facts.insert("task144.controlled.reopen-terminal.not-run")
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    if t10Control != nil { try prepareT10Root(); return }
                    if r4Control != nil { try prepareR4Root(reopening: true); return }
                    if interruptionControl != nil {
                        try interruptionPrepareRoot()
                        return
                    }
                    if restartControl != nil {
                        guard try restartReadback(reopening: true) else {
                            throw SyncStoreGenerationError.activationReadBackFailed
                        }
                        // Freeze the readback before admission. UI may observe the
                        // root after its normal startup has already replayed A.
                        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                        restartControl?.qualifiedReopen = try encoder.encode(restartControl!.state)
                        transport.release()
                        hasStarted = true
                        isPreparedForRoot = true
                        startRestartObservation()
                        return
                    }
                    if let domainControl {
                        guard try domainReadback(reopening: true) else { throw SyncStoreGenerationError.activationReadBackFailed }
                        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                        domainControl.qualifiedReopen = try encoder.encode(domainControl.state)
                        transport.release()
                        hasStarted = true
                        isPreparedForRoot = true
                        startDomainObservation()
                        return
                    }
                    if let retryControl {
                        guard try retryReadback(reopening: true) else {
                            throw SyncStoreGenerationError.activationReadBackFailed
                        }
                        retryControl.isArmed = true
                        transport.release()
                        stateStore.reconcilePendingRecoveryJournal()
                        hasStarted = true
                        startRetryObservation()
                        isPreparedForRoot = true
                        return
                    }
                    if isolationControl != nil {
                        guard try isolationReadback(reopening: true) else { throw SyncStoreGenerationError.activationReadBackFailed }
                        transport.release(); hasStarted = true; isPreparedForRoot = true
                        startIsolationObservation(); return
                    }
                    if saveBControl != nil {
                        // This opt-in pending branch never weakens the original
                        // terminal-only reopen oracle used by the existing tests.
                        guard try saveBReadback(reopening: true) else {
                            throw SyncStoreGenerationError.activationReadBackFailed
                        }
                        transport.release()
                        hasStarted = true
                        isPreparedForRoot = true
                        startSaveBObservation()
                        return
                    }
                    let terminal: Bool
                    do {
                        terminal = try terminalReadback(observesReopenFailure: true)
                    } catch {
                        facts.insert("task144.controlled.reopen-terminal.throws")
                        throw error
                    }
                    facts.insert("task144.controlled.reopen-terminal.\(terminal)")
                    guard terminal else { throw SyncStoreGenerationError.activationReadBackFailed }
                    facts.formUnion(["task144.controlled.reopened", "task144.controlled.queue-empty-no-duplicates"])
                    hasStarted = true
                    isPreparedForRoot = true
                    return
                }
                if !emptyBootstrap {
                    setupStage = .initialRecovery
                    _ = try await recoveryService().recoverFromRemoteSnapshot(ownerUserID: owner)
                    setupStage = .postInitialScope
                    guard await controller.awaitLocalBodyQualification() else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
                if r4Control != nil { try prepareR4Root(reopening: false); return }
                if Task145PerformanceConfiguration.mode == "seed" {
                    let context = ModelContext(controller.modelContainer)
                    guard try context.fetchCount(FetchDescriptor<Product>()) == 20_000,
                          try context.fetchCount(FetchDescriptor<ProductPrice>()) == 40_000,
                          try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0 else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    guard let directory = transport.performance?.directory,
                          try context.fetchCount(FetchDescriptor<Supplier>()) == 2,
                          try context.fetchCount(FetchDescriptor<ProductCategory>()) == 2,
                          try context.fetchCount(FetchDescriptor<HistoryEntry>()) == 0 else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    // Dataset relationships are checked only in the excluded seed process.
                    let seededProducts = try context.fetch(FetchDescriptor<Product>())
                    let seededPrices = try context.fetch(FetchDescriptor<ProductPrice>())
                    guard seededPrices.allSatisfy({ $0.product?.remoteID != nil }),
                          seededProducts.filter({ $0.supplier != nil }).count == 1,
                          seededProducts.filter({ $0.category != nil }).count == 1,
                          seededProducts.first(where: { $0.remoteID == Task145PerformanceConfiguration.targetID })?.supplier?.remoteID == Task145PerformanceConfiguration.supplierIDs[0],
                          seededProducts.first(where: { $0.remoteID == Task145PerformanceConfiguration.targetID })?.category?.remoteID == Task145PerformanceConfiguration.categoryIDs[0] else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    performanceSeedManifest = try String(contentsOf: directory.appendingPathComponent("manifest.json"), encoding: .utf8)
                    hasStarted = true; facts.insert("task145.perf.seed-qualified")
                }
                if r23ShellMode == "seed" {
                    guard controller.activeManifest != nil,
                          try ModelContext(controller.modelContainer).fetchCount(FetchDescriptor<Product>()) == 1 else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    hasStarted = true
                    facts.insert("task144.r23.seed-qualified")
                }
                if interruptionControl != nil {
                    try interruptionPrepareRoot()
                    return
                }
// TASK145_SCOPE_SWITCH_INSERT_BEGIN prepare-C-body
                if scopeSwitchControl != nil { try prepareScopeSwitch() }
// TASK145_SCOPE_SWITCH_INSERT_END prepare-C-body
                if seq6Control != nil { try await prepareSeq6() }
                if let retryControl {
                    guard let manifest = controller.activeManifest,
                          let binding = AccountBindingStore().currentBinding,
                          AccountBindingStore().beginSameScopeRecovery(accountHash: binding.accountHash,
                            storeIdentity: binding.storeIdentity, reason: "TASK145_REAL_RETRY_MIXED"),
                          let journal = AccountBindingStore().pendingRecoveryJournal,
                          journal.mode == .sameScopeRecovery, journal.phase == .prepared else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    retryControl.state.generationID = manifest.generationID
                    retryControl.state.journalIdentity = SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal)
                    try retryControl.persist()
                    controller.startLocalBodyQualification(ownerUserID: owner)
                    guard await controller.awaitLocalBodyQualification() else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    retryControl.isArmed = true
                    transport.release()
                    stateStore.reconcilePendingRecoveryJournal()
                    hasStarted = true // Actual recovery belongs exclusively to the normal app coordinator.
                    startRetryObservation()
                }
                try prepareHistoryFeedbackLocalSuccess()
                if isolationControl != nil {
                    try seedIsolation()
                    transport.release(); hasStarted = true; isPreparedForRoot = true
                    startIsolationObservation(); return
                }
                isPreparedForRoot = true
            } catch {
                recordSetupFailure(error, stage: setupStage)
            }
        }
    }

    /// Called after the real root has completed its ordinary shop refresh and
    /// bootstrap. This fixture never manually submits or drains a business run.
    func startIfNeeded() {
// TASK145_SCOPE_SWITCH_INSERT_BEGIN C-root-startup
        if scopeSwitchControl != nil {
            guard isPreparedForRoot, !hasStarted else { return }
            startScopeSwitch()
            return
        }
// TASK145_SCOPE_SWITCH_INSERT_END C-root-startup
        guard isPreparedForRoot, !hasStarted else { return }
        hasStarted = true
        if restartControl != nil {
            // Sequence 2 uses the already qualified initial generation. There
            // is no unfinished recovery journal to reconstruct at reopen.
            facts.insert("task145.restart.admission-held")
            startRestartObservation()
            return
        }
        // Owned above the App's generation .id; activation must not cancel it.
        task = Task { [weak self] in
            guard let self else { return }
            var setupStage = SetupStage.heldJournal
            do {
                guard authViewModel.isSignedIn,
                      authViewModel.localMutationOwnerUserID == owner,
                      shopContextStore.context.syncAllowed else { throw URLError(.timedOut) }
                setupStage = .heldJournal
                if domainControl != nil {
                    domainOldContainer = controller.modelContainer
                    domainOldLease = controller.captureLease(for: controller.modelContainer)
                }
                if let binding = AccountBindingStore().currentBinding {
                    guard AccountBindingStore().beginSameScopeRecovery(accountHash: binding.accountHash,
                        storeIdentity: binding.storeIdentity, reason: "TASK144_CONTROLLED_ROOT_HELD",
                        deviceIdentityHash: DeviceInstallIDStore.identityHash(for: try DeviceInstallIDStore().requireDeviceInstallID())) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
                heldRecoveryScope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                    allowsPendingSameScopeRecovery: true)
                transport.holdsProducts = true
                heldGenerationID = controller.activeManifest?.generationID
                stateStore.updatePhase(.checking)
                setupStage = .heldRecovery
                let recovery = Task {
                    do {
                        return try await self.recoveryService().recoverFromRemoteSnapshot(ownerUserID: self.owner)
                    } catch {
                        if !self.rememberPublishedShopUnavailability(error) {
                            self.recordSetupFailure(error, stage: .heldRecovery)
                        }
                        throw error
                    }
                }
                defer { recovery.cancel() }
                while !transport.isReleased {
                    if t10Control != nil {
                        _ = try t10Readback(beforeActivation: true)
                    } else if domainControl != nil {
                        _ = try domainReadback(heldPage: true)
                    } else if try durableSaveReadback() {
                        if !facts.contains("task144.controlled.local-save-durable") {
                            facts.insert("task144.controlled.local-save-durable")
                        }
                        if provesIndependentPending, !independentPendingInserted {
                            try insertIndependentPendingHistory()
                        }
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let summary: SyncRecoverySnapshotPullSummary?
                Task144RootObservation.record("fixture-recovery-value", "branch.before-await", callsite: "Task144.startIfNeeded")
                do {
                    summary = try await recovery.value
                    Task144RootObservation.record("fixture-recovery-value", "branch.returned.completed-journal.\(summary?.completedRecoveryJournal == true)", callsite: "Task144.startIfNeeded")
                }
                catch {
                    Task144RootObservation.record("fixture-recovery-value", "branch.threw.kind.\(Self.failureKind(error)).category.\(Task144RootObservation.errorCategory(error))", callsite: "Task144.startIfNeeded")
                    // Only the first actual throw's verified published boundary
                    // may wait for the ordinary automatic runtime to resume.
                    guard error as? Task126OwnerStoreGateError == .shopContextUnavailable,
                          awaitingAutomaticResumeManifest != nil else { throw error }
                    Task144RootObservation.record("fixture-recovery-value", "branch.automatic-resume-admitted", callsite: "Task144.startIfNeeded")
                    summary = nil
                }
                if let summary {
                    guard summary.completedRecoveryJournal, controller.activeManifest != nil else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    facts.insert("task144.controlled.activated")
                    if hasR23DraftReview {
                        observeR23DraftState()
                        return // This mode observes draft/cutover, not the ordinary saved-name drain oracle.
                    }
                }
                setupStage = .automaticTerminal
                // No direct push or synthetic ACK here. The real root observes
                // the resolved shop/local mutation and runs its normal facade.
                for _ in 0..<300 {
                    refreshAutomaticObservation()
                    let activated: Bool
                    if summary != nil { activated = true }
                    else if let returned = completedAutomaticRecoverySummary,
                            let published = awaitingAutomaticResumeManifest {
                        activated = automaticRecoveryCompletionIsCurrent(returned, manifest: published)
                        if activated { facts.insert("task144.controlled.activated") }
                    } else { activated = false }
                    if activated {
                        if domainControl != nil { startDomainObservation(); return }
                        if saveBControl != nil {
                            startSaveBObservation()
                            return
                        }
                        if summary == nil, emptyBootstrap { return }
                        if provesRelatedSave, try relatedMappingPendingReadback() {
                            facts.insert("task144.controlled.related-mapped-product-pending")
                        }
                        if provesRelatedSave, try relatedProductACKReadback() {
                            facts.insert("task144.controlled.related-save-ack")
                            return
                        }
                        if provesIndependentPending, try productACKWithIndependentPendingReadback() {
                            facts.insert("task144.controlled.product-ack-other-pending")
                            return
                        }
                        if try terminalReadback(), catalogRemote.attemptCount == 1, catalogRemote.eventCount == 1 {
                            facts.formUnion(["task144.controlled.activated-and-drained", "task144.controlled.queue-empty-no-duplicates"])
                            return
                        }
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw SyncStoreGenerationError.activationReadBackFailed
            } catch {
                recordSetupFailure(error, stage: setupStage)
            }
        }
    }

    /// TEST-only scheduling of the existing async heartbeat callback. It grants
    /// no scope or readiness and is inactive outside its explicit namespace.
    func awaitControlledShopHeartbeatForOrderingProof() async -> Bool {
        guard provesShopCallbackOrder, !callbackHeartbeatEntered else { return false }
        callbackHeartbeatEntered = true
        facts.insert("task144.controlled.previous-shop-callback-entered")
        Task144RootObservation.record("fixture-boundary", "branch.existing-previous-callback-entered", callsite: "Task144.awaitControlledShopHeartbeatForOrderingProof")
        await withCheckedContinuation { callbackHeartbeatContinuation = $0 }
        facts.insert("task144.controlled.previous-shop-callback-released")
        Task144RootObservation.record("fixture-boundary", "branch.existing-previous-callback-released", callsite: "Task144.awaitControlledShopHeartbeatForOrderingProof")
        return true
    }

    func noteControlledShopHeartbeatCompleted() {
        guard provesShopCallbackOrder, callbackHeartbeatEntered else { return }
        callbackHeartbeatCompleted = true
        callbackCompletionContinuation?.resume(); callbackCompletionContinuation = nil
    }

    private func releasePreviousShopCallbackAtCheckpoint() async {
        guard provesShopCallbackOrder, transport.holdsProducts, !transport.isReleased else { return }
        guard callbackHeartbeatEntered else { return }
        callbackHeartbeatContinuation?.resume(); callbackHeartbeatContinuation = nil
        if !callbackHeartbeatCompleted {
            await withCheckedContinuation { callbackCompletionContinuation = $0 }
        }
    }

    /// TEST-only value observation. This does not authorize, trigger or retry recovery.
    private func rememberPublishedShopUnavailability(_ error: Error) -> Bool {
        guard error as? Task126OwnerStoreGateError == .shopContextUnavailable,
              let scope = heldRecoveryScope, scope.ownerUserID == owner,
              authViewModel.isSignedIn, authViewModel.localMutationOwnerUserID == scope.ownerUserID,
              UserDefaults.standard.string(forKey: "mobile.shopContext.activeAccountHash.v1") == scope.accountHash,
              let selected = SelectedShopStore().selectedShop(accountHash: scope.accountHash),
              selected.shopID == scope.shopID, selected.localStoreIdentity == scope.storeIdentity,
              selected.selectable, selected.status == "active",
              let device = try? DeviceInstallIDStore().requireDeviceInstallID(),
              device == scope.deviceInstallID, DeviceInstallIDStore.identityHash(for: device) == scope.deviceIdentityHash,
              !SelectedShopStore().hasConfirmedDeviceDenial(accountHash: scope.accountHash,
                shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash),
              let binding = AccountBindingStore().currentBinding,
              binding.accountHash == scope.accountHash, binding.storeIdentity == scope.storeIdentity,
              let manifest = controller.activeManifest,
              manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
              manifest.storeIdentity == scope.storeIdentity, manifest.deviceIdentityHash == scope.deviceIdentityHash,
              let journal = AccountBindingStore().pendingRecoveryJournal,
              journal.mode == .sameScopeRecovery, journal.phase == .activated,
              journal.replacement == scope.pendingReplacement, journal.deviceIdentityHash == scope.deviceIdentityHash,
              journal.generationID == manifest.generationID, journal.checkpointDigest == manifest.checkpoint.checkpointDigest,
              journal.watermark == manifest.checkpoint.maxEventID, journal.baselineRunID == manifest.baselineRunID else { return false }
        // Preserve the first throw's actual publication before a future real
        // automatic completion may clear its journal. No readiness fact is made.
        awaitingAutomaticResumeManifest = manifest
        return true
    }

    private func automaticRecoveryCompletionIsCurrent(
        _ summary: SyncRecoverySnapshotPullSummary, manifest: SyncStoreGenerationManifest
    ) -> Bool {
        guard transport.isReleased, let initial = heldRecoveryScope,
              summary.completedRecoveryJournal, summary.activatedGenerationID == manifest.generationID,
              summary.watermarkAfter == manifest.checkpoint.maxEventID,
              controller.activeManifest == manifest, !AccountBindingStore().hasPendingReplacementJournal,
              authViewModel.isSignedIn, authViewModel.localMutationOwnerUserID == initial.ownerUserID,
              let current = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: initial.ownerUserID),
              current.ownerUserID == initial.ownerUserID, current.accountHash == initial.accountHash,
              current.shopID == initial.shopID, current.storeIdentity == initial.storeIdentity,
              current.deviceInstallID == initial.deviceInstallID, current.deviceIdentityHash == initial.deviceIdentityHash,
              current.pendingReplacement == nil,
              manifest.accountHash == current.accountHash, manifest.shopID == current.shopID,
              manifest.storeIdentity == current.storeIdentity, manifest.deviceIdentityHash == current.deviceIdentityHash,
              (try? Task126OwnerStoreGate.revalidateAutomaticScope(current)) != nil,
              (try? controller.isActiveRecoveryFinalized(scope: current)) == true,
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                ownerUserID: current.ownerUserID) else { return false }
        return true
    }

    private func observeAutomaticRecoverySummary(ownerUserID: UUID, summary: SyncRecoverySnapshotPullSummary) {
        if t10Control?.reopening == true {
            guard ownerUserID == owner, summary.completedRecoveryJournal,
                  let generationID = summary.activatedGenerationID,
                  let finalization = summary.verifiedFinalization,
                  finalization.generationID == generationID,
                  finalization.watermark == summary.watermarkAfter else { return }
            // This is the exact value returned by the real observed provider.
            // The T10 poll revalidates its current manifest after a root remount.
            completedAutomaticRecoverySummary = summary
            return
        }
        guard ownerUserID == owner, summary.completedRecoveryJournal,
              let manifest = awaitingAutomaticResumeManifest ?? controller.activeManifest,
              controller.activeManifest == manifest,
              summary.activatedGenerationID == manifest.generationID,
              summary.watermarkAfter == manifest.checkpoint.maxEventID else { return }
        // Retain only the real returned value here. The existing wait loop must
        // independently admit current scope/body/finalization before any fact.
        completedAutomaticRecoverySummary = summary
    }

    private func recordSetupFailure(_ error: Error, stage: SetupStage) {
        facts.formUnion([
            "task144.controlled.failure",
            "task144.controlled.failure-stage.\(stage.rawValue)",
            "task144.controlled.failure-kind.\(Self.failureKind(error))",
            "task144.controlled.auth-signed-in.\(authViewModel.isSignedIn)",
            "task144.controlled.auth-owner-present.\(authViewModel.localMutationOwnerUserID != nil)",
            "task144.controlled.shop-resolved.\(shopContextStore.context.syncAllowed)",
            "task144.controlled.active-manifest.\(controller.activeManifest != nil)",
            "task144.controlled.recovery-journal.\(AccountBindingStore().hasPendingReplacementJournal)"
        ])
        if stage == .heldRecovery || stage == .automaticTerminal {
            facts.insert("task144.controlled.failure-new-generation.\(controller.activeManifest?.generationID != heldGenerationID)")
            if let journal = AccountBindingStore().pendingRecoveryJournal {
                facts.insert("task144.controlled.failure-journal-phase.\(journal.phase.rawValue)")
            }
        }
        do {
            _ = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                allowsPendingSameScopeRecovery: true)
            facts.insert("task144.controlled.failure-scope.accepted")
        } catch {
            facts.insert("task144.controlled.failure-scope.\(Self.failureKind(error))")
        }
    }

    /// Closed categories only: neither error descriptions nor scope values
    /// become UI-test attachments or console metadata.
    private static func failureKind(_ error: Error) -> String {
        if let error = error as? Task126OwnerStoreGateError {
            switch error {
            case .cancelled: return "scope-cancelled"
            case .activeAccountMismatch: return "scope-account-mismatch"
            case .shopContextUnavailable: return "scope-shop-unavailable"
            case .bindingMismatch: return "scope-binding-mismatch"
            case .replacementInterrupted: return "scope-replacement-interrupted"
            case .scopeChanged: return "scope-changed"
            case .retiredStoreGeneration: return "scope-retired-generation"
            case .localModelUnavailable: return "scope-local-model-unavailable"
            case .localRemoteConflictRequiresReview: return "scope-local-remote-conflict"
            }
        }
        if let error = error as? AtomicGenerationRecoveryError {
            switch error {
            case .journalTransitionRejected: return "journal-transition-rejected"
            case .journalCompletionRejected: return "journal-completion-rejected"
            case .pendingLocalWorkRequiresDrain: return "pending-local-work"
            }
        }
        if let error = error as? SyncStoreGenerationError {
            switch error {
            case .activationReadBackFailed: return "generation-readback-failed"
            case .staleGenerationLease: return "generation-stale-lease"
            case .stagingScopeChanged: return "generation-staging-scope-changed"
            case .stagingChangedAfterVerification: return "generation-staging-changed"
            default: return "generation-other"
            }
        }
        if let error = error as? URLError {
            switch error.code {
            case .timedOut: return "transport-timeout"
            case .cancelled: return "transport-cancelled"
            default: return "transport-other"
            }
        }
        if error is CancellationError { return "task-cancelled" }
        if let error = error as? ShopSyncRecoveryContractError {
            switch error {
            case .authenticationChanged: return "contract-authentication-changed"
            case .checkpointChanged: return "contract-checkpoint-changed"
            case .scopeFenceMissing: return "contract-scope-fence-missing"
            case .markerNotVerified: return "contract-marker-not-verified"
            case .fullRecoveryRequired: return "contract-full-recovery-required"
            default: return "recovery-contract-other"
            }
        }
        return "other"
    }

    func release() {
        if r23ShellMode == "hold" {
            r23QualificationReleased = true
            let waiters = r23QualificationWaiters
            r23QualificationWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        if seq6Control != nil { startSeq6SafetyFault(); return }
        if let restartControl {
            guard restartControl.state.scenario == .postCommit,
                  facts.contains("task145.restart.admission-held") else { return }
            transport.release() // Availability only; never submit a business run.
            facts.insert("task145.restart.availability-restored")
            return
        }
        if retryControl != nil { return } // T05 has no control that triggers or advances recovery.
        if let saveBControl, transport.isReleased {
            // These controls only restore the remote response/admission. They
            // never call run, push, refresh, Retry or mutate the client queue.
            if facts.contains("task145.save-b.b-durable-a-held") { saveBControl.releaseA = true }
            if facts.contains("task145.save-b.pending-reopened") { saveBControl.releaseB = true }
            return
        }
        cancelEmptyFenceInitialRequest(stage: "cancelled-by-release")
        facts.remove("task144.controlled.held")
        facts.insert("task144.controlled.released")
        transport.release()
        catalogRemote.releaseHeldProduct()
    }
    /// Opt-in peer stimulus for the real editor discriminator. The ordinary
    /// targeted fetch/apply path supplies scope validation, identity and fence.
    func publishR23EditorPeerChange() {
        guard provesR23EditorConflict, !r23EditorPeerApplyStarted,
              let scope = heldRecoveryScope, !transport.isReleased else { return }
        r23EditorPeerApplyStarted = true
        Task {
            do {
                let result = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                    _ = try catalogRemote.publishR23EditorPeerValues()
                    // Use the complete production incremental transaction: it
                    // records the qualified row proof and refreshes the physical
                    // local-write fence before publishing a changed business row.
                    return try await SyncEventIncrementalPullService(modelContainer: controller.modelContainer,
                        remote: catalogRemote).applyIncrementalRemoteChanges(ownerUserID: owner)
                }
                guard result.productsUpdated == 1, result.eventsProcessed == 1,
                      result.watermarkBefore == 41, result.watermarkAfter == 42,
                      !result.requiresFullRecovery else { throw SyncStoreGenerationError.activationReadBackFailed }
                try requireR23EditorNoPartialSave()
                facts.insert("task145.editor.peer-applied")
            } catch {
                facts.insert("task145.editor.peer-apply-failed.\(Self.failureKind(error))")
            }
        }
    }

    func observeR23EditorNoPartialSave() {
        guard provesR23EditorConflict else { return }
        do {
            try requireR23EditorNoPartialSave()
            facts.insert("task145.editor.no-partial-save")
        } catch {
            facts.insert("task145.editor.partial-save-readback-failed")
        }
    }

    private func requireR23EditorNoPartialSave() throws {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        guard Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer, ownerUserID: owner),
              products.count == 1,
              products[0].productName == "R23 peer name", products[0].itemNumber == "R23 peer item",
              pending.isEmpty, catalogRemote.attemptCount == 0, !transport.isReleased else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }

    /// Controlled peer data, delivered by the complete production incremental
    /// reader/apply. No draft mutation, writer, proof grant or synthetic ACK.
    func publishR23DraftPeer() {
        guard let scenario = r23DraftReviewScenario, !r23DraftOperationInFlight,
              r23DraftPeerStep < (scenario == "deleted-rebind" ? 1 : 2) else { return }
        r23DraftOperationInFlight = true
        Task {
            defer { r23DraftOperationInFlight = false; observeR23DraftState() }
            do {
                let step = r23DraftPeerStep + 1
                let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                    allowsPendingSameScopeRecovery: true)
                let result = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                    try catalogRemote.publishR23DraftPeerValues(scenario: scenario, step: step)
                    return try await SyncEventIncrementalPullService(modelContainer: controller.modelContainer,
                        remote: catalogRemote).applyIncrementalRemoteChanges(ownerUserID: owner)
                }
                guard result.eventsProcessed == 1, result.targetedProductsFetched == 1,
                      result.watermarkBefore == Int64(40 + step), result.watermarkAfter == Int64(41 + step),
                      !result.requiresFullRecovery,
                      (scenario == "deleted-rebind" ? result.productsTombstoned == 1 : result.productsUpdated == 1) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                let context = ModelContext(controller.modelContainer)
                let rows = try context.fetch(FetchDescriptor<Product>())
                guard Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
                      Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                        ownerUserID: owner), try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0 else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                if scenario != "deleted-rebind" {
                    guard rows.count == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
                    r23DraftPeerFingerprint = LocalPendingChangeLogicalKey.productFingerprintHash(rows[0])
                } else {
                    guard rows.count == 1, rows[0].remoteDeletedAt != nil else { throw SyncStoreGenerationError.activationReadBackFailed }
                }
                r23DraftPeerStep = step
                facts.insert("task145.r3.peer-applied.\(step)")
            } catch { facts.insert("task145.r3.peer-failed.\(Self.failureKind(error))") }
        }
    }

    /// A second bounded recovery through the existing production service. The
    /// controlled server keeps the same tombstone/checkpoint for every page.
    func recoverR23DeletedDraft() {
        guard r23DraftReviewScenario == "deleted-rebind", r23DraftPeerStep == 1,
              !r23DraftOperationInFlight, !r23DraftSecondRecoveryComplete,
              transport.isReleased, let before = controller.activeManifest,
              before.generationID != heldGenerationID else { return }
        r23DraftOperationInFlight = true
        Task {
            defer { r23DraftOperationInFlight = false; observeR23DraftState() }
            do {
                let context = ModelContext(controller.modelContainer)
                let tombstones = try context.fetch(FetchDescriptor<Product>())
                guard tombstones.count == 1, tombstones[0].remoteDeletedAt != nil,
                      try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0,
                      let binding = AccountBindingStore().currentBinding,
                      AccountBindingStore().beginSameScopeRecovery(accountHash: binding.accountHash,
                        storeIdentity: binding.storeIdentity, reason: "TASK145_R3_DELETED_DRAFT_REBIND",
                        deviceIdentityHash: before.deviceIdentityHash) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                let summary = try await recoveryService().recoverFromRemoteSnapshot(ownerUserID: owner)
                let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
                guard let after = controller.activeManifest, after.generationID != before.generationID,
                      summary.completedRecoveryJournal, summary.activatedGenerationID == after.generationID,
                      summary.watermarkAfter == 42, after.checkpoint.maxEventID == 42,
                      !AccountBindingStore().hasPendingReplacementJournal,
                      try controller.isActiveRecoveryFinalized(scope: scope),
                      Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
                      Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                        ownerUserID: owner) else { throw SyncStoreGenerationError.activationReadBackFailed }
                r23DraftSecondRecoveryComplete = true
                facts.insert("task145.r3.deleted-rebound")
            } catch { facts.insert("task145.r3.rebind-failed.\(Self.failureKind(error))") }
        }
    }

    /// Every observation reopens a ModelContext. No historical terminal flag
    /// substitutes for the product, pending-token, authority and generation read.
    func observeR23DraftState() {
        guard hasR23DraftReview else { return }
        r23DraftObservation += 1
        var value: [String: Any] = ["observation": r23DraftObservation, "namespace": namespace.uuidString.lowercased(),
            "peerStep": r23DraftPeerStep, "secondRecovery": r23DraftSecondRecoveryComplete,
            "productWriteEntries": r23DraftProductWriteEntries, "eventEntries": r23DraftEventEntries,
            "transportReleased": transport.isReleased, "operationInFlight": r23DraftOperationInFlight,
            "failureFacts": facts.filter { $0.hasPrefix("task145.r3.") && $0.contains("failed") }.sorted()]
        do {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                allowsPendingSameScopeRecovery: true)
            let context = ModelContext(controller.modelContainer); context.autosaveEnabled = false
            let products = try context.fetch(FetchDescriptor<Product>())
            let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
            let tokens = pending.map(LocalPendingChangeCASToken.init)
            value["status"] = "FRESH_QUALIFIED_READ"
            value["generation"] = controller.activeManifest?.generationID.uuidString
            value["generationChanged"] = controller.activeManifest?.generationID != heldGenerationID
            value["bodyProof"] = Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer)
            value["localAccess"] = Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: controller.modelContainer, ownerUserID: owner)
            value["activeProducts"] = products.filter { $0.remoteDeletedAt == nil }.count
            value["tombstones"] = products.filter { $0.remoteDeletedAt != nil }.count
            value["products"] = products.map { ["remoteID": $0.remoteID?.uuidString.lowercased() ?? "",
                "barcode": $0.barcode, "name": $0.productName ?? "",
                "item": $0.itemNumber ?? "", "second": $0.secondProductName ?? "",
                "fingerprint": LocalPendingChangeLogicalKey.productFingerprintHash($0)] }
            value["pending"] = try tokens.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) }
            value["pendingStatuses"] = pending.map(\.statusRaw)
            value["pendingFields"] = pending.map(\.changedFieldsRaw)
            value["pendingBaseIsPeer"] = pending.count == 1 && pending[0].baselineFingerprintHash == r23DraftPeerFingerprint
            value["pendingMatchesProduct"] = products.count == 1 && pending.count == 1
                && products[0].remoteID != nil && products[0].remoteID == catalogRemote.recoverySnapshot.product?.id
                && pending[0].entityKind == .product && pending[0].entityRemoteID == products[0].remoteID
                && pending[0].logicalKey == LocalPendingChangeLogicalKey.product(remoteID: products[0].remoteID,
                    barcode: products[0].barcode) && pending[0].recordSchemaVersion == 1
                && LocalPendingChangeScopeMatcher.matches(pending[0], ownerUserID: scope.ownerUserID,
                    accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)
                && pending[0].intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(products[0])
            value["prices"] = try context.fetchCount(FetchDescriptor<ProductPrice>())
            value["outbox"] = try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>())
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        } catch { value["status"] = "READ_REJECTED"; value["error"] = Self.failureKind(error) }
        if let bytes = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
            r23DraftLedger = bytes.base64EncodedString()
        }
    }

    func observeRootPresentation() {
        guard ProcessInfo.processInfo.environment["TASK145_ROOT_PRESENTATION_OBSERVATION"] == "1" else { return }
        rootPresentationObservationOrdinal += 1
        // Reads current presentation/owner metadata only, never model records,
        // admission, runtime dispatch, phase setters or durable state.
        let outcome: String
        switch stateStore.state.lastOutcome {
        case .succeeded?: outcome = "succeeded"
        case .noWork?: outcome = "noWork"
        case .failed?: outcome = "failed"
        case .busy?: outcome = "busy"
        case .cancelled?: outcome = "cancelled"
        case .scheduledRetry?: outcome = "scheduledRetry"
        case .blocked?: outcome = "blocked"
        case nil: outcome = "none"
        }
        let values: [String: Any] = ["observation": rootPresentationObservationOrdinal,
            "namespace": namespace.uuidString.lowercased(), "presentationID": controller.presentationID,
            "hasActivePresentationInvocation": stateStore.hasActivePresentationInvocation,
            "phase": String(describing: stateStore.state.phase),
            "outcome": outcome,
            "held": facts.contains("task144.controlled.held"), "released": transport.isReleased]
        rootPresentationObservation = (try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]).base64EncodedString()) ?? "invalid"
    }

    func publishCheckingUpdate() {
        Task144ControlGestureObservation.record("function-entry", control: "state-update")
        cancelEmptyFenceInitialRequest(stage: "cancelled-by-phase-control")
        Task144ControlGestureObservation.record("after-cancel", control: "state-update")
        Task144ControlGestureObservation.record("before-failed-update", control: "state-update")
        stateStore.updatePhase(.failed, outcome: .failed)
        Task144ControlGestureObservation.record("after-failed-update", control: "state-update")
        stateStore.updatePhase(.checking)
        Task144ControlGestureObservation.record("after-checking-update", control: "state-update")
        facts.insert("task144.controlled.state-updated")
        Task144ControlGestureObservation.record("after-fact-insert.present.\(facts.contains("task144.controlled.state-updated"))", control: "state-update")
    }

    /// Opt-in file metadata drift in this run's synthetic empty store. The
    /// production view must schedule its own successor qualification.
    func invalidateEmptyRootPhysicalFence() {
        guard provesEmptyFenceRequalification, emptyBootstrap,
              !facts.contains("task144.controlled.empty-fence.invalidated"),
              !emptyFenceInitialRequestWasStarted else { return }
        emptyFenceInitialRequestWasStarted = true
        let request = Task144EmptyFenceInitialRequest(initialRevision: controller.localBodyQualificationRevision)
        emptyFenceInitialRequest = request
        // Subscribe before the first admission check. A truthful pending fact
        // then causes the same normal view reevaluation as the former failure.
        emptyFenceInitialSubscription = controller.$localBodyQualificationRevision.dropFirst().sink { [weak self, weak request] published in
            Task { @MainActor [weak self, weak request] in
                guard let self, let request, self.emptyFenceInitialRequest === request,
                      self.controller.localBodyQualificationRevision == published else { return }
                self.attemptEmptyRootPhysicalFence(request: request, revisionSignal: published)
            }
        }
        emptyFenceInitialExpiry = Task { @MainActor [weak self, weak request] in
            guard let request else { return }
            do { try await Task.sleep(until: request.deadline, clock: .continuous) }
            catch { return }
            guard let self, self.emptyFenceInitialRequest === request, request.expire() else { return }
            self.cancelEmptyFenceInitialRequest(stage: "initial-admission-timeout")
        }
        attemptEmptyRootPhysicalFence(request: request, revisionSignal: nil)
    }

    private func cancelEmptyFenceInitialRequest(stage: String? = nil) {
        guard let request = emptyFenceInitialRequest else { return }
        request.cancel()
        emptyFenceInitialSubscription?.cancel()
        emptyFenceInitialSubscription = nil
        emptyFenceInitialExpiry?.cancel()
        emptyFenceInitialExpiry = nil
        emptyFenceInitialAnchors = nil
        emptyFenceInitialRequest = nil
        facts.remove("task144.controlled.empty-fence.waiting-initial-admission")
        if let stage {
            facts.formUnion(["task144.controlled.empty-fence.failure",
                "task144.controlled.empty-fence.failure-stage.\(stage)"])
        }
    }

    private func attemptEmptyRootPhysicalFence(request: Task144EmptyFenceInitialRequest, revisionSignal: Int?) {
        guard emptyFenceInitialRequest === request, request.isPending else { return }
        guard request.isBeforeDeadline else {
            cancelEmptyFenceInitialRequest(stage: "initial-admission-timeout")
            return
        }
        var stage = "capture-scope"
        var firstFailedPrerequisite: String?
        func prerequisite(_ value: Bool, _ name: String) -> Bool {
            if !value, firstFailedPrerequisite == nil { firstFailedPrerequisite = name }
            return value
        }
        do {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                allowsPendingReplacement: true)
            let phase = stateStore.state.phase
            let container = controller.modelContainer
            let revision = controller.localBodyQualificationRevision
            stage = "initial-prerequisites"
            guard prerequisite(facts.contains("task144.controlled.held"), "held"),
                  prerequisite(!transport.isReleased, "transport-held"),
                  prerequisite(authViewModel.localMutationOwnerUserID == owner, "owner"),
                  prerequisite(controller.activeManifest == nil, "no-manifest"),
                  prerequisite(revision > 0, "qualification-revision") else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            if let anchors = emptyFenceInitialAnchors {
                guard prerequisite(scope == anchors.scope, "initial-scope-unchanged"),
                      prerequisite(phase == anchors.phase, "initial-phase-unchanged"),
                      prerequisite(container === anchors.container, "initial-container-unchanged") else {
                    _ = request.evaluate(admitted: false, revisionSignal: revisionSignal, anchorsUnchanged: false)
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
            } else {
                emptyFenceInitialAnchors = EmptyFenceInitialAnchors(scope: scope, phase: phase, container: container)
            }
            let admitted = controller.permitsScopedEmptyRoot(ownerUserID: owner)
            if !admitted {
                switch request.evaluate(admitted: false, revisionSignal: revisionSignal, anchorsUnchanged: true) {
                case .waiting:
                    facts.insert("task144.controlled.empty-fence.waiting-initial-admission")
                case .expired:
                    cancelEmptyFenceInitialRequest(stage: "initial-admission-timeout")
                default:
                    cancelEmptyFenceInitialRequest(stage: "initial-admission-aborted")
                }
                return
            }
            guard prerequisite(!Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: container, ownerUserID: owner), "no-local-mutation-grant"),
                  prerequisite(AccountBindingStore().hasPendingReplacementJournal, "pending-journal") else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            stage = "capture-initial-fence"
            let before = try ownedRepository.captureActiveMutationFence(for: controller.active)
            stage = "initial-file-metadata"
            let values = try ownedLegacyStoreURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey,
                .contentModificationDateKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let modificationDate = values.contentModificationDate else {
                throw SyncStoreGenerationError.activeStoreMissing
            }
            switch request.evaluate(admitted: true, revisionSignal: revisionSignal, anchorsUnchanged: true) {
            case .ready: break
            case .waiting:
                facts.insert("task144.controlled.empty-fence.waiting-initial-admission")
                return
            case .expired:
                cancelEmptyFenceInitialRequest(stage: "initial-admission-timeout")
                return
            default:
                cancelEmptyFenceInitialRequest(stage: "initial-admission-aborted")
                return
            }
            // Disarm both initial observers before the one mutation and before
            // installing the unchanged post-mutation qualification observer.
            cancelEmptyFenceInitialRequest()
            facts.insert("task144.controlled.empty-fence.initially-admitted")
            stage = "physical-fence-invalidation"
            guard request.isBeforeDeadline else { throw SyncStoreGenerationError.activationReadBackFailed }
            try FileManager.default.setAttributes([.modificationDate: modificationDate.addingTimeInterval(-60)],
                ofItemAtPath: ownedLegacyStoreURL.path)
            stage = "invalidated-fence-readback"
            let after = try ownedRepository.captureActiveMutationFence(for: controller.active)
            guard before != after,
                  let beforeFile = before.files.first(where: { $0.relativePath == ownedLegacyStoreURL.lastPathComponent }),
                  let afterFile = after.files.first(where: { $0.relativePath == ownedLegacyStoreURL.lastPathComponent }),
                  beforeFile.modificationTimeBits != afterFile.modificationTimeBits,
                  controller.modelContainer === container,
                  try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                    allowsPendingReplacement: true) == scope,
                  stateStore.state.phase == phase,
                  !controller.permitsScopedEmptyRoot(ownerUserID: owner) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            // @Published emits from willSet. Hop to MainActor asynchronously so
            // both the revision and its proof have completed publication.
            emptyFenceQualificationSubscription = controller.$localBodyQualificationRevision.dropFirst().sink { [weak self] published in
                Task { @MainActor [weak self] in
                    guard let self, published != revision,
                          self.controller.localBodyQualificationRevision == published,
                          self.controller.modelContainer === container,
                          self.controller.activeManifest == nil,
                          self.authViewModel.localMutationOwnerUserID == self.owner,
                          self.stateStore.state.phase == phase,
                          !self.transport.isReleased,
                          (try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: self.owner,
                            allowsPendingReplacement: true)) == scope,
                          self.controller.permitsScopedEmptyRoot(ownerUserID: self.owner),
                          !Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: container, ownerUserID: self.owner),
                          AccountBindingStore().hasPendingReplacementJournal else { return }
                    self.facts.insert("task144.controlled.empty-fence.requalified")
                    self.emptyFenceQualificationSubscription = nil
                }
            }
            facts.insert("task144.controlled.empty-fence.invalidated")
            controller.objectWillChange.send()
        } catch {
            cancelEmptyFenceInitialRequest()
            var failureFacts: Set<String> = ["task144.controlled.empty-fence.failure",
                "task144.controlled.empty-fence.failure-stage.\(stage)",
                "task144.controlled.empty-fence.failure-kind.\(Self.failureKind(error))"]
            if let firstFailedPrerequisite {
                failureFacts.insert("task144.controlled.empty-fence.failure-prerequisite.\(firstFailedPrerequisite)")
            }
            facts.formUnion(failureFacts)
        }
    }

    func runtime(modelContainer: ModelContainer, stateStore: SyncStateStore) -> any SyncAutomaticRuntimeProviding {
// TASK145_SCOPE_SWITCH_INSERT_BEGIN C-runtime-factory
        if let scopeSwitchControl {
            return scopeSwitchRuntime(modelContainer: modelContainer, stateStore: stateStore, control: scopeSwitchControl)
        }
// TASK145_SCOPE_SWITCH_INSERT_END C-runtime-factory
        let lease = controller.captureLease(for: modelContainer)
        let invocationID = UUID()
        let recoveryProvider: (any SyncRecoverySnapshotPullProviding)?
        if Task145PerformanceConfiguration.measures {
            recoveryProvider = Task144ObservedAtomicRecoveryProvider(base: recoveryService(), observe: { [weak self] owner, summary in
                guard let self, owner == self.owner, let callID = Task145PerformanceCallContext.invocationID else { return }
                guard self.performanceSummaries.count < 64 || self.performanceSummaries[callID] != nil else {
                    self.performanceObservationCapacityExceeded = true; return
                }
                self.performanceSummaries[callID] = summary
            })
        } else if t10Control?.reopening == true, t10Control?.state.terminalGeneration == nil {
            recoveryProvider = Task144ObservedAtomicRecoveryProvider(base: recoveryService(),
                observe: { [weak self] ownerUserID, summary in
                    self?.observeAutomaticRecoverySummary(ownerUserID: ownerUserID, summary: summary)
                })
        } else if isolationControl != nil {
            // This scenario has a finalized baseline and no recovery journal.
            // An unexpected recovery request remains a real failed/no-provider run.
            recoveryProvider = nil
        } else if let interruptionControl, !interruptionControl.isSeed {
            recoveryProvider = Task144ObservedAtomicRecoveryProvider(base: recoveryService(),
                observe: { [weak self] ownerUserID, summary in
                    self?.observeAutomaticRecoverySummary(ownerUserID: ownerUserID, summary: summary)
                })
        } else if retryControl?.isArmed == true || seq6Control?.state.scenario == .snapshotChanged {
            recoveryProvider = Task144ObservedAtomicRecoveryProvider(base: recoveryService(),
                observe: { [weak self] ownerUserID, summary in
                    self?.observeAutomaticRecoverySummary(ownerUserID: ownerUserID, summary: summary)
                })
        } else if hasStarted, transport.isReleased, let published = controller.activeManifest,
           published.generationID != heldGenerationID {
            // A fresh remounted runtime can resume only after the direct held
            // recovery published. Preparation and the pre-cutover root keep nil.
            recoveryProvider = Task144ObservedAtomicRecoveryProvider(base: recoveryService(),
                observe: { [weak self] ownerUserID, summary in
                    self?.observeAutomaticRecoverySummary(ownerUserID: ownerUserID, summary: summary)
                })
        } else { recoveryProvider = nil }
        let actualIncremental = SyncEventIncrementalPullService(modelContainer: modelContainer,
            remote: catalogRemote, storeGenerationController: controller)
        let observedIncremental: any SyncIncrementalPullProviding
        if let seq6Control {
            observedIncremental = Task145Seq6ObservedIncrementalProvider(base: actualIncremental, control: seq6Control)
        } else { observedIncremental = actualIncremental }
        let catalogBase = CatalogPushService(modelContainer: modelContainer, remote: catalogRemote)
        let activityBase = SyncActivityRegistrationService(modelContainer: modelContainer, recorder: catalogRemote)
        let catalogProvider: any SyncCatalogPushProviding
        let activityProvider: any SyncActivityRegistrationProviding
        if let isolationControl {
            catalogProvider = Task145IsolationCatalogProvider(base: catalogBase) { result, error in isolationControl.observeCatalog(result, error: error) }
            activityProvider = Task145IsolationActivityProvider(base: activityBase) { result in isolationControl.observeActivity(result) }
        } else { catalogProvider = catalogBase; activityProvider = activityBase }
        let runtime = AutomaticSyncRuntimeFacade(authViewModel: authViewModel,
            catalogPushProvider: catalogProvider,
            productPriceProvider: Task145PerformanceConfiguration.measures || domainControl?.state.domain == .prices || r4Control != nil || t10Control != nil
                ? ProductPricePushService(modelContainer: modelContainer, remote: catalogRemote) : nil,
            historySessionProvider: domainControl?.state.domain == .history
                ? HistorySessionPushService(modelContainer: modelContainer, remote: catalogRemote, recorder: catalogRemote) : nil,
            incrementalPullProvider: observedIncremental,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: activityProvider,
            runAdmissionValidator: { [controller, transport, domainControl] in
                guard let lease else { throw SyncStoreGenerationError.staleGenerationLease }
                if let domainControl {
                    try await MainActor.run {
                        guard transport.isReleased else { throw URLError(.timedOut) }
                    }
                    try await domainControl.awaitCutoverAdmission()
                }
                try await MainActor.run {
                    if Task145PerformanceConfiguration.measures && Task145PerformanceConfiguration.offline { throw URLError(.notConnectedToInternet) }
                    guard Task145PerformanceConfiguration.measures || transport.isReleased else { throw URLError(.timedOut) }
                    try controller.validateLease(lease)
                }
            })
        let invocationObserver: ((UUID, Bool) -> Void)? = Task145PerformanceConfiguration.measures ? { [weak self] callID, started in
            guard let self else { return }
            if started {
                guard self.performanceInvocations.count < 64 else {
                    self.performanceObservationCapacityExceeded = true; return
                }
                self.performanceInvocations[callID] = runtime
                Task144RootObservation.performanceMark("runtimeAdmissionStarted", facts: callID.uuidString)
            } else {
                self.performanceInvocations.removeValue(forKey: callID)
                if self.performanceInvocations.isEmpty { self.performanceLastAllInvocationsFinishedNS = DispatchTime.now().uptimeNanoseconds }
            }
        } : nil
        let observed = Task144ObservedAutomaticRuntime(runtime: runtime, invocation: invocationObserver) { [weak self] action, result in
            if Task145PerformanceConfiguration.measures, let callID = Task145PerformanceCallContext.invocationID {
                if let self {
                    if self.performanceResults.count < 64 || self.performanceResults[callID] != nil {
                        self.performanceResults[callID] = result
                    } else { self.performanceObservationCapacityExceeded = true }
                }
                Task144RootObservation.performanceMetadata(["lastRuntimeCallID": callID.uuidString,
                    "lastRuntimeStatus": result.status.rawValue, "lastRuntimeError": result.errorCode ?? "none"])
            }
            self?.recordAutomaticReadback(action: action, result: result, presentationID: lease?.presentationID, invocationID: invocationID)
        }
// TASK145_T19_INSERT_BEGIN runtime-observer
        observed.t19Begin = { [weak self] action, source in self?.t19Control?.begin(action: Self.actionKind(action), source: source.rawValue) }
        observed.t19Observe = { [weak self] action, source, result in self?.t19Observe(action: action, source: source, result: result) }

// TASK145_T19_INSERT_END runtime-observer
        return observed
    }

    /// Observes the result of the real facade; it never submits work or changes
    /// admission. Only closed categories and bounded TEST-row counts are exposed.
    private func recordAutomaticReadback(action: SyncAction, result: SyncAutomaticRunResult, presentationID: String?, invocationID: UUID) {
        if let control = t10Control, presentationID == controller.presentationID {
            do {
                let qualified = try t10Readback(beforeActivation: false)
                if qualified, control.state.processIDs.count == 3, control.state.terminalGeneration != nil,
                   result.status == .success || result.status == .noWork,
                   result.errorCode == nil, result.failure == nil, result.blockReason == nil,
                   result.scheduledRetryAfter == nil,
                   let observation = result.observation, observation.hasValidPersistentFacts,
                   observation.matches(result), observation.origin.isCurrent(defaults: .standard, ownerUserID: owner),
                   observation.origin.generationID == controller.activeManifest?.generationID {
                    facts.insert("task145.t10a.second-reopen-own-ack-no-resend")
                }
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
        if let control = r4Control, presentationID == controller.presentationID {
            do {
                let terminalReadback = try observeR4State()
                if control.reopening, terminalReadback, facts.contains("task145.r4.terminal-reopened"),
                   r4IsTerminalWakeAction(action), result.status == .success || result.status == .noWork,
                   result.errorCode == nil, result.failure == nil, result.blockReason == nil,
                   result.scheduledRetryAfter == nil,
                   let observation = result.observation, observation.hasValidPersistentFacts,
                   observation.matches(result), observation.origin.isCurrent(defaults: .standard, ownerUserID: owner),
                   observation.origin.generationID == controller.activeManifest?.generationID {
                    facts.insert("task145.r4.terminal-wake-observed")
                }
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
        if let isolationControl {
            if presentationID == controller.presentationID { isolationControl.observeRun(result) }
            else { isolationControl.state.failed = true; try? isolationControl.persist() }
        }
        let prefix = "task144.controlled.auto."
        let error: String
        switch result.errorCode {
        case nil: error = "none"
        case "providerMissing": error = "recovery-provider-missing"
        case "incrementalProviderMissing": error = "incremental-provider-missing"
        case "atomicProviderRequired": error = "atomic-provider-required"
        case "scopeChanged": error = "scope-changed"
        case "staleGenerationLease": error = "stale-generation-lease"
        case "retiredStoreGeneration": error = "retired-store-generation"
        case "responseMismatch": error = "response-mismatch"
        case "unexpectedCall": error = "fixture-unexpected-call"
        default: error = "other"
        }
        if let retryControl, retryControl.isArmed, result.failure != nil {
            do { try retryControl.noteResult(result, action: Self.actionKind(action)) }
            catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
        if let seq6Control, seq6Control.armed {
            do {
                try seq6Control.note("runtime-result", ["action": Self.actionKind(action), "status": result.status.rawValue,
                    "error": result.errorCode ?? "none", "verified": String(result.verifiedConvergence),
                    "continuation": String(result.continuationReceipt != nil),
                    "generation": controller.activeManifest?.generationID.uuidString ?? "missing"])
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
        lastAutomaticResult = "\(prefix)result.\(Self.actionKind(action)).\(result.status.rawValue).\(error)"
        lastAutomaticPresentationID = presentationID
        lastAutomaticInvocationID = invocationID
        lastAutomaticCallbackUptime = ProcessInfo.processInfo.systemUptime
        if saveBControl != nil, facts.contains("task145.save-b.terminal-reopen-qualified"),
           presentationID == controller.presentationID, result.errorCode == nil,
           result.status == .success || result.status == .noWork {
            do {
                guard try saveBReadback() else { throw SyncStoreGenerationError.activationReadBackFailed }
                facts.insert("task145.save-b.terminal-reopened-no-resend")
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
        if restartControl != nil, facts.contains("task145.restart.terminal-reopen-qualified"),
           presentationID == controller.presentationID, result.errorCode == nil,
           result.status == .success || result.status == .noWork {
            do {
                guard try restartReadback() else { throw SyncStoreGenerationError.activationReadBackFailed }
                facts.insert("task145.restart.terminal-reopened-no-resend")
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
        if domainControl != nil, facts.contains("task145.domain.terminal-reopen-qualified"),
           presentationID == controller.presentationID, result.errorCode == nil,
           result.status == .success || result.status == .noWork {
            do {
                guard try domainReadback() else { throw SyncStoreGenerationError.activationReadBackFailed }
                facts.insert("task145.domain.terminal-reopened-no-resend")
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
        if provesIndependentPending, automaticCompletionObservations.count < 8 {
            automaticCompletionObservations.append(lastAutomaticResult + ".http-entries.\(catalogRemote.attemptCount)")
        }
        refreshAutomaticObservation()
    }

// TASK145_T14_INSERT_BEGIN passive-runtime-values
    /// A bounded read of current-process fixture callbacks and eight public diagnostics.
    /// No refresh, store mutation, trigger, defaults write or authority renewal occurs.
    fileprivate func t14PassiveCurrentRuntimeValues() -> [String: Any] {
        guard ProcessInfo.processInfo.environment["TASK145_T14_OBSERVATION"] == "1" else {
            return ["status": "DISABLED"]
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        let uptime = ProcessInfo.processInfo.systemUptime
        let utc = Date().timeIntervalSince1970
        let keys: [(String, String)] = [
            ("sync.runtime.timer.lastTickAt", "number"),
            ("sync.runtime.timer.intervalSeconds", "number"),
            ("sync.runtime.timer.sceneActive", "bool"),
            ("sync.runtime.timer.isSignedIn", "bool"),
            ("sync.runtime.timer.didReachInteractiveUI", "bool"),
            ("sync.runtime.foreground.requestedAt", "number"),
            ("sync.runtime.foreground.source", "string"),
            ("sync.runtime.foreground.outcome", "string")
        ]
        var defaults: [String: Any] = [:]
        for (key, kind) in keys {
            guard let raw = UserDefaults.standard.object(forKey: key) else {
                defaults[key] = ["status": "UNKNOWN_MISSING"]
                continue
            }
            switch kind {
            case "number":
                if let number = raw as? NSNumber,
                   String(cString: number.objCType) != "c", number.doubleValue.isFinite {
                    defaults[key] = ["status": "VALUE", "value": number.doubleValue]
                } else { defaults[key] = ["status": "UNKNOWN_TYPE"] }
            case "bool":
                if let number = raw as? NSNumber, String(cString: number.objCType) == "c" {
                    defaults[key] = ["status": "VALUE", "value": number.boolValue]
                } else { defaults[key] = ["status": "UNKNOWN_TYPE"] }
            default:
                if let value = raw as? String, value.utf8.count <= 128 {
                    defaults[key] = ["status": "VALUE", "value": value]
                } else { defaults[key] = ["status": "UNKNOWN_TYPE_OR_LIMIT"] }
            }
        }
        var callback: [String: Any] = [
            "status": lastAutomaticCallbackUptime == nil ? "NOT_OBSERVED" : "OBSERVED",
            "namespace": namespace.uuidString.lowercased(), "pid": pid,
            "currentPresentationID": controller.presentationID,
            "sourceCurrent": lastAutomaticPresentationID != nil
                && lastAutomaticPresentationID == controller.presentationID
        ]
        if lastAutomaticResult.utf8.count <= 256 { callback["result"] = lastAutomaticResult }
        else { callback["resultStatus"] = "UNKNOWN_TEXT_LIMIT" }
        if let value = lastAutomaticCallbackUptime, value.isFinite { callback["uptime"] = value }
        if let value = lastAutomaticPresentationID { callback["sourcePresentationID"] = value }
        if let value = lastAutomaticInvocationID { callback["invocationID"] = value.uuidString.lowercased() }
        var observed: [String: Any] = ["status": "PASSIVE_ONLY", "observedUptime": uptime, "observedUTC": utc,
            "pid": pid, "namespace": namespace.uuidString.lowercased(),
            "bodyProof": Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
            "generation": controller.activeManifest?.generationID.uuidString.lowercased() ?? "missing",
            "defaults": defaults, "callback": callback]
        // Reuse existing fresh-context readbacks without publishing facts or
        // changing the terminal poll. A read error is never an empty queue.
        do { observed["pendingSaveA"] = ["status": "VALUE", "value": try durableSaveReadback()] }
        catch { observed["pendingSaveA"] = ["status": "UNKNOWN_READ_FAILED"] }
        do { observed["terminalSaveA"] = ["status": "VALUE", "value": try terminalReadback()] }
        catch { observed["terminalSaveA"] = ["status": "UNKNOWN_READ_FAILED"] }
        return observed
    }
// TASK145_T14_INSERT_END passive-runtime-values
    /// Observational only: no runtime trigger, scope grant or queue action.
    private func refreshAutomaticObservation() {
        let prefix = "task144.controlled.auto."
        var diagnostic = [lastAutomaticResult, "\(prefix)source-current.\(lastAutomaticPresentationID == controller.presentationID)",
            "\(prefix)namespace.\(namespace.uuidString.lowercased())",
            "\(prefix)invocation.\(lastAutomaticInvocationID?.uuidString.lowercased() ?? "none")",
            "\(prefix)callback-uptime.\(lastAutomaticCallbackUptime ?? 0)",
            "\(prefix)source-presentation.\(lastAutomaticPresentationID ?? "none")",
            "\(prefix)current-presentation.\(controller.presentationID)",
            "\(prefix)calls.\(catalogRemote.attemptCount).events.\(catalogRemote.eventCount)",
            "\(prefix)new-generation.\(controller.activeManifest?.generationID != heldGenerationID)",
            "\(prefix)body-proof.\(Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer))",
            "\(prefix)phase.\(Self.phaseKind(stateStore.state.phase))"]
        do {
            let context = ModelContext(controller.modelContainer)
            var pendingDescriptor = FetchDescriptor<LocalPendingChange>()
            pendingDescriptor.fetchLimit = 101
            var outboxDescriptor = FetchDescriptor<SyncEventOutboxEntry>()
            outboxDescriptor.fetchLimit = 101
            let pending = try context.fetch(pendingDescriptor)
            let outbox = try context.fetch(outboxDescriptor)
            guard pending.count <= 100, outbox.count <= 100 else {
                diagnostic.append("\(prefix)rows.capped")
                publishAutomaticObservation(diagnostic)
                return
            }
            let pendingReady = pending.filter { $0.statusRaw == LocalPendingChangeStatus.pending.rawValue }.count
            let pendingAck = pending.filter { $0.statusRaw == LocalPendingChangeStatus.acknowledged.rawValue }.count
            let sent = outbox.filter { $0.statusRaw == SyncEventOutboxStatus.sent.rawValue }.count
            let localOnly = outbox.filter { $0.statusRaw == SyncEventOutboxStatus.localOnly.rawValue }.count
            diagnostic.append("\(prefix)rows.pending.\(pendingReady).ack.\(pendingAck).outbox.\(outbox.count).sent.\(sent).local.\(localOnly)")
        } catch {
            diagnostic.append("\(prefix)rows.read-failed")
        }
        if provesIndependentPending { diagnostic.append(contentsOf: independentProductObservation()) }
        if let saveBControl { diagnostic.append(saveBControl.readback) }
        if let interruptionControl { diagnostic.append(interruptionControl.readback) }
        if let isolationControl { diagnostic.append(isolationControl.readback) }
        if let restartControl { diagnostic.append(restartControl.readback) }
        if let domainControl { diagnostic.append(domainControl.readback) }
        if let retryControl { diagnostic.append(retryControl.readback) }
// TASK145_T19_INSERT_BEGIN readback
        if let t19Control { diagnostic.append(t19Control.readback) }

// TASK145_T19_INSERT_END readback
        if let seq6Control { diagnostic.append(seq6Control.readback) }
        publishAutomaticObservation(diagnostic)
    }

    // The private Catalog mutation is decoded only for observation, after the
    // real immutable-attempt validator has checked its complete envelope.
    private func observeProductHTTP(id: UUID, payload: SyncAutomaticProductUpdatePayload,
        scope: Task126VerifiedOwnerStoreScope, providerReturning: Bool) {
        guard provesIndependentPending else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let payloadData = try encoder.encode(payload)
            let payloadHash = ShopSyncRecoveryCanonical.sha256(String(decoding: payloadData, as: UTF8.self))
            if providerReturning {
                guard let index = productHTTPObservations.indices.last,
                      productHTTPObservations[index].id == id,
                      productHTTPObservations[index].payloadHash == payloadHash,
                      productHTTPObservations[index].scope == scope else { return }
                productHTTPObservations[index].providerReturned = true
                return
            }
            guard productHTTPObservations.count < 8 else { productHTTPObservationCapped = true; return }
            let context = ModelContext(controller.modelContainer)
            var changesRequest = FetchDescriptor<LocalPendingChange>(); changesRequest.fetchLimit = 101
            var outboxRequest = FetchDescriptor<SyncEventOutboxEntry>(); outboxRequest.fetchLimit = 101
            let changes = try context.fetch(changesRequest)
            let outbox = try context.fetch(outboxRequest)
            guard changes.count <= 100, outbox.count <= 100 else { productHTTPObservationCapped = true; return }
            var precedingACK = "not-observed"
            var precedingCASMatches = "not-observed"
            if let previous = productHTTPObservations.last?.sealedToken {
                let sameID = changes.filter { $0.changeID == previous.changeID }
                if sameID.count == 1 {
                    precedingACK = String(sameID[0].status == .acknowledged)
                    precedingCASMatches = String(previous.matches(sameID[0]))
                }
            }
            let products = changes.filter { $0.entityKind == .product && $0.status == .pending }
            var token: LocalPendingChangeCASToken?
            var sealedHash: String?
            var corresponds = false
            if products.count == 1 {
                let sealed = outbox.filter { $0.id == products[0].changeID && LocalPendingBusinessAttemptStore.isSealed($0) }
                if sealed.count == 1 {
                    let data = try LocalPendingBusinessAttemptStore.validate(sealed[0], kind: "catalog", scope: scope)
                    let envelope = try JSONDecoder().decode(
                        LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self, from: data)
                    token = envelope.pending
                    sealedHash = sealed[0].entityIDsShape
                    let incoming = envelope.payload.call.updateProduct
                    corresponds = envelope.pending.matches(products[0]) && incoming.id == id && incoming.payload == payload
                }
            }
            productHTTPObservations.append(.init(id: id, payloadHash: payloadHash, scope: scope,
                sealedToken: token, sealedHash: sealedHash, sealedBodyCorresponds: corresponds,
                precedingACK: precedingACK, precedingCASMatches: precedingCASMatches))
        } catch {
            // Never change the incoming HTTP request or propagate a diagnostic failure.
            productHTTPObservationCapped = true
        }
    }

    private func independentProductObservation() -> [String] {
        let prefix = "task144.controlled.independent."
        var result = ["\(prefix)attempt-observation-capped.\(productHTTPObservationCapped)",
            "\(prefix)caller-cas-result.not-directly-observed",
            "\(prefix)first-product-commit-response-lost.\(catalogRemote.firstProductResponseWasLost)"]
        let first = productHTTPObservations.first
        for (index, observation) in productHTTPObservations.enumerated() {
            let token = observation.sealedToken
            let scope = observation.scope
            let scopeHash = LocalPendingChangeLogicalKey.privacyHash([
                scope.ownerUserID.uuidString.lowercased(), scope.shopID.uuidString.lowercased(),
                scope.deviceIdentityHash, scope.storeIdentity.storeId, scope.storeIdentity.localStoreId,
                String(scope.storeIdentity.syncProtocolVersion), String(scope.storeIdentity.schemaVersion),
                String(scope.storeIdentity.storeEpoch), String(scope.leaseGeneration)].joined(separator: "|"))
            let values: [String] = ["\(prefix)http.\(index + 1)",
                "id.\(LocalPendingChangeLogicalKey.privacyHash(observation.id.uuidString.lowercased()))",
                "body.\(observation.payloadHash)", "scope.\(scopeHash)",
                "sealed-key.\(token.map { LocalPendingChangeLogicalKey.privacyHash($0.idempotencyKey) } ?? "absent")",
                "sealed-revision.\(token?.eventFingerprint ?? "absent")", "sealed-body.\(observation.sealedHash ?? "absent")",
                "incoming-scope-verified.true", "sealed-owner-store-schema-device-valid.\(token != nil)",
                "sealed-corresponds.\(observation.sealedBodyCorresponds)",
                "provider-returned.\(observation.providerReturned)", "preceding-ack.\(observation.precedingACK)",
                "preceding-cas-matches.\(observation.precedingCASMatches)",
                "same-first-id.\(observation.id == first?.id)", "same-first-body.\(observation.payloadHash == first?.payloadHash)",
                "same-first-scope.\(Self.sameStableProductScope(scope, first?.scope))", "same-first-sealed-revision.\(token != nil && token == first?.sealedToken)",
                "same-first-full-scope.\(scope == first?.scope)"]
            result.append(values.joined(separator: "."))
            if observesReplayScopeComponents {
                let components: [String] = ["\(prefix)scope-components.\(index + 1)",
                    "same-first-owner.\(scope.ownerUserID == first?.scope.ownerUserID)",
                    "same-first-account.\(scope.accountHash == first?.scope.accountHash)",
                    "same-first-shop.\(scope.shopID == first?.scope.shopID)",
                    "same-first-full-store.\(scope.storeIdentity == first?.scope.storeIdentity)",
                    "same-first-device-install.\(scope.deviceInstallID == first?.scope.deviceInstallID)",
                    "same-first-device-hash.\(scope.deviceIdentityHash == first?.scope.deviceIdentityHash)",
                    "same-first-full-pending.\(scope.pendingReplacement == first?.scope.pendingReplacement)",
                    "pending-present.\(scope.pendingReplacement != nil)",
                    "pending-account-matches-scope.\(scope.pendingReplacement.map { String($0.accountHash == scope.accountHash) } ?? "absent")",
                    "pending-full-store-matches-scope.\(scope.pendingReplacement.map { String($0.storeIdentity == scope.storeIdentity) } ?? "absent")",
                    "same-first-lease.\(scope.leaseGeneration == first?.scope.leaseGeneration)"]
                result.append(components.joined(separator: "."))
            }
        }
        result.append(contentsOf: automaticCompletionObservations.enumerated().map { "\(prefix)completion.\($0.offset + 1).\($0.element)" })
        result.append(contentsOf: catalogRemote.eventRequestObservations.map { "\(prefix)event.\($0)" })
        do {
            let context = ModelContext(controller.modelContainer)
            var productRequest = FetchDescriptor<Product>(); productRequest.fetchLimit = 2
            var pendingRequest = FetchDescriptor<LocalPendingChange>(); pendingRequest.fetchLimit = 101
            let products = try context.fetch(productRequest)
            let pending = try context.fetch(pendingRequest)
            guard pending.count <= 100 else { result.append("\(prefix)predicates.capped"); return result }
            let productChanges = pending.filter { $0.entityKind == .product }
            let historyChanges = pending.filter { $0.entityKind == .historySession }
            let oneProduct = products.count == 1 && productChanges.count == 1
            let oneHistory = historyChanges.count == 1
            let historyCount = try context.fetchCount(FetchDescriptor<HistoryEntry>())
            let productACK = oneProduct && productChanges[0].status == .acknowledged
            let productFingerprint = oneProduct && productChanges[0].intendedFingerprintHash
                == LocalPendingChangeLogicalKey.productFingerprintHash(products[0])
            let historyNonterminal = oneHistory && !historyChanges[0].status.isTerminal
            let historyOwner = oneHistory && historyChanges[0].ownerUserID == owner.uuidString.lowercased()
            let historyScope = oneHistory && first.map { LocalPendingChangeScopeMatcher.matches(historyChanges[0],
                ownerUserID: $0.scope.ownerUserID, accountHash: $0.scope.accountHash, storeIdentity: $0.scope.storeIdentity) } == true
            let productScope = oneProduct && first.map { LocalPendingChangeScopeMatcher.matches(productChanges[0],
                ownerUserID: $0.scope.ownerUserID, accountHash: $0.scope.accountHash, storeIdentity: $0.scope.storeIdentity) } == true
            let predicates: [(String, Bool)] = [("product-unique", products.count == 1), ("product-intent-unique", productChanges.count == 1),
                ("history-intent-unique", oneHistory), ("product-name", oneProduct && products[0].productName == "Saved before network release"),
                ("product-ack", productACK), ("product-fingerprint", productFingerprint), ("history-nonterminal", historyNonterminal),
                ("history-owner", historyOwner), ("history-count-one", historyCount == 1), ("http-count-one", catalogRemote.attemptCount == 1),
                ("product-exact-scope", productScope), ("history-exact-scope", historyScope),
                ("history-status-pending", oneHistory && historyChanges[0].status == .pending),
                ("single-immutable-product-ack-and-event", oneProduct && oneHistory
                    && hasOneImmutableProductAttemptACK(product: products[0], change: productChanges[0],
                        historyChange: historyChanges[0], context: context))]
            result.append(contentsOf: predicates.map { "\(prefix)predicate.\($0.0).\($0.1)" })
        } catch { result.append("\(prefix)predicates.read-failed") }
        return result
    }

    private func publishAutomaticObservation(_ diagnostic: [String]) {
        let payload = diagnostic.joined(separator: ";")
        guard payload != lastObservationPayload else { return }
        lastObservationPayload = payload
        observationSequence += 1
        automaticReadback = payload + ";sequence=\(observationSequence);captured-uptime=\(ProcessInfo.processInfo.systemUptime)"
    }

    private static func phaseKind(_ phase: SyncPhase) -> String {
        switch phase {
        case .idle: return "idle"
        case .checking: return "checking"
        case .pushing: return "pushing"
        case .pullingEvents: return "pulling-events"
        case .reconciling: return "reconciling"
        case .recoveryRequired: return "recovery-required"
        case .blocked: return "blocked"
        case .failed: return "failed"
        }
    }

    private static func actionKind(_ action: SyncAction) -> String {
        switch action {
        case .noOp: return "noop"
        case .pushPending: return "push"
        case .drainEvents: return "drain"
        case .lightReconcile: return "reconcile"
        case .bootstrap: return "bootstrap"
        case .fullRecovery: return "recovery"
        case .requestRecovery: return "request-recovery"
        case .retryAfterBusy: return "retry-busy"
        case .blocked: return "blocked"
        case .sequence(let actions): return actions.map(actionKind).joined(separator: "-")
        }
    }

    private func recoveryService() -> AtomicGenerationRecoverySnapshotPullService {
        AtomicGenerationRecoverySnapshotPullService(storeGenerationController: controller,
            recoveryRemote: ShopSyncRecoveryRemoteAdapter(transport: transport), pageLimit: Task145PerformanceConfiguration.enabled ? 250 : (interruptionControl?.isSeed == false ? 1 : 25),
            progressReporter: { [weak self, weak stateStore] event in
                stateStore?.recordRecoveryProgress(event)
                Task144RootObservation.performanceDurableProgress(event.progress)
                do { try self?.interruptionProgress(event) }
                catch {
                    self?.interruptionControl?.state.observationFailed = true
                    try? self?.interruptionControl?.persist()
                    self?.recordSetupFailure(error, stage: .heldRecovery)
                }
                if event.progress.stage == .finalizing, self?.domainControl != nil {
                    do { try self?.domainProbeAfterPublish() }
                    catch { self?.recordSetupFailure(error, stage: .heldRecovery) }
                }
            })
    }

    func performanceRecordSaveReceipt(_ receipt: LocalProductSaveReceipt) {
        guard Task145PerformanceConfiguration.measures else { return }
        // Value capture only; no query/I/O added to the measured Save handler.
        performanceSaveReceipt = (Task144RootObservation.performanceSampleID(), receipt)
    }
    private nonisolated struct PerformanceAttemptHeader: Decodable { let schemaVersion: Int; let pending: LocalPendingChangeCASToken }
    private func performanceIntentIsExact(_ token: LocalPendingChangeCASToken, change: LocalPendingChange,
                                         context: ModelContext, scope: Task126VerifiedOwnerStoreScope) throws -> Bool {
        guard token.changeID == change.changeID, token.entityKindRaw == change.entityKindRaw,
              token.entityRemoteIDRaw == change.entityRemoteIDRaw, token.logicalKey == change.logicalKey,
              token.intendedFingerprintHash == change.intendedFingerprintHash,
              LocalPendingChangeScopeMatcher.matches(change, ownerUserID: scope.ownerUserID,
                accountHash: scope.accountHash, storeIdentity: scope.storeIdentity), !change.status.isTerminal else { return false }
        if token.matches(change) { return true }
        // The only expected pre-response mutation is the real dispatch timestamp.
        // Qualify its persisted immutable attempt, then compare every other token field.
        let id = token.changeID
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate { $0.id == id }); descriptor.fetchLimit = 2
        let entries = try context.fetch(descriptor)
        guard entries.count == 1 else { return false }
        let bytes = try LocalPendingBusinessAttemptStore.validate(entries[0], scope: scope)
        let sealed = try JSONDecoder().decode(PerformanceAttemptHeader.self, from: bytes)
        guard sealed.schemaVersion == 1, sealed.pending.matches(change), sealed.pending.lastAttemptAt != nil else { return false }
        func stable(_ value: LocalPendingChangeCASToken) throws -> NSDictionary {
            var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any]
            object.removeValue(forKey: "lastAttemptAt")
            return object as NSDictionary
        }
        return try stable(token).isEqual(stable(sealed.pending))
    }
    private func performanceRecoveryFinalizationIsCurrent() -> Bool {
        guard let manifest = controller.activeManifest, !AccountBindingStore().hasPendingReplacementJournal,
              authViewModel.isSignedIn, authViewModel.localMutationOwnerUserID == owner,
              let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner),
              scope.shopID == shop, scope.accountHash == manifest.accountHash, scope.storeIdentity == manifest.storeIdentity,
              scope.deviceIdentityHash == manifest.deviceIdentityHash,
              (try? controller.isActiveRecoveryFinalized(scope: scope)) == true,
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer, ownerUserID: owner) else { return false }
        return performanceResults.contains { callID, result in
            guard (result.status == .success || result.status == .noWork),
                  result.errorCode == nil, result.blockReason == nil,
                  let finalization = result.verifiedFinalization, finalization.exactlyMatches(manifest),
                  let summary = performanceSummaries[callID], summary.completedRecoveryJournal,
                  summary.activatedGenerationID == manifest.generationID,
                  summary.watermarkAfter == manifest.checkpoint.maxEventID else { return false }
            return true
        }
    }

    // TASK145_PERF controls run AFTER the timed path. No test-control poll in Save.
    func exportPerformanceSample(failed: Bool = false) {
        var failure: String? = failed ? "first_functional_gate_failed" : nil
        if !failed {
            do {
                let context = ModelContext(controller.modelContainer)
                let remoteID = Task145PerformanceConfiguration.targetID
                var request = FetchDescriptor<Product>(predicate: #Predicate { $0.remoteID == remoteID }); request.fetchLimit = 2
                let rows = try context.fetch(request)
                let expected = "T20 edited " + Task144RootObservation.performanceSampleID()
                guard rows.count == 1, rows[0].productName == expected else { throw SyncStoreGenerationError.activationReadBackFailed }
                let variant = Task145PerformanceConfiguration.environment["TASK145_PERF_VARIANT"] ?? "missing"
                let index = Int(Task145PerformanceConfiguration.environment["TASK145_PERF_INDEX"] ?? "")
                let warm = Task144RootObservation.performanceSampleID().hasSuffix("-warm")
                if variant == "price" {
                    guard let index, rows[0].retailPrice == Double(1100 + index * 2 + (warm ? 1 : 0)) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
                if variant == "relations" {
                    let selected = warm ? 0 : 1
                    guard rows[0].supplier?.remoteID == Task145PerformanceConfiguration.supplierIDs[selected],
                          rows[0].category?.remoteID == Task145PerformanceConfiguration.categoryIDs[selected] else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
                guard let observed = performanceSaveReceipt,
                      observed.sampleID == Task144RootObservation.performanceSampleID(),
                      observed.receipt.remoteID == remoteID, observed.receipt.barcode == "T20-020000",
                      observed.receipt.matches(controller.activeManifest), observed.receipt.matches(rows[0]),
                      !observed.receipt.intents.isEmpty, observed.receipt.intents.count <= 5,
                      let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, allowsPendingSameScopeRecovery: true) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                let ids = observed.receipt.intents.map(\.changeID)
                var intents = FetchDescriptor<LocalPendingChange>(predicate: #Predicate { ids.contains($0.changeID) }); intents.fetchLimit = 6
                let pending = try context.fetch(intents)
                guard pending.count == ids.count, Set(ids).count == ids.count,
                      observed.receipt.intents.contains(where: { $0.entityKindRaw == LocalPendingChangeEntityKind.product.rawValue
                        && $0.entityRemoteIDRaw.flatMap(UUID.init(uuidString:)) == remoteID
                        && $0.logicalKey == LocalPendingChangeLogicalKey.product(remoteID: remoteID, barcode: "T20-020000") }) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                for token in observed.receipt.intents {
                    guard let change = pending.first(where: { $0.changeID == token.changeID }),
                          try performanceIntentIsExact(token, change: change, context: context, scope: scope) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
                Task144RootObservation.performanceMetadata(["saveIntentIDs": ids.sorted().joined(separator: ","),
                    "saveTokenFingerprints": observed.receipt.intents.map(\.eventFingerprint).joined(separator: ","),
                    "saveVariant": variant, "savedRetailPrice": String(rows[0].retailPrice ?? -1),
                    "savedSupplierID": rows[0].supplier?.remoteID?.uuidString ?? "nil",
                    "savedCategoryID": rows[0].category?.remoteID?.uuidString ?? "nil"])
                Task144RootObservation.performanceMark("durableReadbackVerified", facts: "fresh-context-business-and-nonterminal-intent")
                if Task145PerformanceConfiguration.recovery {
                    guard let remote = transport.performance, remote.held,
                          let heldAt = remote.heldAt, DispatchTime.now().uptimeNanoseconds - heldAt >= 10_000_000_000,
                          performanceInvocations.values.contains(where: { $0.isRunning }) else { throw SyncStoreGenerationError.activationReadBackFailed }
                    Task144RootObservation.performanceMark("heldThroughEnd", facts: "actual-runtime-running;actual-request-held>=10s")
                }
            } catch { failure = "durable_readback_or_held_request_failed" }
        }
        guard !performanceFinishInProgress else { return }
        performanceFinishInProgress = true
        Task144RootObservation.performanceCaptureResources(prefix: "ui_end_")
        Task { [weak self] in
            guard let self else { return }
            defer { performanceFinishInProgress = false }
            await finishPerformanceObservation(initialFailure: failure)
        }
    }
    private func finishPerformanceObservation(initialFailure: String?) async {
        var failure = initialFailure
        let start = DispatchTime.now().uptimeNanoseconds
        var cancellationAt: UInt64?
        if failure == nil { transport.performance?.release() }
        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            let flight = await AutomaticSyncSingleFlight.processShared.isRunning
            let remote = transport.performance
            let request = remote?.activeRequest
            if failure == nil, let request, now > request.requestDeadlineNS { failure = "request_deadline_exceeded" }
            if failure == nil, request == nil, performanceHasActiveInvocation || flight {
                let segmentStart = max(start, max(remote?.lastRequestTerminalNS ?? start,
                    Task144RootObservation.performanceLastDurableProgressNS() ?? start))
                if now - segmentStart > 10_000_000_000 { failure = "local_no_durable_progress_10s" }
            }
            if failure != nil, cancellationAt == nil {
                cancellationAt = now
                transport.performance?.cancelPending()
                performanceCancelInvocations()
                Task144RootObservation.performanceMark("cancellationRequested", facts: failure!)
            }
            if let terminal = remote?.lastFailedRequestTerminalNS, terminal >= start,
               now - terminal > 1_000_000_000, performanceHasActiveInvocation || flight {
                failure = "owner_not_released_1s_after_failed_transport_terminal"
            }
            if let request, now > request.requestDeadlineNS + 5_000_000_000 {
                failure = "stalled_cancellation_request_alive_after_deadline_plus5s"; break
            }
            if !performanceHasActiveInvocation && !flight && request == nil { break }
            if let cancellationAt, now - cancellationAt > 5_000_000_000 {
                failure = "stalled_owner_after_cancellation_5s"; break
            }
            // A live request before its deadline is WAITING. Neither request
            // count, polling nor phase labels can advance durable progress.
            try? await Task.sleep(for: .milliseconds(50))
        }
        let sharedFlight = await AutomaticSyncSingleFlight.processShared.isRunning
        let releaseNS = performanceLastAllInvocationsFinishedNS
        Task144RootObservation.performanceMetadata([
            "terminalActiveInvocations": String(performanceInvocations.count),
            "terminalSharedFlight": String(sharedFlight),
            "terminalActiveRequest": String(transport.performance?.activeRequest != nil),
            "actualLastInvocationTerminalNS": releaseNS.map(String.init) ?? "NOT_OBSERVED",
            "persistedJournalPhase": AccountBindingStore().pendingRecoveryJournal?.phase.rawValue ?? "none"])
        if failure == nil, performanceObservationCapacityExceeded { failure = "invocation_observation_capacity_exceeded" }
        if failure == nil, !Task145PerformanceConfiguration.offline {
            // A stopped runtime can have failed; inspect every exact completed invocation.
            let unacceptable = performanceResults.values.contains { result in
                ![SyncAutomaticRunStatus.success, .noWork, .busy].contains(result.status)
                    || result.errorCode != nil || result.blockReason != nil
            }
            let successful = performanceResults.values.contains { $0.status == .success || $0.status == .noWork }
            if unacceptable || !successful { failure = "actual_invocation_outcome_not_successful" }
        }
        if failure == nil, Task145PerformanceConfiguration.recovery, !performanceRecoveryFinalizationIsCurrent() {
            failure = "exact_success_finalization_journal_scope_body_not_qualified"
        }
        if failure == nil, Task145PerformanceConfiguration.recovery {
            do {
                let context = ModelContext(controller.modelContainer), remoteID = Task145PerformanceConfiguration.targetID
                var request = FetchDescriptor<Product>(predicate: #Predicate { $0.remoteID == remoteID }); request.fetchLimit = 2
                let rows = try context.fetch(request)
                guard rows.count == 1, let saved = performanceSaveReceipt,
                      saved.sampleID == Task144RootObservation.performanceSampleID(),
                      saved.receipt.matches(controller.activeManifest), saved.receipt.matches(rows[0]) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                Task144RootObservation.performanceMark("postCutoverSavedBodyVerified", facts: "fresh-current-generation;actual-save-body-preserved;no-ACK-inference")
            } catch { failure = "saved_body_not_preserved_after_actual_cutover" }
        }
        if failure == nil {
            Task144RootObservation.performanceMark("runtimeReleased", facts: "all-exact-invocations-terminated;shared-flight-idle;no-active-request")
            try? await Task.sleep(for: .milliseconds(200)) // observe actual frame spanning cutover, outside UI latency windows
        }
        performanceExport = Task144RootObservation.performanceSeal(status: failure == nil ? "PASS" : "FAIL", reason: failure ?? "")
    }
    func armPerformanceWarm() {
        guard Task145PerformanceConfiguration.measures, !performanceFinishInProgress,
              !performanceHasActiveInvocation, transport.performance?.activeRequest == nil else { return }
        if Task145PerformanceConfiguration.recovery, !performanceRecoveryFinalizationIsCurrent() { return }
        performanceWarmRecoveryPending = Task145PerformanceConfiguration.recovery
        performanceWarmActivationPending = true
        performanceObservationCapacityExceeded = false
        performanceResults.removeAll(keepingCapacity: true); performanceSummaries.removeAll(keepingCapacity: true)
        performanceSaveReceipt = nil; performanceExport = ""
        facts.remove("task145.perf.actual-recovery-request-held")
        Task144RootObservation.performanceArmWarm()
        performanceWarmReady = true
    }
    func beginPerformanceWarmRecoveryIfArmed() {
        guard Task145PerformanceConfiguration.measures, performanceWarmActivationPending,
              Task144RootObservation.performanceSampleID().hasSuffix("-warm") else { return }
        performanceWarmActivationPending = false
        performanceWarmReady = false
        transport.performance?.armBusinessHold()
        if let checkpoint = transport.performance?.checkpointValue {
            Task144RootObservation.performanceMetadata(["datasetCheckpointDigest": checkpoint.checkpointDigest,
                "productVersionDigest": checkpoint.catalog.products.versionDigest, "priceVersionDigest": checkpoint.prices.versionDigest])
        }
        guard performanceWarmRecoveryPending else { return }
        performanceWarmRecoveryPending = false
        guard !AccountBindingStore().hasPendingReplacementJournal,
              let binding = AccountBindingStore().currentBinding,
              let device = try? DeviceInstallIDStore().requireDeviceInstallID(),
              AccountBindingStore().beginSameScopeRecovery(accountHash: binding.accountHash,
                storeIdentity: binding.storeIdentity, reason: "TASK145_PERF_NEXT_WARM_REQUEST",
                deviceIdentityHash: DeviceInstallIDStore.identityHash(for: device)) else {
            performanceExport = Task144RootObservation.performanceSeal(status: "FAIL", reason: "warm_recovery_admission_setup_failed")
            return
        }
        transport.performance?.holdNextProducts = true
    }

    private func insertIndependentPendingHistory() throws {
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: controller.modelContainer,
            ownerUserID: owner) { context in
            let entry = HistoryEntry(id: "TASK144_INDEPENDENT_PENDING", timestamp: Date(timeIntervalSince1970: 1_784_635_200),
                data: [["Item", "Quantity"], ["Independent pending history", "1"]], uid: UUID())
            context.insert(entry)
            try LocalPendingChangeAccumulator(context: context, ownerUserID: owner)
                .recordHistorySessionChange(entry: entry, operation: .create, changedFields: ["data"])
            try context.save()
        }
        independentPendingInserted = true
        facts.insert("task144.controlled.independent-history-pending")
    }

    private func productACKWithIndependentPendingReadback() throws -> Bool {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let productChanges = pending.filter { $0.entityKind == .product }
        let historyChanges = pending.filter { $0.entityKind == .historySession }
        guard products.count == 1, productChanges.count == 1, historyChanges.count == 1 else { return false }
        let historyCount = try context.fetchCount(FetchDescriptor<HistoryEntry>())
        return products[0].productName == "Saved before network release"
            && productChanges[0].status == .acknowledged
            && productChanges[0].intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(products[0])
            && !historyChanges[0].status.isTerminal
            && historyChanges[0].ownerUserID == owner.uuidString.lowercased()
            && historyCount == 1
            && hasOneImmutableProductAttemptACK(product: products[0], change: productChanges[0],
                historyChange: historyChanges[0], context: context)
    }

    // Compare immutable business identity; each request and the current readback
    // separately validate their own current automatic writer lease.
    private static func sameStableProductScope(_ scope: Task126VerifiedOwnerStoreScope,
        _ reference: Task126VerifiedOwnerStoreScope?) -> Bool {
        guard let reference else { return false }
        return scope.ownerUserID == reference.ownerUserID
            && scope.accountHash == reference.accountHash
            && scope.shopID == reference.shopID
            && scope.storeIdentity == reference.storeIdentity
            && scope.deviceInstallID == reference.deviceInstallID
            && scope.deviceIdentityHash == reference.deviceIdentityHash
            && scope.pendingReplacement == reference.pendingReplacement
    }

    private func hasOneImmutableProductAttemptACK(product: Product, change: LocalPendingChange,
        historyChange: LocalPendingChange, context: ModelContext) -> Bool {
        guard change.status == .acknowledged,
              change.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
              !historyChange.status.isTerminal,
              !productHTTPObservationCapped, !catalogRemote.eventObservationCapped,
              !productHTTPObservations.isEmpty,
              productHTTPObservations.count == catalogRemote.attemptCount,
              let first = productHTTPObservations.first, let token = first.sealedToken,
              first.sealedHash != nil, first.id == product.remoteID,
              first.scope.ownerUserID == owner, first.scope.shopID == shop,
              token.changeID == change.changeID, token.idempotencyKey == change.idempotencyKey,
              token.intendedFingerprintHash == change.intendedFingerprintHash,
              productHTTPObservations.last?.providerReturned == true,
              LocalPendingChangeScopeMatcher.matches(change, ownerUserID: first.scope.ownerUserID,
                accountHash: first.scope.accountHash, storeIdentity: first.scope.storeIdentity),
              LocalPendingChangeScopeMatcher.matches(historyChange, ownerUserID: first.scope.ownerUserID,
                accountHash: first.scope.accountHash, storeIdentity: first.scope.storeIdentity),
              productHTTPObservations.enumerated().allSatisfy({ entry in
                let observation = entry.element
                return observation.sealedBodyCorresponds && observation.id == first.id
                    && observation.payloadHash == first.payloadHash && Self.sameStableProductScope(observation.scope, first.scope)
                    && observation.sealedToken == token && observation.sealedHash == first.sealedHash
                    && (entry.offset == 0 || (observation.precedingACK == "false"
                        && observation.precedingCASMatches == "true"))
              }) else { return false }
        do {
            // Historical request evidence is immutable. Its retired lease does
            // not authorize this readback: admit and revalidate current authority.
            let current = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
            guard current.ownerUserID == first.scope.ownerUserID,
                  current.accountHash == first.scope.accountHash,
                  current.shopID == first.scope.shopID,
                  current.storeIdentity == first.scope.storeIdentity,
                  current.deviceInstallID == first.scope.deviceInstallID,
                  current.deviceIdentityHash == first.scope.deviceIdentityHash,
                  context.container === controller.modelContainer,
                  Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                    modelContainer: context.container, ownerUserID: current.ownerUserID) else { return false }
            var descriptor = FetchDescriptor<SyncEventOutboxEntry>(); descriptor.fetchLimit = 101
            let outbox = try context.fetch(descriptor)
            guard outbox.count <= 100 else { return false }
            let events = outbox.filter { $0.domain == "catalog" }
            guard events.count == 1, let event = events.first,
                  event.status == .sent, event.eventType == "catalog_changed", event.changedCount == 1,
                  event.ownerUserID == first.scope.ownerUserID.uuidString.lowercased(),
                  event.storeId == first.scope.storeIdentity.storeId,
                  event.localStoreId == first.scope.storeIdentity.localStoreId,
                  event.syncProtocolVersion == first.scope.storeIdentity.syncProtocolVersion,
                  event.schemaVersion == first.scope.storeIdentity.schemaVersion,
                  event.storeEpoch == first.scope.storeIdentity.storeEpoch,
                  event.sourceDeviceID == first.scope.deviceInstallID,
                  catalogRemote.eventCount == 1, !catalogRemote.eventRequestKeys.isEmpty,
                  Set(catalogRemote.eventRequestKeys) == Set([event.clientEventID]) else { return false }
            let storedRequest = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: event)
            let expectedIDs = try AutomaticSyncEventOutboxWriter.entityIDs([
                "supplier_ids": [], "category_ids": [], "product_ids": [first.id]])
            guard storedRequest.entityIDs == expectedIDs,
                  !catalogRemote.eventRequests.isEmpty,
                  catalogRemote.eventRequests.allSatisfy({ $0 == storedRequest }) else { return false }
            try Task126OwnerStoreGate.revalidateAutomaticScope(current)
            return true
        } catch { return false }
    }

    private func relatedProductACKReadback() throws -> Bool {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let suppliers = try context.fetch(FetchDescriptor<Supplier>())
        let categories = try context.fetch(FetchDescriptor<ProductCategory>())
        guard products.count == 1, suppliers.count == 1, categories.count == 1,
              changes.count == 3, changes.allSatisfy({ $0.status == .acknowledged && $0.ownerUserID == owner.uuidString.lowercased() }) else { return false }
        return products[0].productName == "Saved before network release"
            && products[0].supplier?.name == "New related supplier"
            && products[0].category?.name == "New related category"
            && suppliers[0].remoteID != nil && categories[0].remoteID != nil
            && products[0].supplier?.remoteID == catalogRemote.currentSupplierID
            && products[0].category?.remoteID == catalogRemote.currentCategoryID
            && catalogRemote.attemptCount == 1 && catalogRemote.eventCount == 3
    }

    private func relatedMappingPendingReadback() throws -> Bool {
        guard catalogRemote.isProductHeld else { return false }
        let context = ModelContext(controller.modelContainer)
        var productRequest = FetchDescriptor<Product>(); productRequest.fetchLimit = 2
        var changeRequest = FetchDescriptor<LocalPendingChange>(); changeRequest.fetchLimit = 4
        let products = try context.fetch(productRequest)
        let changes = try context.fetch(changeRequest)
        guard products.count == 1, changes.count == 3,
              changes.allSatisfy({ $0.ownerUserID == owner.uuidString.lowercased() }),
              changes.filter({ $0.entityKind == .supplier || $0.entityKind == .productCategory })
                .allSatisfy({ $0.status == .acknowledged }),
              changes.filter({ $0.entityKind == .product }).count == 1,
              changes.first(where: { $0.entityKind == .product })?.status != .acknowledged else { return false }
        return products[0].supplier?.remoteID == catalogRemote.currentSupplierID
            && products[0].category?.remoteID == catalogRemote.currentCategoryID
            && catalogRemote.currentSupplierID != nil && catalogRemote.currentCategoryID != nil
    }

    private func durableSaveReadback() throws -> Bool {
        if provesTransientAuthStorageFailure,
           !Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                ownerUserID: authViewModel.localMutationOwnerUserID) { return false }
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        return products.count == 1 && products[0].productName == "Saved before network release"
            && pending.contains { $0.status == .pending && $0.ownerUserID == owner.uuidString.lowercased() }
    }

    // Solely reads fresh contexts and the real sealed-attempt validator. No
    // client pending row, receipt, ACK, selection or generation is manufactured.
    // R23 B6 observations use fresh read-only contexts and the real decision
    // receipt. They never synthesize an ACK, intent, review or resolution.
    var hasT10Control: Bool { t10Control != nil }
    var t10Ledger: String {
        guard let control = t10Control else { return "none" }
        return ((try? control.bytes())?.base64EncodedString() ?? "encoding-failed")
            + ";qualified." + (control.qualifiedReopen?.base64EncodedString() ?? "none")
    }
    private func prepareT10Root() throws {
        guard let control = t10Control, control.reopening,
              try t10Readback(beforeActivation: control.state.terminalGeneration == nil) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        control.qualifiedReopen = try control.bytes()
        heldGenerationID = control.state.originalGeneration
        transport.release(); hasStarted = true; isPreparedForRoot = true
        facts.insert("task145.t10a.reopen-qualified")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let deadline = ContinuousClock.now.advanced(by: .seconds(60))
                while ContinuousClock.now < deadline {
                    if try t10Readback(beforeActivation: false), control.state.terminalGeneration != nil { return }
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw URLError(.timedOut)
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }
    private func t10Readback(beforeActivation: Bool) throws -> Bool {
        guard let control = t10Control, let manifest = controller.activeManifest,
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                  ownerUserID: owner) else { return false }
        let context = ModelContext(controller.modelContainer); context.autosaveEnabled = false
        let products = try context.fetch(FetchDescriptor<Product>())
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        guard products.count == 1, let product = products.first else { throw SyncStoreGenerationError.activationReadBackFailed }
        guard product.productName == Task145SavedRecoveryControl.savedName,
              product.purchasePrice == 37 else {
            if control.state.savedTokens.isEmpty, !control.reopening { return false }
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let priceChanges = changes.filter { $0.entityKind == .productPrice }
        guard prices.count == 1, let price = prices.first, price.price == 37,
              price.type == .purchase, price.product?.remoteID == product.remoteID else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if beforeActivation {
            guard changes.count == 2, priceChanges.count == 1, let priceChange = priceChanges.first,
                  Set(changes.map(\.entityKindRaw)) == ["product", "productPrice"] else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            guard let journal = AccountBindingStore().pendingRecoveryJournal,
                  journal.mode == .sameScopeRecovery, journal.phase == .staging,
                  let journalURL = AccountBindingStore().durableRecoveryJournalURLForTesting,
                  changes.allSatisfy({ $0.status == .pending }), price.remoteID == nil,
                  priceChange.entityRemoteID == nil, control.state.savedPriceID == nil,
                  control.state.catalogPayloads.isEmpty, control.state.pricePayloads.isEmpty,
                  control.state.prices.isEmpty, control.state.events.isEmpty,
                  control.state.catalogIngressCount == 0, control.state.priceIngressCount == 0,
                  control.state.eventIngressCount == 0 else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                allowsPendingSameScopeRecovery: true)
            let raw = try Data(contentsOf: journalURL)
            let tokens = changes.map(LocalPendingChangeCASToken.init).sorted { $0.changeID < $1.changeID }
            let witness = try t10LocalPriceWitness(price: price, product: product, change: priceChange,
                scope: scope, originalToken: LocalPendingChangeCASToken(priceChange))
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
            if control.state.savedTokens.isEmpty {
                guard !control.reopening else { throw SyncStoreGenerationError.activationReadBackFailed }
                control.state.originalGeneration = manifest.generationID
                control.state.savedTokens = tokens; control.state.savedLocalPriceWitness = witness
                control.state.journalBytes = raw; try control.persist()
            }
            guard control.state.savedTokens == tokens, control.state.savedLocalPriceWitness == witness,
                  control.hasOriginalPriceWitness(), control.state.savedPriceID == nil,
                  control.state.originalGeneration == manifest.generationID,
                  control.state.journalBytes == raw else { throw SyncStoreGenerationError.activationReadBackFailed }
            facts.insert("task145.t10a.save-durable-before-activation")
            return true
        }
        // A cutover legitimately leaves the acknowledged intents in its source
        // archive. Keep observing while the real journal/finalization completes.
        guard manifest.generationID != control.state.originalGeneration,
              AccountBindingStore().pendingRecoveryJournal == nil else { return false }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
        guard try controller.isActiveRecoveryFinalized(scope: scope) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if control.state.terminalGeneration == nil {
            guard let summary = completedAutomaticRecoverySummary,
                  summary.completedRecoveryJournal,
                  summary.activatedGenerationID == manifest.generationID,
                  summary.watermarkAfter == manifest.checkpoint.maxEventID,
                  let finalization = summary.verifiedFinalization,
                  finalization.exactlyMatches(manifest),
                  finalization.storeIdentity.hasSameProvenance(as: manifest.storeIdentity) else { return false }
        }
        guard changes.isEmpty,
              try context.fetch(FetchDescriptor<SyncEventOutboxEntry>()).isEmpty,
              control.state.catalogPayloads.count == 1, control.state.pricePayloads.count == 1,
              control.state.prices.count == 1, control.state.events.count == 2,
              control.state.catalogIngressCount == 1, control.state.priceIngressCount == 1,
              control.state.eventIngressCount == 2,
              control.state.product.productName == Task145SavedRecoveryControl.savedName,
              control.state.product.purchasePrice == 37,
              control.hasOriginalPriceWitness(),
              let originalProduct = control.state.savedTokens.first(where: { $0.entityKindRaw == "product" }),
              originalProduct.entityRemoteIDRaw == product.remoteID?.uuidString.lowercased(),
              originalProduct.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
              originalProduct.ownerUserID == scope.ownerUserID.uuidString.lowercased(),
              originalProduct.ownerHash == scope.accountHash,
              originalProduct.storeId == scope.storeIdentity.storeId,
              originalProduct.localStoreId == scope.storeIdentity.localStoreId,
              originalProduct.schemaVersion == scope.storeIdentity.schemaVersion,
              originalProduct.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion,
              originalProduct.storeEpoch == scope.storeIdentity.storeEpoch,
              manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
              manifest.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              manifest.deviceIdentityHash == scope.deviceIdentityHash,
              manifest.checkpoint.maxEventID == control.state.events.map(\.id).max(),
              let witness = control.state.savedLocalPriceWitness, let priceID = price.remoteID,
              control.state.savedPriceID == priceID, witness.matchesScope(scope),
              price.price.bitPattern == witness.localPriceBits,
              ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt) == witness.effectiveAt,
              ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt) == witness.createdAt,
              price.source == witness.source, price.note == witness.note,
              try control.observedPriceIsJoined() else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        // The first terminal already verified the real archive ACKs and summary.
        // An ordinary reopen may legitimately clean that retired source archive.
        if control.state.terminalGeneration == nil {
            let archive = try t10ReadOnlySourceArchive(scope: scope, manifest: manifest)
            let sourceContext = ModelContext(archive); sourceContext.autosaveEnabled = false
            let sourceProducts = try sourceContext.fetch(FetchDescriptor<Product>())
            let sourcePrices = try sourceContext.fetch(FetchDescriptor<ProductPrice>())
            let sourceChanges = try sourceContext.fetch(FetchDescriptor<LocalPendingChange>())
            let sourcePriceChanges = sourceChanges.filter { $0.entityKind == .productPrice }
            guard sourceProducts.count == 1, let sourceProduct = sourceProducts.first,
                  sourcePrices.count == 1, let sourcePrice = sourcePrices.first,
                  sourceChanges.count == 2, sourcePriceChanges.count == 1,
                  let sourcePriceChange = sourcePriceChanges.first,
                  Set(sourceChanges.map(\.entityKindRaw)) == ["product", "productPrice"],
                  sourceChanges.allSatisfy({ $0.status == .acknowledged }),
                  sourcePrice.remoteID == priceID, sourcePriceChange.entityRemoteID == priceID,
                  control.hasOriginalPriceWitness(),
                  control.acknowledgedPriceTokenMatches(LocalPendingChangeCASToken(sourcePriceChange)),
                  try t10ArchivedTokensMatch(control.state.savedTokens, changes: sourceChanges, priceID: priceID),
                  try t10LocalPriceWitness(price: sourcePrice, product: sourceProduct, change: sourcePriceChange,
                    scope: scope, originalToken: witness.originalToken) == witness else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            let receipt = LocalProductSaveReceipt(product: sourceProduct, manifest: manifest,
                intents: control.state.savedTokens)
            guard receipt.matches(product), receipt.isCloudConfirmed(by: sourceChanges),
                  controller.activeManifest == manifest,
                  try controller.isActiveRecoveryFinalized(scope: scope),
                  AccountBindingStore().pendingRecoveryJournal == nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        guard controller.activeManifest == manifest,
              try controller.isActiveRecoveryFinalized(scope: scope),
              AccountBindingStore().pendingRecoveryJournal == nil else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        if control.state.terminalGeneration == nil {
            control.state.terminalGeneration = manifest.generationID; try control.persist()
        }
        guard control.state.terminalGeneration == manifest.generationID else { throw SyncStoreGenerationError.activationReadBackFailed }
        facts.insert("task145.t10a.automatic-finished-own-acks")
        return true
    }

    /// Opens only the already existing, sealed source file. It never creates a
    /// generation or uses the production writable-container factory.
    private func t10ReadOnlySourceArchive(scope: Task126VerifiedOwnerStoreScope,
                                          manifest: SyncStoreGenerationManifest) throws -> ModelContainer {
        guard let control = t10Control, let sourceID = control.state.originalGeneration,
              sourceID != manifest.generationID, let bytes = control.state.journalBytes,
              let journal = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              journal["modeRaw"] as? String == AccountRecoveryJournalMode.sameScopeRecovery.rawValue,
              journal["phaseRaw"] as? String == AccountRecoveryJournalPhase.staging.rawValue,
              journal["wipeCommitted"] as? Bool == false,
              journal["deviceIdentityHash"] as? String == scope.deviceIdentityHash,
              let targetRaw = journal["generationID"] as? String, let targetID = UUID(uuidString: targetRaw),
              targetID != sourceID, let replacement = journal["replacement"] as? [String: Any] else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let binding = try JSONDecoder().decode(AccountBinding.self,
            from: JSONSerialization.data(withJSONObject: replacement))
        guard binding.accountHash == scope.accountHash,
              binding.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
              manifest.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              manifest.deviceIdentityHash == scope.deviceIdentityHash else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let root = ownedRepository.baseDirectory.standardizedFileURL
        let url = root.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent(sourceID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("store.store", isDirectory: false)
        guard root.resolvingSymlinksInPath().standardizedFileURL == root,
              url.resolvingSymlinksInPath().standardizedFileURL == url,
              (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let schema = SyncStoreSchema.schema
        let configuration = ModelConfiguration("sync-store-generation", schema: schema, url: url,
            allowsSave: false, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func t10ArchivedTokensMatch(_ originals: [LocalPendingChangeCASToken],
                                        changes: [LocalPendingChange], priceID: UUID) throws -> Bool {
        guard originals.count == 2, changes.count == 2,
              Set(originals.map(\.changeID)).count == 2 else { return false }
        let encoder = JSONEncoder()
        return try originals.allSatisfy { original in
            let matching = changes.filter { $0.changeID == original.changeID }
            guard matching.count == 1, let change = matching.first, change.status == .acknowledged,
                  var expected = try JSONSerialization.jsonObject(with: encoder.encode(original)) as? [String: Any],
                  var actual = try JSONSerialization.jsonObject(with: encoder.encode(LocalPendingChangeCASToken(change))) as? [String: Any] else { return false }
            // Catalog's attempt timestamp and both ACK update timestamps are
            // mutable. The price validator separately keeps its attempt exact.
            for key in ["statusRaw", "updatedAt", "lastAttemptAt"] {
                expected.removeValue(forKey: key); actual.removeValue(forKey: key)
            }
            if original.entityKindRaw == "productPrice" {
                expected["entityRemoteIDRaw"] = priceID.uuidString.lowercased()
            }
            return NSDictionary(dictionary: expected).isEqual(to: actual)
        }
    }

    /// Read the current row and exact original price intent at the existing
    /// automatic remote ingress. Never prepares, saves, assigns an ID or ACKs.
    private func t10PriceWitnessAtIngress(_ payload: SyncAutomaticProductPricePayload,
                                         scope: Task126VerifiedOwnerStoreScope) throws -> Task145SavedRecoveryControl.LocalPriceWitness {
        guard let control = t10Control, let saved = control.state.savedLocalPriceWitness,
              control.state.savedPriceID == nil,
              let journalURL = AccountBindingStore().durableRecoveryJournalURLForTesting,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        func originalRecoveryContextIsCurrent() throws -> Bool {
            let bindingStore = AccountBindingStore()
            guard bindingStore.durableRecoveryJournalURLForTesting == journalURL else { return false }
            return control.matchesOriginalStagingRecoveryContext(scope: scope,
                activeManifest: controller.activeManifest, binding: bindingStore.currentBinding,
                pendingReplacement: bindingStore.pendingReplacement,
                pendingWipeCommitted: bindingStore.pendingReplacementWipeCommitted,
                journal: bindingStore.pendingRecoveryJournal, journalBytes: try Data(contentsOf: journalURL))
        }
        guard try originalRecoveryContextIsCurrent() else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let context = ModelContext(controller.modelContainer); context.autosaveEnabled = false
        let products = try context.fetch(FetchDescriptor<Product>())
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let priceChanges = changes.filter { $0.entityKind == .productPrice }
        guard products.count == 1, let product = products.first,
              prices.count == 1, let price = prices.first, price.remoteID == nil,
              changes.count == 2, Set(changes.map(\.entityKindRaw)) == ["product", "productPrice"],
              priceChanges.count == 1, let change = priceChanges.first,
              change.status == .pending, change.entityRemoteID == nil,
              saved.originalToken.matches(change) else { throw SyncStoreGenerationError.activationReadBackFailed }
        let witness = try t10LocalPriceWitness(price: price, product: product, change: change,
            scope: scope, originalToken: saved.originalToken)
        guard witness == saved, witness.matchesScope(scope), witness.matchesPayload(payload) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        guard try originalRecoveryContextIsCurrent(),
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return witness
    }

    private func t10LocalPriceWitness(price: ProductPrice, product: Product,
                                      change: LocalPendingChange, scope: Task126VerifiedOwnerStoreScope,
                                      originalToken: LocalPendingChangeCASToken) throws -> Task145SavedRecoveryControl.LocalPriceWitness {
        guard let control = t10Control, let productID = product.remoteID,
              productID == control.state.product.id, product.barcode == control.state.product.barcode,
              price.product?.remoteID == productID, price.product?.barcode == product.barcode,
              price.type == .purchase, price.price == 37, scope.ownerUserID == owner,
              scope.shopID == control.state.product.shopID,
              let amount = PriceCanonicalizer.canonicalAmount(from: price.price),
              LocalPendingChangeScopeMatcher.matches(change, ownerUserID: owner,
                accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let key = LocalPendingChangeLogicalKey.productPrice(productRemoteID: productID,
            productBarcode: product.barcode, type: price.type, effectiveAt: price.effectiveAt)
        let fingerprint = LocalPendingChangeLogicalKey.productPriceFingerprintHash(price)
        guard change.entityKind == .productPrice, change.logicalKey == key,
              change.intendedFingerprintHash == fingerprint,
              originalToken.entityKindRaw == "productPrice", originalToken.logicalKey == key,
              originalToken.intendedFingerprintHash == fingerprint else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return Task145SavedRecoveryControl.LocalPriceWitness(ownerUserID: owner, shopID: scope.shopID,
            accountHash: scope.accountHash, storeRawValue: scope.storeIdentity.rawValue,
            defaultStoreID: scope.storeIdentity.defaultStoreId, localStoreID: scope.storeIdentity.localStoreId,
            schemaVersion: scope.storeIdentity.schemaVersion, syncProtocolVersion: scope.storeIdentity.syncProtocolVersion,
            storeEpoch: scope.storeIdentity.storeEpoch, deviceInstallID: scope.deviceInstallID,
            deviceIdentityHash: scope.deviceIdentityHash, productID: productID, productBarcode: product.barcode,
            type: price.type.rawValue.uppercased(), localPriceBits: price.price.bitPattern,
            localEffectiveAt: price.effectiveAt, localCreatedAt: price.createdAt,
            price: amount.doubleValue, amountCanonical: amount.value,
            effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt),
            source: price.source, note: price.note,
            createdAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt),
            logicalKey: key, intendedFingerprintHash: fingerprint, originalToken: originalToken)
    }

    var hasR4ReviewControl: Bool { r4Control != nil }
    lazy var catalogConflictResolutionService = CatalogConflictResolutionService(remote: catalogRemote)
    var r4Ledger: String { r4Control?.ledger ?? "" }

    func prepareR4Peer() {
        guard let control = r4Control, !control.reopening else { return }
        Task {
            do {
                let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
                try await Task126OwnerStoreGate.withAutomaticScope(scope) { try catalogRemote.prepareR4Peer() }
                facts.insert("task145.r4.peer-ready")
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }

    private func prepareR4Root(reopening: Bool) throws {
        guard let control = r4Control, let manifest = controller.activeManifest,
              AccountBindingStore().pendingRecoveryJournal == nil,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if reopening {
            guard control.reopening, control.state.generationID == manifest.generationID,
                  control.state.receiptJSON != nil else { throw SyncStoreGenerationError.activationReadBackFailed }
            let terminalReadback = try observeR4State()
            guard facts.contains("task145.r4.adopted-durable"), !control.state.terminal || terminalReadback else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            facts.insert(terminalReadback ? "task145.r4.terminal-reopened" : "task145.r4.adopted-reopened")
        } else {
            guard !control.reopening, try ModelContext(controller.modelContainer).fetchCount(FetchDescriptor<LocalPendingChange>()) == 0 else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            control.state.generationID = manifest.generationID
            try control.persist()
            facts.insert("task145.r4.ready")
        }
        transport.release()
        hasStarted = true
        isPreparedForRoot = true
        r4ObservationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for _ in 0..<600 {
                    if try observeR4State() { return }
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw URLError(.timedOut)
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }

    private func r4Envelope(id: UUID, payload: SyncAutomaticProductUpdatePayload,
                            scope: Task126VerifiedOwnerStoreScope) throws -> Data {
        let context = ModelContext(controller.modelContainer)
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let entries = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        guard changes.count <= 4, entries.count <= 10 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let matches = try entries.filter(LocalPendingBusinessAttemptStore.isSealed).compactMap { entry -> Data? in
            guard entry.eventType == "catalog" else { return nil }
            let data = try LocalPendingBusinessAttemptStore.validate(entry, kind: "catalog", scope: scope)
            let envelope = try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self, from: data)
            return envelope.payload.call.updateProduct.id == id && envelope.payload.call.updateProduct.payload == payload
                && changes.contains(where: { envelope.pending.matches($0) }) ? data : nil
        }
        guard matches.count == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
        return matches[0]
    }

    /// True means this invocation read the complete current terminal state.
    /// The persisted fixture flag alone never qualifies a later process.
    private func observeR4State() throws -> Bool {
        guard let control = r4Control, let manifest = controller.activeManifest,
              manifest.generationID == control.state.generationID else { throw SyncStoreGenerationError.activationReadBackFailed }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
        guard Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer, ownerUserID: owner) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let context = ModelContext(controller.modelContainer)
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let products = try context.fetch(FetchDescriptor<Product>())
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        guard products.count == 1, let product = products.first, product.remoteID == control.state.product.id,
              changes.count <= 4, prices.count <= 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
        guard let original = control.state.originalPending, let originalSeal = control.state.originalSeal else { return false }
        guard let originalRow = changes.first(where: { $0.changeID == original.changeID }), original.matches(originalRow),
              let seal = try LocalPendingBusinessAttemptStore.entry(changeID: original.changeID, context: context),
              seal.metadataPayloadJSON == originalSeal, let price = prices.first,
              prices.count == 1, price.price == 37, price.product?.remoteID == product.remoteID,
              let child = changes.first(where: { $0.entityKind == .productPrice }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let receipt = try LocalCatalogConflictResolutionStore.receipts(context: context).first
        if receipt == nil {
            if try LocalPendingBusinessAttemptStore.rejectionProof(change: originalRow, context: context, scope: scope) == nil {
                guard stateStore.state.phase.isAutomaticWorkActive else { throw SyncStoreGenerationError.activationReadBackFailed }
                return false
            }
            guard child.status == .pending, CatalogConflictProductValues(product: product) == CatalogConflictProductValues(row: control.state.product),
                  control.state.priceRequests.isEmpty, control.state.priceIngressCount == 0,
                  control.state.catalogIngressCount == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
            if control.state.childBefore == nil { control.state.childBefore = LocalPendingChangeCASToken(child); try control.persist() }
            if !stateStore.state.phase.isAutomaticWorkActive { facts.insert("task145.r4.saved-rejected") }
            return false
        }
        let receiptEntry = receipt!
        guard receiptEntry.1.decision.original == original, receiptEntry.1.decision.choice == .adoptRemote,
              receiptEntry.1.decision.outcome == .adoptedRemote, receiptEntry.1.decision.successor == nil,
              receiptEntry.1.decision.remote.values == receiptEntry.1.decision.desired,
              receiptEntry.1.resolvedChangeIDs == [original.changeID],
              let json = receiptEntry.0.metadataPayloadJSON, let childBefore = control.state.childBefore,
              child.idempotencyKey == childBefore.idempotencyKey, child.changedFieldsRaw == childBefore.changedFieldsRaw,
              child.intendedFingerprintHash == childBefore.intendedFingerprintHash else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if let previous = control.state.receiptJSON {
            guard previous == json else { throw SyncStoreGenerationError.activationReadBackFailed }
        } else { control.state.receiptJSON = json; try control.persist() }
        facts.insert("task145.r4.adopted-durable")
        guard let later = control.state.laterPending else { return false }
        guard let laterRow = changes.first(where: { $0.changeID == later.changeID }),
              laterRow.idempotencyKey == later.idempotencyKey, laterRow.changedFieldsRaw == "itemnumber",
              laterRow.baselineFingerprintHash == receiptEntry.1.decision.remote.values.fingerprint,
              product.itemNumber == Task145R4ReviewControl.itemB,
              product.productName == Task145R4ReviewControl.nameA, product.purchasePrice == 37 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard laterRow.status == .acknowledged, child.status == .acknowledged else { return false }
        guard control.state.catalogRequests.count == 2, control.state.priceRequests.count == 1,
              control.state.catalogIngressCount == 2, control.state.priceIngressCount == 1,
              control.state.prices.count == 1, price.remoteID == control.state.prices[0].id,
              control.state.product.itemNumber == Task145R4ReviewControl.itemB,
              control.state.product.productName == Task145R4ReviewControl.nameA,
              try LocalPendingChangeSnapshotProvider(context: context).loadSnapshot(ownerUserID: owner,
                storeIdentity: scope.storeIdentity).pendingCatalogChangeCount == 0,
              try LocalPendingChangeSnapshotProvider(context: context).loadSnapshot(ownerUserID: owner,
                storeIdentity: scope.storeIdentity).pendingProductPriceChangeCount == 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        control.state.terminal = true
        try control.persist()
        facts.insert("task145.r4.b-and-price-own-ack")
        return true
    }

    private func r4IsTerminalWakeAction(_ action: SyncAction) -> Bool {
        switch action {
        case .noOp, .drainEvents, .lightReconcile: true
        case .sequence(let actions): !actions.isEmpty && actions.allSatisfy(r4IsTerminalWakeAction)
        case .pushPending, .bootstrap, .fullRecovery, .requestRecovery, .retryAfterBusy, .blocked: false
        }
    }

    private func saveBEnvelope(id: UUID, payload: SyncAutomaticProductUpdatePayload,
        scope: Task126VerifiedOwnerStoreScope) throws -> Data {
        let context = ModelContext(controller.modelContainer)
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        guard changes.count <= 2, outbox.count <= 6 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let matching = try outbox.filter(LocalPendingBusinessAttemptStore.isSealed).compactMap { entry -> Data? in
            let data = try LocalPendingBusinessAttemptStore.validate(entry, kind: "catalog", scope: scope)
            let envelope = try JSONDecoder().decode(
                LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self, from: data)
            guard envelope.payload.call.updateProduct.id == id,
                  envelope.payload.call.updateProduct.payload == payload,
                  changes.contains(where: { envelope.pending.matches($0) }) else { return nil }
            return data
        }
        guard matching.count == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
        return matching[0]
    }

    private func prepareSeq6() async throws {
        guard let control = seq6Control, let manifest = controller.activeManifest,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
              AccountBindingStore().pendingRecoveryJournal == nil else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
        guard scope.shopID == shop, scope.storeIdentity == manifest.storeIdentity else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let body = try seq6Body()
        guard body["name"] == "Safe local baseline", body["products"] == "1", body["pending"] == "0",
              body["watermark"] == "41" else { throw SyncStoreGenerationError.activationReadBackFailed }
        control.state.facts = body.merging(["initial-generation": manifest.generationID.uuidString,
            "initial-manifest": body["manifest-sha256"]!, "owner": scope.ownerUserID.uuidString,
            "account-hash": scope.accountHash, "shop": scope.shopID.uuidString,
            "store": scope.storeIdentity.rawValue, "device-hash": scope.deviceIdentityHash,
            "initial-fingerprint": body["fingerprint"]!, "initial-outbox": body["outbox"]!,
            "initial-pending": body["pending"]!, "initial-name": body["name"]!]) { _, new in new }
        if control.state.scenario == .snapshotChanged {
            guard AccountBindingStore().beginSameScopeRecovery(accountHash: scope.accountHash,
                storeIdentity: scope.storeIdentity, reason: "TASK145_SEQ6_CHANGED_SNAPSHOT"),
                let journal = AccountBindingStore().pendingRecoveryJournal,
                journal.mode == .sameScopeRecovery, journal.phase == .prepared else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            control.state.facts["initial-journal"] = SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal)
            controller.startLocalBodyQualification(ownerUserID: owner)
            guard await controller.awaitLocalBodyQualification() else { throw SyncStoreGenerationError.activationReadBackFailed }
            stateStore.reconcilePendingRecoveryJournal()
        }
        if control.state.scenario == .healthyIncremental || control.state.scenario == .missingEntityGap {
            try catalogRemote.prepareSeq6Event(missingIDs: control.state.scenario == .missingEntityGap)
        }
        control.armed = true
        hasStarted = true // No fixture call runs sync; the ordinary root owns every post-setup invocation.
        if !control.state.scenario.isSafety { transport.release() }
        try control.note("qualified-initial-body", body)
        facts.insert("task145.seq6.ready")
        if !control.state.scenario.isSafety { startSeq6Observation() }
        refreshAutomaticObservation()
    }

    private func seq6Body() throws -> [String: String] {
        let context = ModelContext(controller.modelContainer)
        var request = FetchDescriptor<Product>(); request.fetchLimit = 2
        let products = try context.fetch(request)
        guard products.count == 1, let product = products.first, let productName = product.productName,
              product.remoteID == UUID(uuidString: "14400000-0000-4000-8000-000000000003") else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        var outboxRequest = FetchDescriptor<SyncEventOutboxEntry>(); outboxRequest.fetchLimit = 12
        let outbox = try context.fetch(outboxRequest)
        guard outbox.count < 12 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let watermark = WatermarkStore().watermark(for: .init(ownerUserID: owner,
            storeIdentity: LocalStoreIdentity(rawValue: shop.uuidString.lowercased())))
        guard let manifest = controller.activeManifest else { throw SyncStoreGenerationError.activationReadBackFailed }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let manifestHash = ShopSyncRecoveryCanonical.sha256(String(decoding: try encoder.encode(manifest), as: UTF8.self))
        return ["products": "1", "name": productName,
            "manifest-sha256": manifestHash,
            "fingerprint": LocalPendingChangeLogicalKey.productFingerprintHash(product),
            "pending": String(try context.fetchCount(FetchDescriptor<LocalPendingChange>())),
            "outbox": outbox.map { $0.clientEventID + ":" + $0.statusRaw }.sorted().joined(separator: "|"),
            "watermark": String(watermark), "generation": controller.activeManifest?.generationID.uuidString ?? "missing",
            "body-proof": String(Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer)),
            "local-access": String(Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: controller.modelContainer, ownerUserID: owner))]
    }

    private func startSeq6SafetyFault() {
        guard let control = seq6Control, control.armed, control.state.scenario.isSafety,
              !control.actionStarted, !control.reopening else { return }
        control.actionStarted = true
        task = Task { [weak self] in
            guard let self else { return }
            do {
                guard let manifest = controller.activeManifest,
                      manifest.generationID.uuidString == control.state.facts["initial-generation"],
                      Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer, ownerUserID: owner) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                let captured = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
                control.capturedScope = captured
                try control.note("captured-current-writer", ["shop": captured.shopID.uuidString,
                    "store": captured.storeIdentity.rawValue, "generation": manifest.generationID.uuidString])
                switch control.state.scenario {
                case .membershipRefusal:
                    // The provider supplies the same typed response handled by the real resolver.
                    // No session, selected-store record or syncAllowed property is written here.
                    shopFetcher.seq6RefusesPermission = true
                    await shopContextStore.refresh(ownerUserID: owner)
                    guard authViewModel.isSignedIn, authViewModel.localMutationOwnerUserID == owner,
                          !shopContextStore.context.syncAllowed, shopContextStore.context.selectedShop == nil,
                          shopContextStore.context.linkedShops.count == 1,
                          shopContextStore.context.linkedShops[0].status == "revoked",
                          !shopContextStore.context.linkedShops[0].canWrite,
                          SelectedShopStore().selectedShop(accountHash: captured.accountHash) == nil else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    control.state.facts["server-membership"] = "revoked"
                    control.state.facts["sdk-session-preserved"] = "true"
                    do {
                        try Task126OwnerStoreGate.revalidateAutomaticScope(captured)
                        throw Task144ControlledCatalogRemote.Fault.unexpectedCall
                    } catch let error as Task126OwnerStoreGateError {
                        control.state.facts["captured-scope-rejected"] = Task144RootObservation.errorCategory(error)
                    }
                case .corruptBody:
                    // Actual nonempty body corruption, deliberately outside all accepted writers.
                    // The clean fingerprint/metadata and all intent/proof records stay unchanged.
                    let context = ModelContext(controller.modelContainer)
                    context.autosaveEnabled = false
                    let products = try context.fetch(FetchDescriptor<Product>())
                    guard products.count == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
                    products[0].productName = "Unexplained Seq6 clean-body corruption"
                    try context.save()
                    let changed = try seq6Body()
                    guard changed["fingerprint"] != control.state.facts["initial-fingerprint"],
                          changed["pending"] == "0", changed["outbox"] == control.state.facts["initial-outbox"],
                          changed["body-proof"] == "false" else { throw SyncStoreGenerationError.activationReadBackFailed }
                    control.state.facts["corruption-persisted"] = "true"
                    control.state.facts["corrupt-fingerprint"] = changed["fingerprint"]
                    try control.note("nonempty-body-actually-changed", changed)
                    controller.startLocalBodyQualification(ownerUserID: owner)
                    guard !(await controller.awaitLocalBodyQualification()) else { throw SyncStoreGenerationError.activationReadBackFailed }
                    control.state.facts["qualification-rejected"] = "true"
                default: throw Task144ControlledCatalogRemote.Fault.unexpectedCall
                }
                try seq6DeniedWriterReadback(reopening: false)
                control.terminal = true
                facts.insert("task145.seq6.safety-terminal")
                refreshAutomaticObservation()
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }

    private func seq6DeniedWriterReadback(reopening: Bool) throws {
        guard let control = seq6Control, control.state.scenario.isSafety else { throw SyncStoreGenerationError.activationReadBackFailed }
        var entered = false
        do {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: controller.modelContainer, ownerUserID: owner) { _ in
                entered = true
                throw Task144ControlledCatalogRemote.Fault.unexpectedCall
            }
            throw Task144ControlledCatalogRemote.Fault.unexpectedCall
        } catch let error as Task126OwnerStoreGateError {
            guard !entered else { throw error }
            control.state.facts["writer-denial"] = Task144RootObservation.errorCategory(error)
        }
        let body = try seq6Body()
        guard body["local-access"] == "false", body["generation"] == control.state.facts["initial-generation"],
              body["manifest-sha256"] == control.state.facts["initial-manifest"],
              body["pending"] == "0", body["outbox"] == control.state.facts["initial-outbox"],
              body["watermark"] == "41", AccountBindingStore().pendingRecoveryJournal == nil,
              control.count("checkpoint") == 0, control.count("product-write") == 0,
              control.count("event-write") == 0 else { throw SyncStoreGenerationError.activationReadBackFailed }
        switch control.state.scenario {
        case .membershipRefusal:
            guard body["fingerprint"] == control.state.facts["initial-fingerprint"] else { throw SyncStoreGenerationError.activationReadBackFailed }
        case .corruptBody:
            guard body["fingerprint"] == control.state.facts["corrupt-fingerprint"], body["body-proof"] == "false" else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        default: throw Task144ControlledCatalogRemote.Fault.unexpectedCall
        }
        control.state.facts["writer-entered"] = "false"
        control.state.facts[reopening ? "reopen-denied" : "safety-denied"] = "true"
        control.state.facts["observed-pid"] = String(ProcessInfo.processInfo.processIdentifier)
        try control.note(reopening ? "reopen-denial-readback" : "denial-readback", body)
    }

    private func startSeq6Observation() {
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let deadline = ContinuousClock.now.advanced(by: .seconds(60))
                while ContinuousClock.now < deadline {
                    if try seq6TerminalReadback() { return }
                    refreshAutomaticObservation()
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw URLError(.timedOut)
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }

    private func seq6TerminalReadback() throws -> Bool {
        guard let control = seq6Control else { return false }
        if control.terminal { return true }
        guard !stateStore.state.phase.isAutomaticWorkActive,
              let result = control.state.entries.last(where: { $0.kind == "runtime-result" }) else { return false }
        let body = try seq6Body()
        guard body["generation"] == control.state.facts["initial-generation"], body["products"] == "1",
              body["manifest-sha256"] == control.state.facts["initial-manifest"],
              body["pending"] == "0", control.count("product-write") == 0, control.count("event-write") == 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        switch control.state.scenario {
        case .healthyIncremental:
            guard let summary = control.state.entries.first(where: { $0.kind == "incremental-summary" && $0.values["applied"] == "1" }),
                  summary.values["before"] == "41", summary.values["after"] == "42",
                  summary.values["requires-recovery"] == "false", body["watermark"] == "42",
                  body["name"] == "Seq6 remote incremental product", body["body-proof"] == "true",
                  body["local-access"] == "true", result.values["continuation"] == "true",
                  result.values["status"] == "success" || result.values["status"] == "noWork",
                  stateStore.state.phase == .idle else { return false }
            guard control.count("checkpoint") == 0, AccountBindingStore().pendingRecoveryJournal == nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        case .missingEntityGap, .invalidCursor:
            let reason = control.state.scenario == .missingEntityGap ? "sync_event_missing_entity_ids" : "sync_event_invalid_cursor"
            guard let summary = control.state.entries.last(where: { $0.kind == "incremental-summary" }),
                  summary.values["reason"] == reason, summary.values["before"] == "41", summary.values["after"] == "41",
                  summary.values["requires-recovery"] == "true", result.values["status"] == "recoveryRequired" else { return false }
            guard body["watermark"] == "41", body["fingerprint"] == control.state.facts["initial-fingerprint"],
                  control.count("checkpoint") == 0, control.count("fence-advance") == 0,
                  result.values["verified"] == "false" else { throw SyncStoreGenerationError.activationReadBackFailed }
            if control.state.scenario == .missingEntityGap {
                guard let status = SyncEventApplyStatusStore().record(ownerUserID: owner, shopID: shop, eventID: 42),
                      status.status == .blocked, status.reason == .missingEntityIDs else { throw SyncStoreGenerationError.activationReadBackFailed }
                control.state.facts["gap-status"] = "blocked-missingEntityIDs"
            }
        case .snapshotChanged:
            guard result.values["status"] == "failed", result.values["error"] == "checkpointChanged" else { return false }
            guard control.count("checkpoint") >= 2, control.count("checkpoint") <= 4,
                  control.count("snapshot-moved-before-B") >= 1, control.count("marker") == 0,
                  body["watermark"] == "41", body["fingerprint"] == control.state.facts["initial-fingerprint"],
                  body["local-access"] == "true", body["body-proof"] == "true",
                  AccountBindingStore().pendingRecoveryJournal != nil, result.values["verified"] == "false" else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            control.state.facts["snapshot-error"] = "checkpointChanged"
        case .membershipRefusal, .corruptBody: return false
        }
        control.state.facts["terminal"] = "true"
        control.terminal = true
        try control.note("terminal-readback", body)
        facts.insert("task145.seq6.automatic-terminal")
        refreshAutomaticObservation()
        return true
    }

    private func retryCheckpointEntry() throws {
        guard let control = retryControl, control.isArmed else { return } // Initial baseline setup is outside the fault profile.
        guard let journal = AccountBindingStore().pendingRecoveryJournal else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if control.state.savedToken != nil, journal.phase == .prepared {
            guard try retryReadback(atCheckpoint: true) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        try control.checkpoint(journal: journal)
    }

    private func startRetryObservation() {
        guard retryControl != nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                // This bounded observer does not submit a run or advance time.
                let deadline = ContinuousClock.now.advanced(by: .seconds(450))
                while ContinuousClock.now < deadline {
                    if try retryReadback(), retryControl?.state.terminalGeneration != nil { return }
                    refreshAutomaticObservation()
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw URLError(.timedOut)
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }

    private func retryReadback(reopening: Bool = false, atCheckpoint: Bool = false) throws -> Bool {
        guard let control = retryControl, let manifest = controller.activeManifest,
              control.state.generationID != nil else { return false }
        let journal = AccountBindingStore().pendingRecoveryJournal
        if let journal, journal.phase != .prepared { return false }
        // A remount may temporarily lack current shop/body authority. Waiting
        // does not qualify it; reopen and terminal callers still require true.
        guard Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
              let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                allowsPendingSameScopeRecovery: true) else { return false }
        guard scope.shopID == shop, scope.accountHash == manifest.accountHash,
              scope.storeIdentity == manifest.storeIdentity, scope.deviceIdentityHash == manifest.deviceIdentityHash else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let context = ModelContext(controller.modelContainer)
        var productRequest = FetchDescriptor<Product>(); productRequest.fetchLimit = 2
        var pendingRequest = FetchDescriptor<LocalPendingChange>(); pendingRequest.fetchLimit = 3
        var outboxRequest = FetchDescriptor<SyncEventOutboxEntry>(); outboxRequest.fetchLimit = 7
        let products = try context.fetch(productRequest)
        let changes = try context.fetch(pendingRequest)
        let outbox = try context.fetch(outboxRequest)
        guard products.count == 1, let product = products.first,
              product.remoteID == UUID(uuidString: "14400000-0000-4000-8000-000000000003"),
              changes.count <= 1, outbox.count <= 6,
              changes.allSatisfy({ LocalPendingChangeScopeMatcher.matches($0, ownerUserID: owner,
                accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if let journal {
            guard journal.mode == .sameScopeRecovery,
                  SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal) == control.state.journalIdentity else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            // The observer is suspended while Atomic prepares/publishes its
            // private stage; all cooldown evidence belongs to the old generation.
            guard journal.phase == .prepared else { return false }
            guard manifest.generationID == control.state.generationID else { throw SyncStoreGenerationError.activationReadBackFailed }
            guard !control.state.entries.isEmpty else { return false }
            try control.observeCompletion(busy: stateStore.state.phase.isAutomaticWorkActive)
            let budgetBytes = try control.currentBudget()
            let budget = try control.decode(budgetBytes)
            if budget.totalAttempts == 3, let completed = budget.lastCompletedAt,
               Date().timeIntervalSince1970 < budget.nextAllowedAt {
                guard budget.attemptsInWindow == 3, budget.windowIndex == 1,
                      budget.nextAllowedAt >= completed + 300,
                      budget.failure == AutomaticSyncFailure.classify(URLError(.dnsLookupFailed)), !stateStore.state.phase.isAutomaticWorkActive,
                      control.state.entries.count == 3, control.state.completions.count == 3,
                      control.state.results.count == 3 else { throw SyncStoreGenerationError.activationReadBackFailed }
                facts.insert("task145.retry.cooldown-after-three")
            }
            if product.productName == Task145RetryControl.savedName, let change = changes.first {
                if change.status == .pending {
                    // At expiry the real push may legitimately seal A before
                    // its ACK. The subsequent checkpoint reads the own ACK.
                    if Date().timeIntervalSince1970 >= budget.nextAllowedAt { return false }
                    guard budget.totalAttempts == 3, budget.lastCompletedAt != nil,
                          Date().timeIntervalSince1970 < budget.nextAllowedAt,
                          change.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
                          change.lastAttemptAt == nil, change.status == .pending,
                          control.state.productEntries == 0, control.state.eventEntries == 0,
                          !LocalProductSaveReceipt(product: product, manifest: manifest,
                            intents: [LocalPendingChangeCASToken(change)]).isCloudConfirmed(by: [change]) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    if control.state.savedToken == nil {
                        guard !reopening else { throw SyncStoreGenerationError.activationReadBackFailed }
                        control.state.savedToken = LocalPendingChangeCASToken(change)
                        control.state.savedBudgetBytes = budgetBytes
                        try control.persist()
                    }
                    guard control.state.savedToken == LocalPendingChangeCASToken(change),
                          control.state.savedBudgetBytes == budgetBytes else { throw SyncStoreGenerationError.activationReadBackFailed }
                    if reopening {
                        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                        control.qualifiedReopen = try encoder.encode(control.state)
                        facts.insert("task145.retry.pending-reopened-before-deadline")
                    }
                    facts.insert("task145.retry.save-durable-during-cooldown")
                } else if change.status == .acknowledged, let saved = control.state.savedToken {
                    guard change.changeID == saved.changeID, change.idempotencyKey == saved.idempotencyKey,
                          change.intendedFingerprintHash == saved.intendedFingerprintHash,
                          LocalProductSaveReceipt(product: product, manifest: manifest, intents: [saved]).isCloudConfirmed(by: [change]),
                          control.state.productEntries == 1,
                          catalogRemote.recoverySnapshot.product?.productName == Task145RetryControl.savedName else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    let catalogEvents = outbox.filter { $0.domain == "catalog" }
                    guard control.state.eventEntries <= 1, catalogRemote.eventCount <= 1,
                          catalogEvents.count <= 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
                    let registrationComplete = control.state.eventEntries == 1 && catalogRemote.eventCount == 1
                        && catalogEvents.count == 1 && catalogEvents[0].status == .sent
                    if !registrationComplete {
                        // ACK is durable before the engine awaits independent
                        // activity registration. Polling may see that valid
                        // intermediate state; a checkpoint/quiescent boundary may not.
                        guard !atCheckpoint, stateStore.state.phase.isAutomaticWorkActive else {
                            throw SyncStoreGenerationError.activationReadBackFailed
                        }
                        return false
                    }
                    if !control.state.ownACKBeforeRecovery {
                        control.state.ownACKBeforeRecovery = true
                        try control.persist()
                    }
                } else { throw SyncStoreGenerationError.activationReadBackFailed }
            } else if control.state.savedToken != nil { throw SyncStoreGenerationError.activationReadBackFailed }
            if reopening {
                guard facts.contains("task145.retry.pending-reopened-before-deadline") else { return false }
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
            return true
        }
        guard control.state.savedToken != nil, control.state.ownACKBeforeRecovery,
              control.state.entries.filter({ $0.failureUTC != nil }).count == 5,
              control.state.completions.count == 5, control.state.results.count == 5,
              control.state.productEntries == 1, control.state.eventEntries == 1,
              product.productName == Task145RetryControl.savedName,
              changes.allSatisfy({ $0.status.isTerminal }),
              manifest.generationID != control.state.generationID,
              try controller.isActiveRecoveryFinalized(scope: scope),
              completedAutomaticRecoverySummary?.completedRecoveryJournal == true,
              completedAutomaticRecoverySummary?.activatedGenerationID == manifest.generationID,
              !stateStore.state.phase.isAutomaticWorkActive, stateStore.state.lastVerifiedAt != nil else { return false }
        control.state.terminalGeneration = manifest.generationID
        try control.persist()
        facts.insert("task145.retry.automatic-terminal-after-real-cooldown")
        refreshAutomaticObservation()
        return true
    }

    private func startSaveBObservation() {
        guard saveBControl != nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                // Bounded observation, not a second scheduler. All work enters
                // through the normal root/facade and real user Save callbacks.
                for _ in 0..<1200 {
                    if try saveBReadback(), saveBControl?.state.returned.count == 2 { return }
                    refreshAutomaticObservation()
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw URLError(.timedOut)
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }

    private func saveBReadback(reopening: Bool = false) throws -> Bool {
        guard let control = saveBControl, let manifest = controller.activeManifest else { return false }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        guard products.count == 1, changes.count <= 2, outbox.count <= 6,
              let product = products.first, product.remoteID == control.state.product.id,
              product.barcode == "LOCAL-ROOT", product.itemNumber == "root fixture",
              product.supplier == nil, product.category == nil,
              try context.fetchCount(FetchDescriptor<ProductPrice>()) == 0,
              try context.fetchCount(FetchDescriptor<HistoryEntry>()) == 0,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
              changes.allSatisfy({ LocalPendingChangeScopeMatcher.matches($0, ownerUserID: owner,
                  accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) }) else { return false }
        guard let firstData = control.state.firstEnvelope else { return false }
        let first = try control.token(firstData)
        guard let a = changes.first(where: { $0.changeID == first.changeID }),
              a.idempotencyKey == first.idempotencyKey,
              a.intendedFingerprintHash == first.intendedFingerprintHash,
              control.state.committed.contains(first.changeID) else { return false }
        if control.state.secondSavedToken == nil {
            if changes.count == 1, product.productName == Task145SaveBControl.nameA,
               first.matches(a), control.aHeld {
                facts.insert("task145.save-b.a-committed-response-held")
                refreshAutomaticObservation()
                return false
            }
            guard changes.count == 2, let b = changes.first(where: { $0.changeID != first.changeID }),
                  b.status == .pending, b.idempotencyKey != first.idempotencyKey,
                  b.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
                  product.productName == Task145SaveBControl.nameB, first.matches(a), control.aHeld,
                  try saveBEnvelope(id: product.remoteID!, payload: try control.payload(firstData), scope: scope) == firstData else {
                return false
            }
            control.state.secondSavedToken = LocalPendingChangeCASToken(b)
            control.state.generationID = manifest.generationID
            try control.persist()
            facts.insert("task145.save-b.b-durable-a-held")
            refreshAutomaticObservation()
            return false
        }
        guard let savedB = control.state.secondSavedToken,
              let b = changes.first(where: { $0.changeID == savedB.changeID }), changes.count == 2,
              b.idempotencyKey == savedB.idempotencyKey,
              b.intendedFingerprintHash == savedB.intendedFingerprintHash,
              b.changedFieldsRaw == savedB.changedFieldsRaw,
              b.baselineFingerprintHash == savedB.baselineFingerprintHash,
              b.baseRemoteUpdatedAt == SupabaseRemoteDateParser.parse("2026-07-21T12:01:00.000000Z"),
              b.baseVersion == savedB.baseVersion, b.baseEventId == savedB.baseEventId,
              manifest.generationID == control.state.generationID,
              product.productName == Task145SaveBControl.nameB,
              b.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
              a.status == .acknowledged, a.supersededByChangeID == nil else { return false }
        let receipt = LocalProductSaveReceipt(product: product, manifest: manifest, intents: [savedB])
        let events = outbox.filter { $0.domain == "catalog" }
        let expectedIDs = try AutomaticSyncEventOutboxWriter.entityIDs(["product_ids": [control.state.product.id]])
        guard events.count <= 2, events.allSatisfy({ $0.changedCount == 1 && $0.eventType == "catalog_changed" }),
              outbox.allSatisfy({ $0.status == .localOnly || $0.domain == "catalog" }) else { return false }
        for event in events {
            let request = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: event)
            guard request.entityIDs == expectedIDs, request.shopID == scope.shopID,
                  request.sourceDeviceID == scope.deviceInstallID,
                  event.ownerUserID == scope.ownerUserID.uuidString.lowercased(),
                  event.storeId == scope.storeIdentity.storeId, event.localStoreId == scope.storeIdentity.localStoreId,
                  event.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion,
                  event.schemaVersion == scope.storeIdentity.schemaVersion,
                  event.storeEpoch == scope.storeIdentity.storeEpoch else { return false }
            if event.status == .sent {
                guard control.state.eventRequests[event.clientEventID] == Task145SaveBControl.eventIdentity(request) else { return false }
            }
        }
        if b.status == .pending {
            guard let secondData = control.state.secondEnvelope,
                  try control.token(secondData).matches(b),
                  try saveBEnvelope(id: product.remoteID!, payload: try control.payload(secondData), scope: scope) == secondData,
                  !receipt.isCloudConfirmed(by: [b]), control.state.returned == [first.changeID],
                  control.state.committed == [first.changeID], control.state.product.productName == Task145SaveBControl.nameA,
                  events.count == 1, events[0].status == .sent, control.state.events.count == 1,
                  control.state.eventChangeIDs[events[0].clientEventID] == first.changeID,
                  control.state.eventAttempts.count == 1,
                  control.state.eventAttempts[0].clientEventID == events[0].clientEventID,
                  control.state.eventAttempts[0].requestIdentity == control.state.eventRequests[events[0].clientEventID] else { return false }
            if reopening {
                guard control.state.pendingReopenToken == LocalPendingChangeCASToken(b),
                      control.state.firstPID != ProcessInfo.processInfo.processIdentifier,
                      control.state.requests.count == 2 else { return false }
                facts.insert("task145.save-b.pending-reopened")
            } else if control.bHeld, !control.reopening {
                if control.state.pendingReopenToken != LocalPendingChangeCASToken(b) {
                    control.state.pendingReopenToken = LocalPendingChangeCASToken(b)
                    try control.persist()
                }
                facts.insert("task145.save-b.ack-a-b-pending")
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
            refreshAutomaticObservation()
            return true
        }
        guard b.status == .acknowledged, receipt.isCloudConfirmed(by: [b]),
              control.state.product.productName == Task145SaveBControl.nameB,
              control.state.committed == [first.changeID, savedB.changeID],
              control.state.returned == [first.changeID, savedB.changeID],
              control.state.requests.count == 3, control.state.events.count == 2,
              events.count == 2, events.allSatisfy({ $0.status == .sent }),
              Set(events.map(\.clientEventID)) == Set(control.state.eventRequests.keys),
              Set(control.state.eventChangeIDs.values) == Set([first.changeID, savedB.changeID]),
              control.state.eventAttempts.count == 2,
              Set(control.state.eventAttempts.map(\.clientEventID)) == Set(events.map(\.clientEventID)),
              control.state.eventAttempts.allSatisfy({ $0.requestIdentity == control.state.eventRequests[$0.clientEventID] }),
              outbox.allSatisfy({ $0.status == .localOnly || $0.status == .sent }) else { return false }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        facts.insert(reopening ? "task145.save-b.terminal-reopen-qualified" : "task145.save-b.b-own-ack")
        refreshAutomaticObservation()
        return true
    }

    /// The HTTP entry reads the actual durable sealed attempt, independently of
    /// the polling phase oracle. It never mutates client data or manufactures a token.
    private func restartEnvelope(id: UUID, payload: SyncAutomaticProductUpdatePayload,
        scope: Task126VerifiedOwnerStoreScope) throws -> Data {
        guard let control = restartControl, let manifest = controller.activeManifest,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let bytes = try saveBEnvelope(id: id, payload: payload, scope: scope)
        let envelope = try control.decoded(bytes)
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        guard products.count == 1, changes.count == 1,
              let product = products.first, let change = changes.first,
              product.remoteID == id, product.productName == Task145SaveBControl.nameA,
              product.barcode == "LOCAL-ROOT", product.itemNumber == "root fixture",
              product.supplier == nil, product.category == nil,
              try context.fetchCount(FetchDescriptor<ProductPrice>()) == 0,
              try context.fetchCount(FetchDescriptor<HistoryEntry>()) == 0,
              change.status == .pending, envelope.pending.matches(change),
              change.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
              LocalPendingChangeScopeMatcher.matches(change, ownerUserID: owner,
                accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if control.state.savedToken == nil {
            guard control.state.scenario == .postCommit, !control.reopening,
                  control.state.requests.isEmpty else { throw SyncStoreGenerationError.activationReadBackFailed }
            control.state.savedToken = envelope.pending
            control.state.generationID = manifest.generationID
            try control.persist()
        }
        guard control.state.generationID == manifest.generationID else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        return bytes
    }

    private func startRestartObservation() {
        guard restartControl != nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for _ in 0..<1200 {
                    _ = try restartReadback()
                    refreshAutomaticObservation()
                    if facts.contains("task145.restart.own-ack") { return }
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw URLError(.timedOut)
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }

    private func restartReadback(reopening: Bool = false) throws -> Bool {
        guard let control = restartControl, let manifest = controller.activeManifest,
              let rawCatalogEntries = control.state.rawCatalogEntryCount,
              control.state.rawCatalogEntryCapped == false,
              rawCatalogEntries == control.state.requests.count else { return false }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        guard products.count == 1, changes.count == 1, outbox.count <= 3,
              let product = products.first, let change = changes.first,
              product.remoteID == control.state.product.id,
              product.productName == Task145SaveBControl.nameA,
              product.barcode == "LOCAL-ROOT", product.itemNumber == "root fixture",
              product.supplier == nil, product.category == nil,
              try context.fetchCount(FetchDescriptor<ProductPrice>()) == 0,
              try context.fetchCount(FetchDescriptor<HistoryEntry>()) == 0,
              AccountBindingStore().pendingRecoveryJournal == nil,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
              LocalPendingChangeScopeMatcher.matches(change, ownerUserID: owner,
                accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) else { return false }
        if control.state.savedToken == nil {
            guard !reopening, !control.reopening, change.status == .pending,
                  control.state.requests.isEmpty,
                  (control.state.scenario == .postCommit || outbox.allSatisfy({ !LocalPendingBusinessAttemptStore.isSealed($0) })),
                  change.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product) else { return false }
            control.state.savedToken = LocalPendingChangeCASToken(change)
            control.state.generationID = manifest.generationID
            try control.persist()
        }
        guard let saved = control.state.savedToken,
              manifest.generationID == control.state.generationID,
              change.changeID == saved.changeID, change.idempotencyKey == saved.idempotencyKey,
              change.intendedFingerprintHash == saved.intendedFingerprintHash,
              change.changedFieldsRaw == saved.changedFieldsRaw,
              change.baselineFingerprintHash == saved.baselineFingerprintHash,
              change.baseRemoteUpdatedAt == saved.baseRemoteUpdatedAt,
              change.baseVersion == saved.baseVersion, change.baseEventId == saved.baseEventId,
              change.supersededByChangeID == nil else { return false }
        if reopening {
            guard control.state.firstPID != ProcessInfo.processInfo.processIdentifier else { return false }
        }
        if change.status == .pending {
            guard control.state.returned.isEmpty, control.state.events.isEmpty,
                  control.state.eventAttempts.isEmpty,
                  !LocalProductSaveReceipt(product: product, manifest: manifest, intents: [saved]).isCloudConfirmed(by: [change]) else { return false }
            if control.state.scenario == .preSend {
                guard saved.matches(change), control.state.requests.isEmpty, control.state.committed.isEmpty,
                      control.state.envelope == nil, control.state.product.productName == "Safe local baseline",
                      outbox.allSatisfy({ !LocalPendingBusinessAttemptStore.isSealed($0) }) else { return false }
                facts.insert("task145.restart.pre-send-durable-zero-rpc")
            } else if let bytes = control.state.envelope {
                let envelope = try control.decoded(bytes)
                guard envelope.pending.matches(change), control.state.requests == [bytes],
                      control.state.committed == [saved.changeID], control.state.product.productName == Task145SaveBControl.nameA,
                      (reopening || control.reopening || control.responseHeld),
                      try saveBEnvelope(id: product.remoteID!, payload: envelope.payload.call.updateProduct.payload, scope: scope) == bytes else { return false }
                facts.insert("task145.restart.post-commit-response-held")
            } else {
                // Initial Save is durable; only the user restores availability.
                guard !reopening, saved.matches(change), control.state.requests.isEmpty else { return false }
                facts.insert("task145.restart.saved-before-admission")
            }
            if reopening { facts.insert("task145.restart.pending-reopen-qualified") }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
            refreshAutomaticObservation()
            return true
        }
        guard let bytes = control.state.envelope,
              change.status == .acknowledged,
              LocalProductSaveReceipt(product: product, manifest: manifest, intents: [saved]).isCloudConfirmed(by: [change]),
              control.state.product.productName == Task145SaveBControl.nameA,
              control.state.committed == [saved.changeID], control.state.returned == [saved.changeID],
              control.state.requests.count == (control.state.scenario == .preSend ? 1 : 2),
              control.state.requests.allSatisfy({ $0 == bytes }),
              control.state.events.count == 1, control.state.eventAttempts.count == 1,
              outbox.filter({ LocalPendingBusinessAttemptStore.isSealed($0) }).isEmpty else { return false }
        let events = outbox.filter { $0.domain == "catalog" }
        guard events.count == 1, let event = events.first, event.status == .sent,
              outbox.allSatisfy({ $0.status == .localOnly || $0.status == .sent }) else { return false }
        let request = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: event)
        guard request.entityIDs == (try AutomaticSyncEventOutboxWriter.entityIDs(["product_ids": [control.state.product.id]])),
              request.domain == "catalog", request.eventType == "catalog_changed", request.changedCount == 1,
              request.shopID == scope.shopID, request.sourceDeviceID == scope.deviceInstallID,
              event.ownerUserID == scope.ownerUserID.uuidString.lowercased(),
              event.storeId == scope.storeIdentity.storeId, event.localStoreId == scope.storeIdentity.localStoreId,
              event.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion,
              event.schemaVersion == scope.storeIdentity.schemaVersion, event.storeEpoch == scope.storeIdentity.storeEpoch,
              control.state.eventClientIDs[request.clientEventID]?.id == control.state.events.first?.id,
              control.state.eventAttempts[0].clientEventID == request.clientEventID,
              control.state.eventAttempts[0].requestIdentity == Task145SaveBControl.eventIdentity(request) else { return false }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        facts.insert(reopening ? "task145.restart.terminal-reopen-qualified" : "task145.restart.own-ack")
        refreshAutomaticObservation()
        return true
    }

    private func domainCatalogEnvelope(id: UUID, payload: SyncAutomaticProductUpdatePayload,
        scope: Task126VerifiedOwnerStoreScope) throws -> Data {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        guard products.count == 1, let product = products.first, product.remoteID == id,
              changes.count <= 4, outbox.count <= 10 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let matches = try outbox.filter { LocalPendingBusinessAttemptStore.isSealed($0) && $0.eventType == "catalog" }
            .map { try LocalPendingBusinessAttemptStore.validate($0, kind: "catalog", scope: scope) }
        let selected = try matches.filter { bytes in
            let stored = try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self, from: bytes)
            return stored.payload.call.updateProduct.id == id && stored.payload.call.updateProduct.payload == payload
                && changes.contains { stored.pending.matches($0) }
                && stored.pending.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product)
                && stored.pending.changedFieldsRaw == "retailprice"
        }
        guard selected.count == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
        return selected[0]
    }

    private func domainPriceTokens(_ payloads: [SyncAutomaticProductPricePayload], scope: Task126VerifiedOwnerStoreScope) throws -> [LocalPendingChangeCASToken] {
        let context = ModelContext(controller.modelContainer)
        let points = try context.fetch(FetchDescriptor<ProductPrice>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        guard points.count <= 2, changes.count <= 4,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return try payloads.map { payload in
            let matching = points.filter { point in
                point.product?.remoteID == payload.productID && point.type == .retail &&
                PriceCanonicalizer.canonicalAmount(from: point.price)?.doubleValue == payload.price
            }
            guard matching.count == 1, let point = matching.first,
                  ProductPriceEffectiveAtCanonicalizer.canonicalString(from: point.effectiveAt) == payload.effectiveAt,
                  ProductPriceEffectiveAtCanonicalizer.canonicalString(from: point.createdAt) == payload.createdAt,
                  point.source == payload.source, point.note == payload.note,
                  point.remoteID == nil || point.remoteID == payload.id else { throw SyncStoreGenerationError.activationReadBackFailed }
            let key = LocalPendingChangeLogicalKey.productPrice(productRemoteID: point.product?.remoteID,
                productBarcode: point.product?.barcode ?? "", type: point.type, effectiveAt: point.effectiveAt)
            let pending = changes.filter { $0.entityKind == .productPrice && $0.logicalKey == key }
            guard pending.count == 1, let change = pending.first, change.status == .pending,
                  change.intendedFingerprintHash == LocalPendingChangeLogicalKey.productPriceFingerprintHash(point),
                  LocalPendingChangeScopeMatcher.matches(change, ownerUserID: owner,
                    accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            return LocalPendingChangeCASToken(change)
        }
    }

    private func domainHistoryEnvelope(_ row: SharedSheetSessionUpsertRow, scope: Task126VerifiedOwnerStoreScope) throws -> Data {
        let context = ModelContext(controller.modelContainer)
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        guard entries.count == 1, let entry = entries.first, entry.remoteID == row.remoteID,
              entry.isCompatibleWithHistoryScope(ownerUserID: owner, selectedShopID: scope.shopID, storeIdentity: scope.storeIdentity),
              changes.count <= 2, outbox.count <= 5 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let matches = try outbox.filter { LocalPendingBusinessAttemptStore.isSealed($0) && $0.eventType == "history" }
            .map { try LocalPendingBusinessAttemptStore.validate($0, kind: "history", scope: scope) }
        let selected = try matches.filter { bytes in
            let stored = try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task145ObservedHistoryUpload>.self, from: bytes)
            return stored.payload.row == row && changes.contains { stored.pending.matches($0) }
                && stored.payload.localUID == entry.uid && stored.payload.revision <= entry.localChangeRevision
                && stored.payload.payloadFingerprint == HistorySessionPayloadCodec.fingerprintHash(for: row)
        }
        guard selected.count == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
        return selected[0]
    }

    private func domainEventReadback(_ request: SyncEventRecordRequest, scope: Task126VerifiedOwnerStoreScope) throws {
        guard let control = domainControl else { throw SyncStoreGenerationError.activationReadBackFailed }
        let context = ModelContext(controller.modelContainer)
        let rows = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>()).filter { $0.clientEventID == request.clientEventID }
        guard rows.count == 1, let entry = rows.first,
              try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: entry) == request,
              entry.ownerUserID == scope.ownerUserID.uuidString.lowercased(),
              entry.storeId == scope.storeIdentity.storeId, entry.localStoreId == scope.storeIdentity.localStoreId,
              entry.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion,
              entry.schemaVersion == scope.storeIdentity.schemaVersion, entry.storeEpoch == scope.storeIdentity.storeEpoch,
              request.shopID == scope.shopID, request.sourceDeviceID == scope.deviceInstallID else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let ids: SyncEventJSONValue
        if control.state.domain == .prices, request.domain == "catalog" {
            guard request.eventType == "catalog_changed", request.changedCount == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
            ids = try AutomaticSyncEventOutboxWriter.entityIDs(["product_ids": [control.state.product.id]])
        } else if control.state.domain == .prices, request.domain == "prices" {
            guard request.eventType == "prices_changed", request.changedCount == 2, control.state.prices.count == 2 else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            ids = try AutomaticSyncEventOutboxWriter.entityIDs(["price_ids": control.state.prices.map(\.id), "product_ids": [control.state.product.id]])
        } else if control.state.domain == .history, request.domain == "history" {
            guard request.eventType == "history_changed", request.changedCount == 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
            ids = try AutomaticSyncEventOutboxWriter.entityIDs(["session_ids": [Task145DomainControl.historyID]])
        } else { throw SyncStoreGenerationError.activationReadBackFailed }
        guard request.entityIDs == ids else { throw SyncStoreGenerationError.activationReadBackFailed }
    }

    private func domainClientSnapshot() throws -> Data {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        let history = try context.fetch(FetchDescriptor<HistoryEntry>())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let value: [String: Any] = [
            "products": products.map(LocalPendingChangeLogicalKey.productFingerprintHash).sorted(),
            "pending": try changes.map { try encoder.encode(LocalPendingChangeCASToken($0)).base64EncodedString() }.sorted(),
            "prices": prices.map { LocalPendingChangeLogicalKey.productPriceFingerprintHash($0) + "|" + ($0.remoteID?.uuidString ?? "") }.sorted(),
            "history": history.map { "\($0.uid)|\($0.title)|\($0.localChangeRevision)|\($0.lastSyncedLocalRevision)|" + HistorySessionPayloadCodec.fingerprintHash(for: HistorySessionPayloadSnapshotFactory.snapshot(for: $0, ensureRemoteID: false)) }.sorted()
        ]
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private func domainProbeAfterPublish() throws {
        guard let control = domainControl, control.state.staleWriter == nil,
              let old = domainOldContainer, let lease = domainOldLease,
              let manifest = controller.activeManifest,
              !control.state.savedA.isEmpty, manifest.generationID != control.state.generationBeforeCutover else { return }
        do {
            try controller.validateLease(lease)
            throw SyncStoreGenerationError.activationReadBackFailed
        } catch SyncStoreGenerationError.staleGenerationLease { }
        let context = ModelContext(controller.modelContainer)
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        guard changes.count == control.state.savedA.count,
              control.state.savedA.allSatisfy({ saved in changes.contains { $0.changeID == saved.changeID
                && $0.idempotencyKey == saved.idempotencyKey && $0.intendedFingerprintHash == saved.intendedFingerprintHash
                && $0.status == .pending } }) else { throw SyncStoreGenerationError.activationReadBackFailed }
        let before = try domainClientSnapshot()
        let rpcBefore = control.rpcCount
        var entered = false
        do {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: old, ownerUserID: owner) { context in
                entered = true
                guard let product = try context.fetch(FetchDescriptor<Product>()).first else { throw SyncStoreGenerationError.activationReadBackFailed }
                product.productName = "FORBIDDEN_STALE_DOMAIN_WRITE"
                try LocalPendingChangeAccumulator(context: context, ownerUserID: owner).recordProductChange(
                    product: product, operation: .update, origin: .manualCatalogSave, changedFields: ["productName"])
                try context.save()
            }
            throw SyncStoreGenerationError.activationReadBackFailed
        } catch Task126OwnerStoreGateError.retiredStoreGeneration { }
        let after = try domainClientSnapshot()
        guard !entered, before == after, rpcBefore == 0, control.rpcCount == rpcBefore else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        control.state.generationAfterCutover = manifest.generationID
        control.state.staleWriter = .init(oldPresentationID: lease.presentationID, currentPresentationID: controller.presentationID,
            error: "retiredStoreGeneration", closureEntered: entered, before: before, after: after,
            rpcBefore: rpcBefore, rpcAfter: control.rpcCount)
        try control.persist()
        facts.insert("task145.domain.cutover-pending-stale-writer-rejected")
    }

    var hasHistoryFeedback: Bool { domainControl?.state.historyFeedback != nil }
    var historyFeedbackService: HistorySessionSyncService? {
        hasHistoryFeedback ? HistorySessionSyncService(remote: catalogRemote) : nil
    }

    private func prepareHistoryFeedbackLocalSuccess() throws {
        guard let control = domainControl, control.state.historyFeedback != nil else { return }
        guard !control.reopening, control.state.historyFeedback?.localSuccess == nil,
              control.rpcCount == 0, Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let context = ModelContext(controller.modelContainer)
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>())
        let products = try context.fetch(FetchDescriptor<Product>())
        guard entries.count == 1, products.count == 1, products[0].stockQuantity == 1,
              entries[0].data == [["barcode", "quantity", "SyncError"], ["LOCAL-ROOT", "1", ""]],
              !entries[0].isHistorySessionDirtyForCloud,
              try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let before = HistorySessionPayloadCodec.fingerprintHash(for: HistorySessionPayloadSnapshotFactory.snapshot(for: entries[0], ensureRemoteID: false))
        let revision = entries[0].localChangeRevision
        // Execute the real local application; no synthetic status assignment or ACK.
        let result = try InventorySyncService(context: context).sync(entry: entries[0], ownerUserID: owner)
        let fresh = ModelContext(controller.modelContainer)
        let rows = try fresh.fetch(FetchDescriptor<HistoryEntry>())
        let freshProducts = try fresh.fetch(FetchDescriptor<Product>())
        guard result.attemptedUpdates == 1, result.succeeded == 1, result.failed == 0,
              result.pendingCloudChanges == 0, result.priceRowsInserted == 0,
              rows.count == 1, rows[0].syncStatus == .syncedSuccessfully,
              rows[0].localChangeRevision == revision, !rows[0].isHistorySessionDirtyForCloud,
              before == HistorySessionPayloadCodec.fingerprintHash(for: HistorySessionPayloadSnapshotFactory.snapshot(for: rows[0], ensureRemoteID: false)),
              freshProducts.count == 1, freshProducts[0].stockQuantity == 1,
              try fresh.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        control.state.historyFeedback?.localSuccess = ["pid": Int(ProcessInfo.processInfo.processIdentifier),
            "attempted": result.attemptedUpdates, "succeeded": result.succeeded, "failed": result.failed,
            "pendingCloudChanges": result.pendingCloudChanges, "priceRowsInserted": result.priceRowsInserted,
            "revision": revision]
        try control.persist()
        facts.insert("task145.history-feedback.local-success-qualified")
    }

    private func captureHistoryFeedback(_ stage: String, entry: HistoryEntry, changes: [LocalPendingChange], generation: UUID) throws {
        guard let control = domainControl, let feedback = control.state.historyFeedback else { return }
        guard !feedback.poisoned, feedback.localSuccess?["attempted"] == 1,
              feedback.localSuccess?["succeeded"] == 1, feedback.localSuccess?["failed"] == 0,
              feedback.localSuccess?["pendingCloudChanges"] == 0, feedback.localSuccess?["priceRowsInserted"] == 0,
              entry.syncStatus == .syncedSuccessfully else { throw SyncStoreGenerationError.activationReadBackFailed }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let snapshot: [String: String] = ["stage": stage, "generation": generation.uuidString,
            "uid": entry.uid.uuidString, "title": entry.title, "localStatus": String(entry.syncStatus.rawValue),
            "localRevision": String(entry.localChangeRevision), "syncedRevision": String(entry.lastSyncedLocalRevision),
            "dirty": String(entry.isHistorySessionDirtyForCloud),
            "pending": String(changes.filter { $0.status == .pending }.count),
            "bodyFingerprint": HistorySessionPayloadCodec.fingerprintHash(for: HistorySessionPayloadSnapshotFactory.snapshot(for: entry, ensureRemoteID: false)),
            "tokens": try encoder.encode(changes.map(LocalPendingChangeCASToken.init).sorted { $0.changeID < $1.changeID }).base64EncodedString()]
        if let previous = feedback.frames.first(where: { $0["stage"] == stage }) {
            guard previous == snapshot else { throw SyncStoreGenerationError.activationReadBackFailed }
        } else {
            guard feedback.frames.count < 4 else { throw SyncStoreGenerationError.activationReadBackFailed }
            control.state.historyFeedback?.frames.append(snapshot)
            try control.persist()
        }
    }

    private func historyFeedbackACKA(entry: HistoryEntry, product: Product, changes: [LocalPendingChange], generation: UUID,
                                     scope: Task126VerifiedOwnerStoreScope) throws -> Bool {
        guard let control = domainControl, control.state.historyFeedback != nil,
              control.feedbackBHeld, control.state.savedA.count == 1, control.state.savedB.count == 1,
              control.state.requests.count == 2, control.state.historyRPCCount == 2,
              control.state.returnedChangeIDs == [control.state.savedA[0].changeID],
              control.state.committedChangeIDs == control.state.returnedChangeIDs,
              control.state.history[0].displayName == Task145DomainControl.titleA,
              control.state.events.isEmpty, control.state.eventAttempts.isEmpty, control.state.eventRPCCount == 0,
              changes.count == 2,
              let a = changes.first(where: { $0.changeID == control.state.savedA[0].changeID }), a.status == .acknowledged,
              let b = changes.first(where: { $0.changeID == control.state.savedB[0].changeID }), b.status == .pending,
              control.state.requests[1].tokens.count == 1, control.state.requests[1].tokens[0].matches(b),
              b.idempotencyKey == control.state.savedB[0].idempotencyKey,
              b.intendedFingerprintHash == control.state.savedB[0].intendedFingerprintHash,
              entry.title == Task145DomainControl.titleB, entry.localChangeRevision == control.state.revisionB,
              entry.lastSyncedLocalRevision == control.state.revisionA, entry.isHistorySessionDirtyForCloud,
              try domainIntentsMatchBody([b], product: product, prices: [], history: [entry]) else { return false }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        try captureHistoryFeedback("a-ack-b-pending", entry: entry, changes: changes, generation: generation)
        facts.insert("task145.history-feedback.a-ack-b-pending")
        refreshAutomaticObservation()
        return true
    }

    func releaseHistoryFeedbackA() {
        do {
            guard let control = domainControl, control.state.historyFeedback != nil,
                  facts.contains("task145.domain.b-durable-a-held"), try domainReadback(),
                  control.responseHeld, control.state.returnedChangeIDs.isEmpty else { throw SyncStoreGenerationError.activationReadBackFailed }
            control.state.historyFeedback?.releaseA = true; try control.persist()
        } catch { failHistoryFeedback(error) }
    }
    func releaseHistoryFeedbackB() {
        do {
            guard let control = domainControl, control.state.historyFeedback != nil,
                  try domainReadback(), facts.contains("task145.history-feedback.a-ack-b-pending"),
                  control.feedbackBHeld else { throw SyncStoreGenerationError.activationReadBackFailed }
            control.state.historyFeedback?.releaseB = true; try control.persist()
        } catch { failHistoryFeedback(error) }
    }
    private func failHistoryFeedback(_ error: Error) {
        domainControl?.state.historyFeedback?.poisoned = true
        try? domainControl?.persist()
        facts.remove("task145.history-feedback.a-ack-b-pending")
        facts.remove("task145.domain.b-own-ack")
        facts.remove("task145.domain.terminal-reopened-no-resend")
        recordSetupFailure(error, stage: .automaticTerminal)
    }

    private func startDomainObservation() {
        guard domainControl != nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for _ in 0..<1200 {
                    _ = try domainReadback()
                    refreshAutomaticObservation()
                    if facts.contains("task145.domain.b-own-ack") { return }
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw URLError(.timedOut)
            } catch {
                if hasHistoryFeedback { failHistoryFeedback(error) }
                else { recordSetupFailure(error, stage: .automaticTerminal) }
            }
        }
    }

    private func domainReadback(heldPage: Bool = false, reopening: Bool = false) throws -> Bool {
        guard let control = domainControl, let manifest = controller.activeManifest else { return false }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, allowsPendingSameScopeRecovery: true)
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        let history = try context.fetch(FetchDescriptor<HistoryEntry>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        let priceMode = control.state.domain == .prices
        guard products.count == 1, let product = products.first,
              product.remoteID == control.state.product.id, product.productName == "Safe local baseline",
              product.barcode == "LOCAL-ROOT", product.itemNumber == "root fixture", product.purchasePrice == nil,
              product.supplier == nil, product.category == nil, changes.count <= (priceMode ? 4 : 2), outbox.count <= 10,
              !control.state.rpcOverflow, control.state.historyFeedback?.poisoned != true,
              control.state.historyFeedback == nil || product.stockQuantity == 1,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer),
              changes.allSatisfy({ LocalPendingChangeScopeMatcher.matches($0, ownerUserID: owner,
                accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) && $0.supersededByChangeID == nil }) else { return false }
        if priceMode {
            guard history.isEmpty, prices.count == 1 || prices.count == 2,
                  prices.allSatisfy({ $0.type == .retail && $0.product?.remoteID == product.remoteID
                    && $0.source == "EDIT_PRODUCT" && ($0.price == 12 || $0.price == 13) }),
                  Set(prices.map(\.price)).count == prices.count else { return false }
        } else {
            guard prices.isEmpty, product.retailPrice == nil, history.count == 1,
                  history[0].remoteID == Task145DomainControl.historyID,
                  history[0].isCompatibleWithHistoryScope(ownerUserID: owner, selectedShopID: scope.shopID, storeIdentity: scope.storeIdentity),
                  history[0].data == control.state.history[0].data,
                  history[0].editable == control.state.history[0].sessionOverlay?.editable,
                  history[0].complete == control.state.history[0].sessionOverlay?.complete else { return false }
        }
        if heldPage {
            guard changes.count == (priceMode ? 2 : 1), changes.allSatisfy({ $0.status == .pending }),
                  control.rpcCount == 0, control.state.requests.isEmpty,
                  priceMode ? (prices.count == 1 && product.retailPrice == 12) : (history[0].title == Task145DomainControl.titleA) else { return false }
            guard try domainIntentsMatchBody(changes, product: product, prices: prices, history: history) else { return false }
            if control.state.savedA.isEmpty {
                control.state.savedA = changes.map(LocalPendingChangeCASToken.init).sorted { $0.changeID < $1.changeID }
                control.state.generationBeforeCutover = manifest.generationID
                if !priceMode { control.state.revisionA = history[0].localChangeRevision }
                try control.persist()
            }
            if control.state.historyFeedback != nil {
                try captureHistoryFeedback("a-local", entry: history[0], changes: changes, generation: manifest.generationID)
            }
            facts.insert("task145.domain.a-durable-held-page")
            refreshAutomaticObservation()
            return true
        }
        guard control.state.generationAfterCutover == manifest.generationID,
              control.state.generationBeforeCutover != manifest.generationID,
              let stale = control.state.staleWriter, stale.error == "retiredStoreGeneration", !stale.closureEntered,
              stale.before == stale.after, stale.rpcBefore == 0, stale.rpcAfter == 0,
              AccountBindingStore().pendingRecoveryJournal == nil else { return false }
        let aIDs = Set(control.state.savedA.map(\.changeID))
        let first = changes.filter { aIDs.contains($0.changeID) }
        guard first.count == control.state.savedA.count,
              control.state.savedA.allSatisfy({ saved in first.contains { $0.changeID == saved.changeID
                && $0.idempotencyKey == saved.idempotencyKey && $0.intendedFingerprintHash == saved.intendedFingerprintHash } }) else { return false }
        let domainA = first.filter { priceMode ? $0.entityKind == .productPrice : $0.entityKind == .historySession }
        guard domainA.count == 1 else { return false }
        if control.state.returnedChangeIDs.isEmpty {
            guard control.state.requests.count == 1, control.state.committedChangeIDs == [domainA[0].changeID],
                  domainA[0].status == .pending, control.state.events.isEmpty, control.state.eventAttempts.isEmpty, control.state.eventRPCCount == 0,
                  reopening || control.reopening || control.responseHeld else { return false }
            if priceMode {
                guard first.first(where: { $0.entityKind == .product })?.status == .acknowledged,
                      control.state.catalogRPCCount == 1, control.state.priceRPCCount == 1, control.state.historyRPCCount == 0,
                      control.state.catalogEnvelopes.count == 1, control.state.product.retailPrice == 12,
                      control.state.prices.count == 1, control.state.prices[0].price == 12 else { return false }
            } else {
                guard let bytes = control.state.requests[0].sealedEnvelope,
                      control.state.catalogRPCCount == 0, control.state.priceRPCCount == 0, control.state.historyRPCCount == 1,
                      let rowBytes = control.state.requests[0].payloads.first,
                      control.state.history[0].displayName == Task145DomainControl.titleA,
                      try domainHistoryEnvelope(JSONDecoder().decode(SharedSheetSessionUpsertRow.self, from: rowBytes), scope: scope) == bytes else { return false }
            }
            let b = changes.filter { !aIDs.contains($0.changeID) }
            if b.isEmpty {
                guard !reopening, control.state.savedB.isEmpty,
                      priceMode ? product.retailPrice == 12 : history[0].title == Task145DomainControl.titleA else { return false }
                facts.insert("task145.domain.a-committed-response-held")
                refreshAutomaticObservation()
                return true
            }
            guard b.count == (priceMode ? 2 : 1), b.allSatisfy({ $0.status == .pending && !control.state.savedA.map(\.idempotencyKey).contains($0.idempotencyKey) }),
                  priceMode ? (prices.count == 2 && product.retailPrice == 13) : (history[0].title == Task145DomainControl.titleB),
                  try domainIntentsMatchBody(b, product: product, prices: prices.filter { $0.price == 13 }, history: history) else { return false }
            if control.state.savedB.isEmpty {
                guard !reopening else { return false }
                control.state.savedB = b.map(LocalPendingChangeCASToken.init).sorted { $0.changeID < $1.changeID }
                if !priceMode { control.state.revisionB = history[0].localChangeRevision }
                try control.persist()
            }
            guard control.state.savedB.allSatisfy({ saved in b.contains { saved.matches($0) } }) else { return false }
            if priceMode {
                guard !LocalProductSaveReceipt(product: product, manifest: manifest, intents: control.state.savedB).isCloudConfirmed(by: b) else { return false }
            } else {
                guard let aRevision = control.state.revisionA, control.state.revisionB == aRevision + 1,
                      history[0].localChangeRevision == control.state.revisionB,
                      history[0].lastSyncedLocalRevision < aRevision else { return false }
            }
            if control.state.historyFeedback != nil {
                try captureHistoryFeedback("b-dirty-a-held", entry: history[0], changes: changes, generation: manifest.generationID)
            }
            if reopening {
                guard control.state.firstPID != ProcessInfo.processInfo.processIdentifier else { return false }
                facts.insert("task145.domain.pending-reopen-qualified")
            } else { facts.insert("task145.domain.b-durable-a-held") }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
            refreshAutomaticObservation()
            return true
        }
        if control.state.historyFeedback != nil, control.state.returnedChangeIDs.count == 1 {
            return try historyFeedbackACKA(entry: history[0], product: product, changes: changes,
                generation: manifest.generationID, scope: scope)
        }
        let saved = control.state.savedA + control.state.savedB
        guard !control.state.savedB.isEmpty, changes.count == saved.count,
              changes.allSatisfy({ $0.status == .acknowledged }),
              saved.allSatisfy({ token in changes.contains { $0.changeID == token.changeID && $0.idempotencyKey == token.idempotencyKey
                && $0.intendedFingerprintHash == token.intendedFingerprintHash } }),
              !outbox.contains(where: LocalPendingBusinessAttemptStore.isSealed),
              outbox.allSatisfy({ $0.status == .localOnly || $0.status == .sent }) else { return false }
        let relevant = changes.filter { priceMode ? $0.entityKind == .productPrice : $0.entityKind == .historySession }
        guard relevant.count == 2, Set(control.state.committedChangeIDs) == Set(relevant.map(\.changeID)),
              Set(control.state.returnedChangeIDs) == Set(relevant.map(\.changeID)) else { return false }
        if priceMode {
            guard prices.count == 2, control.state.prices.count == 2, product.retailPrice == 13, control.state.product.retailPrice == 13,
                  control.state.catalogRPCCount == 2, control.state.priceRPCCount == 2, control.state.historyRPCCount == 0,
                  Set(prices.compactMap(\.remoteID)) == Set(control.state.prices.map(\.id)),
                  control.state.requests.count == 2, control.state.requests[0].payloads.count == 1,
                  control.state.requests[1].payloads.contains(control.state.requests[0].payloads[0]),
                  control.state.catalogEnvelopes.count == 2,
                  LocalProductSaveReceipt(product: product, manifest: manifest, intents: control.state.savedB).isCloudConfirmed(by: changes) else { return false }
            for price in prices {
                guard let remote = control.state.prices.first(where: { $0.id == price.remoteID }),
                      price.price == remote.price, remote.productID == product.remoteID,
                      ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt) == remote.effectiveAt,
                      ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt) == remote.createdAt else { return false }
            }
        } else {
            guard history[0].title == Task145DomainControl.titleB, history[0].localChangeRevision == control.state.revisionB,
                  control.state.catalogRPCCount == 0, control.state.priceRPCCount == 0,
                  control.state.historyRPCCount == (control.state.historyFeedback == nil ? 3 : 2),
                  history[0].lastSyncedLocalRevision == control.state.revisionB, history[0].syncStatus == .syncedSuccessfully,
                  control.state.history[0].displayName == Task145DomainControl.titleB,
                  history[0].remotePayloadFingerprint == HistorySessionPayloadCodec.fingerprintHash(for: control.state.history[0]),
                  control.state.requests.count == (control.state.historyFeedback == nil ? 3 : 2),
                  control.state.historyFeedback != nil || (control.state.requests[0].sealedEnvelope == control.state.requests[1].sealedEnvelope
                    && control.state.requests[0].payloads == control.state.requests[1].payloads),
                  control.state.catalogEnvelopes.isEmpty else { return false }
        }
        let events = outbox.filter { $0.domain != "local_business_attempt" && $0.status == .sent }
        let expectedEvents = priceMode ? 3 : 1
        guard events.count == expectedEvents, control.state.events.count == expectedEvents,
              control.state.eventAttempts.count == expectedEvents, control.state.eventRPCCount == expectedEvents,
              Set(events.map(\.clientEventID)) == Set(control.state.eventAttempts.map(\.clientEventID)),
              Set(events.map(\.clientEventID)) == Set(control.state.eventClientIDs.keys) else { return false }
        for event in events {
            let request = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: event)
            try domainEventReadback(request, scope: scope)
            guard control.state.eventAttempts.first(where: { $0.clientEventID == request.clientEventID })?.identity == Task145SaveBControl.eventIdentity(request) else { return false }
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        if control.state.historyFeedback != nil {
            guard !history[0].isHistorySessionDirtyForCloud else { return false }
            try captureHistoryFeedback("b-own-ack", entry: history[0], changes: changes, generation: manifest.generationID)
        }
        facts.insert(reopening ? "task145.domain.terminal-reopen-qualified" : "task145.domain.b-own-ack")
        refreshAutomaticObservation()
        return true
    }

    private func domainIntentsMatchBody(_ changes: [LocalPendingChange], product: Product,
        prices: [ProductPrice], history: [HistoryEntry]) throws -> Bool {
        for change in changes {
            switch change.entityKind {
            case .product:
                guard change.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
                      change.changedFields == ["retailprice"] else { return false }
            case .productPrice:
                guard prices.contains(where: { LocalPendingChangeLogicalKey.productPriceFingerprintHash($0) == change.intendedFingerprintHash }) else { return false }
            case .historySession:
                guard history.count == 1, change.changedFields == ["title"],
                      change.intendedFingerprintHash == HistorySessionPayloadCodec.fingerprintHash(for: HistorySessionPayloadSnapshotFactory.snapshot(for: history[0], ensureRemoteID: false)) else { return false }
            default: return false
            }
        }
        return true
    }

    private func seedIsolation() throws {
        guard let control = isolationControl, !control.reopening, let manifest = controller.activeManifest,
              AccountBindingStore().pendingRecoveryJournal == nil,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let identity = manifest.storeIdentity
        control.state.generationID = manifest.generationID
        control.state.initialLastVerified = stateStore.state.lastVerifiedAt
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: controller.modelContainer, ownerUserID: owner) { context in
            guard try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0,
                  try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()) == 0 else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            if control.state.scenario == .malformedHead {
                let baselineID = UUID(uuidString: "14400000-0000-4000-8000-000000000003")!
                for index in 0..<2 {
                    let client = UUID().uuidString.lowercased()
                    let request = SyncEventRecordRequest(domain: "catalog", eventType: "catalog_changed", changedCount: 1,
                        entityIDs: .object(["product_ids": .array([.string(baselineID.uuidString.lowercased())])]),
                        metadata: .object(["source": .string("ios")]), shopID: shop, source: "ios",
                        sourceDeviceID: try DeviceInstallIDStore().requireDeviceInstallID(), batchID: UUID(), clientEventID: client)
                    let payload = try SyncEventOutboxPayloadCodec.makePayloadJSON(for: request)
                    let time = Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
                    let row = SyncEventOutboxEntry(ownerUserID: owner.uuidString.lowercased(), storeId: identity.storeId,
                        localStoreId: identity.localStoreId, syncProtocolVersion: identity.syncProtocolVersion,
                        schemaVersion: identity.schemaVersion, storeEpoch: identity.storeEpoch, clientEventID: client,
                        batchID: request.batchID?.uuidString.lowercased(), domain: "catalog", eventType: "catalog_changed",
                        changedCount: 1, entityIDsShape: "product_ids:count=1", metadataShape: "source=ios",
                        entityIDsPayloadJSON: index == 0 ? "{not-json" : payload.entityIDsPayloadJSON,
                        metadataPayloadJSON: payload.metadataPayloadJSON, status: .pending, nextRetryAt: time,
                        createdAt: time, updatedAt: time, sourceDeviceID: request.sourceDeviceID)
                    context.insert(row); control.state.seededOutbox.append(.init(row))
                }
            } else {
                // Persisted legacy-invalid fixture, never a claim of an accepted UI Save.
                let supplier = Supplier(name: Task145IsolationControl.invalidName)
                let dependent = Product(barcode: Task145IsolationControl.dependentBarcode, productName: "Dependent T11 intent", supplier: supplier)
                let independent = Product(barcode: Task145IsolationControl.independentBarcode, productName: "Independent T11 intent")
                context.insert(supplier); context.insert(dependent); context.insert(independent)
                let graph: [(LocalPendingChangeEntityKind, String, [String], String)] = [
                    (.supplier, LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: supplier.name), ["name"], LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)),
                    (.product, LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: dependent.barcode), ["barcode", "productName", "supplier"], LocalPendingChangeLogicalKey.productFingerprintHash(dependent)),
                    (.product, LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: independent.barcode), ["barcode", "productName"], LocalPendingChangeLogicalKey.productFingerprintHash(independent))
                ]
                for (index, row) in graph.enumerated() {
                    let time = Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
                    let change = LocalPendingChange(ownerUserID: owner, ownerHash: AccountBindingStore.accountHash(for: owner),
                        storeId: identity.storeId, localStoreId: identity.localStoreId, syncProtocolVersion: identity.syncProtocolVersion,
                        schemaVersion: identity.schemaVersion, storeEpoch: identity.storeEpoch, entityKind: row.0, operation: .create,
                        status: .pending, origin: .manualCatalogSave, logicalKey: row.1, changedFields: row.2,
                        intendedFingerprintHash: row.3, createdAt: time, updatedAt: time)
                    context.insert(change); control.state.tokens.append(.init(change))
                }
                if control.state.scenario == .corruptSeal {
                    let id = control.state.tokens[0].changeID; let now = Date()
                    let seal = SyncEventOutboxEntry(id: id, ownerUserID: owner.uuidString.lowercased(), storeId: identity.storeId,
                        localStoreId: identity.localStoreId, clientEventID: id, batchID: id,
                        domain: LocalPendingBusinessAttemptStore.domain, eventType: "catalog", changedCount: 1,
                        entityIDsShape: "corrupt-T11-hash", metadataShape: "sealed_business_attempt_v1",
                        metadataPayloadJSON: "corrupt-T11-seal", status: .localOnly, nextRetryAt: now,
                        createdAt: now, updatedAt: now, sourceDeviceID: try DeviceInstallIDStore().requireDeviceInstallID())
                    context.insert(seal); control.state.seededOutbox.append(.init(seal))
                }
            }
            try context.save()
        }
        try control.persist()
        // Fresh context qualifies real stored rows, typed rejection and ordering before root.
        let read = ModelContext(controller.modelContainer)
        if control.state.scenario == .malformedHead {
            let rows = try read.fetch(FetchDescriptor<SyncEventOutboxEntry>(sortBy: [SortDescriptor(\.createdAt)]))
            guard rows.map({ Task145IsolationControl.OutboxIdentity($0) }) == control.state.seededOutbox else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            var rejected = false
            do { _ = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: rows[0]) }
            catch SyncEventOutboxPayloadError.invalidPayloadJSON(.entityIDs) { rejected = true }
            guard rejected else { throw SyncStoreGenerationError.activationReadBackFailed }
            _ = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: rows[1])
        } else {
            let changes = try read.fetch(FetchDescriptor<LocalPendingChange>())
            let suppliers = try read.fetch(FetchDescriptor<Supplier>())
            let products = try read.fetch(FetchDescriptor<Product>())
            guard changes.count == 3, suppliers.count == 1,
                  control.state.tokens.allSatisfy({ token in changes.contains { token.matches($0) } }),
                  products.first(where: { $0.barcode == Task145IsolationControl.dependentBarcode })?.supplier === suppliers[0] else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            var typed: CatalogTextValidationError?
            do { _ = try CatalogTextPolicy.validate(suppliers[0].name, for: .supplierName) }
            catch let error as CatalogTextValidationError { typed = error }
            guard typed == CatalogTextValidationError(field: .supplierName, reason: .tooLong) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        facts.insert("task145.isolation.seed-qualified")
    }

    private func isolationEventMatchesOutbox(_ request: SyncEventRecordRequest) throws -> Bool {
        let read = ModelContext(controller.modelContainer)
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(); descriptor.fetchLimit = 33
        let rows = try read.fetch(descriptor)
        guard rows.count <= 32, let row = rows.first(where: { $0.clientEventID == request.clientEventID }),
              row.ownerUserID == owner.uuidString.lowercased(), row.storeId == controller.activeManifest?.storeIdentity.storeId,
              row.localStoreId == controller.activeManifest?.storeIdentity.localStoreId else { return false }
        return try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: row) == request
    }

    private func startIsolationObservation() {
        Task { [weak self] in
            guard let self, let control = isolationControl else { return }
            do {
                var stableReopenSamples = 0
                for _ in 0..<1800 {
                    guard !control.state.failed, !control.state.overflow else { throw SyncStoreGenerationError.activationReadBackFailed }
                    var observed = try isolationReadback()
                    if observed && control.reopening { observed = try control.hasCurrentReopenOutcome() }
                    if observed {
                        facts.insert("task145.isolation.observed")
                        if control.reopening {
                            control.localSnapshot["runtimePID"] = String(ProcessInfo.processInfo.processIdentifier)
                            stableReopenSamples += 1
                            if stableReopenSamples >= 10 { facts.insert("task145.isolation.reopen-observed") }
                        }
                    } else {
                        stableReopenSamples = 0
                        if facts.contains("task145.isolation.observed") { throw SyncStoreGenerationError.activationReadBackFailed }
                    }
                    refreshAutomaticObservation()
                    try await Task.sleep(for: .milliseconds(100))
                }
                // A test that outlives the bounded observer cannot reuse a stale PASS marker.
                throw URLError(.timedOut)
            } catch {
                control.state.failed = true; try? control.persist()
                facts.remove("task145.isolation.observed"); facts.remove("task145.isolation.reopen-observed")
                refreshAutomaticObservation(); recordSetupFailure(error, stage: .automaticTerminal)
            }
        }
    }

    private func isolationReadback(reopening: Bool = false) throws -> Bool {
        guard let control = isolationControl, !control.state.failed, !control.state.overflow,
              let manifest = controller.activeManifest, manifest.generationID == control.state.generationID,
              AccountBindingStore().pendingRecoveryJournal == nil,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else { return false }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
        guard scope.storeIdentity == manifest.storeIdentity, scope.shopID == shop else { return false }
        let read = ModelContext(controller.modelContainer)
        var pd = FetchDescriptor<Product>(); pd.fetchLimit = 5
        var sd = FetchDescriptor<Supplier>(); sd.fetchLimit = 3
        var cd = FetchDescriptor<LocalPendingChange>(); cd.fetchLimit = 9
        var od = FetchDescriptor<SyncEventOutboxEntry>(); od.fetchLimit = 9
        let products = try read.fetch(pd), suppliers = try read.fetch(sd), changes = try read.fetch(cd), outbox = try read.fetch(od)
        guard products.count < 5, suppliers.count < 3, changes.count < 9, outbox.count < 9,
              outbox.allSatisfy({ $0.ownerUserID == owner.uuidString.lowercased()
                && $0.storeId == scope.storeIdentity.storeId && $0.localStoreId == scope.storeIdentity.localStoreId }),
              changes.allSatisfy({ LocalPendingChangeScopeMatcher.matches($0, ownerUserID: owner,
                accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) }),
              products.contains(where: { $0.barcode == "LOCAL-ROOT" && $0.productName == "Safe local baseline" }) else { return false }
        let business = control.state.rpc.filter { !$0.kind.hasPrefix("read:") }
        let pendingCount = try OptionsPendingAttentionCounter.countAll(context: read)
        let eventRows = outbox.filter { $0.domain == "catalog" }
        if control.state.scenario == .malformedHead {
            guard products.count == 1, suppliers.isEmpty, changes.isEmpty, eventRows.count == 2,
                  control.state.seededOutbox.count == 2 else { return false }
            for original in control.state.seededOutbox {
                guard let row = eventRows.first(where: { $0.id == original.id }), Task145IsolationControl.OutboxIdentity(row) == original else { return false }
            }
            guard let head = eventRows.first(where: { $0.id == control.state.seededOutbox[0].id }),
                  let sibling = eventRows.first(where: { $0.id == control.state.seededOutbox[1].id }),
                  head.status == .blockedContract, head.lastErrorKind == .contract,
                  head.lastErrorCode == "payload_replay_invalid_entity_ids", head.entityIDsPayloadJSON == "{not-json",
                  sibling.status == .sent, business.count == 1, business[0].kind == "recordEvent",
                  control.state.events.count == 1, control.state.eventClients.keys.sorted() == [sibling.clientEventID],
                  business[0].identity == Task145SaveBControl.eventIdentity(try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: sibling)),
                  pendingCount == 1, control.state.activities.contains(where: { $0.registered == 1 && $0.blocked == 1 && $0.waiting == 0 && $0.status == "partialRetryable" }) else { return false }
            control.localSnapshot = ["pending": "1", "head": head.statusRaw, "headError": head.lastErrorCode ?? "", "sibling": sibling.statusRaw]
        } else {
            guard products.count == 3, suppliers.count == 1, changes.count == 3, control.state.tokens.count == 3,
                  suppliers[0].name == Task145IsolationControl.invalidName, suppliers[0].remoteID == nil,
                  let dependent = products.first(where: { $0.barcode == Task145IsolationControl.dependentBarcode }),
                  let independent = products.first(where: { $0.barcode == Task145IsolationControl.independentBarcode }),
                  dependent.productName == "Dependent T11 intent", dependent.supplier === suppliers[0], dependent.remoteID == nil,
                  independent.productName == "Independent T11 intent", independent.supplier == nil,
                  independent.category == nil, independent.itemNumber == nil, independent.secondProductName == nil,
                  independent.purchasePrice == nil, independent.retailPrice == nil, independent.stockQuantity == nil,
                  control.state.tokens[0].intendedFingerprintHash == LocalPendingChangeLogicalKey.supplierFingerprintHash(suppliers[0]),
                  control.state.tokens[1].intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(dependent) else { return false }
            for token in control.state.tokens.prefix(2) {
                guard let row = changes.first(where: { $0.changeID == token.changeID }), token.matches(row), row.status == .pending else { return false }
            }
            let q = control.state.tokens[2]
            guard let qRow = changes.first(where: { $0.changeID == q.changeID }), qRow.idempotencyKey == q.idempotencyKey,
                  qRow.ownerHash == q.ownerHash, qRow.storeId == q.storeId, qRow.localStoreId == q.localStoreId, qRow.storeEpoch == q.storeEpoch else { return false }
            if control.state.scenario == .corruptSeal {
                guard q.matches(qRow), qRow.status == .pending, independent.remoteID == nil, business.isEmpty,
                      eventRows.isEmpty, control.state.remoteProduct == nil, control.state.events.isEmpty,
                      control.state.activities.isEmpty, control.state.seededOutbox.count == 1,
                      let seal = outbox.first(where: { $0.id == control.state.seededOutbox[0].id }),
                      Task145IsolationControl.OutboxIdentity(seal) == control.state.seededOutbox[0], seal.status == .localOnly,
                      control.state.catalogs.contains(where: { $0.error == "activationReadBackFailed" }),
                      control.state.runs.contains(where: { $0.stable && $0.category == "integrity" && !$0.didWork && !$0.convergence && !$0.finalization && !$0.continuation }),
                      pendingCount == 3 else { return false }
            } else {
                let blockers = ["invalidCatalogText:\(control.state.tokens[0].changeID):supplierName:too_long",
                    "unresolvedCatalogReference:\(control.state.tokens[1].changeID):supplier"].sorted()
                guard qRow.status == .acknowledged, independent.remoteID != nil, independent.remoteID == control.state.remoteProduct?.id,
                      qRow.entityRemoteID == independent.remoteID,
                      business.map(\.kind) == ["createProducts", "recordEvent"], control.state.events.count == 1,
                      eventRows.count == 1, eventRows[0].status == .sent,
                      business[1].identity == Task145SaveBControl.eventIdentity(try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: eventRows[0])),
                      control.state.catalogs.contains(where: { $0.blockers == blockers && $0.creates == 1 && $0.total == 1 && $0.error == nil }),
                      control.state.catalogs.allSatisfy({ $0.error == nil && $0.blockers == blockers && $0.creates <= 1 }),
                      control.state.runs.contains(where: { $0.error == "catalog_local_changes_blocked" && $0.stable && $0.category == "payload" && $0.didWork && !$0.convergence && !$0.continuation && !$0.finalization }),
                      pendingCount == 2 else { return false }
            }
            guard stateStore.state.lastVerifiedAt == control.state.initialLastVerified else { return false }
            control.localSnapshot = ["pending": String(pendingCount), "supplier": "preserved-pending", "dependent": "preserved-pending", "independent": qRow.statusRaw]
        }
        control.localSnapshot["qualified"] = "true"
        control.localSnapshot["generation"] = manifest.generationID.uuidString
        control.localSnapshot["pid"] = String(ProcessInfo.processInfo.processIdentifier)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        control.localSnapshot["actualTokens"] = try encoder.encode(changes.map { LocalPendingChangeCASToken($0) }.sorted { $0.changeID < $1.changeID }).base64EncodedString()
        control.localSnapshot["actualOutboxIdentities"] = try encoder.encode(outbox.map { Task145IsolationControl.OutboxIdentity($0) }.sorted { $0.id < $1.id }).base64EncodedString()
        control.localSnapshot["actualOutboxStatuses"] = try encoder.encode(outbox.map { [$0.id: $0.statusRaw] }).base64EncodedString()
        control.localSnapshot["actualProductFingerprints"] = try encoder.encode(products.map { [$0.barcode: LocalPendingChangeLogicalKey.productFingerprintHash($0)] }).base64EncodedString()
        control.localSnapshot["actualSupplierFingerprints"] = try encoder.encode(suppliers.map { LocalPendingChangeLogicalKey.supplierFingerprintHash($0) }).base64EncodedString()
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        if reopening {
            guard control.reopening, control.state.seedPID != ProcessInfo.processInfo.processIdentifier else { return false }
            try control.qualifyReopen(generationID: manifest.generationID)
            facts.insert("task145.isolation.reopen-qualified")
        }
        return true
    }

    private func interruptionPrepareRoot() throws {
        guard let control = interruptionControl, let manifest = controller.activeManifest,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, allowsPendingSameScopeRecovery: true)
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        guard try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0,
              try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()) == 0,
              try context.fetchCount(FetchDescriptor<ProductPrice>()) == 0,
              try context.fetchCount(FetchDescriptor<HistoryEntry>()) == 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if control.isSeed {
            guard products.count == 1, products[0].remoteID == control.state.products[0].id,
                  products[0].productName == "Safe local baseline", AccountBindingStore().pendingRecoveryJournal == nil,
                  control.state.oldGenerationID == nil else { throw SyncStoreGenerationError.activationReadBackFailed }
            control.state.oldGenerationID = manifest.generationID
            try control.persist()
            try Task145InterruptionFiles.write(Task145InterruptionControl.Result(phase: "seed", passed: true,
                runID: namespace, scenario: control.state.scenario, pid: ProcessInfo.processInfo.processIdentifier,
                generationID: manifest.generationID, products: products.compactMap(\.remoteID), qualified: true,
                journalPhase: nil, state: control.state), to: control.root.appendingPathComponent("seed-result.json"))
            facts.insert("task145.interruption.seed-ready")
        } else if control.isCrash {
            guard manifest.generationID == control.state.oldGenerationID, products.count == 1,
                  products[0].productName == "Safe local baseline", products[0].remoteID == control.state.products[0].id,
                  AccountBindingStore().pendingRecoveryJournal == nil else { throw SyncStoreGenerationError.activationReadBackFailed }
            // A deliberate same-scope recovery request is established before
            // mounting root. Only normal bootstrap/coordinator invokes Atomic.
            guard AccountBindingStore().beginSameScopeRecovery(accountHash: scope.accountHash,
                storeIdentity: scope.storeIdentity, reason: "TASK145_INTERRUPTION_F",
                deviceIdentityHash: scope.deviceIdentityHash) else { throw SyncStoreGenerationError.activationReadBackFailed }
            stateStore.reconcilePendingRecoveryJournal()
            transport.release()
        } else {
            let marker = try Task145InterruptionFiles.decode(Task145InterruptionBoundary.Marker.self,
                control.root.appendingPathComponent("boundary-marker.json"))
            let generation = control.root.appendingPathComponent("generation-root/generations")
                .appendingPathComponent(marker.candidateGenerationID.uuidString.lowercased())
            let expectedCount = marker.boundary == "staging" || marker.boundary == "before" ? 1 : 2
            guard marker.runID == namespace, marker.scenario == control.state.scenario,
                  marker.pid != ProcessInfo.processInfo.processIdentifier,
                  marker.pid == control.state.crashPID, manifest == marker.manifest,
                  marker.candidateGenerationID == control.state.candidateGenerationID,
                  marker.oldGenerationID == control.state.oldGenerationID,
                  products.count == expectedCount,
                  Set(products.compactMap(\.remoteID)) == Set(control.state.products.prefix(expectedCount).map(\.id)),
                  products.allSatisfy({ local in control.state.products.contains { $0.id == local.remoteID
                      && $0.productName == local.productName && $0.barcode == local.barcode } }),
                  let journal = AccountBindingStore().pendingRecoveryJournal,
                  journal.mode == .sameScopeRecovery, journal.generationID == marker.candidateGenerationID,
                  journal.replacement.accountHash == scope.accountHash, journal.replacement.storeIdentity == scope.storeIdentity,
                  journal.deviceIdentityHash == scope.deviceIdentityHash,
                  try Task145InterruptionFiles.read(control.root.appendingPathComponent("generation-root/recovery-journal.json")) == marker.journal,
                  try Task145InterruptionFiles.read(generation.appendingPathComponent("recovery-page-progress-v1.json")) == marker.progress,
                  try Task145InterruptionFiles.read(generation.appendingPathComponent("recovery-ledger-v1/products.ndjson")) == marker.productLedger,
                  !control.state.entryOverflow, !control.state.observationFailed else { throw SyncStoreGenerationError.activationReadBackFailed }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            guard try encoder.encode(control.state) == encoder.encode(marker.state) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
            try Task145InterruptionFiles.write(Task145InterruptionControl.Result(phase: "qualified-reopen", passed: true,
                runID: namespace, scenario: control.state.scenario, pid: ProcessInfo.processInfo.processIdentifier,
                generationID: manifest.generationID, products: products.compactMap(\.remoteID), qualified: true,
                journalPhase: journal.phase.rawValue, state: control.state), to: control.root.appendingPathComponent("reopen-result.json"))
            facts.insert("task145.interruption.pending-reopen-qualified")
            stateStore.reconcilePendingRecoveryJournal()
            transport.release()
            startInterruptionObservation()
        }
        hasStarted = true
        isPreparedForRoot = true
        refreshAutomaticObservation()
    }

    private func interruptionProgress(_ event: SyncRecoveryProgressEvent) throws {
        guard let control = interruptionControl, !control.isSeed,
              event.scope.ownerUserID == owner, event.scope.shopID == shop,
              let journal = AccountBindingStore().pendingRecoveryJournal,
              journal.replacement.accountHash == event.scope.accountHash,
              journal.replacement.storeIdentity == event.scope.storeIdentity,
              journal.deviceIdentityHash == event.scope.deviceIdentityHash else { return }
        if journal.generationID != nil { try control.prepareCandidateFromJournal(journal) }
        if control.isCrash, control.state.scenario == .finalizing, event.progress.stage == .finalizing {
            control.boundary.block("finalizing")
        }
    }

    private func startInterruptionObservation() {
        guard interruptionControl?.mode == .verify else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for _ in 0..<1200 {
                    if try interruptionTerminalReadback() { return }
                    refreshAutomaticObservation()
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw URLError(.timedOut)
            } catch { recordSetupFailure(error, stage: .automaticTerminal) }
        }
    }

    private func interruptionTerminalReadback() throws -> Bool {
        guard let control = interruptionControl, control.mode == .verify,
              let summary = completedAutomaticRecoverySummary,
              let manifest = controller.activeManifest,
              manifest.generationID == control.state.candidateGenerationID,
              manifest.generationID != control.state.oldGenerationID,
              summary.completedRecoveryJournal, summary.activatedGenerationID == manifest.generationID,
              summary.watermarkAfter == 42, summary.verifiedFinalization?.generationID == manifest.generationID,
              AccountBindingStore().pendingRecoveryJournal == nil,
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer), !control.state.entryOverflow, !control.state.observationFailed else { return false }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
        guard try controller.isActiveRecoveryFinalized(scope: scope) else { return false }
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        guard products.count == 2, Set(products.compactMap(\.remoteID)) == Set(control.state.products.map(\.id)),
              products.allSatisfy({ local in control.state.products.contains { $0.id == local.remoteID && $0.productName == local.productName
                  && $0.barcode == local.barcode && $0.itemNumber == local.itemNumber } }),
              try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0,
              try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()) == 0,
              try context.fetchCount(FetchDescriptor<ProductPrice>()) == 0,
              try context.fetchCount(FetchDescriptor<HistoryEntry>()) == 0 else { return false }
        let crashPages = control.state.entries.filter { $0.mode == .crash && $0.kind == "page:products" }
        let replayPages = control.state.entries.filter { $0.mode == .verify && $0.kind == "page:products" }
        guard crashPages.count == 2, crashPages[0].afterID == nil,
              crashPages[1].afterID == control.state.products[0].id.uuidString.lowercased(),
              !control.state.entries.contains(where: { $0.kind == "business:catalog" || $0.kind == "business:event" }),
              replayPages.count == (control.state.scenario == .staging ? 1 : 0),
              replayPages.allSatisfy({ $0.afterID == control.state.products[0].id.uuidString.lowercased() }) else { return false }
        // Every pre-crash accepted page remains represented exactly once. A
        // fresh generation or first-page redownload cannot satisfy these gates.
        let progressURL = control.root.appendingPathComponent("generation-root/generations")
            .appendingPathComponent(manifest.generationID.uuidString.lowercased())
            .appendingPathComponent("recovery-page-progress-v1.json")
        let progress = try JSONSerialization.jsonObject(with: Task145InterruptionFiles.read(progressURL)) as? [String: Any]
        let domains = progress?["domains"] as? [String: Any]
        let cursor = domains?["products"] as? [String: Any]
        guard cursor?["processed"] as? Int == 2, cursor?["pages"] as? Int == 2,
              cursor?["complete"] as? Bool == true else { return false }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        try Task145InterruptionFiles.write(Task145InterruptionControl.Result(phase: "verify", passed: true,
            runID: namespace, scenario: control.state.scenario, pid: ProcessInfo.processInfo.processIdentifier,
            generationID: manifest.generationID, products: products.compactMap(\.remoteID), qualified: true,
            journalPhase: nil, state: control.state), to: control.root.appendingPathComponent("verify-result.json"))
        facts.insert("task145.interruption.verified")
        refreshAutomaticObservation()
        return true
    }

    private func terminalReadback(observesReopenFailure: Bool = false) throws -> Bool {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        let prices = try context.fetchCount(FetchDescriptor<ProductPrice>())
        let history = try context.fetchCount(FetchDescriptor<HistoryEntry>())
        let checks: [(String, Bool)] = [
            ("product-unique", products.count == 1),
            ("product-name", products.count == 1 && products[0].productName == "Saved before network release"),
            ("intent-unique", pending.count == 1),
            ("intent-acknowledged", pending.allSatisfy { $0.status == .acknowledged }),
            ("sent-unique", outbox.filter { $0.status == .sent }.count == 1),
            ("outbox-allowed", outbox.allSatisfy { $0.status == .localOnly || $0.status == .sent }),
            ("price-empty", prices == 0),
            ("history-empty", history == 0)
        ]
        let valid = checks.allSatisfy { $0.1 }
        if observesReopenFailure && !valid {
            for (name, passed) in checks {
                facts.insert("task144.controlled.terminal-\(name).\(passed)")
            }
        }
        return valid
    }
}

private nonisolated struct Task144ObservedAtomicRecoveryProvider: SyncRecoverySnapshotPullProviding {
    let base: AtomicGenerationRecoverySnapshotPullService
    let observe: @MainActor @Sendable (UUID, SyncRecoverySnapshotPullSummary) -> Void
    nonisolated var publicationMode: SyncRecoverySnapshotPublicationMode { base.publicationMode }

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        let summary = try await base.recoverFromRemoteSnapshot(ownerUserID: ownerUserID)
        observe(ownerUserID, summary)
        return summary
    }
}

@MainActor
private final class Task144ObservedAutomaticRuntime: SyncAutomaticRuntimeProviding {
    private let runtime: any SyncAutomaticRuntimeProviding
    private let observe: (SyncAction, SyncAutomaticRunResult) -> Void
    private let invocation: ((UUID, Bool) -> Void)?
// TASK145_T19_INSERT_BEGIN wrapper-properties
    var t19Begin: ((SyncAction, SyncAutomaticTriggerSource) -> Void)?
    var t19Observe: ((SyncAction, SyncAutomaticTriggerSource, SyncAutomaticRunResult) -> Void)?

// TASK145_T19_INSERT_END wrapper-properties

    init(runtime: any SyncAutomaticRuntimeProviding, invocation: ((UUID, Bool) -> Void)? = nil,
         observe: @escaping (SyncAction, SyncAutomaticRunResult) -> Void) {
        self.runtime = runtime
        self.observe = observe
        self.invocation = invocation
    }
    var isRunning: Bool { runtime.isRunning }
    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        if let invocation {
            let callID = UUID(); invocation(callID, true)
            defer { invocation(callID, false) }
            return await Task145PerformanceCallContext.$invocationID.withValue(callID) {
                let result = await runtime.run(action: action, source: source)
                observe(action, result); return result
            }
        }
// TASK145_T19_INSERT_BEGIN wrapper-before
        t19Begin?(action, source)
// TASK145_T19_INSERT_END wrapper-before
        let result = await runtime.run(action: action, source: source)
        observe(action, result)
// TASK145_T19_INSERT_BEGIN wrapper-after
        t19Observe?(action, source, result)
// TASK145_T19_INSERT_END wrapper-after
        return result
    }
    func cancel() { runtime.cancel() }
    func cancelAndWait() async { await runtime.cancelAndWait() }
    func resumeAfterStoreReplacement() async { await runtime.resumeAfterStoreReplacement() }
}

struct Task144ControlledRootAdmission<Content: View>: View {
    @ObservedObject var fixture: Task144LocalAvailabilityRootFixture
    @ViewBuilder let content: () -> Content

    var body: some View {
        if fixture.isPreparedForRoot {
            content()
        } else {
            ProgressView("Preparing controlled local baseline")
                .accessibilityValue(fixture.facts.sorted().joined(separator: ";"))
        }
    }
}

// The exact production History consumer with its existing concrete dependency.
// This DEBUG host does not qualify the normal App/ContentView dependency wiring.
private struct Task145HistoryFeedbackHost: View {
    @ObservedObject var fixture: Task144LocalAvailabilityRootFixture
    let service: HistorySessionSyncService
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            HistoryView(historySessionSyncService: service)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close feedback History") { dismiss() }
                            .accessibilityIdentifier("task145.history-feedback.close")
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button("Return ACK A") { fixture.releaseHistoryFeedbackA() }
                            .accessibilityIdentifier("task145.history-feedback.return-a")
                        Button("Release B") { fixture.releaseHistoryFeedbackB() }
                            .accessibilityIdentifier("task145.history-feedback.release-b")
                    }.buttonStyle(.bordered).padding(4)
                }
        }
        .environmentObject(fixture.authViewModel)
        .environmentObject(fixture.controller)
        .modelContainer(fixture.controller.modelContainer)
    }
}

private struct Task144ControlledRootControls: View {
    @ObservedObject var fixture: Task144LocalAvailabilityRootFixture
    let controlPrefix: String
    @State private var showsHistoryFeedback = false
    var body: some View {
        VStack(spacing: 1) {
// TASK145_SCOPE_SWITCH_INSERT_BEGIN C-observation-controls
            if fixture.hasScopeSwitchControl {
                Task145ScopeSwitchControls(fixture: fixture, prefix: controlPrefix)
            }
// TASK145_SCOPE_SWITCH_INSERT_END C-observation-controls
            if Task145PerformanceConfiguration.enabled && !Task145PerformanceConfiguration.measures {
                Text(fixture.performanceSeedManifest).lineLimit(1).font(.system(size: 1))
                    .accessibilityIdentifier("task145.perf.dataset-json").accessibilityValue(fixture.performanceSeedManifest)
            }
            if Task145PerformanceConfiguration.measures {
                HStack {
                    Button("Export sample") { fixture.exportPerformanceSample() }.accessibilityIdentifier("task145.perf.export")
                    Button("Record first failure") { fixture.exportPerformanceSample(failed: true) }.accessibilityIdentifier("task145.perf.fail")
                    Button("Arm warm") { fixture.armPerformanceWarm() }.accessibilityIdentifier("task145.perf.arm-warm")
                }
                Task145PerformanceReadback().frame(width: 1, height: 1).allowsHitTesting(false)
                Text(fixture.performanceExport).lineLimit(1).font(.system(size: 1))
                    .accessibilityIdentifier("task145.perf.sample-json").accessibilityValue(fixture.performanceExport)
                if fixture.performanceWarmReady { Text("task145.perf.warm-ready").accessibilityIdentifier("task145.perf.warm-ready") }
            }
            ForEach(fixture.facts.sorted(), id: \.self) { fact in
                Text(fact).font(.system(size: 8)).accessibilityIdentifier(fact)
            }
            HStack {
                if ProcessInfo.processInfo.environment["TASK145_ROOT_PRESENTATION_OBSERVATION"] == "1" {
                    Text("Observe root presentation")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.observeRootPresentation() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("task145.root-presentation.observe")
                    Text("Root presentation observation")
                        .accessibilityIdentifier("task145.root-presentation.ledger")
                        .accessibilityValue(fixture.rootPresentationObservation)
                }
                if fixture.provesTransientAuthStorageFailure {
                    Text("Hold SDK storage read")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.beginAuthStorageReadFailure() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("task145.t13.storage-fault")
                    Text("Restore SDK storage read")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.restoreAuthStorageRead() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("task145.t13.storage-restore")
                    Text("Observe SDK and local scope")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.observeAuthStorageBoundary() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("task145.t13.observe")
                    Text("SDK local access observation")
                        .accessibilityIdentifier("task145.t13.ledger")
                        .accessibilityValue(fixture.authStorageObservation)
                }
                if fixture.provesSafeStoreLoadFailure {
                    Text("Observe failed store")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.observeSafeStoreFailure() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("task145.safe-store-failure.observe")
                    Text("Failed store observation")
                        .accessibilityIdentifier("task145.safe-store-failure.ledger")
                        .accessibilityValue(fixture.safeStoreFailureObservation)
                }
                if fixture.hasT10Control {
                    Text("Saved recovery ledger")
                        .accessibilityIdentifier("task145.t10a.ledger")
                        .accessibilityValue(fixture.t10Ledger)
                }
                if fixture.hasR4ReviewControl {
                    Text("Prepare controlled R4 peer")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.prepareR4Peer() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("\(controlPrefix).r4-peer")
                        .accessibilityValue(fixture.r4Ledger)
                }
                if fixture.hasR23DraftReview {
                    Text("Apply R3 peer")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.publishR23DraftPeer() }
                        .accessibilityAddTraits(.isButton).accessibilityIdentifier("task145.r3.peer")
                    Text("Read R3 state")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.observeR23DraftState() }
                        .accessibilityAddTraits(.isButton).accessibilityIdentifier("task145.r3.observe")
                    Text("Recover deleted draft")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.recoverR23DeletedDraft() }
                        .accessibilityAddTraits(.isButton).accessibilityIdentifier("task145.r3.rebind")
                    Text("R3 current state").accessibilityIdentifier("task145.r3.ledger")
                        .accessibilityValue(fixture.r23DraftLedger)
                }
                if fixture.provesR23EditorConflict {
                    Text("Apply controlled peer edit")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.publishR23EditorPeerChange() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("\(controlPrefix).peer-apply")
                    Text("Read saved values")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.observeR23EditorNoPartialSave() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("\(controlPrefix).peer-readback")
                }
                if fixture.hasHistoryFeedback {
                    Button("Open feedback History") { showsHistoryFeedback = true }
                        .accessibilityIdentifier("task145.history-feedback.open")
                }
                if fixture.provesEmptyFenceRequalification {
                    Text("Change controlled empty store fence")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.invalidateEmptyRootPhysicalFence() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("\(controlPrefix).empty-fence.invalidate")
                }
                Text("Controlled state update")
                    .padding(8).contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1) {
                        Task144ControlGestureObservation.record("perform-entry", control: controlPrefix)
                        fixture.publishCheckingUpdate()
                    } onPressingChanged: { pressing in
                        Task144ControlGestureObservation.record("pressing.\(pressing)", control: controlPrefix)
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("\(controlPrefix).state-update")
                Text("Release controlled transport")
                    .padding(8).contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1) {
                        Task144ControlGestureObservation.record("perform-entry", control: "\(controlPrefix).release")
                        fixture.release()
                        Task144ControlGestureObservation.record(
                            "returned.fact-present.\(fixture.facts.contains("task144.controlled.released"))",
                            control: "\(controlPrefix).release")
                    } onPressingChanged: { pressing in
                        Task144ControlGestureObservation.record("pressing.\(pressing)", control: "\(controlPrefix).release")
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityValue(fixture.automaticReadback + Task144RootObservation.snapshotAtRealRender())
                    .accessibilityIdentifier("\(controlPrefix).release")
            }.font(.caption2)
        }.padding(2).background(.ultraThinMaterial)
            // Observation controls must not consume the product's viewport
            // when the real root is exercised at accessibility text sizes.
            .dynamicTypeSize(.medium ... .large)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(controlPrefix).band")
            .sheet(isPresented: $showsHistoryFeedback) {
                if let service = fixture.historyFeedbackService {
                    Task145HistoryFeedbackHost(fixture: fixture, service: service)
                }
            }
    }
}
/// On-demand public UIKit observations in the isolated fixture only. This view
/// does not participate in hit testing or publish any application state.
@MainActor
private final class Task144NativeNameReadbackView: UIView {
    weak var fixture: Task144LocalAvailabilityRootFixture?
    private var sampleCount = 0
    // TASK145_T14_INSERT_BEGIN observer-context
    fileprivate var t14Context: String?
    // TASK145_T14_INSERT_END observer-context

    override var accessibilityValue: String? {
        get { nativeNameReadback() }
        set { }
    }

    private func nativeNameReadback() -> String {
        // TASK145_T14_INSERT_BEGIN existing-AX-getter
        if ProcessInfo.processInfo.environment["TASK145_T14_OBSERVATION"] == "1" {
            return t14PassiveNativeReadback()
        }
        // TASK145_T14_INSERT_END existing-AX-getter
        // TASK145_T18_INSERT_BEGIN existing-AX-getter
        if ProcessInfo.processInfo.environment["TASK145_T18_OBSERVATION"] == "1" {
            guard let fixture, window != nil else { return "{\"status\":\"MISSING_FIXTURE_OR_WINDOW\"}" }
            return fixture.t18PassiveSnapshot(traits: traitCollection)
        }
        // TASK145_T18_INSERT_END existing-AX-getter
        guard sampleCount < 256 else { return "native-name-observation=CAP256" }
        sampleCount += 1
        var result: [String: Any] = [
            "sample": sampleCount, "uptime": ProcessInfo.processInfo.systemUptime,
            "observerID": String(describing: ObjectIdentifier(self))
        ]
        guard let fixture, let window, let scene = window.windowScene else {
            result["status"] = "MISSING_FIXTURE_WINDOW_OR_SCENE"
            return encode(result)
        }
        result["windowID"] = String(describing: ObjectIdentifier(window))
        result["windowBounds"] = String(describing: window.bounds)
        result["windowIsKey"] = window.isKeyWindow
        result["presentationID"] = String(describing: fixture.controller.presentationID)
        result["modelContainerID"] = String(describing: ObjectIdentifier(fixture.controller.modelContainer))
        result["activeManifestGeneration"] = fixture.controller.activeManifest
            .map { String(describing: $0.generationID) } ?? "missing"
        var pending: [UIView] = [window]
        var fields: [UITextField] = []
        var visited = 0
        while visited < 1024, let view = pending.popLast() {
            visited += 1
            if let field = view as? UITextField,
               field.accessibilityIdentifier == "task144.product.name" {
                fields.append(field)
            }
            pending.append(contentsOf: view.subviews)
        }
        result["visitedViewCount"] = visited
        result["exactNameFieldCount"] = fields.count
        guard pending.isEmpty, fields.count == 1 else {
            result["status"] = pending.isEmpty
                ? (fields.isEmpty ? "MISSING_EXACT_NATIVE_NAME" : "AMBIGUOUS_EXACT_NATIVE_NAME")
                : "VIEW_TRAVERSAL_CAP1024"
            return encode(result)
        }
        let field = fields[0]
        result["status"] = "EXACT_NATIVE_NAME"
        result["fieldID"] = String(describing: ObjectIdentifier(field))
        result["fieldFrameInWindow"] = String(describing: field.convert(field.bounds, to: window))
        result["accessibilityFrameInScreen"] = String(describing: field.accessibilityFrame)
        let activation = field.accessibilityActivationPoint
        result["accessibilityActivationPointInScreen"] = String(describing: activation)
        result["isFirstResponder"] = field.isFirstResponder
        result["isEnabled"] = field.isEnabled
        if fixture.hasR23DraftReview {
            if let text = field.text, text.utf8.count <= 256 { result["draft"] = text }
            if let range = field.selectedTextRange {
                let start = field.offset(from: field.beginningOfDocument, to: range.start)
                let end = field.offset(from: field.beginningOfDocument, to: range.end)
                if let count = field.text?.utf16.count, start >= 0, end >= start, end <= count {
                    result["selectionStatus"] = "EXACT_UTF16"
                    result["selectionStart"] = start; result["selectionEnd"] = end
                }
            }
        }
        result["isHidden"] = field.isHidden
        result["alpha"] = Double(field.alpha)
        result["isUserInteractionEnabled"] = field.isUserInteractionEnabled
        if activation.x.isFinite, activation.y.isFinite {
            let point = window.convert(activation, from: scene.screen.coordinateSpace)
            let hit = window.hitTest(point, with: nil)
            result["activationPointInWindow"] = String(describing: point)
            result["hitTargetExists"] = hit != nil
            result["hitTargetIsFieldOrDescendant"] = hit === field
                || hit?.isDescendant(of: field) == true
        } else { result["hitTestStatus"] = "NOT_REQUESTED_NONFINITE_ACTIVATION_POINT" }
        var ancestors: [[String: Any]] = []
        var ancestor = field.superview
        while let view = ancestor, ancestors.count < 16 {
            ancestors.append([
                "id": String(describing: ObjectIdentifier(view)),
                "frameInWindow": String(describing: view.convert(view.bounds, to: window)),
                "clipsToBounds": view.clipsToBounds, "isHidden": view.isHidden,
                "alpha": Double(view.alpha), "isUserInteractionEnabled": view.isUserInteractionEnabled
            ])
            ancestor = view.superview
        }
        result["ancestors"] = ancestors
        result["ancestorLimitReached"] = ancestor != nil
        return encode(result)
    }

// TASK145_T14_INSERT_BEGIN passive-native-getter
    /// Reads native getters only. IDs diagnose provenance; they are not cross-cutover equality oracles.
    private func t14PassiveNativeReadback() -> String {
        guard sampleCount < 256 else { return "native-name-observation=CAP256" }
        sampleCount += 1
        var result: [String: Any] = ["sample": sampleCount,
            "uptime": ProcessInfo.processInfo.systemUptime, "utc": Date().timeIntervalSince1970,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "observerID": String(describing: ObjectIdentifier(self))]
        result["context"] = t14Context ?? "UNKNOWN_MISSING_CONTEXT"
        guard t14Context == "root" || t14Context == "editor" else {
            result["status"] = "UNKNOWN_OBSERVER_CONTEXT"
            return encode(result)
        }
        guard let fixture else {
            result["status"] = "UNKNOWN_MISSING_FIXTURE"
            return encode(result)
        }
        let runtime = fixture.t14PassiveCurrentRuntimeValues()
        result["runtime"] = runtime
        result["namespace"] = runtime["namespace"]
        guard let window, window.windowScene != nil else {
            result["status"] = "UNKNOWN_MISSING_WINDOW_OR_SCENE"
            return encode(result)
        }
        result["windowID"] = String(describing: ObjectIdentifier(window))
        result["windowIsKey"] = window.isKeyWindow
        result["presentationID"] = fixture.controller.presentationID
        result["modelContainerID"] = String(describing: ObjectIdentifier(fixture.controller.modelContainer))
        result["activeManifestGeneration"] = fixture.controller.activeManifest
            .map { $0.generationID.uuidString.lowercased() } ?? "missing"
        guard let windowBounds = t14Rect(window.bounds) else {
            result["status"] = "UNKNOWN_WINDOW_GEOMETRY"
            return encode(result)
        }
        result["windowBounds"] = windowBounds
        var pending: [UIView] = [window]
        var fields: [UITextField] = []
        var visited = 0
        while visited < 1024, let view = pending.popLast() {
            visited += 1
            if let field = view as? UITextField,
               field.accessibilityIdentifier == "task144.product.name" { fields.append(field) }
            pending.append(contentsOf: view.subviews)
        }
        result["visitedViewCount"] = visited
        result["exactNameFieldCount"] = fields.count
        guard pending.isEmpty else {
            result["status"] = "UNKNOWN_VIEW_TRAVERSAL_CAP1024"
            return encode(result)
        }
        guard fields.count == 1 else {
            result["status"] = fields.isEmpty ? "SHELL_NO_NAME" : "UNKNOWN_AMBIGUOUS_NATIVE_NAME"
            return encode(result)
        }
        let field = fields[0]
        result["status"] = "EXACT_NATIVE_NAME"
        result["fieldID"] = String(describing: ObjectIdentifier(field))
        result["isFirstResponder"] = field.isFirstResponder
        result["isHidden"] = field.isHidden
        result["isEnabled"] = field.isEnabled
        if let draft = field.text, draft.utf8.count <= 256 { result["draft"] = draft }
        else { result["draftStatus"] = "UNKNOWN_MISSING_OR_LIMIT" }
        if let selected = field.selectedTextRange {
            let start = field.offset(from: field.beginningOfDocument, to: selected.start)
            let end = field.offset(from: field.beginningOfDocument, to: selected.end)
            let length = field.text?.utf16.count
            if let length, start >= 0, end >= start, end <= length {
                result["selectionStatus"] = "EXACT_UTF16"
                result["selectionStart"] = start
                result["selectionEnd"] = end
            } else { result["selectionStatus"] = "UNKNOWN_INVALID_UTF16_RANGE" }
        } else { result["selectionStatus"] = "UNKNOWN_NO_SELECTED_TEXT_RANGE" }
        let frame = field.convert(field.bounds, to: window)
        guard let fieldFrame = t14Rect(frame) else {
            result["geometryStatus"] = "UNKNOWN_FIELD_GEOMETRY"
            result["scroll"] = ["status": "UNKNOWN_FIELD_GEOMETRY"]
            return encode(result)
        }
        result["fieldFrameInWindow"] = fieldFrame
        var ancestors: [UIView] = []
        var ancestor = field.superview
        var reachedWindow = false
        while let view = ancestor, ancestors.count < 16 {
            ancestors.append(view)
            if view === window { reachedWindow = true; break }
            ancestor = view.superview
        }
        result["ancestorCount"] = ancestors.count
        result["ancestorLimitReached"] = !reachedWindow
        guard reachedWindow else {
            result["geometryStatus"] = "UNKNOWN_ANCESTOR_LIMIT_OR_WINDOW"
            result["scroll"] = ["status": "UNKNOWN_ANCESTOR_LIMIT_OR_WINDOW"]
            return encode(result)
        }
        var visible = frame.intersection(window.bounds)
        var validAncestors = !field.isHidden && field.alpha.isFinite && field.alpha > 0
        for view in ancestors {
            let ancestorFrame = view.convert(view.bounds, to: window)
            guard t14Rect(ancestorFrame) != nil, view.alpha.isFinite, !view.isHidden, view.alpha > 0 else {
                validAncestors = false
                break
            }
            if view.clipsToBounds { visible = visible.intersection(ancestorFrame) }
        }
        guard validAncestors, !visible.isNull, !visible.isEmpty, visible.contains(frame) else {
            result["geometryStatus"] = "UNKNOWN_HIDDEN_OR_CLIPPED_FIELD"
            result["scroll"] = ["status": "UNKNOWN_HIDDEN_OR_CLIPPED_FIELD"]
            return encode(result)
        }
        result["geometryStatus"] = "EXACT_UNCLIPPED_FIELD"
        guard let scroll = ancestors.compactMap({ $0 as? UIScrollView }).first else {
            result["scroll"] = ["status": "UNKNOWN_NO_SCROLL_ANCESTOR"]
            return encode(result)
        }
        let offset = scroll.contentOffset, size = scroll.contentSize
        let bounds = scroll.bounds, inset = scroll.adjustedContentInset
        let values = [offset.x, offset.y, size.width, size.height, bounds.width, bounds.height,
            inset.top, inset.bottom, inset.left, inset.right]
        guard values.allSatisfy({ $0.isFinite }), size.width >= 0, size.height >= 0,
              bounds.width > 0, bounds.height > 0,
              let scrollFrame = t14Rect(scroll.convert(scroll.bounds, to: window)) else {
            result["scroll"] = ["status": "UNKNOWN_SCROLL_GEOMETRY"]
            return encode(result)
        }
        result["scroll"] = ["status": "EXACT_NEAREST_SCROLL", "insetKind": "adjustedContentInset",
            "scrollID": String(describing: ObjectIdentifier(scroll)),
            "offsetX": Double(offset.x), "offsetY": Double(offset.y),
            "sizeW": Double(size.width), "sizeH": Double(size.height),
            "boundsW": Double(bounds.width), "boundsH": Double(bounds.height),
            "insetTop": Double(inset.top), "insetBottom": Double(inset.bottom),
            "insetLeft": Double(inset.left), "insetRight": Double(inset.right),
            "frameInWindow": scrollFrame]
        return encode(result)
    }

    private func t14Rect(_ rect: CGRect) -> [String: Double]? {
        guard !rect.isNull, !rect.isInfinite,
              [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy({ $0.isFinite }),
              rect.width > 0, rect.height > 0 else { return nil }
        return ["x": Double(rect.origin.x), "y": Double(rect.origin.y),
            "width": Double(rect.width), "height": Double(rect.height)]
    }
// TASK145_T14_INSERT_END passive-native-getter
    private func encode(_ result: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              data.count <= 8192, let text = String(data: data, encoding: .utf8) else {
            return "native-name-observation=ENCODING_OR_BYTE_LIMIT"
        }
        return text
    }
}

@MainActor
private struct Task144NativeNameReadback: UIViewRepresentable {
    let fixture: Task144LocalAvailabilityRootFixture

    func makeUIView(context: Context) -> Task144NativeNameReadbackView {
        let view = Task144NativeNameReadbackView()
        view.fixture = fixture
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "task144.controlled.native-name-observation"
        view.accessibilityLabel = "Controlled native Name observation"
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: Task144NativeNameReadbackView, context: Context) { }
}

// TASK145_T14_INSERT_BEGIN context-specific-observer
@MainActor
private struct Task145T14NativeReadback: UIViewRepresentable {
    let fixture: Task144LocalAvailabilityRootFixture
    let inEditor: Bool

    func makeUIView(context: Context) -> Task144NativeNameReadbackView {
        let view = Task144NativeNameReadbackView()
        let observationContext = inEditor ? "editor" : "root"
        view.fixture = fixture
        view.t14Context = observationContext
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "task145.t14.native-observation.\(observationContext)"
        view.accessibilityLabel = "Controlled T14 native observation \(observationContext)"
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: Task144NativeNameReadbackView, context: Context) { }
}
// TASK145_T14_INSERT_END context-specific-observer
private struct Task144ControlledRootModifier: ViewModifier {
    let inEditor: Bool
    func body(content: Content) -> some View {
        if let fixture = Task144LocalAvailabilityRootFixture.current,
           fixture.hasScopeSwitchControl && !inEditor {
            VStack(spacing: 0) {
                Task144ControlledRootControls(fixture: fixture,
                    controlPrefix: inEditor ? "task144.controlled.editor" : "task144.controlled")
                    .overlay(alignment: .topLeading) {
                        // TASK145_T14_INSERT_BEGIN existing-observer-root-admission-open
                        if ProcessInfo.processInfo.environment["TASK145_T14_OBSERVATION"] == "1" {
                            Task145T14NativeReadback(fixture: fixture, inEditor: inEditor)
                                .frame(width: 1, height: 1).allowsHitTesting(false)
                        } else {
                        // TASK145_T14_INSERT_END existing-observer-root-admission-open
                        // TASK145_T18_INSERT_BEGIN existing-observer-root-admission
                        if (inEditor && ProcessInfo.processInfo.environment[
                            "TASK144_LOCAL_AVAILABILITY_OBSERVE_NATIVE_NAME"] == "1")
                            || ProcessInfo.processInfo.environment["TASK145_T18_OBSERVATION"] == "1" {
                        // TASK145_T18_INSERT_END existing-observer-root-admission
                            Task144NativeNameReadback(fixture: fixture)
                                .frame(width: 1, height: 1).allowsHitTesting(false)
                        }
                        // TASK145_T14_INSERT_BEGIN existing-observer-root-admission-close
                        }
                        // TASK145_T14_INSERT_END existing-observer-root-admission-close
                    }
                content
            }
        } else if let fixture = Task144LocalAvailabilityRootFixture.current {
            content.safeAreaInset(edge: .top, spacing: 0) {
                Task144ControlledRootControls(fixture: fixture,
                    controlPrefix: inEditor ? "task144.controlled.editor" : "task144.controlled")
                    .overlay(alignment: .topLeading) {
                        // TASK145_T14_INSERT_BEGIN existing-observer-root-admission-open
                        if ProcessInfo.processInfo.environment["TASK145_T14_OBSERVATION"] == "1" {
                            Task145T14NativeReadback(fixture: fixture, inEditor: inEditor)
                                .frame(width: 1, height: 1).allowsHitTesting(false)
                        } else {
                        // TASK145_T14_INSERT_END existing-observer-root-admission-open
                        // TASK145_T18_INSERT_BEGIN existing-observer-root-admission
                        if (inEditor && ProcessInfo.processInfo.environment[
                            "TASK144_LOCAL_AVAILABILITY_OBSERVE_NATIVE_NAME"] == "1")
                            || ProcessInfo.processInfo.environment["TASK145_T18_OBSERVATION"] == "1" {
                        // TASK145_T18_INSERT_END existing-observer-root-admission
                            Task144NativeNameReadback(fixture: fixture)
                                .frame(width: 1, height: 1).allowsHitTesting(false)
                        }
                        // TASK145_T14_INSERT_BEGIN existing-observer-root-admission-close
                        }
                        // TASK145_T14_INSERT_END existing-observer-root-admission-close
                    }
            }
        } else { content }
    }
}
extension View {
    func task144ControlledRootControls(inEditor: Bool = false) -> some View {
        modifier(Task144ControlledRootModifier(inEditor: inEditor))
    }
}

@MainActor
private final class Task144ControlledShopFetcher: LinkedShopFetching {
// TASK145_SCOPE_SWITCH_INSERT_BEGIN C-fetcher-property
    var scopeSwitchControl: Task145ScopeSwitchControl?
// TASK145_SCOPE_SWITCH_INSERT_END C-fetcher-property
    var seq6Control: Task145Seq6Control?
    var seq6RefusesPermission = false
    let shop: LinkedShop
    init(shop: LinkedShop) { self.shop = shop }
    func fetchLinkedShops() async throws -> [LinkedShop] {
// TASK145_SCOPE_SWITCH_INSERT_BEGIN C-membership-provider
        if let scopeSwitchControl { return try await scopeSwitchControl.fetchLinkedShops() }
// TASK145_SCOPE_SWITCH_INSERT_END C-membership-provider
        if seq6RefusesPermission {
            let payload: [String: Any] = ["ok": true, "code": "ok", "shops": [[
                "shop_id": shop.shopID.uuidString, "code": shop.code ?? "TASK144", "name": shop.name,
                "role": shop.role, "status": "revoked", "selectable": false, "can_write": false]]]
            let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            try seq6Control?.note("membership-rpc-revoked", ["response-sha256": ShopSyncRecoveryCanonical.sha256(String(decoding: bytes, as: UTF8.self))])
            return try MobileLinkedShopRPCDecoder.decode(bytes)
        }
        return [shop]
    }
}

@MainActor
private final class Task144ControlledRecoveryTransport: ShopSyncRecoveryRPCTransporting {
    var performance: Task145LargeUITransport?
    let owner: UUID
    let product: RemoteInventoryProductRow?
    let baseline: ShopSyncRecoveryCheckpoint
    var holdsProducts = false
    private(set) var isReleased = false
    var onHeld: (() -> Void)?
    var checkpointBoundary: (() async -> Void)?
    var beforeCheckpoint: (() throws -> Void)?
    var beforePage: ((String) throws -> Void)?
    var beforeMarker: (() throws -> Void)?
    var remoteSnapshot: (() -> Task144ControlledRemoteSnapshot)?
    var t10EventPage: ((ShopSyncEventPageParameters, ShopSyncRecoveryCheckpoint) throws -> Data)?
    var interruptionControl: Task145InterruptionControl?
    private var continuation: CheckedContinuation<Void, Never>?
    init(owner: UUID, shop: UUID, device: String, product: RemoteInventoryProductRow?) throws {
        self.owner = owner; self.product = product
        let hash = ShopSyncRecoveryCanonical.checkpointChainInitialDigest
        let empty = ShopSyncRecoveryEntityDigest(activeCount: 0, tombstoneCount: 0, idSetDigest: hash, versionDigest: hash)
        let scope = ShopSyncRecoveryScope(kind: "shop_scoped",
            key: ShopSyncRecoveryCanonical.sha256(shop.uuidString.lowercased() + ":shop_scoped:-:" + ShopSyncRecoveryCanonical.sha256(device)),
            legacyOwnerKey: nil, accountKey: AccountBindingStore.accountHash(for: owner),
            deviceKey: ShopSyncRecoveryCanonical.sha256(device))
        let events = ShopSyncRecoveryEventCheckpoint(maxId: "41", verifiedBaselineId: "0", requiresFullRecovery: true,
            domainMaxIds: .init(catalog: "41", prices: "41", history: "41"))
        let integrity = ShopSyncRecoveryIntegrity(productCategoryViolationCount: 0, productSupplierViolationCount: 0,
            priceProductViolationCount: 0, primaryImageViolationCount: 0, historyIdViolationCount: 0, totalViolationCount: 0)
        let initial = ShopSyncRecoveryCheckpoint(schemaVersion: "shop-sync-recovery-checkpoint-v1", shopId: shop,
            scope: scope, syncEvents: events, catalog: .init(suppliers: empty, categories: empty,
                products: .init(activeCount: 0, tombstoneCount: 0, idSetDigest: hash, versionDigest: hash, identityDigest: hash),
                digest: ShopSyncRecoveryCanonical.sha256(hash + "\n" + hash + "\n" + hash)),
            prices: empty, history: empty, images: empty, integrity: integrity,
            checkpointDigest: ShopSyncRecoveryCanonical.sha256("task144-controlled-root"))
        var accumulator = ShopSyncRecoveryDigestAccumulator(hasIdentity: true)
        if let product {
            let row = try ShopSyncRecoveryRowContract.product(product, checkpoint: initial)
            try accumulator.append(orderingID: row.orderingID, idLine: row.idLine, versionLine: row.versionLine,
                identityLine: row.identityLine, isTombstone: row.isTombstone)
        }
        let products = accumulator.finalize()
        baseline = ShopSyncRecoveryCheckpoint(schemaVersion: initial.schemaVersion, shopId: shop, scope: scope,
            syncEvents: events, catalog: .init(suppliers: empty, categories: empty, products: products,
                digest: ShopSyncRecoveryCanonical.sha256(hash + "\n" + hash + "\n" + products.versionDigest)),
            prices: empty, history: empty, images: empty, integrity: integrity, checkpointDigest: initial.checkpointDigest)
    }
    func release() { isReleased = true; continuation?.resume(); continuation = nil }
    func authenticatedUserID() async throws -> UUID { owner }
    // Both recovery RPCs and ordinary Catalog writes describe one controlled
    // server. A later recovery must not resurrect the pre-ACK baseline.
    private func currentSnapshot() throws -> (Task144ControlledRemoteSnapshot, ShopSyncRecoveryCheckpoint) {
        let snapshot = remoteSnapshot?() ?? .init(product: product, supplier: nil, category: nil, eventMaxID: 41)
        func digest(_ rows: [ShopSyncRecoveryLedgerRecord], identity: Bool = false) throws -> ShopSyncRecoveryEntityDigest {
            var accumulator = ShopSyncRecoveryDigestAccumulator(hasIdentity: identity)
            for row in rows {
                try accumulator.append(orderingID: row.orderingID, idLine: row.idLine, versionLine: row.versionLine,
                    identityLine: row.identityLine, isTombstone: row.isTombstone)
            }
            return accumulator.finalize()
        }
        let suppliers = try digest(snapshot.supplier.map { [try ShopSyncRecoveryRowContract.supplier($0, checkpoint: baseline)] } ?? [])
        let categories = try digest(snapshot.category.map { [try ShopSyncRecoveryRowContract.category($0, checkpoint: baseline)] } ?? [])
        let productRows = ((snapshot.product.map { [$0] } ?? []) + snapshot.additionalProducts).sorted { $0.id.uuidString < $1.id.uuidString }
        let products = try digest(productRows.map { try ShopSyncRecoveryRowContract.product($0, checkpoint: baseline) }, identity: true)
        let catalog = ShopSyncRecoveryCatalogDigest(suppliers: suppliers, categories: categories, products: products,
            digest: ShopSyncRecoveryCanonical.sha256(suppliers.versionDigest + "\n" + categories.versionDigest + "\n" + products.versionDigest))
        let prices = try digest(snapshot.prices.map { try ShopSyncRecoveryRowContract.price($0, checkpoint: baseline) })
        let history = try digest(snapshot.history.map { try ShopSyncRecoveryRowContract.history($0, checkpoint: baseline) })
        let domainSuffix = snapshot.hasDomains ? "\n" + prices.versionDigest + "\n" + history.versionDigest : ""
        let unchanged = catalog == baseline.catalog && snapshot.eventMaxID == 41 && prices == baseline.prices && history == baseline.history
        let checkpoint = ShopSyncRecoveryCheckpoint(schemaVersion: baseline.schemaVersion, shopId: baseline.shopId,
            scope: baseline.scope, syncEvents: .init(maxId: String(snapshot.eventMaxID), verifiedBaselineId: "0",
                requiresFullRecovery: true, domainMaxIds: .init(catalog: String(snapshot.eventMaxID),
                    prices: snapshot.hasDomains ? String(snapshot.eventMaxID) : baseline.syncEvents.domainMaxIds.prices,
                    history: snapshot.hasDomains ? String(snapshot.eventMaxID) : baseline.syncEvents.domainMaxIds.history)),
            catalog: catalog, prices: prices, history: history, images: baseline.images,
            integrity: baseline.integrity, checkpointDigest: unchanged ? baseline.checkpointDigest
                : ShopSyncRecoveryCanonical.sha256("task144-controlled-root\n" + String(snapshot.eventMaxID) + "\n" + catalog.digest + domainSuffix))
        return (snapshot, checkpoint)
    }
    func checkpoint(_ parameters: ShopSyncRecoveryCheckpointParameters) async throws -> Data {
        if let performance { return try performance.checkpoint(parameters) }
        try beforeCheckpoint?()
        await checkpointBoundary?()
        let (_, current) = try currentSnapshot()
        return try JSONEncoder().encode(ShopSyncRecoveryCheckpoint(schemaVersion: current.schemaVersion, shopId: current.shopId,
            scope: current.scope, syncEvents: .init(maxId: current.syncEvents.maxId, verifiedBaselineId: parameters.verifiedBaselineID,
                requiresFullRecovery: true, domainMaxIds: current.syncEvents.domainMaxIds), catalog: current.catalog,
            prices: current.prices, history: current.history, images: current.images, integrity: current.integrity,
            checkpointDigest: current.checkpointDigest))
    }
    func page(_ parameters: ShopSyncRecoveryPageParameters) async throws -> Data {
        if let performance { return try await performance.page(parameters) }
        try beforePage?(parameters.domain)
        guard let domain = ShopSyncRecoveryDomain(rawValue: parameters.domain) else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        if let interruptionControl {
            if domain == .products { try await interruptionControl.beforeProductPage(afterID: parameters.afterID) }
            else { try interruptionControl.note("page:" + domain.rawValue, afterID: parameters.afterID) }
        }
        if holdsProducts && domain == .products && !isReleased {
            onHeld?()
            await withCheckedContinuation { continuation = $0 }
            try Task.checkCancellation()
        }
        let (snapshot, current) = try currentSnapshot()
        func encode<Row: Encodable>(_ rows: [Row], nextAfterID: String? = nil) throws -> Data {
            try JSONEncoder().encode(Task144ControlledPage(schemaVersion: "shop-sync-recovery-page-v1",
                shopId: parameters.shopID, scope: current.scope, domain: domain,
                snapshotEventMaxId: parameters.expectedEventMaxID, currentScopeEventMaxId: current.syncEvents.maxId,
                baselineDomainEventMaxId: parameters.expectedDomainEventMaxID,
                pageDomainEventMaxId: current.syncEvents.domainMaxID(for: domain),
                domainScope: domain == .history ? current.scope.historyKind : current.scope.kind,
                pageLimit: parameters.limit, rows: rows, nextAfterId: nextAfterID, hasMore: nextAfterID != nil))
        }
        switch domain {
        case .suppliers: return try encode(snapshot.supplier.map { [$0] } ?? [])
        case .categories: return try encode(snapshot.category.map { [$0] } ?? [])
        case .products:
            if let interruptionControl, !interruptionControl.isSeed {
                let rows = interruptionControl.state.products
                guard parameters.limit == 1, rows.count == 2,
                      parameters.afterID == nil || parameters.afterID == rows[0].id.uuidString.lowercased() else {
                    throw ShopSyncRecoveryContractError.invalidCursor
                }
                return parameters.afterID == nil
                    ? try encode([rows[0]], nextAfterID: rows[0].id.uuidString.lowercased())
                    : try encode([rows[1]])
            }
            return try encode(snapshot.product.map { [$0] } ?? [])
        case .prices: return try encode(snapshot.prices)
        case .history: return try encode(snapshot.history)
        case .images: return try encode([RemoteInventoryProductRow]())
        }
    }
    func marker(_ parameters: ShopSyncConvergenceMarkerParameters) async throws -> Data {
        if let performance { return try performance.marker(parameters) }
        try beforeMarker?()
        let (_, current) = try currentSnapshot()
        return try JSONEncoder().encode(ShopSyncRecoveryConvergenceMarker(schemaVersion: "shop-sync-convergence-marker-v1",
            status: "ready", shopId: current.shopId, scope: current.scope,
            syncEvents: .init(maxId: current.syncEvents.maxId, verifiedBaselineId: parameters.verifiedBaselineID, requiresFullRecovery: false,
                domainMaxIds: current.syncEvents.domainMaxIds), catalog: current.catalog, prices: current.prices,
            history: current.history, images: current.images, integrity: .init(totalViolationCount: 0),
            checkpointDigest: current.checkpointDigest, serverNoWorkEligible: true,
            markerDigest: ShopSyncRecoveryCanonical.sha256("task144-controlled-marker")))
    }
    func eventPage(_ parameters: ShopSyncEventPageParameters) async throws -> Data {
        guard let t10EventPage else { throw ShopSyncRecoveryContractError.fullRecoveryRequired }
        let (_, checkpoint) = try currentSnapshot()
        return try t10EventPage(parameters, checkpoint)
    }
}
private nonisolated struct Task144ControlledPage<Row: Encodable>: Encodable {
    let schemaVersion: String; let shopId: UUID; let scope: ShopSyncRecoveryScope; let domain: ShopSyncRecoveryDomain
    let snapshotEventMaxId: String; let currentScopeEventMaxId: String
    let baselineDomainEventMaxId: String; let pageDomainEventMaxId: String; let domainScope: String
    let pageLimit: Int; let rows: [Row]; let nextAfterId: String?; let hasMore: Bool
}

private nonisolated struct Task144ControlledRemoteSnapshot {
    let product: RemoteInventoryProductRow?
    let supplier: RemoteInventorySupplierRow?
    let category: RemoteInventoryCategoryRow?
    let eventMaxID: Int64
    var additionalProducts: [RemoteInventoryProductRow] = []
    let prices: [RemoteInventoryProductPriceRow]
    let history: [RemoteSharedSheetSessionRow]
    let hasDomains: Bool
    init(product: RemoteInventoryProductRow?, supplier: RemoteInventorySupplierRow?, category: RemoteInventoryCategoryRow?,
         eventMaxID: Int64, prices: [RemoteInventoryProductPriceRow] = [], history: [RemoteSharedSheetSessionRow] = [], hasDomains: Bool = false,
         additionalProducts: [RemoteInventoryProductRow] = []) {
        self.product = product; self.supplier = supplier; self.category = category; self.eventMaxID = eventMaxID
        self.prices = prices; self.history = history; self.hasDomains = hasDomains
        self.additionalProducts = additionalProducts
    }
}

nonisolated private struct Task144ObservedStoredProductMutation: Codable {
    struct Call: Codable {
        struct Arguments: Codable {
            let id: UUID
            let payload: SyncAutomaticProductUpdatePayload
            enum CodingKeys: String, CodingKey { case id = "_0"; case payload = "_1" }
        }
        let updateProduct: Arguments
    }
    let call: Call
}

/// A file-backed controlled remote for the isolated R4 UI namespace. Its
/// responses pass through the real writers; this state is never a local ACK.
@MainActor
private final class Task145R4ReviewControl {
    static let nameA = "R23 saved catalog A"
    static let itemB = "R23 ordinary item B"
    struct State: Codable {
        let schema: Int
        let runID: UUID
        var product: RemoteInventoryProductRow
        var peerReady = false
        var generationID: UUID?
        var catalogRequests: [Data] = []
        var catalogIngressCount = 0
        var originalPending: LocalPendingChangeCASToken?
        var originalSeal: String?
        var childBefore: LocalPendingChangeCASToken?
        var receiptJSON: String?
        var laterPending: LocalPendingChangeCASToken?
        var priceRequests: [Data] = []
        var priceIngressCount = 0
        var prices: [RemoteInventoryProductPriceRow] = []
        var events: [RemoteSyncEventRow] = []
        var eventClientIDs: [String: RemoteSyncEventRow] = [:]
        var terminal = false
        var processIDs: [Int32] = []
    }
    let url: URL
    let reopening: Bool
    var state: State
    var captureEnvelope: ((UUID, SyncAutomaticProductUpdatePayload, Task126VerifiedOwnerStoreScope) throws -> Data)?
    init(url: URL, runID: UUID, initial: RemoteInventoryProductRow, reopening: Bool) throws {
        self.url = url; self.reopening = reopening
        if reopening {
            let data = try Data(contentsOf: url)
            guard data.count <= 262_144 else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = try JSONDecoder().decode(State.self, from: data)
            guard state.schema == 1, state.runID == runID, state.product.id == initial.id,
                  state.product.ownerUserID == initial.ownerUserID, state.product.shopID == initial.shopID,
                  state.receiptJSON != nil, state.processIDs.count < 3,
                  !state.processIDs.contains(ProcessInfo.processInfo.processIdentifier) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        } else {
            guard !FileManager.default.fileExists(atPath: url.path) else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = State(schema: 1, runID: runID, product: initial)
        }
        state.processIDs.append(ProcessInfo.processInfo.processIdentifier)
        try persist()
    }
    func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        guard data.count <= 262_144 else { throw SyncStoreGenerationError.activationReadBackFailed }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    var ledger: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(state).base64EncodedString()) ?? "encoding-failed"
    }
    func preparePeer() throws -> RemoteInventoryProductRow {
        guard !reopening, !state.peerReady, state.catalogRequests.isEmpty else { throw SyncStoreGenerationError.activationReadBackFailed }
        let old = state.product
        state.product = RemoteInventoryProductRow(id: old.id, ownerUserID: old.ownerUserID, shopID: old.shopID,
            barcode: old.barcode, itemNumber: old.itemNumber, productName: Self.nameA,
            secondProductName: old.secondProductName, purchasePrice: 37, retailPrice: old.retailPrice,
            supplierID: old.supplierID, categoryID: old.categoryID, stockQuantity: old.stockQuantity,
            updatedAt: "2026-10-23T20:10:00.123456Z", deletedAt: nil)
        state.peerReady = true
        try persist()
        return state.product
    }
    func update(id: UUID, payload: SyncAutomaticProductUpdatePayload,
                scope: Task126VerifiedOwnerStoreScope) throws -> RemoteInventoryProductRow {
        guard state.peerReady, id == state.product.id, scope.ownerUserID == state.product.ownerUserID,
              scope.shopID == state.product.shopID, let captureEnvelope else { throw SyncStoreGenerationError.activationReadBackFailed }
        let data = try captureEnvelope(id, payload, scope)
        let envelope = try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self, from: data)
        if state.catalogRequests.isEmpty {
            guard payload.productName == Self.nameA, payload.purchasePrice == 37,
                  Set(envelope.pending.changedFieldsRaw.split(separator: ",").map(String.init)) == ["productname", "purchaseprice"] else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            state.catalogRequests.append(data)
            state.originalPending = envelope.pending
            state.originalSeal = String(decoding: data, as: UTF8.self)
            try persist()
            // A distinct controlled peer already owns the compared values.
            // This atomic rejected request changes no remote row.
            throw SyncCatalogWriteRejectedWithoutCommit(sqlstate: "23505")
        }
        guard state.receiptJSON != nil, state.catalogRequests.count == 1,
              envelope.pending.changeID != state.originalPending?.changeID,
              envelope.pending.changedFieldsRaw == "itemnumber", payload.itemNumber == Self.itemB,
              payload.productName == nil, payload.purchasePrice == nil,
              envelope.pending.baselineFingerprintHash == CatalogConflictProductValues(row: state.product).fingerprint else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.catalogRequests.append(data)
        state.laterPending = envelope.pending
        let old = state.product
        state.product = RemoteInventoryProductRow(id: old.id, ownerUserID: old.ownerUserID, shopID: old.shopID,
            barcode: old.barcode, itemNumber: Self.itemB, productName: old.productName,
            secondProductName: old.secondProductName, purchasePrice: old.purchasePrice, retailPrice: old.retailPrice,
            supplierID: old.supplierID, categoryID: old.categoryID, stockQuantity: old.stockQuantity,
            updatedAt: "2026-10-23T20:12:00.654321Z", deletedAt: nil)
        try persist()
        return state.product
    }
    func noteCatalogEntry() throws { state.catalogIngressCount += 1; try persist() }
    func notePriceEntry() throws { state.priceIngressCount += 1; try persist() }
    var captureAdoption: (() throws -> Void)?
    func insertPrices(_ payloads: [SyncAutomaticProductPricePayload], scope: Task126VerifiedOwnerStoreScope) throws -> [RemoteInventoryProductPriceRow] {
        try captureAdoption?()
        guard state.priceIngressCount == 1, state.receiptJSON != nil, payloads.count == 1, let payload = payloads.first,
              payload.productID == state.product.id, payload.price == 37,
              payload.ownerUserID == scope.ownerUserID, payload.shopID == scope.shopID,
              state.priceRequests.isEmpty else { throw SyncStoreGenerationError.activationReadBackFailed }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        state.priceRequests.append(try encoder.encode(payloads))
        let row = RemoteInventoryProductPriceRow(id: payload.id, ownerUserID: payload.ownerUserID,
            shopID: payload.shopID, productID: payload.productID, type: payload.type, price: payload.price,
            effectiveAt: payload.effectiveAt, source: payload.source, note: payload.note,
            createdAt: payload.createdAt, updatedAt: "2026-10-23T20:11:00.123456Z")
        state.prices = [row]
        try persist()
        return [row]
    }
}

@MainActor
private final class Task144ControlledCatalogRemote: SyncAutomaticCatalogRemoteWriting, SyncAutomaticProductPriceRemoteWriting, SyncEventRecording,
    SyncAutomaticIncrementalRemote, ShopScopedIncrementalRPCAuthorizing,
    ShopScopedIncrementalFencePersisting, @unchecked Sendable {
    nonisolated let usesServerAuthorizedShopScope = true
    enum Fault: Error { case unexpectedCall }
    private var current: RemoteInventoryProductRow
    private var t10Control: Task145SavedRecoveryControl?
    func configureT10(_ control: Task145SavedRecoveryControl) {
        t10Control = control; current = control.state.product
        events = control.state.events; eventClientIDs = control.state.eventClientIDs
        eventCount = events.count
    }
    private var r4Control: Task145R4ReviewControl?
    func configureR4(_ control: Task145R4ReviewControl) {
        r4Control = control; current = control.state.product
        events = control.state.events; eventClientIDs = control.state.eventClientIDs
        attemptCount = control.state.catalogIngressCount; eventCount = events.count
    }
    func prepareR4Peer() throws {
        _ = try verifiedScope()
        guard let r4Control else { throw Fault.unexpectedCall }
        current = try r4Control.preparePeer()
    }
    private let authoritativeScope: ShopSyncRecoveryScope
    private let isEmpty: Bool
    private var events: [RemoteSyncEventRow] = []
// TASK145_T19_INSERT_BEGIN transport-script
    var t19RPC: ((String, [String: Any]) -> Int)?
    var t19RPCComplete: ((String, Int, String?) -> Void)?
    private var t19AdditionalEvents: [RemoteSyncEventRow] = []
    func t19ArmRepeatedMaterial() throws {
        guard t19RPC != nil, restartControl != nil, events.count == 1, events[0].id == 42,
              t19AdditionalEvents.isEmpty, current.productName == Task145SaveBControl.nameA else { throw Fault.unexpectedCall }
        let encoder = JSONEncoder()
        let original = try JSONSerialization.jsonObject(with: encoder.encode(events[0])) as? [String: Any]
        guard var original else { throw Fault.unexpectedCall }
        for id in [43, 44] {
            original["id"] = String(id)
            original.removeValue(forKey: "source_device_id")
            original.removeValue(forKey: "client_event_id")
            original["source_device_key"] = ShopSyncRecoveryCanonical.sha256("task145-t19-controlled-peer")
            original["client_event_key"] = ShopSyncRecoveryCanonical.sha256("task145-t19-peer-\(id)")
            t19AdditionalEvents.append(try JSONDecoder().decode(RemoteSyncEventRow.self,
                from: JSONSerialization.data(withJSONObject: original)))
        }
    }

// TASK145_T19_INSERT_END transport-script
    private var eventClientIDs: [String: RemoteSyncEventRow] = [:]
    private var performanceDirectory: URL?
    private var performanceTransport: Task145LargeUITransport?
    private var performanceSuppliers: [RemoteInventorySupplierRow] = []
    private var performanceCategories: [RemoteInventoryCategoryRow] = []
    private var performancePrices: [RemoteInventoryProductPriceRow] = []
    private nonisolated struct PerformanceServerLedger: Codable, Sendable {
        let current: RemoteInventoryProductRow
        let events: [RemoteSyncEventRow]
        let eventClientIDs: [String: RemoteSyncEventRow]
        let extraPrices: [RemoteInventoryProductPriceRow]
    }
    func configurePerformanceServer(directory: URL, transport: Task145LargeUITransport) throws {
        performanceDirectory = directory; performanceTransport = transport
        performanceSuppliers = try JSONDecoder().decode([RemoteInventorySupplierRow].self, from: Data(contentsOf: directory.appendingPathComponent("suppliers.json")))
        performanceCategories = try JSONDecoder().decode([RemoteInventoryCategoryRow].self, from: Data(contentsOf: directory.appendingPathComponent("categories.json")))
        let file = directory.appendingPathComponent("controlled-server-ledger.json")
        if FileManager.default.fileExists(atPath: file.path) {
            let ledger = try JSONDecoder().decode(PerformanceServerLedger.self, from: Data(contentsOf: file))
            guard ledger.current.id == current.id, ledger.current.ownerUserID == current.ownerUserID,
                  ledger.current.shopID == current.shopID else { throw Fault.unexpectedCall }
            current = ledger.current; events = ledger.events; eventClientIDs = ledger.eventClientIDs
            eventCount = events.count; performancePrices = ledger.extraPrices
        } else {
            guard Task145PerformanceConfiguration.mode == "seed" else { throw Fault.unexpectedCall }
            let ledger = PerformanceServerLedger(current: current, events: events, eventClientIDs: eventClientIDs, extraPrices: performancePrices)
            try JSONEncoder().encode(ledger).write(to: file, options: .withoutOverwriting)
        }
    }
    private func persistPerformanceServer() async throws {
        guard let performanceDirectory else { return }
        let ledger = PerformanceServerLedger(current: current, events: events, eventClientIDs: eventClientIDs, extraPrices: performancePrices)
        let bytes = try JSONEncoder().encode(ledger)
        try await Task.detached(priority: .utility) {
            try bytes.write(to: performanceDirectory.appendingPathComponent("controlled-server-ledger.json"), options: .atomic)
        }.value
        try await performanceTransport?.recordServerProduct(current, extraPrices: performancePrices, eventMaxID: Int64(41 + events.count),
            catalogMaxID: events.filter { $0.domain == "catalog" }.map(\.id).max() ?? 41,
            pricesMaxID: events.filter { $0.domain == "prices" }.map(\.id).max() ?? 41)
    }
    private let allowsRelatedSave: Bool
    private let saveBControl: Task145SaveBControl?
    private let restartControl: Task145RestartControl?
    private let domainControl: Task145DomainControl?
    private let isolationControl: Task145IsolationControl?
    private let interruptionControl: Task145InterruptionControl?
    private var supplier: RemoteInventorySupplierRow?
    private var category: RemoteInventoryCategoryRow?
    private var productContinuation: CheckedContinuation<Void, Never>?
    private(set) var isProductHeld = false
    var currentSupplierID: UUID? { supplier?.id }
    var currentCategoryID: UUID? { category?.id }
    var recoverySnapshot: Task144ControlledRemoteSnapshot {
        .init(product: isEmpty ? nil : current, supplier: supplier, category: category,
            eventMaxID: interruptionControl?.isSeed == false ? 42 : (events.last?.id ?? 41), prices: t10Control?.state.prices ?? r4Control?.state.prices ?? domainControl?.state.prices ?? [],
            history: domainControl?.state.history ?? [], hasDomains: domainControl != nil || t10Control != nil,
            additionalProducts: interruptionControl?.extraProduct.map { [$0] } ?? [])
    }
    private(set) var attemptCount = 0
    private(set) var eventCount = 0
    var observeProductAttempt: ((UUID, SyncAutomaticProductUpdatePayload, Task126VerifiedOwnerStoreScope, Bool) -> Void)?
    private(set) var eventRequestObservations: [String] = []
    private(set) var eventRequestKeys: [String] = []
    private(set) var eventRequests: [SyncEventRecordRequest] = []
    private(set) var eventObservationCapped = false
    var observeRawProductEntry: (() throws -> Void)?
    var observeRawEventEntry: (() throws -> Void)?
    var losesFirstCommittedProductResponse = false
    private(set) var firstProductResponseWasLost = false
// TASK145_SCOPE_SWITCH_INSERT_BEGIN C-catalog-ingress-property
    var scopeSwitchIngress: ((String) throws -> Void)?
// TASK145_SCOPE_SWITCH_INSERT_END C-catalog-ingress-property
    var seq6Control: Task145Seq6Control?
    init(initial: RemoteInventoryProductRow, authoritativeScope: ShopSyncRecoveryScope, isEmpty: Bool,
        allowsRelatedSave: Bool, saveBControl: Task145SaveBControl? = nil,
        restartControl: Task145RestartControl? = nil, domainControl: Task145DomainControl? = nil, isolationControl: Task145IsolationControl? = nil, interruptionControl: Task145InterruptionControl? = nil) {
        current = restartControl?.state.product ?? domainControl?.state.product ?? saveBControl?.state.product ?? initial
        self.authoritativeScope = authoritativeScope; self.isEmpty = isEmpty
        self.allowsRelatedSave = allowsRelatedSave; self.saveBControl = saveBControl
        self.restartControl = restartControl
        self.domainControl = domainControl
        self.interruptionControl = interruptionControl
        self.isolationControl = isolationControl
        if let isolationControl {
            events = isolationControl.state.events; eventClientIDs = isolationControl.state.eventClients
            eventCount = events.count
        }
        if let saveBControl {
            events = saveBControl.state.events
            eventClientIDs = saveBControl.state.eventClientIDs
            eventCount = events.count
            attemptCount = saveBControl.state.requests.count
        }
        if let restartControl {
            events = restartControl.state.events
            eventClientIDs = restartControl.state.eventClientIDs
            eventCount = events.count
            attemptCount = restartControl.state.requests.count
        }
        if let domainControl {
            events = domainControl.state.events; eventClientIDs = domainControl.state.eventClientIDs
            eventCount = events.count; attemptCount = domainControl.state.catalogEnvelopes.count
        }
    }
    func publishR23EditorPeerValues() throws -> UUID {
        _ = try verifiedScope()
        guard !isEmpty, current.productName == "Safe local baseline", attemptCount == 0 else {
            throw Fault.unexpectedCall
        }
        current = RemoteInventoryProductRow(id: current.id, ownerUserID: current.ownerUserID,
            shopID: current.shopID, barcode: current.barcode, itemNumber: "R23 peer item",
            productName: "R23 peer name", secondProductName: current.secondProductName,
            purchasePrice: current.purchasePrice, retailPrice: current.retailPrice,
            supplierID: current.supplierID, categoryID: current.categoryID,
            stockQuantity: current.stockQuantity, updatedAt: "2026-07-21T12:02:00.000000Z", deletedAt: nil)
        guard events.isEmpty else { throw Fault.unexpectedCall }
        let event: [String: Any] = ["id": "42", "owner_user_id": current.ownerUserID.uuidString,
            "shop_id": current.shopID!.uuidString, "domain": "catalog", "event_type": "catalog_changed",
            "source": "r23-controlled-peer", "source_device_key": ShopSyncRecoveryCanonical.sha256("r23-other-device"),
            "client_event_key": ShopSyncRecoveryCanonical.sha256("r23-peer-event-42"), "changed_count": 1,
            "entity_ids": ["supplier_ids": [], "category_ids": [], "product_ids": [current.id.uuidString.lowercased()]],
            "metadata": [:], "requires_full_recovery": false, "created_at": "2026-07-21T12:02:00Z"]
        events = [try JSONDecoder().decode(RemoteSyncEventRow.self, from: JSONSerialization.data(withJSONObject: event))]
        return current.id
    }
    func publishR23DraftPeerValues(scenario: String, step: Int) throws {
        _ = try verifiedScope()
        guard ProcessInfo.processInfo.environment["TASK145_DRAFT_REVIEW_UI"] == scenario,
              ["mixed", "use-current", "deleted-rebind"].contains(scenario),
              (1...2).contains(step), events.count == step - 1, attemptCount == 0,
              current.deletedAt == nil else { throw Fault.unexpectedCall }
        let stamp = String(format: "2026-07-21T12:03:%02d.123456Z", step)
        let deletes = scenario == "deleted-rebind"
        let keepsName = scenario == "use-current" && step == 2
        current = RemoteInventoryProductRow(id: current.id, ownerUserID: current.ownerUserID,
            shopID: current.shopID, barcode: current.barcode, itemNumber: "R23 peer item \(step)",
            productName: keepsName ? current.productName : "R23 peer name \(step)",
            secondProductName: keepsName ? current.secondProductName : "R23 peer second \(step)",
            purchasePrice: current.purchasePrice, retailPrice: current.retailPrice,
            supplierID: current.supplierID, categoryID: current.categoryID, stockQuantity: current.stockQuantity,
            updatedAt: stamp, deletedAt: deletes ? stamp : nil)
        let event: [String: Any] = ["id": String(41 + step), "owner_user_id": current.ownerUserID.uuidString,
            "shop_id": current.shopID!.uuidString, "domain": "catalog", "event_type": "catalog_changed",
            "source": "r23-controlled-peer", "source_device_key": ShopSyncRecoveryCanonical.sha256("r23-other-device"),
            "client_event_key": ShopSyncRecoveryCanonical.sha256("r23-draft-event-\(41 + step)"), "changed_count": 1,
            "entity_ids": ["supplier_ids": [], "category_ids": [], "product_ids": [current.id.uuidString.lowercased()]],
            "metadata": [:], "requires_full_recovery": false, "created_at": stamp]
        events.append(try JSONDecoder().decode(RemoteSyncEventRow.self, from: JSONSerialization.data(withJSONObject: event)))
    }
    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
// TASK145_T19_INSERT_BEGIN rpc-createSuppliers-begin
        let t19Entry = t19RPC?("createSuppliers", ["count": payloads.count]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("createSuppliers", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-createSuppliers-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-createSuppliers
        try scopeSwitchIngress?("write:createSuppliers")
// TASK145_SCOPE_SWITCH_INSERT_END raw-createSuppliers
        if let seq6Control, seq6Control.armed { try seq6Control.note("product-write", ["operation": "createSuppliers"]) }
        try isolationControl?.raw("createSuppliers", identity: "entry-before-validation")
        _ = try verifiedScope()
        guard allowsRelatedSave, payloads.count == 1, let payload = payloads.first,
              payload.ownerUserID == current.ownerUserID, payload.shopID == current.shopID,
              payload.name == "New related supplier", supplier == nil || supplier?.id == payload.id else { throw Fault.unexpectedCall }
        let row = RemoteInventorySupplierRow(id: payload.id, ownerUserID: payload.ownerUserID, shopID: payload.shopID,
            name: payload.name, updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: nil)
        supplier = row
        return [row]

// TASK145_T19_INSERT_BEGIN rpc-createSuppliers-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-createSuppliers-end
    }
    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
// TASK145_T19_INSERT_BEGIN rpc-updateSupplier-begin
        let t19Entry = t19RPC?("updateSupplier", ["id": id.uuidString]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("updateSupplier", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-updateSupplier-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-updateSupplier
        try scopeSwitchIngress?("write:updateSupplier")
// TASK145_SCOPE_SWITCH_INSERT_END raw-updateSupplier
        if let seq6Control, seq6Control.armed { try seq6Control.note("product-write", ["operation": "updateSupplier"]) }
        try isolationControl?.raw("updateSupplier", identity: id.uuidString)
        throw Fault.unexpectedCall

// TASK145_T19_INSERT_BEGIN rpc-updateSupplier-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-updateSupplier-end
    }
    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
// TASK145_T19_INSERT_BEGIN rpc-createCategories-begin
        let t19Entry = t19RPC?("createCategories", ["count": payloads.count]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("createCategories", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-createCategories-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-createCategories
        try scopeSwitchIngress?("write:createCategories")
// TASK145_SCOPE_SWITCH_INSERT_END raw-createCategories
        if let seq6Control, seq6Control.armed { try seq6Control.note("product-write", ["operation": "createCategories"]) }
        try isolationControl?.raw("createCategories", identity: "entry-before-validation")
        _ = try verifiedScope()
        guard allowsRelatedSave, payloads.count == 1, let payload = payloads.first,
              payload.ownerUserID == current.ownerUserID, payload.shopID == current.shopID,
              payload.name == "New related category", category == nil || category?.id == payload.id else { throw Fault.unexpectedCall }
        let row = RemoteInventoryCategoryRow(id: payload.id, ownerUserID: payload.ownerUserID, shopID: payload.shopID,
            name: payload.name, updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: nil)
        category = row
        return [row]

// TASK145_T19_INSERT_BEGIN rpc-createCategories-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-createCategories-end
    }
    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
// TASK145_T19_INSERT_BEGIN rpc-updateCategory-begin
        let t19Entry = t19RPC?("updateCategory", ["id": id.uuidString]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("updateCategory", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-updateCategory-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-updateCategory
        try scopeSwitchIngress?("write:updateCategory")
// TASK145_SCOPE_SWITCH_INSERT_END raw-updateCategory
        if let seq6Control, seq6Control.armed { try seq6Control.note("product-write", ["operation": "updateCategory"]) }
        try isolationControl?.raw("updateCategory", identity: id.uuidString)
        throw Fault.unexpectedCall

// TASK145_T19_INSERT_BEGIN rpc-updateCategory-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-updateCategory-end
    }
    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        // R23 observes ordinary Product create/update ingress, including a
        // rejected create before every fake-server payload/scope guard.
        if ProcessInfo.processInfo.environment["TASK145_DRAFT_REVIEW_UI"] != nil {
            try observeRawProductEntry?()
        }
// TASK145_T19_INSERT_BEGIN rpc-createProducts-begin
        let t19Entry = t19RPC?("createProducts", ["count": payloads.count]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("createProducts", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-createProducts-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-createProducts
        try scopeSwitchIngress?("write:createProducts")
// TASK145_SCOPE_SWITCH_INSERT_END raw-createProducts
        if let seq6Control, seq6Control.armed { try seq6Control.note("product-write", ["operation": "createProducts"]) }
        guard let isolationControl else { throw Fault.unexpectedCall }
        try isolationControl.raw("createProducts", identity: "entry-before-validation")
        try isolationControl.captureLastIdentity(JSONEncoder().encode(payloads).base64EncodedString())
        _ = try verifiedScope()
        return try isolationControl.create(payloads, initial: current)

// TASK145_T19_INSERT_BEGIN rpc-createProducts-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-createProducts-end
    }
    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        if Task145PerformanceConfiguration.enabled { return try await performanceUpdateProduct(id: id, payload: payload) }
// TASK145_T19_INSERT_BEGIN rpc-updateProduct-begin
        let t19Entry = t19RPC?("updateProduct", ["id": id.uuidString]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("updateProduct", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-updateProduct-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-updateProduct
        try scopeSwitchIngress?("write:updateProduct")
// TASK145_SCOPE_SWITCH_INSERT_END raw-updateProduct
        try isolationControl?.raw("updateProduct", identity: id.uuidString)
        try t10Control?.noteIngress("catalog")
        try observeRawProductEntry?() // Count before scope/payload validation, including rejected entries.
        let scope = try verifiedScope()
        if let restartControl { try restartControl.noteCatalogEntry() }
        if let domainControl { try domainControl.noteRPCEntry("catalog") }
        guard !isEmpty, id == current.id else { throw Fault.unexpectedCall }
        attemptCount += 1
        if let t10Control { try t10Control.recordCatalog(id: id, payload: payload, scope: scope) }
        if let r4Control {
            current = try r4Control.update(id: id, payload: payload, scope: scope)
            return current
        }
        observeProductAttempt?(id, payload, scope, false)
        var saveBEnvelope: Data?
        if let saveBControl {
            saveBEnvelope = try await saveBControl.enter(id: id, payload: payload, scope: scope)
            _ = try verifiedScope()
        }
        let restartEnvelope = try restartControl?.enter(id: id, payload: payload, scope: scope)
        if let domainControl { try domainControl.observeCatalog(id: id, payload: payload, scope: scope) }
        if allowsRelatedSave {
            isProductHeld = true
            await withCheckedContinuation { productContinuation = $0 }
            isProductHeld = false
            try Task.checkCancellation()
            _ = try verifiedScope()
        }
        current = RemoteInventoryProductRow(id: id, ownerUserID: current.ownerUserID, shopID: current.shopID,
            barcode: payload.barcode ?? current.barcode, itemNumber: payload.itemNumber ?? current.itemNumber,
            productName: payload.productName ?? current.productName, secondProductName: payload.secondProductName ?? current.secondProductName,
            purchasePrice: payload.purchasePrice ?? current.purchasePrice, retailPrice: payload.retailPrice ?? current.retailPrice,
            supplierID: payload.supplierID ?? current.supplierID, categoryID: payload.categoryID ?? current.categoryID,
            stockQuantity: payload.stockQuantity ?? current.stockQuantity,
            updatedAt: (saveBControl != nil && payload.productName == Task145SaveBControl.nameB) || (domainControl != nil && payload.retailPrice == 13)
                ? "2026-07-21T12:02:00.000000Z" : "2026-07-21T12:01:00.000000Z", deletedAt: payload.deletedAt)
        if let saveBControl, let saveBEnvelope {
            let response = current
            try await saveBControl.committed(response, envelope: saveBEnvelope)
            _ = try verifiedScope()
            // A's response is a captured value, never a later mutable B body.
            return response
        }
        if let restartControl, let restartEnvelope {
            let response = try await restartControl.committed(current, envelope: restartEnvelope)
            _ = try verifiedScope()
            return response
        }
        if let t10Control { t10Control.state.product = current; try t10Control.persist() }
        if let domainControl { domainControl.state.product = current; try domainControl.persist() }
        if losesFirstCommittedProductResponse, attemptCount == 1 {
            firstProductResponseWasLost = true
            throw URLError(.networkConnectionLost)
        }
        observeProductAttempt?(id, payload, scope, true)
        return current

// TASK145_T19_INSERT_BEGIN rpc-updateProduct-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-updateProduct-end
    }
    func releaseHeldProduct() {
        productContinuation?.resume()
        productContinuation = nil
    }
    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        if Task145PerformanceConfiguration.enabled { return try await performanceRecord(request) }
// TASK145_T19_INSERT_BEGIN rpc-record-begin
        let t19Entry = t19RPC?("record", ["domain": request.domain, "clientEventID": request.clientEventID]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("record", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-record-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-record
        try scopeSwitchIngress?("write:record")
// TASK145_SCOPE_SWITCH_INSERT_END raw-record
        try t10Control?.noteIngress("event")
        try isolationControl?.eventEntry(request)
        try observeRawEventEntry?()
        let scope = try verifiedScope()
        if let domainControl { try domainControl.noteRPCEntry("events") }
        try SyncEventRecordValidator().validate(request)
        guard !isEmpty, request.shopID == current.shopID, let device = request.sourceDeviceID,
              device == DeviceInstallIDStore().deviceInstallID else { throw Fault.unexpectedCall }
        if let domainControl { try domainControl.observeEvent(request, scope: scope) }
        else if r4Control != nil || t10Control != nil {
            guard ((request.domain == "catalog" && request.eventType == "catalog_changed")
                || (request.domain == "prices" && request.eventType == "prices_changed")), request.changedCount == 1 else { throw Fault.unexpectedCall }
        } else {
            guard request.domain == "catalog", request.eventType == "catalog_changed", request.changedCount == 1 else { throw Fault.unexpectedCall }
        }
        if observeProductAttempt != nil, eventRequestObservations.count >= 8 { eventObservationCapped = true }
        if observeProductAttempt != nil, eventRequestObservations.count < 8 {
            eventRequestKeys.append(request.clientEventID)
            eventRequests.append(request)
            eventRequestObservations.append("key.\(LocalPendingChangeLogicalKey.privacyHash(request.clientEventID)).replayed.\(eventClientIDs[request.clientEventID] != nil)")
        }
        if let saveBControl { try saveBControl.observeEventRequest(request) }
        try isolationControl?.acceptEvent(request, initial: current)
        if let restartControl { try restartControl.observeEvent(request) }
        if let event = eventClientIDs[request.clientEventID] { return .recorded(event) }
        guard events.count < (r4Control != nil || t10Control != nil ? 2 : domainControl != nil ? 3 : (allowsRelatedSave ? 3 : (saveBControl == nil ? 1 : 2))) else { throw Fault.unexpectedCall }
        eventCount += 1
        let payload: [String: Any] = ["id": String(41 + eventCount), "owner_user_id": current.ownerUserID.uuidString,
            "shop_id": current.shopID!.uuidString, "domain": request.domain, "event_type": request.eventType,
            "source": request.source ?? "ios", "source_device_key": ShopSyncRecoveryCanonical.sha256(device),
            "client_event_key": ShopSyncRecoveryCanonical.sha256(request.clientEventID), "changed_count": request.changedCount,
            "entity_ids": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.entityIDs)),
            "metadata": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.metadata)),
            "requires_full_recovery": false, "created_at": "2026-07-21T12:01:00Z"]
        let recorded = try JSONDecoder().decode(RemoteSyncEventRow.self,
            from: JSONSerialization.data(withJSONObject: payload))
        events.append(recorded); eventClientIDs[request.clientEventID] = recorded
        if let t10Control {
            t10Control.state.events = events; t10Control.state.eventClientIDs = eventClientIDs
            try t10Control.persist()
        }
        if let r4Control {
            r4Control.state.events = events; r4Control.state.eventClientIDs = eventClientIDs
            try r4Control.persist()
        }
        if let saveBControl {
            saveBControl.state.events = events
            saveBControl.state.eventClientIDs = eventClientIDs
            guard let acknowledged = saveBControl.state.returned.last,
                  !saveBControl.state.eventChangeIDs.values.contains(acknowledged) else {
                throw Fault.unexpectedCall
            }
            saveBControl.state.eventRequests[request.clientEventID] = Task145SaveBControl.eventIdentity(request)
            saveBControl.state.eventChangeIDs[request.clientEventID] = acknowledged
            try saveBControl.persist()
        }
        if let restartControl {
            restartControl.state.events = events
            restartControl.state.eventClientIDs = eventClientIDs
            try restartControl.persist()
        }
        if let domainControl {
            domainControl.state.events = events; domainControl.state.eventClientIDs = eventClientIDs
            try domainControl.persist()
        }
        if let isolationControl {
            isolationControl.state.events = events; isolationControl.state.eventClients = eventClientIDs
            try isolationControl.persist()
        }
        return .recorded(recorded)

// TASK145_T19_INSERT_BEGIN rpc-record-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-record-end
    }

    func prepareSeq6Event(missingIDs: Bool) throws {
        guard events.isEmpty, eventCount == 0, attemptCount == 0 else { throw Fault.unexpectedCall }
        if !missingIDs { moveSeq6Snapshot(version: 1, name: "Seq6 remote incremental product") }
        let ids: Any = missingIDs ? NSNull() : ["supplier_ids": [], "category_ids": [], "product_ids": [current.id.uuidString.lowercased()]]
        let payload: [String: Any] = ["id": "42", "owner_user_id": current.ownerUserID.uuidString,
            "shop_id": current.shopID!.uuidString, "domain": "catalog", "event_type": "catalog_changed",
            "source": "seq6-controlled-peer", "source_device_key": ShopSyncRecoveryCanonical.sha256("seq6-other-device"),
            "client_event_key": ShopSyncRecoveryCanonical.sha256("seq6-remote-event-42"), "changed_count": 1,
            "entity_ids": ids, "metadata": [:], "requires_full_recovery": false,
            "created_at": "2026-07-21T12:01:01Z"]
        events = [try JSONDecoder().decode(RemoteSyncEventRow.self, from: JSONSerialization.data(withJSONObject: payload))]
    }
    func moveSeq6Snapshot(version: Int, name: String) {
        let previous = current
        current = RemoteInventoryProductRow(id: previous.id, ownerUserID: previous.ownerUserID,
            shopID: previous.shopID, barcode: previous.barcode, itemNumber: previous.itemNumber,
            productName: name, secondProductName: previous.secondProductName, purchasePrice: previous.purchasePrice,
            retailPrice: previous.retailPrice, supplierID: previous.supplierID, categoryID: previous.categoryID,
            stockQuantity: previous.stockQuantity,
            updatedAt: String(format: "2026-07-21T12:02:%02d.000000Z", version), deletedAt: previous.deletedAt)
    }

    private func verifiedScope() throws -> Task126VerifiedOwnerStoreScope {
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: current.ownerUserID)
        guard scope.shopID == current.shopID else { throw Task126OwnerStoreGateError.scopeChanged }
        try authoritativeScope.validate(expectedShopID: scope.shopID,
            expectedDeviceIdentifier: scope.deviceInstallID, expectedOwnerUserID: scope.ownerUserID)
        let watermark = WatermarkStore().watermark(for: .init(ownerUserID: scope.ownerUserID,
            storeIdentity: scope.storeIdentity))
        guard ShopSyncRecoveryFenceStore().scopeKey(accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity, deviceIdentityHash: scope.deviceIdentityHash,
            watermark: watermark) == authoritativeScope.key else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        return scope
    }

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
// TASK145_T19_INSERT_BEGIN rpc-fetchSyncEventsAfter-begin
        let t19Entry = t19RPC?("fetchSyncEventsAfter", ["afterID": afterID, "limit": limit]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("fetchSyncEventsAfter", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-fetchSyncEventsAfter-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-fetchSyncEventsAfter
        try scopeSwitchIngress?("read:fetchSyncEventsAfter")
// TASK145_SCOPE_SWITCH_INSERT_END raw-fetchSyncEventsAfter
        if let seq6Control, seq6Control.armed { try seq6Control.note("event-read", ["after": String(afterID), "limit": String(limit)]) }
        try isolationControl?.raw("read:events", identity: String(afterID))
        _ = try verifiedScope()
        if let seq6Control, seq6Control.armed, seq6Control.state.scenario == .invalidCursor {
            // A lower authoritative as-of bound is a true contract rejection;
            // derive the typed error through the production cursor validator.
            try ShopSyncEventPageCursorContract.validate(rows: [], afterID: afterID,
                asOfEventMaxID: 40, nextAfterID: nil, hasMore: false)
            throw Fault.unexpectedCall
        }
        guard ownerUserID == current.ownerUserID, afterID >= 41, limit > 0 else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        return Array((events + t19AdditionalEvents).filter { $0.id > afterID }.prefix(limit))

// TASK145_T19_INSERT_BEGIN rpc-fetchSyncEventsAfter-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-fetchSyncEventsAfter-end
    }
    func fetchCatalogByIDs(supplierIDs: Set<UUID>, categoryIDs: Set<UUID>, productIDs: Set<UUID>) async throws -> (
        suppliers: [RemoteInventorySupplierRow], categories: [RemoteInventoryCategoryRow], products: [RemoteInventoryProductRow]
    ) {
        if Task145PerformanceConfiguration.enabled { return try await performanceFetchCatalogByIDs(supplierIDs: supplierIDs, categoryIDs: categoryIDs, productIDs: productIDs) }
// TASK145_T19_INSERT_BEGIN rpc-fetchCatalogByIDs-begin
        let t19Entry = t19RPC?("fetchCatalogByIDs", ["products": productIDs.map(\.uuidString).sorted(), "suppliers": supplierIDs.count, "categories": categoryIDs.count]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("fetchCatalogByIDs", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-fetchCatalogByIDs-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-fetchCatalogByIDs
        try scopeSwitchIngress?("read:fetchCatalogByIDs")
// TASK145_SCOPE_SWITCH_INSERT_END raw-fetchCatalogByIDs
        _ = try verifiedScope()
        if let isolationControl {
            try isolationControl.raw("read:catalog", identity: productIDs.map(\.uuidString).sorted().joined(separator: ","))
            let rows = [current] + (isolationControl.state.remoteProduct.map { [$0] } ?? [])
            guard supplierIDs.isEmpty, categoryIDs.isEmpty, productIDs.isSubset(of: Set(rows.map(\.id))) else { throw Fault.unexpectedCall }
            return ([], [], rows.filter { productIDs.contains($0.id) })
        }
        guard (supplierIDs.isEmpty || (allowsRelatedSave && supplierIDs == Set(supplier.map { [$0.id] } ?? []))),
              (categoryIDs.isEmpty || (allowsRelatedSave && categoryIDs == Set(category.map { [$0.id] } ?? []))),
              productIDs.isEmpty || (!isEmpty && productIDs == Set([current.id])) else {
            throw Fault.unexpectedCall
        }
        return (supplierIDs.isEmpty ? [] : supplier.map { [$0] } ?? [],
                categoryIDs.isEmpty ? [] : category.map { [$0] } ?? [], productIDs.isEmpty ? [] : [current])

// TASK145_T19_INSERT_BEGIN rpc-fetchCatalogByIDs-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-fetchCatalogByIDs-end
    }
    func advanceDurableFence(ownerUserID: UUID, scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64, through newWatermark: Int64) async throws {
        if Task145PerformanceConfiguration.enabled { return try await performanceAdvanceDurableFence(ownerUserID: ownerUserID, scope: scope, from: watermark, through: newWatermark) }
// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-advanceDurableFence
        try scopeSwitchIngress?("fence:advanceDurableFence")
// TASK145_SCOPE_SWITCH_INSERT_END raw-advanceDurableFence
        if let seq6Control, seq6Control.armed {
            try seq6Control.note("fence-advance", ["before": String(watermark), "after": String(newWatermark)])
        }
        let captured = try verifiedScope()
        guard scope == captured, ownerUserID == current.ownerUserID,
              newWatermark > watermark, newWatermark <= 44,
              (events + t19AdditionalEvents).filter({ $0.id > watermark && $0.id <= newWatermark }).map(\.id)
                == Array((watermark + 1)...newWatermark) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        guard ShopSyncRecoveryFenceStore().saveAuthoritative(scope: authoritativeScope,
            watermark: newWatermark, accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
    }
    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        if Task145PerformanceConfiguration.enabled { return try await performanceInsertProductPrices(payloads) }
// TASK145_T19_INSERT_BEGIN rpc-insertProductPrices-begin
        let t19Entry = t19RPC?("insertProductPrices", ["count": payloads.count]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("insertProductPrices", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-insertProductPrices-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-insertProductPrices
        try scopeSwitchIngress?("write:insertProductPrices")
// TASK145_SCOPE_SWITCH_INSERT_END raw-insertProductPrices
        try t10Control?.noteIngress("price")
        try r4Control?.notePriceEntry()
        let scope = try verifiedScope()
        if let t10Control { return try t10Control.insertPrices(payloads, scope: scope) }
        if let r4Control { return try r4Control.insertPrices(payloads, scope: scope) }
        guard let domainControl else { throw Fault.unexpectedCall }
        try domainControl.noteRPCEntry("prices")
        let rows = try await domainControl.insertPrices(payloads, scope: scope)
        _ = try verifiedScope()
        return rows

// TASK145_T19_INSERT_BEGIN rpc-insertProductPrices-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-insertProductPrices-end
    }
    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        if Task145PerformanceConfiguration.enabled { return try await performanceFetchReconciliationRemoteCounts() }
// TASK145_T19_INSERT_BEGIN rpc-fetchReconciliationRemoteCounts-begin
        let t19Entry = t19RPC?("fetchReconciliationRemoteCounts", [:]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("fetchReconciliationRemoteCounts", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-fetchReconciliationRemoteCounts-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-fetchReconciliationRemoteCounts
        try scopeSwitchIngress?("read:fetchReconciliationRemoteCounts")
// TASK145_SCOPE_SWITCH_INSERT_END raw-fetchReconciliationRemoteCounts
        _ = try verifiedScope()
        if let isolationControl {
            try isolationControl.raw("read:counts", identity: "scoped")
            return .init(products: isolationControl.state.remoteProduct == nil ? 1 : 2, suppliers: 0, categories: 0, productPrices: 0, historySessions: 0)
        }
        if ProcessInfo.processInfo.environment["TASK145_DRAFT_REVIEW_UI"] == "deleted-rebind", current.deletedAt != nil {
            return .init(products: 0, suppliers: 0, categories: 0, productPrices: 0, historySessions: 0)
        }
        return .init(products: interruptionControl?.isSeed == false ? 2 : (isEmpty ? 0 : 1), suppliers: supplier == nil ? 0 : 1,
            categories: category == nil ? 0 : 1, productPrices: t10Control?.state.prices.count ?? r4Control?.state.prices.count ?? domainControl?.state.prices.count ?? 0, historySessions: domainControl?.state.history.count ?? 0)

// TASK145_T19_INSERT_BEGIN rpc-fetchReconciliationRemoteCounts-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-fetchReconciliationRemoteCounts-end
    }
    func fetchProductPricesByIDs(ownerUserID: UUID, priceIDs: Set<UUID>) async throws -> [RemoteInventoryProductPriceRow] {
        if Task145PerformanceConfiguration.enabled { return try await performanceFetchProductPricesByIDs(ownerUserID: ownerUserID, priceIDs: priceIDs) }
// TASK145_T19_INSERT_BEGIN rpc-fetchProductPricesByIDs-begin
        let t19Entry = t19RPC?("fetchProductPricesByIDs", ["count": priceIDs.count]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("fetchProductPricesByIDs", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-fetchProductPricesByIDs-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-fetchProductPricesByIDs
        try scopeSwitchIngress?("read:fetchProductPricesByIDs")
// TASK145_SCOPE_SWITCH_INSERT_END raw-fetchProductPricesByIDs
        _ = try verifiedScope()
        if let t10Control {
            guard ownerUserID == current.ownerUserID, priceIDs.isSubset(of: Set(t10Control.state.prices.map(\.id))) else { throw Fault.unexpectedCall }
            return t10Control.state.prices.filter { priceIDs.contains($0.id) }
        }
        if let r4Control {
            guard ownerUserID == current.ownerUserID, priceIDs.isSubset(of: Set(r4Control.state.prices.map(\.id))) else { throw Fault.unexpectedCall }
            return r4Control.state.prices.filter { priceIDs.contains($0.id) }
        }
        if let domainControl {
            guard ownerUserID == current.ownerUserID, priceIDs.isSubset(of: Set(domainControl.state.prices.map(\.id))) else { throw Fault.unexpectedCall }
            return domainControl.state.prices.filter { priceIDs.contains($0.id) }
        }
        guard ownerUserID == current.ownerUserID, priceIDs.isEmpty else { throw Fault.unexpectedCall }
        return []

// TASK145_T19_INSERT_BEGIN rpc-fetchProductPricesByIDs-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-fetchProductPricesByIDs-end
    }
    private func performanceUpdateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        let scope = try verifiedScope()
        guard !isEmpty, id == current.id else { throw Fault.unexpectedCall }
        attemptCount += 1
        var performanceSucceeded = false
        defer { performanceTransport?.finishRequest(success: performanceSucceeded) }
        if let performanceTransport { try await performanceTransport.waitForBusinessRelease() }
        observeProductAttempt?(id, payload, scope, false)
        if allowsRelatedSave {
            isProductHeld = true
            await withCheckedContinuation { productContinuation = $0 }
            isProductHeld = false
            try Task.checkCancellation()
            _ = try verifiedScope()
        }
        current = RemoteInventoryProductRow(id: id, ownerUserID: current.ownerUserID, shopID: current.shopID,
            barcode: payload.barcode ?? current.barcode, itemNumber: payload.itemNumber ?? current.itemNumber,
            productName: payload.productName ?? current.productName, secondProductName: payload.secondProductName ?? current.secondProductName,
            purchasePrice: payload.purchasePrice ?? current.purchasePrice, retailPrice: payload.retailPrice ?? current.retailPrice,
            supplierID: payload.supplierID ?? current.supplierID, categoryID: payload.categoryID ?? current.categoryID,
            stockQuantity: payload.stockQuantity ?? current.stockQuantity, updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: payload.deletedAt)
        if losesFirstCommittedProductResponse, attemptCount == 1 {
            firstProductResponseWasLost = true
            throw URLError(.networkConnectionLost)
        }
        try await persistPerformanceServer()
        try performanceTransport?.validateRequestDeadline()
        performanceSucceeded = true
        observeProductAttempt?(id, payload, scope, true)
        return current
    }
    private func performanceRecord(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        _ = try verifiedScope()
        try performanceTransport?.beginRequest("activity-registration")
        var performanceSucceeded = false
        defer { performanceTransport?.finishRequest(success: performanceSucceeded) }
        try SyncEventRecordValidator().validate(request)
        guard !isEmpty,
              (Task145PerformanceConfiguration.enabled ? ["catalog", "prices"].contains(request.domain) : request.domain == "catalog"),
              (Task145PerformanceConfiguration.enabled || request.eventType == "catalog_changed"), (Task145PerformanceConfiguration.enabled ? request.changedCount > 0 : request.changedCount == 1),
              request.shopID == current.shopID, let device = request.sourceDeviceID,
              device == DeviceInstallIDStore().deviceInstallID else { throw Fault.unexpectedCall }
        if observeProductAttempt != nil, eventRequestObservations.count >= 8 { eventObservationCapped = true }
        if observeProductAttempt != nil, eventRequestObservations.count < 8 {
            eventRequestKeys.append(request.clientEventID)
            eventRequests.append(request)
            eventRequestObservations.append("key.\(LocalPendingChangeLogicalKey.privacyHash(request.clientEventID)).replayed.\(eventClientIDs[request.clientEventID] != nil)")
        }
        if let event = eventClientIDs[request.clientEventID] { performanceSucceeded = true; return .recorded(event) }
        guard events.count < (Task145PerformanceConfiguration.enabled ? 128 : (allowsRelatedSave ? 3 : 1)) else { throw Fault.unexpectedCall }
        eventCount += 1
        let payload: [String: Any] = ["id": String(41 + eventCount), "owner_user_id": current.ownerUserID.uuidString,
            "shop_id": current.shopID!.uuidString, "domain": request.domain, "event_type": request.eventType,
            "source": request.source ?? "ios", "source_device_key": ShopSyncRecoveryCanonical.sha256(device),
            "client_event_key": ShopSyncRecoveryCanonical.sha256(request.clientEventID), "changed_count": request.changedCount,
            "entity_ids": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.entityIDs)),
            "metadata": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.metadata)),
            "requires_full_recovery": false, "created_at": "2026-07-21T12:01:00Z"]
        let recorded = try JSONDecoder().decode(RemoteSyncEventRow.self,
            from: JSONSerialization.data(withJSONObject: payload))
        events.append(recorded); eventClientIDs[request.clientEventID] = recorded
        try await persistPerformanceServer()
        try performanceTransport?.validateRequestDeadline()
        performanceSucceeded = true
        return .recorded(recorded)
    }
    private func performanceFetchCatalogByIDs(supplierIDs: Set<UUID>, categoryIDs: Set<UUID>, productIDs: Set<UUID>) async throws -> (
        suppliers: [RemoteInventorySupplierRow], categories: [RemoteInventoryCategoryRow], products: [RemoteInventoryProductRow]
    ) {
        _ = try verifiedScope()
        if Task145PerformanceConfiguration.enabled {
            let suppliers = performanceSuppliers.filter { supplierIDs.contains($0.id) }
            let categories = performanceCategories.filter { categoryIDs.contains($0.id) }
            guard suppliers.count == supplierIDs.count, categories.count == categoryIDs.count,
                  productIDs.isEmpty || productIDs == Set([current.id]) else { throw Fault.unexpectedCall }
            return (suppliers, categories, productIDs.isEmpty ? [] : [current])
        }
        guard (supplierIDs.isEmpty || (allowsRelatedSave && supplierIDs == Set(supplier.map { [$0.id] } ?? []))),
              (categoryIDs.isEmpty || (allowsRelatedSave && categoryIDs == Set(category.map { [$0.id] } ?? []))),
              productIDs.isEmpty || (!isEmpty && productIDs == Set([current.id])) else {
            throw Fault.unexpectedCall
        }
        return (supplierIDs.isEmpty ? [] : supplier.map { [$0] } ?? [],
                categoryIDs.isEmpty ? [] : category.map { [$0] } ?? [], productIDs.isEmpty ? [] : [current])
    }
    private func performanceAdvanceDurableFence(ownerUserID: UUID, scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64, through newWatermark: Int64) async throws {
        let captured = try verifiedScope()
        guard scope == captured, ownerUserID == current.ownerUserID,
              newWatermark > watermark, newWatermark <= (Task145PerformanceConfiguration.enabled ? Int64(41 + events.count) : 44),
              events.filter({ $0.id > watermark && $0.id <= newWatermark }).map(\.id)
                == Array((watermark + 1)...newWatermark) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        guard ShopSyncRecoveryFenceStore().saveAuthoritative(scope: authoritativeScope,
            watermark: newWatermark, accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
    }
    private func performanceInsertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        _ = try verifiedScope()
        guard Task145PerformanceConfiguration.enabled, !payloads.isEmpty else { throw Fault.unexpectedCall }
        try performanceTransport?.beginRequest("price-insert")
        var succeeded = false; defer { performanceTransport?.finishRequest(success: succeeded) }
        var result: [RemoteInventoryProductPriceRow] = []
        for payload in payloads {
            guard payload.ownerUserID == current.ownerUserID, payload.shopID == current.shopID,
                  payload.productID == current.id, payload.price.isFinite,
                  payload.price == payload.price.rounded(), payload.price > 0, payload.price < 10_000 else { throw Fault.unexpectedCall }
            if let old = performancePrices.first(where: { $0.id == payload.id }) {
                guard old.productID == payload.productID, old.type == payload.type, old.price == payload.price,
                      old.effectiveAt == payload.effectiveAt, old.source == payload.source, old.note == payload.note else { throw Fault.unexpectedCall }
                result.append(old); continue
            }
            let row = RemoteInventoryProductPriceRow(id: payload.id, ownerUserID: payload.ownerUserID, shopID: payload.shopID,
                productID: payload.productID, type: payload.type, price: payload.price, priceCanonical: String(Int(payload.price)),
                effectiveAt: payload.effectiveAt, source: payload.source, note: payload.note, createdAt: payload.createdAt,
                updatedAt: "2026-10-23T12:00:00.000000Z")
            performancePrices.append(row); result.append(row)
        }
        try await persistPerformanceServer(); try performanceTransport?.validateRequestDeadline()
        succeeded = true; return result
    }
    private func performanceFetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        _ = try verifiedScope()
        if Task145PerformanceConfiguration.enabled {
            return .init(products: 20_000, suppliers: 2, categories: 2, productPrices: 40_000 + performancePrices.count, historySessions: 0)
        }
        return .init(products: isEmpty ? 0 : 1, suppliers: supplier == nil ? 0 : 1,
            categories: category == nil ? 0 : 1, productPrices: 0, historySessions: 0)
    }
    private func performanceFetchProductPricesByIDs(ownerUserID: UUID, priceIDs: Set<UUID>) async throws -> [RemoteInventoryProductPriceRow] {
        _ = try verifiedScope()
        guard ownerUserID == current.ownerUserID else { throw Fault.unexpectedCall }
        if Task145PerformanceConfiguration.enabled {
            let rows = performancePrices.filter { priceIDs.contains($0.id) }
            guard rows.count == priceIDs.count else { throw Fault.unexpectedCall }; return rows
        }
        guard priceIDs.isEmpty else { throw Fault.unexpectedCall }; return []
    }

    func upsertSharedSheetSessions(_ rows: [SharedSheetSessionUpsertRow], ownerUserID: UUID) async throws -> [RemoteSharedSheetSessionRow] {
// TASK145_T19_INSERT_BEGIN rpc-upsertSharedSheetSessions-begin
        let t19Entry = t19RPC?("upsertSharedSheetSessions", ["count": rows.count]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("upsertSharedSheetSessions", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-upsertSharedSheetSessions-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-upsertSharedSheetSessions
        try scopeSwitchIngress?("write:upsertSharedSheetSessions")
// TASK145_SCOPE_SWITCH_INSERT_END raw-upsertSharedSheetSessions
        let scope = try verifiedScope()
        guard let domainControl, ownerUserID == scope.ownerUserID else { throw Fault.unexpectedCall }
        try domainControl.noteRPCEntry("history")
        let result = try await domainControl.upsertHistory(rows, scope: scope)
        _ = try verifiedScope()
        return result

// TASK145_T19_INSERT_BEGIN rpc-upsertSharedSheetSessions-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-upsertSharedSheetSessions-end
    }
    func fetchSharedSheetSessionsPage(ownerUserID: UUID, from: Int, to: Int) async throws -> [RemoteSharedSheetSessionRow] {
// TASK145_T19_INSERT_BEGIN rpc-fetchSharedSheetSessionsPage-begin
        let t19Entry = t19RPC?("fetchSharedSheetSessionsPage", ["from": from, "to": to]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("fetchSharedSheetSessionsPage", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-fetchSharedSheetSessionsPage-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-fetchSharedSheetSessionsPage
        try scopeSwitchIngress?("read:fetchSharedSheetSessionsPage")
// TASK145_SCOPE_SWITCH_INSERT_END raw-fetchSharedSheetSessionsPage
        _ = try verifiedScope()
        guard ownerUserID == current.ownerUserID else { throw Fault.unexpectedCall }
        if let domainControl {
            guard from >= 0, to >= from, to - from < 250 else { throw Fault.unexpectedCall }
            return Array(domainControl.state.history.dropFirst(from).prefix(to - from + 1))
        }
        return []

// TASK145_T19_INSERT_BEGIN rpc-fetchSharedSheetSessionsPage-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-fetchSharedSheetSessionsPage-end
    }
    func fetchSharedSheetSessionsByIDs(ownerUserID: UUID, sessionIDs: Set<UUID>) async throws -> [RemoteSharedSheetSessionRow] {
// TASK145_T19_INSERT_BEGIN rpc-fetchSharedSheetSessionsByIDs-begin
        let t19Entry = t19RPC?("fetchSharedSheetSessionsByIDs", ["count": sessionIDs.count]) ?? 0
        var t19Error: String?
        defer { t19RPCComplete?("fetchSharedSheetSessionsByIDs", t19Entry, t19Error) }
        do {
// TASK145_T19_INSERT_END rpc-fetchSharedSheetSessionsByIDs-begin

// TASK145_SCOPE_SWITCH_INSERT_BEGIN raw-fetchSharedSheetSessionsByIDs
        try scopeSwitchIngress?("read:fetchSharedSheetSessionsByIDs")
// TASK145_SCOPE_SWITCH_INSERT_END raw-fetchSharedSheetSessionsByIDs
        _ = try verifiedScope()
        if let domainControl {
            guard ownerUserID == current.ownerUserID, sessionIDs.isSubset(of: Set(domainControl.state.history.map(\.remoteID))) else { throw Fault.unexpectedCall }
            return domainControl.state.history.filter { sessionIDs.contains($0.remoteID) }
        }
        guard ownerUserID == current.ownerUserID, sessionIDs.isEmpty else { throw Fault.unexpectedCall }
        return []

// TASK145_T19_INSERT_BEGIN rpc-fetchSharedSheetSessionsByIDs-end
        } catch { t19Error = String(reflecting: type(of: error)); throw error }
// TASK145_T19_INSERT_END rpc-fetchSharedSheetSessionsByIDs-end
    }
}

/// One opt-in native mixed transient profile. This stores only observations and a bounded
/// transport fault count; it neither owns retry admission nor edits its clock,
/// budget, journal, identity, business queue or production retry metadata.
// Seq6 transports and observations are confined to the existing DEBUG fixture.
// None of these facts grants runtime admission or manufactures a SyncState.
@MainActor
private final class Task145Seq6Control {
    enum Scenario: String, Codable {
        case membershipRefusal = "membership-refusal"
        case corruptBody = "corrupt-body"
        case healthyIncremental = "healthy-incremental"
        case missingEntityGap = "missing-entity-gap"
        case invalidCursor = "invalid-cursor"
        case snapshotChanged = "snapshot-changed"
        var isSafety: Bool { self == .membershipRefusal || self == .corruptBody }
    }
    struct Observation: Codable {
        let kind: String
        let utc: Double
        let uptime: Double
        let pid: Int32
        let values: [String: String]
    }
    struct State: Codable {
        let schema: Int
        let runID: UUID
        let scenario: Scenario
        let firstPID: Int32
        var facts: [String: String] = [:]
        var entries: [Observation] = []
    }
    var state: State
    var armed = false
    var actionStarted = false
    var terminal = false
    var capturedScope: Task126VerifiedOwnerStoreScope?
    let reopening: Bool
    private let url: URL

    static func validateInitialAdmission(root: URL, runID: UUID, scenario: Scenario,
        owner: UUID, shop: UUID) throws {
        let manager = FileManager.default
        let observationURL = root.appendingPathComponent("seq6-observation-v1.json")
        guard manager.fileExists(atPath: observationURL.path) else {
            // An existing root is evidence, not permission to seed a replacement.
            guard !manager.fileExists(atPath: root.path) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            return
        }
        let observationBytes = try Data(contentsOf: observationURL)
        guard observationBytes.count <= 131_072 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let prior = try JSONDecoder().decode(State.self, from: observationBytes)
        guard prior.schema == 1, prior.runID == runID, prior.scenario == scenario,
              prior.entries.count <= 128, scenario == .corruptBody,
              prior.facts["corruption-persisted"] == "true" else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        // Match the canonical manifest already observed from the qualified generation.
        // Missing or changed evidence must throw; this admission never restores authority.
        let manifestBytes = try Data(contentsOf: root.appendingPathComponent("generation-root/active-generation.json"))
        guard manifestBytes.count <= ShopSyncRecoveryLimits.maximumGenerationManifestBytes else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let manifest = try JSONDecoder().decode(SyncStoreGenerationManifest.self, from: manifestBytes)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let manifestHash = ShopSyncRecoveryCanonical.sha256(String(decoding: try encoder.encode(manifest), as: UTF8.self))
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let bindingStore = AccountBindingStore(durableJournalURL: root.appendingPathComponent("generation-root/recovery-journal.json"))
        guard manifest.schemaVersion == SyncStoreGenerationManifest.currentSchemaVersion,
              manifest.accountHash == accountHash, manifest.shopID == shop,
              prior.facts["initial-generation"] == manifest.generationID.uuidString,
              prior.facts["initial-manifest"] == manifestHash,
              prior.facts["owner"] == owner.uuidString, prior.facts["account-hash"] == accountHash,
              prior.facts["shop"] == shop.uuidString, prior.facts["store"] == manifest.storeIdentity.rawValue,
              prior.facts["device-hash"] == manifest.deviceIdentityHash,
              SelectedShopStore().selectedShop(accountHash: accountHash)?.shopID == shop,
              bindingStore.currentBinding?.accountHash == accountHash,
              bindingStore.currentBinding?.storeIdentity == manifest.storeIdentity,
              !bindingStore.hasPendingReplacementJournal else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }

    init(runID: UUID, scenario: Scenario, url: URL, reopening: Bool) throws {
        self.url = url; self.reopening = reopening
        if reopening {
            let bytes = try Data(contentsOf: url)
            guard bytes.count <= 131_072 else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = try JSONDecoder().decode(State.self, from: bytes)
            guard state.schema == 1, state.runID == runID, state.scenario == scenario,
                  scenario == .corruptBody, state.facts["corruption-persisted"] == "true" else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        } else {
            guard !FileManager.default.fileExists(atPath: url.path) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            state = State(schema: 1, runID: runID, scenario: scenario,
                firstPID: ProcessInfo.processInfo.processIdentifier)
            try persist()
        }
    }
    func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        guard state.entries.count <= 128, data.count <= 131_072 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        do { try handle.synchronize(); try handle.close() }
        catch { try? handle.close(); throw error }
        guard try Data(contentsOf: url) == data else { throw SyncStoreGenerationError.activationReadBackFailed }
    }
    func note(_ kind: String, _ values: [String: String] = [:]) throws {
        state.entries.append(.init(kind: kind, utc: Date().timeIntervalSince1970,
            uptime: ProcessInfo.processInfo.systemUptime, pid: ProcessInfo.processInfo.processIdentifier, values: values))
        try persist()
    }
    func count(_ kind: String) -> Int { state.entries.filter { $0.kind == kind }.count }
    func summary(_ value: SyncIncrementalPullSummary) throws {
        try note("incremental-summary", ["before": String(value.watermarkBefore), "after": String(value.watermarkAfter),
            "fetched": String(value.eventsFetched), "processed": String(value.eventsProcessed),
            "applied": String(value.totalApplied), "requires-recovery": String(value.requiresFullRecovery),
            "reason": value.requiresFullRecoveryReason ?? "none", "verified": String(value.verifiedConvergence)])
    }
    var readback: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return "task145.seq6.ledger-encoding-failed" }
        return "task145.seq6.ledger." + data.base64EncodedString()
    }
}

@MainActor
private final class Task145Seq6ObservedIncrementalProvider: SyncIncrementalPullProviding {
    let base: SyncEventIncrementalPullService
    let control: Task145Seq6Control
    init(base: SyncEventIncrementalPullService, control: Task145Seq6Control) {
        self.base = base; self.control = control
    }
    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        try await applyIncrementalRemoteChanges(ownerUserID: ownerUserID, forceLightReconcile: false)
    }
    func applyIncrementalRemoteChanges(ownerUserID: UUID, forceLightReconcile: Bool) async throws -> SyncIncrementalPullSummary {
        let result = try await base.applyIncrementalRemoteChanges(ownerUserID: ownerUserID,
            forceLightReconcile: forceLightReconcile)
        try control.summary(result)
        return result
    }
}

@MainActor
private final class Task145RetryControl {
    static let savedName = "Saved during real recovery cooldown"
    nonisolated struct Attempt: Codable {
        let schemaVersion: Int
        let identity: String
        let invocationID: UUID
        let windowIndex: Int
        let attemptsInWindow: Int
        let totalAttempts: Int
        let lastAttemptAt: TimeInterval
        let lastCompletedAt: TimeInterval?
        let failure: AutomaticSyncFailure?
        let nextAllowedAt: TimeInterval
        let retryAfterUntil: TimeInterval?
    }
    nonisolated struct Entry: Codable {
        let utc: TimeInterval
        let uptime: TimeInterval
        let pid: Int32
        let budgetBytes: Data
        let journalIdentity: String
        let journalPhase: String
        var thrownFailure: AutomaticSyncFailure?
        var failureUTC: TimeInterval?
        var failureUptime: TimeInterval?
    }
    nonisolated struct Completion: Codable {
        let budgetBytes: Data
        let observedUTC: TimeInterval
        let observedUptime: TimeInterval
        let busy: Bool
    }
    nonisolated struct ResultObservation: Codable {
        let budgetBytes: Data
        let action: String
        let status: String
        let failure: AutomaticSyncFailure?
        let verified: Bool
    }
    nonisolated struct ReadEntry: Codable {
        let kind: String
        let budgetBytes: Data
        let utc: TimeInterval
    }
    nonisolated struct State: Codable {
        let runID: UUID
        let firstPID: Int32
        var generationID: UUID?
        var journalIdentity: String?
        var entries: [Entry] = []
        var reads: [ReadEntry] = []
        var completions: [Completion] = []
        var results: [ResultObservation] = []
        var savedToken: LocalPendingChangeCASToken?
        var savedBudgetBytes: Data?
        var ownACKBeforeRecovery = false
        var productEntries = 0
        var eventEntries = 0
        var terminalGeneration: UUID?
    }
    var state: State
    var isArmed = false
    let reopening: Bool
    var qualifiedReopen: Data?
    private let url: URL
    private var key: String { "task144.controlled.\(state.runID.uuidString.lowercased()).automaticRecoveryAttempt.v2" }

    init(runID: UUID, url: URL, reopening: Bool) throws {
        self.url = url; self.reopening = reopening
        if reopening {
            let bytes = try Data(contentsOf: url)
            guard bytes.count <= 65_536 else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = try JSONDecoder().decode(State.self, from: bytes)
            guard state.runID == runID, state.firstPID != ProcessInfo.processInfo.processIdentifier,
                  state.generationID != nil, state.journalIdentity != nil,
                  state.entries.count == 3, state.completions.count == 3, state.results.count == 3,
                  state.reads.isEmpty,
                  state.savedToken != nil, state.savedBudgetBytes != nil,
                  state.productEntries == 0, state.eventEntries == 0, state.terminalGeneration == nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        } else {
            guard !FileManager.default.fileExists(atPath: url.path) else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = State(runID: runID, firstPID: ProcessInfo.processInfo.processIdentifier)
            try persist()
        }
    }
    func currentBudget() throws -> Data {
        guard let bytes = UserDefaults.standard.data(forKey: key), bytes.count <= 8_192 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return bytes
    }
    func decode(_ bytes: Data) throws -> Attempt { try JSONDecoder().decode(Attempt.self, from: bytes) }
    func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(state)
        guard bytes.count <= 65_536, state.entries.count <= 12, state.reads.count <= 32, state.completions.count <= 5,
              state.results.count <= 5, state.productEntries <= 4, state.eventEntries <= 4 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        var closed = false
        defer { if !closed { try? handle.close() } }
        try handle.synchronize(); try handle.close(); closed = true
        guard try Data(contentsOf: url) == bytes else { throw SyncStoreGenerationError.activationReadBackFailed }
    }
    func checkpoint(journal: AccountRecoveryJournalSnapshot) throws {
        let bytes = try currentBudget()
        let attempt = try decode(bytes)
        let identity = SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal)
        // Retain every checkpoint entry before its validation, including an
        // unexpectedly early or duplicate call. The test owns the oracle.
        state.entries.append(Entry(utc: Date().timeIntervalSince1970,
            uptime: ProcessInfo.processInfo.systemUptime, pid: ProcessInfo.processInfo.processIdentifier,
            budgetBytes: bytes, journalIdentity: identity, journalPhase: journal.phase.rawValue))
        try persist()
        guard attempt.schemaVersion == 2, attempt.identity == state.journalIdentity,
              identity == state.journalIdentity, attempt.lastCompletedAt == nil,
              attempt.totalAttempts <= 6, attempt.totalAttempts > 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if state.entries.count <= 5 {
            guard journal.phase == .prepared, journal.generationID == nil,
                  attempt.totalAttempts == state.entries.count else { throw SyncStoreGenerationError.activationReadBackFailed }
            do {
                switch state.entries.count {
                case 1, 2, 4:
                    let status = state.entries.count == 1 ? 503 : state.entries.count == 2 ? 500 : 429
                    let headers = status == 429 ? ["Retry-After": "12"] : [:]
                    let response = HTTPURLResponse(url: URL(string: "https://task145-retry.example.invalid/checkpoint")!,
                        statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
                    try SupabaseTransportClient.validateRPCResponse(response)
                case 3: throw URLError(.dnsLookupFailed)
                case 5: throw URLError(.timedOut)
                default: throw SyncStoreGenerationError.activationReadBackFailed
                }
            } catch {
                let failure = AutomaticSyncFailure.classify(error)
                guard failure.disposition == .transient else { throw error }
                state.entries[state.entries.count - 1].thrownFailure = failure
                state.entries[state.entries.count - 1].failureUTC = Date().timeIntervalSince1970
                state.entries[state.entries.count - 1].failureUptime = ProcessInfo.processInfo.systemUptime
                try persist()
                throw error // The real adapter/runtime/coordinator classify and schedule this typed error.
            }
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard attempt.totalAttempts == 6 else { throw SyncStoreGenerationError.activationReadBackFailed }
    }
    func observeCompletion(busy: Bool) throws {
        let bytes = try currentBudget()
        let attempt = try decode(bytes)
        guard attempt.lastCompletedAt != nil else { return }
        guard attempt.identity == state.journalIdentity,
              attempt.totalAttempts >= 1, attempt.totalAttempts <= 5,
              state.entries.count >= attempt.totalAttempts,
              attempt.failure == state.entries[attempt.totalAttempts - 1].thrownFailure,
              attempt.failure?.disposition == .transient else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if try state.completions.contains(where: { try decode($0.budgetBytes).invocationID == attempt.invocationID }) { return }
        state.completions.append(.init(budgetBytes: bytes, observedUTC: Date().timeIntervalSince1970,
            observedUptime: ProcessInfo.processInfo.systemUptime, busy: busy))
        try persist()
    }
    func noteResult(_ result: SyncAutomaticRunResult, action: String) throws {
        state.results.append(.init(budgetBytes: try currentBudget(), action: action,
            status: result.status.rawValue, failure: result.failure, verified: result.verifiedConvergence))
        try persist()
    }
    func noteRead(_ kind: String) throws {
        guard isArmed else { return }
        state.reads.append(.init(kind: kind, budgetBytes: try currentBudget(), utc: Date().timeIntervalSince1970))
        try persist()
    }
    func noteProductEntry() throws { state.productEntries += 1; try persist() }
    func noteEventEntry() throws { state.eventEntries += 1; try persist() }
    var readback: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state), data.count <= 65_536 else { return "task145.retry.encoding-failed" }
        return "task145.retry.pid.\(ProcessInfo.processInfo.processIdentifier);task145.retry.ledger.\(data.base64EncodedString())"
            + (qualifiedReopen.map { ";task145.retry.qualified-reopen.\($0.base64EncodedString())" } ?? "")
    }
}

/// Bounded DEBUG-only backend journal for the single same-field Save A/B UI
/// scenario. It lives outside generation-root so app relaunch cannot reseed A.
@MainActor
private final class Task145SaveBControl {
    static let nameA = "Saved before network release"
    static let nameB = "Saved while first ACK is held"
    nonisolated struct EventAttempt: Codable {
        let clientEventID: String
        let requestIdentity: String
    }
    nonisolated struct State: Codable {
        let runID: UUID
        let firstPID: Int32
        var product: RemoteInventoryProductRow
        var firstEnvelope: Data?
        var secondEnvelope: Data?
        var secondSavedToken: LocalPendingChangeCASToken?
        var pendingReopenToken: LocalPendingChangeCASToken?
        var generationID: UUID?
        var requests: [Data] = []
        var committed: [String] = []
        var returned: [String] = []
        var events: [RemoteSyncEventRow] = []
        var eventClientIDs: [String: RemoteSyncEventRow] = [:]
        var eventRequests: [String: String] = [:]
        var eventChangeIDs: [String: String] = [:]
        var eventAttempts: [EventAttempt] = []
    }
    var state: State
    let reopening: Bool
    private let url: URL
    private(set) var aHeld = false
    private(set) var bHeld = false
    var releaseA = false
    var releaseB = false
    var captureEnvelope: ((UUID, SyncAutomaticProductUpdatePayload, Task126VerifiedOwnerStoreScope) throws -> Data)?

    init(runID: UUID, url: URL, initial: RemoteInventoryProductRow, reopening: Bool) throws {
        self.url = url; self.reopening = reopening
        if reopening {
            let bytes = try Data(contentsOf: url)
            guard bytes.count <= 131_072 else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = try JSONDecoder().decode(State.self, from: bytes)
            guard state.runID == runID, state.product.id == initial.id,
                  state.product.ownerUserID == initial.ownerUserID, state.product.shopID == initial.shopID,
                  state.requests.count <= 3, state.events.count <= 2,
                  state.eventAttempts.count <= 4, state.eventRequests.count <= 2, state.eventClientIDs.count <= 2,
                  state.firstEnvelope != nil, state.secondSavedToken != nil,
                  state.pendingReopenToken != nil, state.generationID != nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        } else {
            guard !FileManager.default.fileExists(atPath: url.path) else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = State(runID: runID, firstPID: ProcessInfo.processInfo.processIdentifier, product: initial)
            try persist()
        }
    }

    func token(_ data: Data) throws -> LocalPendingChangeCASToken {
        try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self,
            from: data).pending
    }
    func payload(_ data: Data) throws -> SyncAutomaticProductUpdatePayload {
        try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self,
            from: data).payload.call.updateProduct.payload
    }
    func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(state)
        guard bytes.count <= 131_072, state.requests.count <= 3, state.events.count <= 2,
              state.eventAttempts.count <= 4, state.eventRequests.count <= 2, state.eventClientIDs.count <= 2 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        var closed = false
        defer { if !closed { try? handle.close() } }
        try handle.synchronize()
        try handle.close()
        closed = true
        guard try Data(contentsOf: url) == bytes else { throw SyncStoreGenerationError.activationReadBackFailed }
    }

    func enter(id: UUID, payload: SyncAutomaticProductUpdatePayload, scope: Task126VerifiedOwnerStoreScope) async throws -> Data {
        guard let captureEnvelope, state.requests.count < 3 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let envelope = try captureEnvelope(id, payload, scope)
        let incoming = try token(envelope)
        if state.firstEnvelope == nil {
            guard !reopening, payload.productName == Self.nameA else { throw SyncStoreGenerationError.activationReadBackFailed }
            state.firstEnvelope = envelope
        } else {
            guard let saved = state.secondSavedToken, incoming.changeID == saved.changeID,
                  incoming.idempotencyKey == saved.idempotencyKey,
                  incoming.intendedFingerprintHash == saved.intendedFingerprintHash,
                  payload.productName == Self.nameB,
                  state.secondEnvelope == nil || state.secondEnvelope == envelope else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            state.secondEnvelope = envelope
        }
        state.requests.append(envelope)
        try persist()
        if envelope == state.secondEnvelope {
            bHeld = true
            defer { bHeld = false }
            try await awaitRelease { self.reopening && self.releaseB }
        }
        return envelope
    }

    func committed(_ response: RemoteInventoryProductRow, envelope: Data) async throws {
        let changeID = try token(envelope).changeID
        guard !state.committed.contains(changeID) else { throw SyncStoreGenerationError.activationReadBackFailed }
        state.product = response
        state.committed.append(changeID)
        try persist() // Persist + sync + exact readback before exposing committed.
        if envelope == state.firstEnvelope {
            aHeld = true
            defer { aHeld = false }
            try await awaitRelease { self.releaseA }
        }
        state.returned.append(changeID)
        try persist()
    }

    private func awaitRelease(_ released: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(90))
        while !released() {
            guard ContinuousClock.now < deadline else { throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(50))
        }
        try Task.checkCancellation()
    }

    func observeEventRequest(_ request: SyncEventRecordRequest) throws {
        let identity = Self.eventIdentity(request)
        guard state.eventAttempts.count < 4, identity != "invalid",
              state.eventRequests[request.clientEventID] == nil || state.eventRequests[request.clientEventID] == identity else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        // Every real recorder entry is counted before server deduplication,
        // including repeated calls with the same original client event key.
        state.eventAttempts.append(EventAttempt(clientEventID: request.clientEventID, requestIdentity: identity))
        try persist()
    }

    static func eventIdentity(_ request: SyncEventRecordRequest) -> String {
        // All request fields are compared, including actual entity IDs and the
        // existing writer's key. No test-generated idempotency key is introduced.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let ids = try? encoder.encode(request.entityIDs), let metadata = try? encoder.encode(request.metadata) else { return "invalid" }
        return ShopSyncRecoveryCanonical.sha256([
            request.domain, request.eventType, String(request.changedCount), String(decoding: ids, as: UTF8.self),
            String(decoding: metadata, as: UTF8.self), request.shopID?.uuidString ?? "", request.source ?? "",
            request.sourceDeviceID ?? "", request.batchID?.uuidString ?? "", request.clientEventID
        ].map { "\($0.utf8.count):\($0)" }.joined(separator: "|"))
    }

    var readback: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return "task145.save-b.ledger-encoding-failed" }
        return "task145.save-b.pid.\(ProcessInfo.processInfo.processIdentifier);task145.save-b.ledger." + data.base64EncodedString()
    }
}

/// DEBUG-only bounded backend state for the two controlled process-restart
/// boundaries. Client work is only observed; ordinary providers own every ACK.
@MainActor
private final class Task145RestartControl {
    nonisolated enum Scenario: String, Codable { case preSend = "pre-send", postCommit = "post-commit" }
    nonisolated struct State: Codable {
        let runID: UUID
        let scenario: Scenario
        let firstPID: Int32
        var product: RemoteInventoryProductRow
        var savedToken: LocalPendingChangeCASToken?
        var generationID: UUID?
        var envelope: Data?
        var requests: [Data] = []
        // Optional for v1 decode compatibility. Missing fields cannot qualify C03.
        var rawCatalogEntryCount: Int? = 0
        var rawCatalogEntryCapped: Bool? = false
        var committed: [String] = []
        var returned: [String] = []
        var events: [RemoteSyncEventRow] = []
        var eventClientIDs: [String: RemoteSyncEventRow] = [:]
        var eventAttempts: [Task145SaveBControl.EventAttempt] = []
    }
    var state: State
    let reopening: Bool
    private let url: URL
    private(set) var responseHeld = false
    var qualifiedReopen: Data?
    var captureEnvelope: ((UUID, SyncAutomaticProductUpdatePayload, Task126VerifiedOwnerStoreScope) throws -> Data)?

    init(runID: UUID, scenario: Scenario, url: URL, initial: RemoteInventoryProductRow, reopening: Bool) throws {
        self.url = url; self.reopening = reopening
        if reopening {
            let bytes = try Data(contentsOf: url)
            guard bytes.count <= 131_072 else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = try JSONDecoder().decode(State.self, from: bytes)
            guard state.runID == runID, state.scenario == scenario,
                  state.product.id == initial.id, state.product.ownerUserID == initial.ownerUserID,
                  state.product.shopID == initial.shopID, state.savedToken != nil, state.generationID != nil,
                  state.requests.count <= 2, state.committed.count <= 1, state.returned.count <= 1,
                  state.rawCatalogEntryCount.map({ (0...4).contains($0) }) ?? true,
                  state.events.count <= 1, state.eventClientIDs.count <= 1, state.eventAttempts.count <= 2 else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        } else {
            guard !FileManager.default.fileExists(atPath: url.path) else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = State(runID: runID, scenario: scenario, firstPID: ProcessInfo.processInfo.processIdentifier, product: initial)
            try persist()
        }
    }

    func decoded(_ data: Data) throws -> LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation> {
        try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self, from: data)
    }

    func noteCatalogEntry() throws {
        guard let count = state.rawCatalogEntryCount, count >= 0,
              state.rawCatalogEntryCapped == false else { throw SyncStoreGenerationError.activationReadBackFailed }
        guard count < 4 else {
            state.rawCatalogEntryCapped = true
            try persist() // Sticky cap evidence survives every later reopen.
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.rawCatalogEntryCount = count + 1
        try persist() // Every scoped entry precedes payload and sealed-attempt validation.
    }

    func enter(id: UUID, payload: SyncAutomaticProductUpdatePayload, scope: Task126VerifiedOwnerStoreScope) throws -> Data {
        guard let captureEnvelope, state.requests.count < 2,
              payload.productName == Task145SaveBControl.nameA else { throw SyncStoreGenerationError.activationReadBackFailed }
        let bytes = try captureEnvelope(id, payload, scope)
        let attempt = try decoded(bytes)
        guard let saved = state.savedToken, attempt.pending.changeID == saved.changeID, attempt.pending.idempotencyKey == saved.idempotencyKey,
              attempt.pending.intendedFingerprintHash == saved.intendedFingerprintHash,
              attempt.pending.changedFieldsRaw == saved.changedFieldsRaw,
              attempt.pending.baseRemoteUpdatedAt == saved.baseRemoteUpdatedAt,
              attempt.pending.baseVersion == saved.baseVersion, attempt.pending.baseEventId == saved.baseEventId,
              attempt.pending.baselineFingerprintHash == saved.baselineFingerprintHash,
              state.envelope == nil || state.envelope == bytes,
              state.scenario == .postCommit || reopening else { throw SyncStoreGenerationError.activationReadBackFailed }
        state.envelope = bytes
        state.requests.append(bytes)
        try persist()
        return bytes
    }

    func committed(_ response: RemoteInventoryProductRow, envelope: Data) async throws -> RemoteInventoryProductRow {
        let id = try decoded(envelope).pending.changeID
        if state.committed.isEmpty {
            state.product = response
            state.committed = [id]
            try persist() // Commit, synchronize, close and exact readback before marker.
        } else {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            guard state.committed == [id], try encoder.encode(state.product) == encoder.encode(response) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        if state.scenario == .postCommit, !reopening {
            responseHeld = true
            defer { responseHeld = false }
            let deadline = ContinuousClock.now.advanced(by: .seconds(90))
            while ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
            throw URLError(.timedOut) // There is no release in this process: test must terminate at marker.
        }
        guard state.returned.isEmpty else { throw SyncStoreGenerationError.activationReadBackFailed }
        state.returned = [id]
        try persist()
        return state.product
    }

    func observeEvent(_ request: SyncEventRecordRequest) throws {
        let identity = Task145SaveBControl.eventIdentity(request)
        guard state.returned == state.committed, state.returned.count == 1,
              state.eventAttempts.count < 2, identity != "invalid",
              state.eventAttempts.allSatisfy({ $0.clientEventID == request.clientEventID && $0.requestIdentity == identity }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.eventAttempts.append(.init(clientEventID: request.clientEventID, requestIdentity: identity))
        try persist() // Every recorder entry, including a replay, precedes dedup.
    }

    func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(state)
        guard bytes.count <= 131_072, state.requests.count <= 2,
              state.rawCatalogEntryCount.map({ (0...4).contains($0) }) ?? true,
              state.events.count <= 1, state.eventClientIDs.count <= 1, state.eventAttempts.count <= 2 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        var closed = false
        defer { if !closed { try? handle.close() } }
        try handle.synchronize()
        try handle.close(); closed = true
        guard try Data(contentsOf: url) == bytes else { throw SyncStoreGenerationError.activationReadBackFailed }
    }

    var readback: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return "task145.restart.ledger-encoding-failed" }
        return "task145.restart.pid.\(ProcessInfo.processInfo.processIdentifier);task145.restart.ledger." + data.base64EncodedString()
            + (qualifiedReopen.map { ";task145.restart.reopen-qualification." + $0.base64EncodedString() } ?? "")
    }
}

nonisolated private struct Task145ObservedHistoryUpload: Codable {
    let localUID: UUID
    let row: SharedSheetSessionUpsertRow
    let revision: Int
    let payloadFingerprint: String
}

/// Two opt-in DEBUG scenarios share persisted remote DTOs, but retain separate
/// request ledgers and per-domain oracles. No client write or scheduler lives here.
@MainActor
private final class Task145DomainControl {
    nonisolated enum Domain: String, Codable { case prices, history }
    nonisolated static var feedbackRequested: Bool { ProcessInfo.processInfo.environment["TASK145_HISTORY_FEEDBACK_UI"] == "1" }
    nonisolated struct HistoryFeedback: Codable {
        var localSuccess: [String: Int]?
        var releaseA = false
        var releaseB = false
        var poisoned = false
        var frames: [[String: String]] = []
    }
    static let historyID = UUID(uuidString: "14500000-0000-4000-8000-000000000013")!
    static let title0 = "Controlled history baseline"
    static let titleA = "History title saved during recovery"
    static let titleB = "History title saved while ACK is held"
    nonisolated struct Request: Codable {
        let payloads: [Data]
        let tokens: [LocalPendingChangeCASToken]
        let sealedEnvelope: Data?
    }
    nonisolated struct Event: Codable {
        let clientEventID: String
        let domain: String
        let identity: String
    }
    nonisolated struct StaleWriter: Codable {
        let oldPresentationID: String
        let currentPresentationID: String
        let error: String
        let closureEntered: Bool
        let before: Data
        let after: Data
        let rpcBefore: Int
        let rpcAfter: Int
    }
    nonisolated struct State: Codable {
        let runID: UUID
        let domain: Domain
        let firstPID: Int32
        var product: RemoteInventoryProductRow
        var prices: [RemoteInventoryProductPriceRow] = []
        var history: [RemoteSharedSheetSessionRow] = []
        var generationBeforeCutover: UUID?
        var generationAfterCutover: UUID?
        var savedA: [LocalPendingChangeCASToken] = []
        var savedB: [LocalPendingChangeCASToken] = []
        var revisionA: Int?
        var revisionB: Int?
        var catalogEnvelopes: [Data] = []
        var requests: [Request] = []
        var catalogRPCCount = 0
        var priceRPCCount = 0
        var historyRPCCount = 0
        var eventRPCCount = 0
        var rpcOverflow = false
        var pricePayloads: [String: Data] = [:]
        var committedChangeIDs: [String] = []
        var returnedChangeIDs: [String] = []
        var events: [RemoteSyncEventRow] = []
        var eventClientIDs: [String: RemoteSyncEventRow] = [:]
        var eventAttempts: [Event] = []
        var staleWriter: StaleWriter?
        var historyFeedback: HistoryFeedback?
    }
    var state: State
    let reopening: Bool
    private let url: URL
    private(set) var responseHeld = false
    private(set) var feedbackBHeld = false
    var qualifiedReopen: Data?
    var capturePrices: (([SyncAutomaticProductPricePayload], Task126VerifiedOwnerStoreScope) throws -> [LocalPendingChangeCASToken])?
    var captureHistory: ((SharedSheetSessionUpsertRow, Task126VerifiedOwnerStoreScope) throws -> Data)?
    var captureCatalog: ((UUID, SyncAutomaticProductUpdatePayload, Task126VerifiedOwnerStoreScope) throws -> Data)?
    var validateEvent: ((SyncEventRecordRequest, Task126VerifiedOwnerStoreScope) throws -> Void)?

    init(runID: UUID, domain: Domain, url: URL, initial: RemoteInventoryProductRow, reopening: Bool) throws {
        self.url = url; self.reopening = reopening
        if reopening {
            let bytes = try Data(contentsOf: url)
            guard bytes.count <= 262_144 else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = try JSONDecoder().decode(State.self, from: bytes)
            guard state.runID == runID, state.domain == domain, state.product.id == initial.id,
                  state.product.ownerUserID == initial.ownerUserID, state.product.shopID == initial.shopID,
                  !state.savedA.isEmpty, !state.savedB.isEmpty,
                  state.generationBeforeCutover != nil, state.generationAfterCutover != nil,
                  state.generationBeforeCutover != state.generationAfterCutover,
                  state.staleWriter != nil else { throw SyncStoreGenerationError.activationReadBackFailed }
            guard (state.historyFeedback != nil) == Self.feedbackRequested,
                  state.historyFeedback?.poisoned != true else { throw SyncStoreGenerationError.activationReadBackFailed }
            try validateBounds(bytes: bytes.count)
        } else {
            guard !FileManager.default.fileExists(atPath: url.path) else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = State(runID: runID, domain: domain, firstPID: ProcessInfo.processInfo.processIdentifier, product: initial)
            if Self.feedbackRequested {
                guard domain == .history else { throw SyncStoreGenerationError.activationReadBackFailed }
                state.historyFeedback = HistoryFeedback()
            }
            if domain == .history {
                state.history = [Self.historyRow(title: Self.title0, owner: initial.ownerUserID,
                    shop: initial.shopID, updatedAt: "2026-07-21T12:00:00.000000Z")]
            }
            try persist()
        }
    }

    static func historyRow(title: String, owner: UUID, shop: UUID?, updatedAt: String) -> RemoteSharedSheetSessionRow {
        let grid = feedbackRequested ? [["barcode", "quantity", "SyncError"], ["LOCAL-ROOT", "1", ""]]
            : [["Barcode", "Quantity"], ["LOCAL-ROOT", "1"]]
        // The synthetic server supplies the PostgreSQL-jsonb text digests for
        // these fixed arrays. Actual mobile row-contract code computes the chain.
        return RemoteSharedSheetSessionRow(remoteID: historyID, payloadVersion: 2,
            displayName: title, timestamp: "2026-07-21 12:00:00", supplier: "", category: "",
            isManualEntry: true, data: grid,
            sessionOverlay: .init(overlaySchema: 1, editable: grid, complete: [false, false]),
            ownerUserID: owner, shopID: shop,
            dataCheckpointDigest: ShopSyncRecoveryCanonical.sha256(feedbackRequested
                ? #"[["barcode", "quantity", "SyncError"], ["LOCAL-ROOT", "1", ""]]"#
                : #"[["Barcode", "Quantity"], ["LOCAL-ROOT", "1"]]"#),
            overlayCheckpointDigest: ShopSyncRecoveryCanonical.sha256(feedbackRequested
                ? #"{"complete": [false, false], "editable": [["barcode", "quantity", "SyncError"], ["LOCAL-ROOT", "1", ""]], "overlay_schema": 1}"#
                : #"{"complete": [false, false], "editable": [["Barcode", "Quantity"], ["LOCAL-ROOT", "1"]], "overlay_schema": 1}"#),
            updatedAt: updatedAt, deletedAt: nil)
    }

    func observeCatalog(id: UUID, payload: SyncAutomaticProductUpdatePayload, scope: Task126VerifiedOwnerStoreScope) throws {
        guard state.domain == .prices, let captureCatalog, state.catalogEnvelopes.count < 2,
              id == state.product.id, payload.retailPrice == (state.catalogEnvelopes.isEmpty ? 12 : 13),
              payload.productName == nil, payload.purchasePrice == nil else { throw SyncStoreGenerationError.activationReadBackFailed }
        let bytes = try captureCatalog(id, payload, scope)
        let token = try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self, from: bytes).pending
        let saved = state.catalogEnvelopes.isEmpty ? state.savedA : state.savedB
        guard saved.contains(where: { $0.changeID == token.changeID && $0.idempotencyKey == token.idempotencyKey
            && $0.intendedFingerprintHash == token.intendedFingerprintHash && $0.entityKindRaw == "product" }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.catalogEnvelopes.append(bytes)
        try persist()
    }

    func noteRPCEntry(_ kind: String) throws {
        // Count every scoped entry before payload validation or idempotent
        // replay checks. A rejected duplicate must also fail the no-resend oracle.
        if state.catalogRPCCount + state.priceRPCCount + state.historyRPCCount + state.eventRPCCount >= 16 {
            state.rpcOverflow = true
            try persist()
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        switch kind {
        case "catalog": state.catalogRPCCount += 1
        case "prices": state.priceRPCCount += 1
        case "history": state.historyRPCCount += 1
        case "events": state.eventRPCCount += 1
        default: throw SyncStoreGenerationError.activationReadBackFailed
        }
        try persist()
    }

    func insertPrices(_ payloads: [SyncAutomaticProductPricePayload], scope: Task126VerifiedOwnerStoreScope) async throws -> [RemoteInventoryProductPriceRow] {
        guard state.domain == .prices, let capturePrices,
              state.requests.count < 2, payloads.count == (state.requests.isEmpty ? 1 : 2) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let tokens = try capturePrices(payloads, scope)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try payloads.map { try encoder.encode($0) }
        let expected = (state.requests.isEmpty ? state.savedA : state.savedA + state.savedB)
            .filter { $0.entityKindRaw == "productPrice" }
        guard Set(tokens.map(\.changeID)) == Set(expected.map(\.changeID)),
              tokens.allSatisfy({ token in expected.contains { $0.changeID == token.changeID
                && $0.idempotencyKey == token.idempotencyKey && $0.intendedFingerprintHash == token.intendedFingerprintHash } }),
              state.requests.isEmpty || reopening else { throw SyncStoreGenerationError.activationReadBackFailed }
        state.requests.append(Request(payloads: bytes, tokens: tokens, sealedEnvelope: nil))
        for (index, payload) in payloads.enumerated() {
            guard payload.ownerUserID == scope.ownerUserID, payload.shopID == scope.shopID,
                  payload.productID == state.product.id, payload.type == "RETAIL",
                  payload.price == 12 || payload.price == 13, payload.source == "EDIT_PRODUCT",
                  let amount = PriceCanonicalizer.canonicalAmount(from: payload.price) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            let key = payload.id.uuidString.lowercased()
            if let old = state.pricePayloads[key] {
                guard old == bytes[index], state.prices.contains(where: { $0.id == payload.id }) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
            } else {
                state.pricePayloads[key] = bytes[index]
                state.prices.append(.init(id: payload.id, ownerUserID: payload.ownerUserID, shopID: payload.shopID,
                    productID: payload.productID, type: payload.type, price: payload.price, priceCanonical: amount.value,
                    effectiveAt: payload.effectiveAt, source: payload.source, note: payload.note,
                    createdAt: payload.createdAt, updatedAt: payload.price == 12 ? "2026-07-21T12:01:00.000000Z" : "2026-07-21T12:02:00.000000Z"))
            }
            if !state.committedChangeIDs.contains(tokens[index].changeID) { state.committedChangeIDs.append(tokens[index].changeID) }
        }
        state.prices.sort { $0.id.uuidString < $1.id.uuidString }
        try persist()
        if !reopening { try await holdFirstResponse() }
        state.returnedChangeIDs = tokens.map(\.changeID)
        try persist()
        return try payloads.map { payload in
            guard let row = state.prices.first(where: { $0.id == payload.id }) else { throw SyncStoreGenerationError.activationReadBackFailed }
            return row
        }
    }

    func upsertHistory(_ rows: [SharedSheetSessionUpsertRow], scope: Task126VerifiedOwnerStoreScope) async throws -> [RemoteSharedSheetSessionRow] {
        guard state.domain == .history, rows.count == 1, let row = rows.first,
              let captureHistory, state.requests.count < 3 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let envelope = try captureHistory(row, scope)
        let sealed = try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<Task145ObservedHistoryUpload>.self, from: envelope)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(row)
        let isB = state.requests.count == (state.historyFeedback == nil ? 2 : 1)
        guard row.remoteID == Self.historyID, row.payloadVersion == 2,
              row.ownerUserID == scope.ownerUserID, row.shopID == scope.shopID,
              row.displayName == (isB ? Self.titleB : Self.titleA),
              row.supplier.isEmpty, row.category.isEmpty, row.deletedAt == nil,
              row.data == state.history[0].data, row.sessionOverlay == state.history[0].sessionOverlay,
              row.timestamp == state.history[0].timestamp,
              (isB ? state.savedB : state.savedA).contains(where: { $0.changeID == sealed.pending.changeID
                && $0.idempotencyKey == sealed.pending.idempotencyKey && $0.intendedFingerprintHash == sealed.pending.intendedFingerprintHash }),
              sealed.payload.revision == (isB ? state.revisionB : state.revisionA),
              sealed.payload.payloadFingerprint == HistorySessionPayloadCodec.fingerprintHash(for: row) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if state.requests.count == 1, state.historyFeedback == nil {
            guard reopening, envelope == state.requests[0].sealedEnvelope,
                  bytes == state.requests[0].payloads[0] else { throw SyncStoreGenerationError.activationReadBackFailed }
        }
        state.requests.append(Request(payloads: [bytes], tokens: [sealed.pending], sealedEnvelope: envelope))
        if state.historyFeedback != nil {
            try persist()
            if isB { try await holdHistoryFeedback(isB: true) }
        }
        let response = Self.historyRow(title: row.displayName, owner: row.ownerUserID, shop: row.shopID,
            updatedAt: isB ? "2026-07-21T12:02:00.000000Z" : "2026-07-21T12:01:00.000000Z")
        guard HistorySessionPayloadCodec.fingerprintHash(for: response) == sealed.payload.payloadFingerprint else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.history = [response]
        if !state.committedChangeIDs.contains(sealed.pending.changeID) { state.committedChangeIDs.append(sealed.pending.changeID) }
        try persist()
        if state.historyFeedback != nil {
            if !isB { try await holdHistoryFeedback(isB: false) }
        } else if !reopening { try await holdFirstResponse() }
        guard !state.returnedChangeIDs.contains(sealed.pending.changeID) else { throw SyncStoreGenerationError.activationReadBackFailed }
        state.returnedChangeIDs.append(sealed.pending.changeID)
        try persist()
        return [response]
    }

    private func holdHistoryFeedback(isB: Bool) async throws {
        if isB { feedbackBHeld = true } else { responseHeld = true }
        defer { if isB { feedbackBHeld = false } else { responseHeld = false } }
        do {
            let deadline = ContinuousClock.now.advanced(by: .seconds(90))
            while ContinuousClock.now < deadline {
                guard let feedback = state.historyFeedback, !feedback.poisoned else { throw SyncStoreGenerationError.activationReadBackFailed }
                if isB ? feedback.releaseB : feedback.releaseA { return }
                try await Task.sleep(for: .milliseconds(50))
            }
            throw URLError(.timedOut)
        } catch {
            state.historyFeedback?.poisoned = true; try? persist(); throw error
        }
    }

    private func holdFirstResponse() async throws {
        responseHeld = true
        defer { responseHeld = false }
        let deadline = ContinuousClock.now.advanced(by: .seconds(90))
        while ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
        throw URLError(.timedOut)
    }

    func awaitCutoverAdmission() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        while state.staleWriter == nil {
            guard ContinuousClock.now < deadline else { throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(50))
        }
        try Task.checkCancellation()
    }

    func observeEvent(_ request: SyncEventRecordRequest, scope: Task126VerifiedOwnerStoreScope) throws {
        guard let validateEvent, state.eventAttempts.count < 6 else { throw SyncStoreGenerationError.activationReadBackFailed }
        try validateEvent(request, scope)
        let identity = Task145SaveBControl.eventIdentity(request)
        guard identity != "invalid",
              state.eventAttempts.filter({ $0.clientEventID == request.clientEventID }).allSatisfy({ $0.identity == identity }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.eventAttempts.append(.init(clientEventID: request.clientEventID, domain: request.domain, identity: identity))
        try persist()
    }

    private func validateBounds(bytes: Int) throws {
        guard bytes <= 262_144, (state.historyFeedback?.frames.count ?? 0) <= 4,
              state.historyFeedback == nil || state.domain == .history,
              state.prices.count <= 2, state.history.count <= 1,
              (state.domain == .prices ? state.history.isEmpty : (state.history.count == 1 && state.prices.isEmpty)),
              state.savedA.count <= 2, state.savedB.count <= 2,
              state.catalogRPCCount >= 0, state.priceRPCCount >= 0, state.historyRPCCount >= 0, state.eventRPCCount >= 0,
              state.catalogRPCCount + state.priceRPCCount + state.historyRPCCount + state.eventRPCCount <= 16,
              state.catalogEnvelopes.count <= 2, state.requests.count <= 3,
              state.requests.allSatisfy({ !$0.payloads.isEmpty && $0.payloads.count <= 2 && $0.tokens.count == $0.payloads.count }),
              state.pricePayloads.count <= 2, state.committedChangeIDs.count <= 2, state.returnedChangeIDs.count <= 2,
              state.events.count <= 3, state.eventClientIDs.count <= 3, state.eventAttempts.count <= 6 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }

    func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(state)
        try validateBounds(bytes: bytes.count)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        var closed = false
        defer { if !closed { try? handle.close() } }
        try handle.synchronize()
        try handle.close(); closed = true
        guard try Data(contentsOf: url) == bytes else { throw SyncStoreGenerationError.activationReadBackFailed }
    }

    var rpcCount: Int { state.catalogRPCCount + state.priceRPCCount + state.historyRPCCount + state.eventRPCCount }
    var readback: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return "task145.domain.ledger-encoding-failed" }
        return "task145.domain.pid.\(ProcessInfo.processInfo.processIdentifier);task145.domain.ledger." + data.base64EncodedString()
            + (qualifiedReopen.map { ";task145.domain.reopen-qualification." + $0.base64EncodedString() } ?? "")
    }
}

// TASK145 opt-in T11 native scenarios. All persistence belongs to the synthetic UUID.
@MainActor
private final class Task145IsolationControl {
    nonisolated enum Scenario: String, Codable { case stableSupplier = "stable-supplier", corruptSeal = "corrupt-seal", malformedHead = "malformed-head" }
    nonisolated struct Entry: Codable, Equatable { let pid: Int32; let kind: String; let identity: String }
    nonisolated struct CatalogObservation: Codable {
        let pid: Int32; let blockers: [String]; let creates: Int; let total: Int; let error: String?
    }
    nonisolated struct ActivityObservation: Codable {
        let pid: Int32; let status: String; let registered: Int; let waiting: Int; let blocked: Int
    }
    nonisolated struct RunObservation: Codable {
        let pid: Int32; let status: String; let error: String?; let stable: Bool; let category: String?
        let didWork: Bool; let convergence: Bool; let continuation: Bool; let finalization: Bool
        let catalogCount: Int; let activityCount: Int
    }
    nonisolated struct ReopenQualification: Codable {
        let pid: Int32; let generationID: UUID; let localSnapshot: [String: String]
        let business: [Entry]; let catalogCount: Int; let activityCount: Int; let runCount: Int
    }
    nonisolated struct OutboxIdentity: Codable, Equatable {
        let id: String; let owner: String; let store: String?; let localStore: String?; let epoch: Int
        let client: String; let batch: String?; let domain: String; let eventType: String; let count: Int
        let entityShape: String; let metadataShape: String; let entityJSON: String?; let metadataJSON: String?
        let device: String?; let createdAt: Date
        @MainActor init(_ row: SyncEventOutboxEntry) {
            id = row.id; owner = row.ownerUserID; store = row.storeId; localStore = row.localStoreId; epoch = row.storeEpoch
            client = row.clientEventID; batch = row.batchID; domain = row.domain; eventType = row.eventType; count = row.changedCount
            entityShape = row.entityIDsShape; metadataShape = row.metadataShape; entityJSON = row.entityIDsPayloadJSON
            metadataJSON = row.metadataPayloadJSON; device = row.sourceDeviceID; createdAt = row.createdAt
        }
    }
    nonisolated struct State: Codable {
        let runID: UUID; let scenario: Scenario; let seedPID: Int32
        var generationID: UUID?; var tokens: [LocalPendingChangeCASToken] = []; var seededOutbox: [OutboxIdentity] = []
        var remoteProduct: RemoteInventoryProductRow?; var events: [RemoteSyncEventRow] = []
        var eventClients: [String: RemoteSyncEventRow] = [:]; var rpc: [Entry] = []
        var catalogs: [CatalogObservation] = []; var activities: [ActivityObservation] = []; var runs: [RunObservation] = []
        var expectedEventIdentity: String?; var initialLastVerified: Date?
        var reopenQualification: ReopenQualification?
        var failed = false; var overflow = false
    }
    let root: URL; let reopening: Bool; var state: State
    var qualifiedPID: Int32?; var localSnapshot: [String: String] = [:]
    var verifyEventRequest: ((SyncEventRecordRequest) throws -> Bool)?
    static let invalidName = String(repeating: "X", count: 161)
    static let dependentBarcode = "T145-ISOLATION-P"
    static let independentBarcode = "T145-ISOLATION-Q"

    static func validateAdmission(root: URL, runID: UUID, scenario: Scenario) throws {
        let stateURL = root.appendingPathComponent("isolation-v1.json")
        if FileManager.default.fileExists(atPath: stateURL.path) {
            let prior = try read(State.self, at: stateURL)
            let manifest = try read(SyncStoreGenerationManifest.self, at: root.appendingPathComponent("generation-root/active-generation.json"))
            guard prior.runID == runID, prior.scenario == scenario, prior.generationID == manifest.generationID,
                  !prior.failed, !prior.overflow else { throw SyncStoreGenerationError.activationReadBackFailed }
        } else if FileManager.default.fileExists(atPath: root.path) {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }
    init(root: URL, runID: UUID, scenario: Scenario) throws {
        self.root = root
        let url = root.appendingPathComponent("isolation-v1.json")
        reopening = FileManager.default.fileExists(atPath: url.path)
        state = reopening ? try Self.read(State.self, at: url) : State(runID: runID, scenario: scenario, seedPID: ProcessInfo.processInfo.processIdentifier)
        guard state.runID == runID, state.scenario == scenario, !state.failed, !state.overflow else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if !reopening { try persist() }
    }
    static func read<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize, size <= 524_288 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let bytes = try Data(contentsOf: url)
        guard bytes.count <= 524_288 else { throw SyncStoreGenerationError.activationReadBackFailed }
        return try JSONDecoder().decode(type, from: bytes)
    }
    func persist() throws {
        guard state.rpc.count <= 32, state.catalogs.count <= 32, state.activities.count <= 32, state.runs.count <= 32 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(state)
        guard bytes.count <= 524_288 else { throw SyncStoreGenerationError.activationReadBackFailed }
        let url = root.appendingPathComponent("isolation-v1.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url); var closed = false
        defer { if !closed { try? handle.close() } }
        try handle.synchronize(); try handle.close(); closed = true
        let descriptor = Darwin.open(root.path, O_RDONLY)
        guard descriptor >= 0 else { throw SyncStoreGenerationError.activationReadBackFailed }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0, try Data(contentsOf: url) == bytes else { throw SyncStoreGenerationError.activationReadBackFailed }
    }
    func raw(_ kind: String, identity: String) throws {
        guard !state.failed, !state.overflow, state.rpc.count < 32 else {
            state.overflow = true; try persist(); throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.rpc.append(.init(pid: ProcessInfo.processInfo.processIdentifier, kind: kind, identity: identity))
        try persist()
    }
    func observeCatalog(_ result: SyncCatalogPushResult?, error: String?) {
        guard state.catalogs.count < 32 else { state.overflow = true; preserveObservation(); return }
        state.catalogs.append(.init(pid: ProcessInfo.processInfo.processIdentifier, blockers: result?.plan?.blockers.sorted() ?? [],
            creates: result?.productCreates ?? 0, total: result?.totalChanged ?? 0, error: error))
        preserveObservation()
    }
    func observeActivity(_ result: SyncActivityRegistrationResult) {
        guard state.activities.count < 32 else { state.overflow = true; preserveObservation(); return }
        let status: String
        switch result.status {
        case .success: status = "success"
        case .empty: status = "empty"
        case .partialRetryable: status = "partialRetryable"
        case .authRequired: status = "authRequired"
        case .retryableFailure: status = "retryableFailure"
        case .blocked: status = "blocked"
        case .cancelled: status = "cancelled"
        }
        state.activities.append(.init(pid: ProcessInfo.processInfo.processIdentifier, status: status,
            registered: result.summary.registered, waiting: result.summary.waiting, blocked: result.summary.notRegisterable))
        preserveObservation()
    }
    func observeRun(_ result: SyncAutomaticRunResult) {
        guard state.runs.count < 32 else { state.overflow = true; preserveObservation(); return }
        state.runs.append(.init(pid: ProcessInfo.processInfo.processIdentifier, status: result.status.rawValue,
            error: result.errorCode, stable: result.failure?.disposition == .stable,
            category: result.failure?.category.rawValue, didWork: result.didWork, convergence: result.verifiedConvergence,
            continuation: result.continuationReceipt != nil, finalization: result.verifiedFinalization != nil,
            catalogCount: state.catalogs.count, activityCount: state.activities.count))
        preserveObservation()
    }
    func qualifyReopen(generationID: UUID) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        guard reopening, state.seedPID != pid, state.generationID == generationID,
              state.catalogs.allSatisfy({ $0.pid != pid }), state.activities.allSatisfy({ $0.pid != pid }),
              state.runs.allSatisfy({ $0.pid != pid }), state.rpc.allSatisfy({ $0.pid != pid }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        // Durable local-body qualification before mounting root is not a new runtime outcome.
        state.reopenQualification = .init(pid: pid, generationID: generationID, localSnapshot: localSnapshot,
            business: state.rpc.filter { !$0.kind.hasPrefix("read:") }, catalogCount: state.catalogs.count,
            activityCount: state.activities.count, runCount: state.runs.count)
        try persist(); qualifiedPID = pid
    }
    func hasCurrentReopenOutcome() throws -> Bool {
        let pid = ProcessInfo.processInfo.processIdentifier
        guard let qualified = state.reopenQualification, qualifiedPID == pid, qualified.pid == pid,
              qualified.generationID == state.generationID, !state.failed, !state.overflow,
              qualified.business == state.rpc.filter({ !$0.kind.hasPrefix("read:") }),
              qualified.catalogCount <= state.catalogs.count, qualified.activityCount <= state.activities.count,
              qualified.runCount <= state.runs.count else { throw SyncStoreGenerationError.activationReadBackFailed }
        // Each facade result records provider counts at its completion. A prior callback
        // cannot qualify later provider observations, even within this same process.
        for run in state.runs.dropFirst(qualified.runCount) where run.pid == pid {
            guard run.catalogCount >= qualified.catalogCount, run.catalogCount <= state.catalogs.count,
                  run.activityCount >= qualified.activityCount, run.activityCount <= state.activities.count else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            let catalogs = state.catalogs.prefix(run.catalogCount).dropFirst(qualified.catalogCount).filter { $0.pid == pid }
            let activities = state.activities.prefix(run.activityCount).dropFirst(qualified.activityCount).filter { $0.pid == pid }
            switch state.scenario {
            case .stableSupplier:
                guard !catalogs.isEmpty else { continue }
                let blockers = ["invalidCatalogText:\(state.tokens[0].changeID):supplierName:too_long",
                    "unresolvedCatalogReference:\(state.tokens[1].changeID):supplier"].sorted()
                if catalogs.allSatisfy({ $0.blockers == blockers && $0.creates == 0 && $0.total == 0 && $0.error == nil }),
                   !activities.isEmpty, activities.allSatisfy({ $0.status == "empty" && $0.registered == 0 && $0.waiting == 0 && $0.blocked == 0 }),
                   run.error == "catalog_local_changes_blocked", run.stable, run.category == "payload",
                   !run.convergence, !run.continuation, !run.finalization { return true }
            case .corruptSeal:
                guard !catalogs.isEmpty else { continue }
                if catalogs.allSatisfy({ $0.error == "activationReadBackFailed" && $0.creates == 0 && $0.total == 0 }),
                   activities.isEmpty, run.stable, run.category == "integrity", !run.didWork,
                   !run.convergence, !run.continuation, !run.finalization { return true }
            case .malformedHead:
                // blockedContract is excluded from pending work: normal light reconciliation
                // need not call either push provider. Validate any that did precede this
                // current-PID facade outcome, without forcing a push or global failure.
                if catalogs.allSatisfy({ $0.error == nil && $0.creates == 0 && $0.total == 0 && $0.blockers.isEmpty }),
                   activities.allSatisfy({ $0.status == "blocked" && $0.registered == 0 && $0.waiting == 0 && $0.blocked == 1 }) {
                    return true
                }
            }
        }
        return false
    }
    private func preserveObservation() {
        do { try persist() } catch { state.failed = true; try? persist() }
    }
    func captureLastIdentity(_ identity: String) throws {
        guard let last = state.rpc.last, last.pid == ProcessInfo.processInfo.processIdentifier,
              last.identity == "entry-before-validation" else { throw SyncStoreGenerationError.activationReadBackFailed }
        state.rpc[state.rpc.count - 1] = .init(pid: last.pid, kind: last.kind, identity: identity)
        try persist()
    }
    func create(_ payloads: [SyncAutomaticProductCreatePayload], initial: RemoteInventoryProductRow) throws -> [RemoteInventoryProductRow] {
        guard state.scenario == .stableSupplier, payloads.count == 1, let p = payloads.first,
              p.ownerUserID == initial.ownerUserID, p.shopID == initial.shopID,
              p.barcode == Self.independentBarcode, p.productName == "Independent T11 intent",
              p.supplierID == nil, p.categoryID == nil, p.itemNumber == nil, p.secondProductName == nil,
              p.purchasePrice == nil, p.retailPrice == nil, p.stockQuantity == nil, state.remoteProduct == nil else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let row = RemoteInventoryProductRow(id: p.id, ownerUserID: p.ownerUserID, shopID: p.shopID,
            barcode: p.barcode, itemNumber: p.itemNumber, productName: p.productName, secondProductName: p.secondProductName,
            purchasePrice: p.purchasePrice, retailPrice: p.retailPrice, supplierID: p.supplierID, categoryID: p.categoryID,
            stockQuantity: p.stockQuantity, updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: nil)
        state.remoteProduct = row; try persist(); return [row]
    }
    func eventEntry(_ request: SyncEventRecordRequest) throws {
        try raw("recordEvent", identity: "entry-before-validation")
        try captureLastIdentity(Task145SaveBControl.eventIdentity(request))
    }
    func acceptEvent(_ request: SyncEventRecordRequest, initial: RemoteInventoryProductRow) throws {
        let expectedID = state.scenario == .malformedHead ? initial.id : state.remoteProduct?.id
        guard state.scenario != .corruptSeal, let expectedID,
              request.entityIDs == .object(["product_ids": .array([.string(expectedID.uuidString.lowercased())])]),
              try verifyEventRequest?(request) == true else { throw SyncStoreGenerationError.activationReadBackFailed }
        let identity = Task145SaveBControl.eventIdentity(request)
        guard state.expectedEventIdentity == nil || state.expectedEventIdentity == identity else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.expectedEventIdentity = identity; try persist()
    }
    var readback: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(state), let snapshot = try? JSONSerialization.data(withJSONObject: localSnapshot, options: [.sortedKeys]) else {
            return "task145.isolation.encoding-failed"
        }
        return "task145.isolation.pid.\(ProcessInfo.processInfo.processIdentifier);task145.isolation.ledger." + bytes.base64EncodedString()
            + ";task145.isolation.local." + snapshot.base64EncodedString()
    }
}

// These wrappers observe exactly one delegated production call and return the
// same result/error; diagnostics never substitute for the actual service result.
private final class Task145IsolationCatalogProvider: SyncCatalogPushProviding {
    let base: any SyncCatalogPushProviding
    let observe: @MainActor (SyncCatalogPushResult?, String?) -> Void
    init(base: any SyncCatalogPushProviding, observe: @escaping @MainActor (SyncCatalogPushResult?, String?) -> Void) {
        self.base = base; self.observe = observe
    }
    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult {
        do {
            let result = try await base.pushPendingCatalog(ownerUserID: ownerUserID)
            observe(result, nil); return result
        } catch {
            observe(nil, (error as? SyncStoreGenerationError) == .activationReadBackFailed ? "activationReadBackFailed" : String(reflecting: type(of: error)))
            throw error
        }
    }
}
private final class Task145IsolationActivityProvider: SyncActivityRegistrationProviding {
    let base: any SyncActivityRegistrationProviding
    let observe: @MainActor (SyncActivityRegistrationResult) -> Void
    init(base: any SyncActivityRegistrationProviding, observe: @escaping @MainActor (SyncActivityRegistrationResult) -> Void) {
        self.base = base; self.observe = observe
    }
    func loadSyncActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SyncActivityRegistrationSnapshot {
        try await base.loadSyncActivityRegistrationSnapshot(ownerUserID: ownerUserID)
    }
    func registerSyncActivities(ownerUserID: UUID) async throws -> SyncActivityRegistrationResult {
        let result = try await base.registerSyncActivities(ownerUserID: ownerUserID)
        observe(result); return result
    }
}

/// Bounded file evidence for the four existing recovery interruption seams.
/// The host owns SIGKILL; this fixture never kills a process or resets a store.
private nonisolated enum Task145InterruptionFiles {
    static func read(_ url: URL, maximum: Int = 524_288) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= maximum else { throw SyncStoreGenerationError.activationReadBackFailed }
        let data = try Data(contentsOf: url)
        guard data.count <= maximum else { throw SyncStoreGenerationError.activationReadBackFailed }
        return data
    }
    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(value)
        guard bytes.count <= 1_048_576 else { throw SyncStoreGenerationError.activationReadBackFailed }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        var closed = false
        defer { if !closed { try? handle.close() } }
        try handle.synchronize(); try handle.close(); closed = true
        let descriptor = Darwin.open(url.deletingLastPathComponent().path, O_RDONLY)
        guard descriptor >= 0 else { throw SyncStoreGenerationError.activationReadBackFailed }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0, try read(url, maximum: 1_048_576) == bytes else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }
    static func decode<T: Decodable>(_ type: T.Type, _ url: URL) throws -> T {
        try JSONDecoder().decode(type, from: read(url, maximum: 1_048_576))
    }
}

@MainActor
private final class Task145InterruptionControl {
    nonisolated enum Scenario: String, Codable { case staging, before, after, finalizing }
    nonisolated enum Mode: String, Codable { case seed, crash, verify }
    nonisolated struct Entry: Codable {
        let mode: Mode; let pid: Int32; let kind: String; let afterID: String?
    }
    nonisolated struct State: Codable {
        let runID: UUID; let scenario: Scenario; let seedPID: Int32
        var mode: Mode = .seed
        var crashPID: Int32?
        var oldGenerationID: UUID?
        var candidateGenerationID: UUID?
        var products: [RemoteInventoryProductRow]
        var entries: [Entry] = []
        var entryOverflow = false
        var observationFailed = false
    }
    nonisolated struct KillReceipt: Codable {
        let runID: UUID; let scenario: String; let pid: Int32; let bundleID: String
        let simulatorUDID: String; let markerSHA256: String; let deathConfirmed: Bool; let signal: Int
    }
    nonisolated struct Result: Codable {
        let phase: String; let passed: Bool; let runID: UUID; let scenario: Scenario; let pid: Int32
        let generationID: UUID; let products: [UUID]; let qualified: Bool; let journalPhase: String?
        let state: State
    }
    let root: URL
    let mode: Mode
    var state: State
    var isSeed: Bool { mode == .seed }
    var isCrash: Bool { mode == .crash }
    var extraProduct: RemoteInventoryProductRow? { isSeed ? nil : state.products.last }
    var boundary: Task145InterruptionBoundary {
        Task145InterruptionBoundary(root: root, runID: state.runID, scenario: state.scenario)
    }

    static func validateInitialAdmission(root: URL, runID: UUID, scenario: Scenario, action: String) throws {
        let manager = FileManager.default
        let stateURL = root.appendingPathComponent("interruption-state-v1.json")
        if manager.fileExists(atPath: stateURL.path) {
            let prior = try Task145InterruptionFiles.decode(State.self, stateURL)
            let manifest = try Task145InterruptionFiles.decode(SyncStoreGenerationManifest.self,
                root.appendingPathComponent("generation-root/active-generation.json"))
            guard prior.runID == runID, prior.scenario == scenario, prior.oldGenerationID != nil,
                  !prior.entryOverflow, !prior.observationFailed,
                  manifest.generationID == prior.oldGenerationID || manifest.generationID == prior.candidateGenerationID,
                  (action == "crash" && prior.mode == .seed && prior.crashPID == nil)
                    || (action == "ui" && prior.mode == .crash && prior.crashPID != nil),
                  !manager.fileExists(atPath: root.appendingPathComponent("boundary-marker-error.json").path) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        } else {
            // A leftover directory, manifest, marker or store is not a fresh seed.
            guard action == "ui", !manager.fileExists(atPath: root.path) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
    }

    init(root: URL, runID: UUID, scenario: Scenario, action: String, initial: RemoteInventoryProductRow) throws {
        self.root = root
        let stateURL = root.appendingPathComponent("interruption-state-v1.json")
        if FileManager.default.fileExists(atPath: stateURL.path) {
            state = try Task145InterruptionFiles.decode(State.self, stateURL)
            guard state.runID == runID, state.scenario == scenario, state.oldGenerationID != nil,
                  state.products.count >= 1, state.products.count <= 2,
                  state.products[0].id == initial.id, state.entries.count <= 64, !state.entryOverflow, !state.observationFailed else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            guard try encoder.encode(state.products[0]) == encoder.encode(initial) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            if action == "crash" {
                guard state.mode == .seed, state.crashPID == nil,
                      !FileManager.default.fileExists(atPath: root.appendingPathComponent("boundary-marker.json").path) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                mode = .crash
                state.mode = .crash; state.crashPID = ProcessInfo.processInfo.processIdentifier
                state.products.append(RemoteInventoryProductRow(
                    id: UUID(uuidString: "14400000-0000-4000-8000-000000000004")!,
                    ownerUserID: initial.ownerUserID, shopID: initial.shopID, barcode: "RECOVERY-SECOND",
                    itemNumber: "second recovery row", productName: "Recovery added product", secondProductName: nil,
                    purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil,
                    updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: nil))
                try persist()
            } else {
                guard action == "ui", state.mode == .crash, state.products.count == 2 else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                let receipt = try Task145InterruptionFiles.decode(KillReceipt.self, root.appendingPathComponent("host-kill-receipt.json"))
                let markerBytes = try Task145InterruptionFiles.read(root.appendingPathComponent("boundary-marker.json"), maximum: 1_048_576)
                // Host uses raw-byte SHA256; the marker hash below uses that same implementation.
                guard receipt.runID == runID, receipt.scenario == scenario.rawValue,
                      receipt.pid == state.crashPID, receipt.pid != ProcessInfo.processInfo.processIdentifier,
                      receipt.bundleID == Bundle.main.bundleIdentifier, UUID(uuidString: receipt.simulatorUDID) != nil,
                      receipt.deathConfirmed, receipt.signal == 9,
                      receipt.markerSHA256 == SHA256.hash(data: markerBytes).map({ String(format: "%02x", $0) }).joined() else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                mode = .verify
                // Keep the original crash state until pre-root readback proves exact continuity.
            }
        } else {
            guard action == "ui" else { throw SyncStoreGenerationError.activationReadBackFailed }
            mode = .seed
            state = State(runID: runID, scenario: scenario, seedPID: ProcessInfo.processInfo.processIdentifier, products: [initial])
            try persist()
        }
    }
    func persist() throws {
        guard state.entries.count <= 64, state.products.count <= 2 else { throw SyncStoreGenerationError.activationReadBackFailed }
        try Task145InterruptionFiles.write(state, to: root.appendingPathComponent("interruption-state-v1.json"))
    }
    func note(_ kind: String, afterID: String? = nil) throws {
        guard !state.entryOverflow, state.entries.count < 64 else {
            state.entryOverflow = true; try persist(); throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.entries.append(.init(mode: mode, pid: ProcessInfo.processInfo.processIdentifier, kind: kind, afterID: afterID))
        try persist()
    }
    func prepareCandidateFromJournal(_ journal: AccountRecoveryJournalSnapshot) throws {
        guard journal.mode == .sameScopeRecovery, let id = journal.generationID,
              id != state.oldGenerationID, state.candidateGenerationID == nil || state.candidateGenerationID == id else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.candidateGenerationID = id
        try persist()
    }
    func beforeProductPage(afterID: String?) async throws {
        try note("page:products", afterID: afterID)
        if isCrash, state.scenario == .staging, afterID != nil {
            // Unlike the repository's synchronous rename seam, this second RPC
            // remains asynchronous so the host can capture the live root UI.
            do {
                _ = try boundary.capture("staging")
                let deadline = ContinuousClock.now.advanced(by: .seconds(90))
                while ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
                throw URLError(.timedOut)
            } catch {
                // Any exit invalidates this historical marker before recovery can continue.
                state.observationFailed = true
                try persist()
                try Task145InterruptionFiles.write(["phase": "staging-hold-exited"],
                    to: root.appendingPathComponent("boundary-marker-error.json"))
                throw error
            }
        }
    }
    var readback: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(state) else { return "task145.interruption.encoding-failed" }
        return "task145.interruption.mode.\(mode.rawValue);task145.interruption.pid.\(ProcessInfo.processInfo.processIdentifier);task145.interruption.ledger." + bytes.base64EncodedString()
    }
}

/// Same immutable marker/PID/semaphore protocol as Task139. No repository API
/// is added, and no SwiftUI state is read from the synchronous rename callback.
private nonisolated final class Task145InterruptionBoundary: @unchecked Sendable {
    struct Marker: Codable {
        let runID: UUID; let scenario: Task145InterruptionControl.Scenario; let boundary: String; let pid: Int32
        let oldGenerationID: UUID; let candidateGenerationID: UUID; let manifest: SyncStoreGenerationManifest
        let journal: Data; let progress: Data; let productLedger: Data; let finalization: Data?
        let state: Task145InterruptionControl.State
        let storeBytes: Int; let walBytes: Int
    }
    private struct Failure: Codable { let phase: String; let passed: Bool; let pid: Int32 }
    let root: URL; let runID: UUID; let scenario: Task145InterruptionControl.Scenario
    init(root: URL, runID: UUID, scenario: Task145InterruptionControl.Scenario) {
        self.root = root; self.runID = runID; self.scenario = scenario
    }
    func handle(_ boundary: SyncStoreActivationBoundary) {
        guard (scenario == .before && boundary == .beforeManifestRename)
            || (scenario == .after && boundary == .afterManifestRename) else { return }
        block(boundary == .beforeManifestRename ? "before" : "after")
    }
    func block(_ name: String) {
        do { _ = try capture(name) }
        catch { try? Task145InterruptionFiles.write(Failure(phase: name, passed: false, pid: ProcessInfo.processInfo.processIdentifier), to: root.appendingPathComponent("boundary-marker-error.json")) }
        // Only the host's finite watchdog may end this owned process. Returning
        // here would let publication continue and invalidate the experiment.
        DispatchSemaphore(value: 0).wait()
    }
    func capture(_ name: String) throws -> Marker {
        let state = try Task145InterruptionFiles.decode(Task145InterruptionControl.State.self, root.appendingPathComponent("interruption-state-v1.json"))
        guard state.runID == runID, state.scenario == scenario, state.mode == .crash,
              state.crashPID == ProcessInfo.processInfo.processIdentifier, !state.observationFailed,
              let old = state.oldGenerationID, let candidate = state.candidateGenerationID,
              !FileManager.default.fileExists(atPath: root.appendingPathComponent("boundary-marker.json").path) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let generationRoot = root.appendingPathComponent("generation-root")
        let generation = generationRoot.appendingPathComponent("generations").appendingPathComponent(candidate.uuidString.lowercased())
        let manifest = try Task145InterruptionFiles.decode(SyncStoreGenerationManifest.self, generationRoot.appendingPathComponent("active-generation.json"))
        let journal = try Task145InterruptionFiles.read(generationRoot.appendingPathComponent("recovery-journal.json"))
        let progress = try Task145InterruptionFiles.read(generation.appendingPathComponent("recovery-page-progress-v1.json"))
        let ledger = try Task145InterruptionFiles.read(generation.appendingPathComponent("recovery-ledger-v1/products.ndjson"))
        let progressObject = try JSONSerialization.jsonObject(with: progress) as? [String: Any]
        let domains = progressObject?["domains"] as? [String: Any]
        let products = domains?["products"] as? [String: Any]
        let journalObject = try JSONSerialization.jsonObject(with: journal) as? [String: Any]
        let beforePublish = name == "staging" || name == "before"
        let expectedPhase = name == "staging" ? "staging" : name == "finalizing" ? "activated" : "verified"
        guard name == scenario.rawValue, manifest.generationID == (beforePublish ? old : candidate),
              UUID(uuidString: progressObject?["generationID"] as? String ?? "") == candidate,
              progressObject?["pageLimit"] as? Int == 1,
              products?["pages"] as? Int == (name == "staging" ? 1 : 2),
              products?["processed"] as? Int == (name == "staging" ? 1 : 2),
              products?["complete"] as? Bool == (name != "staging"),
              (name != "staging" || products?["afterID"] as? String == state.products[0].id.uuidString.lowercased()),
              products?["ledgerBytes"] as? Int == ledger.count,
              journalObject?["phaseRaw"] as? String == expectedPhase,
              UUID(uuidString: journalObject?["generationID"] as? String ?? "") == candidate,
              journalObject?["modeRaw"] as? String == "sameScopeRecovery",
              !FileManager.default.fileExists(atPath: generation.appendingPathComponent("recovery-page-prepared-v1.json").path) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let finalURL = generationRoot.appendingPathComponent("recovery-finalization.json")
        let final = FileManager.default.fileExists(atPath: finalURL.path) ? try Task145InterruptionFiles.read(finalURL) : nil
        if let final {
            let receipt = try JSONDecoder().decode(SyncStoreRecoveryFinalization.self, from: final)
            guard receipt.generationID != candidate else { throw SyncStoreGenerationError.activationReadBackFailed }
        }
        func size(_ name: String) throws -> Int {
            let file = generation.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: file.path) { return 0 }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw SyncStoreGenerationError.activationReadBackFailed }
            return values.fileSize ?? 0
        }
        let marker = Marker(runID: runID, scenario: scenario, boundary: name, pid: ProcessInfo.processInfo.processIdentifier,
            oldGenerationID: old, candidateGenerationID: candidate, manifest: manifest, journal: journal, progress: progress,
            productLedger: ledger, finalization: final, state: state, storeBytes: try size("store.store"), walBytes: try size("store.store-wal"))
        guard marker.storeBytes > 0, !ledger.isEmpty else { throw SyncStoreGenerationError.activationReadBackFailed }
        try Task145InterruptionFiles.write(marker, to: root.appendingPathComponent("boundary-marker.json"))
        return marker
    }
}

private nonisolated final class Task144ControlledAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock(); private var values: [String: Data] = [:]
    private var failReads = false
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? {
        try lock.withLock {
            if failReads { throw CocoaError(.fileReadNoPermission) }
            return values[key]
        }
    }
    func setReadFailure(_ value: Bool) { lock.withLock { failReads = value } }
    var readsFailing: Bool { lock.withLock { failReads } }
    func rawDigest() -> String {
        lock.withLock {
            var digest = SHA256()
            for key in values.keys.sorted() { digest.update(data: Data(key.utf8)); digest.update(data: values[key]!) }
            return digest.finalize().map { String(format: "%02x", $0) }.joined()
        }
    }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}
private nonisolated final class Task144ControlledNetworkBlocker: URLProtocol, @unchecked Sendable {
    private static let observationLock = NSLock()
    nonisolated(unsafe) private static var t13Requests = 0
    static var t13RequestCount: Int { observationLock.withLock { t13Requests } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if ProcessInfo.processInfo.environment["TASK145_AUTH_STORAGE_UI"] == "cached-read-failure" {
            Self.observationLock.withLock { Self.t13Requests = min(9, Self.t13Requests + 1) }
        }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}
// TASK145_SCOPE_SWITCH_INSERT_BEGIN append
// Controlled provider data and observations only. No authority, journal, draft or ACK is restored here.
@MainActor
private final class Task145ScopeSwitchControl {
    enum Scenario: String { case cancelReturn = "cancel-explicit-return"; case confirmedCallback = "confirmed-delayed-response" }
    enum Fault: Error { case invalidBoundary, observationLimit, heldResponseDeadline }
    struct Entry: Codable {
        let ordinal: Int
        let uptime: TimeInterval
        let kind: String
        let values: [String: String]
    }
    struct Ledger: Codable {
        let schema: String
        let runID: UUID
        let scenario: String
        let root: String
        let shopA: UUID
        let shopB: UUID
        let productA: UUID
        let productB: UUID
        var facts: [String: String] = [:]
        var entries: [Entry] = []
    }
    static let shopB = UUID(uuidString: "145c0000-0000-4000-8000-000000000002")!
    static let productA = UUID(uuidString: "14400000-0000-4000-8000-000000000003")!
    static let productB = UUID(uuidString: "145c0000-0000-4000-8000-000000000003")!
    static let nameB = "Qualified scope B product"
    static let shopNameB = "Controlled scope B"
    static let draftA = "Scope A unsaved isolated draft"
    let scenario: Scenario
    let shopA: LinkedShop
    let linkedB: LinkedShop
    let transportB: Task144ControlledRecoveryTransport
    let catalogB: Task144ControlledCatalogRemote
    let url: URL
    var ledger: Ledger
    var originalScope: Task126VerifiedOwnerStoreScope?
    var originalLease: SyncStoreGenerationLease?
    var originalBody: [String: String]?
    var qualifiedB: [String: String]?
    var finalB: [String: String]?
    weak var presentation: LocalRootPresentationState?
    var ingress: [String: Int] = [:]
    var armedMembershipHold = false
    var refreshRequested = false
    private(set) var membershipHeld = false
    private(set) var membershipReturned = false
    private(set) var refreshCompleted = false
    private var membershipContinuation: CheckedContinuation<Void, Error>?
    private var holdExpiry: Task<Void, Never>?
    private var membershipRequest = 0
    var onChange: (() -> Void)?

    init(runID: UUID, scenario: Scenario, root: URL, owner: UUID, shopA: LinkedShop, device: String) throws {
        self.scenario = scenario; self.shopA = shopA
        linkedB = LinkedShop(shopID: Self.shopB, code: "TASK145-C-B", name: Self.shopNameB,
            role: "owner", status: "active", selectable: true, canWrite: true)
        let row = RemoteInventoryProductRow(id: Self.productB, ownerUserID: owner, shopID: Self.shopB,
            barcode: "SCOPE-B-ONLY", itemNumber: "scope B fixture", productName: Self.nameB,
            secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil,
            categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:00:00.000000Z", deletedAt: nil)
        transportB = try Task144ControlledRecoveryTransport(owner: owner, shop: Self.shopB, device: device, product: row)
        catalogB = Task144ControlledCatalogRemote(initial: row, authoritativeScope: transportB.baseline.scope,
            isEmpty: false, allowsRelatedSave: false)
        url = root.appendingPathComponent("scope-switch-observation-v1.json")
        guard !FileManager.default.fileExists(atPath: url.path) else { throw Fault.invalidBoundary }
        ledger = Ledger(schema: "task145-scope-switch-observation-v1", runID: runID,
            scenario: scenario.rawValue, root: root.path, shopA: shopA.shopID, shopB: Self.shopB,
            productA: Self.productA, productB: Self.productB)
        transportB.remoteSnapshot = { [catalogB] in catalogB.recoverySnapshot }
        transportB.release()
        try persist()
        // An exact-owned cleanup manifest; no cleanup runs before evidence export.
        let cleanup: [String: Any] = ["runID": runID.uuidString.lowercased(), "ownedRoot": root.path,
            "productIDs": [Self.productA.uuidString, Self.productB.uuidString],
            "shopIDs": [shopA.shopID.uuidString, Self.shopB.uuidString],
            "policy": "After runner stop and evidence export only; remove this exact owned runID root, never defaults/global stores or a prefix query.",
            "liveBackendRows": 0, "automaticCleanup": false]
        let bytes = try JSONSerialization.data(withJSONObject: cleanup, options: [.sortedKeys])
        try bytes.write(to: root.appendingPathComponent("scope-switch-cleanup-manifest-v1.json"), options: [.atomic])
    }

    func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(ledger)
        guard bytes.count <= 131_072 else { throw Fault.observationLimit }
        try bytes.write(to: url, options: [.atomic])
        guard try Data(contentsOf: url) == bytes else { throw Fault.invalidBoundary }
    }
    func note(_ kind: String, _ values: [String: String] = [:]) throws {
        guard ledger.entries.count < 256 else { throw Fault.observationLimit }
        ledger.entries.append(Entry(ordinal: ledger.entries.count + 1,
            uptime: ProcessInfo.processInfo.systemUptime, kind: kind, values: values))
        try persist(); onChange?()
    }
    func raw(_ kind: String, shop: UUID) throws {
        let key = shop.uuidString.lowercased() + ":" + kind
        ingress[key, default: 0] += 1
        try note("raw-ingress", ["operation": kind, "shop": shop.uuidString.lowercased(),
            "count": String(ingress[key]!)])
    }
    var writeCount: Int {
        ingress.filter { $0.key.contains(":write:") }.values.reduce(0, +)
    }
    func decodedMembership(_ shops: [LinkedShop]) throws -> [LinkedShop] {
        let rows: [[String: Any]] = shops.map { ["shop_id": $0.shopID.uuidString,
            "code": $0.code ?? "", "name": $0.name, "role": $0.role, "status": $0.status,
            "selectable": $0.selectable, "can_write": $0.canWrite] }
        let bytes = try JSONSerialization.data(withJSONObject: ["ok": true, "code": "ok", "shops": rows], options: [.sortedKeys])
        try note("membership-response", ["shops": shops.map { $0.shopID.uuidString.lowercased() }.joined(separator: ","),
            "sha256": ShopSyncRecoveryCanonical.sha256(String(decoding: bytes, as: UTF8.self))])
        return try MobileLinkedShopRPCDecoder.decode(bytes)
    }
    func fetchLinkedShops() async throws -> [LinkedShop] {
        membershipRequest += 1
        guard membershipRequest <= 16 else { throw Fault.observationLimit }
        let request = membershipRequest
        try note("membership-ingress", ["request": String(request)])
        if armedMembershipHold {
            armedMembershipHold = false; membershipHeld = true
            try note("old-a-response-held", ["request": String(request), "response-shop": shopA.shopID.uuidString.lowercased()])
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                membershipContinuation = continuation
                holdExpiry = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .seconds(120)) } catch { return }
                    guard let self, let pending = self.membershipContinuation else { return }
                    self.membershipContinuation = nil
                    self.ledger.facts["hold-deadline"] = "expired"
                    pending.resume(throwing: Fault.heldResponseDeadline)
                }
            }
            membershipReturned = true
            try note("old-a-provider-return", ["request": String(request)])
            return try decodedMembership([shopA])
        }
        return try decodedMembership([shopA, linkedB])
    }
    func releaseOldResponse() throws {
        guard qualifiedB != nil, membershipHeld, !membershipReturned,
              let pending = membershipContinuation else { throw Fault.invalidBoundary }
        try note("old-a-release-after-b-qualified")
        membershipContinuation = nil; holdExpiry?.cancel(); holdExpiry = nil
        pending.resume()
    }
    func markRefreshCompleted() throws {
        guard membershipHeld, membershipReturned, membershipContinuation == nil,
              ledger.facts["hold-deadline"] == nil else { throw Fault.invalidBoundary }
        refreshCompleted = true
        try note("old-a-refresh-completed", ["provider-returned": String(membershipReturned),
            "deadline-expired": ledger.facts["hold-deadline"] ?? "false"])
    }
    var readback: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(ledger) else { return "ENCODING_FAILED" }
        return data.base64EncodedString()
    }
}

@MainActor
private final class Task145ScopeSwitchRecoveryRouter: ShopSyncRecoveryRPCTransporting {
    let owner: UUID
    let a: Task144ControlledRecoveryTransport
    let control: Task145ScopeSwitchControl
    init(owner: UUID, a: Task144ControlledRecoveryTransport, control: Task145ScopeSwitchControl) {
        self.owner = owner; self.a = a; self.control = control
    }
    func authenticatedUserID() async throws -> UUID { owner }
    private func target(_ shop: UUID, operation: String) throws -> Task144ControlledRecoveryTransport {
        try control.raw("recovery:" + operation, shop: shop)
        if shop == control.shopA.shopID { return a }
        guard shop == Task145ScopeSwitchControl.shopB else { throw Task145ScopeSwitchControl.Fault.invalidBoundary }
        return control.transportB
    }
    func checkpoint(_ p: ShopSyncRecoveryCheckpointParameters) async throws -> Data {
        let transport = try target(p.shopID, operation: "checkpoint")
        if p.shopID == Task145ScopeSwitchControl.shopB {
            guard let journal = AccountBindingStore().pendingRecoveryJournal,
                  journal.mode == .accountOrShopReplacement,
                  journal.replacement.storeIdentity == LocalStoreIdentity(rawValue: p.shopID.uuidString.lowercased()) else {
                throw Task145ScopeSwitchControl.Fault.invalidBoundary
            }
            try control.note("b-real-replacement-journal", ["mode": "accountOrShopReplacement",
                "phase": String(describing: journal.phase)])
        }
        return try await transport.checkpoint(p)
    }
    func page(_ p: ShopSyncRecoveryPageParameters) async throws -> Data {
        try await target(p.shopID, operation: "page:" + p.domain).page(p)
    }
    func marker(_ p: ShopSyncConvergenceMarkerParameters) async throws -> Data {
        try await target(p.shopID, operation: "marker").marker(p)
    }
    func eventPage(_ p: ShopSyncEventPageParameters) async throws -> Data {
        try await target(p.shopID, operation: "event-page").eventPage(p)
    }
}

extension Task144LocalAvailabilityRootFixture {
    var hasScopeSwitchControl: Bool { scopeSwitchControl != nil }
    var scopeSwitchReadback: String { scopeSwitchControl?.readback ?? "ABSENT" }
    func bindScopeSwitchPresentation(_ presentation: LocalRootPresentationState?) {
        // The actual environment object is observed, never replaced or mutated.
        if let presentation { scopeSwitchControl?.presentation = presentation }
    }
    private func configureScopeSwitch(_ control: Task145ScopeSwitchControl) {
        scopeSwitchControl = control
        shopFetcher.scopeSwitchControl = control
        control.onChange = { [weak self, weak control] in
            guard let self, let control else { return }
            self.facts = self.facts.filter { !$0.hasPrefix("task145.scope.observation.") }
            self.facts.insert("task145.scope.observation.\(control.ledger.entries.count)")
        }
        catalogRemote.scopeSwitchIngress = { [weak control] operation in
            guard let control else { throw Task145ScopeSwitchControl.Fault.invalidBoundary }
            try control.raw(operation, shop: control.shopA.shopID)
        }
        control.catalogB.scopeSwitchIngress = { [weak control] operation in
            guard let control else { throw Task145ScopeSwitchControl.Fault.invalidBoundary }
            try control.raw(operation, shop: Task145ScopeSwitchControl.shopB)
        }
    }
    private func prepareScopeSwitch() throws {
        guard let control = scopeSwitchControl, AccountBindingStore().pendingRecoveryJournal == nil,
              let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner),
              scope.shopID == shop, Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else {
            throw Task145ScopeSwitchControl.Fault.invalidBoundary
        }
        let initial = try scopeSwitchBody()
        guard initial["product-id"] == Task145ScopeSwitchControl.productA.uuidString.lowercased(),
              initial["name"] == "Safe local baseline", initial["pending"] == "0",
              initial["local-access"] == "true", initial["body-proof"] == "true" else {
            throw Task145ScopeSwitchControl.Fault.invalidBoundary
        }
        control.originalScope = scope
        control.originalLease = controller.captureLease(for: controller.modelContainer)
        control.originalBody = initial
        control.ledger.facts = initial.mapKeysForScopeSwitch(prefix: "initial-")
        try control.note("a-qualified-real-body", initial)
        transport.release()
        facts.insert("task145.scope.prepared")
    }
    private func startScopeSwitch() {
        guard scopeSwitchControl != nil, !hasStarted else { return }
        hasStarted = true
        facts.insert("task145.scope.root-startup-completed")
        task = Task { @MainActor [weak self] in
            guard let self, let control = self.scopeSwitchControl else { return }
            let deadline = ProcessInfo.processInfo.systemUptime + 180
            do {
                while ProcessInfo.processInfo.systemUptime < deadline {
                    let current = try self.scopeSwitchBody()
                    let selected = current["selected-shop"]
                    if selected == Task145ScopeSwitchControl.shopB.uuidString.lowercased(),
                       !self.facts.contains("task145.scope.b-selected") {
                        try control.note("b-selected-readback", current)
                        self.facts.insert("task145.scope.b-selected")
                    }
                    if current["manifest-shop"] == Task145ScopeSwitchControl.shopB.uuidString.lowercased(),
                       current["local-access"] == "true", current["body-proof"] == "true",
                       current["journal-present"] == "false", control.qualifiedB == nil,
                       let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: self.owner),
                       scope.shopID == Task145ScopeSwitchControl.shopB,
                       try self.controller.isActiveRecoveryFinalized(scope: scope) {
                        guard current["product-id"] == Task145ScopeSwitchControl.productB.uuidString.lowercased(),
                              current["name"] == Task145ScopeSwitchControl.nameB,
                              current["pending"] == "0", control.writeCount == 0 else {
                            throw Task145ScopeSwitchControl.Fault.invalidBoundary
                        }
                        control.qualifiedB = current
                        try control.note("b-qualified-real-body", current)
                        self.facts.insert("task145.scope.b-qualified")
                    }
                    if control.refreshCompleted, control.membershipReturned,
                       let before = control.qualifiedB, control.finalB == nil {
                        let protected = ["manifest-sha256", "generation", "binding-sha256", "selected-shop",
                            "product-id", "name", "fingerprint", "pending", "outbox", "watermark", "local-access", "body-proof"]
                        guard protected.allSatisfy({ current[$0] == before[$0] }), control.writeCount == 0,
                              let oldScope = control.originalScope, let oldLease = control.originalLease else {
                            throw Task145ScopeSwitchControl.Fault.invalidBoundary
                        }
                        var rejectedScope = false; var rejectedLease = false
                        do { try Task126OwnerStoreGate.revalidateAutomaticScope(oldScope) } catch { rejectedScope = true }
                        do { try self.controller.validateLease(oldLease) } catch { rejectedLease = true }
                        guard rejectedScope, rejectedLease else { throw Task145ScopeSwitchControl.Fault.invalidBoundary }
                        control.finalB = current
                        try control.note("b-after-old-a-completion", current.merging([
                            "captured-a-scope-rejected": "true", "old-generation-lease-rejected": "true"]) { _, new in new })
                        self.facts.insert("task145.scope.callback-terminal")
                        return
                    }
                    try await Task.sleep(for: .milliseconds(200))
                }
                throw URLError(.timedOut)
            } catch {
                self.scopeSwitchFailure(error, stage: "observation")
            }
        }
    }
    private func scopeSwitchBody() throws -> [String: String] {
        guard let control = scopeSwitchControl, let manifest = controller.activeManifest else {
            throw Task145ScopeSwitchControl.Fault.invalidBoundary
        }
        let context = ModelContext(controller.modelContainer)
        var request = FetchDescriptor<Product>(); request.fetchLimit = 3
        let products = try context.fetch(request)
        guard products.count == 1, let product = products.first,
              let id = product.remoteID, let name = product.productName else { throw Task145ScopeSwitchControl.Fault.invalidBoundary }
        var outboxRequest = FetchDescriptor<SyncEventOutboxEntry>(); outboxRequest.fetchLimit = 16
        let outbox = try context.fetch(outboxRequest)
        guard outbox.count < 16 else { throw Task145ScopeSwitchControl.Fault.observationLimit }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let binding = AccountBindingStore().currentBinding
        let selected = SelectedShopStore().selectedShop(accountHash: AccountBindingStore.accountHash(for: owner))
        let draft = control.presentation?.editor(presentationID: controller.presentationID,
            remoteID: Task145ScopeSwitchControl.productA, barcode: "LOCAL-ROOT")
        return ["manifest-sha256": ShopSyncRecoveryCanonical.sha256(String(decoding: try encoder.encode(manifest), as: UTF8.self)),
            "binding-sha256": ShopSyncRecoveryCanonical.sha256(String(decoding: try encoder.encode(binding), as: UTF8.self)),
            "generation": manifest.generationID.uuidString.lowercased(), "manifest-shop": manifest.shopID.uuidString.lowercased(),
            "selected-shop": selected?.shopID.uuidString.lowercased() ?? "none",
            "context-shop": shopContextStore.context.selectedShop?.shopID.uuidString.lowercased() ?? "none",
            "product-id": id.uuidString.lowercased(), "name": name,
            "fingerprint": LocalPendingChangeLogicalKey.productFingerprintHash(product),
            "pending": String(try context.fetchCount(FetchDescriptor<LocalPendingChange>())),
            "outbox": outbox.map { $0.clientEventID + ":" + $0.statusRaw }.sorted().joined(separator: "|"),
            "watermark": String(WatermarkStore().watermark(for: .init(ownerUserID: owner, storeIdentity: manifest.storeIdentity))),
            "body-proof": String(Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer)),
            "local-access": String(Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer, ownerUserID: owner)),
            "journal-present": String(AccountBindingStore().hasPendingReplacementJournal),
            "draft-observer-bound": String(control.presentation != nil),
            "draft-name": draft?.name ?? "ABSENT", "raw-write-count": String(control.writeCount)]
    }
    func scopeSwitchSelectBFromEditor() {
        do {
            guard let control = scopeSwitchControl, control.scenario == .cancelReturn,
                  facts.contains("task145.scope.root-startup-completed"),
                  shopContextStore.context.activeShopID == shop else { throw Task145ScopeSwitchControl.Fault.invalidBoundary }
            let body = try scopeSwitchBody()
            guard body["draft-observer-bound"] == "true", body["draft-name"] == Task145ScopeSwitchControl.draftA,
                  body["local-access"] == "true" else { throw Task145ScopeSwitchControl.Fault.invalidBoundary }
            try control.note("native-draft-before-controlled-select-b", body)
            shopContextStore.selectShop(Task145ScopeSwitchControl.shopB)
            try control.note("debug-selection-producer-called", ["producer": "ShopContextStore.selectShop", "native-picker": "false"])
        } catch { scopeSwitchFailure(error, stage: "controlled-select-b") }
    }
    func scopeSwitchStartHeldRefresh() {
        guard let control = scopeSwitchControl else { return }
        do {
            guard control.scenario == .confirmedCallback, !control.refreshRequested,
                  facts.contains("task145.scope.root-startup-completed"),
                  shopContextStore.context.activeShopID == shop else { throw Task145ScopeSwitchControl.Fault.invalidBoundary }
            control.refreshRequested = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    guard self.shopContextStore.context.activeShopID == self.shop,
                          !control.membershipHeld, !control.armedMembershipHold else {
                        throw Task145ScopeSwitchControl.Fault.invalidBoundary
                    }
                    let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: self.owner)
                    try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
                    guard scope.shopID == self.shop,
                          let lease = self.controller.captureLease(for: self.controller.modelContainer) else {
                        throw Task145ScopeSwitchControl.Fault.invalidBoundary
                    }
                    try self.controller.validateLease(lease)
                    control.originalScope = scope; control.originalLease = lease
                    try control.note("old-a-refresh-requested", try self.scopeSwitchBody())
                    // Arm immediately before the same MainActor refresh enters the fetcher.
                    control.armedMembershipHold = true
                    await self.shopContextStore.refresh(ownerUserID: self.owner)
                    try control.markRefreshCompleted()
                } catch { self.scopeSwitchFailure(error, stage: "old-refresh-completion") }
            }
        } catch { scopeSwitchFailure(error, stage: "request-old-refresh") }
    }
    func scopeSwitchReleaseOldResponse() {
        do { try scopeSwitchControl?.releaseOldResponse() }
        catch { scopeSwitchFailure(error, stage: "release-old-response") }
    }
    func scopeSwitchObserve() {
        do { try scopeSwitchControl?.note("native-ui-checkpoint", try scopeSwitchBody()) }
        catch { scopeSwitchFailure(error, stage: "ui-readback") }
    }
    private func scopeSwitchFailure(_ error: Error, stage: String) {
        facts.insert("task145.scope.failure")
        facts.insert("task145.scope.failure-stage." + stage)
        if let control = scopeSwitchControl {
            control.ledger.facts["failure-stage"] = stage
            control.ledger.facts["failure-kind"] = Self.failureKind(error)
            try? control.persist()
        }
    }
    private func scopeSwitchRuntime(modelContainer: ModelContainer, stateStore: SyncStateStore,
        control: Task145ScopeSwitchControl) -> any SyncAutomaticRuntimeProviding {
        let lease = controller.captureLease(for: modelContainer)
        let remote = controller.activeManifest?.shopID == Task145ScopeSwitchControl.shopB ? control.catalogB : catalogRemote
        let router = Task145ScopeSwitchRecoveryRouter(owner: owner, a: transport, control: control)
        let recovery = AtomicGenerationRecoverySnapshotPullService(storeGenerationController: controller,
            recoveryRemote: ShopSyncRecoveryRemoteAdapter(transport: router), pageLimit: 25,
            progressReporter: { [weak stateStore] event in stateStore?.recordRecoveryProgress(event) })
        let facade = AutomaticSyncRuntimeFacade(authViewModel: authViewModel,
            catalogPushProvider: CatalogPushService(modelContainer: modelContainer, remote: remote),
            productPriceProvider: nil, historySessionProvider: nil,
            incrementalPullProvider: SyncEventIncrementalPullService(modelContainer: modelContainer,
                remote: remote, storeGenerationController: controller),
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: SyncActivityRegistrationService(modelContainer: modelContainer, recorder: remote),
            runAdmissionValidator: { [controller] in
                guard let lease else { throw SyncStoreGenerationError.staleGenerationLease }
                try await MainActor.run { try controller.validateLease(lease) }
            })
        return Task144ObservedAutomaticRuntime(runtime: facade) { [weak self, weak control] action, result in
            guard let self, let control else { return }
            do {
                try control.note("real-runtime-result", ["action": Self.actionKind(action), "status": result.status.rawValue,
                    "error": result.errorCode ?? "none", "verified": String(result.verifiedConvergence),
                    "generation": self.controller.activeManifest?.generationID.uuidString.lowercased() ?? "none"])
            } catch { self.scopeSwitchFailure(error, stage: "runtime-observation") }
        }
    }
}

private extension Dictionary where Key == String, Value == String {
    func mapKeysForScopeSwitch(prefix: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: map { (prefix + $0.key, $0.value) })
    }
}

@MainActor
private struct Task145ScopeSwitchControls: View {
    @ObservedObject var fixture: Task144LocalAvailabilityRootFixture
    @Environment(\.localRootPresentationState) private var presentation
    let prefix: String
    var body: some View {
        HStack {
            Button("Observe scope") { fixture.scopeSwitchObserve() }
                .accessibilityIdentifier(prefix + ".scope.observe")
            if prefix.hasSuffix("editor") {
                Button("Controlled select B") { fixture.scopeSwitchSelectBFromEditor() }
                    .accessibilityIdentifier(prefix + ".scope.select-b")
            } else {
                Button("Hold A membership response") { fixture.scopeSwitchStartHeldRefresh() }
                    .accessibilityIdentifier(prefix + ".scope.hold-a")
                Button("Release old A response") { fixture.scopeSwitchReleaseOldResponse() }
                    .accessibilityIdentifier(prefix + ".scope.release-a")
            }
            Text("Scope evidence").accessibilityIdentifier(prefix + ".scope.ledger")
                .accessibilityValue(fixture.scopeSwitchReadback)
        }
        .font(.caption2)
        .onAppear { if prefix.hasSuffix("editor") { fixture.bindScopeSwitchPresentation(presentation) } }
    }
}
// TASK145_SCOPE_SWITCH_INSERT_END append
// TASK145_T19_INSERT_BEGIN helper
/// Passive, bounded observations for controlled native T19. Never grants scope or submits sync.
private struct Task145T19Error: Error { let code: String }
@MainActor
private final class Task145T19Control {
    let root: URL
    let runID: String
    let mode: String
    let collecting: Bool
    var state: [String: Any]
    private(set) var trace: [[String: Any]]
    private(set) var frame = 0
    private(set) var frameStart = 0
    var observationTask: Task<Void, Never>?
    var failed: Bool { state["error"] != nil }
    var completed: Int { state["completed"] as? Int ?? 0 }
    var baseline: String? { state["baseline"] as? String }
    var isComplete: Bool { state["status"] as? String == "COMPLETE" }
    var readback: String {
        guard let data = try? Self.json(state), data.count <= 65_536 else { return "task145.t19.invalid-readback" }
        return "task145.t19.state." + data.base64EncodedString()
    }
    init(parent: URL, runID: UUID, mode: String, collecting: Bool) throws {
        self.runID = runID.uuidString.lowercased(); self.mode = mode; self.collecting = collecting
        try Self.require(["cycles", "repeated-material"].contains(mode), "mode")
        try Self.require(parent.lastPathComponent == self.runID && parent.deletingLastPathComponent().lastPathComponent == "task144-root-fixtures", "root_namespace")
        try Self.require(parent.standardizedFileURL == parent.resolvingSymlinksInPath(), "root_symlink")
        root = parent.appendingPathComponent("t19-observations", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Self.require(root.standardizedFileURL == root.resolvingSymlinksInPath(), "observation_symlink")
        let url = root.appendingPathComponent("state.json")
        if FileManager.default.fileExists(atPath: url.path) {
            state = try Self.object(Data(contentsOf: url)); trace = try Self.array(Data(contentsOf: root.appendingPathComponent("trace.json")))
            try Self.require(state["runID"] as? String == self.runID && state["mode"] as? String == mode && state["protocol"] as? String == "task145-t19-controlled-v1", "reopen_identity")
            try Self.require(!failed && !isComplete, "preserve_terminal_no_retry")
        } else {
            state = ["protocol": "task145-t19-controlled-v1", "runID": self.runID, "mode": mode,
                "lane": "CONTROLLED_NATIVE_APP_DI_NOT_AUTHENTICATED_TEST", "status": "SETUP", "completed": 0,
                "lateDiagnostic": "UNKNOWN_NOT_TRAVERSED", "processes": [Int32](),
                "cycles": (1...(mode == "cycles" ? 30 : 1)).map { ["cycle": $0, "status": "NOT_RUN"] as [String: Any] }]
            trace = []
            try Self.require(!collecting, "setup_evidence_required")
        }
        var pids = state["processes"] as? [Int32] ?? []
        // NSNumber bridging is explicit when reopening JSON.
        if let values = state["processes"] as? [NSNumber] { pids = values.map(\.int32Value) }
        let pid = ProcessInfo.processInfo.processIdentifier
        try Self.require(!pids.contains(pid) && pids.count < 8, "process_reopen_identity")
        pids.append(pid); state["processes"] = pids; state["pid"] = pid
        if collecting { state["status"] = "COLLECTING"; state["qualifiedPID"] = NSNull() }
        try persist()
    }
    static func require(_ condition: Bool, _ code: String) throws { if !condition { throw Task145T19Error(code: code) } }
    static func json(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]) }
    static func object(_ data: Data) throws -> [String: Any] {
        try require(data.count <= 2_097_152, "json_bound")
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Task145T19Error(code: "object") }
        return value
    }
    static func array(_ data: Data) throws -> [[String: Any]] {
        try require(data.count <= 4_194_304, "trace_bound")
        guard let value = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw Task145T19Error(code: "array") }
        return value
    }
    static func encoded<T: Encodable>(_ value: T) throws -> Any {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try JSONSerialization.jsonObject(with: encoder.encode(value), options: [.fragmentsAllowed])
    }
    static func hash(_ data: Data) -> String { ShopSyncRecoveryCanonical.sha256(data.base64EncodedString()) }
    func write(_ name: String, _ object: Any) throws -> String {
        try Self.require(name.range(of: "^[a-z0-9-]+\\.json$", options: .regularExpression) != nil, "file_name")
        let data = try Self.json(object); try Self.require(data.count <= 4_194_304, "output_bound")
        let target = root.appendingPathComponent(name), pending = root.appendingPathComponent(name + ".pending")
        try Self.require(!FileManager.default.fileExists(atPath: pending.path), "preserve_partial")
        try data.write(to: pending, options: [.withoutOverwriting])
        let handle = try FileHandle(forWritingTo: pending)
        do { try handle.synchronize(); try handle.close() } catch { try? handle.close(); throw error }
        try Self.require(rename(pending.path, target.path) == 0, "rename")
        let fd = open(root.path, O_RDONLY); try Self.require(fd >= 0, "open_directory")
        defer { close(fd) }
        try Self.require(fsync(fd) == 0, "fsync_directory")
        return Self.hash(data)
    }
    func persist() throws {
        _ = try write("trace.json", trace); _ = try write("state.json", state)
    }
    func emit(_ kind: String, _ data: [String: Any] = [:]) throws {
        try Self.require(trace.count < 8192, "trace_cap")
        trace.append(["sequence": trace.count + 1, "pid": ProcessInfo.processInfo.processIdentifier,
            "uptime": ProcessInfo.processInfo.systemUptime, "frame": frame, "kind": kind, "data": data])
        try persist()
    }
    func fail(_ error: Error) {
        if !failed {
            let code = (error as? Task145T19Error)?.code ?? String(reflecting: type(of: error))
            state["error"] = code; state["status"] = "FAIL"; state["failedFrame"] = frame
            if collecting, baseline != nil, var rows = state["cycles"] as? [[String: Any]], completed < rows.count {
                rows[completed] = ["cycle": completed + 1, "status": "FAIL", "error": code,
                    "boundary": "observer_or_current_cycle", "actualCycleCompleted": false]
                state["cycles"] = rows
            }
        }
        do { try persist() } catch { NSLog("TASK145_T19_EVIDENCE_WRITE_FAILED %@", String(reflecting: type(of: error))) }
    }
    func begin(action: String, source: String) {
        guard !failed else { return }
        do {
            try Self.require(observationTask == nil, "overlapping_publication_observation")
            frame += 1; frameStart = trace.count
            try emit("runtime_begin", ["action": action, "source": source])
        } catch { fail(error) }
    }
    @discardableResult func rpc(_ name: String, _ data: [String: Any] = [:]) -> Int {
        guard !failed else { return 0 }
        do { try emit("rpc", ["name": name, "arguments": data]); return trace.count }
        catch { fail(error); return 0 }
    }
    func rpcComplete(_ name: String, entry: Int, errorType: String?) {
        guard !failed else { return }
        do {
            try Self.require(entry > 0 && entry <= trace.count, "rpc_completion_binding")
            try emit(errorType == nil ? "rpc_return" : "rpc_failure", ["name": name, "entry": entry, "errorType": errorType as Any? ?? NSNull()])
        } catch { fail(error) }
    }
    func file(_ name: String) throws -> [String: Any] { try Self.object(Data(contentsOf: root.appendingPathComponent(name))) }
    func saveBaseline(_ snapshot: [String: Any]) throws {
        try Self.require(baseline == nil, "baseline_once")
        state["baselineSha256OfBase64"] = try write("baseline.json", snapshot); state["baseline"] = "baseline.json"
        state["status"] = "BASELINE_READY"; state["verifiedText"] = snapshot["verifiedText"]; try persist()
    }
    func cycle(_ snapshot: [String: Any], observation: Any, source: String, presentation: String, calls: [String]) throws {
        try Self.require(!failed && !isComplete && baseline != nil, "cycle_admission")
        let index = completed + 1, total = mode == "cycles" ? 30 : 1
        try Self.require(index <= total && source == "foregroundPoll", "cycle_source")
        let name = String(format: "cycle-%02d.json", index)
        let baselineObject = try file(baseline!)
        try Self.require(try Self.json(snapshot) == Self.json(baselineObject), "no_op_snapshot_diff")
        let hash = try write(name, snapshot)
        var rows = state["cycles"] as? [[String: Any]] ?? []
        try Self.require(rows.count == total && rows[index - 1]["status"] as? String == "NOT_RUN", "cycle_inventory")
        rows[index - 1] = ["cycle": index, "status": "PASS", "source": source, "observation": observation,
            "pid": ProcessInfo.processInfo.processIdentifier, "presentation": presentation,
            "frame": frame, "calls": calls, "snapshot": name, "sha256OfBase64": hash]
        state["cycles"] = rows; state["completed"] = index
        state["status"] = index == total ? "COMPLETE" : "COLLECTING"
        try persist()
    }
}

/// Read-only SQLite image from the exact owned active-generation URL. No PRAGMA/write/backup.
@MainActor
private enum Task145T19SQLite {
    static func image(url: URL, ownedRoot: URL) throws -> [String: Any] {
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        let root = ownedRoot.resolvingSymlinksInPath().standardizedFileURL
        try Task145T19Control.require(url.standardizedFileURL == canonical && root == ownedRoot.standardizedFileURL &&
            canonical.path.hasPrefix(root.path + "/generation-root/") && FileManager.default.fileExists(atPath: canonical.path), "sqlite_owned_url")
        var db: OpaquePointer?
        let opened = sqlite3_open_v2(canonical.path, &db, SQLITE_OPEN_READONLY, nil)
        guard opened == SQLITE_OK, let db else { if let db { sqlite3_close(db) }; throw Task145T19Error(code: "sqlite_open_\(opened)") }
        var closed = false
        defer { if !closed { sqlite3_close(db) } }
        try Task145T19Control.require(sqlite3_db_readonly(db, "main") == 1, "sqlite_readonly")
        try Task145T19Control.require(sqlite3_busy_timeout(db, 1000) == SQLITE_OK, "sqlite_busy_bound")
        try Task145T19Control.require(sqlite3_exec(db, "BEGIN", nil, nil, nil) == SQLITE_OK, "sqlite_begin")
        var reading = true
        defer { if reading { sqlite3_exec(db, "ROLLBACK", nil, nil, nil) } }
        func query(_ sql: String) throws -> (columns: [String], rows: [[[String: Any]]]) {
            var statement: OpaquePointer?
            let prepared = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            guard prepared == SQLITE_OK, let statement else { if let statement { sqlite3_finalize(statement) }; throw Task145T19Error(code: "sqlite_prepare_\(prepared)") }
            defer { sqlite3_finalize(statement) }
            try Task145T19Control.require(sqlite3_stmt_readonly(statement) == 1, "sqlite_statement_readonly")
            let count = sqlite3_column_count(statement)
            try Task145T19Control.require(count > 0 && count <= 256, "sqlite_columns")
            let columns = (0..<count).map { String(cString: sqlite3_column_name(statement, $0)) }
            var rows: [[[String: Any]]] = []
            var step = sqlite3_step(statement)
            while step == SQLITE_ROW {
                try Task145T19Control.require(rows.count < 256, "sqlite_rows")
                var cells: [[String: Any]] = []
                for index in 0..<count {
                    let kind = sqlite3_column_type(statement, index)
                    let value: Any
                    switch kind {
                    case SQLITE_NULL: value = NSNull()
                    case SQLITE_INTEGER: value = String(sqlite3_column_int64(statement, index))
                    case SQLITE_FLOAT: value = String(sqlite3_column_double(statement, index).bitPattern, radix: 16)
                    case SQLITE_TEXT:
                        let bytes = sqlite3_column_bytes(statement, index)
                        try Task145T19Control.require(bytes >= 0 && bytes <= 2_097_152, "sqlite_text_bound")
                        guard let pointer = sqlite3_column_text(statement, index), let text = String(data: Data(bytes: pointer, count: Int(bytes)), encoding: .utf8) else { throw Task145T19Error(code: "sqlite_text") }
                        value = text
                    case SQLITE_BLOB:
                        let count = Int(sqlite3_column_bytes(statement, index))
                        try Task145T19Control.require(count >= 0 && count <= 2_097_152, "sqlite_blob_bound")
                        if count == 0 { value = "" }
                        else { guard let pointer = sqlite3_column_blob(statement, index) else { throw Task145T19Error(code: "sqlite_blob") }; value = Data(bytes: pointer, count: count).base64EncodedString() }
                    default: throw Task145T19Error(code: "sqlite_type")
                    }
                    cells.append(["type": kind, "value": value])
                }
                rows.append(cells); step = sqlite3_step(statement)
            }
            try Task145T19Control.require(step == SQLITE_DONE, "sqlite_step_\(step)")
            return (columns, rows)
        }
        let inventory = try query("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
        try Task145T19Control.require(!inventory.rows.isEmpty && inventory.rows.count <= 128, "sqlite_inventory")
        var tables: [String: Any] = [:]
        for table in inventory.rows {
            guard let name = table[0]["value"] as? String, let schema = table[1]["value"] as? String else { throw Task145T19Error(code: "sqlite_schema") }
            try Task145T19Control.require(name.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil, "sqlite_identifier")
            let read = try query("SELECT * FROM \"" + name + "\"")
            let sorted = try read.rows.map { try Task145T19Control.json($0) }.sorted { $0.lexicographicallyPrecedes($1) }
            tables[name] = ["schema": schema, "columns": read.columns, "rows": try sorted.map { try JSONSerialization.jsonObject(with: $0) }]
        }
        try Task145T19Control.require(try Task145T19Control.json(tables).count <= 2_097_152, "sqlite_image_bound")
        // Explicit rollback/close result is qualified; defers still run on every failure path.
        try Task145T19Control.require(sqlite3_exec(db, "ROLLBACK", nil, nil, nil) == SQLITE_OK, "sqlite_rollback")
        reading = false
        try Task145T19Control.require(sqlite3_close(db) == SQLITE_OK, "sqlite_close")
        closed = true
        return tables
    }
}
// TASK145_T19_INSERT_END helper

// TASK145_T19_INSERT_BEGIN observation
@MainActor
private extension Task144LocalAvailabilityRootFixture {
    func t19Observe(action: SyncAction, source: SyncAutomaticTriggerSource, result: SyncAutomaticRunResult) {
        guard let control = t19Control, !control.failed, !control.isComplete else { return }
        do {
            try control.emit("runtime_return", ["source": source.rawValue, "action": Self.actionKind(action),
                "status": result.status.rawValue, "didWork": result.didWork, "verifiedConvergence": result.verifiedConvergence,
                "errorCode": result.errorCode as Any? ?? NSNull(), "receiptPresent": result.continuationReceipt != nil,
                "observation": try result.observation.map { try Task145T19Control.encoded($0) } ?? NSNull()])
        } catch { control.fail(error); refreshAutomaticObservation(); return }
        guard control.collecting else { return }
        let frame = control.frame, start = control.frameStart
        control.observationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { control.observationTask = nil; self.refreshAutomaticObservation() }
            do {
                guard let observation = result.observation else { throw Task145T19Error(code: "missing_producer_observation") }
                let deadline = ProcessInfo.processInfo.systemUptime + 5
                var published = false
                while !published && ProcessInfo.processInfo.systemUptime < deadline {
                    try Task.checkCancellation()
                    published = SyncStateStore.currentRunObservation(keyPrefix: "task144.controlled.\(self.namespace.uuidString.lowercased())", ownerUserID: self.owner) == observation
                    if !published { try await Task.sleep(nanoseconds: 10_000_000) }
                }
                try Task145T19Control.require(published && frame == control.frame && !control.failed, "producer_publication_timeout_or_superseded")
                try Task145T19Control.require(result.errorCode == nil && result.failure == nil && result.blockReason == nil &&
                    !action.containsFullRecovery && self.stateStore.state.phase == .idle, "healthy_terminal")
                guard let receipt = result.continuationReceipt else { throw Task145T19Error(code: "missing_real_continuation_receipt") }
                try receipt.withValidatedAuthority(defaults: .standard) {}
                let snapshot = try self.t19Snapshot()
                try receipt.withValidatedAuthority(defaults: .standard) {}
                try Task145T19Control.require(SyncStateStore.currentRunObservation(keyPrefix: "task144.controlled.\(self.namespace.uuidString.lowercased())", ownerUserID: self.owner) == observation, "publication_changed_during_snapshot")
                control.state["qualifiedPID"] = ProcessInfo.processInfo.processIdentifier
                let frameRows = Array(control.trace.dropFirst(start))
                let entries = frameRows.filter { $0["kind"] as? String == "rpc" }
                let returns = frameRows.filter { $0["kind"] as? String == "rpc_return" }
                try Task145T19Control.require(!frameRows.contains { $0["kind"] as? String == "rpc_failure" } && entries.count == returns.count, "rpc_terminal_inventory")
                for entry in entries {
                    guard let sequence = entry["sequence"] as? Int, let request = entry["data"] as? [String: Any], let name = request["name"] as? String else { throw Task145T19Error(code: "rpc_entry_shape") }
                    let matching = returns.filter { row in
                        guard let value = row["data"] as? [String: Any] else { return false }
                        return value["entry"] as? Int == sequence && value["name"] as? String == name
                    }
                    try Task145T19Control.require(matching.count == 1, "rpc_entry_return_binding")
                }
                let calls = entries.compactMap { ($0["data"] as? [String: Any])?["name"] as? String }
                let healthyCalls = ["fetchSyncEventsAfter", "fetchReconciliationRemoteCounts", "fetchSyncEventsAfter"]
                if control.baseline == nil {
                    try Task145T19Control.require(result.status == .noWork && !result.didWork && calls == healthyCalls, "baseline_no_work")
                    try control.saveBaseline(snapshot)
                    self.facts.insert("task145.t19.baseline-ready")
                    if control.mode == "repeated-material" {
                        try self.catalogRemote.t19ArmRepeatedMaterial()
                        try control.emit("repeated_material_script_armed", ["eventIDs": [43, 44], "sameBody": true])
                    }
                } else if control.mode == "repeated-material" && control.state["variant"] == nil {
                    try Task145T19Control.require(source == .foregroundPoll && result.status == .success && result.didWork && !result.verifiedConvergence, "variant_real_apply")
                    try Task145T19Control.require(calls == ["fetchSyncEventsAfter", "fetchCatalogByIDs", "fetchSyncEventsAfter"], "variant_rpc_inventory")
                    try self.t19ValidateRepeated(before: control.file("baseline.json"), after: snapshot)
                    _ = try control.write("repeated-material-after.json", snapshot)
                    control.state["variant"] = ["status": "PASS", "frame": frame, "calls": calls, "observation": try Task145T19Control.encoded(observation)]
                    // The no-op tail baseline is a separate file; original baseline is preserved.
                    control.state["baseline"] = "variant-baseline.json"
                    control.state["baselineSha256OfBase64"] = try control.write("variant-baseline.json", snapshot)
                    try control.persist()
                } else {
                    try Task145T19Control.require(result.status == .noWork && !result.didWork && !result.verifiedConvergence && calls == healthyCalls, "no_op_runtime_or_rpc")
                    let baseline = try control.file(control.baseline!)
                    try Task145T19Control.require(try Task145T19Control.json(snapshot) == Task145T19Control.json(baseline), "reopen_or_no_op_snapshot_diff")
                    if source == .foregroundPoll {
                        try control.cycle(snapshot, observation: Task145T19Control.encoded(observation), source: source.rawValue,
                            presentation: self.controller.presentationID, calls: calls)
                        self.facts.insert("task145.t19.cycle.\(control.completed)")
                        if control.isComplete { self.facts.insert("task145.t19.complete") }
                    } else {
                        try control.emit("reopen_no_op_not_counted", ["source": source.rawValue, "snapshotUnchanged": true])
                    }
                }
            } catch { control.fail(error); self.facts.insert("task145.t19.failed") }
        }
    }

    func t19Snapshot() throws -> [String: Any] {
        guard let control = t19Control, let manifest = controller.activeManifest, let restart = restartControl else { throw Task145T19Error(code: "snapshot_scope") }
        try Task145T19Control.require(try restartReadback(), "real_ack_body_readback")
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
        let store = try ownedRepository.storeURLForLocalBodyReadback(manifest)
        let parent = ownedLegacyStoreURL.deletingLastPathComponent()
        let binding = AccountBindingStore().currentBinding
        try Task145T19Control.require(binding?.accountHash == manifest.accountHash && binding?.storeIdentity == manifest.storeIdentity &&
            AccountBindingStore().pendingRecoveryJournal == nil && Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) &&
            (try ownedRepository.isRecoveryFinalized(manifest)), "snapshot_authority")
        let context = ModelContext(controller.modelContainer); context.autosaveEnabled = false
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        try Task145T19Control.require(products.count == 1 && pending.count == 1 && pending[0].status == .acknowledged &&
            outbox.count <= 3 && outbox.allSatisfy { $0.status == .sent || $0.status == .localOnly } &&
            !outbox.contains { LocalPendingBusinessAttemptStore.isSealed($0) }, "snapshot_pending_outbox")
        let statusKey = SyncEventApplyStatusStore().storageKeyForTesting(ownerUserID: owner, shopID: shop)
        guard let statusBytes = UserDefaults.standard.data(forKey: statusKey), statusBytes.count <= 524_288 else { throw Task145T19Error(code: "incoming_status_missing") }
        let statuses = try JSONDecoder().decode([String: SyncEventApplyStatusRecord].self, from: statusBytes)
        guard let own = statuses["42"] else { throw Task145T19Error(code: "own_event_not_observed") }
        try Task145T19Control.require(own.ownerUserID == owner && own.shopID == shop && own.eventID == 42 && own.status == .skipped && own.reason == .selfOrigin,
            "own_event_status")
        let prefix = "task144.controlled.\(namespace.uuidString.lowercased())"
        guard let verifiedProof = UserDefaults.standard.data(forKey: prefix + ".lastVerifiedProof.v2"),
              !verifiedProof.isEmpty && verifiedProof.count <= 131_072 else { throw Task145T19Error(code: "verified_proof_missing") }
        let verified = stateStore.state.lastVerifiedAt
        try Task145T19Control.require(verified != nil, "verified_provenance_missing")
        let outboxBodies = outbox.sorted { $0.id < $1.id }.map { row -> [String: Any] in
            ["id": row.id, "owner": row.ownerUserID, "store": row.storeId as Any? ?? NSNull(), "localStore": row.localStoreId as Any? ?? NSNull(),
             "protocol": row.syncProtocolVersion, "schema": row.schemaVersion, "epoch": row.storeEpoch, "clientEventID": row.clientEventID,
             "batch": row.batchID as Any? ?? NSNull(), "domain": row.domain, "eventType": row.eventType, "changedCount": row.changedCount,
             "entityShape": row.entityIDsShape, "metadataShape": row.metadataShape, "entities": row.entityIDsPayloadJSON as Any? ?? NSNull(),
             "metadata": row.metadataPayloadJSON as Any? ?? NSNull(), "status": row.statusRaw, "attempts": row.attemptCount, "maxAttempts": row.maxAttempts,
             "lastError": row.lastErrorCode as Any? ?? NSNull(), "lastErrorKind": row.lastErrorKindRaw, "sourceDevice": row.sourceDeviceID as Any? ?? NSNull()]
        }
        let tables = try Task145T19SQLite.image(url: store, ownedRoot: parent)
        let snapshot: [String: Any] = ["tables": tables, "manifest": try Task145T19Control.encoded(manifest),
            "binding": try Task145T19Control.encoded(binding), "deviceHash": scope.deviceIdentityHash, "journal": NSNull(), "finalized": true,
            "watermark": WatermarkStore().watermark(for: .init(ownerUserID: owner, storeIdentity: scope.storeIdentity)),
            "applyStatus": try Task145T19Control.encoded(statuses),
            "verifiedAt": verified!.timeIntervalSince1970, "verifiedText": verified!.formatted(date: .abbreviated, time: .shortened),
            "verifiedProof": verifiedProof.base64EncodedString(),
            "productFingerprint": LocalPendingChangeLogicalKey.productFingerprintHash(products[0]), "outboxBodies": outboxBodies,
            "backend": try Task145T19Control.encoded(restart.state), "bodyProof": true,
            "emptyDomains": ["prices", "history", "supplier", "category"], "lane": control.mode]
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
        try Task145T19Control.require(controller.activeManifest == manifest && stateStore.state.phase == .idle, "snapshot_fence_changed")
        return snapshot
    }

    func t19ValidateRepeated(before: [String: Any], after: [String: Any]) throws {
        // Full raw images are retained. The transport has exactly two increasing event IDs,
        // unchanged body/revision. Only CoreData row bookkeeping and local-body-proof time
        // can change in SQLite; pending intent, sent event, all body columns stay equal.
        try Task145T19Control.require(before["watermark"] as? Int == 42 && after["watermark"] as? Int == 44, "variant_watermark")
        for key in ["manifest", "binding", "deviceHash", "journal", "finalized", "verifiedAt", "verifiedText", "verifiedProof", "productFingerprint", "outboxBodies", "backend", "bodyProof", "emptyDomains", "lane"] {
            try Task145T19Control.require(try Task145T19Control.json(before[key] as Any? ?? NSNull()) == Task145T19Control.json(after[key] as Any? ?? NSNull()), "variant_" + key)
        }
        guard let statuses = after["applyStatus"] as? [String: Any], let prior = before["applyStatus"] as? [String: Any] else { throw Task145T19Error(code: "variant_status_shape") }
        try Task145T19Control.require(Set(statuses.keys) == Set(prior.keys).union(["43", "44"]), "variant_status_ids")
        for id in prior.keys { try Task145T19Control.require(try Task145T19Control.json(prior[id]!) == Task145T19Control.json(statuses[id]!), "prior_event_changed") }
        for id in ["43", "44"] {
            guard let row = statuses[id] as? [String: Any] else { throw Task145T19Error(code: "variant_status") }
            try Task145T19Control.require(row["status"] as? String == "applied" && row["attemptCount"] as? Int == 1, "variant_not_applied_once")
        }
        guard let old = before["tables"] as? [String: Any], let new = after["tables"] as? [String: Any] else { throw Task145T19Error(code: "variant_tables") }
        try Task145T19Control.require(Set(old.keys) == Set(new.keys), "variant_schema_inventory")
        for name in old.keys {
            guard var left = old[name] as? [String: Any], var right = new[name] as? [String: Any],
                  let columns = left["columns"] as? [String], columns == right["columns"] as? [String],
                  let leftRows = left["rows"] as? [[[String: Any]]], let rightRows = right["rows"] as? [[[String: Any]]] else { throw Task145T19Error(code: "variant_table_shape") }
            try Task145T19Control.require(leftRows.count == rightRows.count, "variant_duplicate_row_" + name)
            try Task145T19Control.require(try Task145T19Control.json(left.filter { $0.key != "rows" }) == Task145T19Control.json(right.filter { $0.key != "rows" }), "variant_table_metadata_" + name)
            // CoreData may allocate a replacement localOnly body-proof row and advance its
            // table PK counter. No other table may change; actual logical rows checked above.
            if name == "Z_PRIMARYKEY" {
                guard let nameIndex = columns.firstIndex(of: "Z_NAME"), let maxIndex = columns.firstIndex(of: "Z_MAX") else { throw Task145T19Error(code: "primary_key_schema") }
                var matched = Set<Int>()
                for oldRow in leftRows {
                    guard let entity = oldRow[nameIndex]["value"] as? String,
                          let index = rightRows.firstIndex(where: { $0[nameIndex]["value"] as? String == entity }) else { throw Task145T19Error(code: "primary_key_entity") }
                    try Task145T19Control.require(matched.insert(index).inserted, "primary_key_duplicate")
                    var newRow = rightRows[index]
                    if entity == "SyncEventOutboxEntry" {
                        guard oldRow[maxIndex]["type"] as? Int32 == SQLITE_INTEGER,
                              newRow[maxIndex]["type"] as? Int32 == SQLITE_INTEGER,
                              let oldText = oldRow[maxIndex]["value"] as? String, let oldMax = Int64(oldText),
                              let newText = newRow[maxIndex]["value"] as? String, let newMax = Int64(newText) else { throw Task145T19Error(code: "primary_key_counter") }
                        try Task145T19Control.require(newMax >= oldMax && newMax - oldMax <= 1, "primary_key_allocation_bound")
                        newRow[maxIndex]["value"] = oldRow[maxIndex]["value"]
                    }
                    try Task145T19Control.require(try Task145T19Control.json(oldRow) == Task145T19Control.json(newRow), "primary_key_unexpected_delta")
                }
                try Task145T19Control.require(matched.count == rightRows.count, "primary_key_inventory")
                continue
            }
            let ignored: Set<String> = name == "ZPRODUCT" ? ["Z_OPT"] : []
            func normalized(_ rows: [[[String: Any]]]) throws -> [String] {
                try rows.map { cells in
                    var selected = cells
                    var omit = ignored
                    if name == "ZSYNCEVENTOUTBOXENTRY", let i = columns.firstIndex(of: "ZDOMAIN"), cells[i]["value"] as? String == LocalCatalogBodyProofStore.domain {
                        omit.formUnion(["Z_PK", "Z_OPT", "ZCREATEDAT", "ZUPDATEDAT", "ZNEXTRETRYAT"])
                    }
                    selected = selected.enumerated().filter { !omit.contains(columns[$0.offset]) }.map(\.element)
                    return String(decoding: try Task145T19Control.json(selected), as: UTF8.self)
                }.sorted()
            }
            left["rows"] = try normalized(leftRows); right["rows"] = try normalized(rightRows)
            try Task145T19Control.require(try Task145T19Control.json(left) == Task145T19Control.json(right), "variant_unexpected_table_diff_" + name)
        }
    }
}
// TASK145_T19_INSERT_END observation

#endif
