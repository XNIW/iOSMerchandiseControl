import Foundation

enum HistoryImportedGridSupport {
    static func editableTemplate(forGrid grid: [[String]]) -> [[String]] {
        guard !grid.isEmpty else { return [] }
        return Array(repeating: ["", ""], count: grid.count)
    }

    static func initialSummary(forGrid grid: [[String]]) -> (totalItems: Int, orderTotal: Double) {
        guard let headerRow = grid.first else { return (0, 0) }

        let purchaseIndex = headerRow.firstIndex(of: "purchasePrice")
        let quantityIndex = headerRow.firstIndex(of: "quantity")

        guard let purchaseIndex, let quantityIndex else {
            return (0, 0)
        }

        var totalItems = 0
        var orderTotal = 0.0

        for row in grid.dropFirst() {
            guard quantityIndex < row.count,
                  let quantity = parsedNumber(from: row[quantityIndex]),
                  quantity > 0 else {
                continue
            }

            totalItems += 1

            let price = purchaseIndex < row.count
                ? (parsedNumber(from: row[purchaseIndex]) ?? 0.0)
                : 0.0
            orderTotal += price * quantity
        }

        return (totalItems, orderTotal)
    }

    static func isValidImportSnapshotGrid(_ snapshotData: [[String]]) -> Bool {
        guard !snapshotData.isEmpty,
              let header = snapshotData.first,
              !header.isEmpty else {
            return false
        }

        let hasNonEmptyHeaderCell = header.contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return hasNonEmptyHeaderCell && snapshotData.count >= 2
    }

    private static func parsedNumber(from raw: String) -> Double? {
        let normalized = raw
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}
