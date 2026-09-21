import XCTest
@testable import KeiquaCore

/// 測試用的輪子：用字串描述按鍵順序，例如 press("200+300=")。
/// 按鍵對應：0-9 . + - × ÷ ( ) % = 、⌫ 退格、C 清除、\n 換行
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
            case "C": controller.handle(.clear)
            case "\n": controller.handle(.newline)
            default: XCTFail("unknown key \(ch)")
            }
        }
    }
}

@MainActor
final class InputControllerTests: XCTestCase {

    // MARK: 基本輸入與 "="

    func testTypingInsertsCharactersImmediately() {
        let h = Harness()
        h.press("200")
        XCTAssertEqual(h.proxy.text, "200")
        h.press("+")
        XCTAssertEqual(h.proxy.text, "200+")
        h.press("300")
        XCTAssertEqual(h.proxy.text, "200+300")
        XCTAssertEqual(h.controller.expression, "200+300")
    }

    func testEqualsInsertsResult() {
        let h = Harness()
        h.press("200+300=")
        XCTAssertEqual(h.proxy.text, "200+300=500")
        XCTAssertEqual(h.controller.phase, .evaluated(result: "500"))
        XCTAssertEqual(h.controller.expression, "200+300")
    }

    func testResultsFromSpec() {
        let cases: [(String, String)] = [
            ("0.1+0.2=", "0.1+0.2=0.3"),
            ("10÷4=", "10÷4=2.5"),
            ("1÷3=", "1÷3=0.3333333333"),
            ("-5+3=", "-5+3=-2"),
            ("2+3×4=", "2+3×4=14"),
            ("(2+3)×4=", "(2+3)×4=20"),
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
        XCTAssertEqual(h.proxy.text, "5=5")
    }

    func testEqualsTwiceDoesNotDuplicateResult() {
        let h = Harness()
        h.press("1+1==")
        XCTAssertEqual(h.proxy.text, "1+1=2")
    }

    // MARK: "=" 之後

    func testOperatorAfterEqualsContinuesFromResult() {
        let h = Harness()
        h.press("200+300=+")
        XCTAssertEqual(h.proxy.text, "200+300=500+")
        XCTAssertEqual(h.controller.expression, "500+")
        h.press("100=")
        XCTAssertEqual(h.proxy.text, "200+300=500+100=600")
    }

    func testPercentAfterEqualsContinuesFromResult() {
        let h = Harness()
        h.press("50=%")
        XCTAssertEqual(h.proxy.text, "50=50%")
        h.press("=")
        XCTAssertEqual(h.proxy.text, "50=50%=0.5")
    }

    func testDigitAfterEqualsStartsNewExpressionOnNewLine() {
        let h = Harness()
        h.press("200+300=7")
        XCTAssertEqual(h.proxy.text, "200+300=500\n7")
        XCTAssertEqual(h.controller.expression, "7")
        XCTAssertEqual(h.controller.sessionText, "\n7")
        XCTAssertEqual(h.controller.phase, .editing)
        h.press("+1=")
        XCTAssertEqual(h.proxy.text, "200+300=500\n7+1=8")
    }

    func testLeftParenAndDecimalPointAfterEqualsStartNewExpression() {
        let h1 = Harness()
        h1.press("1+1=(")
        XCTAssertEqual(h1.proxy.text, "1+1=2\n(")
        XCTAssertEqual(h1.controller.expression, "(")

        let h2 = Harness()
        h2.press("1+1=.")
        XCTAssertEqual(h2.proxy.text, "1+1=2\n.")
        XCTAssertEqual(h2.controller.expression, ".")
    }

    func testRightParenAfterEqualsIsIgnored() {
        let h = Harness()
        h.press("1+1=)")
        XCTAssertEqual(h.proxy.text, "1+1=2")
        XCTAssertEqual(h.controller.phase, .evaluated(result: "2"))
    }

    // MARK: 錯誤

    func testDivisionByZeroInsertsNoResultAndShowsError() {
        let h = Harness()
        h.press("1÷0=")
        XCTAssertEqual(h.proxy.text, "1÷0")
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
            h.press(keys.replacingOccurrences(of: "=", with: ""))
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
        XCTAssertEqual(h.proxy.text, "12+3")
        XCTAssertEqual(h.controller.expression, "12+3")
        h.press("5=")
        XCTAssertEqual(h.proxy.text, "12+35=47")
    }

    func testBackspaceAfterEqualsUndoesTheWholeResult() {
        let h = Harness()
        h.press("200+300=⌫")
        XCTAssertEqual(h.proxy.text, "200+300")
        XCTAssertEqual(h.controller.phase, .editing)
        XCTAssertEqual(h.controller.expression, "200+300")
        h.press("=")
        XCTAssertEqual(h.proxy.text, "200+300=500")
        h.press("⌫⌫")
        XCTAssertEqual(h.proxy.text, "200+30")
        XCTAssertEqual(h.controller.expression, "200+30")
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

    func testBackspaceAfterNewExpressionThenNewline() {
        let h = Harness()
        h.press("1+1=5⌫")
        XCTAssertEqual(h.proxy.text, "1+1=2\n")
        XCTAssertEqual(h.controller.expression, "")
        h.press("⌫")
        XCTAssertEqual(h.proxy.text, "1+1=2")
    }

    // MARK: 清除

    func testClearRemovesOnlyTextInsertedThisSession() {
        let h = Harness()
        h.proxy.text = "Hi "
        h.press("1+2C")
        XCTAssertEqual(h.proxy.text, "Hi ")
        XCTAssertEqual(h.controller.expression, "")
        XCTAssertEqual(h.controller.sessionText, "")
    }

    func testClearAfterEqualsRemovesResultToo() {
        let h = Harness()
        h.proxy.text = "Hi "
        h.press("1+2=C")
        XCTAssertEqual(h.proxy.text, "Hi ")
        XCTAssertEqual(h.controller.phase, .editing)
    }

    func testClearAfterNewExpressionKeepsPreviousLine() {
        let h = Harness()
        h.press("1+1=5C")
        XCTAssertEqual(h.proxy.text, "1+1=2")
    }

    func testClearAfterContinuationRemovesWholeSession() {
        let h = Harness()
        h.press("1+1=+3C")
        XCTAssertEqual(h.proxy.text, "")
    }

    // MARK: 換行

    func testNewlineInsertsLineBreakAndResetsBuffer() {
        let h = Harness()
        h.press("12\n")
        XCTAssertEqual(h.proxy.text, "12\n")
        XCTAssertEqual(h.controller.expression, "")
        XCTAssertEqual(h.controller.sessionText, "")
        h.press("3=")
        XCTAssertEqual(h.proxy.text, "12\n3=3")
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
        XCTAssertEqual(h.proxy.text, ".5+.5=1")
    }

    func testSeventeenthSignificantDigitIsRejected() {
        let h = Harness()
        h.press("1234567890123456")
        h.press("7")
        XCTAssertEqual(h.proxy.text, "1234567890123456")
        XCTAssertEqual(h.currentError, .numberTooLong)
        // 運算符之後可以開始新的數字
        h.press("+7")
        XCTAssertEqual(h.proxy.text, "1234567890123456+7")
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
        h.press(String(repeating: "1+", count: 100))
        XCTAssertEqual(h.controller.expression.count, InputController.maxExpressionLength)
        h.press("1")
        XCTAssertEqual(h.controller.expression.count, InputController.maxExpressionLength)
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
        XCTAssertEqual(h.proxy.text, "200+300=500")
        XCTAssertEqual(h.controller.expression, "200+300")
        XCTAssertEqual(h.controller.phase, .evaluated(result: "500"))
    }

    func testTextDidChangeKeepsStateWhenContextMatches() {
        let h = Harness()
        h.press("200+300")
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "200+300")
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
        // 之後按運算符不會再沿用舊結果
        h.press("+")
        XCTAssertEqual(h.controller.expression, "+")
    }

    func testNilContextIsTreatedAsUnknown() {
        let h = Harness()
        h.press("200+")
        h.proxy.text = ""   // documentContextBeforeInput 為 nil
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "200+")
    }

    func testTruncatedContextIsTolerated() {
        let h = Harness()
        h.press("200+300")
        h.proxy.text = "+300"   // 系統只給了游標前的一小段
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "200+300")
    }

    func testExistingTextBeforeSessionIsTolerated() {
        let h = Harness()
        h.proxy.text = "Total: "
        h.press("1+2")
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "1+2")
    }

    func testParagraphLimitedContextAfterNewLineIsTolerated() {
        let h = Harness()
        h.press("1+1=5")
        h.proxy.text = "5"   // 部分 App 的 context 只到目前這一段
        h.controller.textDidChange()
        XCTAssertEqual(h.controller.expression, "5")
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
