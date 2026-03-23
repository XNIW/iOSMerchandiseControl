import Foundation

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

func formatCLPMoney(_ value: Double) -> String {
    if let formatted = clpMoneyFormatter.string(from: value as NSNumber) {
        return formatted
    }

    let number = clpNumberFormatter.string(from: value as NSNumber) ?? String(Int(value.rounded()))
    return "$\(number)"
}
