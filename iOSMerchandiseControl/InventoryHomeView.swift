import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct InventoryHomeView: View {
    let isBusinessContentAvailable: Bool
    let businessContentIsCurrent: @MainActor () -> Bool
    let unavailableTitleKey: String
    let unavailableDetailKey: String
    let openOptions: (() -> Void)?
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @EnvironmentObject var excelSession: ExcelSessionViewModel
    @EnvironmentObject private var shopContextStore: ShopContextStore
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.localBusinessWriteIsAllowed) private var localWriteIsAllowed

    @StateObject private var workbookPreparation: LocalWorkbookPreparation
    @State private var businessRequestID = UUID()
    @State private var showPreGenerate = false
    @State private var showShopPicker = false
    @State private var loadError: String?
    @State private var navigateToManualGenerated = false
    /// Serve per dire a GeneratedView se deve aprire subito lo scanner
    @State private var autoOpenScannerInGenerated = false

    init(isBusinessContentAvailable: Bool, businessContentIsCurrent: @escaping @MainActor () -> Bool,
         unavailableTitleKey: String = "sync.local.qualifying.title",
         unavailableDetailKey: String = "sync.local.qualifying.detail", openOptions: (() -> Void)? = nil,
         workbookPreparation: LocalWorkbookPreparation? = nil) {
        self.isBusinessContentAvailable = isBusinessContentAvailable
        self.businessContentIsCurrent = businessContentIsCurrent
        self.unavailableTitleKey = unavailableTitleKey
        self.unavailableDetailKey = unavailableDetailKey
        self.openOptions = openOptions
        _workbookPreparation = StateObject(wrappedValue: workbookPreparation ?? LocalWorkbookPreparation())
    }

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

    private func loadSelectedFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        navigateToManualGenerated = false; autoOpenScannerInGenerated = false; showPreGenerate = false
        workbookPreparation.load(urls, session: excelSession)
    }

    private func loadExternalFile(_ url: URL) {
        loadSelectedFiles([url])
    }

    private func startManualInventory(autoOpenScanner: Bool) {
        guard isBusinessContentAvailable, businessContentIsCurrent(), localWriteIsAllowed() else { return }
        let requestID = businessRequestID
        Task {
            guard requestID == businessRequestID, businessContentIsCurrent(), localWriteIsAllowed() else { return }
            do {
                let entry: HistoryEntry
                if autoOpenScanner,
                   let current = excelSession.currentHistoryEntry,
                   current.isManualEntry {
                    entry = current
                } else {
                    entry = try excelSession.createManualHistoryEntry(
                        in: context,
                        ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID
                    )
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

        return Group {
            if isBusinessContentAvailable {
                businessContent
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    shopContextHeader
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    POSReadEntry()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    LocalWorkbookPreparationView(preparation: workbookPreparation, session: excelSession,
                        statusTitle: L(unavailableTitleKey), statusDetail: L(unavailableDetailKey), openOptions: openOptions)
                }
            }
        }
        .sheet(isPresented: $showShopPicker) { shopPickerSheet }
        .onAppear { presentPreparedWorkbookIfAllowed() }
        .onChange(of: workbookPreparation.completedRequestID) { _, _ in presentPreparedWorkbookIfAllowed() }
        .onChange(of: isBusinessContentAvailable) { _, available in
            guard !available else { presentPreparedWorkbookIfAllowed(); return }
            // Withdraw destinations and invalidate in-flight presentation completions.
            // The workbook and app-owned draft values are deliberately untouched.
            businessRequestID = UUID()
            showPreGenerate = false
            navigateToManualGenerated = false
            autoOpenScannerInGenerated = false
            loadError = nil
        }
    }

    private func presentPreparedWorkbookIfAllowed() {
        guard isBusinessContentAvailable, businessContentIsCurrent(), excelSession.hasData,
              let request = workbookPreparation.completedRequestID,
              workbookPreparation.consumedRequestID != request else { return }
        workbookPreparation.consumedRequestID = request
        showPreGenerate = true
    }

    private var businessContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                POSReadEntry()

                headerSection

                Button {
                    workbookPreparation.isPickerPresented = true
                } label: {
                    Label(L("inventory.home.select_files"), systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(excelSession.isLoading || workbookPreparation.isImporting)
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
        // Navigation "nascosta" verso PreGenerateView e GeneratedView (manuale)
        .navigationDestination(isPresented: $showPreGenerate) {
            if isBusinessContentAvailable, businessContentIsCurrent() {
                PreGenerateView(onExitToHome: {
                    showPreGenerate = false
                })
                .environmentObject(excelSession)
            }
        }
        .navigationDestination(isPresented: $navigateToManualGenerated) {
            Group {
                if isBusinessContentAvailable, businessContentIsCurrent() {
                    if let entry = excelSession.currentHistoryEntry {
                        GeneratedView(entry: entry, autoOpenScanner: autoOpenScannerInGenerated)
                    } else {
                        Text(L("inventory.home.no_inventory"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .alert(L("inventory.home.error.loading_title"), isPresented: Binding(
            get: { loadError != nil || workbookPreparation.errorMessage != nil },
            set: { newValue in
                if !newValue { loadError = nil; workbookPreparation.errorMessage = nil }
            }
        )) {
            Button(L("common.ok"), role: .cancel) {
                loadError = nil; workbookPreparation.errorMessage = nil
            }
        } message: {
            Text(loadError ?? workbookPreparation.errorMessage ?? L("inventory.home.error.unknown"))
        }
        // Gestione file ricevuto da "Apri con" — warm resume
        .onChange(of: excelSession.pendingOpenURL) { _, newURL in
            guard businessContentIsCurrent(), let url = newURL else { return }
            excelSession.pendingOpenURL = nil
            loadExternalFile(url)
        }
        // Gestione file ricevuto da "Apri con" — cold launch
        .onAppear {
            guard businessContentIsCurrent() else { return }
            if let url = excelSession.pendingOpenURL {
                excelSession.pendingOpenURL = nil
                loadExternalFile(url)
            }
        }
        .foregroundCloudWorkflowActivity(.scanner, isActive: navigateToManualGenerated && autoOpenScannerInGenerated)
        .foregroundCloudWorkflowActivity(.editing, isActive: showPreGenerate || navigateToManualGenerated)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            shopContextHeader

            Text(L("inventory.home.title"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(L("inventory.home.subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var shopContextHeader: some View {
        let presentation = InventoryHomeShopContextPresentation.make(context: shopContextStore.context)
        if let shopName = presentation.shopName {
            if presentation.showsSwitcher {
                Button {
                    showShopPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "storefront")
                            .imageScale(.small)
                            .accessibilityHidden(true)
                        Text(shopName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text(shopName))
            } else {
                Label {
                    Text(shopName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "storefront")
                        .imageScale(.small)
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        } else if shopContextStore.context.validLinkedShops.count > 1 {
            Button {
                showShopPicker = true
            } label: {
                Label(L("inventory.shop.choose"), systemImage: "storefront")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var shopPickerSheet: some View {
        NavigationStack {
            List(shopContextStore.context.linkedShops) { shop in
                Button {
                    shopContextStore.selectShop(shop.shopID)
                    showShopPicker = false
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shop.name)
                                .font(.body)
                            if let code = shop.code {
                                Text(code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if shop.shopID == shopContextStore.context.activeShopID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .disabled(!shop.isValidSelection)
                .foregroundStyle(shop.isValidSelection ? .primary : .secondary)
            }
            .navigationTitle("Negozio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.ok")) {
                        showShopPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

                if excelSession.hasData, !excelSession.isLoading, !workbookPreparation.isImporting {
                    Button(L("pregenerate.title")) {
                        guard isBusinessContentAvailable, businessContentIsCurrent() else { return }
                        showPreGenerate = true
                    }
                }

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
        .disabled(!localWriteIsAllowed())
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
        .disabled(!localWriteIsAllowed())
    }
}

#Preview {
    InventoryHomeView(isBusinessContentAvailable: true, businessContentIsCurrent: { true })
        .environmentObject(ExcelSessionViewModel())
        .environmentObject(ShopContextStore())
        .environmentObject(SupabaseAuthViewModel(authService: nil))
        .modelContainer(for: [
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            LocalPendingChange.self
        ], inMemory: true)
}
