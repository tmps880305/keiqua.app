/// 鍵盤對輸入框的操作介面，包住 UIKit 的 UITextDocumentProxy。
///
/// InputController 只依賴這個 protocol，因此單元測試可以用假物件取代真正的輸入框。
/// Web 類比：把 `fetch` 包在一個 interface 後面，測試時換成 mock。
@MainActor
public protocol TextInputProxy: AnyObject {
    /// 游標前的文字。只能當輔助檢查：各 App 的行為不一致，可能是 nil 或被截斷。
    var documentContextBeforeInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
}
