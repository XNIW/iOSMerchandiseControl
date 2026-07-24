import Foundation
import Supabase

actor SupabaseSyncEventRPCTransport: SyncEventRPCTransport {
    private let clientProvider: SupabaseClientProvider

    init(clientProvider: SupabaseClientProvider) {
        self.clientProvider = clientProvider
    }

    func call(
        functionName: String,
        params: SyncEventRPCRequestParameters
    ) async throws -> Data {
        do {
            if functionName == SyncEventRPCRequestMapper.legacyFunctionName {
                guard let legacy = SyncEventRPCRequestMapper.legacyParametersIfCompatible(
                    params,
                    hasAutomaticShopScope: false
                ) else {
                    throw SyncEventRPCTransportError.postgrest(
                        code: "legacy_incompatible",
                        message: "Legacy sync-event writer is not compatible with this request."
                    )
                }
                let response = try await clientProvider.client
                    .rpc(functionName, params: legacy)
                    .execute()
                return response.data
            } else {
                let response = try await clientProvider.client
                    .rpc(functionName, params: params)
                    .execute()
                return response.data
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as PostgrestError {
            throw SyncEventRPCTransportError.postgrest(
                code: error.code,
                message: [error.message, error.detail, error.hint]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
        } catch let error as URLError {
            if error.code == .cancelled {
                throw CancellationError()
            }
            throw SyncEventRPCTransportError.network(
                code: "url_error_\(error.code.rawValue)",
                message: error.localizedDescription
            )
        } catch {
            throw SyncEventRPCTransportError.unknown(
                code: "transport_unknown",
                message: String(describing: error)
            )
        }
    }
}
