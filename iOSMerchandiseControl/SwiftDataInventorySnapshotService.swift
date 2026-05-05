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
        var productBarcodeCounts: [String: Int] = [:]

        for product in products {
            guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode) else {
                continue
            }

            productBarcodeCounts[barcode, default: 0] += 1
            if productsByBarcode[barcode] == nil {
                productsByBarcode[barcode] = LocalProductSnapshot(
                    barcode: product.barcode,
                    itemNumber: product.itemNumber,
                    productName: product.productName,
                    secondProductName: product.secondProductName,
                    purchasePrice: product.purchasePrice,
                    retailPrice: product.retailPrice,
                    stockQuantity: product.stockQuantity,
                    supplierName: product.supplier?.name,
                    categoryName: product.category?.name
                )
            }
        }

        let supplierNames = makeNameDictionary(suppliers.map(\.name))
        let categoryNames = makeNameDictionary(categories.map(\.name))

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
            suppliersByNormalizedName: supplierNames.values,
            categoriesByNormalizedName: categoryNames.values,
            priceHistoryByLogicalKey: priceHistoryByLogicalKey,
            counts: LocalInventorySnapshotCounts(
                products: products.count,
                suppliers: suppliers.count,
                categories: categories.count,
                productPrices: prices.count
            ),
            duplicateProductBarcodes: productBarcodeCounts
                .filter { $0.value > 1 }
                .map(\.key)
                .sorted(),
            duplicateSupplierNames: supplierNames.duplicates,
            duplicateCategoryNames: categoryNames.duplicates
        )
    }

    private func makeNameDictionary(_ names: [String]) -> (values: [String: String], duplicates: [String]) {
        var values: [String: String] = [:]
        var counts: [String: Int] = [:]

        for name in names {
            guard let key = SupabasePullPreviewNormalizer.normalizedLookupName(name) else {
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
                .sorted()
        )
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
