import SwiftUI

#if DEBUG
private struct Task143StorefrontScopeOverrideKey: EnvironmentKey {
    static let defaultValue: StorefrontScope? = nil
}

private struct Task143StorefrontCanMutateOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var task143StorefrontScopeOverride: StorefrontScope? {
        get { self[Task143StorefrontScopeOverrideKey.self] }
        set { self[Task143StorefrontScopeOverrideKey.self] = newValue }
    }

    var task143StorefrontCanMutateOverride: Bool {
        get { self[Task143StorefrontCanMutateOverrideKey.self] }
        set { self[Task143StorefrontCanMutateOverrideKey.self] = newValue }
    }
}
#endif

@MainActor
func resolvedStorefrontScope(
    auth: SupabaseAuthViewModel,
    shopContext: ShopContextStore
) -> StorefrontScope? {
    guard auth.isSignedIn,
          let accountID = auth.sessionInfo?.userID,
          shopContext.context.accountHash == AccountBindingStore.accountHash(for: accountID),
          let selectedShop = shopContext.context.selectedShop,
          selectedShop.isValidProductImageSelection else {
        return nil
    }
    return StorefrontScope(accountID: accountID, shopID: selectedShop.shopID)
}

struct StorefrontFilterBar: View {
    @Binding var selection: StorefrontListFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StorefrontListFilter.allCases) { filter in
                    Button {
                        selection = filter
                    } label: {
                        Text(label(filter))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .frame(minHeight: 36)
                            .background(
                                selection == filter ? Color.accentColor : Color(.tertiarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(selection == filter ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == filter ? .isSelected : [])
                    .accessibilityIdentifier("storefront.filter.\(filter.rawValue)")
                }
            }
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("storefront.filters.title"))
    }

    private func label(_ filter: StorefrontListFilter) -> String {
        L("storefront.filter.\(filter.rawValue)")
    }
}

struct StorefrontProductRowSummary: View {
    @EnvironmentObject private var store: StorefrontAuthoringStore
    let productID: UUID?
    let scope: StorefrontScope?

    var body: some View {
        Group {
            if productID == nil {
                Label(L("storefront.sync.required.short"), systemImage: "icloud.slash")
                    .foregroundStyle(.orange)
            } else if let productID,
                      let summary = store.summary(for: productID) {
                HStack(spacing: 6) {
                    Label(statusLabel(summary.publicationStatus), systemImage: statusIcon(summary.publicationStatus))
                        .foregroundStyle(statusColor(summary.publicationStatus))
                    if summary.differsFromOperational {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                            .accessibilityLabel(L("storefront.differs"))
                    }
                    if store.conflictedProductIDs.contains(productID) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityLabel(L("storefront.conflict"))
                    }
                }
            } else {
                Label(L("storefront.status.unpublished"), systemImage: "storefront")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .task(id: taskID) {
            guard let productID, let scope else { return }
            store.requestVisibleSummary(productID: productID, scope: scope)
        }
    }

    private var taskID: String {
        "\(scope?.cacheNamespace ?? "none").\(productID?.uuidString ?? "none")"
    }
}

struct StorefrontEditorSection: View {
    @Environment(\.localModelGenerationIsCurrent) private var modelGenerationIsCurrent
    @Environment(\.localRootPresentationState) private var localPresentation
    @EnvironmentObject private var auth: SupabaseAuthViewModel
    @EnvironmentObject private var shopContext: ShopContextStore
    @EnvironmentObject private var store: StorefrontAuthoringStore
    @EnvironmentObject private var productImageStore: ProductImageStore
    #if DEBUG
    @Environment(\.task143StorefrontScopeOverride) private var debugScopeOverride
    @Environment(\.task143StorefrontCanMutateOverride) private var debugCanMutateOverride
    #endif

    let product: Product?
    let operationalName: String
    let operationalRetailPrice: Double?
    let operationalCategoryRemoteID: UUID?
    private let capturedRemoteID: UUID?
    private let mountedPresentationID: String?

    init(product: Product?, operationalName: String, operationalRetailPrice: Double?, operationalCategoryRemoteID: UUID?, presentationID: String? = nil) {
        self.product = product
        self.operationalName = operationalName
        self.operationalRetailPrice = operationalRetailPrice
        self.operationalCategoryRemoteID = operationalCategoryRemoteID
        self.capturedRemoteID = product?.remoteID
        self.mountedPresentationID = presentationID
    }

    private var isCurrentModelGeneration: Bool {
        modelGenerationIsCurrent() && (localPresentation?.isCurrent(presentationID: mountedPresentationID) ?? true)
    }
    private var currentProduct: Product? { isCurrentModelGeneration ? product : nil }
    private var currentRemoteID: UUID? { isCurrentModelGeneration ? capturedRemoteID : nil }

    @State private var expanded = false
    @State private var draftExpectedVersion: Int64 = 0
    @State private var publication: StorefrontPublication?
    @State private var categories: [StorefrontCategory] = []
    @State private var draft = StorefrontEditorDraft()
    @State private var baseDraft = StorefrontEditorDraft()
    @State private var conflict: StorefrontPublication?
    @State private var loading = false
    @State private var mutating = false
    @State private var adoptingImage = false
    @State private var message: String?
    @State private var localDraft = false
    @State private var operationTask: Task<Void, Never>?
    @State private var reachabilityObserver: AutomaticSyncNetworkReachabilityObserver?
    @State private var isActive = false

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                expandedEditor
                    .disabled(loading || mutating || adoptingImage)
            } label: {
                collapsedSummary
                    .accessibilityIdentifier("storefront.editor.disclosure")
            }
        } header: {
            Text(L("storefront.section.title"))
        } footer: {
            if let message {
                Text(message)
                    .foregroundStyle(messageIsError ? .red : .secondary)
                    .accessibilityIdentifier("storefront.editor.message")
            }
        }
        .task(id: scopeTaskID) {
            isActive = true
            startReconnectObservationIfNeeded()
            guard let scope else { return }
            store.activate(scope: scope)
            await load(scope: scope)
        }
        .onDisappear {
            isActive = false
            operationTask?.cancel()
            operationTask = nil
            reachabilityObserver?.cancel()
            reachabilityObserver = nil
        }
        .onChange(of: scopeTaskID) { _, _ in
            operationTask?.cancel()
            conflict = nil
            publication = nil
            draftExpectedVersion = 0
            mutating = false
            adoptingImage = false
            categories = []
            draft = StorefrontEditorDraft()
            baseDraft = StorefrontEditorDraft()
            localDraft = false
        }
    }

    private var scope: StorefrontScope? {
        #if DEBUG
        if let debugScopeOverride { return debugScopeOverride }
        #endif
        return resolvedStorefrontScope(auth: auth, shopContext: shopContext)
    }

    private var scopeTaskID: String {
        "\(scope?.cacheNamespace ?? "none").\(currentRemoteID?.uuidString ?? "unreconciled")"
    }

    private var canMutate: Bool {
        #if DEBUG
        if debugCanMutateOverride,
           store.isAvailable,
           scope != nil,
           currentRemoteID != nil,
           !mutating,
           !adoptingImage {
            return true
        }
        #endif
        guard store.isAvailable,
              scope != nil,
              currentRemoteID != nil,
              shopContext.context.syncAllowed,
              let selected = shopContext.context.selectedShop else { return false }
        return selected.canWrite && selected.isValidProductImageSelection && !mutating && !adoptingImage
    }

    private var messageIsError: Bool {
        guard let message else { return false }
        return message == L("storefront.error.permission")
            || message == L("storefront.error.contract")
            || message == L("storefront.error.validation")
    }

    @ViewBuilder
    private var collapsedSummary: some View {
        if currentRemoteID == nil {
            Label(L("storefront.sync.required"), systemImage: "icloud.slash")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        } else if loading {
            HStack {
                ProgressView()
                Text(L("storefront.loading"))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(statusLabel(publication?.publicationStatus ?? .unpublished), systemImage: "storefront")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if localDraft {
                        Text(L("storefront.local_draft"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                HStack(alignment: .top, spacing: 10) {
                    storefrontThumbnail
                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.publicName.isEmpty ? L("storefront.public_name.empty") : draft.publicName)
                            .lineLimit(2)
                        Text(publicPriceText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(categorySummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let publication {
                    Text(L("storefront.version_updated", publication.version, formattedUpdatedAt(publication.updatedAt)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var storefrontThumbnail: some View {
        if let imagePublicationID = draft.publicImageId,
           let scope {
            StorefrontPublicImageView(
                scope: ProductImageScope(accountID: scope.accountID, shopID: scope.shopID),
                imagePublicationID: imagePublicationID,
                publicURL: publication?.publicImageId == imagePublicationID
                    ? safePublicImageURL(publication?.publicImageThumbnailUrl)
                    : nil,
                variant: .thumb,
                contentMode: .fill
            )
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: draft.publicImageId == nil ? "photo" : "photo.badge.checkmark")
                .frame(width: 54, height: 54)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var expandedEditor: some View {
        if !store.isAvailable {
            Label(L("storefront.unavailable"), systemImage: "lock.fill")
                .foregroundStyle(.secondary)
        } else if currentRemoteID == nil {
            Label(L("storefront.sync.required"), systemImage: "icloud.slash")
                .foregroundStyle(.orange)
        } else {
            if let conflict {
                conflictCard(conflict)
            }

            TextField(L("storefront.field.public_name"), text: $draft.publicName)
                .textInputAutocapitalization(.words)
                .accessibilityLabel(L("storefront.field.public_name"))
                .accessibilityIdentifier("storefront.editor.public-name")

            TextField(L("storefront.field.description"), text: $draft.publicDescription, axis: .vertical)
                .lineLimit(3...8)

            TextField(L("storefront.field.brand"), text: $draft.publicBrand)

            Picker(L("storefront.field.category"), selection: $draft.storefrontCategoryId) {
                Text(L("storefront.category.choose")).tag(UUID?.none)
                ForEach(categories.filter { $0.status == "active" }) { category in
                    Text(category.publicName).tag(Optional(category.categoryId))
                }
            }

            HStack {
                Text(L("storefront.internal_price"))
                Spacer()
                Text(operationalPriceText).monospacedDigit()
            }
            .font(.subheadline)

            TextField(L("storefront.field.public_price"), text: int64Binding(\StorefrontEditorDraft.publicPrice))
                .keyboardType(.numberPad)
                .monospacedDigit()
                .accessibilityLabel(L("storefront.field.public_price"))
                .accessibilityIdentifier("storefront.editor.public-price")

            TextField(L("storefront.field.compare_at_price"), text: int64Binding(\StorefrontEditorDraft.compareAtPrice))
                .keyboardType(.numberPad)
                .monospacedDigit()

            Picker(L("storefront.field.availability"), selection: $draft.availability) {
                ForEach(StorefrontAvailability.allCases, id: \.self) { value in
                    Text(L("storefront.availability.\(value.rawValue)")).tag(value)
                }
            }

            Toggle(L("storefront.field.pickup"), isOn: $draft.pickupEnabled)
            Toggle(L("storefront.field.delivery"), isOn: $draft.deliveryEnabled)
            Toggle(L("storefront.field.reservation"), isOn: $draft.reservationEnabled)
            Toggle(L("storefront.field.featured"), isOn: $draft.featured)

            TextField(L("storefront.field.home_order"), text: int64Binding(\StorefrontEditorDraft.homeOrder, optional: false))
                .keyboardType(.numberPad)

            TextField(L("storefront.field.starts_at"), text: optionalStringBinding(\StorefrontEditorDraft.promotionStartsAt))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField(L("storefront.field.ends_at"), text: optionalStringBinding(\StorefrontEditorDraft.promotionEndsAt))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            imageAdoptionRow

            Button {
                alignWithOperationalProduct()
            } label: {
                Label(L("storefront.action.align"), systemImage: "arrow.left.arrow.right")
            }
            .disabled(mutating || adoptingImage)

            actionGrid
        }
    }

    @ViewBuilder
    private var imageAdoptionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("storefront.field.public_image"))
                .font(.subheadline.weight(.semibold))
            if let imageScope,
               let productID = currentRemoteID,
               let versionID = currentProduct?.primaryImageVersionID {
                ProductImageRemoteView(
                    scope: imageScope,
                    productID: productID,
                    versionID: versionID,
                    variant: .thumb
                )
                .frame(width: 72, height: 72)
                Button {
                    adoptOperationalImage()
                } label: {
                    Label(L("storefront.action.use_client_image"), systemImage: "photo.badge.checkmark")
                }
                .disabled(!canMutate || publication == nil || adoptingImage)
            } else {
                Text(L("storefront.image.operational_missing"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var imageScope: ProductImageScope? {
        guard let scope else { return nil }
        let bindingStore = AccountBindingStore()
        return ProductImageOwnerStoreGate.scope(
            accountID: scope.accountID,
            selectedShop: shopContext.context.selectedShop,
            binding: bindingStore.currentBinding,
            hasPendingReplacement: bindingStore.hasPendingReplacementJournal
        )
    }

    private var actionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                storefrontAction(
                    L("storefront.action.save_draft"),
                    icon: "square.and.arrow.down",
                    identifier: "storefront.action.save-draft"
                ) {
                    mutate(.saveDraft)
                }
                storefrontAction(
                    L("storefront.action.publish"),
                    icon: "paperplane.fill",
                    identifier: "storefront.action.publish"
                ) {
                    mutate(.publish)
                }
            }
            HStack {
                storefrontAction(
                    L("storefront.action.schedule"),
                    icon: "calendar.badge.clock",
                    identifier: "storefront.action.schedule"
                ) {
                    mutate(.schedule)
                }
                storefrontAction(
                    L("storefront.action.hide"),
                    icon: "eye.slash",
                    identifier: "storefront.action.hide"
                ) {
                    mutate(.hide)
                }
            }
            HStack {
                storefrontAction(
                    L("storefront.action.archive"),
                    icon: "archivebox",
                    identifier: "storefront.action.archive"
                ) {
                    mutate(.archive)
                }
                NavigationLink {
                    StorefrontPublicPreview(
                        draft: draft,
                        publication: publication,
                        scope: scope
                    )
                } label: {
                    Label(L("storefront.action.preview"), systemImage: "eye")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("storefront.action.preview")
            }
            Button {
                guard let scope else { return }
                operationTask?.cancel()
                operationTask = Task { await load(scope: scope) }
            } label: {
                Label(L("storefront.action.reload"), systemImage: "arrow.clockwise")
            }
            .disabled(loading || mutating)
        }
    }

    private func storefrontAction(
        _ title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!canMutate || publication?.publicationStatus == .archived)
        .accessibilityIdentifier(identifier)
    }

    private func conflictCard(_ server: StorefrontPublication) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("storefront.conflict"), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(L("storefront.conflict.server", server.version, sourceLabel(server.mutationSource), formattedUpdatedAt(server.updatedAt)))
                .font(.caption)
            Text(L("storefront.conflict.local_fields", storefrontChangedFields(base: baseDraft, draft: draft).count))
                .font(.caption)
            HStack {
                Button(L("storefront.action.reload")) {
                    reloadFromConflict(server)
                }
                Button(L("storefront.action.reapply")) {
                    reapplyConflict(server)
                }
                Button(L("common.cancel")) {
                    conflict = nil
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("storefront.editor.conflict")
    }

    private func load(scope: StorefrontScope) async {
        guard let productID = currentRemoteID else { return }
        loading = true
        message = nil
        do {
            let snapshot = try await store.loadEditor(scope: scope, productID: productID)
            guard isActive, self.scope == scope, !Task.isCancelled else { return }
            publication = snapshot.publication
            draftExpectedVersion = snapshot.localExpectedVersion ?? snapshot.publication?.version ?? 0
            categories = snapshot.categories
            draft = snapshot.draft
            baseDraft = snapshot.baseDraft
            conflict = snapshot.conflict
            localDraft = snapshot.isLocalDraft
            message = snapshot.isServerVerified
                ? (snapshot.conflict == nil && snapshot.isLocalDraft ? L("storefront.local_draft.pending") : nil)
                : L("storefront.server_version.unverified")
        } catch is CancellationError {
        } catch let error as StorefrontAuthoringError {
            guard isActive else { return }
            message = message(for: error)
        } catch {
            guard isActive else { return }
            message = L("storefront.error.contract")
        }
        if isActive, self.scope == scope, !Task.isCancelled { loading = false }
    }

    private func mutate(_ operation: StorefrontMutationOperation) {
        guard validate(operation: operation),
              let scope,
              let productID = currentRemoteID else { return }
        operationTask?.cancel()
        mutating = true
        message = nil
        let candidate = draft
        let expectedVersion = draftExpectedVersion
        operationTask = Task {
            do {
                let updated = try await store.mutate(
                    scope: scope,
                    productID: productID,
                    operation: operation,
                    draft: candidate,
                    expectedVersion: expectedVersion,
                    baseDraft: baseDraft
                )
                guard isActive, self.scope == scope, !Task.isCancelled else { return }
                publication = updated
                draftExpectedVersion = updated.version
                draft = StorefrontEditorDraft(publication: updated)
                baseDraft = draft
                conflict = nil
                localDraft = false
                message = L("storefront.saved_ack")
            } catch is CancellationError {
            } catch StorefrontAuthoringError.offline where operation == .saveDraft {
                guard isActive, self.scope == scope else { return }
                adoptReconciledBaseIfNeeded(scope: scope, productID: productID)
                draft = candidate
                localDraft = true
                message = L("storefront.local_draft.pending")
            } catch StorefrontAuthoringError.conflict(let server) {
                guard isActive, self.scope == scope else { return }
                adoptReconciledBaseIfNeeded(scope: scope, productID: productID)
                conflict = server
                message = L("storefront.conflict")
            } catch let error as StorefrontAuthoringError {
                guard isActive, self.scope == scope else { return }
                adoptReconciledBaseIfNeeded(scope: scope, productID: productID)
                message = message(for: error)
            } catch {
                guard isActive, self.scope == scope else { return }
                message = L("storefront.error.contract")
            }
            if isActive, self.scope == scope, !Task.isCancelled { mutating = false }
        }
    }

    private func adoptReconciledBaseIfNeeded(scope: StorefrontScope, productID: UUID) {
        if let acknowledged = store.reconciledBase(scope: scope, productID: productID),
           acknowledged.version > draftExpectedVersion {
            baseDraft = StorefrontEditorDraft(publication: acknowledged)
            draftExpectedVersion = acknowledged.version
        }
    }

    private func validate(operation: StorefrontMutationOperation) -> Bool {
        switch storefrontDraftValidationCode(draft, operation: operation) {
        case nil:
            return true
        case "schedule":
            message = L("storefront.error.schedule")
        default:
            message = L("storefront.error.validation")
        }
        return false
    }

    private func alignWithOperationalProduct() {
        draft = storefrontAlignedDraft(
            draft,
            operationalName: operationalName,
            operationalRetailPrice: operationalRetailPrice,
            operationalCategoryRemoteID: operationalCategoryRemoteID,
            categories: categories
        )
        message = L("storefront.aligned")
    }

    private func adoptOperationalImage() {
        guard let imageScope,
              let productID = currentRemoteID,
              let sourceVersionID = currentProduct?.primaryImageVersionID,
              let publicationID = publication?.publicationId else { return }
        operationTask?.cancel()
        adoptingImage = true
        message = nil
        operationTask = Task {
            do {
                let imagePublicationID = try await productImageStore.adoptForStorefront(
                    scope: imageScope,
                    productID: productID,
                    publicationID: publicationID,
                    sourceImageVersionID: sourceVersionID
                )
                guard isActive, self.imageScope == imageScope, !Task.isCancelled else { return }
                await productImageStore.stageStorefrontPreviewCandidate(
                    scope: imageScope,
                    imagePublicationID: imagePublicationID,
                    sourceProductID: productID,
                    sourceImageVersionID: sourceVersionID
                )
                guard isActive, self.imageScope == imageScope, !Task.isCancelled else { return }
                draft.publicImageId = imagePublicationID
                message = L("storefront.image.ready_to_save")
            } catch is CancellationError {
            } catch {
                guard isActive else { return }
                message = L("storefront.image.error")
            }
            if isActive, self.imageScope == imageScope, !Task.isCancelled { adoptingImage = false }
        }
    }

    private func reloadFromConflict(_ server: StorefrontPublication) {
        if let scope, let productID = currentRemoteID {
            do { try store.clearLocalDraft(scope: scope, productID: productID) }
            catch { message = L("storefront.error.local_persistence"); return }
        }
        publication = server
        draftExpectedVersion = server.version
        draft = StorefrontEditorDraft(publication: server)
        baseDraft = draft
        conflict = nil
        localDraft = false
    }

    private func reapplyConflict(_ server: StorefrontPublication) {
        let dirty = storefrontChangedFields(base: baseDraft, draft: draft)
        let serverDraft = StorefrontEditorDraft(publication: server)
        draft = storefrontOverlay(server: serverDraft, local: draft, fields: dirty)
        baseDraft = serverDraft
        publication = server
        draftExpectedVersion = server.version
        conflict = nil
        mutate(.saveDraft)
    }

    private func startReconnectObservationIfNeeded() {
        guard reachabilityObserver == nil else { return }
        let scheduler = AutomaticSyncReconnectScheduler(debounce: 0.5) {
            guard isActive, localDraft, !mutating, let scope else { return }
            operationTask?.cancel()
            operationTask = Task { await load(scope: scope) }
        }
        scheduler.setForeground(true)
        let observer = AutomaticSyncNetworkReachabilityObserver(
            scheduler: scheduler,
            statusHandler: { status in
                if status == .unsatisfied, isActive {
                    message = L("storefront.server_version.unverified")
                }
            }
        )
        reachabilityObserver = observer
        observer.start()
    }

    private func int64Binding(
        _ keyPath: WritableKeyPath<StorefrontEditorDraft, Int64?>
    ) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath].map(String.init) ?? "" },
            set: { value in
                let normalized = value.filter(\.isNumber)
                draft[keyPath: keyPath] = normalized.isEmpty ? nil : Int64(normalized)
            }
        )
    }

    private func int64Binding(
        _ keyPath: WritableKeyPath<StorefrontEditorDraft, Int64>,
        optional: Bool
    ) -> Binding<String> {
        Binding(
            get: { String(draft[keyPath: keyPath]) },
            set: { value in draft[keyPath: keyPath] = Int64(value.filter(\.isNumber)) ?? 0 }
        )
    }

    private func optionalStringBinding(
        _ keyPath: WritableKeyPath<StorefrontEditorDraft, String?>
    ) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                draft[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private var categorySummary: String {
        guard let id = draft.storefrontCategoryId,
              let category = categories.first(where: { $0.categoryId == id }) else {
            return L("storefront.category.choose")
        }
        return category.publicName
    }

    private var publicPriceText: String {
        draft.publicPrice.map { formatStorefrontCLP($0) } ?? L("storefront.price.empty")
    }

    private var operationalPriceText: String {
        guard let value = operationalRetailPrice else { return "—" }
        return formatCLPMoney(value)
    }

    private func message(for error: StorefrontAuthoringError) -> String {
        switch error {
        case .localPersistence: L("storefront.error.local_persistence")
        case .permissionDenied: L("storefront.error.permission")
        case .offline: L("storefront.error.network_required")
        case .unauthenticated: L("storefront.error.unauthenticated")
        case .conflict: L("storefront.conflict")
        case .invalidInput: L("storefront.error.validation")
        case .invalidScope: L("storefront.error.scope_changed")
        case .unavailable: L("storefront.unavailable")
        case .server, .contractInvalid: L("storefront.error.contract")
        }
    }
}

private struct StorefrontPublicPreview: View {
    @Environment(\.dismiss) private var dismiss
    let draft: StorefrontEditorDraft
    let publication: StorefrontPublication?
    let scope: StorefrontScope?

    var body: some View {
        List {
            Section {
                if let scope,
                   let imagePublicationID = draft.publicImageId {
                    StorefrontPublicImageView(
                        scope: ProductImageScope(accountID: scope.accountID, shopID: scope.shopID),
                        imagePublicationID: imagePublicationID,
                        publicURL: publication?.publicImageId == imagePublicationID
                            ? safePublicImageURL(publication?.publicImageDetailUrl)
                            : nil,
                        variant: .detail,
                        contentMode: .fit
                    )
                    .frame(maxHeight: 260)
                }
                Text(draft.publicName)
                    .font(.title2.weight(.bold))
                if !draft.publicDescription.isEmpty {
                    Text(draft.publicDescription)
                }
                Text(draft.publicPrice.map(formatStorefrontCLP) ?? "—")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                if let compare = draft.compareAtPrice {
                    Text(formatStorefrontCLP(compare))
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Label(L("storefront.preview.public_only"), systemImage: "eye")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("storefront.preview.public-only")
            }
        }
        .navigationTitle(L("storefront.action.preview"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("common.ok")) { dismiss() }
            }
        }
    }
}

private struct StorefrontPublicImageView: View {
    @EnvironmentObject private var imageStore: ProductImageStore

    let scope: ProductImageScope
    let imagePublicationID: UUID
    let publicURL: URL?
    let variant: StorefrontPublicImageVariant
    let contentMode: ContentMode

    var body: some View {
        Group {
            if let image = imageStore.storefrontPublicImage(
                scope: scope,
                imagePublicationID: imagePublicationID,
                variant: variant
            ) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: taskID) {
            guard let publicURL else { return }
            await imageStore.loadStorefrontPublicImage(
                scope: scope,
                imagePublicationID: imagePublicationID,
                publicURL: publicURL,
                variant: variant
            )
        }
    }

    private var taskID: String {
        "\(scope.accountID).\(scope.shopID).\(imagePublicationID).\(variant.rawValue).\(publicURL?.absoluteString ?? "candidate")"
    }
}

func safePublicImageURL(_ value: String?) -> URL? {
    guard let value,
          let url = URL(string: value),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          components.scheme?.lowercased() == "https",
          components.host != nil,
          components.user == nil,
          components.password == nil,
          components.fragment == nil else { return nil }
    return url
}

func formatStorefrontCLP(_ value: Int64) -> String {
    let formatter = NumberFormatter()
    formatter.locale = appLocale()
    formatter.numberStyle = .currency
    formatter.currencyCode = "CLP"
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "CLP \(value)"
}

func statusLabel(_ status: StorefrontPublicationStatus) -> String {
    let key: String
    switch status {
    case .unpublished: key = "unpublished"
    case .draft: key = "draft"
    case .scheduled: key = "scheduled"
    case .published: key = "published"
    case .hidden: key = "hidden"
    case .archived: key = "archived"
    }
    return L("storefront.status.\(key)")
}

private func statusIcon(_ status: StorefrontPublicationStatus) -> String {
    switch status {
    case .unpublished: "storefront"
    case .draft: "square.and.pencil"
    case .scheduled: "calendar.badge.clock"
    case .published: "checkmark.circle.fill"
    case .hidden: "eye.slash"
    case .archived: "archivebox"
    }
}

private func statusColor(_ status: StorefrontPublicationStatus) -> Color {
    switch status {
    case .published: .green
    case .scheduled: .blue
    case .draft: .orange
    case .hidden, .archived, .unpublished: .secondary
    }
}

private func sourceLabel(_ source: String) -> String {
    switch source.lowercased() {
    case "android": "Android"
    case "ios": "iOS"
    case "admin": "Admin"
    default: L("storefront.source.system")
    }
}

private func formattedUpdatedAt(_ raw: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: raw) else { return raw }
    return date.formatted(date: .abbreviated, time: .shortened)
}
