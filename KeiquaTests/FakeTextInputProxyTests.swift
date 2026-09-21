import XCTest
@testable import KeiquaCore

/// 確認假物件本身的行為正確，之後 InputController 的測試才可信。
@MainActor
final class FakeTextInputProxyTests: XCTestCase {

    func testInsertAppendsText() {
        let proxy = FakeTextInputProxy()
        proxy.insertText("200")
        proxy.insertText("+")
        XCTAssertEqual(proxy.text, "200+")
    }

    func testInsertNewline() {
        let proxy = FakeTextInputProxy()
        proxy.insertText("1")
        proxy.insertText("\n")
        proxy.insertText("2")
        XCTAssertEqual(proxy.text, "1\n2")
    }

    func testDeleteBackwardRemovesLastCharacter() {
        let proxy = FakeTextInputProxy()
        proxy.insertText("12")
        proxy.deleteBackward()
        XCTAssertEqual(proxy.text, "1")
    }

    func testDeleteBackwardOnEmptyIsNoOp() {
        let proxy = FakeTextInputProxy()
        proxy.deleteBackward()
        XCTAssertEqual(proxy.text, "")
    }

    func testDeleteBackwardRemovesWholeEmoji() {
        let proxy = FakeTextInputProxy()
        proxy.insertText("1👨‍👩‍👧")
        proxy.deleteBackward()
        XCTAssertEqual(proxy.text, "1")
    }

    func testContextBeforeInputIsNilWhenEmpty() {
        let proxy = FakeTextInputProxy()
        XCTAssertNil(proxy.documentContextBeforeInput)
        proxy.insertText("5")
        XCTAssertEqual(proxy.documentContextBeforeInput, "5")
    }
}
