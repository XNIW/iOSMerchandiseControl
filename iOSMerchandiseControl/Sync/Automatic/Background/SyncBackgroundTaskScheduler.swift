import BackgroundTasks
import Foundation
import SwiftData

nonisolated enum SyncBackgroundTaskConstants {
    static let appRefreshIdentifier = "com.niwcyber.iOSMerchandiseControl.sync.refresh"
}

nonisolated enum SyncBackgroundScheduleReason: String, Sendable {
    case appLaunch
    case foregroundCompletion
    case localPendingWrite
    case networkReconnect
    case periodicOpportunity
}

@MainActor
protocol SyncBackgroundTaskScheduling: AnyObject {
    func schedule(reason: SyncBackgroundScheduleReason)
}

@MainActor
final class SyncNoopBackgroundTaskScheduler: SyncBackgroundTaskScheduling {
    func schedule(reason: SyncBackgroundScheduleReason) {}
}

@MainActor
final class SyncBackgroundTaskScheduler: SyncBackgroundTaskScheduling {
    static let shared = SyncBackgroundTaskScheduler()

    private let defaults: UserDefaults
    private var isRegistered = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func register() {
        guard !isRegistered else { return }
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SyncBackgroundTaskConstants.appRefreshIdentifier,
            using: nil
        ) { task in
            Task {
                await SyncBackgroundTaskRunner.handle(task)
            }
        }
        isRegistered = registered
        defaults.set(registered, forKey: "sync.runtime.background.registrationSucceeded")
        defaults.set(Date().timeIntervalSince1970, forKey: "sync.runtime.background.registrationAttemptedAt")
    }

    func schedule(reason: SyncBackgroundScheduleReason) {
        let request = BGAppRefreshTaskRequest(identifier: SyncBackgroundTaskConstants.appRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            defaults.set(reason.rawValue, forKey: "sync.runtime.background.lastScheduleReason")
            defaults.set(Date().timeIntervalSince1970, forKey: "sync.runtime.background.lastScheduledAt")
            defaults.set(true, forKey: "sync.runtime.background.lastScheduleSucceeded")
        } catch {
            defaults.set(reason.rawValue, forKey: "sync.runtime.background.lastScheduleReason")
            defaults.set(Date().timeIntervalSince1970, forKey: "sync.runtime.background.lastScheduleFailedAt")
            defaults.set(false, forKey: "sync.runtime.background.lastScheduleSucceeded")
            defaults.set(
                SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(String(describing: error)) ?? "background_schedule_error",
                forKey: "sync.runtime.background.lastScheduleError"
            )
        }
    }
}

nonisolated enum SyncBackgroundTaskRunner {
    static func handle(_ task: BGTask) async {
        guard task is BGAppRefreshTask else {
            task.setTaskCompleted(success: false)
            return
        }

        let drainTask = Task {
            await drainOnce()
        }
        task.expirationHandler = {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "sync.runtime.background.lastExpiredAt")
            drainTask.cancel()
        }

        let success = await drainTask.value
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "sync.runtime.background.lastCompletedAt")
        UserDefaults.standard.set(success, forKey: "sync.runtime.background.lastCompletedSuccessfully")
        task.setTaskCompleted(success: success)

        await MainActor.run {
            SyncBackgroundTaskScheduler.shared.schedule(reason: .periodicOpportunity)
        }
    }

    static func drainOnce() async -> Bool {
        do {
            let config = try SupabaseConfig.load()
            let provider = SupabaseClientProvider(config: config)
            let authService = SupabaseAuthService(provider: provider)
            guard let session = authService.currentSession,
                  !session.isExpired else {
                UserDefaults.standard.set("blocked_auth", forKey: "sync.runtime.background.lastOutcome")
                return false
            }

            let modelContainer = try makeModelContainer()
            let transport = SupabaseTransportClient(clientProvider: provider)
            let recorder: (any SyncEventRecording)? = SupabaseSyncEventLiveRecorder(
                configProvider: SupabaseSyncEventLiveRecorderConfigurationProvider(),
                sessionProvider: authService,
                transport: SupabaseSyncEventRPCTransport(clientProvider: provider)
            )
            let engine = AutomaticSyncEngine(
                catalogPushProvider: CatalogPushService(
                    modelContainer: modelContainer,
                    remote: CatalogRemoteSupabaseAdapter(remote: transport)
                ),
                productPriceProvider: ProductPricePushService(
                    modelContainer: modelContainer,
                    remote: ProductPriceRemoteSupabaseAdapter(remote: transport)
                ),
                historySessionProvider: HistorySessionPushService(
                    modelContainer: modelContainer,
                    remote: HistorySessionRemoteSupabaseAdapter(remote: transport),
                    recorder: recorder
                ),
                incrementalPullProvider: SyncEventIncrementalPullService(
                    modelContainer: modelContainer,
                    remote: SyncEventRemoteSupabaseAdapter(remote: transport)
                ),
                activityRegistrationProvider: SyncActivityRegistrationService(
                    modelContainer: modelContainer,
                    recorder: recorder
                )
            )
            let result = await engine.run(
                action: .sequence([.pushPending, .drainEvents]),
                source: .backgroundRefresh,
                ownerUserID: session.userID
            )
            UserDefaults.standard.set(result.status.rawValue, forKey: "sync.runtime.background.lastOutcome")
            UserDefaults.standard.set(result.didWork, forKey: "sync.runtime.background.lastDidWork")
            return result.status == .success || result.status == .noWork || result.status == .scheduledRetry
        } catch is CancellationError {
            UserDefaults.standard.set("cancelled", forKey: "sync.runtime.background.lastOutcome")
            return false
        } catch {
            UserDefaults.standard.set("failed", forKey: "sync.runtime.background.lastOutcome")
            UserDefaults.standard.set(
                SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(String(describing: error)) ?? "background_drain_error",
                forKey: "sync.runtime.background.lastError"
            )
            return false
        }
    }

    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
