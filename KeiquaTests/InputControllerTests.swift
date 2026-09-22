import XCTest
@testable import KeiquaCore

/// 測試用的輪子：用字串描述按鍵順序，例如 press("200+300=")。
/// 按鍵對應：0-9 . + - × ÷ ( ) % = 、⌫ 退格、\n 換行
/// + - × ÷ = 在這裡仍用單一字元描述按鍵序列，InputController 內部會轉成前後加空白的插入文字。
@MainActor
private final class Harness {
    let proxy: FakeTextInputProxy
    let controller: InputController
    private(set) var events: [InputError?] = []

    var currentError: InputError? { events.last.flatMap { $0 } }

    init() {
        let proxy = FakeTextInputProxy()
        self.proxy = proxy
        self.controller = InputController(proxy: proxy)
        self.controller.onError = { [unowned self] error in self.events.append(error) }
    }

    /// 之後每次 insert／delete 都會同步觸發 textDidChange，模擬系統的同步回呼
    func enableSynchronousCallbacks() {
        proxy.onTextChange = { [unowned self] in self.controller.textDidChange() }
    }

    func press(_ keys: String) {
        for ch in keys {
            switch ch {
            case "0"..."9": controller.handle(.digit(ch.wholeNumberValue!))
            case ".": controller.handle(.decimalPoint)
            case "+": controller.handle(.op(.plus))
            case "-": controller.handle(.op(.minus))
            case "×": controller.handle(.op(.multiply))
            case "÷": controller.handle(.op(.divide))
            case "(": controller.handle(.leftParen)
            case ")": controller.handle(.rightParen)
            case "%": controller.handle(.percent)
            case "=": controller.handle(.equals)
            case "⌫": controller.handle(.backspace)
            case "\n": controller.handle(.newline)
            default: XCTFail("unknown key \(ch)")
            }
        }
    }
}

@MainActor
final class InputControllerTests: XCTestCase {

    // MARK: 基本輸入與空白

    func testTypingInsertsCharactersImmediately() {
        let h = Harness()
        h.press("200")
        XCTAssertEqual(h.proxy.text, "200")
        h.press("+")
        XCTAssertEqual(h.proxy.text, "200 + ")
        h.press("300")
        XCTAssertEqual(h.proxy.text, "200 + 300")
        XCTAssertEqual(h.controller.expression, "200 + 300")
    }

    func testParenthesesAndPercentHaveNoSurroundingSpace() {
        let h = Harness()
        h.press("(1+2)%")
        XCTAssertEqual(h.proxy.text, "(1 + 2)%")
    }

    func testEqualsInsertsSpacedResultWithTrailingSpace() {
        let h = Harness()
        h.press("200+300=")
        XCTAssertEqual(h.proxy.text, "200 + 300 = 500 ")
        XCTAssertEqual(h.controller.phase, .evaluated(result: "500"))
        XCTAssertEqual(h.controller.expression, "200 + 300")
    }

    func testResultsFromSpec() {
        let cases: [(String, String)] = [
            ("0.1+0.2=", "0.1 + 0.2 = 0.3 "),
            ("10÷4=", "10 ÷ 4 = 2.5 "),
            ("1÷3=", "1 ÷ 3 = 0.3333333333 "),
            ("-5+3=", " - 5 + 3 = -2 "),
            ("2+3×4=", "2 + 3 × 4 = 14 "),
            ("(2+3)×4=", "(2 + 3) × 4 = 20 "),
        ]
        for (keys, expected) in cases {
            let h = Harness()
            h.press(keys)
            XCTAssertEqual(h.proxy.text, expected, keys)
        }
    }

    func testEqualsOnEmptyBufferIsIgnored() {
        let h = Harness()
        h.press("=")
        XCTAssertEqual(h.proxy.text, "")
        XCTAssertNil(h.currentError)
    }

    func testEqualsOnSingleNumberStillInsertsResult() {
        let h = Harness()
        h.press("5=")
        XCTAssertEqual(h.proxy.text, "5 = 5 ")
    }

    func testEqualsTwiceDoesNotDuplicateResult() {
        let h = Harness()
        h.press("1+1==")
        XCTAssertEqual(h.proxy.text, "1 + 1 = 2 ")
    }

    // MARK: "=" 之後一律開新算式

    func testAnyKeyAfterEqualsStartsNewExpressionRightAfterTrailingSpace() {
        let h = Harness()
        h.press("200+300=7")
        XCTAssertEqual(h.proxy.text, "200 + 300 = 500 7")
        XCTAssertEqual(h.controller.expression, "7")
        XCTAssertEqual(h.controller.phase, .editing)
        h.press("+1=")
        XCTAssertEqual(h.proxy.text, "200 + 300 = 500 7 + 1 = 8 ")
    }

    func testOperatorAfterEqualsStartsNewExpressionRatherThanContinuing() {
        let h = Harness()
        h.press("200+300=+")
        XCTAssertEqual(h.proxy.text, "200 + 300 = 500  + ")
        XCTAssertEqual(h.controller.expression, " + ")
        // 以運算符開頭不是合法算式，交給 "=" 報格式錯誤
        h.press("=")
        XCTAssertEqual(h.currentError, .syntax)
    }

    func testLeftParenAndDecimalPointAfterEqualsStartNewExpression() {
        let h1 = Harness()
        h1.press("1+1=(")
        XCTAssertEqual(h1.proxy.text, "1 + 1 = 2 (")
        XCTAssertEqual(h1.controller.expression, "(")

        let h2 = Harness()
        h2.press("1+1=.")
        XCTAssertEqual(h2.proxy.text, "1 + 1 = 2 .")
        XCTAssertEqual(h2.controller.expression, ".")
    }

    func testRightParenAfterEqualsStartsNewExpressionAndErrorsOnEquals() {
        let h = Harness()
        h.press("1+1=)")
        XCTAssertEqual(h.proxy.text, "1 + 1 = 2 )")
        XCTAssertEqual(h.controller.expression, ")")
        h.press("=")
        XCTAssertEqual(h.currentError, .syntax)
    }

    // MARK: 錯誤

    func testDivisionByZeroInsertsNoResultAndShowsError() {
        let h = Harness()
        h.press("1÷0=")
        XCTAssertEqual(h.proxy.text, "1 ÷ 0")
        XCTAssertEqual(h.currentError, .divisionByZero)
        XCTAssertEqual(h.controller.phase, .editing)
    }

    func testErrorIsClearedOnNextKeyPress() {
        let h = Harness()
        h.press("1÷0=")
        XCTAssertEqual(h.events, [.divisionByZero])
        h.press("5")
        XCTAssertEqual(h.events, [.divisionByZero, nil])
        XCTAssertNil(h.currentError)
    }

    func testSyntaxErrors() {
        for keys in ["1+=", "(1+2=", "1+2)=", "()=", "2(3)="] {
            let h = Harness()
            h.press(String(keys.dropLast()))
            let before = h.proxy.text
            h.press("=")
            XCTAssertEqual(h.proxy.text, before, keys)
            XCTAssertEqual(h.currentError, .syntax, keys)
        }
    }

    func testOverflowShowsError() {
        let h = Harness()
        h.press(Array(repeating: "9999999999999999", count: 11).joined(separator: "×"))
        let before = h.proxy.text
        h.press("=")
        XCTAssertEqual(h.proxy.text, before)
        XCTAssertEqual(h.currentError, .overflow)
    }

    // MARK: 退格

    func testBackspaceThenRecalculate() {
        let h = Harness()
        h.press("12+34⌫")
        XCTAssertEqual(h.proxy.text, "12 + 3")
        XCTAssertEqual(h.controller.expression, "12 + 3")
        h.press("5=")
        XCTAssertEqual(h.proxy.text, "12 + 35 = 47 ")
    }

    func testBackspaceAfterEqualsUndoesTheWholeSpacedResult() {
        let h = Harness()
        h.press("200+300=⌫")
        XCTAssertEqual(h.proxy.text, "200 + 300")
        XCTAssertEqual(h.controller.phase, .editing)
        XCTAssertEqual(h.controller.expression, "200 + 300")
        h.press("=")
        XCTAssertEqual(h.proxy.text, "200 + 300 = 500 ")
        h.press("⌫⌫")
        XCTAssertEqual(h.proxy.text, "200 + 30")
        XCTAssertEqual(h.controller.expression, "200 + 30")
    }

    func testBackspaceOnEmptyBufferStillDeletesExistingText() {
        let h = Harness()
        h.proxy.text = "Hello"
        h.controller.handle(.backspace)
        XCTAssertEqual(h.proxy.text, "Hell")
        XCTAssertEqual(h.controller.expression, "")
    }

    func testBackspaceDoesNotTouchBufferBelowZero() {
        let h = Harness()
        h.proxy.text = "Hi "
        h.press("1+2⌫⌫⌫")
        XCTAssertEqual(h.proxy.text, "Hi ")
        XCTAssertEqual(h.controller.expression, "")
        h.press("⌫")
        XCTAssertEqual(h.proxy.text, "Hi")
    }

    func testBackspaceCharByCharThroughAnOperatorBlock() {
        let h = Harness()
        h.press("1+")
        XCTAssertEqual(h.proxy.text, "1 + ")
        h.press("⌫")
        XCTAssertEqual(h.proxy.text, "1 +")
        h.press("⌫")
        XCTAssertEqual(h.proxy.text, "1 ")
        h.press("⌫")
        XCTAssertEqual(h.proxy.text, "1")
        XCTAssertEqual(h.controller.expression, "1")
    }

    func testBackspaceAfterNewExpressionFollowingEquals() {
        let h = Harness()
        h.press("1+1=5⌫")
        // 刪掉新算式打的 "5"，正好回到舊結果尾端的空白，不會多刪或少刪
        XCTAssertEqual(h.proxy.text, "1 + 1 = 2 ")
        XCTAssertEqual(h.controller.expression, "")
        XCTAssertEqual(h.controller.phase, .editing)
        // 此時 "= 2 " 已經是單純殘留文字（phase 不再是 evaluated），繼續退格只能一個字元一個字元刪
        h.press("⌫⌫")
        XCTAssertEqual(h.proxy.text, "1 + 1 = ")
    }

    // MARK: 沒有清除鍵：靠退格慢慢刪

    func testNoClearKeyBackspaceRemovesEverythingGradually() {
        let h = Harness()
        h.proxy.text = "Hi "
        h.press("1+2")
        for _ in 0..<h.proxy.text.count - 3 { h.press("⌫") }
        XCTAssertEqual(h.proxy.text, "Hi ")
        XCTAssertEqual(h.controller.expression, "")
    }

    // MARK: 換行

    func testNewlineInsertsLineBreakAndResetsBuffer() {
        let h = Harness()
        h.press("12\n")
        XCTAssertEqual(h.proxy.text, "12\n")
        XCTAssertEqual(h.controller.expression, "")
        XCTAssertEqual(h.controller.sessionText, "")
        h.press("3=")
        XCTAssertEqual(h.proxy.text, "12\n3 = 3 ")
    }

    // MARK: 數字規則

    func testSecondDecimalPointInSameNumberIsIgnored() {
        let h = Harness()
        h.press("1.2.3")
        XCTAssertEqual(h.proxy.text, "1.23")
        XCTAssertEqual(h.controller.expression, "1.23")
        XCTAssertNil(h.currentError)
    }

    func testDecimalPointAllowedInEachNumber() {
        let h = Harness()
        h.press(".5+.5=")
        XCTAssertEqual(h.proxy.text, ".5 + .5 = 1 ")
    }

    func testSeventeenthSignificantDigitIsRejected() {
        let h = Harness()
        h.press("1234567890123456")
        h.press("7")
        XCTAssertEqual(h.proxy.text, "1234567890123456")
        XCTAssertEqual(h.currentError, .numberTooLong)
        // 運算符之後可以開始新的數字
        h.press("+7")
        XCTAssertEqual(h.proxy.text, "1234567890123456 + 7")
        XCTAssertNil(h.currentError)
    }

    func testLeadingZerosDoNotCountTowardDigitLimit() {
        let h = Harness()
        h.press("0.0000000000000001")
        XCTAssertEqual(h.proxy.text, "0.0000000000000001")
        XCTAssertNil(h.currentError)
    }

    func testExpressionLengthIsCapped() {
        let h = Harness()
        h.press(String(repeating: "1+", count: 60))
        let cappedLength = h.controller.expression.count
        XCTAssertLessThanOrEqual(cappedLength, InputController.maxExpressionLength)
        h.press("1")
        XCTAssertEqual(h.controller.expression.count, cappedLength)
        XCTAssertEqual(h.currentError, .expressionTooLong)
    }

    func testOutOfRangeDigitIsIgnored() {
        let h = Harness()
        h.controller.handle(.digit(10))
        XCTAssertEqual(h.proxy.text, "")
    }

    // MARK: 外部變動偵測

    func testOwnEditsDoNotResetWhenCallbackIsSynchronous() {
        let h = Harness()
        h.enableSynchronousCallbacks()
        h.press("200+300=")
        XCTAssertEqual(h.proxy.text, "200 + 300 = 500 ")
        XCTAssertEqual(h.controller.expression, "200 + 300")
        XCTAssertEqual(h.controller.phase, .evaluated(result: "500"))
    }

    func testTextDidChangeKeepsStateWhenContextMatches() {
        let h = Harness()
        h.press("200+300")
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "200 + 300")
    }

    func testExternalEditResetsBuffer() {
        let h = Harness()
        h.press("200+")
        h.proxy.text = "hello"   // 使用者移動游標或貼上內容
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "")
        XCTAssertEqual(h.controller.sessionText, "")
        XCTAssertEqual(h.controller.phase, .editing)
    }

    func testExternalEditAfterEqualsResetsPhase() {
        let h = Harness()
        h.press("1+1=")
        h.proxy.text = "other"
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.phase, .editing)
        h.press("+")
        XCTAssertEqual(h.controller.expression, " + ")
    }

    func testNilContextIsTreatedAsUnknown() {
        let h = Harness()
        h.press("200+")
        h.proxy.text = ""   // documentContextBeforeInput 為 nil
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "200 + ")
    }

    func testTruncatedContextIsTolerated() {
        let h = Harness()
        h.press("200+300")
        h.proxy.text = "300"   // 系統只給了游標前的一小段
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "200 + 300")
    }

    func testExistingTextBeforeSessionIsTolerated() {
        let h = Harness()
        h.proxy.text = "Total: "
        h.press("1+2")
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "1 + 2")
    }

    /// 游標被移到算式中間（而非文字尾端）視為外部變動，屬於已知限制
    func testCursorMovedIntoMiddleOfExpressionIsTreatedAsExternalChange() {
        let h = Harness()
        h.press("200+300=")
        // 模擬游標被移到 "3" 和 "00" 之間，游標前文字變成 "200 + 3"
        h.proxy.text = "200 + 3"
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "")
        XCTAssertEqual(h.controller.phase, .editing)
    }

    func testResetClearsEverything() {
        let h = Harness()
        h.press("1+1=")
        h.controller.reset()
        XCTAssertEqual(h.controller.expression, "")
        XCTAssertEqual(h.controller.sessionText, "")
        XCTAssertEqual(h.controller.phase, .editing)
    }
}
