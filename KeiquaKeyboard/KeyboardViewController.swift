import UIKit
import KeiquaCore

// 目前仍是空白鍵盤（按鍵 UI 在步驟 2-4）。這裡先把 InputController 接上生命週期。
final class KeyboardViewController: UIInputViewController {

    private let globeButton = UIButton(type: .system)

    // 由 controller 擁有；SystemTextInputProxy 以 unowned 參照回來，不會循環參照。
    private lazy var inputController = InputController(
        proxy: SystemTextInputProxy(controller: self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.translatesAutoresizingMaskIntoConstraints = false
        // 系統提供的切換鍵盤行為：點一下切到下一個鍵盤，長按顯示鍵盤清單。
        globeButton.addTarget(
            self,
            action: #selector(handleInputModeList(from:with:)),
            for: .allTouchEvents
        )
        view.addSubview(globeButton)

        NSLayoutConstraint.activate([
            globeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            globeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            globeButton.widthAnchor.constraint(equalToConstant: 44),
            globeButton.heightAnchor.constraint(equalToConstant: 44),
            view.heightAnchor.constraint(equalToConstant: 260)
        ])
        updateGlobeButtonVisibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 鍵盤重新出現可能是換了輸入框，緩衝區不可沿用
        inputController.reset()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        inputController.textDidChange()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateGlobeButtonVisibility()
    }

    // 系統已提供地球鍵時（Face ID 機型）為 false，此時不需要自己畫。
    private func updateGlobeButtonVisibility() {
        globeButton.isHidden = !needsInputModeSwitchKey
    }
}
