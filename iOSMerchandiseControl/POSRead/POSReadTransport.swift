import Foundation
import Supabase

nonisolated struct POSHTTPReleaseEvidence: Sendable {
    let cancelledAt: TimeInterval?
    let completedAt: TimeInterval?
    let invalidatedAt: TimeInterval?
}
nonisolated struct POSFlightReleaseEvidence: Sendable {
    let cancelledAt: TimeInterval?
    let operationReturnedAt: TimeInterval?
    let cancelledDuringSharedRefresh: Bool
    let http: [POSHTTPReleaseEvidence]
}

@MainActor
protocol POSReadFlight: AnyObject {
    var isQuiescent: Bool { get }
    var releaseEvidence: POSFlightReleaseEvidence? { get }
    func response() async throws -> POSReadReply
    func cancel()
}

@MainActor
extension POSReadFlight { var releaseEvidence: POSFlightReleaseEvidence? { nil } }

@MainActor
protocol POSReadTransport: AnyObject {
    func start(_ request: POSReadRequest, scope: POSReadScope, deadline: TimeInterval) throws -> any POSReadFlight
}

nonisolated struct POSReadClock: Sendable {
    var now: @Sendable () -> TimeInterval
    var sleepUntil: @Sendable (TimeInterval) async throws -> Void
    static let live = Self(now: { ProcessInfo.processInfo.systemUptime }, sleepUntil: { deadline in
        let remaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        try await Task.sleep(nanoseconds: UInt64(min(remaining, 86_400) * 1_000_000_000))
        try Task.checkCancellation()
    })
}

// One transport instance is retained with the root POS module, across scope changes.
// A cancelled shared SDK refresh is conservatively stalled: this module cannot
// cancel a refresh owned by the existing auth client on behalf of other domains.
@MainActor
final class POSRPCTransport: POSReadTransport {
    private let provider: SupabaseClientProvider
    private let currentScope: @MainActor () -> POSReadScope?
    private let online: @MainActor () -> Bool
    private let clock: POSReadClock
    private var heldFlight: POSRPCFlight?

    init(provider: SupabaseClientProvider, currentScope: @escaping @MainActor () -> POSReadScope?,
         online: @escaping @MainActor () -> Bool, clock: POSReadClock = .live) {
        self.provider = provider; self.currentScope = currentScope; self.online = online; self.clock = clock
    }

    func start(_ request: POSReadRequest, scope: POSReadScope, deadline: TimeInterval) throws -> any POSReadFlight {
        guard heldFlight?.isQuiescent != false else { throw POSReadError.stalled }
        try validate(scope, deadline: deadline)
        let snapshot = provider.authSnapshot
        guard snapshot.generation == scope.authGeneration else { throw POSReadError.staleScope }
        let flight = POSRPCFlight()
        heldFlight = flight
        flight.begin { [self, flight] in
            try validate(scope, deadline: deadline)
            guard var session = snapshot.client.auth.currentSession, session.user.id == scope.ownerID else {
                throw POSReadError.denied("unauthenticated")
            }
            let bytes = try JSONEncoder().encode(POSRPCParameters(scope: scope, request: request))
            guard bytes.count <= SupabaseTransportClient.maximumRPCRequestBytes else { throw POSReadError.invalidPayload }
            // Exactly one normal POST per attempt; at most one existing SDK refresh
            // after HTTP401, all within the ORIGINAL total deadline.
            for attempt in 0...1 {
                try Task.checkCancellation(); try validate(scope, deadline: deadline)
                guard !session.accessToken.isEmpty, !session.accessToken.contains("\n"), !session.accessToken.contains("\r") else {
                    throw POSReadError.denied("unauthenticated")
                }
                let url = provider.config.projectURL.appendingPathComponent("rest/v1/rpc/mobile_sales_read_v1")
                var wire = URLRequest(url: url)
                wire.httpMethod = "POST"; wire.httpBody = bytes
                wire.cachePolicy = .reloadIgnoringLocalCacheData
                wire.timeoutInterval = max(0.001, deadline - clock.now())
                wire.setValue("application/json", forHTTPHeaderField: "Accept")
                wire.setValue("application/json", forHTTPHeaderField: "Content-Type")
                wire.setValue(provider.config.publishableKey, forHTTPHeaderField: "apikey")
                wire.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                do {
                    let exchange = POSHTTPExchange(request: wire, maximumBytes: POSReadLimits.maximumResponseBytes)
                    flight.exchange = exchange
                    let data: Data
                    do { data = try await exchange.load() }
                    catch { flight.remember(exchange); flight.exchange = nil; throw error }
                    flight.remember(exchange); flight.exchange = nil
                    try Task.checkCancellation(); try validate(scope, deadline: deadline)
                    let decode = Task.detached(priority: .userInitiated) {
                        try Task.checkCancellation()
                        let reply = try POSReadDecoder.decode(data, request: request, scope: scope)
                        try Task.checkCancellation(); return reply
                    }
                    let reply = try await withTaskCancellationHandler { try await decode.value } onCancel: { decode.cancel() }
                    try validate(scope, deadline: deadline)
                    return reply
                } catch POSReadError.http(401, _) where attempt == 0 {
                    flight.exchange = nil
                    try validate(scope, deadline: deadline)
                    flight.refreshAwaiting = true
                    do { session = try await snapshot.client.auth.refreshSession() }
                    catch {
                        flight.refreshAwaiting = false
                        guard provider.acceptsAuthGeneration(scope.authGeneration) else { throw POSReadError.staleScope }
                        provider.recordSessionReadFailure(error, generation: scope.authGeneration)
                        throw error
                    }
                    flight.refreshAwaiting = false
                    try Task.checkCancellation(); try validate(scope, deadline: deadline)
                    guard session.user.id == scope.ownerID else { throw POSReadError.staleScope }
                }
            }
            throw POSReadError.denied("unauthenticated")
        }
        return flight
    }

    private func validate(_ scope: POSReadScope, deadline: TimeInterval) throws {
        guard online() else { throw POSReadError.offline }
        guard currentScope() == scope, provider.acceptsAuthGeneration(scope.authGeneration),
              !provider.requiresReauthentication(generation: scope.authGeneration) else { throw POSReadError.staleScope }
        guard clock.now() < deadline else { throw POSReadError.deadline }
    }
}

@MainActor
private final class POSRPCFlight: POSReadFlight {
    private var task: Task<POSReadReply, Error>?
    private var returned = false
    private var cancelledSharedRefresh = false
    private var cancelledAt: TimeInterval?
    private var returnedAt: TimeInterval?
    private var httpProofs: [POSHTTPReleaseEvidence] = []
    var releaseEvidence: POSFlightReleaseEvidence? {
        POSFlightReleaseEvidence(cancelledAt: cancelledAt, operationReturnedAt: returnedAt,
            cancelledDuringSharedRefresh: cancelledSharedRefresh,
            http: httpProofs + (exchange.map { [$0.releaseProof] } ?? []))
    }
    func remember(_ exchange: POSHTTPExchange) { httpProofs.append(exchange.releaseProof) }
    var refreshAwaiting = false
    var exchange: POSHTTPExchange?
    var isQuiescent: Bool { returned && !cancelledSharedRefresh }
    func begin(_ operation: @escaping @MainActor () async throws -> POSReadReply) {
        precondition(task == nil)
        task = Task { @MainActor [self] in
            defer { returned = true; returnedAt = ProcessInfo.processInfo.systemUptime; exchange = nil }
            return try await operation()
        }
    }
    func response() async throws -> POSReadReply {
        guard let task else { throw POSReadError.stalled }
        defer { self.task = nil }
        return try await task.value
    }
    func cancel() {
        cancelledAt = cancelledAt ?? ProcessInfo.processInfo.systemUptime
        if refreshAwaiting { cancelledSharedRefresh = true }
        task?.cancel(); exchange?.cancel()
    }
}

// Domain-specific bounded read loader. Completion resumes ONLY after the actual
// URLSession invalidation callback; a cancellation continuation is not a release.
nonisolated final class POSHTTPExchange: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private struct State {
        var continuation: CheckedContinuation<Data, Error>?
        var session: URLSession?
        var task: URLSessionDataTask?
        var body = Data()
        var result: Result<Data, Error>?
        var cancelled = false
        var taskCompleted = false
        var invalidated = false
        var cancelledAt: TimeInterval?
        var completedAt: TimeInterval?
        var invalidatedAt: TimeInterval?
    }
    private let lock = NSLock()
    private var state = State()
    private let request: URLRequest
    private let maximumBytes: Int
    private let configuration: URLSessionConfiguration
    private let onInvalidation: @Sendable () -> Void
    var releaseProof: POSHTTPReleaseEvidence {
        lock.withLock { POSHTTPReleaseEvidence(cancelledAt: state.cancelledAt, completedAt: state.completedAt, invalidatedAt: state.invalidatedAt) }
    }
    init(request: URLRequest, maximumBytes: Int, configuration: URLSessionConfiguration = .ephemeral,
         onInvalidation: @escaping @Sendable () -> Void = {}) {
        self.request = request; self.maximumBytes = maximumBytes
        self.configuration = configuration.copy() as! URLSessionConfiguration; self.onInvalidation = onInvalidation
    }

    func load() async throws -> Data {
        let config = configuration.copy() as! URLSessionConfiguration
        config.urlCache = nil; config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = request.timeoutInterval
        config.timeoutIntervalForResource = request.timeoutInterval
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        lock.withLock { state.session = session }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let installed = lock.withLock { () -> (URLSessionDataTask?, Result<Data, Error>?) in
                    if state.invalidated { return (nil, state.result ?? .failure(POSReadError.invalidPayload)) }
                    state.continuation = continuation
                    if state.cancelled { return (nil, nil) }
                    let task = session.dataTask(with: request); state.task = task
                    return (task, nil)
                }
                if let result = installed.1 { continuation.resume(with: result) }
                else if let task = installed.0 { task.resume() }
                else { session.invalidateAndCancel() }
            }
        } onCancel: { self.cancel() }
    }

    func cancel() {
        let owned = lock.withLock { () -> (URLSessionDataTask?, URLSession?) in
            state.cancelled = true; state.cancelledAt = state.cancelledAt ?? ProcessInfo.processInfo.systemUptime
            state.result = .failure(CancellationError())
            return (state.task, state.session)
        }
        owned.0?.cancel(); owned.1?.invalidateAndCancel()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        do {
            guard let http = response as? HTTPURLResponse, http.url == request.url else { throw POSReadError.invalidPayload }
            guard (200..<300).contains(http.statusCode) else {
                let retry = SupabaseTransportClient.retryAfterUntil(http.value(forHTTPHeaderField: "Retry-After"), now: Date())
                throw POSReadError.http(http.statusCode, retryAfter: retry.map { max(0, $0.timeIntervalSinceNow) })
            }
            guard http.mimeType == "application/json" else { throw POSReadError.invalidPayload }
            if let raw = http.value(forHTTPHeaderField: "Content-Length") {
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
                      let count = Int(value), count <= maximumBytes else { throw POSReadError.invalidPayload }
            }
            completionHandler(.allow)
        } catch {
            lock.withLock { if state.result == nil { state.result = .failure(error) } }
            completionHandler(.cancel)
        }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let overflow = lock.withLock { () -> Bool in
            guard state.result == nil else { return true }
            guard data.count <= maximumBytes - state.body.count else {
                state.result = .failure(POSReadError.invalidPayload); return true
            }
            state.body.append(data); return false
        }
        if overflow { dataTask.cancel() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.withLock {
            state.taskCompleted = true; state.completedAt = ProcessInfo.processInfo.systemUptime
            if state.result == nil {
                if let error { state.result = .failure(error) }
                else { state.result = .success(state.body) }
            }
        }
        session.finishTasksAndInvalidate()
    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        let delivery = lock.withLock { () -> (CheckedContinuation<Data, Error>?, Result<Data, Error>) in
            state.invalidated = true; state.invalidatedAt = ProcessInfo.processInfo.systemUptime
            let result: Result<Data, Error>
            if state.task != nil && !state.taskCompleted { result = .failure(POSReadError.stalled) }
            else { result = state.result ?? .failure(error ?? POSReadError.invalidPayload) }
            state.result = result
            let continuation = state.continuation
            state.continuation = nil; state.task = nil; state.session = nil; state.body = Data()
            return (continuation, result)
        }
        onInvalidation()
        delivery.0?.resume(with: delivery.1)
    }
}
