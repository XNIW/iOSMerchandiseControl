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

typealias ProductImageScopeAuthorizationProvider = @Sendable (ProductImageScope) -> Bool

nonisolated enum ProductImageOwnerStoreGate {
    static func allows(
        scope: ProductImageScope,
        selectedShop: SelectedShop?,
        binding: AccountBinding?,
        hasPendingReplacement: Bool = false
    ) -> Bool {
        guard !hasPendingReplacement,
              let selectedShop,
              selectedShop.shopID == scope.shopID,
              selectedShop.isValidProductImageSelection,
              let binding,
              binding.accountHash == AccountBindingStore.accountHash(for: scope.accountID),
              !binding.storeIdentity.needsLegacyRepair else {
            return false
        }

        let selectedIdentity = selectedShop.localStoreIdentity
        return binding.storeIdentity.storeId == selectedIdentity.storeId
            && binding.storeIdentity.localStoreId == selectedIdentity.localStoreId
            && binding.storeIdentity.storeEpoch == selectedIdentity.storeEpoch
    }

    static func scope(
        accountID: UUID,
        selectedShop: SelectedShop?,
        binding: AccountBinding?,
        hasPendingReplacement: Bool = false
    ) -> ProductImageScope? {
        guard let selectedShop else { return nil }
        let scope = ProductImageScope(accountID: accountID, shopID: selectedShop.shopID)
        return allows(
            scope: scope,
            selectedShop: selectedShop,
            binding: binding,
            hasPendingReplacement: hasPendingReplacement
        ) ? scope : nil
    }
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

    func isValid(for variant: ProductImageVariant) -> Bool {
        let maximumSide = variant == .main
            ? ProductImageProcessor.mainMaximumSide
            : ProductImageProcessor.thumbMaximumSide
        return mimeType == "image/jpeg"
            && bytes > 0
            && bytes <= variant.maxBytes
            && width > 0
            && height > 0
            && max(width, height) <= maximumSide
            && sha256.count == 64
            && sha256.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

nonisolated struct PreparedProductImageVariant: Equatable, Sendable {
    let data: Data
    let metadata: ProductImageMetadata
}

nonisolated struct ProductImagePreprocessMetrics: Equatable, Sendable {
    let downsampleMilliseconds: Int
    let elapsedMilliseconds: Int
    let inputBytes: Int
    let inputHeight: Int
    let inputWidth: Int
    let mainBytes: Int
    let mainEncodeMilliseconds: Int
    let mainHeight: Int
    let mainWidth: Int
    let thumbBytes: Int
    let thumbEncodeMilliseconds: Int
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
    case uploadingMain
    case uploadingThumb
    case finalizing
    case completed
    case cancelled
    case removing
    case failed

    var allowsCancellation: Bool {
        switch self {
        case .processing, .uploadingMain, .uploadingThumb:
            true
        case .idle, .finalizing, .completed, .cancelled, .removing, .failed:
            false
        }
    }
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
    case notFound
    case offlineNotCached
    case cacheFailure
}

nonisolated enum ProductImageCanonicalErrorCode: String, CaseIterable, Sendable {
    case operationCancelled = "image_operation_cancelled"
    case inputSizeInvalid = "image_input_size_invalid"
    case dimensionsInvalid = "image_dimensions_invalid"
    case inputFormatUnsupported = "image_input_format_unsupported"
    case decodeFailed = "image_decode_failed"
    case encodeFailed = "image_encode_failed"
    case outputBudgetExceeded = "image_output_budget_exceeded"
    case metadataForbidden = "image_metadata_forbidden"
    case referenceInvalid = "image_reference_invalid"
    case sessionMissing = "image_session_missing"
    case accountChanged = "image_account_changed"
    case offlineNotCached = "image_offline_not_cached"
    case signedURLInvalid = "image_signed_url_invalid"
    case readContractInvalid = "image_read_contract_invalid"
    case downloadInvalid = "image_download_invalid"
    case requestFailed = "image_request_failed"
    case uploadFailed = "image_upload_failed"
}

nonisolated extension ProductImageError {
    var canonicalCode: ProductImageCanonicalErrorCode {
        switch self {
        case .inputEmpty, .inputTooLarge:
            .inputSizeInvalid
        case .inputPixelLimitExceeded:
            .dimensionsInvalid
        case .unsupportedFormat, .animatedInput:
            .inputFormatUnsupported
        case .decodeFailed:
            .decodeFailed
        case .encodeFailed:
            .encodeFailed
        case .outputTooLarge:
            .outputBudgetExceeded
        case .metadataPresent:
            .metadataForbidden
        case .invalidScope, .notFound:
            .referenceInvalid
        case .unauthenticated:
            .sessionMissing
        case .accountChanged:
            .accountChanged
        case .offlineNotCached:
            .offlineNotCached
        case .signedURLInvalid:
            .signedURLInvalid
        case .invalidResponse:
            .readContractInvalid
        case .downloadFailed, .downloadedImageInvalid:
            .downloadInvalid
        case .uploadFailed:
            .uploadFailed
        case .unavailable, .requestFailed, .cacheFailure:
            .requestFailed
        }
    }

    static func canonicalCode(for error: Error) -> ProductImageCanonicalErrorCode {
        if error is CancellationError {
            return .operationCancelled
        }
        return (error as? ProductImageError)?.canonicalCode ?? .requestFailed
    }
}
