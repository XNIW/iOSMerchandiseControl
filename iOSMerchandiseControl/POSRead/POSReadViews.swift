import Combine
import SwiftUI

@MainActor
struct POSReadRootView: View {
    @ObservedObject var model: POSReadViewModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appLanguage") private var appLanguage = "system"
    @State private var choosingPeriod = false
    @State private var overviewAnchor: UUID?
    var body: some View {
        NavigationStack {
            Group {
                switch model.route {
                case .overview: list(model.overview, history: false)
                case .history: list(model.history, history: true)
                case .detail: POSDetailView(model: model)
                case .filters: POSFilterView(model: model)
                }
            }
            .navigationTitle(L("pos.title"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.route == .overview || model.route == .history {
                        Button { model.showFilters() } label: { Label(L("pos.filters"), systemImage: "line.3.horizontal.decrease") }
                            .disabled(!model.salesReadAuthorized || model.isBusy)
                        Button { choosingPeriod = true } label: { Label(L("pos.history"), systemImage: "calendar") }
                    }
                }
            }
            .sheet(isPresented: $choosingPeriod) {
                POSPeriodPicker(initial: model.history?.period ?? model.overview?.period) { period in
                    choosingPeriod = false; model.showHistory(period)
                }
            }
        }
        .localeOverride(for: appLanguage)
        .onAppear { model.setForeground(scenePhase == .active); model.setVisible(true) }
        .onDisappear { model.setVisible(false) }
        .onChange(of: scenePhase) { _, phase in model.setForeground(phase == .active) }
    }
    private func list(_ snapshot: POSListSnapshot?, history: Bool) -> some View {
        VStack(spacing: 0) {
            if history {
                HStack {
                    Button(L("pos.today")) { model.showOverview() }
                    Spacer()
                    Button(L("pos.refresh")) { model.refreshHistory() }.disabled(model.isBusy || model.isStalled)
                }.padding()
            }
            if history && model.hasNewHistory {
                Button(L("pos.newData")) { model.refreshHistory() }
                    .buttonStyle(.borderedProminent).padding(.horizontal)
                    .accessibilityIdentifier("pos.history.newData")
            }
            POSNoticeView(notice: model.notice, busy: model.isBusy, stalled: model.isStalled, retry: model.retry)
            if let snapshot {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("pos.periodSummary")).font(.headline)
                            Text("\(snapshot.period.fromDate.raw) – \(snapshot.period.toDate.raw)").font(.subheadline)
                            Text(L("pos.summaryUnfiltered")).font(.caption).foregroundStyle(.secondary)
                            ForEach(snapshot.summaryDays) { day in POSSummaryDayView(day: day) }
                            POSFreshnessView(date: snapshot.fetchedAt, zone: snapshot.timeZone)
                        }
                        .accessibilityIdentifier("pos.period.summary")
                        Divider()
                        Text(L(history ? "pos.history" : "pos.recent")).font(.headline)
                        if snapshot.filters != .empty { Text(L("pos.listFiltersOnly")).font(.caption).foregroundStyle(.secondary) }
                        if snapshot.sales.isEmpty { ContentUnavailableView(L("pos.empty"), systemImage: "receipt") }
                        ForEach(snapshot.sales) { sale in
                            Button { model.showDetail(sale.id) } label: {
                                POSSaleRow(sale: sale, zone: snapshot.timeZone)
                            }
                            .buttonStyle(.plain).id(sale.id)
                            .accessibilityIdentifier("pos.sale.\(sale.id.uuidString.lowercased())")
                            Divider()
                        }
                        if history && snapshot.cursor != nil {
                            Button(L(snapshot.limitReached ? "pos.cacheLimit" : "pos.loadMore")) { model.loadMore() }
                                .frame(maxWidth: .infinity, minHeight: 44).disabled(!model.canLoadMore)
                        }
                    }
                    .scrollTargetLayout().padding()
                }
                .scrollPosition(id: history ? $model.anchorID : $overviewAnchor, anchor: .top)
                .accessibilityIdentifier(history ? "pos.history.list" : "pos.overview")
            } else if !model.isBusy && model.notice == nil {
                ContentUnavailableView(L("pos.verifyAccess"), systemImage: "lock.shield")
            }
            Spacer(minLength: 0)
        }
    }
}

@MainActor
private struct POSNoticeView: View {
    let notice: POSReadNotice?
    let busy: Bool
    let stalled: Bool
    let retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if busy { ProgressView(L("pos.loading")) }
            if let notice {
                Text(L(notice.key)).accessibilityIdentifier("pos.notice.\(notice.rawValue)")
                if !stalled { Button(L("pos.retry"), action: retry).frame(minHeight: 44) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding()
    }
}

@MainActor
private struct POSSummaryDayView: View {
    let day: POSDaySummary
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day.businessDate.raw).font(.subheadline)
            amount("pos.gross", day.grossSalesClp)
            amount("pos.discounts", day.discountsClp)
            amount("pos.refunds", day.refundsClp)
            amount("pos.net", day.netRevenueClp)
            Text(L("pos.transactionCount", day.transactionCount)).font(.caption)
        }
        .padding(.vertical, 6).accessibilityElement(children: .combine)
    }
    private func amount(_ key: String, _ value: POSAmount) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L(key)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value.formatted(locale: appLocale())).monospacedDigit().multilineTextAlignment(.trailing)
        }
    }
}

@MainActor
private struct POSSaleRow: View {
    let sale: POSSale
    let zone: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(sale.saleNumber).font(.headline)
                Spacer(minLength: 8)
                Text(sale.netAmountClp.formatted(locale: appLocale())).monospacedDigit().multilineTextAlignment(.trailing)
            }
            Text("\(L("pos.kind.\(sale.businessKind.rawValue)")) · \(L("pos.status.\(sale.saleStatus.rawValue)"))")
            Text(POSDisplay.timestamp(sale.occurredAt, zone: zone)).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}

@MainActor
private struct POSDetailView: View {
    @ObservedObject var model: POSReadViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Button(L("pos.back")) { model.returnFromDetail() }.frame(minHeight: 44).padding(.horizontal)
            if model.hasNewDetail { Button(L("pos.newData")) { model.refreshDetail() }.padding(.horizontal) }
            POSNoticeView(notice: model.notice, busy: model.isBusy, stalled: model.isStalled, retry: model.retry)
            if let detail = model.detail {
                List {
                    Section(L("pos.detail")) {
                        POSSaleRow(sale: detail.sale, zone: model.detailTimeZone ?? "UTC")
                        LabeledContent(L("pos.fiscalStatus"), value: detail.sale.fiscalStatus)
                        if let name = detail.sale.staffName { LabeledContent(L("pos.staff"), value: name) }
                        if let name = detail.sale.deviceName { LabeledContent(L("pos.device"), value: name) }
                        LabeledContent(L("pos.payment"), value: detail.sale.paymentMethods.joined(separator: ", "))
                    }
                    Section(L("pos.lines")) {
                        ForEach(detail.lines) { line in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(line.productName ?? line.itemNumber ?? L("pos.line"))
                                if let barcode = line.barcode { Text(barcode).font(.caption) }
                                LabeledContent(L("pos.quantity"), value: line.quantity.formatted(locale: appLocale()))
                                LabeledContent(L("pos.unitAmount"), value: line.unitAmountClp.formatted(locale: appLocale()))
                                LabeledContent(L("pos.lineAmount"), value: line.lineAmountClp.formatted(locale: appLocale()))
                            }.accessibilityElement(children: .combine)
                        }
                    }
                    if let fetched = model.detailFetchedAt {
                        POSFreshnessView(date: fetched, zone: model.detailTimeZone ?? "UTC")
                    }
                }.accessibilityIdentifier("pos.detail")
                Button(L("pos.refresh")) { model.refreshDetail() }.disabled(model.isBusy).padding()
            }
            Spacer(minLength: 0)
        }
    }
}

@MainActor
private struct POSFilterView: View {
    @ObservedObject var model: POSReadViewModel
    @State private var draft = POSFilters.empty
    var body: some View {
        VStack {
            POSNoticeView(notice: model.notice, busy: model.isBusy, stalled: model.isStalled, retry: model.retry)
            if let options = model.filterOptions {
                Form {
                    Section(L("pos.listFiltersOnly")) {
                        Picker(L("pos.status"), selection: $draft.status) {
                            Text(L("pos.all")).tag(Optional<POSSaleStatus>.none)
                            ForEach(POSSaleStatus.allCases, id: \.self) { Text(L("pos.status.\($0.rawValue)")).tag(Optional($0)) }
                        }
                        Picker(L("pos.kind"), selection: $draft.businessKind) {
                            Text(L("pos.all")).tag(Optional<POSBusinessKind>.none)
                            ForEach(POSBusinessKind.allCases, id: \.self) { Text(L("pos.kind.\($0.rawValue)")).tag(Optional($0)) }
                        }
                        Picker(L("pos.payment"), selection: $draft.paymentMethod) {
                            Text(L("pos.all")).tag(Optional<String>.none)
                            ForEach(options.paymentMethods, id: \.self) { Text($0).tag(Optional($0)) }
                        }
                        TextField(L("pos.saleNumber"), text: Binding(get: { draft.saleNumber ?? "" }, set: { draft.saleNumber = $0.isEmpty ? nil : String($0.prefix(80)) }))
                        if options.canFilterOperationalMetadata {
                            Picker(L("pos.staff"), selection: $draft.staffID) {
                                Text(L("pos.all")).tag(Optional<UUID>.none)
                                ForEach(options.staff) { Text($0.name).tag(Optional($0.id)) }
                            }
                            Picker(L("pos.device"), selection: $draft.deviceID) {
                                Text(L("pos.all")).tag(Optional<UUID>.none)
                                ForEach(options.devices) { Text($0.name).tag(Optional($0.id)) }
                            }
                        }
                    }
                    Button(L("pos.apply")) { model.applyFilters(draft) }.accessibilityIdentifier("pos.filters.apply")
                    Button(L("pos.clear")) { draft = .empty }
                }.accessibilityIdentifier("pos.filters")
            }
            Button(L("pos.back")) { model.dismissFilters() }.frame(minHeight: 44)
        }.onAppear { draft = model.filters }
    }
}

@MainActor
private struct POSPeriodPicker: View {
    let initial: POSPeriod?
    let select: (POSPeriod) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var from = Date()
    @State private var to = Date()
    @State private var invalid = false
    var body: some View {
        NavigationStack {
            Form {
                DatePicker(L("pos.from"), selection: $from, displayedComponents: .date)
                DatePicker(L("pos.to"), selection: $to, displayedComponents: .date)
                Text(L("pos.datePolicy")).font(.caption)
                if invalid { Text(L("pos.rangeInvalid")).foregroundStyle(.red) }
                Button(L("pos.apply")) {
                    let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
                    f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"
                    do { select(try POSPeriod(from: POSBusinessDate(f.string(from: from)), to: POSBusinessDate(f.string(from: to)))) }
                    catch { invalid = true }
                }
            }
            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            .navigationTitle(L("pos.period"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("pos.back")) { dismiss() } } }
        }
        .onAppear { if let initial { from = initial.fromDate.utcDate; to = initial.toDate.utcDate } }
    }
}

@MainActor
private struct POSFreshnessView: View {
    let date: Date
    let zone: String
    var body: some View {
        Text(L("pos.updatedAt", POSDisplay.date(date, zone: zone), zone))
            .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("pos.freshness")
    }
}

@MainActor
private enum POSDisplay {
    static func timestamp(_ raw: POSRawTimestamp, zone: String) -> String {
        raw.displayDate.map { date($0, zone: zone) } ?? raw.raw
    }
    static func date(_ value: Date, zone: String) -> String {
        let f = DateFormatter(); f.locale = appLocale(); f.timeZone = TimeZone(identifier: zone)
        f.dateStyle = .medium; f.timeStyle = .medium; return f.string(from: value)
    }
}

// Optional integration leaf only. Host retains its existing inventory action;
// sessions/Excel History remains a different route and receives no POS payload.
@MainActor
struct POSInventoryDomainEntries: View {
    @ObservedObject var model: POSReadViewModel
    let openSales: () -> Void
    let openInventory: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            if model.salesReadNavigationPriority { sales; inventory }
            else { inventory; sales }
        }
    }
    private var sales: some View { Button(action: openSales) { Label(L("pos.title"), systemImage: "receipt") }.frame(minHeight: 44) }
    private var inventory: some View { Button(action: openInventory) { Label(L("pos.inventoryEntry"), systemImage: "shippingbox") }.frame(minHeight: 44) }
}


private struct POSReadEntryActionKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> Void)? = nil
}

private extension EnvironmentValues {
    var openPOSRead: (@MainActor () -> Void)? {
        get { self[POSReadEntryActionKey.self] }
        set { self[POSReadEntryActionKey.self] = newValue }
    }
}

struct POSReadEntry: View {
    @Environment(\.openPOSRead) private var open

    var body: some View {
        if let open {
            Button(action: open) { Label(L("pos.title"), systemImage: "receipt") }
                .accessibilityIdentifier("pos.inventory.entry")
        }
    }
}

/// The presenter and its one reader survive store opening and generation replacement.
struct POSReadPresentationHost: ViewModifier {
    @ObservedObject var auth: SupabaseAuthViewModel
    let remote: SupabaseTransportClient?
    @Environment(\.scenePhase) private var scenePhase
    @State private var module: POSReadModule?
    @State private var presented = false

    func body(content: Content) -> some View {
        observeScope(presentingPOS(content))
    }

    private var entryAction: (@MainActor () -> Void)? {
        guard remote != nil else { return nil }
        return { open() }
    }

    private func presentingPOS(_ content: Content) -> some View {
        content
            .environment(\.openPOSRead, entryAction)
            .sheet(isPresented: $presented) {
                sheetContent.task { await prepareReader() }
            }
    }

    @ViewBuilder
    private var sheetContent: some View {
        if let module {
            POSReadRootView(model: module.model)
        } else {
            ProgressView()
        }
    }

    private func observeScope(_ content: some View) -> some View {
        let defaultsChanges = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
        return content
            .onChange(of: auth.state) { _, _ in
                module?.refreshScope()
            }
            .onChange(of: auth.sessionInfo) { _, _ in
                module?.refreshScope()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, presented { module?.refreshScope(retryDevice: true) }
            }
            .onReceive(defaultsChanges) { _ in
                module?.refreshScope()
            }
    }

    private func prepareReader() async {
        guard let remote else { return }
        if module == nil {
            let reader = await POSReadModule.make(remote: remote, auth: auth)
            guard !Task.isCancelled else { return }
            module = reader
        }
        module?.refreshScope(retryDevice: true)
    }

    private func open() {
        module?.refreshScope(retryDevice: true)
        presented = true
    }
}
