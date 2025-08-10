//
//  RepeatAlarmApp.swift
//  RepeatAlarm
//
//  Created by ryota on 2025/07/12.
//

import SwiftUI

@main
struct RepeatAlarmApp: App {
    // AppDelegateを SwiftUIアプリに接続
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
