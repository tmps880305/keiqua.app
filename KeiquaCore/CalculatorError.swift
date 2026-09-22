public enum CalculatorError: Error, Equatable {
    /// 出現不認得的字元（例如英文字母、"="）
    case invalidCharacter(Character)
    /// 數字格式錯誤（例如 "1.2.3"、單獨的 "."）
    case malformedNumber
    /// 單一數字的有效位數超過上限
    case numberTooLong
    /// 語法錯誤（缺運算元、括號不成對、多餘的 Token 等）
    case syntax
    case divisionByZero
    /// 計算結果超出 Decimal 可表示的範圍
    case overflow
}
