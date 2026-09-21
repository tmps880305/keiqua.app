import KeiquaCore

/// 測試用的假輸入框：游標永遠在文字最後面。
/// 測試可以直接修改 `text` 來模擬使用者在外部改動內容。
@MainActor
final class FakeTextInputProxy: TextInputProxy {
    var text = ""

    /// 與真實行為一致：空的時候回傳 nil
    var documentContextBeforeInput: String? {
        text.isEmpty ? nil : text
    }

    func insertText(_ text: String) {
        self.text += text
    }

    /// 與 UIKit 一致：一次刪除一個字元（含 emoji 等組合字元）
    func deleteBackward() {
        if !text.isEmpty { text.removeLast() }
    }
}
