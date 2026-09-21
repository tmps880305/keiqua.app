import XCTest
@testable import KeiquaCore

// 占位測試，讓測試 target 有內容。階段 1 起換成解析器與格式化的測試。
final class KeiquaCoreTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(KeiquaCore.version.isEmpty)
    }
}
