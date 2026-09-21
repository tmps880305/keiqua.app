import SwiftUI
import KeiquaCore

// 階段 0 的最小畫面。正式的教學、測試輸入框與隱私說明在階段 3 實作。
struct ContentView: View {
    @State private var text = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Keiqua")
                .font(.largeTitle.bold())
            Text("Core v\(KeiquaCore.version)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("在這裡試用鍵盤", text: $text)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
