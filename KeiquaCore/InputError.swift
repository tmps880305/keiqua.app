/// 顯示在鍵盤上的簡短錯誤提示。
public enum InputError: Error, Equatable {
    case divisionByZero
    case syntax
    case overflow
    case numberTooLong
    case expressionTooLong

    public var message: String {
        switch self {
        case .divisionByZero: return "不能除以 0"
        case .syntax: return "格式錯誤"
        case .overflow: return "數字太大"
        case .numberTooLong: return "數字太長"
        case .expressionTooLong: return "算式太長"
        }
    }

    init(_ error: Error) {
        switch error as? CalculatorError {
        case .divisionByZero: self = .divisionByZero
        case .overflow: self = .overflow
        case .numberTooLong: self = .numberTooLong
        default: self = .syntax
        }
    }
}
