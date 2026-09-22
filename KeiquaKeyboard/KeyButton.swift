import UIKit

/// 膠囊形按鍵。樣式比照 iPhone 內建計算機：數字深灰、功能鍵淺灰、運算符橘色。
final class KeyButton: UIButton {

    enum Style {
        case digit
        case function
        case op

        var background: UIColor {
            switch self {
            case .digit: return .dynamic(light: 0xFFFFFF, dark: 0x333333)
            case .function: return .dynamic(light: 0xAEB3BE, dark: 0x5C5C5E)
            case .op: return .dynamic(light: 0xF09A37, dark: 0xF09A37)
            }
        }

        var foreground: UIColor {
            switch self {
            case .digit, .function: return .label
            case .op: return .white
            }
        }
    }

    init(
        style: Style,
        title: String? = nil,
        symbol: String? = nil,
        fontSize: CGFloat = 24,
        accessibilityLabel: String? = nil
    ) {
        super.init(frame: .zero)
        backgroundColor = style.background
        setTitleColor(style.foreground, for: .normal)
        tintColor = style.foreground
        layer.cornerCurve = .continuous

        if let title {
            setTitle(title, for: .normal)
            titleLabel?.font = .systemFont(ofSize: fontSize, weight: .regular)
        }
        if let symbol {
            let config = UIImage.SymbolConfiguration(pointSize: fontSize * 0.75, weight: .regular)
            setImage(UIImage(systemName: symbol, withConfiguration: config), for: .normal)
        }
        self.accessibilityLabel = accessibilityLabel ?? title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    /// 按下時變淡，取代系統預設的高亮效果
    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.55 : 1 }
    }
}

extension UIColor {
    /// 依淺色／深色模式自動切換的顏色
    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
    }
}
