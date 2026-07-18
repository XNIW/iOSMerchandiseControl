import Foundation

nonisolated enum ProductImageVariant: String, Codable, CaseIterable, Sendable {
    case main
    case thumb

    var maxBytes: Int {
        switch self {
        case .main: 1_024 * 1_024
        case .thumb: 90 * 1_024
        }
    }
}

nonisolated struct ProductImageScope: Hashable, Sendable {
    let accountID: UUID
    let shopID: UUID
}

nonisolated extension SelectedShop {
    var isValidProductImageSelection: Bool {
        let blocked: Set<String> = [
            "blocked", "deleted", "disabled", "inactive", "revoked", "suspended"
        ]
        return selectable
            && !blocked.contains(status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

nonisolated struct ProductImageReference: Hashable, Sendable {
    let scope: ProductImageScope
    let productID: UUID
    let versionID: UUID
    let variant: ProductImageVariant
}

nonisolated struct ProductImageCacheKey: Hashable, Sendable {
    let cacheScope: String
    let shopID: UUID
    let productID: UUID
    let versionID: UUID
    let variant: ProductImageVariant
}

nonisolated struct ProductImageMetadata: Codable, Equatable, Sendable {
    let bytes: Int
    let height: Int
    let mimeType: String
    let sha256: String
    let width: Int

    init(bytes: Int, height: Int, sha256: String, width: Int) {
        self.bytes = bytes
        self.height = height
        self.mimeType = "image/jpeg"
        self.sha256 = sha256
        self.width = width
    }
}

nonisolated struct PreparedProductImageVariant: Equatable, Sendable {
    let data: Data
    let metadata: ProductImageMetadata
}

nonisolated struct ProductImagePreprocessMetrics: Equatable, Sendable {
    let elapsedMilliseconds: Int
    let inputBytes: Int
    let inputHeight: Int
    let inputWidth: Int
    let mainBytes: Int
    let mainHeight: Int
    let mainWidth: Int
    let thumbBytes: Int
    let thumbHeight: Int
    let thumbWidth: Int
}

nonisolated struct PreparedProductImage: Equatable, Sendable {
    let main: PreparedProductImageVariant
    let thumb: PreparedProductImageVariant
    let metrics: ProductImagePreprocessMetrics
}

nonisolated struct ProductImageSessionSnapshot: Sendable {
    let accountID: UUID
    let accessToken: String
}

nonisolated struct ProductImageUploadResult: Sendable {
    let imageUpdatedAt: Date?
    let metrics: ProductImagePreprocessMetrics
    let status: String
    let versionID: UUID
}

nonisolated struct ProductImageRemoveResult: Sendable {
    let imageUpdatedAt: Date?
    let status: String
}

nonisolated enum ProductImageOperationStage: Equatable, Sendable {
    case idle
    case processing
    case uploading
    case finalizing
    case removing
    case failed
}

nonisolated enum ProductImageError: Error, Equatable, Sendable {
    case unavailable
    case invalidScope
    case unauthenticated
    case accountChanged
    case inputEmpty
    case inputTooLarge
    case inputPixelLimitExceeded
    case unsupportedFormat
    case animatedInput
    case decodeFailed
    case encodeFailed
    case outputTooLarge
    case metadataPresent
    case invalidResponse
    case requestFailed(status: Int)
    case signedURLInvalid
    case uploadFailed(status: Int)
    case downloadFailed(status: Int)
    case downloadedImageInvalid
    case offlineNotCached
    case cacheFailure
}
