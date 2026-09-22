import Foundation

/// 把算式字串拆成 Token。只負責切字，不判斷語法（例如負號、括號是否配對留給 Parser）。
public enum Tokenizer {
    /// 單一數字最多的有效位數（不含前導 0）。
    public static let maxDigits = 16

    private static let posix = Locale(identifier: "en_US_POSIX")

    public static func tokenize(_ input: String) throws -> [Token] {
        let chars = Array(input)
        var tokens: [Token] = []
        var i = 0

        while i < chars.count {
            let c = chars[i]
            switch c {
            case " ", "\t", "\n":
                i += 1
            case "+":
                tokens.append(.plus)
                i += 1
            case "-", "−":
                tokens.append(.minus)
                i += 1
            case "×", "*":
                tokens.append(.multiply)
                i += 1
            case "÷", "/":
                tokens.append(.divide)
                i += 1
            case "(":
                tokens.append(.leftParen)
                i += 1
            case ")":
                tokens.append(.rightParen)
                i += 1
            case "%":
                tokens.append(.percent)
                i += 1
            default:
                guard isDigit(c) || c == "." else {
                    throw CalculatorError.invalidCharacter(c)
                }
                var literal = ""
                while i < chars.count, isDigit(chars[i]) || chars[i] == "." {
                    literal.append(chars[i])
                    i += 1
                }
                tokens.append(.number(try parseNumber(literal)))
            }
        }
        return tokens
    }

    private static func isDigit(_ c: Character) -> Bool {
        c >= "0" && c <= "9"
    }

    private static func parseNumber(_ literal: String) throws -> Decimal {
        let parts = literal.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, literal != "." else {
            throw CalculatorError.malformedNumber
        }

        // 位數以去掉前導 0 之後的數字個數計算
        let digits = literal.filter { $0 != "." }.drop { $0 == "0" }
        guard digits.count <= maxDigits else {
            throw CalculatorError.numberTooLong
        }

        // 補齊 ".5" 與 "5." 的寫法，不依賴 Decimal(string:) 對這類輸入的行為
        let integerPart = parts[0].isEmpty ? "0" : String(parts[0])
        let fractionPart = parts.count == 2 ? String(parts[1]) : ""
        let normalized = fractionPart.isEmpty ? integerPart : "\(integerPart).\(fractionPart)"

        guard let value = Decimal(string: normalized, locale: posix) else {
            throw CalculatorError.malformedNumber
        }
        return value
    }
}
