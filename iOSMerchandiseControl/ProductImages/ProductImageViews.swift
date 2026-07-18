import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ProductImageRemoteView: View {
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)

            if let reference, let image = store.image(for: reference) {
                if variant == .thumb {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else if let reference, store.isLoading(reference) {
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
        .task(id: reference) {
            guard let reference else { return }
            await store.load(reference)
        }
        .accessibilityLabel(Text(L(versionID == nil ? "product.image.placeholder" : "product.image.preview")))
        .accessibilityValue(Text(L(accessibilityStateKey)))
    }

    private var accessibilityStateKey: String {
        guard let reference else { return "product.image.state.empty" }
        if store.isLoading(reference) { return "product.image.state.loading" }
        if store.didFail(reference) { return "product.image.state.error" }
        if store.image(for: reference) != nil {
            return store.source(for: reference) == "cache"
                ? "product.image.state.cached"
                : "product.image.state.ready"
        }
        return "product.image.state.empty"
    }
}

struct ProductImageTransferFile: Transferable, Sendable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("task137-picker-\(UUID().uuidString.lowercased())")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ProductImageTransferFile(fileURL: destination)
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

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: ProductImageCameraPicker

        init(parent: ProductImageCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let sourceURL = info[.imageURL] as? URL,
               let destination = try? Self.copyToTemporaryFile(sourceURL) {
                picker.dismiss(animated: true)
                parent.onCapture(destination)
                return
            }
            guard let image = info[.originalImage] as? UIImage else {
                picker.dismiss(animated: true)
                parent.onCancel()
                return
            }
            let parent = parent
            Task.detached(priority: .userInitiated) {
                guard let data = image.jpegData(compressionQuality: 1) else {
                    await MainActor.run {
                        picker.dismiss(animated: true)
                        parent.onCancel()
                    }
                    return
                }
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("task137-camera-\(UUID().uuidString.lowercased()).jpg")
                do {
                    try data.write(to: destination, options: [.atomic])
                    await MainActor.run {
                        picker.dismiss(animated: true)
                        parent.onCapture(destination)
                    }
                } catch {
                    await MainActor.run {
                        picker.dismiss(animated: true)
                        parent.onCancel()
                    }
                }
            }
        }

        private static func copyToTemporaryFile(_ sourceURL: URL) throws -> URL {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("task137-camera-\(UUID().uuidString.lowercased())")
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        }
    }
}
