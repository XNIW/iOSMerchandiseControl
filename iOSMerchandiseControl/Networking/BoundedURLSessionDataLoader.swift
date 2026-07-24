import Foundation

nonisolated enum BoundedHTTPBodyError: Error, Equatable, Sendable {
    case invalidContentLength
    case responseTooLarge(limit: Int)
}

/// Receives HTTP response bytes incrementally and stops the task before an
/// oversized body is accumulated. Content-Length is enforced at headers time;
/// chunked/unknown-length responses are bounded on every delegate callback.
nonisolated enum BoundedURLSessionDataLoader {
    typealias ResponseValidator = @Sendable (HTTPURLResponse) throws -> Void

    static func data(
        for request: URLRequest,
        configuration: URLSessionConfiguration,
        maximumBytes: Int,
        validateResponse: @escaping ResponseValidator
    ) async throws -> (Data, HTTPURLResponse) {
        let loader = Loader(
            request: request,
            configuration: configuration,
            maximumBytes: maximumBytes,
            validateResponse: validateResponse
        )
        return try await loader.load()
    }
}

private final class Loader: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate,
    @unchecked Sendable {
    private struct State {
        var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
        var data = Data()
        var response: HTTPURLResponse?
        var task: URLSessionDataTask?
        var finished = false
        var cancelled = false
    }

    private let configuration: URLSessionConfiguration
    private let lock = NSLock()
    private let maximumBytes: Int
    private let request: URLRequest
    private var state = State()
    private let validateResponse: BoundedURLSessionDataLoader.ResponseValidator
    private lazy var session = URLSession(
        configuration: configuration,
        delegate: self,
        delegateQueue: nil
    )

    init(
        request: URLRequest,
        configuration: URLSessionConfiguration,
        maximumBytes: Int,
        validateResponse: @escaping BoundedURLSessionDataLoader.ResponseValidator
    ) {
        self.request = request
        self.configuration = configuration
        self.maximumBytes = max(0, maximumBytes)
        self.validateResponse = validateResponse
    }

    func load() async throws -> (Data, HTTPURLResponse) {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request)
                let shouldStart = lock.withLock {
                    state.continuation = continuation
                    state.task = task
                    return !state.cancelled
                }
                if shouldStart {
                    task.resume()
                } else {
                    complete(.failure(CancellationError()))
                }
            }
        } onCancel: {
            self.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        do {
            guard let http = response as? HTTPURLResponse else {
                throw ProductImageError.invalidResponse
            }
            try validateResponse(http)
            try validateContentLength(http)
            lock.withLock { state.response = http }
            completionHandler(.allow)
        } catch {
            completionHandler(.cancel)
            complete(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        let overflow = lock.withLock { () -> Bool in
            let remaining = maximumBytes - state.data.count
            guard data.count <= remaining else { return true }
            state.data.append(data)
            return false
        }
        if overflow {
            dataTask.cancel()
            complete(.failure(BoundedHTTPBodyError.responseTooLarge(limit: maximumBytes)))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            if (error as? URLError)?.code == .cancelled,
               lock.withLock({ state.cancelled }) {
                complete(.failure(CancellationError()))
            } else {
                complete(.failure(error))
            }
            return
        }
        let result = lock.withLock { () -> Result<(Data, HTTPURLResponse), Error> in
            guard let response = state.response else {
                return .failure(ProductImageError.invalidResponse)
            }
            return .success((state.data, response))
        }
        complete(result)
    }

    private func validateContentLength(_ response: HTTPURLResponse) throws {
        guard let raw = response.value(forHTTPHeaderField: "Content-Length") else { return }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.allSatisfy(\.isNumber),
              let length = Int(value),
              length <= maximumBytes else {
            if let length = Int(value), length > maximumBytes {
                throw BoundedHTTPBodyError.responseTooLarge(limit: maximumBytes)
            }
            throw BoundedHTTPBodyError.invalidContentLength
        }
    }

    private func cancel() {
        let task = lock.withLock { () -> URLSessionDataTask? in
            state.cancelled = true
            return state.task
        }
        task?.cancel()
        complete(.failure(CancellationError()))
    }

    private func complete(_ result: Result<(Data, HTTPURLResponse), Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<(Data, HTTPURLResponse), Error>? in
            guard !state.finished else { return nil }
            state.finished = true
            defer {
                state.continuation = nil
                state.task = nil
            }
            return state.continuation
        }
        guard let continuation else { return }
        session.finishTasksAndInvalidate()
        continuation.resume(with: result)
    }
}
