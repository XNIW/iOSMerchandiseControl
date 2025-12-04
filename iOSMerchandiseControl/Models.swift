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

    init(name: String) {
        self.name = name
    }
}

// MARK: - Category

@Model
final class ProductCategory {
    @Attribute(.unique) var name: String

    init(name: String) {
        self.name = name
    }
}

// MARK: - Product

@Model
final class Product {
    @Attribute(.unique) var barcode: String

    var itemNumber: String?
    var productName: String?
    var secondProductName: String?

    var purchasePrice: Double?
    var retailPrice: Double?
    var stockQuantity: Double?

    var supplier: Supplier?
    var category: ProductCategory?

    /// Storico prezzi associato
    @Relationship var priceHistory: [ProductPrice] = []

    init(
        barcode: String,
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
    var type: PriceType
    var price: Double
    var effectiveAt: Date
    var source: String?
    var note: String?
    var createdAt: Date

    /// Relazione verso il prodotto (per ora senza inverse, per evitare problemi di key path)
    @Relationship var product: Product?

    init(
        type: PriceType,
        price: Double,
        effectiveAt: Date = Date(),
        source: String? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        product: Product? = nil
    ) {
        self.type = type
        self.price = price
        self.effectiveAt = effectiveAt
        self.source = source
        self.note = note
        self.createdAt = createdAt
        self.product = product
    }
}
