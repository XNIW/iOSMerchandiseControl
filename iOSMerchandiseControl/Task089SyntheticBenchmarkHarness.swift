#if DEBUG
import Foundation
import xlsxwriter

enum Task089SyntheticBenchmarkHarness {
    struct ProductExportRow: Sendable {
        let barcode: String
        let itemNumber: String
        let productName: String
        let secondProductName: String
        let purchasePrice: Double?
        let retailPrice: Double?
        let oldPurchasePrice: Double?
        let oldRetailPrice: Double?
        let stockQuantity: Double?
        let supplierName: String
        let categoryName: String
    }

    struct PriceHistoryExportRow: Sendable {
        let productBarcode: String
        let timestamp: Date
        let type: String
        let newPrice: Double
        let source: String
    }

    struct FullDatabaseExportInput: Sendable {
        let products: [ProductExportRow]
        let suppliers: [String]
        let categories: [String]
        let priceHistory: [PriceHistoryExportRow]
    }

    static func exportProducts(rows: [ProductExportRow]) throws -> URL {
        let url = try exportURL(prefix: "TASK089_products")
        let workbook = xlsxwriter.Workbook(name: url.path)
        let sheet = workbook.addWorksheet(name: "Products")
        writeProducts(rows, to: sheet)
        workbook.close()
        return url
    }

    static func exportFullDatabase(input: FullDatabaseExportInput) throws -> URL {
        let url = try exportURL(prefix: "TASK089_database_full")
        let workbook = xlsxwriter.Workbook(name: url.path)

        writeProducts(input.products, to: workbook.addWorksheet(name: "Products"))
        writeNames(input.suppliers, header: "name", to: workbook.addWorksheet(name: "Suppliers"))
        writeNames(input.categories, header: "name", to: workbook.addWorksheet(name: "Categories"))
        writePriceHistory(input.priceHistory, to: workbook.addWorksheet(name: "PriceHistory"))

        workbook.close()
        return url
    }

    private static func exportURL(prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TASK089-benchmarks", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(prefix)_\(UUID().uuidString).xlsx")
    }

    private static func writeProducts(_ rows: [ProductExportRow], to sheet: Worksheet) {
        let headers = [
            "barcode",
            "itemNumber",
            "productName",
            "secondProductName",
            "purchasePrice",
            "retailPrice",
            "oldPurchasePrice",
            "oldRetailPrice",
            "stockQuantity",
            "supplierName",
            "categoryName"
        ]

        for (columnIndex, header) in headers.enumerated() {
            sheet.write(.string(header), [0, columnIndex])
        }

        for (rowIndex, product) in rows.enumerated() {
            let row = rowIndex + 1
            sheet.write(.string(product.barcode), [row, 0])
            sheet.write(.string(product.itemNumber), [row, 1])
            sheet.write(.string(product.productName), [row, 2])
            sheet.write(.string(product.secondProductName), [row, 3])
            if let purchasePrice = product.purchasePrice {
                sheet.write(.number(purchasePrice), [row, 4])
            }
            if let retailPrice = product.retailPrice {
                sheet.write(.number(retailPrice), [row, 5])
            }
            if let oldPurchasePrice = product.oldPurchasePrice {
                sheet.write(.number(oldPurchasePrice), [row, 6])
            }
            if let oldRetailPrice = product.oldRetailPrice {
                sheet.write(.number(oldRetailPrice), [row, 7])
            }
            if let stockQuantity = product.stockQuantity {
                sheet.write(.number(stockQuantity), [row, 8])
            }
            sheet.write(.string(product.supplierName), [row, 9])
            sheet.write(.string(product.categoryName), [row, 10])
        }
    }

    private static func writeNames(_ values: [String], header: String, to sheet: Worksheet) {
        sheet.write(.string(header), [0, 0])
        for (rowIndex, value) in values.enumerated() {
            sheet.write(.string(value), [rowIndex + 1, 0])
        }
    }

    private static func writePriceHistory(_ rows: [PriceHistoryExportRow], to sheet: Worksheet) {
        let headers = [
            "productBarcode",
            "timestamp",
            "type",
            "oldPrice",
            "newPrice",
            "source"
        ]

        for (columnIndex, header) in headers.enumerated() {
            sheet.write(.string(header), [0, columnIndex])
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var previousPriceByGroup: [String: Double] = [:]
        for (rowIndex, rowData) in rows.enumerated() {
            let row = rowIndex + 1
            let groupKey = "\(rowData.productBarcode)|\(rowData.type)"
            let oldPrice = previousPriceByGroup[groupKey]

            sheet.write(.string(rowData.productBarcode), [row, 0])
            sheet.write(.string(formatter.string(from: rowData.timestamp)), [row, 1])
            sheet.write(.string(rowData.type), [row, 2])
            if let oldPrice {
                sheet.write(.number(oldPrice), [row, 3])
            }
            sheet.write(.number(rowData.newPrice), [row, 4])
            sheet.write(.string(rowData.source), [row, 5])

            previousPriceByGroup[groupKey] = rowData.newPrice
        }
    }
}
#endif
