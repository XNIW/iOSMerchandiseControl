import Foundation
import Supabase

struct ProductPriceManualPushRemoteSupabaseAdapter: SupabaseProductPriceManualPushRemoteAccessing {
    let remote: SupabaseTransportClient
    private let manualScope: @Sendable () throws -> Task126VerifiedOwnerStoreScope

    nonisolated init(remote: SupabaseTransportClient,
        manualScope: @escaping @Sendable () throws -> Task126VerifiedOwnerStoreScope = {
            try Task126OwnerStoreGate.requireCurrentAutomaticScope()
        }) {
        self.remote = remote
        self.manualScope = manualScope
    }

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    func insertProductPriceManualPushPayloads(_ payloads: [ProductPriceManualPushPayload]) async throws -> [RemoteInventoryProductPriceRow] {
        if let callback = ManualPendingAtomicDispatchContext.beforeDispatch {
            return try await guardedInsert(payloads, callback: callback)
        }
        let authenticatedUserID = try await query.requireOwner()
        guard !payloads.isEmpty else { return [] }
        guard payloads.allSatisfy({ $0.ownerUserID == authenticatedUserID }) else {
            throw ProductPriceManualPushError.invalidPayload
        }
        let client = await query.client()
        do {
            return try await client
                .from("inventory_product_prices")
                .insert(payloads)
                .select(ProductPriceRemoteSupabaseAdapter.productPriceColumns)
                .execute()
                .value
        } catch let error as PostgrestError {
            throw await mapProductPriceManualPushPostgrestError(error)
        } catch let error as DecodingError {
            throw await remote.mapDecodingError(error)
        } catch let error as URLError {
            throw await remote.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    func fetchProductPricesForManualPushVerificationPage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        if let callback = ManualPendingAtomicDispatchContext.beforeDispatch {
            return try await guardedVerification(ownerUserID: ownerUserID, productIDs: productIDs,
                from: from, to: to, callback: callback)
        }
        return try await ProductPricePreviewRemoteSupabaseAdapter(remote: remote)
            .fetchProductPricesForPushDryRunDedupePage(ownerUserID: ownerUserID, productIDs: productIDs, from: from, to: to)
    }

    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        if let callback = ManualPendingAtomicDispatchContext.beforeDispatch {
            return try await guardedProductUpdate(id: id, payload: payload, callback: callback)
        }
        let ownerUserID = try await query.requireOwner()
        let client = await query.client()
        do {
            let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
            var request = try client
                .from("inventory_products")
                .update(payload)
                .eq("id", value: id.uuidString)
                .eq("owner_user_id", value: ownerUserID.uuidString)
            if let selectedShopID {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
            }
            let row: RemoteInventoryProductRow = try await request
                .select(CatalogRemoteSupabaseAdapter.productColumns)
                .single()
                .execute()
                .value
            guard row.id == id, row.ownerUserID == ownerUserID, row.shopID == selectedShopID else {
                throw SupabaseTransportClientError.schemaDrift(message: "Product update read-back mismatch.")
            }
            return row
        } catch let error as SupabaseTransportClientError {
            throw error
        } catch let error as DecodingError {
            throw await remote.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await remote.mapPostgrestError(error)
        } catch let error as URLError {
            throw await remote.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    private struct ManualAdmission {
        let provider: SupabaseClientProvider
        let snapshot: SupabaseAuthClientSnapshot
        let scope: Task126VerifiedOwnerStoreScope
        let client: PostgrestClient
    }

    private func manualAdmission(
        callback: @escaping @MainActor @Sendable (URLRequest) throws -> Void
    ) async throws -> ManualAdmission {
        let scope = try manualScope()
        let provider = await remote.manualRequestProvider()
        let snapshot = provider.authSnapshot
        let readScope = manualScope
        var configuration = snapshot.client.schema("public").configuration
        configuration.retryEnabled = false
        configuration.fetch = { request in
            try await provider.performManualRequest(request, snapshot: snapshot, scope: scope,
                validateScope: {
                    guard try readScope() == scope else { throw Task126OwnerStoreGateError.scopeChanged }
                }, beforeDispatch: callback)
        }
        return ManualAdmission(provider: provider, snapshot: snapshot, scope: scope,
            client: PostgrestClient(configuration: configuration))
    }

    private func validate(_ admission: ManualAdmission) async throws {
        guard admission.provider.acceptsAuthGeneration(admission.snapshot.generation),
              try manualScope() == admission.scope else { throw LocalPendingManualDispatchError.staleBatch }
    }

    private func guardedInsert(_ payloads: [ProductPriceManualPushPayload],
        callback: @escaping @MainActor @Sendable (URLRequest) throws -> Void
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let admission = try await manualAdmission(callback: callback)
        guard !payloads.isEmpty, Set(payloads.map(\.id)).count == payloads.count,
              payloads.allSatisfy({ $0.ownerUserID == admission.scope.ownerUserID && $0.shopID == admission.scope.shopID }) else {
            throw ProductPriceManualPushError.invalidPayload
        }
        do {
            let rows: [RemoteInventoryProductPriceRow] = try await admission.client
                .from("inventory_product_prices").insert(payloads)
                .select(ProductPriceRemoteSupabaseAdapter.productPriceColumns).execute().value
            try await validate(admission)
            guard rows.count == payloads.count, Set(rows.map(\.id)) == Set(payloads.map(\.id)),
                  rows.allSatisfy({ $0.ownerUserID == admission.scope.ownerUserID && $0.shopID == admission.scope.shopID }) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            // The manual service still owns full verification and durable ACK.
            return rows
        } catch let error as PostgrestError { throw await mapProductPriceManualPushPostgrestError(error) }
        catch let error as DecodingError { throw await remote.mapDecodingError(error) }
        catch let error as URLError { throw await remote.networkError(error) }
        catch { throw error }
    }

    private func guardedVerification(ownerUserID: UUID, productIDs: [UUID], from: Int, to: Int,
        callback: @escaping @MainActor @Sendable (URLRequest) throws -> Void
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let admission = try await manualAdmission(callback: callback)
        guard ownerUserID == admission.scope.ownerUserID else { throw LocalPendingManualDispatchError.staleBatch }
        guard !productIDs.isEmpty else { return [] }
        let ids = Set(productIDs)
        let start = max(0, from), end = max(max(0, from), min(to, max(0, from) + 999))
        do {
            let rows: [RemoteInventoryProductPriceRow] = try await admission.client
                .from("inventory_product_prices").select(ProductPriceRemoteSupabaseAdapter.productPriceColumns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .eq("shop_id", value: admission.scope.shopID.uuidString)
                .in("product_id", values: ids.sorted { $0.uuidString < $1.uuidString }.map(\.uuidString))
                .order("product_id", ascending: true).order("type", ascending: true)
                .order("effective_at", ascending: true).order("id", ascending: true)
                .range(from: start, to: end).execute().value
            try await validate(admission)
            guard rows.allSatisfy({ $0.ownerUserID == ownerUserID && $0.shopID == admission.scope.shopID && ids.contains($0.productID) }) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            return rows
        } catch let error as PostgrestError { throw await remote.mapPostgrestError(error) }
        catch let error as DecodingError { throw await remote.mapDecodingError(error) }
        catch let error as URLError { throw await remote.networkError(error) }
        catch { throw error }
    }

    private func guardedProductUpdate(id: UUID, payload: SupabaseManualPushProductUpdatePayload,
        callback: @escaping @MainActor @Sendable (URLRequest) throws -> Void
    ) async throws -> RemoteInventoryProductRow {
        let admission = try await manualAdmission(callback: callback)
        do {
            let row: RemoteInventoryProductRow = try await admission.client.from("inventory_products")
                .update(payload).eq("id", value: id.uuidString)
                .eq("owner_user_id", value: admission.scope.ownerUserID.uuidString)
                .eq("shop_id", value: admission.scope.shopID.uuidString)
                .select(CatalogRemoteSupabaseAdapter.productColumns).single().execute().value
            try await validate(admission)
            guard row.id == id, row.ownerUserID == admission.scope.ownerUserID, row.shopID == admission.scope.shopID else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            return row
        } catch let error as PostgrestError { throw await remote.mapPostgrestError(error) }
        catch let error as DecodingError { throw await remote.mapDecodingError(error) }
        catch let error as URLError { throw await remote.networkError(error) }
        catch { throw error }
    }

    private func mapProductPriceManualPushPostgrestError(_ error: PostgrestError) async -> Error {
        let code = error.code
        let message = error.message
        let normalized = [code, message, error.detail, error.hint]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if code == "23505"
            || normalized.contains("duplicate key")
            || normalized.contains("unique constraint") {
            return ProductPriceManualPushError.uniqueConflict(
                message: SupabaseTransportClientError.sanitizedDiagnosticDetail(message)
            )
        }

        if normalized.contains("permission denied")
            || normalized.contains("row-level security")
            || normalized.contains("rls")
            || normalized.contains("unauthorized")
            || normalized.contains("authenticated")
            || code == "42501" {
            return SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: code, message: message)
        }

        if code == "42P01" || code == "42703" || code == "PGRST204" {
            return SupabaseTransportClientError.schemaDrift(message: message)
        }

        return await remote.mapPostgrestError(error)
    }
}
