import Foundation

nonisolated enum ShopSyncRecoveryLedgerOpenMode: Sendable {
    case createReplacingExisting
    case readExisting
}

/// A redacted, generation-scoped proof ledger. It contains only remote IDs,
/// canonical timestamps, relationship IDs, hashes and image verification
/// metadata; names, payloads, URLs, object paths and credentials are excluded.
/// The receipt used for activation is always reconstructed from the persisted
/// files, never trusted from the in-memory download stream.
nonisolated final class ShopSyncRecoveryLedger: @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private var handles: [ShopSyncRecoveryDomain: FileHandle] = [:]
    private var writtenBytes: [ShopSyncRecoveryDomain: Int] = [:]
    private var writtenRows: [ShopSyncRecoveryDomain: Int] = [:]
    private var totalWrittenBytes = 0

    init(
        generationStoreURL: URL,
        fileManager: FileManager = .default,
        mode: ShopSyncRecoveryLedgerOpenMode = .createReplacingExisting
    ) throws {
        self.fileManager = fileManager
        self.directory = generationStoreURL.deletingLastPathComponent()
            .appendingPathComponent("recovery-ledger-v1", isDirectory: true)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
        switch mode {
        case .createReplacingExisting:
            try reset()
        case .readExisting:
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: .products)
            }
            try validatePersistedResourceBudget()
        }
    }

    deinit {
        for handle in handles.values {
            try? handle.close()
        }
    }

    func append(
        _ record: ShopSyncRecoveryLedgerRecord,
        domain: ShopSyncRecoveryDomain
    ) throws {
        let handle = try writableHandle(for: domain)
        var encoded = try encoder.encode(record)
        encoded.append(0x0A)
        let currentDomainBytes = writtenBytes[domain, default: 0]
        let currentDomainRows = writtenRows[domain, default: 0]
        let (nextDomainBytes, domainOverflow) = currentDomainBytes.addingReportingOverflow(
            encoded.count
        )
        let (nextTotalBytes, totalOverflow) = totalWrittenBytes.addingReportingOverflow(
            encoded.count
        )
        let (nextDomainRows, rowOverflow) = currentDomainRows.addingReportingOverflow(1)
        guard encoded.count <= ShopSyncRecoveryLimits.maximumLedgerRecordBytes,
              !domainOverflow,
              nextDomainBytes <= ShopSyncRecoveryLimits.maximumLedgerBytesPerDomain,
              !totalOverflow,
              nextTotalBytes <= ShopSyncRecoveryLimits.maximumLedgerBytesTotal,
              !rowOverflow,
              nextDomainRows <= ShopSyncRecoveryLimits.maximumRows(for: domain) else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
        }
        try handle.write(contentsOf: encoded)
        writtenBytes[domain] = nextDomainBytes
        writtenRows[domain] = nextDomainRows
        totalWrittenBytes = nextTotalBytes
    }

    func closeWrites() throws {
        let openHandles = handles.values
        handles.removeAll()
        for handle in openHandles {
            try handle.synchronize()
            try handle.close()
        }
    }

    private func forEachRecord(
        for domain: ShopSyncRecoveryDomain,
        _ body: (ShopSyncRecoveryLedgerRecord) throws -> Void
    ) throws {
        guard handles[domain] == nil else {
            throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
        }
        let fileURL = url(for: domain)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let fileBytes = try persistedFileSize(fileURL, domain: domain)
        guard fileBytes <= ShopSyncRecoveryLimits.maximumLedgerBytesPerDomain else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
        }
        guard fileBytes > 0 else { return }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var buffered = Data()
        var rowCount = 0
        while let chunk = try handle.read(upToCount: 64 * 1_024), !chunk.isEmpty {
            buffered.append(chunk)
            while let newline = buffered.firstIndex(of: 0x0A) {
                let line = buffered[..<newline]
                guard !line.isEmpty else {
                    throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
                }
                let (nextRowCount, overflow) = rowCount.addingReportingOverflow(1)
                guard line.count <= ShopSyncRecoveryLimits.maximumLedgerRecordBytes,
                      !overflow,
                      nextRowCount <= ShopSyncRecoveryLimits.maximumRows(for: domain) else {
                    throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
                }
                try body(try decoder.decode(ShopSyncRecoveryLedgerRecord.self, from: Data(line)))
                rowCount = nextRowCount
                buffered.removeSubrange(...newline)
            }
            // A complete record is required to fit in this bound. Refuse an
            // unterminated oversized line without ever mapping the ledger or
            // retaining a whole domain in memory.
            guard buffered.count <= ShopSyncRecoveryLimits.maximumLedgerRecordBytes else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
            }
        }
        guard buffered.isEmpty else {
            throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
        }
    }

    func receipt(
        relationshipViolationCount: Int,
        pendingLocalCount: Int,
        outboxCount: Int
    ) throws -> ShopSyncRecoveryLocalVerificationReceipt {
        let suppliers = try digest(for: .suppliers, expectsIdentity: false)
        let categories = try digest(for: .categories, expectsIdentity: false)
        let products = try digest(for: .products, expectsIdentity: true)
        let prices = try digest(for: .prices, expectsIdentity: false)
        let history = try digest(for: .history, expectsIdentity: false)
        let images = try digest(for: .images, expectsIdentity: false)
        return ShopSyncRecoveryLocalVerificationReceipt(
            suppliers: suppliers,
            categories: categories,
            products: products,
            prices: prices,
            history: history,
            images: images,
            catalogDigest: ShopSyncRecoveryCanonical.sha256(
                suppliers.versionDigest + "\n"
                    + categories.versionDigest + "\n"
                    + products.versionDigest
            ),
            relationshipViolationCount: relationshipViolationCount,
            pendingLocalCount: pendingLocalCount,
            outboxCount: outboxCount
        )
    }

    private func digest(
        for domain: ShopSyncRecoveryDomain,
        expectsIdentity: Bool
    ) throws -> ShopSyncRecoveryEntityDigest {
        var accumulator = ShopSyncRecoveryDigestAccumulator(hasIdentity: expectsIdentity)
        do {
            try forEachRecord(for: domain) { record in
                guard record.idLine == record.orderingID else {
                    throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
                }
                try accumulator.append(
                    orderingID: record.orderingID,
                    idLine: record.idLine,
                    versionLine: record.versionLine,
                    identityLine: record.identityLine,
                    isTombstone: record.isTombstone
                )
            }
            return accumulator.finalize()
        } catch let error as ShopSyncRecoveryContractError {
            // Keep the precise fail-closed budget diagnostic. Collapsing an
            // oversized persisted ledger into a generic corruption error
            // makes bounded recovery indistinguishable from disk damage and
            // defeats the bounded-retry policy.
            throw error
        } catch {
            throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
        }
    }

    private func reset() throws {
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func writableHandle(for domain: ShopSyncRecoveryDomain) throws -> FileHandle {
        if let handle = handles[domain] { return handle }
        let fileURL = url(for: domain)
        guard fileManager.createFile(atPath: fileURL.path, contents: nil) else {
            throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        handles[domain] = handle
        return handle
    }

    private func url(for domain: ShopSyncRecoveryDomain) -> URL {
        directory.appendingPathComponent("\(domain.rawValue).ndjson", isDirectory: false)
    }

    private func validatePersistedResourceBudget() throws {
        var total = 0
        for domain in ShopSyncRecoveryDomain.allCases {
            let fileURL = url(for: domain)
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            let bytes = try persistedFileSize(fileURL, domain: domain)
            guard bytes <= ShopSyncRecoveryLimits.maximumLedgerBytesPerDomain else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
            }
            let (next, overflow) = total.addingReportingOverflow(bytes)
            guard !overflow, next <= ShopSyncRecoveryLimits.maximumLedgerBytesTotal else {
                throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded
            }
            total = next
        }
    }

    private func persistedFileSize(
        _ url: URL,
        domain: ShopSyncRecoveryDomain
    ) throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let number = attributes[.size] as? NSNumber,
              number.int64Value >= 0,
              number.int64Value <= Int64(Int.max) else {
            throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
        }
        return Int(number.int64Value)
    }
}
