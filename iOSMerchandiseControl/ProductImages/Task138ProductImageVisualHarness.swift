#if DEBUG
import PhotosUI
import SwiftUI
import UIKit

enum Task138ProductImageVisualState: String, CaseIterable, Identifiable {
    case detailMain = "detail-main"
    case detailThumbnail = "detail-thumb"
    case editorPicker = "editor-picker"
    case errorFallback = "error-fallback"
    case list
    case offlineCache = "offline-cache"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: "Catalogo prodotti"
        case .detailThumbnail: "Dettaglio · anteprima"
        case .detailMain: "Dettaglio · immagine pronta"
        case .editorPicker: "Editor prodotto"
        case .offlineCache: "Dettaglio offline"
        case .errorFallback: "Dettaglio · errore"
        }
    }

    init?(environmentValue: String?) {
        guard let value = environmentValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !value.isEmpty else {
            return nil
        }
        self.init(rawValue: value)
    }
}

@MainActor
struct Task138ProductImageVisualHarness: View {
    @StateObject private var store: ProductImageStore
    @State private var selectedPhoto: PhotosPickerItem?

    let state: Task138ProductImageVisualState
    private let fixture: Task138ProductImageVisualFixture

    init(state: Task138ProductImageVisualState) {
        self.state = state
        let fixture = Task138ProductImageVisualFixture()
        self.fixture = fixture
        let store = ProductImageStore(service: nil)
        fixture.seed(store: store, state: state)
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    if state != .editorPicker {
                        header
                    }
                    stateContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 24)
                }
                .containerRelativeFrame(.horizontal, alignment: .leading)
            }
            .contentMargins(20, for: .scrollContent)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(state.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .environmentObject(store)
        .accessibilityIdentifier("task138.visual.\(state.rawValue)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Fixture sintetica TASK-138", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Text("Nessun dato personale · nessuna rete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("task138.visual.header")
    }

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .list:
            listState
        case .detailThumbnail:
            detailThumbnailState
        case .detailMain:
            detailMainState
        case .editorPicker:
            editorPickerState
        case .offlineCache:
            offlineCacheState
        case .errorFallback:
            errorFallbackState
        }
    }

    private var listState: some View {
        VStack(spacing: 12) {
            productRow(
                title: "Prodotto A · senza immagine",
                subtitle: "Placeholder locale · zero Storage",
                productID: fixture.placeholderProductID,
                versionID: nil,
                identifier: "task138.visual.list.placeholder"
            )
            productRow(
                title: "Prodotto B · Caffè Aurora",
                subtitle: "Thumbnail 384 px · crop/fill",
                productID: fixture.productID,
                versionID: fixture.versionID,
                identifier: "task138.visual.list.thumbnail"
            )
        }
    }

    private func productRow(
        title: String,
        subtitle: String,
        productID: UUID,
        versionID: UUID?,
        identifier: String
    ) -> some View {
        HStack(spacing: 14) {
            ProductImageRemoteView(
                scope: fixture.scope,
                productID: productID,
                versionID: versionID,
                variant: .thumb
            )
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var detailThumbnailState: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailImage
            statusPill("Anteprima thumbnail", systemImage: "photo.fill", color: .orange)
            HStack(spacing: 10) {
                ProgressView()
                Text("Decodifica immagine principale…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("task138.visual.detail-thumb.loading-main")
        }
    }

    private var detailMainState: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailImage
            statusPill("Immagine principale pronta", systemImage: "checkmark.circle.fill", color: .green)
            Text("Aspect fit · nessun layout shift · crossfade concluso")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var editorPickerState: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailImage
            Text("Immagine prodotto")
                .font(.headline)
            HStack(spacing: 12) {
                Button(action: {}) {
                    Label("Fotocamera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("task138.visual.editor.camera")

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Libreria foto", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("task138.visual.editor.library")
            }
            Text("Preparazione → main → thumbnail → finalizzazione")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("task138.visual.editor")
    }

    private var offlineCacheState: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailImage
            statusPill("Disponibile offline", systemImage: "wifi.slash", color: .blue)
            Text("Main e thumbnail lette dalla cache locale account/shop scoped.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("task138.visual.offline-cache")
    }

    private var errorFallbackState: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailImage
            statusPill("Main non disponibile", systemImage: "exclamationmark.triangle.fill", color: .red)
            Text("La thumbnail resta visibile. Usa il pulsante di retry sull’immagine per riprovare.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("task138.visual.error-fallback")
    }

    private var detailImage: some View {
        ProductImageRemoteView(
            scope: fixture.scope,
            productID: fixture.productID,
            versionID: fixture.versionID,
            variant: .main
        )
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("task138.visual.detail.image")
    }

    private func statusPill(
        _ title: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.12), in: Capsule())
    }
}

@MainActor
struct Task138ProductImageVisualFixture {
    let scope = ProductImageScope(
        accountID: UUID(uuidString: "13800000-0000-4000-8000-000000000001")!,
        shopID: UUID(uuidString: "13800000-0000-4000-8000-000000000002")!
    )
    let productID = UUID(uuidString: "13800000-0000-4000-8000-000000000003")!
    let placeholderProductID = UUID(uuidString: "13800000-0000-4000-8000-000000000004")!
    let versionID = UUID(uuidString: "13800000-0000-4000-8000-000000000005")!

    var thumbnailReference: ProductImageReference {
        ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )
    }

    var mainReference: ProductImageReference {
        ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: .main
        )
    }

    func seed(store: ProductImageStore, state: Task138ProductImageVisualState) {
        let thumbnail = Self.fixtureImage(size: CGSize(width: 384, height: 288), compact: true)
        let main = Self.fixtureImage(size: CGSize(width: 1_200, height: 900), compact: false)
        switch state {
        case .list:
            store.seedTask138VisualFixture(
                scope: scope,
                images: [thumbnailReference: thumbnail]
            )
        case .detailThumbnail:
            store.seedTask138VisualFixture(
                scope: scope,
                images: [thumbnailReference: thumbnail],
                loading: [mainReference]
            )
        case .detailMain, .editorPicker:
            store.seedTask138VisualFixture(
                scope: scope,
                images: [thumbnailReference: thumbnail, mainReference: main]
            )
        case .offlineCache:
            store.seedTask138VisualFixture(
                scope: scope,
                images: [thumbnailReference: thumbnail, mainReference: main],
                source: "cache"
            )
        case .errorFallback:
            store.seedTask138VisualFixture(
                scope: scope,
                images: [thumbnailReference: thumbnail],
                failures: [mainReference]
            )
        }
    }

    private static func fixtureImage(size: CGSize, compact: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            let colors = [
                UIColor(red: 0.08, green: 0.20, blue: 0.42, alpha: 1).cgColor,
                UIColor(red: 0.10, green: 0.55, blue: 0.62, alpha: 1).cgColor
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let packageRect = CGRect(
                x: size.width * 0.25,
                y: size.height * 0.13,
                width: size.width * 0.50,
                height: size.height * 0.74
            )
            UIColor(red: 0.98, green: 0.88, blue: 0.55, alpha: 1).setFill()
            UIBezierPath(roundedRect: packageRect, cornerRadius: size.width * 0.035).fill()

            let title = compact ? "AURORA" : "CAFFÈ\nAURORA"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(
                    ofSize: compact ? size.width * 0.07 : size.width * 0.065,
                    weight: .black
                ),
                .foregroundColor: UIColor(red: 0.12, green: 0.24, blue: 0.30, alpha: 1),
                .paragraphStyle: paragraph
            ]
            let textRect = packageRect.insetBy(dx: size.width * 0.03, dy: size.height * 0.20)
            (title as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }
}
#endif
