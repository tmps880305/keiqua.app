import Foundation

public enum Token: Equatable {
    case number(Decimal)
    case plus
    case minus
    case multiply
    case divide
    case leftParen
    case rightParen
    case percent
}
