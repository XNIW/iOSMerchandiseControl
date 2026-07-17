import Foundation

actor ProductImageCache {
    private let fileManager: FileManager
    private let rootDirectory: URL

    init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
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
}
