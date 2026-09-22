import Foundation

/// 把計算結果轉成要插入輸入框的字串：小數最多 10 位（四捨五入）、去除尾端 0、不加千分位。
public enum ResultFormatter {
    public static let maxFractionDigits = 10

    public static func format(_ value: Decimal) -> String {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, maxFractionDigits, .plain)   // 四捨五入（0.5 進位）

        // 避免小到被四捨五入成 0 的負數顯示成 "-0"
        if rounded.isZero { return "0" }

        // Decimal.description 固定使用 "." 當小數點，不受使用者語系影響
        var text = "\(rounded)"
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }
}
