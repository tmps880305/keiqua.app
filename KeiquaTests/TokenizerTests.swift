import XCTest
@testable import KeiquaCore

final class TokenizerTests: XCTestCase {

    /// 用字串建立 Decimal，避免 Double 字面值造成的精度誤差（例如 0.1）。
    private func dec(_ s: String) -> Decimal {
        Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))!
    }

    func testIntegers() throws {
        XCTAssertEqual(try Tokenizer.tokenize("200+300"), [.number(200), .plus, .number(300)])
    }

    func testDecimals() throws {
        XCTAssertEqual(try Tokenizer.tokenize("0.1+0.2"), [.number(dec("0.1")), .plus, .number(dec("0.2"))])
    }

    func testLeadingAndTrailingDot() throws {
        XCTAssertEqual(try Tokenizer.tokenize(".5"), [.number(dec("0.5"))])
        XCTAssertEqual(try Tokenizer.tokenize("5."), [.number(5)])
    }

    func testOperatorSymbols() throws {
        XCTAssertEqual(try Tokenizer.tokenize("−×÷"), [.minus, .multiply, .divide])
    }

    func testAsciiOperatorAliases() throws {
        XCTAssertEqual(try Tokenizer.tokenize("-*/"), [.minus, .multiply, .divide])
    }

    func testParenthesesAndPercent() throws {
        XCTAssertEqual(
            try Tokenizer.tokenize("(1+2)%"),
            [.leftParen, .number(1), .plus, .number(2), .rightParen, .percent]
        )
    }

    func testMinusIsAlwaysAMinusToken() throws {
        // 是負號還是減號由 Parser 決定
        XCTAssertEqual(try Tokenizer.tokenize("-5+3"), [.minus, .number(5), .plus, .number(3)])
    }

    func testWhitespaceIsIgnored() throws {
        XCTAssertEqual(try Tokenizer.tokenize(" 1 +\n2 "), [.number(1), .plus, .number(2)])
    }

    func testEmptyInput() throws {
        XCTAssertEqual(try Tokenizer.tokenize(""), [])
    }

    func testMultipleDotsThrows() {
        XCTAssertThrowsError(try Tokenizer.tokenize("1.2.3")) {
            XCTAssertEqual($0 as? CalculatorError, .malformedNumber)
        }
    }

    func testLoneDotThrows() {
        XCTAssertThrowsError(try Tokenizer.tokenize(".")) {
            XCTAssertEqual($0 as? CalculatorError, .malformedNumber)
        }
    }

    func testInvalidCharacterThrows() {
        XCTAssertThrowsError(try Tokenizer.tokenize("2a")) {
            XCTAssertEqual($0 as? CalculatorError, .invalidCharacter("a"))
        }
        // "=" 由 InputController 處理，不屬於算式內容
        XCTAssertThrowsError(try Tokenizer.tokenize("1+1=")) {
            XCTAssertEqual($0 as? CalculatorError, .invalidCharacter("="))
        }
    }

    func testSixteenDigitsAllowed() throws {
        XCTAssertEqual(
            try Tokenizer.tokenize("1234567890123456"),
            [.number(dec("1234567890123456"))]
        )
    }

    func testSeventeenDigitsThrows() {
        XCTAssertThrowsError(try Tokenizer.tokenize("12345678901234567")) {
            XCTAssertEqual($0 as? CalculatorError, .numberTooLong)
        }
    }

    func testLeadingZerosDoNotCountTowardLimit() throws {
        XCTAssertEqual(
            try Tokenizer.tokenize("0.0000000000000001"),
            [.number(dec("0.0000000000000001"))]
        )
    }
}
