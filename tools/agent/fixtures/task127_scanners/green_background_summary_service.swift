import SwiftData

struct OptionsLocalSummaryService {
    func countPrices(context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<ProductPrice>())
    }
}
