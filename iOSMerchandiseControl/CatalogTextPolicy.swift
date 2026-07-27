import Foundation

nonisolated enum CatalogTextField: String, Equatable, Sendable {
    case productName
    case secondProductName
    case supplierName
    case categoryName
    case barcode
    case itemNumber
    case remoteIdentifier

    var isDisplayText: Bool {
        switch self {
        case .productName, .secondProductName, .supplierName, .categoryName:
            true
        case .barcode, .itemNumber, .remoteIdentifier:
            false
        }
    }

    var isRequired: Bool {
        switch self {
        case .productName, .supplierName, .categoryName, .barcode, .remoteIdentifier:
            true
        case .secondProductName, .itemNumber:
            false
        }
    }

    var maximumUTF16Length: Int {
        switch self {
        case .productName, .secondProductName:
            240
        case .supplierName, .categoryName:
            160
        case .barcode:
            96
        case .itemNumber:
            120
        case .remoteIdentifier:
            256
        }
    }
}

nonisolated enum CatalogTextChange: String, Codable, CaseIterable, Sendable {
    case unicodeNFC = "unicode_nfc"
    case lineBreakToSpace = "line_break_to_space"
    case tabToSpace = "tab_to_space"
    case spaceSeparatorToSpace = "space_separator_to_space"
    case spaceCollapsed = "space_collapsed"
    case trimmed
}

nonisolated enum CatalogTextRejectionReason: String, Codable, Error, Sendable {
    case emptyRequired = "empty_required"
    case prohibitedControl = "prohibited_control"
    case prohibitedLineSeparator = "prohibited_line_separator"
    case prohibitedZeroWidth = "prohibited_zero_width"
    case prohibitedBOM = "prohibited_bom"
    case prohibitedBidi = "prohibited_bidi"
    case tooLong = "too_long"
    case invalidUTF8 = "invalid_utf8"
    case invalidUTF16 = "invalid_utf16"
    case identityCollisionAfterTrim = "identity_collision_after_trim"

    var localizationKey: String {
        "catalog.text.error.\(rawValue)"
    }
}

nonisolated enum CatalogTextOutcome: Equatable, Sendable {
    case unchanged(String)
    case normalized(String, changes: [CatalogTextChange])
    case rejected(CatalogTextRejectionReason)

    var value: String? {
        switch self {
        case let .unchanged(value), let .normalized(value, _):
            value
        case .rejected:
            nil
        }
    }

    var changes: [CatalogTextChange] {
        switch self {
        case let .normalized(_, changes):
            changes
        case .unchanged, .rejected:
            []
        }
    }

    var rejectionReason: CatalogTextRejectionReason? {
        guard case let .rejected(reason) = self else { return nil }
        return reason
    }

    var wasNormalized: Bool {
        if case .normalized = self {
            return true
        }
        return false
    }
}

nonisolated struct CatalogTextValidationError: LocalizedError, Equatable, Sendable {
    let field: CatalogTextField
    let reason: CatalogTextRejectionReason

    var errorDescription: String? {
        String(
            format: NSLocalizedString(reason.localizationKey, comment: ""),
            field.rawValue
        )
    }
}

nonisolated struct CatalogTextNormalization: Equatable, Sendable {
    let field: CatalogTextField
    let value: String
    let changes: [CatalogTextChange]

    var wasNormalized: Bool {
        !changes.isEmpty
    }
}

nonisolated enum CatalogTextPolicy {
    static let version = "catalog_text_policy_v1"

    static func evaluate(_ value: String, for field: CatalogTextField) -> CatalogTextOutcome {
        if field.isDisplayText {
            return display(
                value,
                required: field.isRequired,
                maximumUTF16Length: field.maximumUTF16Length
            )
        }
        return strict(
            value,
            required: field.isRequired,
            maximumUTF16Length: field.maximumUTF16Length
        )
    }

    static func validate(_ value: String, for field: CatalogTextField) throws
        -> CatalogTextNormalization {
        let outcome = evaluate(value, for: field)
        switch outcome {
        case let .unchanged(canonical):
            return CatalogTextNormalization(field: field, value: canonical, changes: [])
        case let .normalized(canonical, changes):
            return CatalogTextNormalization(
                field: field,
                value: canonical,
                changes: changes
            )
        case let .rejected(reason):
            throw CatalogTextValidationError(field: field, reason: reason)
        }
    }

    static func optionalValue(_ value: String?, for field: CatalogTextField) throws
        -> CatalogTextNormalization? {
        guard let value else { return nil }
        let normalized = try validate(value, for: field)
        return normalized.value.isEmpty ? nil : normalized
    }

    static func display(
        _ value: String,
        required: Bool,
        maximumUTF16Length: Int
    ) -> CatalogTextOutcome {
        var foundLineBreak = false
        var foundTab = false
        var foundSpaceSeparator = false
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(value.unicodeScalars.count)

        var index = value.unicodeScalars.startIndex
        while index < value.unicodeScalars.endIndex {
            let scalar = value.unicodeScalars[index]
            if let reason = displayRejection(for: scalar) {
                return .rejected(reason)
            }

            if scalar.value == 0x0D {
                foundLineBreak = true
                scalars.append(" ")
                let next = value.unicodeScalars.index(after: index)
                if next < value.unicodeScalars.endIndex,
                   value.unicodeScalars[next].value == 0x0A {
                    index = value.unicodeScalars.index(after: next)
                } else {
                    index = next
                }
                continue
            }
            if scalar.value == 0x0A {
                foundLineBreak = true
                scalars.append(" ")
            } else if scalar.value == 0x09 {
                foundTab = true
                scalars.append(" ")
            } else if scalar.value != 0x20,
                      scalar.properties.generalCategory == .spaceSeparator {
                foundSpaceSeparator = true
                scalars.append(" ")
            } else {
                scalars.append(scalar)
            }
            index = value.unicodeScalars.index(after: index)
        }

        let replaced = String(String.UnicodeScalarView(scalars))
        let collapsed = collapseASCIIWhitespace(replaced)
        let trimmed = trimASCIISpaces(collapsed.value)
        let canonical = trimmed.value.precomposedStringWithCanonicalMapping
        let changedCanonicalScalars =
            Array(canonical.unicodeScalars) != Array(trimmed.value.unicodeScalars)

        if canonical.isEmpty, required {
            return .rejected(.emptyRequired)
        }
        guard canonical.utf16.count <= maximumUTF16Length else {
            return .rejected(.tooLong)
        }

        var changes: [CatalogTextChange] = []
        if foundLineBreak { changes.append(.lineBreakToSpace) }
        if foundTab { changes.append(.tabToSpace) }
        if foundSpaceSeparator { changes.append(.spaceSeparatorToSpace) }
        if collapsed.changed,
           foundLineBreak
            || foundTab
            || foundSpaceSeparator
            || trimASCIISpaces(replaced).value.contains("  ") {
            changes.append(.spaceCollapsed)
        }
        if trimmed.changed { changes.append(.trimmed) }
        if changedCanonicalScalars { changes.append(.unicodeNFC) }

        return changes.isEmpty
            ? .unchanged(canonical)
            : .normalized(canonical, changes: changes)
    }

    static func strict(
        _ value: String,
        required: Bool,
        maximumUTF16Length: Int
    ) -> CatalogTextOutcome {
        for scalar in value.unicodeScalars {
            if let reason = strictRejection(for: scalar) {
                return .rejected(reason)
            }
        }

        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty, required {
            return .rejected(.emptyRequired)
        }
        guard trimmed.utf16.count <= maximumUTF16Length else {
            return .rejected(.tooLong)
        }
        return trimmed == value
            ? .unchanged(trimmed)
            : .normalized(trimmed, changes: [.trimmed])
    }

    static func display(
        utf8Bytes: Data,
        required: Bool,
        maximumUTF16Length: Int
    ) -> CatalogTextOutcome {
        guard let value = String(data: utf8Bytes, encoding: .utf8) else {
            return .rejected(.invalidUTF8)
        }
        return display(
            value,
            required: required,
            maximumUTF16Length: maximumUTF16Length
        )
    }

    static func strict(
        utf8Bytes: Data,
        required: Bool,
        maximumUTF16Length: Int
    ) -> CatalogTextOutcome {
        guard let value = String(data: utf8Bytes, encoding: .utf8) else {
            return .rejected(.invalidUTF8)
        }
        return strict(
            value,
            required: required,
            maximumUTF16Length: maximumUTF16Length
        )
    }

    static func display(
        utf16CodeUnits: [UInt16],
        required: Bool,
        maximumUTF16Length: Int
    ) -> CatalogTextOutcome {
        guard isWellFormedUTF16(utf16CodeUnits) else {
            return .rejected(.invalidUTF16)
        }
        return display(
            String(decoding: utf16CodeUnits, as: UTF16.self),
            required: required,
            maximumUTF16Length: maximumUTF16Length
        )
    }

    static func strict(
        utf16CodeUnits: [UInt16],
        required: Bool,
        maximumUTF16Length: Int
    ) -> CatalogTextOutcome {
        guard isWellFormedUTF16(utf16CodeUnits) else {
            return .rejected(.invalidUTF16)
        }
        return strict(
            String(decoding: utf16CodeUnits, as: UTF16.self),
            required: required,
            maximumUTF16Length: maximumUTF16Length
        )
    }

    static func strictIdentitySet(
        _ values: [String],
        required: Bool,
        maximumUTF16Length: Int
    ) -> CatalogTextOutcome {
        var canonicalValues: [String] = []
        var firstRawValueByCanonical: [String: String] = [:]
        canonicalValues.reserveCapacity(values.count)
        var sawNormalization = false

        for value in values {
            let outcome = strict(
                value,
                required: required,
                maximumUTF16Length: maximumUTF16Length
            )
            if let reason = outcome.rejectionReason {
                return .rejected(reason)
            }
            guard let canonical = outcome.value else {
                return .rejected(.emptyRequired)
            }
            if let previousRaw = firstRawValueByCanonical[canonical],
               previousRaw != value {
                return .rejected(.identityCollisionAfterTrim)
            }
            firstRawValueByCanonical[canonical] = value
            canonicalValues.append(canonical)
            sawNormalization = sawNormalization || outcome.wasNormalized
        }

        let joined = canonicalValues.joined(separator: "\u{001F}")
        return sawNormalization
            ? .normalized(joined, changes: [.trimmed])
            : .unchanged(joined)
    }

    private static func displayRejection(
        for scalar: Unicode.Scalar
    ) -> CatalogTextRejectionReason? {
        let value = scalar.value
        if value == 0x2028 || value == 0x2029 {
            return .prohibitedLineSeparator
        }
        if value == 0x200B || value == 0x2060 {
            return .prohibitedZeroWidth
        }
        if value == 0xFEFF {
            return .prohibitedBOM
        }
        if (0x202A...0x202E).contains(value) || (0x2066...0x2069).contains(value) {
            return .prohibitedBidi
        }
        if (value <= 0x1F && value != 0x09 && value != 0x0A && value != 0x0D)
            || (0x7F...0x9F).contains(value) {
            return .prohibitedControl
        }
        return nil
    }

    private static func strictRejection(
        for scalar: Unicode.Scalar
    ) -> CatalogTextRejectionReason? {
        let value = scalar.value
        if value == 0x2028 || value == 0x2029 {
            return .prohibitedLineSeparator
        }
        if (0x200B...0x200D).contains(value) || value == 0x2060 {
            return .prohibitedZeroWidth
        }
        if value == 0xFEFF {
            return .prohibitedBOM
        }
        if (0x202A...0x202E).contains(value) || (0x2066...0x2069).contains(value) {
            return .prohibitedBidi
        }
        if value <= 0x1F || (0x7F...0x9F).contains(value) {
            return .prohibitedControl
        }
        return nil
    }

    private static func collapseASCIIWhitespace(_ value: String)
        -> (value: String, changed: Bool) {
        var result = ""
        result.reserveCapacity(value.count)
        var previousWasSpace = false
        var changed = false

        for character in value {
            if character == " " {
                if previousWasSpace {
                    changed = true
                    continue
                }
                previousWasSpace = true
            } else {
                previousWasSpace = false
            }
            result.append(character)
        }
        return (result, changed)
    }

    private static func trimASCIISpaces(_ value: String)
        -> (value: String, changed: Bool) {
        let trimmed = String(value.drop(while: { $0 == " " }).reversed()
            .drop(while: { $0 == " " }).reversed())
        return (trimmed, trimmed != value)
    }

    private static func isWellFormedUTF16(_ units: [UInt16]) -> Bool {
        var index = 0
        while index < units.count {
            let unit = units[index]
            if (0xD800...0xDBFF).contains(unit) {
                guard index + 1 < units.count,
                      (0xDC00...0xDFFF).contains(units[index + 1]) else {
                    return false
                }
                index += 2
            } else if (0xDC00...0xDFFF).contains(unit) {
                return false
            } else {
                index += 1
            }
        }
        return true
    }
}
