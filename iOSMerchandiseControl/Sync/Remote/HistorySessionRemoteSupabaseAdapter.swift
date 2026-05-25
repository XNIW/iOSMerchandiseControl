import Foundation
import Supabase

struct HistorySessionRemoteSupabaseAdapter: HistorySessionRemoteWriting {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        guard !rows.isEmpty else { return [] }
        let authenticatedUserID = try await query.requireOwner()
        guard authenticatedUserID == ownerUserID,
              rows.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "History/session owner mismatch"
            )
        }

        let client = await query.client()
        do {
            let readBack: [RemoteSharedSheetSessionRow] = try await client
                .from("shared_sheet_sessions")
                .upsert(rows, onConflict: "remote_id")
                .select(SupabaseTransportClient.sharedSheetSessionColumns)
                .execute()
                .value
            guard readBack.count == rows.count,
                  readBack.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
                throw SupabaseTransportClientError.schemaDrift(message: "History/session read-back mismatch.")
            }
            return readBack
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

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from start: Int,
        to end: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        let authenticatedUserID = try await query.requireOwner()
        guard authenticatedUserID == ownerUserID else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "History/session owner mismatch"
            )
        }
        let client = await query.client()
        do {
            return try await client
                .from("shared_sheet_sessions")
                .select(SupabaseTransportClient.sharedSheetSessionColumns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .order("remote_id", ascending: true)
                .range(from: max(0, start), to: max(start, end))
                .execute()
                .value
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

    func fetchSharedSheetSessionsByIDs(
        ownerUserID: UUID,
        sessionIDs: Set<UUID>
    ) async throws -> [RemoteSharedSheetSessionRow] {
        guard !sessionIDs.isEmpty else { return [] }
        let authenticatedUserID = try await query.requireOwner()
        guard authenticatedUserID == ownerUserID else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "History/session owner mismatch"
            )
        }

        let sortedIDs = sessionIDs.map { $0.uuidString.lowercased() }.sorted()
        let client = await query.client()
        do {
            let rows: [RemoteSharedSheetSessionRow] = try await client
                .from("shared_sheet_sessions")
                .select(SupabaseTransportClient.sharedSheetSessionColumns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("remote_id", values: sortedIDs)
                .order("remote_id", ascending: true)
                .execute()
                .value
            if !rows.isEmpty { return rows }
            return try await client
                .from("shared_sheet_sessions")
                .select(SupabaseTransportClient.sharedSheetSessionColumns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .or(sortedIDs.map { "remote_id.eq.\($0)" }.joined(separator: ","))
                .order("remote_id", ascending: true)
                .execute()
                .value
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
}
