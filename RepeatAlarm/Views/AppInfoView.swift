import SwiftUI

struct AppInfoView: View {
    var body: some View {
        Form {
            Section(header: Text("アプリ情報")) {
                HStack {
                    Text("アプリ名")
                    Spacer()
                    Text("Alarm App")
                }
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text("1.0.0")
                }
                HStack {
                    Text("開発者")
                    Spacer()
                    Text("YourName")
                }
            }

            Section {
                Text("このアプリはSwiftUIで開発され、ローカル通知、サウンド、バイブレーションを活用してアラーム機能を提供します。")
                    .font(.footnote)
            }
        }
        .navigationTitle("アプリ情報")
    }
}
