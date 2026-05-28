import Foundation
import SwiftData

// MARK: - Enum condivisi

/// Stato di sincronizzazione (come su Android)
enum HistorySyncStatus: Int, Codable, CaseIterable {
    case notAttempted = 0
    case syncedSuccessfully = 1
    case attemptedWithErrors = 2
}

/// Tipo di prezzo: acquisto / vendita
enum PriceType: String, Codable, CaseIterable {
    case purchase
    case retail
}

// MARK: - Supplier

@Model
final class Supplier {
    @Attribute(.unique) var name: String

    var remoteID: UUID?
    var remoteUpdatedAt: Date?
    var remoteDeletedAt: Date?

    init(
        name: String,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil
    ) {
        self.name = name
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
    }
}

// MARK: - Category

@Model
final class ProductCategory {
    @Attribute(.unique) var name: String

    var remoteID: UUID?
    var remoteUpdatedAt: Date?
    var remoteDeletedAt: Date?

    init(
        name: String,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil
    ) {
        self.name = name
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
    }
}

// MARK: - Product

@Model
final class Product {
    @Attribute(.unique) var barcode: String

    var remoteID: UUID?
    var remoteUpdatedAt: Date?
    var remoteDeletedAt: Date?

    var itemNumber: String?
    var productName: String?
    var secondProductName: String?

    var purchasePrice: Double?
    var retailPrice: Double?
    var stockQuantity: Double?

    var supplier: Supplier?
    var category: ProductCategory?

    /// Storico prezzi associato
    @Relationship(deleteRule: .cascade, inverse: \ProductPrice.product) var priceHistory: [ProductPrice] = []

    init(
        barcode: String,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        itemNumber: String? = nil,
        productName: String? = nil,
        secondProductName: String? = nil,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        supplier: Supplier? = nil,
        category: ProductCategory? = nil
    ) {
        self.barcode = barcode
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
        self.itemNumber = itemNumber
        self.productName = productName
        self.secondProductName = secondProductName
        self.purchasePrice = purchasePrice
        self.retailPrice = retailPrice
        self.stockQuantity = stockQuantity
        self.supplier = supplier
        self.category = category
    }
}

// MARK: - ProductPrice (storico prezzi)

@Model
final class ProductPrice {
    var remoteID: UUID?

    var type: PriceType
    var price: Double
    var effectiveAt: Date
    var source: String?
    var note: String?
    var createdAt: Date

    /// Relazione verso il prodotto. L'inverse esplicito vive sul lato Product per evitare
    /// la circular macro expansion di SwiftData con doppia annotazione reciproca.
    var product: Product?

    init(
        remoteID: UUID? = nil,
        type: PriceType,
        price: Double,
        effectiveAt: Date = Date(),
        source: String? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        product: Product? = nil
    ) {
        self.remoteID = remoteID
        self.type = type
        self.price = price
        self.effectiveAt = effectiveAt
        self.source = source
        self.note = note
        self.createdAt = createdAt
        self.product = product
    }
}

enum ProductPriceContract {
    static func currentPrice(for product: Product, type: PriceType) -> Double? {
        switch type {
        case .purchase:
            return product.purchasePrice
        case .retail:
            return product.retailPrice
        }
    }

    static func sortedHistory(_ prices: [ProductPrice], type: PriceType? = nil) -> [ProductPrice] {
        prices
            .filter { price in
                guard let type else { return true }
                return price.type == type
            }
            .sorted { lhs, rhs in
                if lhs.effectiveAt != rhs.effectiveAt {
                    return lhs.effectiveAt > rhs.effectiveAt
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    static func lastPrice(in prices: [ProductPrice], type: PriceType) -> ProductPrice? {
        sortedHistory(prices, type: type).first
    }

    static func previousPrice(in prices: [ProductPrice], type: PriceType) -> ProductPrice? {
        sortedHistory(prices, type: type).dropFirst().first
    }
}
