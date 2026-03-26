import Foundation

struct HistoryEntryRuntimeSummary {
    let totalItems: Int
    let missingItems: Int
    let paymentTotal: Double

    static func compute(from mergedGrid: [[String]], complete: [Bool]) -> HistoryEntryRuntimeSummary {
        let totalItems = max(0, mergedGrid.count - 1)
        let header = mergedGrid.first ?? []
        let indices = HeaderIndices(header: header)

        var checked = 0
        var paymentTotal = 0.0

        for rowIndex in 1..<mergedGrid.count {
            let isComplete = rowIndex < complete.count && complete[rowIndex]
            if isComplete {
                checked += 1
            }

            guard isComplete else { continue }

            let row = mergedGrid[rowIndex]
            guard let quantity = resolvedQuantity(in: row, indices: indices),
                  quantity > 0 else {
                continue
            }

            let finalUnitPrice = max(0, resolvedFinalUnitPrice(in: row, indices: indices))
            paymentTotal += finalUnitPrice * quantity
        }

        return HistoryEntryRuntimeSummary(
            totalItems: totalItems,
            missingItems: max(0, totalItems - checked),
            paymentTotal: paymentTotal
        )
    }

    private struct HeaderIndices {
        let quantity: Int?
        let realQuantity: Int?
        let purchasePrice: Int?
        let discountedPrice: Int?
        let discount: Int?

        init(header: [String]) {
            quantity = header.firstIndex(of: "quantity")
            realQuantity = header.firstIndex(of: "realQuantity")
            purchasePrice = header.firstIndex(of: "purchasePrice")
            discountedPrice = header.firstIndex(of: "discountedPrice")
            discount = header.firstIndex(of: "discount")
        }
    }

    private static func resolvedQuantity(in row: [String], indices: HeaderIndices) -> Double? {
        if let realQuantity = parseNumber(cellValue(in: row, at: indices.realQuantity)) {
            return realQuantity
        }

        return parseNumber(cellValue(in: row, at: indices.quantity))
    }

    private static func resolvedFinalUnitPrice(in row: [String], indices: HeaderIndices) -> Double {
        if let discountedPrice = parseNumber(cellValue(in: row, at: indices.discountedPrice)) {
            return discountedPrice
        }

        let purchasePrice = parseNumber(cellValue(in: row, at: indices.purchasePrice)) ?? 0

        if let discount = parseNumber(cellValue(in: row, at: indices.discount), allowPercentSuffix: true),
           (0...100).contains(discount) {
            return purchasePrice * (1 - discount / 100)
        }

        return purchasePrice
    }

    private static func cellValue(in row: [String], at index: Int?) -> String {
        guard let index, row.indices.contains(index) else { return "" }
        return row[index]
    }

    private static func parseNumber(_ raw: String, allowPercentSuffix: Bool = false) -> Double? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if allowPercentSuffix, trimmed.hasSuffix("%") {
            trimmed.removeLast()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
        }

        if trimmed.range(of: #"^-?\d{1,3}(\.\d{3})*,\d+$"#, options: .regularExpression) != nil {
            let withoutSeparators = trimmed.replacingOccurrences(of: ".", with: "")
            return Double(withoutSeparators.replacingOccurrences(of: ",", with: "."))
        }

        if trimmed.range(of: #"^-?\d{1,3}(,\d{3})*\.\d+$"#, options: .regularExpression) != nil {
            return Double(trimmed.replacingOccurrences(of: ",", with: ""))
        }

        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}
