import Foundation
import SwiftData

@MainActor
struct SwiftDataInventorySnapshotService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func makeSnapshot() throws -> LocalInventorySnapshot {
        let products = try context.fetch(
            FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\Product.barcode)]
            )
        )
        let suppliers = try context.fetch(
            FetchDescriptor<Supplier>(
                sortBy: [SortDescriptor(\Supplier.name)]
            )
        )
        let categories = try context.fetch(
            FetchDescriptor<ProductCategory>(
                sortBy: [SortDescriptor(\ProductCategory.name)]
            )
        )
        let prices = try context.fetch(
            FetchDescriptor<ProductPrice>(
                sortBy: [SortDescriptor(\ProductPrice.effectiveAt)]
            )
        )

        var productsByBarcode: [String: LocalProductSnapshot] = [:]
        var productsByRemoteID: [UUID: LocalProductSnapshot] = [:]
        var productBarcodeCounts: [String: Int] = [:]
        var productRemoteIDCounts: [UUID: Int] = [:]
        var invalidProductBarcodes = 0

        for product in products {
            if let remoteID = product.remoteID {
                productRemoteIDCounts[remoteID, default: 0] += 1
            }

            guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode) else {
                invalidProductBarcodes += 1
                continue
            }

            productBarcodeCounts[barcode, default: 0] += 1
            if productsByBarcode[barcode] == nil {
                let snapshot = LocalProductSnapshot(
                    barcode: product.barcode,
                    remoteID: product.remoteID,
                    remoteUpdatedAt: product.remoteUpdatedAt,
                    remoteDeletedAt: product.remoteDeletedAt,
                    itemNumber: product.itemNumber,
                    productName: product.productName,
                    secondProductName: product.secondProductName,
                    purchasePrice: product.purchasePrice,
                    retailPrice: product.retailPrice,
                    stockQuantity: product.stockQuantity,
                    supplierName: product.supplier?.name,
                    categoryName: product.category?.name
                )
                productsByBarcode[barcode] = snapshot
                if let remoteID = product.remoteID, productsByRemoteID[remoteID] == nil {
                    productsByRemoteID[remoteID] = snapshot
                }
            }
        }

        let supplierNames = makeNameDictionary(suppliers.map(\.name))
        let categoryNames = makeNameDictionary(categories.map(\.name))
        let suppliersByRemoteID = makeLookupRemoteIDDictionary(suppliers)
        let categoriesByRemoteID = makeLookupRemoteIDDictionary(categories)
        let supplierRemoteIDByName = makeLookupRemoteIDByNormalizedName(suppliers)
        let categoryRemoteIDByName = makeLookupRemoteIDByNormalizedName(categories)

        var priceHistoryByLogicalKey: [PriceHistoryLogicalKey: LocalPriceSnapshot] = [:]
        for price in prices {
            guard let product = price.product,
                  let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode) else {
                continue
            }

            let type = price.type.rawValue
            let effectiveAt = Self.canonicalDateString(price.effectiveAt)
            let key = PriceHistoryLogicalKey(
                barcode: barcode,
                type: type,
                effectiveAt: effectiveAt
            )

            if priceHistoryByLogicalKey[key] == nil {
                priceHistoryByLogicalKey[key] = LocalPriceSnapshot(
                    barcode: product.barcode,
                    type: type,
                    price: price.price,
                    effectiveAt: effectiveAt,
                    source: price.source,
                    note: price.note,
                    createdAt: Self.canonicalDateString(price.createdAt)
                )
            }
        }

        return LocalInventorySnapshot(
            productsByBarcode: productsByBarcode,
            productsByRemoteID: productsByRemoteID,
            suppliersByNormalizedName: supplierNames.values,
            supplierRemoteIDByNormalizedName: supplierRemoteIDByName,
            suppliersByRemoteID: suppliersByRemoteID,
            categoriesByNormalizedName: categoryNames.values,
            categoryRemoteIDByNormalizedName: categoryRemoteIDByName,
            categoriesByRemoteID: categoriesByRemoteID,
            priceHistoryByLogicalKey: priceHistoryByLogicalKey,
            counts: LocalInventorySnapshotCounts(
                products: products.count,
                suppliers: suppliers.count,
                categories: categories.count,
                productPrices: prices.count,
                linkedProducts: products.filter { $0.remoteID != nil }.count,
                linkedSuppliers: suppliers.filter { $0.remoteID != nil }.count,
                linkedCategories: categories.filter { $0.remoteID != nil }.count
            ),
            duplicateProductBarcodes: productBarcodeCounts
                .filter { $0.value > 1 }
                .map(\.key)
                .sorted(),
            duplicateProductRemoteIDs: duplicateRemoteIDs(productRemoteIDCounts),
            duplicateSupplierNames: supplierNames.duplicates,
            duplicateSupplierRemoteIDs: duplicateRemoteIDs(suppliers.compactMap(\.remoteID)),
            duplicateCategoryNames: categoryNames.duplicates,
            duplicateCategoryRemoteIDs: duplicateRemoteIDs(categories.compactMap(\.remoteID)),
            invalidProductBarcodes: invalidProductBarcodes,
            invalidSupplierNames: supplierNames.invalidCount,
            invalidCategoryNames: categoryNames.invalidCount
        )
    }

    func makeManualPushPreflightProductStates() throws -> [ManualPushProductState] {
        let products = try context.fetch(
            FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\Product.barcode)]
            )
        )

        return products.map { product in
            ManualPushProductState(
                localID: product.barcode,
                remoteID: product.remoteID,
                remoteUpdatedAt: product.remoteUpdatedAt,
                remoteDeletedAt: product.remoteDeletedAt,
                barcode: product.barcode,
                itemNumber: product.itemNumber,
                productName: product.productName,
                secondProductName: product.secondProductName,
                purchasePrice: product.purchasePrice,
                retailPrice: product.retailPrice,
                stockQuantity: product.stockQuantity,
                hasSupplierReference: product.supplier != nil,
                supplierLocalID: product.supplier?.name,
                supplierName: product.supplier?.name,
                supplierRemoteID: product.supplier?.remoteID,
                hasCategoryReference: product.category != nil,
                categoryLocalID: product.category?.name,
                categoryName: product.category?.name,
                categoryRemoteID: product.category?.remoteID,
                hasLocalPriceChanges: false
            )
        }
    }

    func makeManualPushPreflightSupplierStates() throws -> [ManualPushLookupState] {
        let suppliers = try context.fetch(
            FetchDescriptor<Supplier>(
                sortBy: [SortDescriptor(\Supplier.name)]
            )
        )

        return suppliers.map { supplier in
            ManualPushLookupState(
                entityKind: .supplier,
                localID: supplier.name,
                remoteID: supplier.remoteID,
                remoteUpdatedAt: supplier.remoteUpdatedAt,
                remoteDeletedAt: supplier.remoteDeletedAt,
                name: supplier.name
            )
        }
    }

    func makeManualPushPreflightCategoryStates() throws -> [ManualPushLookupState] {
        let categories = try context.fetch(
            FetchDescriptor<ProductCategory>(
                sortBy: [SortDescriptor(\ProductCategory.name)]
            )
        )

        return categories.map { category in
            ManualPushLookupState(
                entityKind: .productCategory,
                localID: category.name,
                remoteID: category.remoteID,
                remoteUpdatedAt: category.remoteUpdatedAt,
                remoteDeletedAt: category.remoteDeletedAt,
                name: category.name
            )
        }
    }

    private func makeNameDictionary(_ names: [String]) -> (values: [String: String], duplicates: [String], invalidCount: Int) {
        var values: [String: String] = [:]
        var counts: [String: Int] = [:]
        var invalidCount = 0

        for name in names {
            guard let key = SupabasePullPreviewNormalizer.normalizedLookupName(name) else {
                invalidCount += 1
                continue
            }

            counts[key, default: 0] += 1
            if values[key] == nil {
                values[key] = name
            }
        }

        return (
            values: values,
            duplicates: counts
                .filter { $0.value > 1 }
                .map(\.key)
                .sorted(),
            invalidCount: invalidCount
        )
    }

    private func makeLookupRemoteIDDictionary(_ suppliers: [Supplier]) -> [UUID: LocalLookupSnapshot] {
        var result: [UUID: LocalLookupSnapshot] = [:]
        for supplier in suppliers {
            guard let remoteID = supplier.remoteID, result[remoteID] == nil else {
                continue
            }
            result[remoteID] = LocalLookupSnapshot(
                name: supplier.name,
                remoteID: remoteID,
                remoteUpdatedAt: supplier.remoteUpdatedAt,
                remoteDeletedAt: supplier.remoteDeletedAt
            )
        }
        return result
    }

    private func makeLookupRemoteIDDictionary(_ categories: [ProductCategory]) -> [UUID: LocalLookupSnapshot] {
        var result: [UUID: LocalLookupSnapshot] = [:]
        for category in categories {
            guard let remoteID = category.remoteID, result[remoteID] == nil else {
                continue
            }
            result[remoteID] = LocalLookupSnapshot(
                name: category.name,
                remoteID: remoteID,
                remoteUpdatedAt: category.remoteUpdatedAt,
                remoteDeletedAt: category.remoteDeletedAt
            )
        }
        return result
    }

    private func makeLookupRemoteIDByNormalizedName(_ suppliers: [Supplier]) -> [String: UUID] {
        var result: [String: UUID] = [:]
        for supplier in suppliers {
            guard let remoteID = supplier.remoteID,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name),
                  result[normalizedName] == nil else {
                continue
            }
            result[normalizedName] = remoteID
        }
        return result
    }

    private func makeLookupRemoteIDByNormalizedName(_ categories: [ProductCategory]) -> [String: UUID] {
        var result: [String: UUID] = [:]
        for category in categories {
            guard let remoteID = category.remoteID,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(category.name),
                  result[normalizedName] == nil else {
                continue
            }
            result[normalizedName] = remoteID
        }
        return result
    }

    private func duplicateRemoteIDs(_ remoteIDs: [UUID]) -> [UUID] {
        var counts: [UUID: Int] = [:]
        for remoteID in remoteIDs {
            counts[remoteID, default: 0] += 1
        }
        return duplicateRemoteIDs(counts)
    }

    private func duplicateRemoteIDs(_ counts: [UUID: Int]) -> [UUID] {
        counts
            .filter { $0.value > 1 }
            .map(\.key)
            .sorted { $0.uuidString < $1.uuidString }
    }

    private static func canonicalDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
