import SwiftData

@Model
class Supplier {
    @Attribute(.unique) var name: String

    init(name: String) {
        self.name = name
    }
}

@Model
class Category {
    @Attribute(.unique) var name: String

    init(name: String) {
        self.name = name
    }
}

@Model
class Product {
    // Room: id Long autogenerato → qui usiamo l’id implicito di SwiftData
    @Attribute(.unique) var barcode: String

    var itemNumber: String?
    var productName: String?
    var secondProductName: String?

    var purchasePrice: Double?
    var retailPrice: Double?
    var stockQuantity: Double?

    // Relazioni come in Room (supplierId, categoryId)
    var supplier: Supplier?
    var category: Category?

    init(
        barcode: String,
        itemNumber: String? = nil,
        productName: String? = nil,
        secondProductName: String? = nil,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        supplier: Supplier? = nil,
        category: Category? = nil
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
