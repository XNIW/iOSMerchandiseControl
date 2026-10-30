import XCTest
import Foundation
import CryptoKit
import Darwin

/// External observer candidate. It never launches/activates/taps/swipes the app.
final class PilotNameObserverTests: XCTestCase {
    struct Binding: Codable {
        let runID: String, sampleID: String, operationID: String, nonce: String
        let scopeHash: String, entityHash: String, mappingProofHash: String
        let barcodeAXLabel: String, oldName: String, newName: String
    }
    struct Query: Codable {
        let sequence: Int, beginNS: UInt64, endNS: UInt64
        let foreground: Bool, uniqueRow: Bool, viewport: Bool, overlayAbsent: Bool
        let oldVisible: Bool, newVisible: Bool
        var contextValid: Bool { foreground && uniqueRow && viewport && overlayAbsent }
        var positive: Bool { contextValid && newVisible && !oldVisible }
        var baseline: Bool { contextValid && oldVisible && !newVisible }
    }
    private let clockID = "ios-observer-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
    private func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    private func emit(_ fields: [String: Any]) throws {
        let bytes = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        guard bytes.count <= 196608 else { throw Failure.overflow }
        FileHandle.standardOutput.write(bytes + Data([10]))
    }
    enum Failure: Error { case missingBinding, invalidBinding, calibration, baseline, context, overflow, timeout }
    private func binding() throws -> Binding {
        guard let raw = ProcessInfo.processInfo.environment["CODEX_PILOT_OBSERVER_BINDING"],
              raw.utf8.count <= 8192 else { throw Failure.missingBinding }
        let b = try JSONDecoder().decode(Binding.self, from: Data(raw.utf8))
        let hashes = [b.scopeHash,b.entityHash,b.mappingProofHash]
        guard b.runID.hasPrefix("R2-PILOT-"), b.runID.count <= 80,
              b.sampleID == "PILOT-A2I-NAME", UUID(uuidString: b.operationID) != nil,
              UUID(uuidString: b.nonce) != nil,
              hashes.allSatisfy({ $0.count == 64 && $0.allSatisfy { "0123456789abcdef".contains($0) } }),
              b.oldName.hasPrefix("CODEX_SYNC_"), b.newName.hasPrefix("CODEX_SYNC_"),
              b.oldName != b.newName, b.oldName.count <= 255, b.newName.count <= 255,
              b.barcodeAXLabel.contains("CODEX"), b.barcodeAXLabel.count <= 255 else { throw Failure.invalidBinding }
        return b
    }
    private func calibration(_ b: Binding, directory: URL) throws {
        let request = directory.appendingPathComponent("calibration-nonce.txt")
        guard !FileManager.default.fileExists(atPath: request.path) else { throw Failure.calibration }
        try emit(["stage":"READY_FOR_NONCE", "operation_id":b.operationID, "request_path":request.path])
        let deadline = now() + 30_000_000_000
        while now() < deadline {
            if let attrs = try? request.resourceValues(forKeys: [.fileSizeKey,.isSymbolicLinkKey]),
               attrs.isSymbolicLink != true, let size = attrs.fileSize, size <= 64,
               let bytes = try? Data(contentsOf: request), bytes.count <= 64 {
                guard String(data: bytes, encoding: .utf8) == b.nonce else { throw Failure.calibration }
                let nativeNS = now()
                try emit(["stage":"CALIBRATION_REPLY", "operation_id":b.operationID,
                          "nonce":b.nonce,"clock_id":clockID,"remote_ns":nativeNS])
                return
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        throw Failure.calibration
    }
    private func query(_ app: XCUIApplication, _ b: Binding, sequence: Int) -> (Query, XCUIElement?) {
        let begin = now()
        let foreground = app.state == .runningForeground
        let windows = app.windows.allElementsBoundByIndex
        let overlayAbsent = app.alerts.count == 0 && app.sheets.count == 0 && app.keyboards.count == 0
        let rows = app.cells.containing(.staticText, identifier: b.barcodeAXLabel).allElementsBoundByIndex
        let row = rows.count == 1 ? rows.first : nil
        var viewport = false, old = false, new = false
        if let row, windows.count == 1 {
            let name = row.staticTexts.matching(NSPredicate(format: "label == %@", b.newName))
            let previous = row.staticTexts.matching(NSPredicate(format: "label == %@", b.oldName))
            let identity = row.staticTexts.matching(NSPredicate(format: "label == %@", b.barcodeAXLabel))
            viewport = !row.frame.isEmpty && windows[0].frame.contains(row.frame)
                && row.isHittable && identity.count == 1 && identity.element.isHittable
            old = previous.count == 1 && previous.element.isHittable
            new = name.count == 1 && name.element.isHittable && row.frame.contains(name.element.frame)
        }
        return (Query(sequence: sequence, beginNS: begin, endNS: now(), foreground: foreground,
                      uniqueRow: rows.count == 1, viewport: viewport, overlayAbsent: overlayAbsent,
                      oldVisible: old, newVisible: new), row)
    }
    func testObserveOnePreparedNameUpdate() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CODEX_PILOT_OBSERVER_BINDING"] != nil,
                          "Legacy name observer requires its explicit binding.")
        let b = try binding() // Missing binding is an error, never an empty successful test.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("codex-pilot-\(b.operationID)")
        guard !FileManager.default.fileExists(atPath: directory.path) else { throw Failure.invalidBinding }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try calibration(b, directory: directory)
        let app = XCUIApplication(bundleIdentifier: "com.niwcyber.iOSMerchandiseControl")
        var queries: [Query] = []
        let first = query(app,b,sequence:0).0
        queries.append(first)
        guard first.baseline else { throw Failure.baseline }
        try emit(["stage":"BASELINE_READY","operation_id":b.operationID,"clock_id":clockID,
                  "negative_begin_ns":first.beginNS,"negative_end_ns":first.endNS])
        let deadline = now() + 30_000_000_000
        var positiveScreenshot: XCTAttachment?
        var outcome = "TIMEOUT"
        while now() < deadline && queries.count < 240 {
            Thread.sleep(forTimeInterval: 0.1)
            let (q,row) = query(app,b,sequence:queries.count)
            if q.positive, let row {
                let screenshot = XCTAttachment(screenshot: row.screenshot())
                screenshot.name = "pilot-peer-row-\(b.operationID)"; screenshot.lifetime = .keepAlways
                let confirmation = query(app,b,sequence:queries.count)
                guard confirmation.0.positive else { queries.append(confirmation.0); outcome = "UI_CHANGED_DURING_CAPTURE"; break }
                // The positive query bracket includes row screenshot and confirmation, never subtracting query cost.
                queries.append(Query(sequence:q.sequence,beginNS:q.beginNS,endNS:now(),foreground:q.foreground,
                                     uniqueRow:q.uniqueRow,viewport:q.viewport,overlayAbsent:q.overlayAbsent,
                                     oldVisible:q.oldVisible,newVisible:q.newVisible))
                positiveScreenshot = screenshot; outcome = "FIRST_POSITIVE_OBSERVED"; break
            }
            queries.append(q)
            if !q.contextValid { outcome = "OBSERVATION_CONTEXT_LOST"; break }
        }
        if queries.count >= 240 && positiveScreenshot == nil { outcome = "OVERFLOW" }
        let data = try JSONEncoder().encode(queries)
        let queryJSON = try JSONSerialization.jsonObject(with:data)
        try emit(["stage":"OBSERVER_RESULT","run_id":b.runID,"operation_id":b.operationID,"sample_id":b.sampleID,"nonce":b.nonce,
                  "old_name_hash":SHA256.hash(data:Data(b.oldName.utf8)).map { String(format:"%02x",$0) }.joined(),
                  "new_name_hash":SHA256.hash(data:Data(b.newName.utf8)).map { String(format:"%02x",$0) }.joined(),
                  "scope_hash":b.scopeHash,"entity_hash":b.entityHash,"mapping_proof_hash":b.mappingProofHash,
                  "clock_id":clockID,"outcome":outcome,"queries":queryJSON])
        if let screenshot = positiveScreenshot { add(screenshot) }
        XCTAssertEqual(outcome,"FIRST_POSITIVE_OBSERVED")
    }
}

// B6 extends the existing external pilot observer. No app launch, navigation,
// input, sync trigger, DB query, or in-process display callback is used here.
extension PilotNameObserverTests {
    struct B6VisibleBinding: Codable {
        let operationID: String, sampleID: String, category: String
        let initialNonce: String, finalNonce: String
        let scopeHash: String, targetDeviceHash: String, targetArtifactHash: String
        let observerArtifactHash: String, targetRuntimeHash: String
        let fixtureProofHash: String, ordinaryPreflightHash: String
        let route: String, routeAnchor: String, rootIdentifier: String?
        let rowIdentity: String, baselineAnchor: String
        let beforeFields: [String], afterFields: [String], absentAfterFields: [String]
        let expectedSearchValue: String?, emptyResultLabel: String?
        let priceSheet: Bool
        var timingMethod: String? = nil
        var visibilityConfirmationNonce: String? = nil
    }
    private static let b6CausalTimingMethod = "HOST_CAUSAL_UPPER_BOUND_V1"
    struct B6VisibleQuery: Encodable {
        let sequence: Int, beginNS: UInt64, endNS: UInt64, phase: String
        let foreground: Bool, uniqueRow: Bool, viewport: Bool, overlayAbsent: Bool
        let before: Bool, after: Bool, exactQuery: Bool
        let matchedLabels: [String], labelsSHA256: String, frame: [Double], windowFrame: [Double]
        enum CodingKeys: String, CodingKey {
            case sequence, beginNS, endNS, phase, foreground, uniqueRow, viewport, overlayAbsent
            case before, after, exactQuery, labelsSHA256, frame, windowFrame
        }
        var contextValid: Bool { foreground && uniqueRow && viewport && overlayAbsent && exactQuery }
    }
    enum B6VisibleFailure: String, Error {
        case binding, artifact, boot, nonce, baseline, context, overflow, timeout, changedDuringCapture
        case causalMethod, causalNonce
    }
    private func b6Hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func b6Boot() throws -> String {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0,
              size > 1, size < 128 else { throw B6VisibleFailure.boot }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0,
              let id = UUID(uuidString: String(cString: bytes)) else { throw B6VisibleFailure.boot }
        return b6Hash(Data(id.uuidString.lowercased().utf8))
    }
    private func b6Write(_ object: Any, to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard data.count <= 196608, !FileManager.default.fileExists(atPath: url.path) else { throw B6VisibleFailure.overflow }
        try data.write(to: url, options: .withoutOverwriting)
        let file = try FileHandle(forWritingTo: url)
        try file.synchronize(); try file.close()
    }
    private func b6WriteCausal(_ object: Any, to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard data.count <= 524_288, !FileManager.default.fileExists(atPath: url.path) else { throw B6VisibleFailure.overflow }
        try data.write(to: url, options: .withoutOverwriting)
        let file = try FileHandle(forWritingTo: url)
        try file.synchronize(); try file.close()
    }
    static func b6Validate(_ b: B6VisibleBinding) -> Bool {
        let hashes = [b.scopeHash,b.targetDeviceHash,b.targetArtifactHash,b.observerArtifactHash,
                      b.targetRuntimeHash,b.fixtureProofHash,b.ordinaryPreflightHash]
        let fields = b.beforeFields + b.afterFields + b.absentAfterFields +
            [b.routeAnchor,b.rowIdentity,b.baselineAnchor]
        guard UUID(uuidString: b.operationID) != nil, UUID(uuidString: b.initialNonce) != nil,
              UUID(uuidString: b.finalNonce) != nil, b.initialNonce != b.finalNonce,
              (b.timingMethod == nil && b.visibilityConfirmationNonce == nil)
                || (b.timingMethod == b6CausalTimingMethod &&
                    b.visibilityConfirmationNonce.flatMap(UUID.init(uuidString:)) != nil &&
                    b.visibilityConfirmationNonce != b.initialNonce && b.visibilityConfirmationNonce != b.finalNonce),
              b.sampleID.range(of: "^T20-G02-(0[1-9]|[12][0-9]|3[0-3])$", options: .regularExpression) != nil,
              ["create","update","delete","price","history"].contains(b.category),
              hashes.allSatisfy({ $0.count == 64 && $0.allSatisfy { "0123456789abcdef".contains($0) } }),
              (1...12).contains(b.beforeFields.count), (1...12).contains(b.afterFields.count),
              b.absentAfterFields.count <= 12,
              fields.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 255 }),
              b.beforeFields != b.afterFields else { return false }
        let expected: String
        switch b.category {
        case "create", "update": expected = "database.products"
        case "delete": expected = "database.products.exact-query"
        case "history": expected = "history.sessions"
        default:
            let parts = b.route.split(separator: ".")
            expected = parts.count == 4 && parts[0] == "database" && parts[1] == "product-prices" &&
                UUID(uuidString: String(parts[2])) != nil && ["purchase","retail"].contains(String(parts[3])) ? b.route : ""
        }
        guard !expected.isEmpty, b.route == expected, b.priceSheet == (b.category == "price") else { return false }
        if b.category == "delete" {
            guard let query = b.expectedSearchValue, !query.isEmpty, query.utf8.count <= 100,
                  let empty = b.emptyResultLabel, !empty.isEmpty, empty.utf8.count <= 255 else { return false }
        } else if b.expectedSearchValue != nil || b.emptyResultLabel != nil { return false }
        return true
    }
    @MainActor
    func testB6NativeCacheInputReaderPreservesBytesAndRejectsUnsafeInputs() async throws {
        let manager = FileManager.default
        let cache = try XCTUnwrap(manager.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let operationID = UUID()
        let relative = "CodexPilotB6Inputs/\(operationID.uuidString.lowercased())/manifest.json"
        let directory = cache.appendingPathComponent("CodexPilotB6Inputs", isDirectory: true)
            .appendingPathComponent(operationID.uuidString.lowercased(), isDirectory: true)
        try manager.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Only an exclusive mkdir success grants ownership for later cleanup.
        guard Darwin.mkdir(directory.path, mode_t(0o700)) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { try? manager.removeItem(at: directory) }
        let input = directory.appendingPathComponent("manifest.json")
        let bytes = Data((0..<8_193).map { UInt8(truncatingIfNeeded: $0) })
        try bytes.write(to: input)
        let actual = try Self.b6ReadCacheInput(relative, basename: "manifest.json",
            operationID: operationID.uuidString.lowercased(), maximumBytes: 131_072)
        XCTAssertEqual(actual.data, bytes)
        XCTAssertEqual(actual.operationID, operationID)

        XCTAssertThrowsError(try Self.b6ReadCacheInput(
            "CodexPilotB6Inputs/\(operationID.uuidString.lowercased())/../manifest.json",
            basename: "manifest.json", maximumBytes: 131_072))

        let alias = directory.appendingPathComponent("hard-link-alias")
        try manager.linkItem(at: input, to: alias)
        XCTAssertThrowsError(try Self.b6ReadCacheInput(relative, basename: "manifest.json",
            operationID: operationID.uuidString.lowercased(), maximumBytes: 131_072))
        try manager.removeItem(at: alias)

        let payload = directory.appendingPathComponent("owned-payload")
        try manager.moveItem(at: input, to: payload)
        try manager.createSymbolicLink(at: input, withDestinationURL: payload)
        XCTAssertThrowsError(try Self.b6ReadCacheInput(relative, basename: "manifest.json",
            operationID: operationID.uuidString.lowercased(), maximumBytes: 131_072))
        try manager.removeItem(at: input)

        try Data(repeating: 0xA5, count: 131_073).write(to: input)
        XCTAssertThrowsError(try Self.b6ReadCacheInput(relative, basename: "manifest.json",
            operationID: operationID.uuidString.lowercased(), maximumBytes: 131_072))
        try manager.removeItem(at: directory)
        XCTAssertFalse(manager.fileExists(atPath: directory.path))
    }

    /// Resolve only the declared B6 input namespace inside this process's cache.
    private static func b6ReadCacheInput(_ path: String, basename: String,
        operationID: String? = nil, maximumBytes: Int) throws -> (data: Data, operationID: UUID) {
        let parts = path.components(separatedBy: "/")
        guard parts.count == 3, parts[0] == "CodexPilotB6Inputs",
              let inputOperation = UUID(uuidString: parts[1]),
              parts[1] == inputOperation.uuidString.lowercased(), parts[2] == basename,
              basename == "peer-binding.json" || basename == "manifest.json",
              operationID == nil || operationID.flatMap(UUID.init(uuidString:)) == inputOperation,
              maximumBytes > 0, maximumBytes <= 262_144,
              let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw B6VisibleFailure.binding
        }
        func sameObject(_ a: stat, _ b: stat) -> Bool {
            a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_mode == b.st_mode &&
                a.st_uid == b.st_uid && a.st_gid == b.st_gid
        }
        func sameFile(_ a: stat, _ b: stat) -> Bool {
            sameObject(a, b) && a.st_nlink == b.st_nlink && a.st_size == b.st_size &&
                a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
                a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec
        }
        let directoryFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        var directories: [Int32] = []
        defer { for descriptor in directories.reversed() { _ = Darwin.close(descriptor) } }
        let root = Darwin.open(cache.path, directoryFlags)
        guard root >= 0 else { throw B6VisibleFailure.binding }
        directories.append(root)
        for component in parts.prefix(2) {
            let child = Darwin.openat(directories[directories.count - 1], component, directoryFlags)
            guard child >= 0 else { throw B6VisibleFailure.binding }
            directories.append(child)
        }
        // NONBLOCK also makes a nonregular input fail without waiting on a FIFO.
        let file = Darwin.openat(directories[2], parts[2], O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard file >= 0 else { throw B6VisibleFailure.binding }
        defer { _ = Darwin.close(file) }
        var before = stat()
        guard Darwin.fstat(file, &before) == 0, (before.st_mode & S_IFMT) == S_IFREG,
              before.st_uid == Darwin.geteuid(), before.st_nlink == 1,
              before.st_size > 0, before.st_size <= off_t(maximumBytes) else { throw B6VisibleFailure.binding }
        let expectedCount = Int(before.st_size)
        var data = Data(); data.reserveCapacity(expectedCount)
        var buffer = [UInt8](repeating: 0, count: min(4_096, expectedCount))
        while data.count < expectedCount {
            let requested = min(buffer.count, expectedCount - data.count)
            let count = buffer.withUnsafeMutableBytes { Darwin.read(file, $0.baseAddress!, requested) }
            guard count > 0 else { throw B6VisibleFailure.binding }
            data.append(contentsOf: buffer.prefix(count))
        }
        var extra: UInt8 = 0
        guard Darwin.read(file, &extra, 1) == 0 else { throw B6VisibleFailure.binding }
        var after = stat(), linkedFile = stat()
        guard Darwin.fstat(file, &after) == 0, sameFile(before, after),
              Darwin.fstatat(directories[2], parts[2], &linkedFile, AT_SYMLINK_NOFOLLOW) == 0,
              sameFile(after, linkedFile) else { throw B6VisibleFailure.binding }
        // An opened old directory is insufficient if its named entry was swapped.
        for (index, component) in parts.prefix(2).enumerated() {
            var opened = stat(), linked = stat()
            guard Darwin.fstat(directories[index + 1], &opened) == 0,
                  Darwin.fstatat(directories[index], component, &linked, AT_SYMLINK_NOFOLLOW) == 0,
                  sameObject(opened, linked), (linked.st_mode & S_IFMT) == S_IFDIR else { throw B6VisibleFailure.binding }
        }
        var openedRoot = stat(), linkedRoot = stat()
        guard Darwin.fstat(root, &openedRoot) == 0, Darwin.lstat(cache.path, &linkedRoot) == 0,
              sameObject(openedRoot, linkedRoot), (linkedRoot.st_mode & S_IFMT) == S_IFDIR else { throw B6VisibleFailure.binding }
        return (data, inputOperation)
    }

    // Unicode token boundaries prevent a price "12" from matching "112".
    // Full remote body/ID is joined separately; these are visible strings only.
    static func b6Contains(_ label: String, _ field: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: field)
        return label.range(of: "(?<![\\p{L}\\p{N}_])" + escaped + "(?![\\p{L}\\p{N}_])", options: .regularExpression) != nil
    }
    @MainActor
    private func b6Query(_ app: XCUIApplication, _ b: B6VisibleBinding, sequence: Int, phase: String = "poll") throws -> (B6VisibleQuery, XCUIElement?) {
        let begin = now()
        let windows = app.windows.allElementsBoundByIndex
        guard windows.count <= 4 else { throw B6VisibleFailure.overflow }
        let root: XCUIElement
        if b.priceSheet { root = app.sheets.count == 1 ? app.sheets.element : app }
        else if let identifier = b.rootIdentifier { root = app.descendants(matching: .any).matching(identifier: identifier).firstMatch }
        else { root = app }
        let texts = root.staticTexts.allElementsBoundByIndex
        let cells = root.cells.allElementsBoundByIndex
        guard texts.count <= 512, cells.count <= 128 else { throw B6VisibleFailure.overflow }
        let foreground = app.state == .runningForeground
        let overlay = app.alerts.count == 0 && app.keyboards.count == 0 &&
            app.sheets.count == (b.priceSheet ? 1 : 0)
        let window = windows.count == 1 ? windows.first : nil
        func visible(_ item: XCUIElement, inside frame: CGRect) -> Bool {
            item.exists && item.isHittable && !item.frame.isEmpty && frame.contains(item.frame)
        }
        let routeBars = root.navigationBars.allElementsBoundByIndex.filter { Self.b6Contains($0.identifier,b.routeAnchor) && $0.isHittable }
        let routeTexts = texts.filter { Self.b6Contains($0.label,b.routeAnchor) && $0.isHittable }
        let routeOK = root.exists && (routeBars.count == 1 || (routeBars.isEmpty && routeTexts.count == 1))
        // A cell is identified by a fixture-unique visible barcode/session ID or
        // new price key, never a SQL lookup or the text entered in a search box.
        let matches = cells.filter { cell in
            Self.b6Contains(cell.label,b.rowIdentity) || cell.staticTexts.allElementsBoundByIndex.contains {
                Self.b6Contains($0.label,b.rowIdentity)
            }
        }
        let row = matches.count == 1 ? matches.first : nil
        let baselineControls = texts.filter { Self.b6Contains($0.label,b.baselineAnchor) && $0.isHittable }
        let control = baselineControls.count == 1 ? baselineControls.first : nil
        let area = row ?? control
        let viewport = window.map { w in area.map { visible($0,inside:w.frame) } ?? false } ?? false
        let labels: [String]
        if let row { labels = [row.label] + row.staticTexts.allElementsBoundByIndex.filter { visible($0,inside:row.frame) }.map(\.label) }
        else { labels = texts.filter { $0.isHittable }.map(\.label) }
        guard labels.count <= 256, labels.reduce(0,{ $0 + $1.utf8.count }) <= 2048 else { throw B6VisibleFailure.overflow }
        func has(_ fields: [String], in values: [String]) -> Bool {
            fields.allSatisfy { field in values.contains { Self.b6Contains($0,field) } }
        }
        let allVisible = texts.filter { $0.isHittable }.map(\.label)
        var before = false, after = false, exactQuery = true
        switch b.category {
        case "create", "price":
            before = matches.isEmpty && control != nil && has(b.beforeFields,in:allVisible)
            after = matches.count == 1 && has(b.afterFields,in:labels)
        case "delete":
            let search = app.textFields.matching(identifier:"task144.database.search")
            exactQuery = search.count == 1 && search.element.isHittable &&
                (search.element.value as? String) == b.expectedSearchValue
            before = matches.count == 1 && has(b.beforeFields,in:labels)
            after = matches.isEmpty && control != nil && has(b.afterFields,in:allVisible) &&
                allVisible.filter { Self.b6Contains($0,b.emptyResultLabel ?? "") }.count == 1
        default:
            before = matches.count == 1 && has(b.beforeFields,in:labels)
            after = matches.count == 1 && has(b.afterFields,in:labels)
        }
        after = after && b.absentAfterFields.allSatisfy { field in !labels.contains { Self.b6Contains($0,field) } }
        let unique = ["create","price","delete"].contains(b.category) ? matches.count <= 1 : matches.count == 1
        func rectangle(_ value: CGRect?) -> [Double] {
            guard let value else { return [] }; return [value.minX,value.minY,value.width,value.height].map(Double.init)
        }
        return (B6VisibleQuery(sequence:sequence,beginNS:begin,endNS:now(),phase:phase,foreground:foreground,
            uniqueRow:unique && routeOK,viewport:viewport,overlayAbsent:overlay,before:before,after:after,
            exactQuery:exactQuery,matchedLabels:labels,labelsSHA256:b6Hash(try JSONSerialization.data(withJSONObject:labels,options:[.sortedKeys])),frame:rectangle(area?.frame),windowFrame:rectangle(window?.frame)), area)
    }
    @MainActor
    func testObservePreparedB6VisibleDeltaWhenEnabled() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["CODEX_B6_EXTERNAL_OBSERVER"] == "1", "B6 observer is explicitly gated.")
        guard let raw = env["CODEX_B6_VISIBLE_BINDING"], raw.utf8.count <= 16384,
              let manifestPath = env["CODEX_B6_MANIFEST_PATH"] else { throw B6VisibleFailure.binding }
        let b = try JSONDecoder().decode(B6VisibleBinding.self,from:Data(raw.utf8))
        let causalMode = b.timingMethod == Self.b6CausalTimingMethod
        guard Self.b6Validate(b) else { throw B6VisibleFailure.binding }
        let manifestData = try Self.b6ReadCacheInput(manifestPath, basename: "manifest.json",
            operationID: b.operationID, maximumBytes: 131_072).data
        guard manifestData.count <= 131072,
              let manifest = try JSONSerialization.jsonObject(with:manifestData) as? [String:Any],
              manifest["status"] as? String == "AUTHORIZED_FOR_B6_EVIDENCE",
              let slots = manifest["slots"] as? [[String:Any]],
              slots.filter({ $0["sample_id"] as? String == b.sampleID }).count == 1,
              let slot = slots.first(where: { $0["sample_id"] as? String == b.sampleID }),
              slot["operation_id"] as? String == b.operationID, slot["category"] as? String == b.category,
              let fixture = slot["fixture"] as? [String:Any],
              fixture["ios_external_visible_binding_sha256"] as? String == b6Hash(Data(raw.utf8)),
              fixture["ios_external_observer_artifact_sha256"] as? String == b.observerArtifactHash,
              fixture["prerequisite_readback_sha256"] as? String == b.fixtureProofHash,
              let directions = manifest["directions"] as? [String:[String:Any]],
              let direction = directions["android_to_ios"],
              direction["peer_artifact_sha256"] as? String == b.targetArtifactHash,
              direction["peer_device_sha256"] as? String == b.targetDeviceHash,
              direction["peer_runtime_sha256"] as? String == b.targetRuntimeHash,
              direction["ordinary_preflight_sha256"] as? String == b.ordinaryPreflightHash,
              let executable = Bundle(for:Self.self).executableURL,
              b6Hash(try Data(contentsOf:executable)) == b.observerArtifactHash,
              let runtimeID = env["SIMULATOR_UDID"], UUID(uuidString:runtimeID) != nil,
              b6Hash(Data(runtimeID.lowercased().utf8)) == b.targetRuntimeHash else { throw B6VisibleFailure.artifact }
        guard causalMode ? manifest["timing_method"] as? String == Self.b6CausalTimingMethod &&
                manifest["timing_method_review_sha256"] as? String == "eaa91da232992c7c27f0a3eb635c867cb0a8e40300c65ca56dec005b2f92ea80"
                : manifest["timing_method"] as? String != Self.b6CausalTimingMethod else { throw B6VisibleFailure.causalMethod }
        let pid = ProcessInfo.processInfo.processIdentifier, boot = try b6Boot()
        let ownClock = "ios-external-uptime-\(boot)-\(pid)-\(UUID().uuidString.lowercased())"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("codex-pilot-b6-visible-\(b.operationID)")
        guard !FileManager.default.fileExists(atPath:directory.path) else { throw B6VisibleFailure.binding }
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
        let visibilityRequest = directory.appendingPathComponent("visibility-confirmation-nonce.txt")
        let causalPositiveURL = directory.appendingPathComponent("causal-positive-preview.json")
        if causalMode {
            guard !FileManager.default.fileExists(atPath: visibilityRequest.path),
                  !FileManager.default.fileExists(atPath: causalPositiveURL.path) else { throw B6VisibleFailure.causalNonce }
        }
        func calibration(_ phase: String, nonce: String) throws -> [String:Any] {
            let request = directory.appendingPathComponent("calibration-\(phase)-nonce.txt")
            guard !FileManager.default.fileExists(atPath:request.path) else { throw B6VisibleFailure.nonce }
            var ready: [String: Any] = ["stage":"B6_EXTERNAL_READY_FOR_NONCE","operation_id":b.operationID,"phase":phase,"request_path":request.path]
            if causalMode {
                ready["timing_method"] = Self.b6CausalTimingMethod
                ready["visibility_confirmation_request_path"] = visibilityRequest.path
                ready["causal_positive_preview_path"] = causalPositiveURL.path
            }
            try emit(ready)
            let deadline = now() + 30_000_000_000
            while now() < deadline {
                if FileManager.default.fileExists(atPath:request.path) {
                    let attrs = try request.resourceValues(forKeys:[.fileSizeKey,.isSymbolicLinkKey])
                    guard attrs.isSymbolicLink != true, attrs.fileSize == nonce.utf8.count,
                          String(data:try Data(contentsOf:request),encoding:.utf8) == nonce,
                          ProcessInfo.processInfo.processIdentifier == pid, try b6Boot() == boot else { throw B6VisibleFailure.nonce }
                    let reply: [String:Any] = ["operation_id":b.operationID,"phase":phase,"nonce":nonce,
                        "clock_id":ownClock,"remote_ns":now(),"participant_pid":pid,"participant_boot_sha256":boot,
                        "artifact_sha256":b.observerArtifactHash,"device_sha256":b.targetDeviceHash,
                        "target_runtime_sha256":b.targetRuntimeHash,"target_artifact_sha256":b.targetArtifactHash,
                        "ordinary_preflight_sha256":b.ordinaryPreflightHash,"manifest_sha256":b6Hash(manifestData)]
                    try b6Write(reply,to:directory.appendingPathComponent("calibration-\(phase).json"))
                    try emit(["stage":"B6_EXTERNAL_CALIBRATION_REPLY","reply":reply]); return reply
                }
                Thread.sleep(forTimeInterval:0.02)
            }
            throw B6VisibleFailure.nonce
        }
        var queries: [B6VisibleQuery] = []
        var outcome = "NOT_STARTED", errorCode: String? = nil, screenshotHash: String? = nil, windowScreenshotHash: String? = nil
        let initial = try calibration("before",nonce:b.initialNonce)
        var final: [String:Any]? = nil
        var captureProof: [String:Any]? = nil
        var originalObservationDeadline: UInt64?
        var causalConfirmation: [String: Any]?
        var causalVisibilityPreviewSHA256: String?
        let app = XCUIApplication(bundleIdentifier:"com.niwcyber.iOSMerchandiseControl")
        do {
            let first = try b6Query(app,b,sequence:0).0; queries.append(first)
            guard first.contextValid && first.before && !first.after else { throw B6VisibleFailure.baseline }
            let baseline: [String:Any] = ["stage":"B6_EXTERNAL_BASELINE_READY","operation_id":b.operationID,"clock_id":ownClock,
                "negative_begin_ns":first.beginNS,"negative_end_ns":first.endNS,
                "query":try JSONSerialization.jsonObject(with:JSONEncoder().encode(first))]
            try b6Write(baseline,to:directory.appendingPathComponent("baseline.json")); try emit(baseline)
            let deadline = now() + 30_000_000_000
            originalObservationDeadline = deadline
            outcome = "TIMEOUT"
            while now() < deadline && queries.count < 238 {
                Thread.sleep(forTimeInterval:0.1)
                let (query,area) = try b6Query(app,b,sequence:queries.count)
                guard query.contextValid else { queries.append(query); throw B6VisibleFailure.context }
                if query.after && (["create","price"].contains(b.category) || !query.before), let area {
                    queries.append(query)
                    let rowCaptureBegin = now()
                    let screenshot = area.screenshot(), data = screenshot.pngRepresentation
                    let rowCaptureEnd = now()
                    screenshotHash = b6Hash(data)
                    let attachment = XCTAttachment(screenshot:screenshot); attachment.name = "b6-peer-row-\(b.operationID)"
                    attachment.lifetime = .keepAlways; add(attachment)
                    captureProof = ["first_positive_sequence":query.sequence,
                        "row_capture_begin_ns":rowCaptureBegin,"row_capture_end_ns":rowCaptureEnd]
                    let confirmed = try b6Query(app,b,sequence:queries.count,phase:"confirm_after_row_capture").0
                    queries.append(confirmed)
                    captureProof?["row_confirmation_sequence"] = confirmed.sequence
                    guard confirmed.contextValid && confirmed.after && confirmed.frame == query.frame &&
                        confirmed.windowFrame == query.windowFrame &&
                        (["create","price"].contains(b.category) || !confirmed.before) else {
                        throw B6VisibleFailure.changedDuringCapture
                    }
                    let windowCaptureBegin = now()
                    let full = app.screenshot()
                    let windowCaptureEnd = now()
                    windowScreenshotHash = b6Hash(full.pngRepresentation)
                    let fullAttachment = XCTAttachment(screenshot:full); fullAttachment.name = "b6-peer-window-\(b.operationID)"
                    fullAttachment.lifetime = .keepAlways; add(fullAttachment)
                    captureProof?["window_capture_begin_ns"] = windowCaptureBegin
                    captureProof?["window_capture_end_ns"] = windowCaptureEnd
                    let finalCheck = try b6Query(app,b,sequence:queries.count,phase:"confirm_after_window_capture").0
                    queries.append(finalCheck)
                    captureProof?["window_confirmation_sequence"] = finalCheck.sequence
                    guard finalCheck.contextValid && finalCheck.after && finalCheck.frame == query.frame &&
                        finalCheck.windowFrame == query.windowFrame &&
                        (["create","price"].contains(b.category) || !finalCheck.before) else { throw B6VisibleFailure.changedDuringCapture }
                    outcome = "FIRST_POSITIVE_OBSERVED"; break
                }
                queries.append(query)
            }
            if queries.count >= 238 && outcome != "FIRST_POSITIVE_OBSERVED" { throw B6VisibleFailure.overflow }
        } catch { outcome = "FAIL"; errorCode = (error as? B6VisibleFailure)?.rawValue ?? "observer_error" }
        func originalVisibilityReceipt(queriesJSON: Any, post: [String: Any]?) -> [String: Any] {
            ["kind":"B6_EXTERNAL_VISIBLE_OBSERVATIONS","operation_id":b.operationID,
             "sample_id":b.sampleID,"category":b.category,"binding_raw":raw,"manifest_sha256":b6Hash(manifestData),
             "clock_id":ownClock,"participant_pid":pid,"participant_boot_sha256":boot,
             "preCalibration":initial,"postCalibration":post as Any? ?? NSNull(),"queries":queriesJSON,
             "baseline_labels":queries.first?.matchedLabels ?? [],
             "last_negative_labels":queries.last(where: { $0.before && !$0.after })?.matchedLabels ?? [],
             "terminal_labels":queries.last?.matchedLabels ?? [],
             "outcome":outcome,"error_code":errorCode as Any? ?? NSNull(),
             "capture_proof":captureProof as Any? ?? NSNull(),
             "row_screenshot_sha256":screenshotHash as Any? ?? NSNull(),
             "window_screenshot_sha256":windowScreenshotHash as Any? ?? NSNull(),"native_acceptance":false,
             "semantics":"last_negative_first_positive_render"]
        }
        if causalMode, outcome == "FIRST_POSITIVE_OBSERVED" {
            do {
                guard let deadline = originalObservationDeadline,
                      let confirmationNonce = b.visibilityConfirmationNonce else { throw B6VisibleFailure.causalNonce }
                // Keep the first positive and all preceding queries/captures.
                // Waiting for the owned postcommit challenge cannot reset the
                // original deadline or hide context loss after the first draw.
                while !FileManager.default.fileExists(atPath: visibilityRequest.path) {
                    guard now() < deadline else { throw B6VisibleFailure.timeout }
                    guard queries.count < 238 else { throw B6VisibleFailure.overflow }
                    Thread.sleep(forTimeInterval: 0.1)
                    let waiting = try b6Query(app, b, sequence: queries.count, phase: "await_causal_confirmation").0
                    queries.append(waiting)
                    guard waiting.contextValid else { throw B6VisibleFailure.context }
                    guard waiting.after && (["create", "price"].contains(b.category) || !waiting.before) else {
                        throw B6VisibleFailure.changedDuringCapture
                    }
                }
                let attrs = try visibilityRequest.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
                let nonceData = try Data(contentsOf: visibilityRequest)
                guard now() < deadline else { throw B6VisibleFailure.timeout }
                guard attrs.isSymbolicLink != true, attrs.fileSize == confirmationNonce.utf8.count,
                      nonceData == Data(confirmationNonce.utf8),
                      ProcessInfo.processInfo.processIdentifier == pid, try b6Boot() == boot else {
                    throw B6VisibleFailure.causalNonce
                }
                let challengeObserved = now()
                causalConfirmation = ["outcome": "INCOMPLETE", "challenge_observed_ns": challengeObserved,
                    "nonce": confirmationNonce, "queries": [], "capture_proof": [:]]
                var freshRecords: [B6VisibleQuery] = []
                func retainFresh(_ q: B6VisibleQuery) throws {
                    freshRecords.append(q)
                    causalConfirmation?["queries"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(freshRecords))
                }
                var retainedProof: [String: Any] = ["first_positive_sequence": 0]
                let legacyQueryJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(queries))
                let legacySnapshot = originalVisibilityReceipt(queriesJSON: legacyQueryJSON, post: nil)
                let legacyData = try JSONSerialization.data(withJSONObject: legacySnapshot, options: [.sortedKeys])
                guard let legacyRaw = String(data: legacyData, encoding: .utf8) else { throw B6VisibleFailure.overflow }
                let originalPositiveSequence = try XCTUnwrap(captureProof?["first_positive_sequence"] as? Int)
                let originalPositive = try XCTUnwrap(queries.first { $0.sequence == originalPositiveSequence })
                func requireFresh(_ q: B6VisibleQuery) throws {
                    guard now() < deadline else { throw B6VisibleFailure.timeout }
                    guard q.beginNS > challengeObserved, q.endNS >= q.beginNS,
                          q.contextValid && q.after && (["create", "price"].contains(b.category) || !q.before),
                          q.frame == originalPositive.frame, q.windowFrame == originalPositive.windowFrame else {
                        throw B6VisibleFailure.changedDuringCapture
                    }
                }
                let (positive, area) = try b6Query(app, b, sequence: 0, phase: "causal_after_commit")
                try retainFresh(positive)
                try requireFresh(positive)
                guard let area else { throw B6VisibleFailure.context }
                let rowCaptureBegin = now()
                let rowShot = area.screenshot(), rowData = rowShot.pngRepresentation
                let rowCaptureEnd = now()
                retainedProof["row_capture_begin_ns"] = rowCaptureBegin
                retainedProof["row_capture_end_ns"] = rowCaptureEnd
                causalConfirmation?["capture_proof"] = retainedProof
                causalConfirmation?["row_screenshot_sha256"] = b6Hash(rowData)
                let rowAttachment = XCTAttachment(screenshot: rowShot)
                rowAttachment.name = "b6-causal-peer-row-\(b.operationID)"; rowAttachment.lifetime = .keepAlways; add(rowAttachment)
                let confirmed = try b6Query(app, b, sequence: 1, phase: "confirm_after_row_capture").0
                try retainFresh(confirmed)
                try requireFresh(confirmed)
                retainedProof["row_confirmation_sequence"] = confirmed.sequence
                causalConfirmation?["capture_proof"] = retainedProof
                guard confirmed.frame == positive.frame, confirmed.windowFrame == positive.windowFrame else {
                    throw B6VisibleFailure.changedDuringCapture
                }
                let windowCaptureBegin = now()
                let windowShot = app.screenshot(), windowData = windowShot.pngRepresentation
                let windowCaptureEnd = now()
                retainedProof["window_capture_begin_ns"] = windowCaptureBegin
                retainedProof["window_capture_end_ns"] = windowCaptureEnd
                causalConfirmation?["capture_proof"] = retainedProof
                causalConfirmation?["window_screenshot_sha256"] = b6Hash(windowData)
                let windowAttachment = XCTAttachment(screenshot: windowShot)
                windowAttachment.name = "b6-causal-peer-window-\(b.operationID)"; windowAttachment.lifetime = .keepAlways; add(windowAttachment)
                let finalCheck = try b6Query(app, b, sequence: 2, phase: "confirm_after_window_capture").0
                try retainFresh(finalCheck)
                try requireFresh(finalCheck)
                retainedProof["window_confirmation_sequence"] = finalCheck.sequence
                causalConfirmation?["capture_proof"] = retainedProof
                causalConfirmation?["terminal_labels"] = finalCheck.matchedLabels
                guard finalCheck.frame == positive.frame, finalCheck.windowFrame == positive.windowFrame,
                      rowCaptureBegin > challengeObserved, rowCaptureEnd >= rowCaptureBegin,
                      windowCaptureBegin > challengeObserved, windowCaptureEnd >= windowCaptureBegin,
                      ProcessInfo.processInfo.processIdentifier == pid, try b6Boot() == boot else {
                    throw B6VisibleFailure.changedDuringCapture
                }
                let freshQueries = try JSONSerialization.jsonObject(with: JSONEncoder().encode([positive, confirmed, finalCheck]))
                let proof: [String: Any] = ["first_positive_sequence": 0,
                    "row_confirmation_sequence": 1, "window_confirmation_sequence": 2,
                    "row_capture_begin_ns": rowCaptureBegin, "row_capture_end_ns": rowCaptureEnd,
                    "window_capture_begin_ns": windowCaptureBegin, "window_capture_end_ns": windowCaptureEnd]
                let confirmation: [String: Any] = ["outcome": "POSITIVE_AFTER_COMMIT", "queries": freshQueries,
                    "capture_proof": proof, "row_screenshot_sha256": b6Hash(rowData),
                    "window_screenshot_sha256": b6Hash(windowData), "terminal_labels": finalCheck.matchedLabels]
                let identity: [String: Any] = ["clock_id": ownClock, "participant_pid": pid,
                    "participant_boot_sha256": boot, "artifact_sha256": b.observerArtifactHash,
                    "device_sha256": b.targetDeviceHash, "ordinary_preflight_sha256": b.ordinaryPreflightHash]
                let preview: [String: Any] = ["kind": "B6_CAUSAL_POSITIVE_PREVIEW",
                    "timing_method": Self.b6CausalTimingMethod, "operation_id": b.operationID,
                    "manifest_sha256": b6Hash(manifestData), "nonce": confirmationNonce, "identity": identity,
                    "challenge_observed_ns": challengeObserved,
                    "original_visibility_receipt_raw": legacyRaw,
                    "original_visibility_receipt_sha256": b6Hash(legacyData), "confirmation": confirmation]
                guard now() < deadline else { throw B6VisibleFailure.timeout }
                try b6WriteCausal(preview, to: causalPositiveURL)
                causalVisibilityPreviewSHA256 = b6Hash(try Data(contentsOf: causalPositiveURL))
                var finalConfirmation = confirmation
                finalConfirmation["challenge_observed_ns"] = challengeObserved
                finalConfirmation["nonce"] = confirmationNonce
                causalConfirmation = finalConfirmation
            } catch {
                // An earlier positive is preserved but cannot become a passing
                // causal result after challenge/context/deadline failure.
                outcome = "FAIL"; errorCode = errorCode ?? (error as? B6VisibleFailure)?.rawValue ?? "causal_confirmation_error"
                if causalConfirmation != nil {
                    causalConfirmation?["outcome"] = "FAIL"
                    causalConfirmation?["error_code"] = errorCode as Any? ?? NSNull()
                }
            }
        }
        let queryJSON = try JSONSerialization.jsonObject(with:JSONEncoder().encode(queries))
        // Preserve failures and all observations before a possibly failing final handshake.
        try b6Write(["operation_id":b.operationID,"clock_id":ownClock,"queries":queryJSON,"baseline_labels":queries.first?.matchedLabels ?? [],
                    "last_negative_labels":queries.last(where: { $0.before && !$0.after })?.matchedLabels ?? [],
                    "terminal_labels":queries.last?.matchedLabels ?? [],
                    "capture_proof":captureProof as Any? ?? NSNull(),
                    "row_screenshot_sha256":screenshotHash as Any? ?? NSNull(),
                    "window_screenshot_sha256":windowScreenshotHash as Any? ?? NSNull(),
                    "outcome":outcome,"error_code":errorCode as Any? ?? NSNull()],
                    to:directory.appendingPathComponent("observations-before-final-calibration.json"))
        do { final = try calibration("after",nonce:b.finalNonce) }
        catch { errorCode = errorCode ?? "final_calibration"; outcome = "FAIL" }
        var receipt = originalVisibilityReceipt(queriesJSON: queryJSON, post: final)
        if causalMode {
            receipt["timing_method"] = Self.b6CausalTimingMethod
            receipt["causal_visibility_preview_sha256"] = causalVisibilityPreviewSHA256 as Any? ?? NSNull()
            receipt["causal_confirmation"] = causalConfirmation as Any? ?? NSNull()
            if causalVisibilityPreviewSHA256 == nil, outcome == "FIRST_POSITIVE_OBSERVED" {
                outcome = "FAIL"; errorCode = errorCode ?? "causal_confirmation_missing"
                receipt["outcome"] = outcome; receipt["error_code"] = errorCode
            }
        }
        try b6Write(receipt,to:directory.appendingPathComponent("receipt.json")); try emit(receipt)
        XCTAssertEqual(outcome,"FIRST_POSITIVE_OBSERVED")
    }
}
