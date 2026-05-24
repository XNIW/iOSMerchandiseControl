#if DEBUG
import Combine
import Foundation

@MainActor
final class SupabaseSyncEventDebugViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case successEmpty
        case successWithEvents
        case error(message: String)
        case noSession
        case notConfigured

        var isLoading: Bool {
            if case .loading = self {
                return true
            }
            return false
        }

        var canRefresh: Bool {
            switch self {
            case .successEmpty, .successWithEvents, .error:
                return true
            case .idle, .loading, .noSession, .notConfigured:
                return false
            }
        }
    }

    @Published private(set) var state: ViewState = .idle
    @Published private(set) var displayRows: [SyncEventDebugDisplayRow] = []
    @Published private(set) var summary: SyncEventDebugDisplaySummary?

    private let service: SupabaseSyncEventPreviewService?
    private var currentTask: Task<SyncEventPreviewSummary, Error>?
    private var requestID = 0

    init(service: SupabaseSyncEventPreviewService?) {
        self.service = service
    }

    deinit {
        currentTask?.cancel()
    }

    var isLoading: Bool {
        state.isLoading
    }

    func loadLatestEvents() async {
        guard !state.isLoading else { return }

        guard let service else {
            invalidateCurrentTask()
            clearDisplayBuffer()
            state = .notConfigured
            return
        }

        requestID += 1
        let activeRequestID = requestID
        state = .loading

        let task = Task {
            let summary = try await service.loadLatestEvents()
            try Task.checkCancellation()
            return summary
        }
        currentTask = task

        do {
            let loadedSummary = try await task.value
            guard activeRequestID == requestID else { return }
            apply(summary: loadedSummary)
            currentTask = nil
        } catch is CancellationError {
            guard activeRequestID == requestID else { return }
            clearDisplayBuffer()
            state = .idle
            currentTask = nil
        } catch let error as SupabaseInventoryServiceError {
            guard activeRequestID == requestID else { return }
            clearDisplayBuffer()
            currentTask = nil
            if case .sessionMissing = error {
                state = .noSession
            } else {
                state = .error(message: sanitizedMessage(for: error))
            }
        } catch {
            guard activeRequestID == requestID else { return }
            clearDisplayBuffer()
            currentTask = nil
            state = .error(message: sanitizedMessage(for: error))
        }
    }

    func cancel() {
        invalidateCurrentTask()
        clearDisplayBuffer()
        state = .idle
    }

    func reset() {
        cancel()
    }

    private func apply(summary loadedSummary: SyncEventPreviewSummary) {
        summary = SyncEventDebugDisplaySummary(summary: loadedSummary)
        displayRows = SyncEventDebugDisplayRow.rows(from: loadedSummary.events)
        state = loadedSummary.events.isEmpty ? .successEmpty : .successWithEvents
    }

    private func invalidateCurrentTask() {
        requestID += 1
        currentTask?.cancel()
        currentTask = nil
    }

    private func clearDisplayBuffer() {
        displayRows = []
        summary = nil
    }

    private func sanitizedMessage(for error: SupabaseInventoryServiceError) -> String {
        let baseMessage: String

        switch error {
        case .configMissing:
            baseMessage = L("options.supabase.diagnostic.configMissing")
        case .invalidConfig:
            baseMessage = L("options.supabase.diagnostic.invalidConfig")
        case .sessionMissing:
            baseMessage = L("options.supabase.diagnostic.sessionMissing")
        case .networkError:
            baseMessage = L("options.supabase.diagnostic.networkError")
        case .permissionDeniedOrRLS:
            baseMessage = L("options.supabase.diagnostic.permissionDeniedOrRLS")
        case .decodingError:
            baseMessage = L("options.supabase.diagnostic.decodingError")
        case .schemaDrift:
            baseMessage = L("options.supabase.diagnostic.schemaDrift")
        case .unknown:
            baseMessage = L("options.supabase.diagnostic.unknown")
        }

        guard let detail = sanitizedDetail(error.safeDiagnosticDetail) else {
            return baseMessage
        }

        return L("options.supabase.diagnostic.messageWithDetail", baseMessage, detail)
    }

    private func sanitizedMessage(for error: Error) -> String {
        let baseMessage = L("options.supabase.diagnostic.unknown")
        guard let detail = sanitizedDetail(String(describing: error)) else {
            return baseMessage
        }

        return L("options.supabase.diagnostic.messageWithDetail", baseMessage, detail)
    }

    private func sanitizedDetail(_ detail: String?) -> String? {
        guard let detail else { return nil }
        return SyncEventDebugFormatter.sanitizedPreview(from: detail, maxLength: 160)
    }
}
#endif
