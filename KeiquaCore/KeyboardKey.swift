public enum Operator: Equatable {
    case plus, minus, multiply, divide

    /// 插入輸入框的字元。減號用 ASCII "-"，貼到其他地方比較不會出問題。
    public var symbol: String {
        switch self {
        case .plus: return "+"
        case .minus: return "-"
        case .multiply: return "×"
        case .divide: return "÷"
        }
    }
}

/// 鍵盤上會送給 InputController 的按鍵（地球鍵由系統處理，不在這裡）。
public enum KeyboardKey: Equatable {
    case digit(Int)          // 0…9
    case decimalPoint
    case op(Operator)
    case leftParen
    case rightParen
    case percent
    case backspace
    case equals
    case newline
}
