import Foundation

enum PendingChangeCoalescer {
    struct State: Equatable, Sendable {
        var operation: LocalPendingChangeOperation
        var status: LocalPendingChangeStatus
        var changedFields: [String]
        var entityRemoteID: UUID?

        init(
            operation: LocalPendingChangeOperation,
            status: LocalPendingChangeStatus = .pending,
            changedFields: [String],
            entityRemoteID: UUID?
        ) {
            self.operation = operation
            self.status = status
            self.changedFields = LocalPendingChange.decodeChangedFields(
                LocalPendingChange.encodeChangedFields(changedFields)
            )
            self.entityRemoteID = entityRemoteID
        }
    }

    static func coalesce(
        current: State,
        incoming: LocalPendingChangeOperation,
        changedFields: [String],
        incomingEntityRemoteID: UUID?
    ) -> State {
        var result = current
        let mergedFields = mergeFields(current.changedFields, changedFields)

        if current.operation == .create, incoming == .delete, current.entityRemoteID == nil {
            result.status = .superseded
        } else if incoming == .delete {
            result.operation = .delete
            result.changedFields = ["tombstone"]
        } else if current.operation == .create, incoming == .update {
            result.operation = .create
            result.changedFields = mergedFields
        } else if incoming == .upsert || current.operation == .upsert {
            result.operation = .upsert
            result.changedFields = mergedFields
        } else {
            result.operation = incoming
            result.changedFields = mergedFields
        }

        result.entityRemoteID = incomingEntityRemoteID ?? current.entityRemoteID
        return result
    }

    private static func mergeFields(_ lhs: [String], _ rhs: [String]) -> [String] {
        LocalPendingChange.decodeChangedFields(
            LocalPendingChange.encodeChangedFields(lhs + rhs)
        )
    }
}
