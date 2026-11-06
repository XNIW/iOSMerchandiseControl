import Foundation

/// Owns a single reader independently of the business store and catalog.
@MainActor
final class POSReadModule {
    private struct RequestScope: Equatable {
        let ownerID: UUID
        let shopID: UUID
        let generation: UUID
        let selectionStamp: String?
        let authorizationRevision: Int
        let deviceMirror: String?
        let denied: Bool
    }

    private final class Inputs {
        weak var auth: SupabaseAuthViewModel?
        let provider: SupabaseClientProvider
        let selectedShops = SelectedShopStore()
        let devices = DeviceInstallIDStore()
        var network = AutomaticSyncNetworkStatus.unknown
        var published: (input: RequestScope, scope: POSReadScope)?

        init(auth: SupabaseAuthViewModel, provider: SupabaseClientProvider) {
            self.auth = auth
            self.provider = provider
        }

        func requestScope() -> RequestScope? {
            guard let auth, auth.isSignedIn, !auth.isTransitioning, let owner = auth.sessionInfo?.userID else { return nil }
            let account = AccountBindingStore.accountHash(for: owner)
            let selectionStamp = selectedShops.readSelectionStamp(accountHash: account)
            guard let selected = selectedShops.selectedShop(accountHash: account),
                  selected.selectable, selected.status == "active" else { return nil }
            let generation = provider.authSnapshot.generation
            guard provider.acceptsAuthGeneration(generation),
                  !provider.requiresReauthentication(generation: generation) else { return nil }
            let device = devices.lastKnownDeviceInstallID
            let denied = device.map {
                selectedShops.hasConfirmedDeviceDenial(accountHash: account, shopID: selected.shopID,
                    deviceIdentityHash: DeviceInstallIDStore.identityHash(for: $0))
            } ?? false
            return RequestScope(ownerID: owner, shopID: selected.shopID, generation: generation,
                selectionStamp: selectionStamp, authorizationRevision: selectedShops.localAuthorizationRevision,
                deviceMirror: device, denied: denied)
        }

        var currentScope: POSReadScope? {
            guard let published, published.input == requestScope() else { return nil }
            return published.scope
        }
    }

    let model: POSReadViewModel
    private let inputs: Inputs
    private var observer: AutomaticSyncNetworkReachabilityObserver?
    private var authTask: Task<Void, Never>?
    private var deviceTask: Task<Void, Never>?
    private var verifiedDevice: String?
    private var failedDeviceInput: RequestScope?

    static func make(remote: SupabaseTransportClient, auth: SupabaseAuthViewModel) async -> POSReadModule {
        POSReadModule(provider: await remote.manualRequestProvider(), auth: auth)
    }

    private init(provider: SupabaseClientProvider, auth: SupabaseAuthViewModel) {
        let inputs = Inputs(auth: auth, provider: provider)
        self.inputs = inputs
        let transport = POSRPCTransport(provider: provider, currentScope: { inputs.currentScope },
                                        online: { inputs.network == .satisfied })
        model = POSReadViewModel(transport: transport, currentAuthority: { inputs.currentScope == $0 })
        observer = AutomaticSyncNetworkReachabilityObserver { [weak self] status in
            guard let self else { return }
            inputs.network = status
            refreshScope()
        }
        observer?.start()
        authTask = Task { [weak self] in
            for await _ in provider.authClientChanges() {
                guard !Task.isCancelled, let self else { return }
                refreshScope()
            }
        }
    }

    // UI observes auth and persisted selection changes to update its state promptly.
    // Dispatch, delivery and render each consult currentScope independently.
    func refreshScope(retryDevice: Bool = false) {
        let request = inputs.requestScope()
        if let request, !request.denied, let device = verifiedDevice, request.deviceMirror == device {
            if inputs.published?.input != request,
               let scope = try? POSReadScope(ownerID: request.ownerID, shopID: request.shopID,
                   deviceIdentifier: device, authGeneration: request.generation, authorizationEpoch: UUID()) {
                inputs.published = (request, scope)
            }
            model.update(scope: inputs.currentScope, network: inputs.network)
            return
        }
        inputs.published = nil
        model.update(scope: nil, network: inputs.network, confirmedDenial: request?.denied == true)
        guard let request, !request.denied, deviceTask == nil,
              retryDevice || failedDeviceInput != request else { return }
        // The existing durable identity lookup can lock, migrate or fsync. Only this small
        // identity read runs here, outside MainActor and outside the business-store opener.
        let devices = inputs.devices
        deviceTask = Task { [weak self] in
            let device = await Task.detached(priority: .userInitiated) {
                try? devices.requireDeviceInstallID()
            }.value
            guard !Task.isCancelled, let self else { return }
            deviceTask = nil
            verifiedDevice = device == devices.lastKnownDeviceInstallID ? device : nil
            failedDeviceInput = verifiedDevice == nil ? inputs.requestScope() : nil
            refreshScope()
        }
    }

    isolated deinit {
        observer?.cancel()
        authTask?.cancel()
        deviceTask?.cancel()
        model.shutdown()
    }
}
