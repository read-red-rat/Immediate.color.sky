import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultSound") private var defaultSound = "Default"
    @AppStorage("vibrationEnabled") private var vibrationEnabled = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("デフォルトサウンド")) {
                    Picker("サウンド", selection: $defaultSound) {
                        ForEach(SoundManager.shared.availableSounds, id: \.self) { sound in
                            Text(sound)
                        }
                    }
                    Toggle("バイブレーション", isOn: $vibrationEnabled)
                }

                Section {
                    NavigationLink("通知設定", destination: NotificationSettingsView())
                    NavigationLink("アプリ情報", destination: AppInfoView())
                }
            }
            .navigationTitle("設定")
        }
    }
}
