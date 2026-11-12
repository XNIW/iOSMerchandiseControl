import Combine
import Foundation

nonisolated enum POSReadRoute: Equatable, Sendable { case overview, history, detail(UUID), filters }
nonisolated enum POSReadNotice: String, Sendable {
    case connect, offline, denied, unavailable, timeout, stalled, invalidData, notFound, repositioned, cacheLimit
    var key: String { "pos.notice.\(rawValue)" }
}

@MainActor
final class POSReadViewModel: ObservableObject {
    private enum Purpose: Equatable { case overview, historyInitial, historyStage, historyRefresh, page, refreshPage, detail, detailStage, filter }
    private struct Intent { let request: POSReadRequest; let purpose: Purpose }
    private final class Active {
        let id = UUID()
        let scope: POSReadScope
        let queryEpoch: UUID
        let intent: Intent
        let deadline: TimeInterval
        let flight: any POSReadFlight
        var cancelled = false
        init(scope: POSReadScope, queryEpoch: UUID, intent: Intent, deadline: TimeInterval, flight: any POSReadFlight) {
            self.scope = scope; self.queryEpoch = queryEpoch; self.intent = intent; self.deadline = deadline; self.flight = flight
        }
    }
    @Published private(set) var route: POSReadRoute = .overview
    @Published private(set) var notice: POSReadNotice? = .connect
    @Published private(set) var isBusy = false
    @Published private(set) var hasNewHistory = false
    @Published private(set) var hasNewDetail = false
    @Published private(set) var isStalled = false
    @Published private(set) var lastFlightEvidence: POSFlightReleaseEvidence?
    @Published var anchorID: UUID?
    @Published var selectedSaleID: UUID?
    @Published private var cache = POSRAMCache()
    @Published private var authorized = false
    @Published private var entryReadVerified = false
    @Published private(set) var detailFetchedAt: Date?
    private(set) var detailTimeZone: String?
    @Published private var detailValue: POSDetailData?
    @Published private var filterValue: POSFilterData?
    private let transport: any POSReadTransport
    private let clock: POSReadClock
    private let currentAuthority: @MainActor (POSReadScope) -> Bool
    private let jitter: @MainActor () -> Double
    private var scope: POSReadScope?
    private var online = false
    private var foreground = false
    private var visible = false
    private var queryEpoch = UUID()
    private var period: POSPeriod?
    private(set) var filters = POSFilters.empty
    private var acceptedAuthorization: POSAuthorization?
    private var overviewID: UUID?
    private var historyID: UUID?
    private var stagedHistoryID: UUID?
    private var refreshAnchor: UUID?
    private var historyLimitBlocked = false
    private var filterReturnRoute = POSReadRoute.overview
    private var detailReturnRoute = POSReadRoute.overview
    private var active: Active?
    private var pending: Intent?
    private var poll = POSPollPolicy()
    private var wakeTask: Task<Void, Never>?
    private var responseTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var drainTask: Task<Void, Never>?

    init(transport: any POSReadTransport, clock: POSReadClock = .live,
         currentAuthority: @escaping @MainActor (POSReadScope) -> Bool,
         jitter: @escaping @MainActor () -> Double = { Double.random(in: 0...1) }) {
        self.transport = transport; self.clock = clock; self.currentAuthority = currentAuthority; self.jitter = jitter
    }
    isolated deinit {
        wakeTask?.cancel(); deadlineTask?.cancel(); drainTask?.cancel(); active?.flight.cancel(); responseTask?.cancel()
    }
    private var mayRequest: Bool {
        guard let scope else { return false }
        return online && foreground && visible && !isStalled && currentAuthority(scope)
    }
    var salesReadAuthorized: Bool { mayRequest && authorized }
    var salesReadNavigationPriority: Bool {
        guard let scope else { return false }; return online && entryReadVerified && currentAuthority(scope)
    }
    var overview: POSListSnapshot? { salesReadAuthorized ? cache[overviewID] : nil }
    var history: POSListSnapshot? { salesReadAuthorized && refreshAnchor == nil ? cache[historyID] : nil }
    var detail: POSDetailData? { salesReadAuthorized ? detailValue : nil }
    var filterOptions: POSFilterData? { salesReadAuthorized ? filterValue : nil }
    var canReadMetadata: Bool {
        guard salesReadAuthorized else { return false }
        return (route == .overview ? cache[overviewID] : cache[historyID])?.metadataRead
            ?? filterValue?.canFilterOperationalMetadata ?? false
    }
    var canLoadMore: Bool { history?.cursor != nil && !(history?.limitReached ?? true) && !isBusy && !historyLimitBlocked }

    // The outer auth/shop/device observer calls this synchronously BEFORE route
    // presentation. No catalog canWrite, ModelContext or local proof grants POS.
    func update(scope newScope: POSReadScope?, network: AutomaticSyncNetworkStatus, confirmedDenial: Bool = false) {
        let changed = scope != newScope
        let wasOnline = online
        scope = newScope; online = network == .satisfied
        if changed {
            queryEpoch = UUID(); authorized = false; entryReadVerified = false; filters = .empty; period = nil; route = .overview; cache.clear(); acceptedAuthorization = nil; overviewID = nil; historyID = nil
            stagedHistoryID = nil; detailValue = nil; filterValue = nil; hasNewHistory = false; hasNewDetail = false
            anchorID = nil; selectedSaleID = nil; refreshAnchor = nil; historyLimitBlocked = false; pending = nil; poll = POSPollPolicy()
            cancelActive()
        }
        if newScope == nil || !online || confirmedDenial {
            authorized = false; entryReadVerified = false; pending = nil; detailValue = nil; filterValue = nil; wakeTask?.cancel(); cancelActive()
            notice = confirmedDenial ? .denied : (newScope == nil ? .connect : .offline)
        } else if changed || !wasOnline { requestCurrent(stageExisting: true) }
    }
    func setForeground(_ value: Bool) {
        guard foreground != value else { return }; foreground = value
        if value { requestCurrent(stageExisting: true) }
        else { authorized = false; pending = nil; wakeTask?.cancel(); cancelActive() }
    }
    func setVisible(_ value: Bool) {
        guard visible != value else { return }; visible = value
        if value { requestCurrent(stageExisting: true) }
        else { authorized = false; pending = nil; wakeTask?.cancel(); cancelActive() }
    }
    func shutdown() {
        visible = false; foreground = false; authorized = false; pending = nil
        cache.clear(); detailValue = nil; filterValue = nil; wakeTask?.cancel(); cancelActive()
    }
    func showOverview() {
        navigate(.overview); requestCurrent(stageExisting: false)
    }
    func showHistory(_ selectedPeriod: POSPeriod) {
        if period != selectedPeriod { cache.remove(historyID); historyID = nil; anchorID = nil; selectedSaleID = nil }
        period = selectedPeriod; historyLimitBlocked = false; navigate(.history); requestCurrent(stageExisting: true)
    }
    func showDetail(_ id: UUID) {
        detailReturnRoute = route; selectedSaleID = id; navigate(.detail(id)); detailValue = nil; requestCurrent(stageExisting: false)
    }
    func showFilters() { filterReturnRoute = route; navigate(.filters); requestCurrent(stageExisting: false) }
    func returnFromDetail() { navigate(detailReturnRoute); requestCurrent(stageExisting: true) }
    func dismissFilters() { navigate(filterReturnRoute); requestCurrent(stageExisting: true) }
    func applyFilters(_ value: POSFilters) {
        do { try value.validate() } catch { notice = .invalidData; return }
        guard canReadMetadata || (value.staffID == nil && value.deviceID == nil) else { notice = .denied; return }
        filters = value; cache.remove(historyID); historyID = nil; anchorID = nil; selectedSaleID = nil
        historyLimitBlocked = false; navigate(filterReturnRoute); requestCurrent(stageExisting: false)
    }
    func retry() {
        guard !isStalled else { return }; poll.stopped = false
        requestCurrent(stageExisting: route == .history || { if case .detail = route { return true }; return false }())
    }
    func refreshHistory() {
        guard let period else { return }
        // Explicit refresh preserves value-only anchor/selection and releases the
        // old chain before building a bounded replacement. It never claims a
        // cross-request server snapshot. Missing anchor reports repositioning.
        historyLimitBlocked = false; refreshAnchor = anchorID; cache.remove(historyID); historyID = nil
        cache.remove(stagedHistoryID); stagedHistoryID = nil; hasNewHistory = false
        queryEpoch = UUID()
        submit(try? Intent(request: POSReadRequest(action: .summary, period: period, filters: filters, limit: 100), purpose: .historyRefresh))
    }
    func refreshDetail() {
        guard case let .detail(id) = route else { return }
        detailValue = nil; hasNewDetail = false; queryEpoch = UUID()
        submit(try? Intent(request: POSReadRequest(action: .detail, saleID: id), purpose: .detail))
    }
    func loadMore() {
        guard let snapshot = history, let cursor = snapshot.cursor, !snapshot.limitReached else { return }
        let remaining = POSReadLimits.maximumSales - snapshot.sales.count
        guard remaining > 0 else { notice = .cacheLimit; return }
        submit(try? Intent(request: POSReadRequest(action: .page, period: snapshot.period, filters: snapshot.filters,
                                                 cursor: cursor, limit: min(100, remaining)), purpose: .page))
    }
    private func navigate(_ route: POSReadRoute) {
        self.route = route; queryEpoch = UUID(); pending = nil; wakeTask?.cancel(); cancelActive()
        detailValue = nil; filterValue = nil; hasNewDetail = false; notice = nil
    }
    private func requestCurrent(stageExisting: Bool) {
        guard mayRequest else { return }
        do {
            switch route {
            case .overview: submit(Intent(request: try POSReadRequest(action: .summary, filters: filters), purpose: .overview))
            case .history:
                guard let period else { return }
                submit(Intent(request: try POSReadRequest(action: .summary, period: period, filters: filters, limit: 100),
                              purpose: stageExisting && cache[historyID] != nil ? .historyStage : .historyInitial))
            case let .detail(id):
                submit(Intent(request: try POSReadRequest(action: .detail, saleID: id),
                              purpose: stageExisting && detailValue != nil ? .detailStage : .detail))
            case .filters:
                guard let range = period ?? cache[overviewID]?.period else { notice = .connect; return }
                submit(Intent(request: try POSReadRequest(action: .filter, period: range), purpose: .filter))
            }
        } catch { notice = .invalidData }
    }
    private func submit(_ intent: Intent?) {
        guard let intent, mayRequest else { return }
        if let active {
            if !active.cancelled && active.queryEpoch == queryEpoch && active.intent.purpose == intent.purpose
                && active.intent.request.cursor == intent.request.cursor { return }
            pending = intent; cancelActive(); return
        }
        if intent.purpose == .overview && !poll.admits(at: clock.now()) {
            guard !poll.stopped else { return }
            pending = intent; scheduleWake(at: poll.nextStart); return
        }
        guard let scope else { return }
        let deadline = clock.now() + (intent.purpose == .overview ? 2 : 8)
        do {
            let flight = try transport.start(intent.request, scope: scope, deadline: deadline)
            let active = Active(scope: scope, queryEpoch: queryEpoch, intent: intent, deadline: deadline, flight: flight)
            self.active = active; isBusy = true; notice = nil
            if intent.purpose == .overview { poll.didStart(at: clock.now()) }
            responseTask = Task { @MainActor [weak self, flight] in
                let result: Result<POSReadReply, Error>
                do { result = .success(try await flight.response()) } catch { result = .failure(error) }
                self?.received(result, activeID: active.id)
            }
            let clock = clock
            deadlineTask = Task { @MainActor [weak self] in
                do { try await clock.sleepUntil(deadline) } catch { return }
                guard let self, self.active?.id == active.id else { return }
                self.authorized = false; self.notice = .timeout
                if active.intent.purpose == .overview {
                    self.poll.failed(at: clock.now(), jitterFraction: self.jitter() * 0.2, retryAfter: nil)
                }
                self.cancelActive()
            }
        } catch { fail(error, purpose: intent.purpose); scheduleNextOverview() }
    }
    private func received(_ result: Result<POSReadReply, Error>, activeID: UUID) {
        guard let active, active.id == activeID, !isStalled else { return }
        guard active.flight.isQuiescent else { cancelActive(); return }
        let stillCurrent = !active.cancelled && active.queryEpoch == queryEpoch && active.scope == scope
            && mayRequest && clock.now() < active.deadline
        if stillCurrent {
            do {
                let reply = try result.get()
                try publish(reply, intent: active.intent, scope: active.scope)
                authorized = true; entryReadVerified = true
                if active.intent.purpose == .overview { poll.succeeded(at: clock.now(), phaseJitter: jitter() * 0.25) }
            } catch { fail(error, purpose: active.intent.purpose) }
        } else if !active.cancelled && active.queryEpoch == queryEpoch && active.scope == scope {
            authorized = false; notice = .timeout
            poll.failed(at: clock.now(), jitterFraction: jitter() * 0.2, retryAfter: nil)
        }
        release(activeID)
    }
    private func publish(_ reply: POSReadReply, intent: Intent, scope: POSReadScope) throws {
        if let previous = acceptedAuthorization,
           previous.metadataRead != reply.authorization.metadataRead || previous.shopDeviceID != reply.authorization.shopDeviceID
            || previous.timeZone != reply.authorization.timeZone {
            // A fresh viewer/changed-device envelope cannot reauthorize cached
            // owner metadata, even when the caller's local epoch did not change.
            cache.clear(); overviewID = nil; historyID = nil; stagedHistoryID = nil
            detailValue = nil; filterValue = nil; hasNewHistory = false; hasNewDetail = false
        }
        acceptedAuthorization = reply.authorization
        switch reply.payload {
        case let .summary(value):
            let snapshot = try POSListSnapshot(summary: value, authorization: reply.authorization, filters: filters, fetchedAt: Date())
            switch intent.purpose {
            case .overview:
                overviewID = try cache.insert(snapshot, scope: scope, replacing: overviewID)
            case .historyStage:
                if cache[historyID] == nil {
                    historyID = try cache.insert(snapshot, scope: scope); hasNewHistory = false; return
                }
                hasNewHistory = true
                // A full deep chain can consume the entire budget: retain only
                // its invalidation marker if staging would exceed any limit.
                stagedHistoryID = try? cache.insert(snapshot, scope: scope, replacing: stagedHistoryID,
                                                   protecting: Set([historyID].compactMap { $0 }))
            default:
                historyID = try cache.insert(snapshot, scope: scope, replacing: historyID)
                if intent.purpose == .historyRefresh { continueAnchorRefresh() }
            }
        case let .page(value):
            guard var snapshot = cache[historyID], snapshot.cursor == intent.request.cursor else { throw POSReadError.staleScope }
            try snapshot.append(value, authorization: reply.authorization)
            if snapshot.sales.count == POSReadLimits.maximumSales && snapshot.cursor != nil { snapshot.limitReached = true }
            historyID = try cache.insert(snapshot, scope: scope, replacing: historyID)
            if intent.purpose == .refreshPage { continueAnchorRefresh() }
        case let .detail(value):
            if intent.purpose == .detailStage && detailValue != nil { hasNewDetail = true; return }
            let charge = (try JSONEncoder().encode(value).count) * 4 + value.lines.count * 256 + 512
            try cache.reserveForDetail(charge: charge)
            detailValue = value; detailFetchedAt = Date(); detailTimeZone = reply.authorization.timeZone; hasNewDetail = false
        case let .filter(value):
            try cache.reserveForDetail(charge: (try JSONEncoder().encode(value).count) * 4 + 1_024)
            filterValue = value
        }
    }
    private func continueAnchorRefresh() {
        guard let snapshot = cache[historyID], let target = refreshAnchor else { return }
        if snapshot.sales.contains(where: { $0.id == target }) { anchorID = target; refreshAnchor = nil; return }
        if let cursor = snapshot.cursor, snapshot.sales.count < POSReadLimits.maximumSales {
            pending = try? Intent(request: POSReadRequest(action: .page, period: snapshot.period, filters: snapshot.filters,
                                                         cursor: cursor, limit: min(100, 500 - snapshot.sales.count)), purpose: .refreshPage)
        } else {
            anchorID = snapshot.sales.first?.id; refreshAnchor = nil; notice = .repositioned
            if let selectedSaleID, !snapshot.sales.contains(where: { $0.id == selectedSaleID }) { self.selectedSaleID = nil }
        }
    }
    private func cancelActive() {
        guard let active, !active.cancelled else { return }
        active.cancelled = true; active.flight.cancel(); deadlineTask?.cancel()
        let end = clock.now() + 1; let clock = clock
        drainTask = Task { @MainActor [weak self] in
            do { try await clock.sleepUntil(end) } catch { return }
            guard let self, self.active?.id == active.id else { return }
            if active.flight.isQuiescent { self.release(active.id) }
            else {
                self.isStalled = true; self.authorized = false; self.isBusy = false; self.pending = nil
                self.lastFlightEvidence = active.flight.releaseEvidence
                self.notice = .stalled; self.poll.stopped = true; self.wakeTask?.cancel()
                // Keep the actual flight. A deadline never creates capacity.
            }
        }
    }
    private func release(_ id: UUID) {
        guard active?.id == id, active?.flight.isQuiescent == true, !isStalled else { return }
        lastFlightEvidence = active?.flight.releaseEvidence
        deadlineTask?.cancel(); drainTask?.cancel(); active = nil; responseTask = nil; isBusy = false
        if let pending { self.pending = nil; submit(pending) }
        else { scheduleNextOverview() }
    }
    private func scheduleNextOverview() {
        guard mayRequest, route == .overview, !poll.stopped, active == nil else { return }
        scheduleWake(at: max(clock.now(), poll.nextStart))
    }
    private func scheduleWake(at deadline: TimeInterval) {
        wakeTask?.cancel(); let clock = clock
        wakeTask = Task { @MainActor [weak self] in
            do { try await clock.sleepUntil(deadline) } catch { return }
            guard let self, self.mayRequest, self.active == nil else { return }
            if let pending = self.pending { self.pending = nil; self.submit(pending) }
            else if self.route == .overview { self.requestCurrent(stageExisting: false) }
        }
    }
    private func fail(_ error: Error, purpose: Purpose) {
        let failure: POSReadError
        if let value = error as? POSReadError { failure = value }
        else if error is DecodingError { failure = .invalidPayload }
        else if error is CancellationError { failure = .cancelled }
        else if let url = error as? URLError {
            failure = url.code == .notConnectedToInternet ? .offline : (url.code == .timedOut ? .deadline : .unavailable)
        } else { failure = .unavailable }
        var retryAfter: TimeInterval?
        switch failure {
        case .denied("not_found") where purpose == .detail || purpose == .detailStage: detailValue = nil; notice = .notFound
        case .denied, .staleScope, .http(401, _), .http(403, _):
            authorized = false; entryReadVerified = false; cache.clear(); detailValue = nil; filterValue = nil; poll.stopped = true; notice = .denied
        case .invalidPayload, .incompatibleContract, .http(404, _):
            authorized = false; poll.stopped = true; notice = failure == .invalidPayload ? .invalidData : .unavailable
        case .cacheLimit:
            historyLimitBlocked = true; refreshAnchor = nil; notice = .cacheLimit
        case .offline: authorized = false; notice = .offline
        case .deadline: authorized = false; notice = .timeout
        case .stalled: authorized = false; isStalled = true; poll.stopped = true; notice = .stalled
        case .http(_, let delay): retryAfter = delay; notice = .unavailable
        case .cancelled: break
        default: notice = .unavailable
        }
        if purpose == .overview && !poll.stopped {
            poll.failed(at: clock.now(), jitterFraction: jitter() * 0.2, retryAfter: retryAfter)
        }
    }
}
