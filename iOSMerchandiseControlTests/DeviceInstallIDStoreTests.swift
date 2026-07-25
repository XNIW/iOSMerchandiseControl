import Foundation
import XCTest
@testable import iOSMerchandiseControl

final class DeviceInstallIDStoreTests: XCTestCase {
    func testConcurrentStoresConvergeOnOneDurableIdentity() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let legacyIdentity = UUID().uuidString.lowercased()
        fixture.defaults.set(legacyIdentity, forKey: "shop.device.install.id")
        let stores = (0..<64).map { _ in
            DeviceInstallIDStore(
                defaults: fixture.defaults,
                durableURL: fixture.durableURL
            )
        }

        let identities = try await withThrowingTaskGroup(of: String.self) { group in
            for store in stores {
                group.addTask {
                    try store.requireDeviceInstallID()
                }
            }
            var values: [String] = []
            for try await value in group { values.append(value) }
            return values
        }

        XCTAssertEqual(Set(identities), [legacyIdentity])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.durableURL.path))
        XCTAssertEqual(
            try DeviceInstallIDStore(
                defaults: fixture.defaults,
                durableURL: fixture.durableURL
            ).requireDeviceInstallID(),
            legacyIdentity
        )
    }

    func testLegacyPreferenceIdentityMigratesToDurableFileWithoutRotation() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let legacyIdentity = UUID().uuidString.lowercased()
        fixture.defaults.set(legacyIdentity, forKey: "shop.device.install.id")

        let identity = try DeviceInstallIDStore(
            defaults: fixture.defaults,
            durableURL: fixture.durableURL
        ).requireDeviceInstallID()

        XCTAssertEqual(identity, legacyIdentity)
        fixture.defaults.removeObject(forKey: "shop.device.install.id")
        XCTAssertEqual(
            try DeviceInstallIDStore(
                defaults: fixture.defaults,
                durableURL: fixture.durableURL
            ).requireDeviceInstallID(),
            legacyIdentity
        )
        XCTAssertEqual(
            fixture.defaults.string(forKey: "shop.device.install.id"),
            legacyIdentity
        )
    }

    func testCorruptDurableIdentityFailsClosedWithoutOverwritingIt() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let legacyIdentity = UUID().uuidString.lowercased()
        fixture.defaults.set(legacyIdentity, forKey: "shop.device.install.id")
        try FileManager.default.createDirectory(
            at: fixture.durableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let corrupt = Data("{\"schemaVersion\":\"invalid\"}".utf8)
        try corrupt.write(to: fixture.durableURL)

        XCTAssertThrowsError(
            try DeviceInstallIDStore(
                defaults: fixture.defaults,
                durableURL: fixture.durableURL
            ).requireDeviceInstallID()
        ) { error in
            XCTAssertEqual(error as? DeviceInstallIDStoreError, .invalidDurableIdentity)
        }
        XCTAssertEqual(try Data(contentsOf: fixture.durableURL), corrupt)
        XCTAssertEqual(
            fixture.defaults.string(forKey: "shop.device.install.id"),
            legacyIdentity
        )
    }

    func testDurableIdentityWinsPreferenceMismatchAndRepairsMirror() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let durableIdentity = UUID().uuidString.lowercased()
        fixture.defaults.set(durableIdentity, forKey: "shop.device.install.id")
        XCTAssertEqual(
            try DeviceInstallIDStore(
                defaults: fixture.defaults,
                durableURL: fixture.durableURL
            ).requireDeviceInstallID(),
            durableIdentity
        )

        fixture.defaults.set(UUID().uuidString.lowercased(), forKey: "shop.device.install.id")
        XCTAssertEqual(
            try DeviceInstallIDStore(
                defaults: fixture.defaults,
                durableURL: fixture.durableURL
            ).requireDeviceInstallID(),
            durableIdentity
        )
        XCTAssertEqual(
            fixture.defaults.string(forKey: "shop.device.install.id"),
            durableIdentity
        )
    }

    func testSymlinkDurableIdentityIsRejected() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let identity = UUID().uuidString.lowercased()
        fixture.defaults.set(identity, forKey: "shop.device.install.id")
        _ = try DeviceInstallIDStore(
            defaults: fixture.defaults,
            durableURL: fixture.durableURL
        ).requireDeviceInstallID()

        let targetURL = fixture.root.appendingPathComponent("redirected-install-id")
        try FileManager.default.moveItem(at: fixture.durableURL, to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: fixture.durableURL,
            withDestinationURL: targetURL
        )

        XCTAssertThrowsError(
            try DeviceInstallIDStore(
                defaults: fixture.defaults,
                durableURL: fixture.durableURL
            ).requireDeviceInstallID()
        ) { error in
            XCTAssertEqual(error as? DeviceInstallIDStoreError, .invalidDurableIdentity)
        }
    }

    private func makeFixture() throws -> DeviceInstallIDFixture {
        let suiteName = "DeviceInstallIDStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeviceInstallIDStore-\(UUID().uuidString)", isDirectory: true)
        return DeviceInstallIDFixture(
            defaults: defaults,
            suiteName: suiteName,
            root: root,
            durableURL: root.appendingPathComponent("identity/install-id")
        )
    }
}

private struct DeviceInstallIDFixture {
    let defaults: UserDefaults
    let suiteName: String
    let root: URL
    let durableURL: URL

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
}
