//
//  ContentView.swift
//  RepeatAlarm
//
//  Created by ryota on 2025/07/12.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            AlarmListView()
                .tabItem {
                    Label("アラーム", systemImage: "alarm")
                }
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
