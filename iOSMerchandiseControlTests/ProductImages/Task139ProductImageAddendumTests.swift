import Foundation
import ImageIO
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task139ProductImageAddendumTests: XCTestCase {
    func testGeneratedFixtureUsesProductionProcessorAndMeetsImageContract() async throws {
        let fixtureURL = repositoryRoot
            .appendingPathComponent("iOSMerchandiseControlTests/Fixtures/TASK-139/product-photo.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixtureURL.path))

        let prepared = try await ProductImageProcessor.prepare(fileURL: fixtureURL)

        XCTAssertTrue(ProductImageProcessor.isJPEG(prepared.main.data))
        XCTAssertTrue(ProductImageProcessor.isJPEG(prepared.thumb.data))
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(prepared.main.data))
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(prepared.thumb.data))
        XCTAssertLessThanOrEqual(prepared.main.metadata.bytes, ProductImageProcessor.mainMaximumBytes)
        XCTAssertLessThanOrEqual(prepared.thumb.metadata.bytes, ProductImageProcessor.thumbMaximumBytes)
        XCTAssertLessThanOrEqual(
            max(prepared.main.metadata.width, prepared.main.metadata.height),
            ProductImageProcessor.mainMaximumSide
        )
        XCTAssertLessThanOrEqual(
            max(prepared.thumb.metadata.width, prepared.thumb.metadata.height),
            ProductImageProcessor.thumbMaximumSide
        )
        XCTAssertEqual(prepared.metrics.inputWidth, prepared.metrics.inputHeight)
    }

    func testCameraAvailabilityIsInjectableWithoutChangingProductionDefaultCallSites() {
        let withoutCamera = EditProductView(isCameraAvailable: false)
        let withCamera = EditProductView(isCameraAvailable: true)

        XCTAssertFalse(withoutCamera.isCameraAvailable)
        XCTAssertTrue(withCamera.isCameraAvailable)
    }

    func testCameraTemporaryLeaseIsRemovedWhenRepresentableIsDismantled() throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("task139-camera-lease-test-\(UUID().uuidString).jpg")
        try Data("camera-fixture".utf8).write(to: temporaryURL, options: [.atomic])
        let coordinator = ProductImageCameraPicker(onCapture: { _ in }, onCancel: {}).makeCoordinator()
        coordinator.leaseTemporaryFile(temporaryURL)

        coordinator.cancelAndCleanUp()

        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
    }

    func testProductionEditorKeepsCameraPrimaryLibrarySecondaryAndRemoveSeparate() throws {
        let source = try productionSource("iOSMerchandiseControl/EditProductView.swift")
        let actions = try sourceSlice(
            source,
            from: "private var productImageSourceActions",
            through: "private var imageScope"
        )
        let horizontal = try sourceSlice(actions, from: "HStack(spacing: 12)", through: "VStack(spacing: 10)")

        let cameraIndex = try XCTUnwrap(horizontal.range(of: "productImageCameraButton"))
        let libraryIndex = try XCTUnwrap(horizontal.range(of: "productImageLibraryPicker"))
        XCTAssertLessThan(cameraIndex.lowerBound, libraryIndex.lowerBound)
        XCTAssertTrue(actions.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(actions.contains(".buttonStyle(.borderedProminent)"))
        XCTAssertTrue(actions.contains(".buttonStyle(.bordered)"))
        XCTAssertTrue(source.contains("product.image.editor.camera"))
        XCTAssertTrue(source.contains("product.image.editor.library"))
        XCTAssertTrue(source.contains("product.image.editor.remove"))
        XCTAssertTrue(source.contains("if currentImageVersionID != nil"))
    }

    func testProductionEditorUsesPendingPreviewRealStagesCancellationAndReduceMotion() throws {
        let source = try productionSource("iOSMerchandiseControl/EditProductView.swift")

        XCTAssertTrue(source.contains("productImageStore.pendingPreview("))
        XCTAssertTrue(source.contains("product.image.pending-preview"))
        XCTAssertTrue(source.contains("product.image.operation.cancel"))
        XCTAssertTrue(source.contains("if isImportingSelectedImage { return L(\"product.image.importing\") }"))
        XCTAssertTrue(source.contains("case .uploadingMain: return L(\"product.image.uploading_main\")"))
        XCTAssertTrue(source.contains("case .uploadingThumb: return L(\"product.image.uploading_thumb\")"))
        XCTAssertTrue(source.contains("case .finalizing: return L(\"product.image.finalizing\")"))
        XCTAssertTrue(source.contains("reduceMotion ? nil"))
        XCTAssertTrue(source.contains("imageOperationID == operationID"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "imageScope == scope").count - 1, 2)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "canWriteProductImage").count - 1, 3)
        XCTAssertTrue(source.contains("Text(L(\"product.image.save_first\"))"))
    }

    func testProductionDatabaseScopeChangeDismissesProductEditorHistoryAddAndScanner() throws {
        let source = try productionSource("iOSMerchandiseControl/DatabaseView.swift")
        let handler = try sourceSlice(
            source,
            from: "private func dismissProductPresentationsForImageScopeChange()",
            through: "private func handleDatabaseScan"
        )

        XCTAssertTrue(source.contains(".onChange(of: imageScope)"))
        XCTAssertTrue(handler.contains("scannerFallbackFocusTask?.cancel()"))
        XCTAssertTrue(handler.contains("showScanner = false"))
        XCTAssertTrue(handler.contains("showAddSheet = false"))
        XCTAssertTrue(handler.contains("productToEdit = nil"))
        XCTAssertTrue(handler.contains("productForHistory = nil"))
    }

    func testProductionDatabaseRowRetainsThumbnailAndFullProductInformation() throws {
        let source = try productionSource("iOSMerchandiseControl/DatabaseView.swift")
        let row = try sourceSlice(
            source,
            from: "private struct DatabaseProductRow",
            through: "// filtro in memoria sui prodotti"
        )

        XCTAssertTrue(row.contains("variant: .thumb"))
        XCTAssertTrue(row.contains(".frame(width: 72, height: 72)"))
        XCTAssertTrue(row.contains("product.productName"))
        XCTAssertTrue(row.contains("product.secondProductName"))
        XCTAssertTrue(row.contains("product.purchasePrice"))
        XCTAssertTrue(row.contains("product.retailPrice"))
        XCTAssertTrue(row.contains("product.stockQuantity"))
        XCTAssertTrue(row.contains("product.barcode"))
        XCTAssertTrue(row.contains("product.itemNumber"))
        XCTAssertTrue(row.contains("product.supplier"))
        XCTAssertTrue(row.contains("product.category"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func productionSource(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func sourceSlice(
        _ source: String,
        from startMarker: String,
        through endMarker: String
    ) throws -> String {
        let start = try XCTUnwrap(source.range(of: startMarker)?.lowerBound)
        let end = try XCTUnwrap(source.range(of: endMarker, range: start..<source.endIndex)?.lowerBound)
        return String(source[start..<end])
    }
}
