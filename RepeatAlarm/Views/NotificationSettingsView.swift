import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var isAuthorized = false

    var body: some View {
        VStack(spacing: 20) {
            Text(isAuthorized ? "通知は許可されています" : "通知は許可されていません")
                .font(.headline)
            Button("通知設定を確認") {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        isAuthorized = settings.authorizationStatus == .authorized
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
        }
        .onAppear {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    isAuthorized = settings.authorizationStatus == .authorized
                }
            }
        }
        .navigationTitle("通知設定")
        .padding()
    }
}
