import Foundation

/// 鍵盤的輸入狀態機：把按鍵翻成對輸入框的操作，並維護算式緩衝區。
///
/// 輸入框裡的文字才是使用者看到的內容，這裡只記錄「這個鍵盤在這一輪插入了什麼」：
/// - `expression`：要拿去計算的算式，例如 "500+100"
/// - `sessionText`：這一輪插入輸入框的全部字元，例如 "200+300=500+100"
/// 一輪從第一個字元開始，到清除、換行、外部改動，或 "=" 之後開始新算式為止。
@MainActor
public final class InputController {
    public enum Phase: Equatable {
        case editing
        case evaluated(result: String)
    }

    public static let maxExpressionLength = 200

    public private(set) var expression = ""
    public private(set) var sessionText = ""
    public private(set) var phase: Phase = .editing

    /// 顯示錯誤提示；傳入 nil 代表清除。錯誤在下一次按鍵時清除，不使用計時器。
    public var onError: ((InputError?) -> Void)?

    private let proxy: TextInputProxy
    private var isPerformingOwnEdit = false
    private var isShowingError = false

    private enum Role {
        case digit, decimalPoint, leftParen   // 開始或延續一個運算元
        case continuation                     // 運算符與 %：可接在 "=" 的結果後面
        case closer                           // ")"
    }

    public init(proxy: TextInputProxy) {
        self.proxy = proxy
    }

    // MARK: - 按鍵

    public func handle(_ key: KeyboardKey) {
        clearError()
        switch key {
        case .digit(let n):
            guard (0...9).contains(n) else { return }
            input(String(n), role: .digit)
        case .decimalPoint:
            input(".", role: .decimalPoint)
        case .op(let op):
            input(op.symbol, role: .continuation)
        case .leftParen:
            input("(", role: .leftParen)
        case .rightParen:
            input(")", role: .closer)
        case .percent:
            input("%", role: .continuation)
        case .backspace:
            backspace()
        case .clear:
            deleteOwn(count: sessionText.count)
            reset()
        case .equals:
            evaluate()
        case .newline:
            performOwnEdit { proxy.insertText("\n") }
            reset()
        }
    }

    public func reset() {
        expression = ""
        sessionText = ""
        phase = .editing
    }

    // MARK: - 外部變動偵測

    /// 由 KeyboardViewController 的 textDidChange 轉發。
    ///
    /// 只用「游標前的文字」輔助判斷：它若有內容，卻和 sessionText 對不上
    /// （兩者不是「其中一個是另一個的結尾」；系統可能把前面截斷），就視為被外部改動。
    /// nil 或空字串代表無法判斷，不重設（部分 App 永遠回傳 nil）。
    /// 已知限制：這類 App 偵測不到游標移動；context 更新有延遲的 App 可能誤重設。
    public func textDidChange() {
        guard !isPerformingOwnEdit, !sessionText.isEmpty else { return }
        guard let context = proxy.documentContextBeforeInput, !context.isEmpty else { return }
        if !(context.hasSuffix(sessionText) || sessionText.hasSuffix(context)) {
            reset()
        }
    }

    // MARK: - 輸入

    private func input(_ text: String, role: Role) {
        var base = expression
        var startsNewExpression = false

        if case .evaluated(let result) = phase {
            switch role {
            case .closer:
                return
            case .digit, .decimalPoint, .leftParen:
                base = ""
                startsNewExpression = true
            case .continuation:
                base = result   // 以上一次結果當第一個運算元
            }
        }

        guard base.count + text.count <= Self.maxExpressionLength else {
            fail(.expressionTooLong)
            return
        }
        switch role {
        case .digit:
            guard significantDigitCount(of: trailingNumber(in: base)) < Tokenizer.maxDigits else {
                fail(.numberTooLong)
                return
            }
        case .decimalPoint:
            guard !trailingNumber(in: base).contains(".") else { return }
        default:
            break
        }

        if startsNewExpression {
            sessionText = ""
            insert("\n")
        }
        phase = .editing
        expression = base
        insert(text)
        expression += text
    }

    private func backspace() {
        switch phase {
        case .evaluated(let result):
            // 撤銷計算：一次刪掉 "=結果"，保留原算式
            deleteOwn(count: 1 + result.count)
            phase = .editing
        case .editing:
            // 緩衝區是空的時也要轉發，否則使用者刪不掉輸入框裡原本的文字
            deleteOwn(count: 1)
            if !expression.isEmpty { expression.removeLast() }
        }
    }

    private func evaluate() {
        guard case .editing = phase, !expression.isEmpty else { return }
        do {
            let result = ResultFormatter.format(try Calculator.evaluate(expression))
            insert("=" + result)
            phase = .evaluated(result: result)
        } catch {
            fail(InputError(error))
        }
    }

    // MARK: - 對輸入框的操作（一律經過這裡，才能標記為自己造成的變動）

    private func insert(_ text: String) {
        performOwnEdit { proxy.insertText(text) }
        sessionText += text
    }

    private func deleteOwn(count: Int) {
        performOwnEdit {
            for _ in 0..<count { proxy.deleteBackward() }
        }
        sessionText.removeLast(min(count, sessionText.count))
    }

    private func performOwnEdit(_ body: () -> Void) {
        isPerformingOwnEdit = true
        defer { isPerformingOwnEdit = false }
        body()
    }

    // MARK: - 錯誤

    private func fail(_ error: InputError) {
        isShowingError = true
        onError?(error)
    }

    private func clearError() {
        guard isShowingError else { return }
        isShowingError = false
        onError?(nil)
    }

    // MARK: - 數字檢查

    /// 結尾連續的數字與小數點，例如 "12+3.5" → "3.5"
    private func trailingNumber(in text: String) -> Substring {
        var start = text.endIndex
        while start > text.startIndex {
            let previous = text.index(before: start)
            let c = text[previous]
            guard (c >= "0" && c <= "9") || c == "." else { break }
            start = previous
        }
        return text[start...]
    }

    /// 有效位數：不含小數點與前導 0，與 Tokenizer 的算法一致
    private func significantDigitCount(of number: Substring) -> Int {
        number.filter { $0 != "." }.drop(while: { $0 == "0" }).count
    }
}
