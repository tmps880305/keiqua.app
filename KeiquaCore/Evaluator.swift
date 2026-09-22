import Foundation

public enum Calculator {
    /// 計算算式字串，例如 "2+3×4" → 14。
    public static func evaluate(_ expression: String) throws -> Decimal {
        var evaluator = Evaluator(tokens: try Tokenizer.tokenize(expression))
        let value = try evaluator.evaluate()
        // 避免 0×-1 得到 -0
        return value.isZero ? 0 : value
    }
}

/// 遞迴下降解析並直接求值。文法（優先順序由低到高）：
///
///     expression := term (("+" | "-") term)*
///     term       := unary (("×" | "÷") unary)*
///     unary      := "-" unary | postfix
///     postfix    := primary "%"*
///     primary    := number | "(" expression ")"
///
/// Web 類比：每個文法規則對應一個函式，函式互相呼叫就是優先順序。
struct Evaluator {
    private let tokens: [Token]
    private var position = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    mutating func evaluate() throws -> Decimal {
        let value = try parseExpression()
        guard position == tokens.count else { throw CalculatorError.syntax }
        return value
    }

    private mutating func parseExpression() throws -> Decimal {
        var result = try parseTerm()
        while let token = peek(), token == .plus || token == .minus {
            position += 1
            let rhs = try parseTerm()
            result = try checked(token == .plus ? result + rhs : result - rhs)
        }
        return result
    }

    private mutating func parseTerm() throws -> Decimal {
        var result = try parseUnary()
        while let token = peek(), token == .multiply || token == .divide {
            position += 1
            let rhs = try parseUnary()
            if token == .multiply {
                result = try checked(result * rhs)
            } else {
                guard !rhs.isZero else { throw CalculatorError.divisionByZero }
                result = try checked(result / rhs)
            }
        }
        return result
    }

    private mutating func parseUnary() throws -> Decimal {
        if peek() == .minus {
            position += 1
            return -(try parseUnary())
        }
        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> Decimal {
        var value = try parsePrimary()
        while peek() == .percent {
            position += 1
            value = try checked(value / 100)
        }
        return value
    }

    private mutating func parsePrimary() throws -> Decimal {
        guard let token = peek() else { throw CalculatorError.syntax }
        switch token {
        case .number(let value):
            position += 1
            return value
        case .leftParen:
            position += 1
            let value = try parseExpression()
            guard peek() == .rightParen else { throw CalculatorError.syntax }
            position += 1
            return value
        default:
            throw CalculatorError.syntax
        }
    }

    private func peek() -> Token? {
        position < tokens.count ? tokens[position] : nil
    }

    /// Decimal 運算超出範圍時結果會是 NaN
    private func checked(_ value: Decimal) throws -> Decimal {
        if value.isNaN { throw CalculatorError.overflow }
        return value
    }
}
