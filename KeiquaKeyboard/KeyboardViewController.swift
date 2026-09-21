import UIKit

// 階段 0：空白鍵盤，只有一顆地球鍵，用來驗證 extension 能被載入與切換。
final class KeyboardViewController: UIInputViewController {

    private let globeButton = UIButton(type: .system)

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

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateGlobeButtonVisibility()
    }

    // 系統已提供地球鍵時（Face ID 機型）為 false，此時不需要自己畫。
    private func updateGlobeButtonVisibility() {
        globeButton.isHidden = !needsInputModeSwitchKey
    }
}
