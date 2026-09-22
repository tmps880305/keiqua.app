import UIKit
import KeiquaCore

/// TextInputProxy 的正式實作，轉呼叫 UIInputViewController 的 textDocumentProxy。
/// 每次都從 controller 取得 textDocumentProxy，不自行保存，避免系統替換 proxy 後拿到舊物件。
@MainActor
final class SystemTextInputProxy: TextInputProxy {
    private unowned let controller: UIInputViewController

    init(controller: UIInputViewController) {
        self.controller = controller
    }

    var documentContextBeforeInput: String? {
        controller.textDocumentProxy.documentContextBeforeInput
    }

    func insertText(_ text: String) {
        controller.textDocumentProxy.insertText(text)
    }

    func deleteBackward() {
        controller.textDocumentProxy.deleteBackward()
    }
}
