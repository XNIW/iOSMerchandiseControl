import Foundation

nonisolated enum SupabaseCatalogFingerprintSchema {
    static let currentVersion = 1
}

nonisolated enum SupabaseCatalogFingerprintNormalizer {
    private static let decimalScale = 6

    static func product(
        barcode: String?,
        itemNumber: String?,
        productName: String?,
        secondProductName: String?,
        purchasePrice: Double?,
        retailPrice: Double?,
        stockQuantity: Double?,
        supplierRemoteID: UUID?,
        categoryRemoteID: UUID?
    ) -> ManualPushFingerprint {
        ManualPushFingerprintNormalizer.fingerprint(
            entityKind: .product,
            fields: [
                ManualPushFingerprintField("barcode", .string(barcode)),
                ManualPushFingerprintField("itemNumber", .string(itemNumber)),
                ManualPushFingerprintField("productName", .string(productName)),
                ManualPushFingerprintField("secondProductName", .string(secondProductName)),
                ManualPushFingerprintField("purchasePrice", .number(purchasePrice)),
                ManualPushFingerprintField("retailPrice", .number(retailPrice)),
                ManualPushFingerprintField("stockQuantity", .number(stockQuantity)),
                ManualPushFingerprintField("supplierRemoteID", .uuid(supplierRemoteID)),
                ManualPushFingerprintField("categoryRemoteID", .uuid(categoryRemoteID))
            ]
        )
    }

    static func supplier(remoteID: UUID?, name: String?) -> ManualPushFingerprint {
        ManualPushFingerprintNormalizer.fingerprint(
            entityKind: .supplier,
            fields: [
                ManualPushFingerprintField("remoteID", .uuid(remoteID)),
                ManualPushFingerprintField("name", .string(name))
            ]
        )
    }

    static func category(remoteID: UUID?, name: String?) -> ManualPushFingerprint {
        ManualPushFingerprintNormalizer.fingerprint(
            entityKind: .productCategory,
            fields: [
                ManualPushFingerprintField("remoteID", .uuid(remoteID)),
                ManualPushFingerprintField("name", .string(name))
            ]
        )
    }

    static func canonicalDecimalString(_ value: Decimal?) -> String? {
        guard var value else {
            return nil
        }

        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, decimalScale, .plain)
        if rounded == Decimal(0) {
            return "0"
        }
        return NSDecimalNumber(decimal: rounded).stringValue
    }

    static func canonicalNumberString(_ value: Double?) -> String? {
        guard let value else {
            return nil
        }
        guard value.isFinite else {
            return "invalid"
        }
        return canonicalDecimalString(Decimal(value)) ?? "invalid"
    }
}
