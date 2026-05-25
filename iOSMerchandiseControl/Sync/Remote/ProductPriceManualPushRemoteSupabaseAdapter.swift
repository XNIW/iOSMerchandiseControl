import Foundation
import Supabase

struct ProductPriceManualPushRemoteSupabaseAdapter: SupabaseProductPriceManualPushRemoteAccessing {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    func insertProductPriceManualPushPayloads(_ payloads: [ProductPriceManualPushPayload]) async throws -> [RemoteInventoryProductPriceRow] {
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
        try await ProductPricePreviewRemoteSupabaseAdapter(remote: remote)
            .fetchProductPricesForPushDryRunDedupePage(ownerUserID: ownerUserID, productIDs: productIDs, from: from, to: to)
    }

    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        let ownerUserID = try await query.requireOwner()
        let client = await query.client()
        do {
            let row: RemoteInventoryProductRow = try await client
                .from("inventory_products")
                .update(payload)
                .eq("id", value: id.uuidString)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .select(CatalogRemoteSupabaseAdapter.productColumns)
                .single()
                .execute()
                .value
            guard row.id == id, row.ownerUserID == ownerUserID else {
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
