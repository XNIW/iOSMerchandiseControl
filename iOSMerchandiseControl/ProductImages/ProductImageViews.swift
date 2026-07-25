import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ProductImageRemoteView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: ProductImageStore

    let scope: ProductImageScope?
    let productID: UUID?
    let versionID: UUID?
    let variant: ProductImageVariant

    private var reference: ProductImageReference? {
        guard let scope, let productID, let versionID else { return nil }
        return ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: variant
        )
    }

    private var thumbnailReference: ProductImageReference? {
        guard variant == .main, let reference else { return nil }
        return ProductImageReference(
            scope: reference.scope,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: .thumb
        )
    }

    private var displayedReference: ProductImageReference? {
        guard let reference else { return nil }
        if store.image(for: reference) != nil {
            return reference
        }
        if let thumbnailReference, store.image(for: thumbnailReference) != nil {
            return thumbnailReference
        }
        return nil
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)

            if let displayedReference,
               let image = store.image(for: displayedReference) {
                renderedImage(image)
                    .id(displayedReference.variant)
                    .transition(.opacity)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let reference, store.didFail(reference) {
                Button {
                    Task { await store.load(reference) }
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L("product.image.retry_read")))
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            if let reference,
               displayedReference != nil,
               store.didFail(reference) {
                retryButton(reference)
                    .padding(8)
            }
        }
        .task(id: reference) {
            guard let reference else { return }
            if variant == .main {
                await store.loadProgressively(
                    scope: reference.scope,
                    productID: reference.productID,
                    versionID: reference.versionID
                )
            } else {
                await store.load(reference)
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: displayedReference?.variant
        )
        .accessibilityLabel(Text(L(versionID == nil ? "product.image.placeholder" : "product.image.preview")))
        .accessibilityValue(Text(L(accessibilityStateKey)))
        .accessibilityIdentifier("product.image.\(variant.rawValue)")
    }

    private var accessibilityStateKey: String {
        guard let reference else { return "product.image.state.empty" }
        if isLoading { return "product.image.state.loading" }
        if store.didFail(reference) { return "product.image.state.error" }
        if let displayedReference {
            return store.source(for: displayedReference) == "cache"
                ? "product.image.state.cached"
                : "product.image.state.ready"
        }
        return "product.image.state.empty"
    }

    private var isLoading: Bool {
        guard let reference else { return false }
        if store.isLoading(reference) { return true }
        if let thumbnailReference, store.isLoading(thumbnailReference) { return true }
        return false
    }

    @ViewBuilder
    private func renderedImage(_ image: UIImage) -> some View {
        if variant == .thumb {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    private func retryButton(_ reference: ProductImageReference) -> some View {
        Button {
            Task {
                if variant == .main {
                    await store.loadProgressively(
                        scope: reference.scope,
                        productID: reference.productID,
                        versionID: reference.versionID
                    )
                } else {
                    await store.load(reference)
                }
            }
        } label: {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L("product.image.retry_read")))
    }
}

struct ProductImageTransferFile: Transferable, Sendable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("task137-picker-\(UUID().uuidString.lowercased())")
            do {
                try FileManager.default.copyItem(at: received.file, to: destination)
                return ProductImageTransferFile(fileURL: destination)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }
    }
}

struct ProductImageCameraPicker: UIViewControllerRepresentable {
    let onCapture: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        controller.sourceType = .camera
        controller.mediaTypes = [UTType.image.identifier]
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    static func dismantleUIViewController(
        _ uiViewController: UIImagePickerController,
        coordinator: Coordinator
    ) {
        coordinator.cancelAndCleanUp()
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: ProductImageCameraPicker
        private var fallbackTask: Task<Void, Never>?
        private var leasedTemporaryURL: URL?
        private var isActive = true
        private var didComplete = false

        init(parent: ProductImageCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finishCancellation(picker: picker, notifyParent: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let sourceURL = info[.imageURL] as? URL,
               let destination = try? Self.copyToTemporaryFile(sourceURL) {
                leaseTemporaryFile(destination)
                finishCapture(picker: picker)
                return
            }
            guard let image = info[.originalImage] as? UIImage else {
                finishCancellation(picker: picker, notifyParent: true)
                return
            }
            fallbackTask?.cancel()
            fallbackTask = Task { @MainActor [weak self, weak picker] in
                guard let self else { return }
                do {
                    let destination = try await Self.writeBoundedCameraFallback(from: image)
                    guard !Task.isCancelled,
                          self.isActive,
                          !self.didComplete,
                          let picker else {
                        try? FileManager.default.removeItem(at: destination)
                        return
                    }
                    self.leaseTemporaryFile(destination)
                    self.finishCapture(picker: picker)
                } catch {
                    guard self.isActive, !self.didComplete, let picker else { return }
                    self.finishCancellation(picker: picker, notifyParent: true)
                }
            }
        }

        func leaseTemporaryFile(_ url: URL) {
            if let leasedTemporaryURL, leasedTemporaryURL != url {
                try? FileManager.default.removeItem(at: leasedTemporaryURL)
            }
            leasedTemporaryURL = url
        }

        func cancelAndCleanUp() {
            isActive = false
            fallbackTask?.cancel()
            fallbackTask = nil
            removeLeasedTemporaryFile()
        }

        private func finishCapture(picker: UIImagePickerController) {
            guard isActive, !didComplete, let destination = leasedTemporaryURL else { return }
            didComplete = true
            isActive = false
            fallbackTask = nil
            leasedTemporaryURL = nil
            picker.dismiss(animated: true)
            parent.onCapture(destination)
        }

        private func finishCancellation(
            picker: UIImagePickerController,
            notifyParent: Bool
        ) {
            guard !didComplete else { return }
            didComplete = true
            isActive = false
            fallbackTask?.cancel()
            fallbackTask = nil
            removeLeasedTemporaryFile()
            picker.dismiss(animated: true)
            if notifyParent {
                parent.onCancel()
            }
        }

        private func removeLeasedTemporaryFile() {
            guard let leasedTemporaryURL else { return }
            try? FileManager.default.removeItem(at: leasedTemporaryURL)
            self.leasedTemporaryURL = nil
        }

        static func writeBoundedCameraFallback(from image: UIImage) async throws -> URL {
            // UIImage is immutable after the picker callback and is transferred exactly once.
            // The unchecked box keeps that ownership boundary explicit for Task.detached.
            let transferredImage = ProductImageCameraImageTransfer(image)
            let task = Task.detached(priority: .userInitiated) {
                try autoreleasepool {
                    try Task.checkCancellation()
                    guard !Thread.isMainThread,
                          let boundedImage = Self.boundedCameraImage(transferredImage.image) else {
                        throw ProductImageError.decodeFailed
                    }
                    try Task.checkCancellation()
                    return try ProductImageProcessor.writeBoundedCameraFallback(boundedImage)
                }
            }
            return try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        }

        nonisolated static func boundedCameraImage(_ image: UIImage) -> CGImage? {
            let sourceSize = image.size
            let longestSide = max(sourceSize.width, sourceSize.height)
            guard longestSide > 0 else { return nil }
            let scale = min(1, CGFloat(ProductImageProcessor.mainMaximumSide) / longestSide)
            let targetSize = CGSize(
                width: max(1, (sourceSize.width * scale).rounded()),
                height: max(1, (sourceSize.height * scale).rounded())
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: targetSize))
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            return rendered.cgImage
        }

        private static func copyToTemporaryFile(_ sourceURL: URL) throws -> URL {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("task137-camera-\(UUID().uuidString.lowercased())")
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destination)
                return destination
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }
    }
}

nonisolated private final class ProductImageCameraImageTransfer: @unchecked Sendable {
    let image: UIImage

    init(_ image: UIImage) {
        self.image = image
    }
}
