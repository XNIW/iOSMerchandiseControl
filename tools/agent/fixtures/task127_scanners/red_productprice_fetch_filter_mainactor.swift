import SwiftData

@MainActor
func countPrices(context: ModelContext) throws -> Int {
    try context.fetch(FetchDescriptor<ProductPrice>())
        .filter { price in price.product?.remoteDeletedAt == nil }
        .count
}
