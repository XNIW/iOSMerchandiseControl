import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct InventoryHomeView: View {
    @EnvironmentObject var excelSession: ExcelSessionViewModel
    @Environment(\.modelContext) private var context

    @State private var showFileImporter = false
    @State private var showPreGenerate = false
    @State private var loadError: String?
    @State private var navigateToManualGenerated = false
    /// Serve per dire a GeneratedView se deve aprire subito lo scanner
    @State private var autoOpenScannerInGenerated = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Inventario")
                .font(.title2)
                .bold()

            Text("Seleziona uno o più file Excel o HTML-export per iniziare la pre-elaborazione.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                showFileImporter = true
            } label: {
                Label("Seleziona file Excel / HTML", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            
            Button {
                Task {
                    do {
                        let entry = try excelSession.createManualHistoryEntry(in: context)
                        excelSession.currentHistoryEntry = entry
                        autoOpenScannerInGenerated = false   // qui NON apriamo lo scanner in automatico
                        navigateToManualGenerated = true
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            } label: {
                Label("Nuovo inventario manuale", systemImage: "square.and.pencil")
            }
            .buttonStyle(.bordered)
            
            Button {
                Task {
                    do {
                        // 1. Prova a riusare una HistoryEntry manuale già attiva
                        let entry: HistoryEntry
                        if let current = excelSession.currentHistoryEntry,
                           current.isManualEntry {
                            entry = current
                        } else {
                            // 2. Altrimenti creane una nuova
                            entry = try excelSession.createManualHistoryEntry(in: context)
                        }

                        // 3. Assicurati che sia l’entry corrente
                        excelSession.currentHistoryEntry = entry

                        // 4. Vai alla GeneratedView in modalità manuale + scanner auto-aperto
                        autoOpenScannerInGenerated = true
                        navigateToManualGenerated = true
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            } label: {
                Label("Scanner inventario veloce", systemImage: "barcode.viewfinder")
            }
            .buttonStyle(.bordered)

            if excelSession.isLoading {
                ProgressView(value: excelSession.progress ?? 0) {
                    Text("Analisi in corso…")
                }
                .padding(.top)
            } else if excelSession.hasData {
                Text("File caricato: \(excelSession.rows.count - 1) righe dati, \(excelSession.normalizedHeader.count) colonne.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nessun file caricato al momento.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Inventario")
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
                    Text("Nessun inventario disponibile.")
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
                guard !urls.isEmpty else { return }

                Task {
                    // Gestione security-scoped URLs
                    let accessFlags = urls.map { $0.startAccessingSecurityScopedResource() }
                    defer {
                        for (url, accessing) in zip(urls, accessFlags) where accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    do {
                        try await excelSession.load(from: urls, in: context)
                        showPreGenerate = true
                    } catch {
                        loadError = excelSession.lastError ?? error.localizedDescription
                    }
                }

            case .failure(let error):
                loadError = error.localizedDescription
            }
        }
        .alert("Errore durante il caricamento", isPresented: Binding(
            get: { loadError != nil },
            set: { newValue in
                if !newValue { loadError = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                loadError = nil
            }
        } message: {
            Text(loadError ?? "Errore sconosciuto.")
        }
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
            ProductPrice.self
        ], inMemory: true)
}
