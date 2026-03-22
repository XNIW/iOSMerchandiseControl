import Foundation
import SwiftData

enum PriceHistoryBackfillService {
    static let backfillSource = "BACKFILL"
    static let backfillDate = Date(timeIntervalSince1970: 946_684_800)

    @discardableResult
    static func backfillIfNeeded(context: ModelContext) throws -> Int {
        let productDescriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.purchasePrice != nil || $0.retailPrice != nil }
        )
        let products = try context.fetch(productDescriptor)

        guard !products.isEmpty else { return 0 }

        let candidateBarcodes = Set(products.map(\.barcode))
        let existingPrices = try context.fetch(FetchDescriptor<ProductPrice>())

        var coveredTypes: [String: Set<PriceType>] = [:]
        for price in existingPrices {
            guard let barcode = price.product?.barcode,
                  candidateBarcodes.contains(barcode) else {
                continue
            }
            coveredTypes[barcode, default: []].insert(price.type)
        }

        var insertedCount = 0

        for product in products {
            let covered = coveredTypes[product.barcode] ?? []

            if let purchasePrice = product.purchasePrice,
               !covered.contains(.purchase) {
                context.insert(
                    ProductPrice(
                        type: .purchase,
                        price: purchasePrice,
                        effectiveAt: backfillDate,
                        source: backfillSource,
                        product: product
                    )
                )
                insertedCount += 1
            }

            if let retailPrice = product.retailPrice,
               !covered.contains(.retail) {
                context.insert(
                    ProductPrice(
                        type: .retail,
                        price: retailPrice,
                        effectiveAt: backfillDate,
                        source: backfillSource,
                        product: product
                    )
                )
                insertedCount += 1
            }
        }

        if insertedCount > 0 {
            try context.save()
        }

        return insertedCount
    }
}
