import Foundation

nonisolated enum CatalogCSVParserError: LocalizedError, Equatable, Sendable {
    case unclosedQuote

    var errorDescription: String? {
        NSLocalizedString("catalog.text.csv.unclosed_quote", comment: "")
    }
}

/// Parser documentale `;` quote-aware. Conserva CR/LF/TAB nei campi quotati:
/// la policy catalogo li renderà visibili nel preview e produrrà il warning.
nonisolated enum CatalogCSVParser {
    static func parse(_ content: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        let scalars = Array(content.unicodeScalars)
        var index = 0

        func appendField() {
            row.append(field)
            field = ""
        }

        func appendRow() {
            appendField()
            rows.append(row)
            row = []
        }

        while index < scalars.count {
            let scalar = scalars[index]
            let next = index + 1

            if scalar.value == 0x22 {
                if insideQuotes,
                   next < scalars.count,
                   scalars[next].value == 0x22 {
                    field.append("\"")
                    index = next + 1
                    continue
                }
                insideQuotes.toggle()
            } else if scalar.value == 0x3B, !insideQuotes {
                appendField()
            } else if (scalar.value == 0x0A || scalar.value == 0x0D), !insideQuotes {
                appendRow()
                if scalar.value == 0x0D,
                   next < scalars.count,
                   scalars[next].value == 0x0A {
                    index = next + 1
                    continue
                }
            } else {
                field.unicodeScalars.append(scalar)
            }
            index += 1
        }

        guard !insideQuotes else {
            throw CatalogCSVParserError.unclosedQuote
        }

        if !field.isEmpty || !row.isEmpty {
            appendRow()
        }
        return rows
    }
}
