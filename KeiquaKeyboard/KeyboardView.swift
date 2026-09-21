import UIKit
import KeiquaCore

/// 鍵盤畫面：上方一條窄的頂部列（地球鍵、提示文字、C、↵），下方 5 列 × 4 欄的計算機按鍵。
/// 純程式碼排版，只用 UIStackView 與 UIButton，視圖階層很淺。
final class KeyboardView: UIView {

    /// 按鍵一按下（touch down）就送出，連續輸入時比較不會漏鍵
    var onKey: ((KeyboardKey) -> Void)?

    /// 由 KeyboardViewController 設定切換鍵盤的動作，並決定是否顯示
    let globeButton = UIButton(type: .system)

    private let messageLabel = UILabel()
    private var errorText: String?
    private var debugText = ""

    private enum Metrics {
        static let sideInset: CGFloat = 8
        static let verticalInset: CGFloat = 6
        static let spacing: CGFloat = 8
        static let topBarHeight: CGFloat = 30
        static let topBarSpacing: CGFloat = 6
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 顯示

    /// 顯示錯誤提示；傳入 nil 代表清除
    func setError(_ message: String?) {
        errorText = message
        updateMessage()
    }

    #if DEBUG
    /// 只在 DEBUG 建置顯示目前的算式與狀態，方便在實機驗證外部變動偵測
    func setDebugText(_ text: String) {
        debugText = text
        updateMessage()
    }
    #endif

    private func updateMessage() {
        if let errorText {
            messageLabel.text = errorText
            messageLabel.textColor = .systemRed
            messageLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        } else {
            messageLabel.text = debugText
            messageLabel.textColor = .secondaryLabel
            messageLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        }
    }

    // MARK: - 建立畫面

    private func build() {
        let root = UIStackView(arrangedSubviews: [makeTopBar(), makeGrid()])
        root.axis = .vertical
        root.spacing = Metrics.topBarSpacing
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.verticalInset),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Metrics.verticalInset),
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.sideInset),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.sideInset),
        ])
    }

    private func makeTopBar() -> UIView {
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.tintColor = .secondaryLabel
        globeButton.accessibilityLabel = "切換鍵盤"

        messageLabel.numberOfLines = 1
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.7
        messageLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        updateMessage()

        let clear = makeKey(.clear, style: .function, title: "C", fontSize: 15, accessibilityLabel: "清除")
        let newline = makeKey(.newline, style: .function, symbol: "return", fontSize: 15, accessibilityLabel: "換行")

        let bar = UIStackView(arrangedSubviews: [globeButton, messageLabel, clear, newline])
        bar.axis = .horizontal
        bar.alignment = .fill
        bar.spacing = Metrics.spacing

        NSLayoutConstraint.activate([
            bar.heightAnchor.constraint(equalToConstant: Metrics.topBarHeight),
            globeButton.widthAnchor.constraint(equalToConstant: Metrics.topBarHeight),
            clear.widthAnchor.constraint(equalToConstant: 56),
            newline.widthAnchor.constraint(equalToConstant: 56),
        ])
        return bar
    }

    private func makeGrid() -> UIView {
        let rows: [[KeyButton]] = [
            [
                makeKey(.backspace, style: .function, symbol: "delete.left", accessibilityLabel: "退格"),
                makeKey(.leftParen, style: .function, title: "(", accessibilityLabel: "左括號"),
                makeKey(.rightParen, style: .function, title: ")", accessibilityLabel: "右括號"),
                makeKey(.op(.divide), style: .op, title: "÷", fontSize: 30, accessibilityLabel: "除"),
            ],
            [
                makeDigit(7), makeDigit(8), makeDigit(9),
                makeKey(.op(.multiply), style: .op, title: "×", fontSize: 30, accessibilityLabel: "乘"),
            ],
            [
                makeDigit(4), makeDigit(5), makeDigit(6),
                makeKey(.op(.minus), style: .op, title: "−", fontSize: 30, accessibilityLabel: "減"),
            ],
            [
                makeDigit(1), makeDigit(2), makeDigit(3),
                makeKey(.op(.plus), style: .op, title: "+", fontSize: 30, accessibilityLabel: "加"),
            ],
            [
                makeKey(.percent, style: .function, title: "%", accessibilityLabel: "百分比"),
                makeDigit(0),
                makeKey(.decimalPoint, style: .digit, title: ".", accessibilityLabel: "小數點"),
                makeKey(.equals, style: .op, title: "=", fontSize: 30, accessibilityLabel: "等於"),
            ],
        ]

        let rowViews = rows.map { buttons -> UIStackView in
            let row = UIStackView(arrangedSubviews: buttons)
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = Metrics.spacing
            return row
        }
        let grid = UIStackView(arrangedSubviews: rowViews)
        grid.axis = .vertical
        grid.distribution = .fillEqually
        grid.spacing = Metrics.spacing
        return grid
    }

    private func makeDigit(_ n: Int) -> KeyButton {
        makeKey(.digit(n), style: .digit, title: String(n))
    }

    private func makeKey(
        _ key: KeyboardKey,
        style: KeyButton.Style,
        title: String? = nil,
        symbol: String? = nil,
        fontSize: CGFloat = 24,
        accessibilityLabel: String? = nil
    ) -> KeyButton {
        let button = KeyButton(
            style: style,
            title: title,
            symbol: symbol,
            fontSize: fontSize,
            accessibilityLabel: accessibilityLabel
        )
        button.addAction(UIAction { [weak self] _ in self?.onKey?(key) }, for: .touchDown)
        return button
    }
}
