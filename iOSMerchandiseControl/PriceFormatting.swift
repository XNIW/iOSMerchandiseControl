import Foundation

enum CLNumericInputResult: Equatable, Sendable {
    case empty
    case value(Double)
    case invalid
    case negative

    var value: Double? {
        guard case let .value(value) = self else { return nil }
        return value
    }

    var isAccepted: Bool {
        switch self {
        case .empty, .value:
            true
        case .invalid, .negative:
            false
        }
    }
}

private let clpMoneyFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "es_CL")
    formatter.numberStyle = .currency
    formatter.currencyCode = "CLP"
    formatter.currencySymbol = "$"
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    formatter.usesGroupingSeparator = true
    return formatter
}()

private let clpNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "es_CL")
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    formatter.usesGroupingSeparator = true
    return formatter
}()

private let clpQuantityFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "es_CL")
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 3
    formatter.usesGroupingSeparator = true
    return formatter
}()

func formatCLPMoney(_ value: Double) -> String {
    if let formatted = clpMoneyFormatter.string(from: value as NSNumber) {
        return formatted
    }

    let number = clpNumberFormatter.string(from: value as NSNumber) ?? String(Int(value.rounded()))
    return "$\(number)"
}

func formatCLQuantity(_ value: Double?) -> String {
    guard let value else { return "—" }
    return clpQuantityFormatter.string(from: value as NSNumber) ?? String(value)
}

func parseOptionalCLPriceInput(_ rawValue: String) -> CLNumericInputResult {
    parseOptionalCLNumericInput(rawValue, kind: .price)
}

func parseOptionalCLQuantityInput(_ rawValue: String) -> CLNumericInputResult {
    parseOptionalCLNumericInput(rawValue, kind: .quantity)
}

private enum CLNumericInputKind {
    case price
    case quantity
}

private func parseOptionalCLNumericInput(
    _ rawValue: String,
    kind: CLNumericInputKind
) -> CLNumericInputResult {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .empty }

    guard !trimmed.unicodeScalars.contains(where: {
        CharacterSet.whitespacesAndNewlines.contains($0)
    }) else {
        return .invalid
    }

    let groupedInteger =
        matchesNumericPattern(trimmed, #"^[+-]?\d{1,3}(\.\d{3})+$"#)
        || matchesNumericPattern(trimmed, #"^[+-]?\d{1,3}(,\d{3})+$"#)
    let groupedCLDecimal = matchesNumericPattern(trimmed, #"^[+-]?\d{1,3}(\.\d{3})+,\d+$"#)
    let groupedDotDecimal = matchesNumericPattern(trimmed, #"^[+-]?\d{1,3}(,\d{3})+\.\d+$"#)
    let scientificDecimal = matchesNumericPattern(
        trimmed,
        #"^[+-]?(\d+([.,]\d*)?|[.,]\d+)[eE][+-]?\d+$"#
    )
    let simpleDecimal = matchesNumericPattern(
        trimmed,
        #"^[+-]?(\d+([.,]\d*)?|[.,]\d+)$"#
    )

    let normalized: String
    switch kind {
    case .price:
        switch (groupedInteger, groupedCLDecimal, groupedDotDecimal, scientificDecimal, simpleDecimal) {
        case (true, _, _, _, _):
            normalized = trimmed
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
        case (_, true, _, _, _):
            normalized = trimmed
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        case (_, _, true, _, _):
            normalized = trimmed.replacingOccurrences(of: ",", with: "")
        case (_, _, _, true, _), (_, _, _, _, true):
            normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        default:
            return .invalid
        }
    case .quantity:
        switch (groupedCLDecimal, groupedDotDecimal, scientificDecimal, simpleDecimal, groupedInteger) {
        case (true, _, _, _, _):
            normalized = trimmed
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        case (_, true, _, _, _):
            normalized = trimmed.replacingOccurrences(of: ",", with: "")
        case (_, _, true, _, _), (_, _, _, true, _):
            normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        case (_, _, _, _, true):
            normalized = trimmed
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
        default:
            return .invalid
        }
    }

    guard let value = Double(normalized), value.isFinite else { return .invalid }
    return value < 0 ? .negative : .value(value)
}

private func matchesNumericPattern(_ value: String, _ pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
}
