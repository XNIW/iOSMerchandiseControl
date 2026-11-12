#if DEBUG
import Foundation
import CryptoKit

/// External candidate only. Called solely from EditProductView.save; never shipped armed.
@MainActor final class PilotCommitTrace {
    struct Binding: Codable {
        let enabled: Bool
        let runID: String
        let sampleID: String
        let operationID: String
        let nonce: String
        let scopeHash: String
        let entityHash: String
        let oldNameHash: String
        let newNameHash: String
        let mappingProofHash: String
    }
    struct Facts {
        let scopeHash: String
        let entityHash: String
        let oldNameHash: String
        let newNameHash: String
        let nameOnly: Bool
        let priorActivePendingCount: Int
        let pendingTokenHash: String
        let pendingIsFreshUpdate: Bool
    }
    struct Event: Codable {
        let stage: String
        let ns: UInt64
        let tokenHash: String?
    }
    struct Receipt: Codable {
        let binding: Binding
        let clockID: String
        let events: [Event]
        let invalidReason: String?
        let overflow: Bool
    }
    private struct CalibrationReply: Codable {
        let nonce: String
        let clockID: String
        let remoteNS: UInt64
    }
    private static let clockID = "ios-app-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
    private static var consumed = Set<String>()
    static let capacity = 8
    private let binding: Binding
    private let directory: URL
    private var events: [Event] = []
    private var invalidReason: String?
    private var overflow = false
    private var started = false
    private var ended = false

    private init(binding: Binding, directory: URL) {
        self.binding = binding
        self.directory = directory
    }

    static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    private static func isHash(_ s: String) -> Bool {
        s.count == 64 && s.allSatisfy { "0123456789abcdef".contains($0) }
    }
    static func valid(_ b: Binding) -> Bool {
        b.enabled && b.runID.hasPrefix("R2-PILOT-") && b.runID.count <= 80
        && b.sampleID == "PILOT-I2A-NAME"
        && UUID(uuidString: b.operationID) != nil && UUID(uuidString: b.nonce) != nil
        && [b.scopeHash, b.entityHash, b.oldNameHash, b.newNameHash, b.mappingProofHash].allSatisfy(isHash)
        && b.oldNameHash != b.newNameHash
    }

    /// One bounded file read/handshake OUTSIDE the mutation fence. Missing file = default OFF.
    /// The private control directory is provisioned only by a later reviewed test procedure.
    static func prepareOutsideFence() -> PilotCommitTrace? {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexPilotTrace", isDirectory: true)
        let control = directory.appendingPathComponent("source-control.json")
        guard let values = try? control.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey]),
              values.isSymbolicLink != true, let size = values.fileSize, size > 0, size <= 8192,
              let data = try? Data(contentsOf: control), data.count <= 8192,
              let binding = try? JSONDecoder().decode(Binding.self, from: data), valid(binding),
              !consumed.contains(binding.operationID), consumed.count < 2 else { return nil }
        consumed.insert(binding.operationID)
        let trace = PilotCommitTrace(binding: binding, directory: directory)
        // nativeNS occurs after the host-created nonce, before the host observes this reply.
        let reply = CalibrationReply(nonce: binding.nonce, clockID: clockID, remoteNS: now())
        let target = directory.appendingPathComponent("\(binding.operationID)-calibration.json")
        guard !FileManager.default.fileExists(atPath: target.path),
              let encoded = try? JSONEncoder().encode(reply) else { return nil }
        do { try encoded.write(to: target, options: .atomic) }
        catch { return nil } // no raw error/log; missing reply prevents qualification
        return trace
    }

    static func qualifies(_ f: Facts, binding b: Binding) -> Bool {
        valid(b) && f.scopeHash == b.scopeHash && f.entityHash == b.entityHash
        && f.oldNameHash == b.oldNameHash && f.newNameHash == b.newNameHash
        && f.nameOnly && f.priorActivePendingCount == 0 && f.pendingIsFreshUpdate
        && isHash(f.pendingTokenHash) && f.oldNameHash != f.newNameHash
    }

    /// Pure metadata/clock/bounded memory only; no file, await, network, or database work.
    func begin(_ facts: Facts) {
        guard !started, !ended, Self.qualifies(facts, binding: binding) else {
            invalidReason = "BINDING_OR_NAME_MUTATION_MISMATCH"; return
        }
        started = true
        append(Event(stage: "commit_call_begin", ns: Self.now(), tokenHash: facts.pendingTokenHash))
    }
    func returned() {
        let timestamp = Self.now()
        guard started, !ended, invalidReason == nil else {
            invalidReason = "MISSING_OR_DUPLICATE_BEGIN"; return
        }
        ended = true
        append(Event(stage: "commit_return", ns: timestamp, tokenHash: nil))
    }
    func failed() {
        ended = true
        invalidReason = "SAVE_THROWN" // preserve original app error/rollback behavior
    }
    private func append(_ event: Event) {
        guard events.count < Self.capacity else { overflow = true; invalidReason = "OVERFLOW"; return }
        events.append(event)
    }
    /// Invoked by defer after the fence has unwound. Export failure leaves no qualified receipt.
    func exportOutsideFence() {
        if !started || !ended { invalidReason = invalidReason ?? "NO_QUALIFIED_COMMIT" }
        let receipt = Receipt(binding: binding, clockID: Self.clockID, events: events,
                              invalidReason: invalidReason, overflow: overflow)
        let target = directory.appendingPathComponent("\(binding.operationID)-commit.json")
        guard !FileManager.default.fileExists(atPath: target.path),
              let encoded = try? JSONEncoder().encode(receipt), encoded.count <= 16384 else { return }
        try? encoded.write(to: target, options: .atomic)
    }
}
#endif
#if DEBUG
import Darwin

nonisolated struct PilotB6RenderWitness: Sendable {
    let operationID: String
    let cycleID: String
    let applyID: String
    let entityRemoteID: UUID
    let projectionHash: String
    let commitNS: UInt64
}

extension PilotCommitTrace {
    nonisolated struct B6Binding: Codable, Sendable {
        let operationID: String
        let sampleID: String
        let role: String
        let category: String
        var scopeHash: String?
        let manifestHash: String
        let authPreflightHash: String
        let twoCASReceiptHash: String
        let artifactHash: String
        let entityRemoteID: UUID?
        let expectedLocalBodyHash: String
        let expectedVisibleFields: [String: String]
        let baselineVisibleFields: [String: String]
        let route: String
        var parentRemoteID: UUID? = nil
        var expectedParentBodyHash: String? = nil
        var expectedBarcode: String? = nil
        var bodySemantics: String = "product_fields_v1"
        var baselineLocalBodyHash: String? = nil
        var timingMethod: String? = nil
        var sourceAdmissionNonce: String? = nil
        var scopeBindingMethod: String? = nil
        var persistentScopeHash: String? = nil
    }
    nonisolated struct B6Event: Codable, Sendable {
        let stage: String
        let ns: UInt64
        let cycleID: String?
        let applyID: String?
        let bodyHash: String?
        let versionHash: String?
        let tokenHash: String?
        var relatedBodyHash: String? = nil
        var observedEntityRemoteID: UUID? = nil
        var bodyValueJSON: String? = nil
        var versionRaw: String? = nil
        var deletedAtRaw: String? = nil
        var priorTokenHash: String? = nil
        var entityLocalID: UUID? = nil
        var localRevision: Int? = nil
        var causalSequence: Int? = nil
        var causalEarliestHookNS: UInt64? = nil
    }
    nonisolated struct B6CausalSourceWitness: Sendable {
        let nativeNS: UInt64
        let nonce: String
        let tracePrefixRaw: String
        let tracePrefixSHA256: String
        let traceEventCount: Int
        let sourceIdleState: [String: Int]
    }
    nonisolated struct B6Receipt: Codable, Sendable {
        let binding: B6Binding
        let bootID: String
        let processID: Int32
        let clockID: String
        let events: [B6Event]
        let invalidReason: String?
        let nativeAcceptance: Bool
        var resolvedEntityRemoteID: UUID? = nil
        var observationComplete: Bool = false
        var originalIntent: LocalPendingChangeCASToken? = nil
        var preparedIntent: LocalPendingChangeCASToken? = nil
        var runtime_scope_proof_sha256: String? = nil
    }
    nonisolated struct B6Cycle: Sendable {
        let operationID: String
        let id: String
        let scope: Task126VerifiedOwnerStoreScope
    }
    nonisolated struct B6Apply: Sendable {
        let operationID: String
        let cycleID: String
        let id: String
        let targetID: UUID
    }
    nonisolated enum B6Context {
        @TaskLocal static var cycle: B6Cycle?
        @TaskLocal static var apply: B6Apply?
        @TaskLocal static var localLeaseGeneration: UInt64?
    }
    nonisolated private struct B6RuntimeScopeContext: Sendable {
        let scope: Task126VerifiedOwnerStoreScope
        let harnessAuthGeneration: UUID
        let predeclaredBindingSHA256: String
        let persistentRaw: String
        let persistentSHA256: String
    }
    nonisolated private final class B6State: @unchecked Sendable {
        let lock = NSLock()
        var binding: B6Binding?
        var runtimeScopeContext: B6RuntimeScopeContext?
        var runtimeScopeProofRaw: String?
        var runtimeScopeProofSHA256: String?
        var bootID = ""
        var consumed = Set<String>()
        var consumedCausalSourceNonces = Set<String>()
        var expiresNS: UInt64 = 0
        var events: [B6Event] = []
        var invalid: String?
        var sourceActionTicket: String?
        var localTicket: String?
        var primaryTokenHash: String?
        var originalIntent: LocalPendingChangeCASToken?
        var preparedIntent: LocalPendingChangeCASToken?
        var sourceLocalID: UUID?
        var sourceRevision: Int?
        var sourceBodyHash: String?
        var sourceValueJSON: String?
        var resolvedID: UUID?
        var activeApply: B6Apply?
        var committed: B6Apply?
        var committedNS: UInt64?
        var scope: Task126VerifiedOwnerStoreScope?
        var mappedBody: String?
        var mappedVersion: String?
        var mappedVersionRaw: String?
        var mappedDeletedAtRaw: String?
        var mappedValueJSON: String?
        var drew = false
        var causalWitnessNS: UInt64?
        var causalWitnessNonce: String?
        var causalWitnessPrefix: String?
        var causalSourceHookCounts: [String: Int] = ["trigger": 0, "transaction": 0, "seal": 0, "result": 0, "transaction_end": 0]
        func append(_ event: B6Event) {
            guard events.count < 128 else { invalid = invalid ?? "OVERFLOW"; return }
            var recorded = event
            if binding?.timingMethod == "HOST_CAUSAL_UPPER_BOUND_V1" {
                guard recorded.causalSequence == nil else { invalid = invalid ?? "CAUSAL_SEQUENCE_INJECTED"; return }
                recorded.causalSequence = events.count
            }
            events.append(recorded)
        }
        func sourceHook(_ name: String, enteredNS: UInt64) -> Bool {
            guard binding?.timingMethod == "HOST_CAUSAL_UPPER_BOUND_V1" else { return true }
            causalSourceHookCounts[name, default: 0] += 1
            guard let witness = causalWitnessNS, enteredNS > witness else {
                append(.init(stage: "causal_source_hook_rejected", ns: enteredNS, cycleID: nil,
                    applyID: name, bodyHash: nil, versionHash: nil, tokenHash: nil, causalEarliestHookNS: enteredNS))
                invalid = invalid ?? "SOURCE_HOOK_BEFORE_CAUSAL_WITNESS"; return false
            }
            guard causalSourceHookCounts[name] == 1 else {
                append(.init(stage: "causal_source_hook_rejected", ns: enteredNS, cycleID: nil,
                    applyID: name, bodyHash: nil, versionHash: nil, tokenHash: nil, causalEarliestHookNS: enteredNS))
                invalid = invalid ?? "DUPLICATE_CAUSAL_SOURCE_HOOK"; return false
            }
            return true
        }
        func live(_ ns: UInt64) -> B6Binding? {
            guard let binding else { return nil }
            if ns > expiresNS { invalid = invalid ?? "EXPIRED" }
            return invalid == nil ? binding : nil
        }
    }
    nonisolated private static let b6State = B6State()
    nonisolated static let b6CausalTimingMethod = "HOST_CAUSAL_UPPER_BOUND_V1"
    nonisolated static let b6ScopeBindingMethod = "IOS_PERSISTENT_IDENTITY_RUNTIME_SCOPE_V1"
    nonisolated static func b6Now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    nonisolated static func b6Hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    nonisolated private static func b6IsHash(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
    nonisolated static var b6RenderObservationEnabled: Bool {
        b6State.lock.withLock { b6State.live(b6Now())?.role == "peer" }
    }
    nonisolated static var b6ObservationEnabled: Bool {
        b6State.lock.withLock { b6State.live(b6Now()) != nil }
    }
    /// Explicit normal-session harness admission only. The legacy pilot arm/file
    /// protocol remains unchanged. No observer performs navigation or starts sync.
    nonisolated static func b6Arm(_ binding: B6Binding) -> Bool {
        b6Arm(binding, runtimeContext: nil)
    }
    /// Only the normal native harness supplies these observed typed values; none
    /// are decoded from the predeclared binding or used to grant business access.
    nonisolated static func b6Arm(_ binding: B6Binding, runtimeScope: Task126VerifiedOwnerStoreScope,
        harnessAuthGeneration: UUID, predeclaredBindingSHA256: String) -> Bool {
        guard binding.scopeBindingMethod == b6ScopeBindingMethod, binding.scopeHash == nil,
              runtimeScope.pendingReplacement == nil, b6IsHash(predeclaredBindingSHA256),
              let identity = b6PersistentScopeIdentity(runtimeScope),
              identity.sha256 == binding.persistentScopeHash else { return false }
        return b6Arm(binding, runtimeContext: .init(scope: runtimeScope,
            harnessAuthGeneration: harnessAuthGeneration, predeclaredBindingSHA256: predeclaredBindingSHA256,
            persistentRaw: identity.raw, persistentSHA256: identity.sha256))
    }
    nonisolated private static func b6Arm(_ binding: B6Binding, runtimeContext: B6RuntimeScopeContext?) -> Bool {
        let hashes = [binding.manifestHash, binding.authPreflightHash,
            binding.twoCASReceiptHash, binding.artifactHash, binding.expectedLocalBodyHash]
        guard UUID(uuidString: binding.operationID) != nil,
              binding.sampleID.range(of: #"^T20-G0[12]-(0[1-9]|[12][0-9]|3[0-3])$"#, options: .regularExpression) != nil,
              b6ScheduleMatches(binding),
              (binding.timingMethod == nil && binding.sourceAdmissionNonce == nil)
                || (binding.timingMethod == b6CausalTimingMethod &&
                    (binding.role == "source" ? binding.sourceAdmissionNonce.flatMap(UUID.init(uuidString:)) != nil
                        : binding.sourceAdmissionNonce == nil)),
              ["source", "peer"].contains(binding.role),
              ["create", "update", "delete", "price", "history"].contains(binding.category),
              hashes.allSatisfy(b6IsHash),
              (binding.scopeBindingMethod == nil && binding.persistentScopeHash == nil &&
                binding.scopeHash.map(b6IsHash) == true && runtimeContext == nil)
                || (binding.scopeBindingMethod == b6ScopeBindingMethod && binding.scopeHash == nil &&
                    binding.persistentScopeHash.map(b6IsHash) == true && runtimeContext != nil &&
                    binding.timingMethod == b6CausalTimingMethod),
              !binding.expectedVisibleFields.isEmpty,
              binding.expectedVisibleFields.count <= 32,
              binding.expectedVisibleFields.allSatisfy({ $0.key.count <= 80 && $0.value.utf8.count <= 512 }),
              !["update", "history"].contains(binding.category) || binding.expectedVisibleFields.contains(where: {
                  binding.baselineVisibleFields[$0.key] != $0.value
              }), b6RouteMatches(binding),
              let bootID = b6BootID() else { return false }
        // Build from one copied native context before taking the observation
        // lock. No filesystem, SDK/storage query, writer lock or host wait here.
        let runtimeProof: (raw: String, sha256: String)?
        if let context = runtimeContext {
            guard let proof = b6MakeRuntimeScopeProof(binding, context: context, bootID: bootID) else { return false }
            runtimeProof = proof
        } else { runtimeProof = nil }
        return b6State.lock.withLock {
            guard b6State.binding == nil, !b6State.consumed.contains(binding.operationID),
                  b6State.consumed.count < 66 else { return false }
            if binding.timingMethod == b6CausalTimingMethod, binding.role == "source" {
                guard let nonce = binding.sourceAdmissionNonce,
                      !b6State.consumedCausalSourceNonces.contains(nonce) else { return false }
                b6State.consumedCausalSourceNonces.insert(nonce)
            }
            b6State.binding = binding; b6State.bootID = bootID
            b6State.runtimeScopeContext = runtimeContext
            b6State.runtimeScopeProofRaw = runtimeProof?.raw
            b6State.runtimeScopeProofSHA256 = runtimeProof?.sha256
            b6State.consumed.insert(binding.operationID)
            b6State.expiresNS = b6Now() + 60_000_000_000
            b6State.events = []; b6State.invalid = nil; b6State.sourceActionTicket = nil; b6State.localTicket = nil
            b6State.primaryTokenHash = nil; b6State.originalIntent = nil; b6State.preparedIntent = nil
            b6State.sourceLocalID = nil; b6State.sourceRevision = nil; b6State.sourceBodyHash = nil; b6State.sourceValueJSON = nil; b6State.resolvedID = binding.entityRemoteID
            b6State.activeApply = nil; b6State.committed = nil; b6State.committedNS = nil
            b6State.scope = nil; b6State.mappedBody = nil; b6State.mappedVersion = nil; b6State.mappedVersionRaw = nil; b6State.mappedDeletedAtRaw = nil; b6State.mappedValueJSON = nil; b6State.drew = false
            b6State.causalWitnessNS = nil; b6State.causalWitnessNonce = nil; b6State.causalWitnessPrefix = nil
            b6State.causalSourceHookCounts = ["trigger": 0, "transaction": 0, "seal": 0, "result": 0, "transaction_end": 0]
            return true
        }
    }
    nonisolated private static func b6RouteMatches(_ binding: B6Binding) -> Bool {
        if binding.category == "delete" {
            return binding.entityRemoteID != nil && binding.route == "database.products.exact-query" &&
                binding.bodySemantics == "product_absence_v1" && binding.parentRemoteID == nil &&
                binding.expectedParentBodyHash == nil && binding.baselineLocalBodyHash.map(b6IsHash) == true &&
                binding.expectedBarcode.map({ !$0.isEmpty && $0.utf8.count <= 100 }) == true &&
                binding.expectedLocalBodyHash == b6DeletedProductBody(binding.entityRemoteID!) &&
                binding.expectedVisibleFields == ["barcodeQuery": binding.expectedBarcode!, "resultCount": "0"]
        }
        if binding.category == "history" {
            return binding.entityRemoteID != nil && binding.route == "history.sessions" &&
                binding.bodySemantics == "history_payload_v1" && binding.parentRemoteID == nil &&
                binding.expectedParentBodyHash == nil
        }
        if binding.category == "price" {
            guard binding.bodySemantics == "price_requested_fields_v1", let parent = binding.parentRemoteID, parent != binding.entityRemoteID,
                  let hash = binding.expectedParentBodyHash, b6IsHash(hash) else { return false }
            let prefix = "database.product-prices.\(parent.uuidString.lowercased())."
            return [prefix + "purchase", prefix + "retail"].contains(binding.route.lowercased())
        }
        guard binding.route == "database.products", binding.parentRemoteID == nil,
              binding.expectedParentBodyHash == nil, binding.bodySemantics == "product_fields_v1" else { return false }
        if binding.category == "create", binding.entityRemoteID == nil {
            guard let barcode = binding.expectedBarcode, !barcode.isEmpty, barcode.utf8.count <= 100 else { return false }
            return true
        }
        return binding.entityRemoteID != nil
    }
    nonisolated static func b6ScheduleMatches(_ binding: B6Binding) -> Bool {
        let parts = binding.sampleID.split(separator: "-")
        guard parts.count == 3, let slot = Int(parts[2]), (1...33).contains(slot),
              String(parts[1]) == (binding.role == "source" ? "G01" : "G02") else { return false }
        let groupOffset = binding.role == "source" ? 0 : 1
        let index = ((slot - 4 + groupOffset) % 5 + 5) % 5
        let category = ["create", "update", "delete", "price", "history"][index]
        return category == binding.category
    }
    nonisolated private static func b6BootID() -> String? {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 1, size < 128 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0 else { return nil }
        return UUID(uuidString: String(cString: bytes))?.uuidString.lowercased()
    }
    nonisolated static func b6ObservationState() -> (terminal: Bool, invalidReason: String?) {
        b6State.lock.withLock {
            guard let binding = b6State.binding else { return (false, "NOT_ARMED") }
            _ = b6State.live(b6Now())
            let terminal = binding.role == "source"
                ? b6State.events.contains(where: { $0.stage == "source_actual_ack_identity_persisted" })
                : b6State.drew
            return (terminal, b6State.invalid)
        }
    }
    nonisolated private static func b6EventsRaw(_ events: [B6Event]) -> String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(events), data.count <= 262_144 else { return nil }
        return String(data: data, encoding: .utf8)
    }
    /// All checks, the witness timestamp and the appended prefix share the real
    /// source-hook lock. No Save, scope acquisition, scheduler or business read.
    nonisolated static func b6CausalSourceIdleWitness(nonce: String) -> B6CausalSourceWitness? {
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "source",
                  binding.timingMethod == b6CausalTimingMethod else { return nil }
            guard nonce == binding.sourceAdmissionNonce, UUID(uuidString: nonce) != nil else {
                b6State.append(.init(stage: "causal_source_witness_rejected", ns: b6Now(), cycleID: nil,
                    applyID: nil, bodyHash: nil, versionHash: nil, tokenHash: nil))
                b6State.invalid = "CAUSAL_SOURCE_NONCE_MISMATCH"; return nil
            }
            guard b6State.causalWitnessNS == nil, b6State.events.isEmpty,
                  b6State.causalSourceHookCounts.values.allSatisfy({ $0 == 0 }),
                  b6State.sourceActionTicket == nil, b6State.localTicket == nil,
                  b6State.primaryTokenHash == nil, b6State.originalIntent == nil,
                  b6State.preparedIntent == nil, b6State.sourceLocalID == nil,
                  b6State.sourceRevision == nil, b6State.sourceBodyHash == nil,
                  b6State.sourceValueJSON == nil, b6State.activeApply == nil,
                  b6State.committed == nil, b6State.invalid == nil else {
                b6State.invalid = b6State.invalid ?? "SOURCE_NOT_IDLE_AT_CAUSAL_WITNESS"; return nil
            }
            let timestamp = b6Now()
            b6State.causalWitnessNS = timestamp; b6State.causalWitnessNonce = nonce
            b6State.append(.init(stage: "causal_source_idle_witness", ns: timestamp, cycleID: nil,
                applyID: nil, bodyHash: nil, versionHash: nil, tokenHash: nil))
            guard let raw = b6EventsRaw(b6State.events), b6State.events.count == 1 else {
                b6State.invalid = "CAUSAL_WITNESS_PREFIX_UNENCODABLE"; return nil
            }
            b6State.causalWitnessPrefix = raw
            return .init(nativeNS: timestamp, nonce: nonce, tracePrefixRaw: raw,
                tracePrefixSHA256: b6Hash(raw), traceEventCount: b6State.events.count,
                sourceIdleState: ["trigger_count": b6State.causalSourceHookCounts["trigger", default: 0],
                    "mutation_ticket_count": b6State.localTicket == nil ? 0 : 1,
                    "transaction_count": b6State.causalSourceHookCounts["transaction", default: 0],
                    "seal_count": b6State.causalSourceHookCounts["seal", default: 0],
                    "source_result_count": b6State.causalSourceHookCounts["result", default: 0]])
        }
    }
    /// The live final/preview path and the deterministic race counterexamples
    /// share this value validator. It accepts no host endpoint or fabricated time.
    nonisolated static func b6CausalSourceEventsFollowWitness(_ events: [B6Event],
        witnessNS: UInt64, witnessPrefixRaw: String) -> Bool {
        guard events.first?.stage == "causal_source_idle_witness", events.first?.ns == witnessNS,
              b6EventsRaw(Array(events.prefix(1))) == witnessPrefixRaw,
              events.enumerated().allSatisfy({ $0.element.causalSequence == $0.offset }),
              events.filter({ $0.stage == "causal_source_idle_witness" }).count == 1 else { return false }
        let entries = events.filter { $0.stage == "source_ui_action_begin" }
        guard entries.count == 1, let entry = entries.first, let entrySequence = entry.causalSequence,
              entrySequence > 0, entry.ns > witnessNS,
              entry.causalEarliestHookNS == entry.ns else { return false }
        let sourceStages: Set<String> = ["source_ui_action_begin", "source_local_mutation_begin",
            "local_commit_call_begin", "local_commit_return", "source_durable_seal_transition",
            "source_actual_ack_identity_persisted"]
        guard events.allSatisfy({ $0.stage == "causal_source_idle_witness" || sourceStages.contains($0.stage) }) else { return false }
        return events.filter { sourceStages.contains($0.stage) }.allSatisfy {
            guard let sequence = $0.causalSequence, let earliest = $0.causalEarliestHookNS,
                  sequence > 0, $0.ns > witnessNS, earliest > witnessNS, earliest <= $0.ns else { return false }
            return $0.stage == "source_ui_action_begin" ||
                (sequence > entrySequence && $0.ns > entry.ns && earliest > entry.ns)
        }
    }
    nonisolated private static func b6CausalSourceTraceValidWithLockHeld() -> Bool {
        guard let binding = b6State.binding, binding.timingMethod == b6CausalTimingMethod else { return true }
        guard b6State.events.enumerated().allSatisfy({ $0.element.causalSequence == $0.offset }) else { return false }
        if binding.role != "source" { return true }
        guard let witness = b6State.causalWitnessNS, let prefix = b6State.causalWitnessPrefix,
              b6State.causalWitnessNonce == binding.sourceAdmissionNonce,
              b6State.events.first?.stage == "causal_source_idle_witness",
              b6EventsRaw(Array(b6State.events.prefix(1))) == prefix,
              b6State.causalSourceHookCounts["trigger"] == 1,
              b6State.causalSourceHookCounts["transaction"] == 1,
              b6State.causalSourceHookCounts["result"] == 1,
              b6State.causalSourceHookCounts["transaction_end"] == 1,
              (binding.category == "price" ? b6State.causalSourceHookCounts["seal"] == 0
                : b6State.causalSourceHookCounts["seal"] == 1) else { return false }
        return b6CausalSourceEventsFollowWitness(b6State.events,
            witnessNS: witness, witnessPrefixRaw: prefix)
    }
    nonisolated private static func b6ReceiptWithLockHeld() -> B6Receipt? {
        guard let binding = b6State.binding else { return nil }
        _ = b6State.live(b6Now())
        let complete = b6State.invalid == nil && b6State.resolvedID != nil &&
            (binding.role == "source" ? b6State.sourceActionTicket != nil && b6State.sourceActionTicket == b6State.localTicket &&
                b6State.sourceValueJSON != nil && b6State.events.contains(where: { $0.stage == "local_commit_return" }) &&
                b6State.events.contains(where: { $0.stage == "source_actual_ack_identity_persisted" }) : b6State.drew)
        let causalValid = b6CausalSourceTraceValidWithLockHeld()
        return B6Receipt(binding: binding, bootID: b6State.bootID,
            processID: ProcessInfo.processInfo.processIdentifier,
            clockID: "ios-uptime-\(b6State.bootID)-\(ProcessInfo.processInfo.processIdentifier)",
            events: b6State.events, invalidReason: b6State.invalid ?? (causalValid ? nil : "CAUSAL_SOURCE_CHAIN_INVALID"),
            nativeAcceptance: false, resolvedEntityRemoteID: b6State.resolvedID,
            observationComplete: complete && causalValid,
            originalIntent: b6State.originalIntent, preparedIntent: b6State.preparedIntent,
            runtime_scope_proof_sha256: b6State.runtimeScopeProofSHA256)
    }
    /// Snapshot only after the original exact source ACK or mapped peer commit
    /// and actual qualified display. It leaves the observer armed for final proof.
    nonisolated static func b6CausalTracePreview() -> (receipt: B6Receipt, traceRaw: String)? {
        b6State.lock.withLock {
            guard b6State.binding?.timingMethod == b6CausalTimingMethod,
                  let receipt = b6ReceiptWithLockHeld(), receipt.observationComplete,
                  receipt.invalidReason == nil, let raw = b6EventsRaw(receipt.events) else { return nil }
            return (receipt, raw)
        }
    }
    nonisolated static func b6ReceiptAndDisarm() -> B6Receipt? {
        b6State.lock.withLock {
            let receipt = b6ReceiptWithLockHeld()
            b6State.binding = nil
            return receipt
        }
    }
    /// The external nonce/response exchange brackets this monotonic read. No
    /// wall timestamp is substituted for RTT/offset or an unobserved server commit.
    nonisolated static func b6Calibration(nonce: String) -> (nonce: String, clockID: String, nativeNS: UInt64, participantPID: Int32, bootHash: String)? {
        guard UUID(uuidString: nonce) != nil else { return nil }
        return b6State.lock.withLock {
            guard b6State.live(b6Now()) != nil else { return nil }
            return (nonce, "ios-uptime-\(b6State.bootID)-\(ProcessInfo.processInfo.processIdentifier)", b6Now(),
                    ProcessInfo.processInfo.processIdentifier, b6Hash(b6State.bootID))
        }
    }
    /// All durable provenance is explicit; this digest grants no runtime lease.
    /// Hash-valued strings keep the canonical raw ASCII and free of credentials.
    nonisolated static func b6PersistentScopeIdentity(_ scope: Task126VerifiedOwnerStoreScope) -> (raw: String, sha256: String)? {
        let store = scope.storeIdentity
        guard b6IsHash(scope.accountHash), b6IsHash(scope.deviceIdentityHash),
              store.storeEpoch >= 0, store.schemaVersion >= 0, store.syncProtocolVersion >= 0 else { return nil }
        let value: [String: Any] = ["kind": "IOS_PERSISTENT_SCOPE_IDENTITY", "schema_version": 1,
            "owner_sha256": b6Hash(scope.ownerUserID.uuidString.lowercased()), "account_hash": scope.accountHash,
            "shop_sha256": b6Hash(scope.shopID.uuidString.lowercased()),
            "device_install_sha256": b6Hash(scope.deviceInstallID), "device_identity_sha256": scope.deviceIdentityHash,
            "store": ["raw_store_sha256": b6Hash(store.rawValue), "default_store_sha256": b6Hash(store.defaultStoreId),
                "local_store_sha256": b6Hash(store.localStoreId), "store_epoch": store.storeEpoch,
                "schema_version": store.schemaVersion, "sync_protocol_version": store.syncProtocolVersion]]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), data.count <= 8192,
              let raw = String(data: data, encoding: .utf8) else { return nil }
        return (raw, b6Hash(raw))
    }
    /// The RawRepresentable store equality is deliberately supplemented by all
    /// six provenance fields and canonical identity from the SAME passed copy.
    nonisolated static func b6RuntimeScopeMatches(current: Task126VerifiedOwnerStoreScope,
        frozen: Task126VerifiedOwnerStoreScope) -> Bool {
        guard current == frozen, current.storeIdentity.hasSameProvenance(as: frozen.storeIdentity),
              let a = b6PersistentScopeIdentity(current), let b = b6PersistentScopeIdentity(frozen) else { return false }
        return a.raw == b.raw && a.sha256 == b.sha256 && b6ScopeHash(current) == b6ScopeHash(frozen)
    }
    nonisolated private static func b6MakeRuntimeScopeProof(_ binding: B6Binding,
        context: B6RuntimeScopeContext, bootID: String) -> (raw: String, sha256: String)? {
        let scope = context.scope, pid = ProcessInfo.processInfo.processIdentifier
        guard context.persistentSHA256 == binding.persistentScopeHash,
              scope.pendingReplacement == nil, let identity = b6PersistentScopeIdentity(scope),
              identity.raw == context.persistentRaw, identity.sha256 == context.persistentSHA256 else { return nil }
        let nativeIdentity: [String: Any] = ["clock_id": "ios-uptime-\(bootID)-\(pid)",
            "participant_pid": pid, "participant_boot_sha256": b6Hash(bootID), "artifact_sha256": binding.artifactHash,
            "device_sha256": b6Hash(scope.deviceInstallID), "ordinary_preflight_sha256": binding.authPreflightHash]
        let proof: [String: Any] = ["kind": "B6_IOS_RUNTIME_SCOPE_PROOF", "schema_version": 1,
            "scope_binding_method": b6ScopeBindingMethod, "operation_id": binding.operationID,
            "manifest_sha256": binding.manifestHash, "predeclared_binding_sha256": context.predeclaredBindingSHA256,
            "role": binding.role, "identity": nativeIdentity,
            "persistent_scope_identity_raw": context.persistentRaw, "persistent_scope_sha256": context.persistentSHA256,
            "legacy_scope_sha256": b6ScopeHash(scope), "lease_generation": scope.leaseGeneration,
            "harness_auth_generation": context.harnessAuthGeneration.uuidString.lowercased(),
            "pending_replacement_present": false, "pending_replacement_sha256": NSNull()]
        guard let data = try? JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys]), data.count <= 16384,
              let raw = String(data: data, encoding: .utf8) else { return nil }
        return (raw, b6Hash(raw))
    }
    nonisolated static func b6RuntimeScopeProof() -> (raw: String, sha256: String)? {
        b6State.lock.withLock {
            guard b6State.live(b6Now())?.scopeBindingMethod == b6ScopeBindingMethod,
                  let raw = b6State.runtimeScopeProofRaw, let sha256 = b6State.runtimeScopeProofSHA256 else { return nil }
            return (raw, sha256)
        }
    }
    nonisolated private static func b6ScopeMatchesWithLockHeld(_ scope: Task126VerifiedOwnerStoreScope) -> Bool {
        guard let binding = b6State.binding else { return false }
        guard binding.scopeBindingMethod != nil else { return binding.scopeHash == b6ScopeHash(scope) }
        guard binding.scopeBindingMethod == b6ScopeBindingMethod, let context = b6State.runtimeScopeContext,
              b6State.runtimeScopeProofSHA256 != nil,
              b6RuntimeScopeMatches(current: scope, frozen: context.scope) else {
            b6State.invalid = b6State.invalid ?? "RUNTIME_SCOPE_CHANGED"; return false
        }
        return true
    }
    nonisolated static func b6ScopeHash(_ scope: Task126VerifiedOwnerStoreScope) -> String {
        b6Hash([scope.ownerUserID.uuidString.lowercased(), scope.accountHash,
            scope.shopID.uuidString.lowercased(), scope.storeIdentity.rawValue,
            scope.storeIdentity.localStoreId, String(scope.storeIdentity.storeEpoch),
            String(scope.storeIdentity.schemaVersion), String(scope.storeIdentity.syncProtocolVersion),
            scope.deviceIdentityHash, String(scope.leaseGeneration)].joined(separator: "|"))
    }
    nonisolated static func b6ProductBody(_ product: Product) -> String {
        b6Hash(SupabaseCatalogFingerprintNormalizer.product(barcode: product.barcode,
            itemNumber: product.itemNumber, productName: product.productName,
            secondProductName: product.secondProductName, purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice, stockQuantity: product.stockQuantity,
            supplierRemoteID: product.supplier?.remoteID, categoryRemoteID: product.category?.remoteID).canonicalString)
    }
    nonisolated private static func b6ValueJSON(_ fields: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
              data.count <= 16_384 else { return nil }
        return String(data: data, encoding: .utf8)
    }
    nonisolated private static func b6Nullable(_ value: String?) -> Any { value.map { $0 as Any } ?? NSNull() }
    nonisolated static func b6ProductValueJSON(_ product: Product) -> String? {
        b6ValueJSON(["barcode": product.barcode, "itemNumber": b6Nullable(product.itemNumber),
            "productName": b6Nullable(product.productName), "secondProductName": b6Nullable(product.secondProductName),
            "purchasePrice": b6Nullable(SupabaseCatalogFingerprintNormalizer.canonicalNumberString(product.purchasePrice)),
            "retailPrice": b6Nullable(SupabaseCatalogFingerprintNormalizer.canonicalNumberString(product.retailPrice)),
            "stockQuantity": b6Nullable(SupabaseCatalogFingerprintNormalizer.canonicalNumberString(product.stockQuantity)),
            "supplierID": b6Nullable(product.supplier?.remoteID?.uuidString.lowercased()),
            "categoryID": b6Nullable(product.category?.remoteID?.uuidString.lowercased())])
    }
    nonisolated static func b6PriceValueJSON(_ price: ProductPrice) -> String? {
        guard let parent = price.product?.remoteID, let amount = PriceCanonicalizer.canonicalAmount(from: price.price) else { return nil }
        return b6ValueJSON(["productID": parent.uuidString.lowercased(), "type": price.type.rawValue.lowercased(),
            "price": amount.value, "effectiveAt": ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt),
            "createdAt": ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt),
            "source": b6Nullable(price.source), "note": b6Nullable(price.note)])
    }
    nonisolated static func b6HistoryValueJSON(_ entry: HistoryEntry) -> String? {
        guard !entry.hasPersistedJSONDecodeFault, let id = entry.remoteID else { return nil }
        let normalize: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return b6ValueJSON(["remoteID": id.uuidString.lowercased(), "payloadVersion": HistorySessionPayloadCodec.payloadVersion,
            "displayName": normalize(entry.title), "timestamp": HistorySessionPayloadCodec.formatTimestamp(entry.timestamp),
            "supplier": normalize(entry.supplier), "category": normalize(entry.category), "isManualEntry": entry.isManualEntry,
            "data": entry.data, "editable": entry.editable, "complete": entry.complete,
            "deletedAt": b6Nullable(entry.remoteDeletedAt.map(HistorySessionPayloadCodec.formatTimestamp))])
    }
    nonisolated private static func b6JSONHash(_ fields: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return b6Hash(text)
    }
    nonisolated static func b6PriceRequestedBody(_ price: ProductPrice) -> String? {
        guard let parent = price.product?.remoteID else { return nil }
        return b6JSONHash(["productID": parent.uuidString.lowercased(), "type": price.type.rawValue,
            "price": PriceCanonicalizer.canonicalAmount(from: price.price)?.value ?? "invalid",
            "source": price.source.map { $0 as Any } ?? NSNull(), "note": price.note.map { $0 as Any } ?? NSNull()])
    }
    nonisolated private static func b6PriceRequestedBody(_ row: RemoteInventoryProductPriceRow) -> String? {
        guard let type = SupabasePullPreviewNormalizer.normalizedPriceType(row.type) else { return nil }
        return b6JSONHash(["productID": row.productID.uuidString.lowercased(), "type": type,
            "price": PriceCanonicalizer.canonicalAmount(from: row.price)?.value ?? "invalid",
            "source": SupabasePullPreviewNormalizer.semanticString(row.source).map { $0 as Any } ?? NSNull(),
            "note": SupabasePullPreviewNormalizer.semanticString(row.note).map { $0 as Any } ?? NSNull()])
    }
    nonisolated private static func b6TokenHash(_ token: LocalPendingChangeCASToken) -> String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let raw = try? encoder.encode(token), let value = String(data: raw, encoding: .utf8) else { return nil }
        return b6Hash(value)
    }
    nonisolated static func b6PriceBody(_ price: ProductPrice) -> String? {
        guard let parent = price.product?.remoteID else { return nil }
        let fields: [String: Any] = [
            "productID": parent.uuidString.lowercased(), "type": price.type.rawValue,
            "price": PriceCanonicalizer.canonicalAmount(from: price.price)?.value ?? "invalid",
            "effectiveAt": ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt),
            "createdAt": ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt),
            "source": price.source.map { $0 as Any } ?? NSNull(),
            "note": price.note.map { $0 as Any } ?? NSNull()]
        guard let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return b6Hash(text)
    }
    /// Earliest handler entry, before local staging/fences. This is observation
    /// only: no authority lookup, business query, Save, notification or scheduler.
    nonisolated static func b6SourceMutationBegin(categories: Set<String>) {
        let enteredNS = b6Now()
        guard b6ObservationEnabled else { return }
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "source",
                  categories.contains(binding.category) else { return }
            guard b6State.sourceHook("trigger", enteredNS: enteredNS) else { return }
            guard b6State.sourceActionTicket == nil, b6State.localTicket == nil else {
                b6State.invalid = "MULTIPLE_OR_LATE_SOURCE_ACTIONS"; return
            }
            let ticket = UUID().uuidString
            b6State.sourceActionTicket = ticket
            b6State.append(.init(stage: binding.timingMethod == b6CausalTimingMethod
                ? "source_ui_action_begin" : "source_local_mutation_begin", ns: enteredNS, cycleID: nil,
                applyID: ticket, bodyHash: nil, versionHash: nil, tokenHash: nil,
                causalEarliestHookNS: binding.timingMethod == b6CausalTimingMethod ? enteredNS : nil))
        }
    }
    /// Caller is the existing Save, after business values and own intent have
    /// been staged and immediately before the durable context.save call.
    nonisolated static func b6LocalBegin(product: Product, prices: [ProductPrice] = [],
        intents: [LocalPendingChangeCASToken], scope: Task126VerifiedOwnerStoreScope?) -> String? {
        let causalEnteredNS = b6Now()
        guard b6ObservationEnabled, let scope, B6Context.localLeaseGeneration == scope.leaseGeneration else { return nil }
        let owner = scope.ownerUserID, productID = product.remoteID
        let productBody = b6ProductBody(product)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let raw = try? encoder.encode(intents), let text = String(data: raw, encoding: .utf8) else { return nil }
        let tokenHash = b6Hash(text)
        let price = prices.count == 1 ? prices[0] : nil
        let priceBody = price.flatMap(b6PriceBody), priceRequested = price.flatMap(b6PriceRequestedBody)
        let productValues = b6ProductValueJSON(product), priceValues = price.flatMap(b6PriceValueJSON)
        let tokenHashes = intents.compactMap { token in b6TokenHash(token).map { (token.changeID, $0) } }
        return b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "source" else { return nil }
            guard b6State.sourceHook("transaction", enteredNS: causalEnteredNS),
                  binding.timingMethod != b6CausalTimingMethod || b6State.sourceActionTicket != nil else { return nil }
            let common = b6ScopeMatchesWithLockHeld(scope) && b6State.localTicket == nil &&
                intents.allSatisfy { $0.ownerUserID.flatMap(UUID.init(uuidString:)) == owner &&
                    $0.statusRaw == "pending" && $0.lastAttemptAt == nil && $0.supersededByChangeID == nil &&
                    $0.intendedFingerprintHash.map(b6IsHash) == true &&
                    $0.ownerHash == scope.accountHash && $0.storeId == scope.storeIdentity.storeId &&
                    $0.localStoreId == scope.storeIdentity.localStoreId && $0.storeEpoch == scope.storeIdentity.storeEpoch &&
                    $0.schemaVersion == scope.storeIdentity.schemaVersion && $0.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion }
            let body: String, primary: LocalPendingChangeCASToken
            if binding.category == "price" {
                guard common, let productID, binding.parentRemoteID == productID,
                      binding.expectedParentBodyHash == productBody, let price, let priceBody,
                      priceRequested == binding.expectedLocalBodyHash, intents.count == 2,
                      intents.contains(where: { $0.entityKindRaw == "product" && $0.operationRaw == "update" &&
                          $0.entityRemoteIDRaw.flatMap(UUID.init(uuidString:)) == productID }),
                      let own = intents.first(where: { $0.entityKindRaw == "productPrice" && $0.operationRaw == "upsert" }),
                      own.intendedFingerprintHash == LocalPendingChangeLogicalKey.productPriceFingerprintHash(price),
                      own.logicalKey == LocalPendingChangeLogicalKey.productPrice(productRemoteID: productID,
                          productBarcode: product.barcode, type: price.type, effectiveAt: price.effectiveAt),
                      binding.entityRemoteID == nil || price.remoteID == binding.entityRemoteID else {
                    b6State.invalid = "LOCAL_PRICE_PARENT_INTENT_OR_BODY_MISMATCH"; return nil
                }
                body = priceBody; primary = own
            } else {
                guard common, prices.isEmpty, binding.expectedLocalBodyHash == productBody,
                      intents.count == 1, let intent = intents.first, intent.entityKindRaw == "product",
                      intent.operationRaw == binding.category,
                      intent.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
                      intent.logicalKey == LocalPendingChangeLogicalKey.product(remoteID: productID, barcode: product.barcode),
                      (binding.entityRemoteID != nil ? productID == binding.entityRemoteID :
                        binding.category == "create" && productID == nil && product.barcode == binding.expectedBarcode) else {
                    b6State.invalid = "LOCAL_INTENT_OR_BODY_MISMATCH"; return nil
                }
                body = productBody; primary = intent
            }
            guard let primaryHash = tokenHashes.first(where: { $0.0 == primary.changeID })?.1 else { return nil }
            let ticket = b6State.sourceActionTicket ?? UUID().uuidString; b6State.localTicket = ticket
            b6State.primaryTokenHash = primaryHash; b6State.originalIntent = primary; b6State.sourceBodyHash = body
            b6State.sourceValueJSON = binding.category == "price" ? priceValues : productValues
            b6State.append(.init(stage: "local_commit_call_begin", ns: b6Now(), cycleID: nil,
                applyID: ticket, bodyHash: body, versionHash: nil, tokenHash: tokenHash,
                relatedBodyHash: binding.category == "price" ? productBody : nil,
                observedEntityRemoteID: binding.category == "price" ? price?.remoteID : productID,
                bodyValueJSON: b6State.sourceValueJSON,
                causalEarliestHookNS: binding.timingMethod == b6CausalTimingMethod ? causalEnteredNS : nil))
            return ticket
        }
    }
    /// Observe only the actual writer's successful durable seal. Both full tokens
    /// remain in the receipt; comparison permits exactly the first attempt stamp.
    /// No body, revision, scope, status, or logical identity may be substituted.
    nonisolated static func b6SourcePrepared(original: LocalPendingChangeCASToken,
        sealed: LocalPendingChangeCASToken, scope: Task126VerifiedOwnerStoreScope) {
        let causalEnteredNS = b6Now()
        guard b6ObservationEnabled, original.lastAttemptAt == nil, sealed.lastAttemptAt != nil,
              let oldHash = b6TokenHash(original), let newHash = b6TokenHash(sealed),
              b6OnlyAttemptStampChanged(original, sealed) else { return }
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "source", b6ScopeMatchesWithLockHeld(scope),
                  b6State.originalIntent == original, b6State.primaryTokenHash == oldHash,
                  b6State.preparedIntent == nil,
                  b6State.events.contains(where: { $0.stage == "local_commit_return" }) else { return }
            guard b6State.sourceHook("seal", enteredNS: causalEnteredNS) else { return }
            b6State.preparedIntent = sealed
            b6State.append(.init(stage: "source_durable_seal_transition", ns: b6Now(), cycleID: nil,
                applyID: b6State.localTicket, bodyHash: b6State.sourceBodyHash, versionHash: nil,
                tokenHash: newHash, priorTokenHash: oldHash,
                causalEarliestHookNS: binding.timingMethod == b6CausalTimingMethod ? causalEnteredNS : nil))
        }
    }
    nonisolated private static func b6OnlyAttemptStampChanged(_ original: LocalPendingChangeCASToken,
        _ sealed: LocalPendingChangeCASToken) -> Bool {
        let encoder = JSONEncoder()
        guard let a = try? encoder.encode(original), let b = try? encoder.encode(sealed),
              var av = (try? JSONSerialization.jsonObject(with: a)) as? [String: Any],
              var bv = (try? JSONSerialization.jsonObject(with: b)) as? [String: Any] else { return false }
        av.removeValue(forKey: "lastAttemptAt"); bv.removeValue(forKey: "lastAttemptAt")
        return NSDictionary(dictionary: av).isEqual(to: bv)
    }
    /// Called only after the existing writer has persisted its actual own ACK.
    /// An unchanged price token is allowed; stamped catalog/history tokens must
    /// match the exact observed durable seal, not merely the same change ID.
    nonisolated static func b6SourceIdentityAcknowledged(pending: LocalPendingChangeCASToken,
        remoteID: UUID, rawVersion: String?, scope: Task126VerifiedOwnerStoreScope,
        localID: UUID? = nil, localRevision: Int? = nil, deletedAtRaw: String? = nil) {
        let causalEnteredNS = b6Now()
        guard b6ObservationEnabled, let tokenHash = b6TokenHash(pending), let rawVersion,
              SupabaseRemoteDateParser.parse(rawVersion) != nil else { return }
        let versionHash = b6Hash(rawVersion)
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "source",
                  b6ScopeMatchesWithLockHeld(scope),
                  (binding.category == "price" ? b6State.originalIntent == pending : b6State.preparedIntent == pending),
                  b6State.events.contains(where: { $0.stage == "local_commit_return" }),
                  binding.category != "history" || (localID == b6State.sourceLocalID && localRevision == b6State.sourceRevision) else { return }
            guard b6State.sourceHook("result", enteredNS: causalEnteredNS) else { return }
            guard b6State.resolvedID == nil || b6State.resolvedID == remoteID else {
                b6State.invalid = "SOURCE_IDENTITY_CHANGED"; return
            }
            b6State.resolvedID = remoteID
            b6State.append(.init(stage: "source_actual_ack_identity_persisted", ns: b6Now(), cycleID: nil,
                applyID: b6State.localTicket, bodyHash: b6State.sourceBodyHash, versionHash: versionHash,
                tokenHash: tokenHash, observedEntityRemoteID: remoteID,
                bodyValueJSON: b6State.sourceValueJSON, versionRaw: rawVersion, deletedAtRaw: deletedAtRaw, entityLocalID: localID, localRevision: localRevision,
                causalEarliestHookNS: binding.timingMethod == b6CausalTimingMethod ? causalEnteredNS : nil))
        }
    }
    nonisolated static func b6DeletedProductBody(_ remoteID: UUID) -> String {
        b6Hash("product_absence_v1|\(remoteID.uuidString.lowercased())|deleted")
    }
    nonisolated static func b6HistoryBody(_ entry: HistoryEntry) -> String? {
        guard !entry.hasPersistedJSONDecodeFault, entry.remoteDeletedAt == nil,
              entry.remoteID != nil else { return nil }
        return HistorySessionPayloadCodec.fingerprintHash(for:
            HistorySessionPayloadSnapshotFactory.snapshot(for: entry, ensureRemoteID: false))
    }
    nonisolated private static func b6FreshIntent(_ token: LocalPendingChangeCASToken,
        scope: Task126VerifiedOwnerStoreScope) -> Bool {
        token.ownerUserID.flatMap(UUID.init(uuidString:)) == scope.ownerUserID &&
        token.ownerHash == scope.accountHash && token.storeId == scope.storeIdentity.storeId &&
        token.localStoreId == scope.storeIdentity.localStoreId && token.storeEpoch == scope.storeIdentity.storeEpoch &&
        token.schemaVersion == scope.storeIdentity.schemaVersion && token.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion &&
        token.statusRaw == "pending" && token.lastAttemptAt == nil && token.supersededByChangeID == nil &&
        token.intendedFingerprintHash.map(b6IsHash) == true
    }
    /// Product is the actual pre-delete object. The expected outcome is absence;
    /// its old full body is pinned separately and is never relabeled as deletion.
    nonisolated static func b6LocalDeleteBegin(product: Product, intents: [LocalPendingChangeCASToken],
        scope: Task126VerifiedOwnerStoreScope?) -> String? {
        let causalEnteredNS = b6Now()
        guard b6ObservationEnabled, let scope, B6Context.localLeaseGeneration == scope.leaseGeneration,
              product.remoteDeletedAt == nil, let remoteID = product.remoteID,
              intents.count == 1, let intent = intents.first, b6FreshIntent(intent, scope: scope),
              intent.entityKindRaw == "product", intent.operationRaw == "delete",
              intent.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
              intent.entityRemoteIDRaw.flatMap(UUID.init(uuidString:)) == remoteID,
              intent.logicalKey == LocalPendingChangeLogicalKey.product(remoteID: remoteID, barcode: product.barcode),
              let tokenHash = b6TokenHash(intent) else { return nil }
        let baselineBody = b6ProductBody(product), absence = b6DeletedProductBody(remoteID)
        return b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "source", binding.category == "delete",
                  b6ScopeMatchesWithLockHeld(scope), b6State.localTicket == nil,
                  binding.entityRemoteID == remoteID, binding.expectedBarcode == product.barcode,
                  binding.baselineLocalBodyHash == baselineBody, binding.expectedLocalBodyHash == absence else { return nil }
            guard b6State.sourceHook("transaction", enteredNS: causalEnteredNS),
                  binding.timingMethod != b6CausalTimingMethod || b6State.sourceActionTicket != nil else { return nil }
            let ticket = b6State.sourceActionTicket ?? UUID().uuidString
            b6State.localTicket = ticket; b6State.primaryTokenHash = tokenHash
            b6State.originalIntent = intent; b6State.sourceBodyHash = absence; b6State.sourceValueJSON = "{\"deleted\":true}"
            b6State.append(.init(stage: "local_commit_call_begin", ns: b6Now(), cycleID: nil,
                applyID: ticket, bodyHash: absence, versionHash: nil, tokenHash: tokenHash,
                relatedBodyHash: baselineBody, observedEntityRemoteID: remoteID, bodyValueJSON: b6State.sourceValueJSON,
                causalEarliestHookNS: binding.timingMethod == b6CausalTimingMethod ? causalEnteredNS : nil))
            return ticket
        }
    }
    nonisolated static func b6LocalHistoryBegin(entry: HistoryEntry, intents: [LocalPendingChangeCASToken],
        scope: Task126VerifiedOwnerStoreScope?) -> String? {
        let causalEnteredNS = b6Now()
        guard b6ObservationEnabled, let scope, B6Context.localLeaseGeneration == scope.leaseGeneration,
              let remoteID = entry.remoteID, let body = b6HistoryBody(entry),
              entry.localChangeRevision > entry.lastSyncedLocalRevision,
              entry.isCompatibleWithHistoryScope(ownerUserID: scope.ownerUserID, selectedShopID: scope.shopID,
                  storeIdentity: scope.storeIdentity),
              intents.count == 1, let intent = intents.first, b6FreshIntent(intent, scope: scope),
              intent.entityKindRaw == "historySession", intent.operationRaw == "upsert",
              intent.entityRemoteIDRaw.flatMap(UUID.init(uuidString:)) == remoteID,
              intent.logicalKey == LocalPendingChangeLogicalKey.historySession(remoteID: remoteID, uid: entry.uid),
              intent.intendedFingerprintHash == body, let tokenHash = b6TokenHash(intent) else { return nil }
        return b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "source", binding.category == "history",
                  b6ScopeMatchesWithLockHeld(scope), binding.entityRemoteID == remoteID,
                  b6State.localTicket == nil, binding.expectedLocalBodyHash == body else { return nil }
            guard b6State.sourceHook("transaction", enteredNS: causalEnteredNS),
                  binding.timingMethod != b6CausalTimingMethod || b6State.sourceActionTicket != nil else { return nil }
            let ticket = b6State.sourceActionTicket ?? UUID().uuidString; b6State.localTicket = ticket
            b6State.primaryTokenHash = tokenHash; b6State.originalIntent = intent; b6State.sourceBodyHash = body
            b6State.sourceValueJSON = b6HistoryValueJSON(entry)
            b6State.sourceLocalID = entry.uid; b6State.sourceRevision = entry.localChangeRevision
            b6State.append(.init(stage: "local_commit_call_begin", ns: b6Now(), cycleID: nil,
                applyID: ticket, bodyHash: body, versionHash: nil, tokenHash: tokenHash,
                observedEntityRemoteID: remoteID, bodyValueJSON: b6State.sourceValueJSON, entityLocalID: entry.uid, localRevision: entry.localChangeRevision,
                causalEarliestHookNS: binding.timingMethod == b6CausalTimingMethod ? causalEnteredNS : nil))
            return ticket
        }
    }
    nonisolated static func b6MappedHistory(entry: HistoryEntry, beforeBody: String?, rawVersion: String?) {
        guard let apply = B6Context.apply, entry.remoteID == apply.targetID,
              let body = b6HistoryBody(entry), let beforeBody, beforeBody != body,
              let rawVersion, SupabaseRemoteDateParser.parse(rawVersion) != nil else { return }
        let version = b6Hash(rawVersion)
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.category == "history",
                  b6State.activeApply?.id == apply.id, body == binding.expectedLocalBodyHash else { return }
            b6State.mappedBody = body; b6State.mappedVersion = version
            b6State.mappedVersionRaw = rawVersion; b6State.mappedValueJSON = b6HistoryValueJSON(entry)
        }
    }
    /// Actual tombstone mapping plus prior-live state in the already loaded index.
    /// The visible empty-query witness is separate; no extra query is issued here.
    nonisolated static func b6MappedDeletion(_ apply: B6Apply?, beforeBody: String?, beforeWasLive: Bool,
        product: Product?, row: RemoteInventoryProductRow) {
        let version = row.updatedAt
        guard let apply, let product, product.remoteID == apply.targetID, row.id == apply.targetID,
              beforeWasLive, let beforeBody, let tombstone = product.remoteDeletedAt,
              let rawDeleted = row.deletedAt, SupabaseRemoteDateParser.parse(rawDeleted) == tombstone,
              SupabaseRemoteDateParser.parse(version) != nil else { return }
        let absent = b6DeletedProductBody(row.id), versionHash = b6Hash(version)
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.category == "delete", b6State.activeApply?.id == apply.id,
                  binding.expectedBarcode == product.barcode, binding.baselineLocalBodyHash == beforeBody,
                  binding.expectedLocalBodyHash == absent else { return }
            b6State.mappedBody = absent; b6State.mappedVersion = versionHash
            b6State.mappedVersionRaw = version; b6State.mappedDeletedAtRaw = rawDeleted; b6State.mappedValueJSON = "{\"deleted\":true}"
        }
    }
    nonisolated static func b6LocalEnd(_ ticket: String?, returned: Bool, ns: UInt64) {
        guard let ticket else { return }
        b6State.lock.withLock {
            guard b6State.localTicket == ticket else { return }
            guard b6State.sourceHook("transaction_end", enteredNS: ns) else { return }
            guard !b6State.events.contains(where: { $0.stage == "local_commit_return" || $0.stage == "local_commit_uncertain" }) else {
                b6State.invalid = "DUPLICATE_LOCAL_COMMIT_END"; return
            }
            b6State.append(.init(stage: returned ? "local_commit_return" : "local_commit_uncertain",
                ns: ns, cycleID: nil, applyID: ticket, bodyHash: nil, versionHash: nil, tokenHash: nil,
                causalEarliestHookNS: b6State.binding?.timingMethod == b6CausalTimingMethod ? ns : nil))
            if !returned { b6State.invalid = "LOCAL_SAVE_THROWN_UNCONFIRMED" }
        }
    }
    nonisolated static func b6ReceiverAdmission(scope: Task126VerifiedOwnerStoreScope?, source: String) -> B6Cycle? {
        guard b6ObservationEnabled, let scope, ["foregroundPoll", "remoteSyncEvent"].contains(source) else { return nil }
        return b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "peer", b6ScopeMatchesWithLockHeld(scope) else { return nil }
            let cycle = B6Cycle(operationID: binding.operationID, id: UUID().uuidString, scope: scope)
            b6State.scope = scope
            b6State.append(.init(stage: "receiver_ordinary_admission", ns: b6Now(), cycleID: cycle.id,
                applyID: nil, bodyHash: nil, versionHash: nil, tokenHash: nil))
            return cycle
        }
    }
    nonisolated static func b6BeginApply(cycle: B6Cycle?, productIDs: Set<UUID>, priceIDs: Set<UUID> = [],
        catalogProducts: [RemoteInventoryProductRow] = [], prices: [RemoteInventoryProductPriceRow] = [],
        historyIDs: Set<UUID> = []) -> B6Apply? {
        guard let cycle else { return nil }
        return b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.operationID == cycle.operationID,
                  binding.scopeBindingMethod == nil || b6ScopeMatchesWithLockHeld(cycle.scope) else { return nil }
            var target = b6State.resolvedID
            if target == nil, binding.category == "create", let barcode = binding.expectedBarcode {
                let matches = catalogProducts.filter { $0.barcode == barcode && productIDs.contains($0.id) }
                guard matches.count == 1 else { if matches.count > 1 { b6State.invalid = "AMBIGUOUS_TARGET_IDENTITY" }; return nil }
                target = matches[0].id
            } else if target == nil, binding.category == "price" {
                let matches = prices.filter { priceIDs.contains($0.id) && $0.productID == binding.parentRemoteID &&
                    b6PriceRequestedBody($0) == binding.expectedLocalBodyHash }
                guard matches.count == 1 else { if matches.count > 1 { b6State.invalid = "AMBIGUOUS_TARGET_IDENTITY" }; return nil }
                target = matches[0].id
            }
            guard let target else { return nil }
            let ids = binding.category == "price" ? priceIDs : binding.category == "history" ? historyIDs : productIDs
            if binding.category == "price", let parent = binding.parentRemoteID,
               productIDs.contains(parent), b6State.drew { b6State.invalid = "TARGET_CHANGED_AFTER_DRAW" }
            guard ids.contains(target) else { return nil }
            if b6State.drew { b6State.invalid = "TARGET_CHANGED_AFTER_DRAW" }
            b6State.resolvedID = target
            let apply = B6Apply(operationID: cycle.operationID, cycleID: cycle.id,
                id: UUID().uuidString, targetID: target)
            b6State.activeApply = apply; b6State.committed = nil; b6State.committedNS = nil
            b6State.mappedBody = nil; b6State.mappedVersion = nil; b6State.mappedVersionRaw = nil; b6State.mappedDeletedAtRaw = nil; b6State.mappedValueJSON = nil
            b6State.append(.init(stage: "peer_commit_call_begin", ns: b6Now(), cycleID: cycle.id,
                applyID: apply.id, bodyHash: nil, versionHash: nil, tokenHash: nil, observedEntityRemoteID: target))
            return apply
        }
    }
    nonisolated static func b6MappedProduct(_ apply: B6Apply?, beforeBody: String?, product: Product?, rawVersion: String?) {
        guard let apply, let product, product.remoteID == apply.targetID,
              product.remoteDeletedAt == nil, let rawVersion, SupabaseRemoteDateParser.parse(rawVersion) != nil else { return }
        let body = b6ProductBody(product), version = b6Hash(rawVersion)
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), ["create", "update"].contains(binding.category), b6State.activeApply?.id == apply.id,
                  body == binding.expectedLocalBodyHash,
                  (binding.category == "create" ? beforeBody == nil : beforeBody != nil && beforeBody != body) else { return }
            b6State.mappedBody = body; b6State.mappedVersion = version
            b6State.mappedVersionRaw = rawVersion; b6State.mappedValueJSON = b6ProductValueJSON(product)
        }
    }
    /// Called on the actual mapped price object inside the existing transaction.
    /// TaskLocal apply ties this mapper observation to its exact enclosing commit.
    nonisolated static func b6MappedPrice(_ price: ProductPrice, beforeBody: String?, rawVersion: String?) {
        guard let apply = B6Context.apply, price.remoteID == apply.targetID,
              let body = b6PriceBody(price), beforeBody != body,
              let parent = price.product, parent.remoteDeletedAt == nil,
              let version = rawVersion, SupabaseRemoteDateParser.parse(version) != nil else { return }
        let parentBody = b6ProductBody(parent), versionHash = b6Hash(version)
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.category == "price",
                  b6State.activeApply?.id == apply.id, b6PriceRequestedBody(price) == binding.expectedLocalBodyHash,
                  parent.remoteID == binding.parentRemoteID, parentBody == binding.expectedParentBodyHash else { return }
            b6State.mappedBody = body; b6State.mappedVersion = versionHash
            b6State.mappedVersionRaw = version; b6State.mappedValueJSON = b6PriceValueJSON(price)
        }
    }
    nonisolated static func b6ApplyEnd(_ apply: B6Apply?, returned: Bool, ns: UInt64) {
        guard let apply else { return }
        let notify = b6State.lock.withLock { () -> Bool in
            guard b6State.activeApply?.id == apply.id else { return false }
            b6State.append(.init(stage: returned ? "peer_commit_return" : "peer_commit_uncertain", ns: ns,
                cycleID: apply.cycleID, applyID: apply.id, bodyHash: b6State.mappedBody,
                versionHash: b6State.mappedVersion, tokenHash: nil,
                relatedBodyHash: b6State.binding?.expectedParentBodyHash, bodyValueJSON: b6State.mappedValueJSON, versionRaw: b6State.mappedVersionRaw, deletedAtRaw: b6State.mappedDeletedAtRaw))
            guard returned, b6State.invalid == nil, b6State.mappedBody != nil, b6State.mappedVersion != nil, b6State.mappedValueJSON != nil else {
                b6State.invalid = b6State.invalid ?? "PEER_COMMIT_OR_TARGET_BODY_UNCONFIRMED"; return false
            }
            b6State.committed = apply; b6State.committedNS = ns; return true
        }
        if notify { Task { @MainActor in
            NotificationCenter.default.post(name: .init("TASK145_B6_RECEIVER_COMMIT_RETURNED"), object: nil)
        } }
    }
    static func b6RenderWitness(entityRemoteID: UUID, kind: String, route: String,
        visibleFields: [String: String],
        validateScope: @MainActor (Task126VerifiedOwnerStoreScope) throws -> Void = {
            try Task126OwnerStoreGate.revalidateAutomaticScope($0)
        }) -> PilotB6RenderWitness? {
        guard b6RenderObservationEnabled else { return nil }
        let scope = b6State.lock.withLock { b6State.scope }
        guard let scope, (try? validateScope(scope)) != nil,
              let data = try? JSONSerialization.data(withJSONObject: visibleFields, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return nil }
        let projection = b6Hash(text)
        return b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), let apply = b6State.committed,
                  let ns = b6State.committedNS, apply.id == b6State.activeApply?.id,
                  entityRemoteID == b6State.resolvedID, kind == binding.category, route == binding.route,
                  binding.expectedVisibleFields.allSatisfy({ visibleFields[$0.key] == $0.value }) else { return nil }
            return .init(operationID: binding.operationID, cycleID: apply.cycleID, applyID: apply.id,
                entityRemoteID: entityRemoteID, projectionHash: projection, commitNS: ns)
        }
    }
    nonisolated static func b6Rendered(_ witness: PilotB6RenderWitness, ns: UInt64) {
        b6State.lock.withLock {
            guard let binding = b6State.live(ns), binding.operationID == witness.operationID,
                  b6State.committed?.id == witness.applyID, b6State.activeApply?.id == witness.applyID,
                  b6State.committed?.cycleID == witness.cycleID, b6State.committedNS == witness.commitNS,
                  witness.entityRemoteID == b6State.resolvedID, ns >= witness.commitNS, !b6State.drew else { return }
            b6State.drew = true
            b6State.append(.init(stage: "peer_expected_visible_projection", ns: ns, cycleID: witness.cycleID,
                applyID: witness.applyID, bodyHash: witness.projectionHash, versionHash: nil, tokenHash: nil))
        }
    }
    nonisolated static func b6DeletionCandidate(query: String) -> (entityRemoteID: UUID, barcode: String)? {
        b6State.lock.withLock {
            guard let binding = b6State.live(b6Now()), binding.role == "peer", binding.category == "delete",
                  binding.expectedBarcode == query, let target = b6State.resolvedID,
                  b6State.committed?.id == b6State.activeApply?.id,
                  b6State.mappedBody == b6DeletedProductBody(target), b6State.committedNS != nil else { return nil }
            return (target, query)
        }
    }
}
#endif
