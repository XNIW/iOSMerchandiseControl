import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class RemoteIdentityMetadataSwiftDataTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testProductRemoteMetadataDefaultsToNil() {
        let product = Product(barcode: "legacy-product")

        XCTAssertNil(product.remoteID)
        XCTAssertNil(product.remoteUpdatedAt)
        XCTAssertNil(product.remoteDeletedAt)
    }

    func testProductRemoteMetadataAcceptsValues() {
        let remoteID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_777_000_001)
        let deletedAt = Date(timeIntervalSince1970: 1_777_000_002)

        let product = Product(
            barcode: "remote-product",
            remoteID: remoteID,
            remoteUpdatedAt: updatedAt,
            remoteDeletedAt: deletedAt
        )

        XCTAssertEqual(product.remoteID, remoteID)
        XCTAssertEqual(product.remoteUpdatedAt, updatedAt)
        XCTAssertEqual(product.remoteDeletedAt, deletedAt)
    }

    func testProductRemoteMetadataPersistsInMemory() throws {
        let container = try makeContainer()
        let insertContext = makeContext(for: container)
        let remoteID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_777_100_001)
        let deletedAt = Date(timeIntervalSince1970: 1_777_100_002)

        insertContext.insert(Product(
            barcode: "persisted-product",
            remoteID: remoteID,
            remoteUpdatedAt: updatedAt,
            remoteDeletedAt: deletedAt
        ))
        try insertContext.save()

        let fetchContext = makeContext(for: container)
        let products = try fetchContext.fetch(FetchDescriptor<Product>())
        let persisted = try XCTUnwrap(products.first { $0.barcode == "persisted-product" })

        XCTAssertEqual(persisted.remoteID, remoteID)
        XCTAssertEqual(persisted.remoteUpdatedAt, updatedAt)
        XCTAssertEqual(persisted.remoteDeletedAt, deletedAt)
    }

    func testSupplierRemoteMetadataDefaultsAndPersistsInMemory() throws {
        let legacySupplier = Supplier(name: "Legacy Supplier")
        XCTAssertNil(legacySupplier.remoteID)
        XCTAssertNil(legacySupplier.remoteUpdatedAt)
        XCTAssertNil(legacySupplier.remoteDeletedAt)

        let container = try makeContainer()
        let insertContext = makeContext(for: container)
        let remoteID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_777_200_001)
        let deletedAt = Date(timeIntervalSince1970: 1_777_200_002)

        insertContext.insert(Supplier(
            name: "Persisted Supplier",
            remoteID: remoteID,
            remoteUpdatedAt: updatedAt,
            remoteDeletedAt: deletedAt
        ))
        try insertContext.save()

        let fetchContext = makeContext(for: container)
        let suppliers = try fetchContext.fetch(FetchDescriptor<Supplier>())
        let persisted = try XCTUnwrap(suppliers.first { $0.name == "Persisted Supplier" })

        XCTAssertEqual(persisted.remoteID, remoteID)
        XCTAssertEqual(persisted.remoteUpdatedAt, updatedAt)
        XCTAssertEqual(persisted.remoteDeletedAt, deletedAt)
    }

    func testProductCategoryRemoteMetadataDefaultsAndPersistsInMemory() throws {
        let legacyCategory = ProductCategory(name: "Legacy Category")
        XCTAssertNil(legacyCategory.remoteID)
        XCTAssertNil(legacyCategory.remoteUpdatedAt)
        XCTAssertNil(legacyCategory.remoteDeletedAt)

        let container = try makeContainer()
        let insertContext = makeContext(for: container)
        let remoteID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_777_300_001)
        let deletedAt = Date(timeIntervalSince1970: 1_777_300_002)

        insertContext.insert(ProductCategory(
            name: "Persisted Category",
            remoteID: remoteID,
            remoteUpdatedAt: updatedAt,
            remoteDeletedAt: deletedAt
        ))
        try insertContext.save()

        let fetchContext = makeContext(for: container)
        let categories = try fetchContext.fetch(FetchDescriptor<ProductCategory>())
        let persisted = try XCTUnwrap(categories.first { $0.name == "Persisted Category" })

        XCTAssertEqual(persisted.remoteID, remoteID)
        XCTAssertEqual(persisted.remoteUpdatedAt, updatedAt)
        XCTAssertEqual(persisted.remoteDeletedAt, deletedAt)
    }

    func testDuplicateRemoteIDIsNotAnImplicitSwiftDataUniqueConstraint() throws {
        let container = try makeContainer()
        let context = makeContext(for: container)
        let remoteID = UUID()

        context.insert(Product(barcode: "duplicate-remote-product-a", remoteID: remoteID))
        context.insert(Product(barcode: "duplicate-remote-product-b", remoteID: remoteID))
        context.insert(Supplier(name: "Duplicate Remote Supplier A", remoteID: remoteID))
        context.insert(Supplier(name: "Duplicate Remote Supplier B", remoteID: remoteID))
        context.insert(ProductCategory(name: "Duplicate Remote Category A", remoteID: remoteID))
        context.insert(ProductCategory(name: "Duplicate Remote Category B", remoteID: remoteID))

        XCTAssertNoThrow(try context.save())

        let fetchContext = makeContext(for: container)
        let products = try fetchContext.fetch(FetchDescriptor<Product>())
        let suppliers = try fetchContext.fetch(FetchDescriptor<Supplier>())
        let categories = try fetchContext.fetch(FetchDescriptor<ProductCategory>())

        XCTAssertEqual(products.filter { $0.remoteID == remoteID }.count, 2)
        XCTAssertEqual(suppliers.filter { $0.remoteID == remoteID }.count, 2)
        XCTAssertEqual(categories.filter { $0.remoteID == remoteID }.count, 2)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return container
    }

    private func makeContext(for container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }
}
