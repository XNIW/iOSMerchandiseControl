import XCTest
@testable import iOSMerchandiseControl

final class PendingChangeCoalescerTests: XCTestCase {
    func testCreateThenUpdateRemainsCreateAndMergesFields() {
        let result = PendingChangeCoalescer.coalesce(
            current: PendingChangeCoalescer.State(operation: .create, changedFields: ["name"], entityRemoteID: nil),
            incoming: .update,
            changedFields: ["price"],
            incomingEntityRemoteID: nil
        )

        XCTAssertEqual(result.operation, .create)
        XCTAssertEqual(result.status, .pending)
        XCTAssertEqual(result.changedFields, ["name", "price"])
    }

    func testLocalCreateThenDeleteWithoutRemoteIDIsSuperseded() {
        let result = PendingChangeCoalescer.coalesce(
            current: PendingChangeCoalescer.State(operation: .create, changedFields: ["name"], entityRemoteID: nil),
            incoming: .delete,
            changedFields: ["tombstone"],
            incomingEntityRemoteID: nil
        )

        XCTAssertEqual(result.status, .superseded)
    }

    func testRemoteBackedUpdateThenDeleteBecomesTombstoneDelete() {
        let remoteID = UUID()
        let result = PendingChangeCoalescer.coalesce(
            current: PendingChangeCoalescer.State(operation: .update, changedFields: ["name"], entityRemoteID: remoteID),
            incoming: .delete,
            changedFields: [],
            incomingEntityRemoteID: remoteID
        )

        XCTAssertEqual(result.operation, .delete)
        XCTAssertEqual(result.status, .pending)
        XCTAssertEqual(result.changedFields, ["tombstone"])
        XCTAssertEqual(result.entityRemoteID, remoteID)
    }
}
