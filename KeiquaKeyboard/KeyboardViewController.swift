import UIKit
import KeiquaCore

final class KeyboardViewController: UIInputViewController {

    private enum Height {
        static let regular: CGFloat = 280
        static let compact: CGFloat = 216   // 橫向（垂直空間不足）
    }

    private let keyboardView = KeyboardView()
    private var heightConstraint: NSLayoutConstraint!

    // 由 controller 擁有；SystemTextInputProxy 以 unowned 參照回來，不會循環參照。
    private lazy var inputController = InputController(
        proxy: SystemTextInputProxy(controller: self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        // 優先權略低於 required，避免和系統一開始加的高度限制衝突
        heightConstraint = view.heightAnchor.constraint(equalToConstant: Height.regular)
        heightConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightConstraint,
        ])

        keyboardView.onKey = { [weak self] key in
            self?.inputController.handle(key)
            self?.refreshDebugInfo()
        }
        inputController.onError = { [weak self] error in
            self?.keyboardView.setError(error?.message)
        }
        // 系統提供的切換鍵盤行為：點一下切到下一個鍵盤，長按顯示鍵盤清單。
        keyboardView.globeButton.addTarget(
            self,
            action: #selector(handleInputModeList(from:with:)),
            for: .allTouchEvents
        )

        updateForCurrentEnvironment()
        refreshDebugInfo()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 鍵盤重新出現可能是換了輸入框，緩衝區不可沿用
        inputController.reset()
        refreshDebugInfo()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        inputController.textDidChange()
        refreshDebugInfo()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateForCurrentEnvironment()
    }

    private func updateForCurrentEnvironment() {
        // 系統已提供地球鍵時（Face ID 機型）為 false，此時不需要自己畫。
        keyboardView.globeButton.isHidden = !needsInputModeSwitchKey

        let height = traitCollection.verticalSizeClass == .compact ? Height.compact : Height.regular
        if heightConstraint.constant != height {
            heightConstraint.constant = height
        }
    }

    private func refreshDebugInfo() {
        #if DEBUG
        let phase: String
        switch inputController.phase {
        case .editing: phase = "編輯中"
        case .evaluated(let result): phase = "=\(result)"
        }
        keyboardView.setDebugText("expr: \(inputController.expression)  [\(phase)]")
        #endif
    }
}
