import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct InventoryHomeView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @EnvironmentObject var excelSession: ExcelSessionViewModel
    @Environment(\.modelContext) private var context

    @State private var showFileImporter = false
    @State private var showPreGenerate = false
    @State private var loadError: String?
    @State private var navigateToManualGenerated = false
    /// Serve per dire a GeneratedView se deve aprire subito lo scanner
    @State private var autoOpenScannerInGenerated = false

    private static let allowedUTTypes: Set<UTType> = [.spreadsheet, .html]
    private static let allowedExtensions: Set<String> = ["xlsx", "xls", "html", "htm"]

    private var loadedDataRowCount: Int {
        max(excelSession.rows.count - 1, 0)
    }

    private var homeStatusIcon: String {
        if excelSession.isLoading {
            return "hourglass"
        }
        return excelSession.hasData ? "checkmark.circle.fill" : "tray"
    }

    private var homeStatusTint: Color {
        if excelSession.isLoading {
            return .accentColor
        }
        return excelSession.hasData ? .green : .secondary
    }

    private var homeStatusTitle: String {
        if excelSession.isLoading {
            return L("inventory.home.loading")
        }
        if excelSession.hasData {
            return L("inventory.home.file_loaded", loadedDataRowCount, excelSession.normalizedHeader.count)
        }
        return L("inventory.home.no_file")
    }

    /// Valida il tipo file usando UTType (primario) con fallback su estensione.
    /// Gestisce file condivisi da altre app con nomi/estensioni poco affidabili.
    private func isFileTypeSupported(_ url: URL) -> Bool {
        // Primario: controlla il content type via URLResourceValues
        if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let contentType = resourceValues.contentType {
            return Self.allowedUTTypes.contains(where: { contentType.conforms(to: $0) })
        }
        // Fallback: estensione (per file senza metadata o da sandbox restrittive)
        return Self.allowedExtensions.contains(url.pathExtension.lowercased())
    }

    private func unsupportedFileDescription(for url: URL) -> String {
        url.pathExtension.isEmpty
            ? "\"\(url.lastPathComponent)\""
            : ".\(url.pathExtension)"
    }

    private func handleImportFailure(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSUserCancelledError {
            return
        }

        loadError = excelSession.lastError ?? error.localizedDescription
    }

    private func loadSelectedFiles(_ urls: [URL], requiresSecurityScopedAccess: Bool) {
        guard !urls.isEmpty else { return }

        Task {
            let accessFlags = requiresSecurityScopedAccess
                ? urls.map { $0.startAccessingSecurityScopedResource() }
                : Array(repeating: false, count: urls.count)
            defer {
                for (url, accessing) in zip(urls, accessFlags) where accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if let unsupportedURL = urls.first(where: { !isFileTypeSupported($0) }) {
                loadError = L("inventory.home.error.unsupported_format", unsupportedFileDescription(for: unsupportedURL))
                return
            }

            guard !excelSession.isLoading else {
                loadError = L("inventory.home.error.import_in_progress")
                return
            }

            // Reset stato navigazione locale per evitare conflitti
            navigateToManualGenerated = false
            autoOpenScannerInGenerated = false
            showPreGenerate = false

            do {
                try await excelSession.load(from: urls, in: context)
                showPreGenerate = true
            } catch {
                handleImportFailure(error)
            }
        }
    }

    private func loadExternalFile(_ url: URL) {
        loadSelectedFiles([url], requiresSecurityScopedAccess: true)
    }

    private func startManualInventory(autoOpenScanner: Bool) {
        Task {
            do {
                let entry: HistoryEntry
                if autoOpenScanner,
                   let current = excelSession.currentHistoryEntry,
                   current.isManualEntry {
                    entry = current
                } else {
                    entry = try excelSession.createManualHistoryEntry(in: context)
                }

                excelSession.currentHistoryEntry = entry
                autoOpenScannerInGenerated = autoOpenScanner
                navigateToManualGenerated = true
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    var body: some View {
        // Tiene questa root view reattiva ai cambi lingua anche se i testi passano da L(...).
        let _ = appLanguage

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                Button {
                    showFileImporter = true
                } label: {
                    Label(L("inventory.home.select_files"), systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(excelSession.isLoading)
                .accessibilityHint(Text(L("inventory.home.subtitle")))

                statusSection

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        manualInventoryButton
                        quickScannerButton
                    }

                    VStack(spacing: 12) {
                        manualInventoryButton
                        quickScannerButton
                    }
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L("inventory.home.title"))
        // Navigation "nascosta" verso PreGenerateView e GeneratedView (manuale)
        .navigationDestination(isPresented: $showPreGenerate) {
            PreGenerateView(onExitToHome: {
                showPreGenerate = false
            })
            .environmentObject(excelSession)
        }
        .navigationDestination(isPresented: $navigateToManualGenerated) {
            Group {
                if let entry = excelSession.currentHistoryEntry {
                    GeneratedView(entry: entry, autoOpenScanner: autoOpenScannerInGenerated)
                } else {
                    Text(L("inventory.home.no_inventory"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        // File picker: .spreadsheet + .html
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.spreadsheet, .html],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                loadSelectedFiles(urls, requiresSecurityScopedAccess: true)

            case .failure(let error):
                handleImportFailure(error)
            }
        }
        .alert(L("inventory.home.error.loading_title"), isPresented: Binding(
            get: { loadError != nil },
            set: { newValue in
                if !newValue { loadError = nil }
            }
        )) {
            Button(L("common.ok"), role: .cancel) {
                loadError = nil
            }
        } message: {
            Text(loadError ?? L("inventory.home.error.unknown"))
        }
        // Gestione file ricevuto da "Apri con" — warm resume
        .onChange(of: excelSession.pendingOpenURL) { _, newURL in
            guard let url = newURL else { return }
            excelSession.pendingOpenURL = nil
            loadExternalFile(url)
        }
        // Gestione file ricevuto da "Apri con" — cold launch
        .onAppear {
            if let url = excelSession.pendingOpenURL {
                excelSession.pendingOpenURL = nil
                loadExternalFile(url)
            }
        }
        .foregroundCloudWorkflowActivity(.importExcel, isActive: excelSession.isLoading || showFileImporter)
        .foregroundCloudWorkflowActivity(.scanner, isActive: navigateToManualGenerated && autoOpenScannerInGenerated)
        .foregroundCloudWorkflowActivity(.editing, isActive: showPreGenerate || navigateToManualGenerated)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(L("inventory.home.title"))
                .font(.title2)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)

            Text(L("inventory.home.subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: homeStatusIcon)
                .font(.title3)
                .foregroundStyle(homeStatusTint)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(homeStatusTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                if excelSession.isLoading {
                    if let progress = excelSession.progress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var manualInventoryButton: some View {
        Button {
            startManualInventory(autoOpenScanner: false)
        } label: {
            Label(L("inventory.home.new_manual"), systemImage: "square.and.pencil")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var quickScannerButton: some View {
        Button {
            startManualInventory(autoOpenScanner: true)
        } label: {
            Label(L("inventory.home.quick_scanner"), systemImage: "barcode.viewfinder")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

#Preview {
    InventoryHomeView()
        .environmentObject(ExcelSessionViewModel())
        .modelContainer(for: [
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            LocalPendingChange.self
        ], inMemory: true)
}
