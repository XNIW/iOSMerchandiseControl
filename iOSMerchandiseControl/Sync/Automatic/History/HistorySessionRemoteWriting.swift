import Foundation

protocol HistorySessionRemoteWriting: HistorySessionRemoteSyncing {}

extension SupabaseInventoryService: HistorySessionRemoteWriting {}
