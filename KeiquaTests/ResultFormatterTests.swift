import XCTest
@testable import KeiquaCore

final class ResultFormatterTests: XCTestCase {

    private func dec(_ s: String) -> Decimal {
        Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func fmt(_ s: String) -> String {
        ResultFormatter.format(dec(s))
    }

    /// 走完整流程：算式 → Calculator → ResultFormatter
    private func result(_ expr: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        do {
            return ResultFormatter.format(try Calculator.evaluate(expr))
        } catch {
            XCTFail("\(expr) threw \(error)", file: file, line: line)
            return ""
        }
    }

    // MARK: 基本

    func testIntegers() {
        XCTAssertEqual(fmt("0"), "0")
        XCTAssertEqual(fmt("500"), "500")
        XCTAssertEqual(fmt("-5"), "-5")
    }

    func testDecimals() {
        XCTAssertEqual(fmt("2.5"), "2.5")
        XCTAssertEqual(fmt("-0.75"), "-0.75")
    }

    func testTrailingZerosAreRemovedOnlyAfterDecimalPoint() {
        XCTAssertEqual(fmt("5.0"), "5")
        XCTAssertEqual(fmt("10.50"), "10.5")
        XCTAssertEqual(fmt("100"), "100")
        XCTAssertEqual(fmt("100.00"), "100")
    }

    func testNoThousandsSeparator() {
        XCTAssertEqual(fmt("1234567.891"), "1234567.891")
    }

    // MARK: 小數位數與四捨五入

    func testTenFractionDigitsAreKept() {
        XCTAssertEqual(fmt("0.1234567891"), "0.1234567891")
        XCTAssertEqual(fmt("0.1234567890"), "0.123456789")
    }

    func testRoundsHalfAwayFromZeroAtTenthDigit() {
        XCTAssertEqual(fmt("0.00000000005"), "0.0000000001")
        XCTAssertEqual(fmt("0.00000000004"), "0")
        XCTAssertEqual(fmt("-0.00000000005"), "-0.0000000001")
    }

    func testRoundingCanCarryIntoIntegerPart() {
        XCTAssertEqual(fmt("0.99999999999"), "1")
        XCTAssertEqual(fmt("2.99999999996"), "3")
    }

    func testTinyValuesBecomeZeroWithoutNegativeSign() {
        XCTAssertEqual(fmt("0.00000000001"), "0")
        XCTAssertEqual(fmt("-0.00000000001"), "0")
    }

    // MARK: 超長數字

    func testLargeNumbersAreNotAbbreviated() {
        XCTAssertEqual(fmt("10000000000000000"), "10000000000000000")
        XCTAssertEqual(
            result("9999999999999999×9999999999999999"),
            "99999999999999980000000000000001"
        )
    }

    // MARK: 與 Calculator 串起來

    func testEndToEnd() {
        XCTAssertEqual(result("200+300"), "500")
        XCTAssertEqual(result("0.1+0.2"), "0.3")
        XCTAssertEqual(result("10÷4"), "2.5")
        XCTAssertEqual(result("1÷3"), "0.3333333333")
        XCTAssertEqual(result("2÷3"), "0.6666666667")
        XCTAssertEqual(result("-5+3"), "-2")
        XCTAssertEqual(result("2+3×4"), "14")
        XCTAssertEqual(result("5.5+4.5"), "10")
        XCTAssertEqual(result("50%"), "0.5")
    }
}
