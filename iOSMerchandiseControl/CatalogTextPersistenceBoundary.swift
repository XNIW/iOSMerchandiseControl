import Foundation

nonisolated struct CatalogTextNonCanonicalError: Error, Equatable, Sendable {
    let field: CatalogTextField
}

/// Ultima barriera locale prima di fingerprint/outbox, export o salvataggio esplicito.
/// Valida tutti i campi prima di mutare il modello, così un rifiuto non lascia
/// canonicalizzazioni parziali nel `ModelContext`.
nonisolated enum CatalogTextPersistenceBoundary {
    static func preflightCanonicalization(_ supplier: Supplier) throws {
        _ = try CatalogTextPolicy.validate(
            supplier.name,
            for: .supplierName
        ).value
    }

    static func preflightCanonicalization(_ category: ProductCategory) throws {
        _ = try CatalogTextPolicy.validate(
            category.name,
            for: .categoryName
        ).value
    }

    static func preflightCanonicalization(_ product: Product) throws {
        _ = try CatalogTextPolicy.validate(
            product.barcode,
            for: .barcode
        ).value
        _ = try optionalStrict(
            product.itemNumber,
            field: .itemNumber
        )
        _ = try optionalDisplay(
            product.productName,
            field: .productName
        )
        _ = try optionalDisplay(
            product.secondProductName,
            field: .secondProductName
        )
    }

    static func canonicalize(_ supplier: Supplier) throws {
        let name = try CatalogTextPolicy.validate(
            supplier.name,
            for: .supplierName
        ).value
        supplier.name = name
    }

    static func canonicalize(_ category: ProductCategory) throws {
        let name = try CatalogTextPolicy.validate(
            category.name,
            for: .categoryName
        ).value
        category.name = name
    }

    static func canonicalize(_ product: Product) throws {
        let barcode = try CatalogTextPolicy.validate(
            product.barcode,
            for: .barcode
        ).value
        let itemNumber = try optionalStrict(
            product.itemNumber,
            field: .itemNumber
        )
        let productName = try optionalDisplay(
            product.productName,
            field: .productName
        )
        let secondProductName = try optionalDisplay(
            product.secondProductName,
            field: .secondProductName
        )
        product.barcode = barcode
        product.itemNumber = itemNumber
        product.productName = productName
        product.secondProductName = secondProductName
    }

    static func validateCanonical(_ supplier: Supplier) throws {
        try requireScalarExact(
            supplier.name,
            canonical: CatalogTextPolicy.validate(
                supplier.name,
                for: .supplierName
            ).value,
            field: .supplierName
        )
    }

    static func validateCanonical(_ category: ProductCategory) throws {
        try requireScalarExact(
            category.name,
            canonical: CatalogTextPolicy.validate(
                category.name,
                for: .categoryName
            ).value,
            field: .categoryName
        )
    }

    static func validateCanonical(_ product: Product) throws {
        try requireScalarExact(
            product.barcode,
            canonical: CatalogTextPolicy.validate(
                product.barcode,
                for: .barcode
            ).value,
            field: .barcode
        )
        try requireOptionalScalarExact(
            product.itemNumber,
            canonical: validatedOptionalStrict(
                product.itemNumber,
                field: .itemNumber
            ),
            field: .itemNumber
        )
        try requireOptionalScalarExact(
            product.productName,
            canonical: validatedOptionalDisplay(
                product.productName,
                field: .productName
            ),
            field: .productName
        )
        try requireOptionalScalarExact(
            product.secondProductName,
            canonical: validatedOptionalDisplay(
                product.secondProductName,
                field: .secondProductName
            ),
            field: .secondProductName
        )
        if let supplier = product.supplier {
            try validateCanonical(supplier)
        }
        if let category = product.category {
            try validateCanonical(category)
        }
    }

    static func validateFullCatalogExport(
        products: [Product],
        suppliers: [Supplier],
        categories: [ProductCategory]
    ) throws {
        for product in products {
            try validateCanonical(product)
        }
        for supplier in suppliers {
            try validateCanonical(supplier)
        }
        for category in categories {
            try validateCanonical(category)
        }
    }

    static func validatedOptionalDisplay(
        _ value: String?,
        field: CatalogTextField
    ) throws -> String? {
        try optionalDisplay(value, field: field)
    }

    static func validatedOptionalStrict(
        _ value: String?,
        field: CatalogTextField
    ) throws -> String? {
        try optionalStrict(value, field: field)
    }

    private static func optionalDisplay(
        _ value: String?,
        field: CatalogTextField
    ) throws -> String? {
        guard let value else { return nil }
        let outcome = CatalogTextPolicy.display(
            value,
            required: false,
            maximumUTF16Length: field.maximumUTF16Length
        )
        return try canonicalValue(outcome, field: field)
    }

    private static func optionalStrict(
        _ value: String?,
        field: CatalogTextField
    ) throws -> String? {
        guard let value else { return nil }
        let outcome = CatalogTextPolicy.strict(
            value,
            required: false,
            maximumUTF16Length: field.maximumUTF16Length
        )
        return try canonicalValue(outcome, field: field)
    }

    private static func canonicalValue(
        _ outcome: CatalogTextOutcome,
        field: CatalogTextField
    ) throws -> String? {
        switch outcome {
        case let .unchanged(value), let .normalized(value, _):
            return value.isEmpty ? nil : value
        case let .rejected(reason):
            throw CatalogTextValidationError(field: field, reason: reason)
        }
    }

    private static func requireOptionalScalarExact(
        _ value: String?,
        canonical: String?,
        field: CatalogTextField
    ) throws {
        switch (value, canonical) {
        case (nil, nil):
            return
        case let (.some(value), .some(canonical)):
            try requireScalarExact(value, canonical: canonical, field: field)
        default:
            throw CatalogTextNonCanonicalError(field: field)
        }
    }

    private static func requireScalarExact(
        _ value: String,
        canonical: String,
        field: CatalogTextField
    ) throws {
        guard Array(value.unicodeScalars) == Array(canonical.unicodeScalars) else {
            throw CatalogTextNonCanonicalError(field: field)
        }
    }
}
