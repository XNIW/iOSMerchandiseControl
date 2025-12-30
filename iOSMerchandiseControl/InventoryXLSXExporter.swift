import Foundation
import xlsxwriter

enum InventoryXLSXExporter {
    static func export(grid: [[String]], preferredName: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let ts = Self.timestampString()
        let safeBase = sanitize(preferredName.isEmpty ? "Inventario" : preferredName)
        let url = dir.appendingPathComponent("\(safeBase)_\(ts).xlsx")

        let workbook = xlsxwriter.Workbook(name: url.path)
        defer { workbook.close() }

        let sheet = workbook.addWorksheet(name: "Inventory")

        for (r, row) in grid.enumerated() {
            for (c, value) in row.enumerated() {
                sheet.write(.string(value), [r, c])
            }
        }

        return url
    }

    private static func timestampString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.string(from: Date())
    }

    private static func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
