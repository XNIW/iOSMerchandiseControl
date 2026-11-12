import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// RAM-only import presentation outlives opening, root replacement and the file picker view.
/// It never creates a ModelContext, a model, a shop reader or a Save.
@MainActor
final class LocalWorkbookPreparation: ObservableObject {
    @Published var isPickerPresented = false
    @Published var errorMessage: String?
    @Published private(set) var isImporting = false
    @Published private(set) var completedRequestID: UUID?
    var consumedRequestID: UUID?
    private var operationID: UUID?
    private var operation: Task<Void, Never>?
    private var requestID: UUID?

    func load(_ urls: [URL], session: ExcelSessionViewModel) {
        guard !urls.isEmpty else { return }
        guard operation == nil, !session.isLoading else {
            errorMessage = L("inventory.home.error.import_in_progress"); return
        }
        let request = UUID(); requestID = request; operationID = request; isImporting = true
        completedRequestID = nil; consumedRequestID = nil
        operation = Task { [weak self, session] in
            let access = urls.map { $0.startAccessingSecurityScopedResource() }
            defer {
                for (url, granted) in zip(urls, access) where granted { url.stopAccessingSecurityScopedResource() }
                if self?.requestID == request { self?.requestID = nil }
                if self?.operationID == request { self?.operationID = nil; self?.operation = nil; self?.isImporting = false }
            }
            do {
                try Task.checkCancellation()
                guard self?.requestID == request else { throw CancellationError() }
                for url in urls {
                    let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
                    let supported = type.map { $0.conforms(to: .spreadsheet) || $0.conforms(to: .html) }
                        ?? ["xlsx", "xls", "html", "htm"].contains(url.pathExtension.lowercased())
                    guard supported else { throw ExcelLoadError.invalidFormat(L("inventory.home.error.unsupported_format", "." + url.pathExtension)) }
                }
                try await session.load(from: urls)
                try Task.checkCancellation()
                guard self?.requestID == request else { return }
                self?.errorMessage = nil; self?.completedRequestID = request
            } catch is CancellationError {
                // A retired parse never changes a new context's alert, workbook or progress.
            } catch {
                guard self?.requestID == request else { return }
                self?.errorMessage = session.lastError ?? error.localizedDescription
            }
        }
    }
    func contextDidChange(session: ExcelSessionViewModel) {
        requestID = nil; operation?.cancel()
        // Do not release the physical/parser worker's resource ownership early.
        // Its task still reaches terminal completion; stale publication is denied by the session epoch.
        // Retain the retiring task until its terminal defer; a second parse cannot race its IO.
        isPickerPresented = false; errorMessage = nil; completedRequestID = nil; consumedRequestID = nil
        session.invalidatePendingWorkbookLoad(); session.withdrawPersistedEntry()
    }
}

/// Uses the existing RAM column-mapping row. PreGenerateView itself owns Queries and is not constructed here.
struct LocalWorkbookPreparationView: View {
    @ObservedObject var preparation: LocalWorkbookPreparation
    @ObservedObject var session: ExcelSessionViewModel
    let statusTitle: String
    let statusDetail: String
    var openOptions: (() -> Void)? = nil

    var body: some View {
        Form {
            Section {
                Text(statusTitle).font(.headline).accessibilityIdentifier("sync-replacement-business-data-gate")
                Text(statusDetail).font(.footnote).foregroundStyle(.secondary)
                if let openOptions { Button(L("sync.local.openOptions"), action: openOptions) }
                POSReadEntry()
            }
            Section {
                Button { preparation.isPickerPresented = true } label: {
                    Label(L("inventory.home.select_files"), systemImage: "doc.badge.plus")
                }
                .disabled(session.isLoading || preparation.isImporting)
                if session.isLoading || preparation.isImporting { ProgressView() }
                if session.hasData {
                    Text(L("inventory.home.file_loaded", max(session.rows.count - 1, 0), session.normalizedHeader.count))
                }
            }
            if session.hasData {
                Section(L("pregenerate.columns.title")) {
                    ForEach(session.sortedColumnIndices, id: \.self) { index in ColumnSelectionRow(index: index) }
                }
                Section(L("pregenerate.preview.title")) {
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading) {
                            ForEach(Array(session.rows.prefix(6).enumerated()), id: \.offset) { _, row in
                                Text(row.joined(separator: "  ·  ")).font(.caption).lineLimit(1)
                            }
                        }
                    }
                    TextField(L("product.field.supplier_name"), text: $session.supplierName)
                    TextField(L("product.field.category_name"), text: $session.categoryName)
                }
            }
        }
        .environmentObject(session)
        .alert(L("inventory.home.error.loading_title"), isPresented: Binding(
            get: { preparation.errorMessage != nil }, set: { if !$0 { preparation.errorMessage = nil } })) {
                Button(L("common.ok")) { preparation.errorMessage = nil }
            } message: { Text(preparation.errorMessage ?? "") }
        .accessibilityIdentifier("local-workbook-without-store")
    }
}

/// One stable presenter and activity token above the pending/opened and generation switches.
struct LocalWorkbookImportHost: ViewModifier {
    @ObservedObject var preparation: LocalWorkbookPreparation
    @ObservedObject var session: ExcelSessionViewModel
    let activityCenter: ForegroundCloudWorkflowActivityCenter

    func body(content: Content) -> some View {
        content
        .fileImporter(isPresented: $preparation.isPickerPresented, allowedContentTypes: [.spreadsheet, .html], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): preparation.load(urls, session: session)
            case .failure(let error):
                let error = error as NSError
                if !(error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError) { preparation.errorMessage = error.localizedDescription }
            }
        }
            .foregroundCloudWorkflowActivity(.importExcel,
                isActive: preparation.isPickerPresented || preparation.isImporting || session.isLoading)
            .environment(\.foregroundCloudWorkflowActivityCenter, activityCenter)
            #if DEBUG
            .safeAreaInset(edge: .top, alignment: .trailing, spacing: 0) {
                if let url = Task144LocalAvailabilityRootFixture.current?.independentDomainWorkbookURL {
                    Button("Load controlled workbook") { preparation.load([url], session: session) }
                        .accessibilityIdentifier("task146.b2.load-workbook")
                }
            }
            #endif
    }
}

struct SyncStoreOpeningShell: View {
    @ObservedObject var bootstrap: SyncStoreBootstrap
    @ObservedObject var preparation: LocalWorkbookPreparation
    @ObservedObject var session: ExcelSessionViewModel
    @Binding var selectedTab: Int
    @AppStorage("appTheme") private var appTheme = "system"
    @AppStorage("appLanguage") private var appLanguage = "system"

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LocalWorkbookPreparationView(preparation: preparation, session: session,
                    statusTitle: L(bootstrap.phase == .failed ? "sync.local.unavailable.title" : "options.safe.opening"),
                    statusDetail: L(bootstrap.phase == .failed ? "sync.local.unavailable.detail" : "sync.local.qualifying.detail"))
                    .navigationTitle(L("tab.inventory"))
            }.tabItem { Label(L("tab.inventory"), systemImage: "doc.on.doc") }.tag(0)
            unavailableTab(title: "tab.database", image: "shippingbox").tag(1)
            unavailableTab(title: "tab.history", image: "clock.arrow.circlepath").tag(2)
            NavigationStack {
                VStack(spacing: 0) {
                    if bootstrap.canRetry {
                        Button(L("options.supabase.automaticSync.action.retry")) { bootstrap.retry() }.padding()
                    }
                    SafeOptionsView(failure: SafeLocalCatalogFailure(code: bootstrap.failureCode ?? "local_store_unavailable"), opening: bootstrap.phase != .failed)
                }
            }.tabItem { Label(L("tab.options"), systemImage: "gearshape") }.tag(3)
        }
        .localeOverride(for: appLanguage)
        .preferredColorScheme(appTheme == "light" ? .light : appTheme == "dark" ? .dark : nil)
    }
    private func unavailableTab(title: String, image: String) -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label(L(bootstrap.phase == .failed ? "sync.local.unavailable.title" : "options.safe.opening"), systemImage: image)
            } description: { Text(L("sync.local.qualifying.detail")) }
            actions: { Button(L("sync.local.openOptions")) { selectedTab = 3 } }
            .navigationTitle(L(title))
        }.tabItem { Label(L(title), systemImage: image) }
    }
}
