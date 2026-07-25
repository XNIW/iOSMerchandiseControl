import Foundation
import Darwin

actor ProductImageCache {
    // Contract worst case for 100 products is about 109 MiB
    // (1 MiB main + 90 KiB thumb each); 128 MiB keeps that working set plus
    // filesystem overhead while remaining deterministically bounded.
    static let defaultMaximumDiskBytes = 128 * 1_024 * 1_024
    static let defaultMaximumEntryCount = 4_096

    private let fileManager: FileManager
    private let maximumDiskBytes: Int
    private let maximumEntryCount: Int
    private let rootDirectory: URL

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        maximumDiskBytes: Int = defaultMaximumDiskBytes,
        maximumEntryCount: Int = defaultMaximumEntryCount
    ) {
        self.fileManager = fileManager
        self.maximumDiskBytes = max(1, maximumDiskBytes)
        self.maximumEntryCount = max(1, maximumEntryCount)
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.rootDirectory = caches
                .appendingPathComponent("ProductImages", isDirectory: true)
                .appendingPathComponent("v1", isDirectory: true)
        }
    }

    func read(_ key: ProductImageCacheKey) throws -> Data? {
        guard Self.isValidCacheScope(key.cacheScope) else {
            throw ProductImageError.invalidScope
        }
        let url = fileURL(for: key)
        try validateNoFollowPath(url, allowMissingTail: true)
        guard pathExistsWithoutFollowingLinks(url) else { return nil }
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else {
            if errno == ENOENT { return nil }
            throw ProductImageError.invalidScope
        }
        defer { close(descriptor) }
        var status = stat()
        guard fstat(descriptor, &status) == 0,
              (status.st_mode & S_IFMT) == S_IFREG,
              status.st_size <= Int64(Int.max) else {
            throw ProductImageError.invalidScope
        }
        let size = Int(status.st_size)
        guard
              size > 0,
              size <= key.variant.maxBytes else {
            try? removeCacheFileAndEmptyAncestors(at: url)
            return nil
        }
        var data = Data(count: size)
        let bytesRead = data.withUnsafeMutableBytes { buffer -> Int in
            guard let base = buffer.baseAddress else { return 0 }
            var total = 0
            while total < size {
                let count = Darwin.read(descriptor, base.advanced(by: total), size - total)
                if count <= 0 { return count < 0 ? -1 : total }
                total += count
            }
            return total
        }
        guard bytesRead == size,
              ProductImageProcessor.isJPEG(data),
              !ProductImageProcessor.containsForbiddenMetadata(data) else {
            try? removeCacheFileAndEmptyAncestors(at: url)
            return nil
        }
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
        return data
    }

    func write(_ data: Data, for key: ProductImageCacheKey) throws {
        guard Self.isValidCacheScope(key.cacheScope) else {
            throw ProductImageError.invalidScope
        }
        guard !data.isEmpty,
              data.count <= key.variant.maxBytes,
              ProductImageProcessor.isJPEG(data),
              !ProductImageProcessor.containsForbiddenMetadata(data) else {
            throw ProductImageError.downloadedImageInvalid
        }
        let url = fileURL(for: key)
        let directory = url.deletingLastPathComponent()
        try ensureRootDirectory()
        try validateNoFollowPath(directory, allowMissingTail: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try validateNoFollowPath(directory, allowMissingTail: false)
        var directoryValues = URLResourceValues()
        directoryValues.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(directoryValues)
        try writeAtomicallyNoFollow(data, to: url)
#if os(iOS)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
#endif
        try evictIfNeeded()
    }

    func remove(_ key: ProductImageCacheKey) throws {
        guard Self.isValidCacheScope(key.cacheScope) else {
            throw ProductImageError.invalidScope
        }
        let url = fileURL(for: key)
        try validateNoFollowPath(url, allowMissingTail: true)
        guard pathExistsWithoutFollowingLinks(url) else { return }
        try removeCacheFileAndEmptyAncestors(at: url)
    }

    func purgeProduct(
        cacheScope: String,
        shopID: UUID,
        productID: UUID,
        keeping versionID: UUID? = nil
    ) throws {
        try Task.checkCancellation()
        guard Self.isValidCacheScope(cacheScope) else {
            throw ProductImageError.invalidScope
        }
        let productDirectory = rootDirectory
            .appendingPathComponent(cacheScope, isDirectory: true)
            .appendingPathComponent(shopID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(productID.uuidString.lowercased(), isDirectory: true)
        try validateNoFollowPath(productDirectory, allowMissingTail: true)
        guard pathExistsWithoutFollowingLinks(productDirectory) else { return }
        try validateNoSymbolicLinksInTree(productDirectory)
        guard let versionID else {
            try fileManager.removeItem(at: productDirectory)
            return
        }
        let keep = versionID.uuidString.lowercased()
        for candidate in try fileManager.contentsOfDirectory(
            at: productDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) where candidate.lastPathComponent != keep {
            try Task.checkCancellation()
            try fileManager.removeItem(at: candidate)
        }
    }

    func purgeShop(cacheScope: String, shopID: UUID) throws {
        try Task.checkCancellation()
        guard Self.isValidCacheScope(cacheScope) else {
            throw ProductImageError.invalidScope
        }
        let shopDirectory = rootDirectory
            .appendingPathComponent(cacheScope, isDirectory: true)
            .appendingPathComponent(shopID.uuidString.lowercased(), isDirectory: true)
        try validateNoFollowPath(shopDirectory, allowMissingTail: true)
        guard pathExistsWithoutFollowingLinks(shopDirectory) else { return }
        try validateNoSymbolicLinksInTree(shopDirectory)
        try fileManager.removeItem(at: shopDirectory)
    }

    func purgeScope(cacheScope: String) throws {
        try Task.checkCancellation()
        guard Self.isValidCacheScope(cacheScope) else {
            throw ProductImageError.invalidScope
        }
        let scopeDirectory = rootDirectory.appendingPathComponent(cacheScope, isDirectory: true)
        try validateNoFollowPath(scopeDirectory, allowMissingTail: true)
        guard pathExistsWithoutFollowingLinks(scopeDirectory) else { return }
        try validateNoSymbolicLinksInTree(scopeDirectory)
        try fileManager.removeItem(at: scopeDirectory)
    }

    func diskUsageBytes() throws -> Int {
        try cacheFiles().reduce(0) { $0 + $1.bytes }
    }

    func diskEntryCount() throws -> Int {
        try cacheFiles().count
    }

    static func isValidCacheScope(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { character in
            character.isNumber || ("a"..."f").contains(String(character))
        }
    }

    private func fileURL(for key: ProductImageCacheKey) -> URL {
        rootDirectory
            .appendingPathComponent(key.cacheScope, isDirectory: true)
            .appendingPathComponent(key.shopID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(key.productID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(key.versionID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("\(key.variant.rawValue).jpg", isDirectory: false)
    }

    private func evictIfNeeded() throws {
        var files = try cacheFiles().sorted { lhs, rhs in
            if lhs.lastAccess == rhs.lastAccess {
                return lhs.url.path < rhs.url.path
            }
            return lhs.lastAccess < rhs.lastAccess
        }
        var totalBytes = files.reduce(0) { $0 + $1.bytes }
        while (totalBytes > maximumDiskBytes || files.count > maximumEntryCount),
              !files.isEmpty {
            let victim = files.removeFirst()
            try removeCacheFileAndEmptyAncestors(at: victim.url)
            totalBytes -= victim.bytes
        }
    }

    private func removeCacheFileAndEmptyAncestors(at fileURL: URL) throws {
        let root = rootDirectory.standardizedFileURL
        let candidate = fileURL.standardizedFileURL
        let prefix = root.path + "/"
        guard candidate.path.hasPrefix(prefix) else {
            throw ProductImageError.invalidScope
        }
        try validateNoFollowPath(candidate, allowMissingTail: true)
        if pathExistsWithoutFollowingLinks(candidate) {
            try fileManager.removeItem(at: candidate)
        }
        var directory = candidate.deletingLastPathComponent()
        while directory.path.hasPrefix(prefix), directory != root {
            try validateNoFollowPath(directory, allowMissingTail: true)
            guard pathExistsWithoutFollowingLinks(directory) else {
                directory.deleteLastPathComponent()
                continue
            }
            let children = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            guard children.isEmpty else { return }
            try fileManager.removeItem(at: directory)
            directory.deleteLastPathComponent()
        }
    }

    private func cacheFiles() throws -> [(url: URL, bytes: Int, lastAccess: Date)] {
        try validateNoFollowPath(rootDirectory, allowMissingTail: true)
        guard pathExistsWithoutFollowingLinks(rootDirectory) else { return [] }
        let keys: [URLResourceKey] = [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: keys,
            options: []
        ) else {
            return []
        }
        var files: [(url: URL, bytes: Int, lastAccess: Date)] = []
        var invalidFiles: [URL] = []
        var directories: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                invalidFiles.append(url)
                enumerator.skipDescendants()
                continue
            }
            if values.isDirectory == true {
                directories.append(url)
                continue
            }
            guard values.isRegularFile == true,
                  let bytes = values.fileSize,
                  bytes > 0,
                  !url.lastPathComponent.hasPrefix(".") else {
                invalidFiles.append(url)
                continue
            }
            files.append((
                url: url,
                bytes: bytes,
                lastAccess: values.contentModificationDate ?? .distantPast
            ))
        }
        for invalid in invalidFiles {
            try removeCacheFileAndEmptyAncestors(at: invalid)
        }
        // A crash may leave empty account/shop/product/version directories.
        // Remove them deepest-first so repeated cleanup remains idempotent and
        // the entry bound also keeps ordinary directory/inode growth bounded.
        for directory in directories.sorted(by: { $0.path.count > $1.path.count }) {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            let children = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            )
            if children.isEmpty { try fileManager.removeItem(at: directory) }
        }
        return files
    }

    private func ensureRootDirectory() throws {
        try validateNoFollowPath(rootDirectory, allowMissingTail: true)
        if !pathExistsWithoutFollowingLinks(rootDirectory) {
            try fileManager.createDirectory(
                at: rootDirectory,
                withIntermediateDirectories: true
            )
        }
        try validateNoFollowPath(rootDirectory, allowMissingTail: false)
    }

    private func validateNoFollowPath(
        _ url: URL,
        allowMissingTail: Bool
    ) throws {
        let root = rootDirectory.standardizedFileURL
        let candidate = url.standardizedFileURL
        guard candidate == root || candidate.path.hasPrefix(root.path + "/") else {
            throw ProductImageError.invalidScope
        }

        if pathExistsWithoutFollowingLinks(root) {
            try rejectSymbolicLink(root)
        } else if !allowMissingTail {
            throw ProductImageError.invalidScope
        }

        let rootComponents = root.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.starts(with: rootComponents) else {
            throw ProductImageError.invalidScope
        }
        var current = root
        var encounteredMissing = !pathExistsWithoutFollowingLinks(root)
        for component in candidateComponents.dropFirst(rootComponents.count) {
            current.appendPathComponent(component)
            if encounteredMissing {
                continue
            }
            if pathExistsWithoutFollowingLinks(current) {
                try rejectSymbolicLink(current)
            } else {
                encounteredMissing = true
            }
        }
        if encounteredMissing && !allowMissingTail {
            throw ProductImageError.invalidScope
        }
    }

    private func validateNoSymbolicLinksInTree(_ directory: URL) throws {
        try validateNoFollowPath(directory, allowMissingTail: false)
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: []
        ) else {
            return
        }
        for case let candidate as URL in enumerator {
            let values = try candidate.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                enumerator.skipDescendants()
                throw ProductImageError.invalidScope
            }
        }
    }

    private func rejectSymbolicLink(_ url: URL) throws {
        var status = stat()
        guard lstat(url.path, &status) == 0 else {
            if errno == ENOENT { return }
            throw ProductImageError.invalidScope
        }
        guard (status.st_mode & S_IFMT) != S_IFLNK else {
            throw ProductImageError.invalidScope
        }
    }

    private func pathExistsWithoutFollowingLinks(_ url: URL) -> Bool {
        var status = stat()
        return lstat(url.path, &status) == 0
    }

    private func writeAtomicallyNoFollow(_ data: Data, to destination: URL) throws {
        try validateNoFollowPath(destination, allowMissingTail: true)
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString.lowercased()).tmp")
        let descriptor = open(
            temporary.path,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW,
            S_IRUSR | S_IWUSR
        )
        guard descriptor >= 0 else {
            throw ProductImageError.invalidScope
        }
        var descriptorIsOpen = true
        defer {
            if descriptorIsOpen { close(descriptor) }
            if pathExistsWithoutFollowingLinks(temporary) {
                try? fileManager.removeItem(at: temporary)
            }
        }
        let written = data.withUnsafeBytes { buffer -> Bool in
            guard let base = buffer.baseAddress else { return data.isEmpty }
            var total = 0
            while total < buffer.count {
                let count = Darwin.write(
                    descriptor,
                    base.advanced(by: total),
                    buffer.count - total
                )
                if count <= 0 { return false }
                total += count
            }
            return true
        }
        guard written, fsync(descriptor) == 0, close(descriptor) == 0 else {
            throw ProductImageError.invalidScope
        }
        descriptorIsOpen = false
        try validateNoFollowPath(destination.deletingLastPathComponent(), allowMissingTail: false)
        guard rename(temporary.path, destination.path) == 0 else {
            throw ProductImageError.invalidScope
        }
    }
}
