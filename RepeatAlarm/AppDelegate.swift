import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        NotificationManager.shared.requestAuthorization()
        
        // 🆕 アプリ起動時の優先度管理初期化
        initializePriorityManagement()
        
        return true
    }
    
    // 🆕 優先度管理システムの初期化
    private func initializePriorityManagement() {
        print("🚀 優先度管理システム初期化開始")
        
        // 古い通知をクリーンアップ
        NotificationManager.shared.cleanupOldNotifications()
        
        // 音声ファイルの確認
        NotificationManager.shared.checkAndPrepareSoundFiles()
        
        // 🆕 全アラームを優先度順で再スケジュール
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NotificationManager.shared.rescheduleAllAlarmsWithPriority()
            
            // 初期化完了後の統計表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AlarmManager.shared.checkNotificationLimits()
                NotificationManager.shared.printNotificationPriorities()
            }
        }
        
        print("✅ 優先度管理システム初期化完了")
    }
    
    private func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "スヌーズ (5分)",
            options: [.foreground]
        )
        
        let stopAction = UNNotificationAction(
            identifier: "STOP_ACTION",
            title: "停止",
            options: [.destructive]
        )
        
        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM_CATEGORY",
            actions: [snoozeAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])
        print("✅ 通知カテゴリ設定完了")
    }
    
    // 🆕 フォアグラウンドでの通知受信（優先度管理対応版）
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("📱 フォアグラウンドで通知受信: \(notification.request.identifier)")
        
        let userInfo = notification.request.content.userInfo
        
        if let isMainAlarm = userInfo["isMainAlarm"] as? Bool, isMainAlarm {
            print("🚨 メインアラーム受信")
            
            let is60SecAlarm = userInfo["is60SecAlarm"] as? Bool ?? false
            let notificationPart = userInfo["notificationPart"] as? Int ?? 1
            
            if is60SecAlarm {
                print("🔊 60秒アラーム Part \(notificationPart) 受信")
                
                // フォアグラウンド中は通知を表示
                if #available(iOS 14.0, *) {
                    completionHandler([.alert, .sound, .badge, .banner])
                } else {
                    completionHandler([.alert, .sound, .badge])
                }
                
                // バイブレーション強化（Part 1のみ）
                if notificationPart == 1,
                   let alarmIdString = userInfo["alarmId"] as? String,
                   let alarmId = UUID(uuidString: alarmIdString) {
                    NotificationManager.shared.enhanceVibrationForAlarm(alarmId)
                }
            } else {
                // 通常のアラーム処理
                if #available(iOS 14.0, *) {
                    completionHandler([.alert, .sound, .badge, .banner])
                } else {
                    completionHandler([.alert, .sound, .badge])
                }
            }
            
        } else {
            // その他の通知は通常通り
            if #available(iOS 14.0, *) {
                completionHandler([.alert, .sound, .badge, .banner])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }
        
        handleNotificationReceived(identifier: notification.request.identifier, userInfo: userInfo)
    }
    
    // 🆕 通知タップ・アクション処理（優先度管理対応版）
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("👆 通知レスポンス: \(response.notification.request.identifier)")
        print("   アクション: \(response.actionIdentifier)")
        
        let userInfo = response.notification.request.content.userInfo
        let is60SecAlarm = userInfo["is60SecAlarm"] as? Bool ?? false
        
        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            handleSnoozeAction(userInfo: userInfo, is60SecAlarm: is60SecAlarm)
        case "STOP_ACTION", UNNotificationDefaultActionIdentifier:
            handleStopAction(userInfo: userInfo, is60SecAlarm: is60SecAlarm)
        case UNNotificationDismissActionIdentifier:
            print("🔕 通知が無視されました")
            handleStopAction(userInfo: userInfo, is60SecAlarm: is60SecAlarm)
        default:
            break
        }
        
        handleNotificationReceived(identifier: response.notification.request.identifier, userInfo: userInfo)
        
        completionHandler()
    }
    
    // 🆕 スヌーズアクション（優先度管理対応版）
    private func handleSnoozeAction(userInfo: [AnyHashable: Any], is60SecAlarm: Bool) {
        guard let alarmIdString = userInfo["alarmId"] as? String,
              let alarmId = UUID(uuidString: alarmIdString) else {
            print("❌ スヌーズ: alarmId取得失敗")
            return
        }
        
        print("😴 スヌーズ実行: \(alarmId)")
        
        // 60秒アラームの場合は専用停止処理
        if is60SecAlarm {
            NotificationManager.shared.stop60SecAlarmNotifications(for: alarmId)
        } else {
            NotificationManager.shared.stopNotificationsForAlarm(alarmId)
        }
        
        // 5分後にアラームを再スケジュール
        if let alarm = AlarmManager.shared.alarms.first(where: { $0.id == alarmId }) {
            let snoozeAlarm = AlarmModel(
                id: UUID(),
                time: Date().addingTimeInterval(300), // 5分後
                selectedDays: [],
                isEnabled: true,
                label: "\(alarm.label) (スヌーズ)",
                soundName: alarm.soundName,
                isVibrationOnly: alarm.isVibrationOnly,
                isRepeatAlarm: false,
                repeatStartTime: nil,
                repeatEndTime: nil,
                repeatInterval: nil
            )
            
            // 🆕 優先度管理システムでスケジュール
            NotificationManager.shared.scheduleAlarmWithPriority(snoozeAlarm)
            print("⏰ スヌーズアラーム作成（優先度管理）: 5分後")
        }
    }
    
    // 🆕 停止アクション（優先度管理対応版）
    private func handleStopAction(userInfo: [AnyHashable: Any], is60SecAlarm: Bool) {
        guard let alarmIdString = userInfo["alarmId"] as? String,
              let alarmId = UUID(uuidString: alarmIdString) else {
            print("❌ 停止: alarmId取得失敗")
            return
        }
        
        print("🔕 アラーム停止: \(alarmId)")
        
        // 60秒アラームの場合は専用停止処理
        if is60SecAlarm {
            NotificationManager.shared.stop60SecAlarmNotifications(for: alarmId)
            print("🔕 60秒アラーム（30秒×2）完全停止")
        } else {
            NotificationManager.shared.stopNotificationsForAlarm(alarmId)
        }
        
        // 🆕 停止後に全体を再スケジュール（優先度最適化）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationManager.shared.rescheduleAllAlarmsWithPriority()
            print("🔄 停止後の優先度再計算完了")
        }
    }
    
    // 🆕 通知受信後の共通処理（優先度管理対応版）
    private func handleNotificationReceived(identifier: String, userInfo: [AnyHashable: Any]) {
        print("🔍 通知処理開始: \(identifier)")
        
        guard let alarmIdString = userInfo["alarmId"] as? String,
              let alarmUUID = UUID(uuidString: alarmIdString) else {
            print("❌ userInfoからalarmIdが取得できません")
            return
        }
        
        print("✅ アラームID取得成功: \(alarmUUID)")
        
        let isMainAlarm = userInfo["isMainAlarm"] as? Bool ?? false
        let isRepeatAlarm = userInfo["isRepeatAlarm"] as? Bool ?? false
        let is60SecAlarm = userInfo["is60SecAlarm"] as? Bool ?? false
        let notificationPart = userInfo["notificationPart"] as? Int ?? 1
        
        if !isMainAlarm {
            print("⚠️ メインアラームではないため処理スキップ")
            return
        }
        
        print("🚨 メインアラーム処理開始: \(alarmUUID)")
        
        if is60SecAlarm {
            print("🔊 60秒アラーム Part \(notificationPart) 処理")
            
            // Part 2（2回目の通知）の場合のみ再スケジュール処理を実行
            if notificationPart == 2 {
                print("🏁 60秒アラーム完了 - 再スケジュール処理開始")
                processAlarmRescheduling(alarmUUID: alarmUUID, userInfo: userInfo)
            } else {
                print("⏳ 60秒アラーム Part 1 - Part 2待機中")
            }
        } else {
            // 通常のアラーム処理
            processAlarmRescheduling(alarmUUID: alarmUUID, userInfo: userInfo)
        }
        
        showAlarmScreenIfNeeded(alarmUUID: alarmUUID)
    }
    
    // 🆕 アラーム再スケジュール処理（優先度管理対応版）
    private func processAlarmRescheduling(alarmUUID: UUID, userInfo: [AnyHashable: Any]) {
        guard let alarm = AlarmManager.shared.alarms.first(where: { $0.id == alarmUUID && $0.isEnabled }) else {
            print("❌ 対応するアラームが見つからないか無効: UUID=\(alarmUUID)")
            return
        }
        
        print("✅ アラーム見つかりました: \(alarm.label)")
        
        // 🆕 優先度管理システムでアラーム再スケジュール処理
        handleAlarmReschedulingWithPriority(alarm: alarm, userInfo: userInfo)
    }
    
    // 🆕 優先度管理対応のアラーム再スケジュール処理
    private func handleAlarmReschedulingWithPriority(alarm: AlarmModel, userInfo: [AnyHashable: Any]) {
        let isRepeatAlarm = userInfo["isRepeatAlarm"] as? Bool ?? false
        
        if isRepeatAlarm || alarm.isRepeatAlarm {
            handleOptimizedRepeatAlarmRescheduling(alarm: alarm, userInfo: userInfo)
        } else if !alarm.selectedDays.isEmpty {
            handleOptimizedWeeklyAlarmRescheduling(alarm: alarm, userInfo: userInfo)
        } else {
            print("📝 単発アラームのため再スケジュールなし")
        }
        
        // 🆕 再スケジュール後に全体の優先度を最適化
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🔄 再スケジュール完了後の優先度最適化")
            NotificationManager.shared.rescheduleAllAlarmsWithPriority()
        }
    }
    
    // 🆕 最適化されたリピートアラーム再スケジュール（優先度管理対応）
    private func handleOptimizedRepeatAlarmRescheduling(alarm: AlarmModel, userInfo: [AnyHashable: Any]) {
        let sequenceNumber = userInfo["sequenceNumber"] as? Int ?? 1
        let totalCount = userInfo["totalCount"] as? Int ?? 1
        
        print("🔄 リピートアラーム処理（優先度管理）: \(alarm.label) (\(sequenceNumber)/\(totalCount))")
        
        // 最後のアラームの場合のみ次週/翌日にスケジュール
        if sequenceNumber >= totalCount {
            print("🏁 リピートアラーム完了: \(alarm.label)")
            
            if !alarm.selectedDays.isEmpty {
                scheduleNextWeekRepeatAlarmWithPriority(alarm: alarm, userInfo: userInfo)
            } else {
                scheduleNextDayRepeatAlarmWithPriority(alarm: alarm)
            }
        } else {
            print("⏭ リピートアラーム継続中: 次は\(sequenceNumber + 1)回目")
        }
    }
    
    // 🆕 次週のリピートアラームスケジュール（優先度管理対応）
    private func scheduleNextWeekRepeatAlarmWithPriority(alarm: AlarmModel, userInfo: [AnyHashable: Any]) {
        guard let weekdayRaw = userInfo["weekday"] as? Int,
              weekdayRaw != 0,
              let weekday = Weekday(rawValue: weekdayRaw) else {
            print("❌ 曜日情報の取得に失敗")
            return
        }
        
        print("📅 リピートアラーム 次週の\(weekday.label)曜日に再スケジュール（優先度管理）")
        
        let nextWeekAlarm = AlarmModel(
            id: UUID(),
            time: alarm.time,
            selectedDays: [weekday],
            isEnabled: true,
            label: alarm.label,
            soundName: alarm.soundName,
            isVibrationOnly: alarm.isVibrationOnly,
            isRepeatAlarm: alarm.isRepeatAlarm,
            repeatStartTime: alarm.repeatStartTime,
            repeatEndTime: alarm.repeatEndTime,
            repeatInterval: alarm.repeatInterval
        )
        
        AlarmManager.shared.addAlarm(nextWeekAlarm)
        // addAlarm内で優先度管理システムが呼び出されるため、個別のスケジュールは不要
    }
    
    // 🆕 翌日のリピートアラームスケジュール（優先度管理対応）
    private func scheduleNextDayRepeatAlarmWithPriority(alarm: AlarmModel) {
        let calendar = Calendar.current
        
        guard let nextDayStartTime = calendar.date(byAdding: .day, value: 1, to: alarm.repeatStartTime ?? alarm.time),
              let nextDayEndTime = calendar.date(byAdding: .day, value: 1, to: alarm.repeatEndTime ?? alarm.time) else {
            print("❌ 翌日の時刻計算に失敗")
            return
        }
        
        print("📅 リピートアラーム 翌日に再スケジュール（優先度管理）")
        
        let nextDayAlarm = AlarmModel(
            id: UUID(),
            time: nextDayStartTime,
            selectedDays: [],
            isEnabled: true,
            label: alarm.label,
            soundName: alarm.soundName,
            isVibrationOnly: alarm.isVibrationOnly,
            isRepeatAlarm: alarm.isRepeatAlarm,
            repeatStartTime: nextDayStartTime,
            repeatEndTime: nextDayEndTime,
            repeatInterval: alarm.repeatInterval
        )
        
        AlarmManager.shared.addAlarm(nextDayAlarm)
        // addAlarm内で優先度管理システムが呼び出されるため、個別のスケジュールは不要
    }
    
    // 🆕 最適化された週次アラーム再スケジュール（優先度管理対応）
    private func handleOptimizedWeeklyAlarmRescheduling(alarm: AlarmModel, userInfo: [AnyHashable: Any]) {
        guard let weekdayRaw = userInfo["weekday"] as? Int,
              weekdayRaw != 0,
              let weekday = Weekday(rawValue: weekdayRaw) else {
            print("❌ 曜日情報の取得に失敗")
            return
        }
        
        print("📅 来週の\(weekday.label)曜日に再スケジュール（優先度管理）")
        
        let nextWeekAlarm = AlarmModel(
            id: UUID(),
            time: alarm.time,
            selectedDays: [weekday],
            isEnabled: true,
            label: alarm.label,
            soundName: alarm.soundName,
            isVibrationOnly: alarm.isVibrationOnly,
            isRepeatAlarm: alarm.isRepeatAlarm,
            repeatStartTime: alarm.repeatStartTime,
            repeatEndTime: alarm.repeatEndTime,
            repeatInterval: alarm.repeatInterval
        )
        
        AlarmManager.shared.addAlarm(nextWeekAlarm)
        // addAlarm内で優先度管理システムが呼び出されるため、個別のスケジュールは不要
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func showAlarmScreenIfNeeded(alarmUUID: UUID) {
        guard UIApplication.shared.applicationState == .active else {
            print("🖥 バックグラウンド実行中のため画面表示スキップ")
            return
        }
        
        print("🖥 アラーム画面表示: \(alarmUUID)")
        // アラーム画面表示の実装をここに追加
    }
    
    // 🆕 アプリ状態変更時の優先度管理（60秒アラーム対応版）
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 アプリがバックグラウンドに移行")
        print("🔊 バックグラウンド: 60秒アラーム（30秒×2）継続中")
        
        // 🆕 バックグラウンド移行時に通知の優先度をチェック
        NotificationManager.shared.monitorNotificationCount()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 アプリがフォアグラウンドに復帰")
        
        // フォアグラウンド復帰時の処理
        handleForegroundReturnWithPriority()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("📱 アプリがアクティブになりました")
        
        // 配信済みのアラーム通知をチェック
        checkActiveAlarmNotifications()
        
        // 🆕 アクティブ時に優先度状況を確認
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationManager.shared.monitorNotificationCount()
            AlarmManager.shared.checkNotificationLimits()
        }
    }
    
    // 🆕 フォアグラウンド復帰時の優先度管理処理
    private func handleForegroundReturnWithPriority() {
        print("🔄 フォアグラウンド復帰: 優先度管理処理開始")
        
        // 60秒アラーム通知を停止
        NotificationManager.shared.stopActiveAlarmNotificationsOnForegroundReturn()
        
        // 通知設定と通知数をチェック
        NotificationManager.shared.checkNotificationSettings()
        
        // 🆕 優先度の再計算（必要に応じて）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NotificationManager.shared.rescheduleAllAlarmsWithPriority()
        }
        
        // 通常のアラーム通知もチェック
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                let alarmNotifications = notifications.filter { notification in
                    let userInfo = notification.request.content.userInfo
                    let categoryMatch = notification.request.content.categoryIdentifier == "ALARM_CATEGORY"
                    let is60SecAlarm = userInfo["is60SecAlarm"] as? Bool ?? false
                    
                    return categoryMatch && !is60SecAlarm
                }
                
                if !alarmNotifications.isEmpty {
                    print("🚨 通常アラーム通知発見: \(alarmNotifications.count)件")
                    
                    if let latestAlarm = alarmNotifications.first,
                       let alarmIdString = latestAlarm.request.content.userInfo["alarmId"] as? String,
                       let alarmId = UUID(uuidString: alarmIdString) {
                        
                        print("📳 フォアグラウンド復帰時のバイブレーション強化")
                        NotificationManager.shared.enhanceVibrationForAlarm(alarmId)
                    }
                } else {
                    print("✅ フォアグラウンド復帰: アクティブなアラーム通知なし")
                }
            }
        }
    }
    
    // アクティブなアラーム通知のチェック
    private func checkActiveAlarmNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                let alarmNotifications = notifications.filter { notification in
                    notification.request.content.categoryIdentifier == "ALARM_CATEGORY"
                }
                
                if !alarmNotifications.isEmpty {
                    print("🔍 アクティブなアラーム通知: \(alarmNotifications.count)件")
                    
                    for notification in alarmNotifications {
                        let userInfo = notification.request.content.userInfo
                        let is60SecAlarm = userInfo["is60SecAlarm"] as? Bool ?? false
                        let part = userInfo["notificationPart"] as? Int ?? 0
                        let title = notification.request.content.title
                        
                        if is60SecAlarm {
                            print("  📱 60秒アラーム Part \(part): \(title)")
                        } else {
                            print("  📱 通常アラーム: \(title)")
                        }
                    }
                } else {
                    print("✅ アクティブなアラーム通知なし")
                }
            }
        }
    }
    
    // 🆕 バックグラウンド処理の優先度管理対応
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("🔄 バックグラウンドフェッチ実行（優先度管理）")
        
        // 古い通知のクリーンアップ
        NotificationManager.shared.cleanupOldNotifications()
        
        // 🆕 通知数のチェックと優先度最適化
        NotificationManager.shared.checkNotificationCount { count in
            if count > 50 {
                print("⚠️ バックグラウンド: 通知数が多いため優先度最適化実行")
                NotificationManager.shared.rescheduleAllAlarmsWithPriority()
            }
            completionHandler(.newData)
        }
    }
    
    // MARK: - 🆕 優先度管理対応の外部インターフェース
    
    /// 手動アラーム停止（優先度管理対応）
    func handleManualAlarmStopWithPriority() {
        print("🔴 手動アラーム停止（優先度管理対応）")
        
        // 現在のアラーム通知を停止
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let alarmNotificationIds = notifications
                .filter { $0.request.content.categoryIdentifier == "ALARM_CATEGORY" }
                .map { $0.request.identifier }
            
            if !alarmNotificationIds.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: alarmNotificationIds)
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: alarmNotificationIds)
                
                print("🔕 手動停止: 配信済み+未配信アラーム通知を削除: \(alarmNotificationIds.count)件")
                
                // 🆕 停止後に優先度を再計算
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NotificationManager.shared.rescheduleAllAlarmsWithPriority()
                    print("🔄 手動停止後の優先度再計算完了")
                }
            }
        }
    }
    
    /// 特定のアラームを手動停止（優先度管理対応）
    func handleManualAlarmStopWithPriority(for alarmId: UUID) {
        print("🔴 特定アラームの手動停止（優先度管理）: \(alarmId)")
        
        // 60秒アラーム専用の停止処理を使用
        NotificationManager.shared.stop60SecAlarmNotifications(for: alarmId)
        
        // 🆕 停止後に優先度を再計算
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationManager.shared.rescheduleAllAlarmsWithPriority()
            print("🔄 個別停止後の優先度再計算完了")
        }
    }
    
    /// 🆕 優先度管理システムの状態確認（デバッグ用）
    func checkPrioritySystemStatus() {
        print("📊 優先度管理システム状態確認:")
        
        // アラーム統計
        let stats = AlarmManager.shared.getAlarmStatistics()
        print("   アクティブアラーム: \(stats.activeAlarms)")
        print("   推定通知数: \(stats.estimatedNotifications)/64")
        
        // 実際の通知数確認
        NotificationManager.shared.checkNotificationCount { actualCount in
            print("   実際の通知数: \(actualCount)/64")
            
            if actualCount != stats.estimatedNotifications {
                print("⚠️ 推定と実際の通知数に差異があります")
                print("💡 優先度再計算を推奨します")
            }
        }
        
        // 優先度表示
        NotificationManager.shared.printNotificationPriorities()
        
        // 最適化提案
        let suggestions = AlarmManager.shared.getOptimizationSuggestions()
        print("💡 最適化提案:")
        for suggestion in suggestions {
            print("   - \(suggestion)")
        }
    }
}
