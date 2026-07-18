import Foundation

actor ProductImageCache {
    // Contract worst case for 100 products is about 109 MiB
    // (1 MiB main + 90 KiB thumb each); 128 MiB keeps that working set plus
    // filesystem overhead while remaining deterministically bounded.
    static let defaultMaximumDiskBytes = 128 * 1_024 * 1_024

    private let fileManager: FileManager
    private let maximumDiskBytes: Int
    private let rootDirectory: URL

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        maximumDiskBytes: Int = defaultMaximumDiskBytes
    ) {
        self.fileManager = fileManager
        self.maximumDiskBytes = max(1, maximumDiskBytes)
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
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let size = values.fileSize,
              size > 0,
              size <= key.variant.maxBytes else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count == size,
              ProductImageProcessor.isJPEG(data),
              !ProductImageProcessor.containsAPP1Metadata(data) else {
            try? fileManager.removeItem(at: url)
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
              !ProductImageProcessor.containsAPP1Metadata(data) else {
            throw ProductImageError.downloadedImageInvalid
        }
        let url = fileURL(for: key)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var directoryValues = URLResourceValues()
        directoryValues.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(directoryValues)
        try data.write(to: url, options: [.atomic])
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
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func purgeProduct(
        cacheScope: String,
        shopID: UUID,
        productID: UUID,
        keeping versionID: UUID? = nil
    ) throws {
        guard Self.isValidCacheScope(cacheScope) else {
            throw ProductImageError.invalidScope
        }
        let productDirectory = rootDirectory
            .appendingPathComponent(cacheScope, isDirectory: true)
            .appendingPathComponent(shopID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(productID.uuidString.lowercased(), isDirectory: true)
        guard fileManager.fileExists(atPath: productDirectory.path) else { return }
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
            try fileManager.removeItem(at: candidate)
        }
    }

    func purgeShop(cacheScope: String, shopID: UUID) throws {
        guard Self.isValidCacheScope(cacheScope) else {
            throw ProductImageError.invalidScope
        }
        let shopDirectory = rootDirectory
            .appendingPathComponent(cacheScope, isDirectory: true)
            .appendingPathComponent(shopID.uuidString.lowercased(), isDirectory: true)
        guard fileManager.fileExists(atPath: shopDirectory.path) else { return }
        try fileManager.removeItem(at: shopDirectory)
    }

    func purgeScope(cacheScope: String) throws {
        guard Self.isValidCacheScope(cacheScope) else {
            throw ProductImageError.invalidScope
        }
        let scopeDirectory = rootDirectory.appendingPathComponent(cacheScope, isDirectory: true)
        guard fileManager.fileExists(atPath: scopeDirectory.path) else { return }
        try fileManager.removeItem(at: scopeDirectory)
    }

    func diskUsageBytes() throws -> Int {
        try cacheFiles().reduce(0) { $0 + $1.bytes }
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
        while totalBytes > maximumDiskBytes, !files.isEmpty {
            let victim = files.removeFirst()
            try fileManager.removeItem(at: victim.url)
            totalBytes -= victim.bytes
        }
    }

    private func cacheFiles() throws -> [(url: URL, bytes: Int, lastAccess: Date)] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return [] }
        let keys: [URLResourceKey] = [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [(url: URL, bytes: Int, lastAccess: Date)] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true,
                  let bytes = values.fileSize,
                  bytes > 0 else {
                continue
            }
            files.append((
                url: url,
                bytes: bytes,
                lastAccess: values.contentModificationDate ?? .distantPast
            ))
        }
        return files
    }
}
