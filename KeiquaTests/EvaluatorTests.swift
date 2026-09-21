import XCTest
@testable import KeiquaCore

final class EvaluatorTests: XCTestCase {

    private func dec(_ s: String) -> Decimal {
        Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func assertEvaluates(_ expr: String, _ expected: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        do {
            XCTAssertEqual(try Calculator.evaluate(expr), dec(expected), expr, file: file, line: line)
        } catch {
            XCTFail("\(expr) threw \(error)", file: file, line: line)
        }
    }

    private func assertThrows(_ expr: String, _ expected: CalculatorError,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try Calculator.evaluate(expr), expr, file: file, line: line) {
            XCTAssertEqual($0 as? CalculatorError, expected, expr, file: file, line: line)
        }
    }

    // MARK: 基本運算

    func testBasicArithmetic() {
        assertEvaluates("200+300", "500")
        assertEvaluates("0.1+0.2", "0.3")   // Decimal 不會有 0.30000000000000004
        assertEvaluates("10÷4", "2.5")
        assertEvaluates("7−10", "-3")
        assertEvaluates("6×7", "42")
    }

    func testDivisionPrecision() throws {
        // 1÷3 保留 Decimal 的完整精度，四捨五入到 10 位由 ResultFormatter 負責
        let result = try Calculator.evaluate("1÷3")
        XCTAssertTrue("\(result)".hasPrefix("0.3333333333"), "\(result)")
    }

    // MARK: 優先順序與結合性

    func testPrecedence() {
        assertEvaluates("2+3×4", "14")
        assertEvaluates("2×3+4", "10")
        assertEvaluates("10−6÷2", "7")
    }

    func testLeftAssociativity() {
        assertEvaluates("10−2−3", "5")
        assertEvaluates("100÷10÷2", "5")
    }

    func testParentheses() {
        assertEvaluates("(2+3)×4", "20")
        assertEvaluates("(1+2)×(3+4)", "21")
        assertEvaluates("((2+3))", "5")
        assertEvaluates("2×(3+(4−1))", "12")
    }

    // MARK: 負號

    func testUnaryMinus() {
        assertEvaluates("-5+3", "-2")
        assertEvaluates("2×-3", "-6")
        assertEvaluates("2−−3", "5")
        assertEvaluates("-(2+3)", "-5")
        assertEvaluates("--5", "5")
    }

    func testNegativeZeroIsNormalized() throws {
        let result = try Calculator.evaluate("0×-1")
        XCTAssertFalse(result.isSignMinus)
    }

    // MARK: 百分比（x% = x/100）

    func testPercent() {
        assertEvaluates("50%", "0.5")
        assertEvaluates("200×10%", "20")
        assertEvaluates("(1+2)%", "0.03")
        assertEvaluates("50%%", "0.005")
        assertEvaluates("-50%", "-0.5")
    }

    // MARK: 錯誤

    func testDivisionByZero() {
        assertThrows("1÷0", .divisionByZero)
        assertThrows("1÷(2−2)", .divisionByZero)
        assertThrows("0÷0", .divisionByZero)
    }

    func testSyntaxErrors() {
        assertThrows("", .syntax)
        assertThrows("-", .syntax)
        assertThrows("1+", .syntax)
        assertThrows("×2", .syntax)
        assertThrows("++1", .syntax)
        assertThrows("1++2", .syntax)
        assertThrows("(1+2", .syntax)
        assertThrows("1+2)", .syntax)
        assertThrows("()", .syntax)
        assertThrows("2(3)", .syntax)
        assertThrows("1 2", .syntax)
        assertThrows("%", .syntax)
    }

    func testTokenizerErrorsPropagate() {
        assertThrows("2a", .invalidCharacter("a"))
        assertThrows("1.2.3", .malformedNumber)
    }

    // MARK: 超長數字

    func testSixteenDigitNumbers() {
        assertEvaluates("9999999999999999+1", "10000000000000000")
        assertEvaluates("9999999999999999×9999999999999999", "99999999999999980000000000000001")
    }

    func testSeventeenDigitNumberThrows() {
        assertThrows("12345678901234567+1", .numberTooLong)
    }

    func testOverflowThrows() {
        // 11 個 16 位數相乘約 1e176，超出 Decimal 的指數範圍
        let expr = Array(repeating: "9999999999999999", count: 11).joined(separator: "×")
        assertThrows(expr, .overflow)
    }
}
