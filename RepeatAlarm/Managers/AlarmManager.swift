import Foundation

class AlarmManager: ObservableObject {
    static let shared = AlarmManager()
    @Published var alarms: [AlarmModel] = []
    
    private init() {
        loadAlarms()
    }
    
    func loadAlarms() {
        if let data = UserDefaults.standard.data(forKey: "alarms"),
           let decoded = try? JSONDecoder().decode([AlarmModel].self, from: data) {
            self.alarms = decoded
        }
    }
    
    func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "alarms")
        }
    }
    
    // 🆕 優先度管理対応版
    func saveAlarm(_ alarm: AlarmModel) {
        print("💾 アラーム保存: \(alarm.label)")
        
        // 既存のアラームを更新または新規追加
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
            print("🔄 既存アラーム更新")
        } else {
            alarms.append(alarm)
            print("🆕 新規アラーム追加")
        }
        
        // 🆕 優先度管理システムでスケジュール
        NotificationManager.shared.scheduleAlarmWithPriority(alarm)
        saveAlarms()
        
        // 通知数監視
        NotificationManager.shared.monitorNotificationCount()
    }
    
    // 🆕 優先度管理対応版
    func deleteAlarm(at offsets: IndexSet) {
        let alarmsToDelete = offsets.map { alarms[$0] }
        
        for alarm in alarmsToDelete {
            print("🗑 アラーム削除: \(alarm.label)")
            NotificationManager.shared.removeAlarmWithOptimization(alarm)
        }
        
        alarms.remove(atOffsets: offsets)
        saveAlarms()
        
        // 通知数監視
        NotificationManager.shared.monitorNotificationCount()
    }
    
    // 🆕 優先度管理対応版
    func toggleAlarm(_ alarm: AlarmModel, isOn: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        
        print("🔄 アラーム切り替え: \(alarm.label) -> \(isOn ? "ON" : "OFF")")
        
        alarms[index].isEnabled = isOn
        
        if isOn {
            // 🆕 優先度管理システムで全体を再スケジュール
            NotificationManager.shared.rescheduleAllAlarmsWithPriority()
        } else {
            // 該当アラームの通知をキャンセル後、全体を再スケジュール
            NotificationManager.shared.cancel(alarm: alarms[index])
            NotificationManager.shared.rescheduleAllAlarmsWithPriority()
        }
        
        saveAlarms()
        
        // 通知数監視
        NotificationManager.shared.monitorNotificationCount()
    }
    
    // 🆕 優先度管理対応版
    func addAlarm(_ alarm: AlarmModel) {
        print("➕ アラーム追加: \(alarm.label)")
        alarms.append(alarm)
        
        // 🆕 優先度管理システムで全体を再スケジュール
        NotificationManager.shared.rescheduleAllAlarmsWithPriority()
        saveAlarms()
        
        // 通知数監視
        NotificationManager.shared.monitorNotificationCount()
    }
    
    // 🆕 全アラーム再スケジュール（設定変更時など）
    func rescheduleAllAlarms() {
        print("🔄 全アラーム再スケジュール実行")
        NotificationManager.shared.rescheduleAllAlarmsWithPriority()
        
        // 通知数監視
        NotificationManager.shared.monitorNotificationCount()
    }
    
    // 🆕 アラーム統計情報
    func getAlarmStatistics() -> AlarmStatistics {
        let activeAlarms = alarms.filter { $0.isEnabled }
        let inactiveAlarms = alarms.filter { !$0.isEnabled }
        let repeatAlarms = activeAlarms.filter { $0.isRepeatAlarm }
        let weeklyAlarms = activeAlarms.filter { !$0.selectedDays.isEmpty && !$0.isRepeatAlarm }
        let singleAlarms = activeAlarms.filter { $0.selectedDays.isEmpty && !$0.isRepeatAlarm }
        
        // 推定通知数を計算
        var estimatedNotifications = 0
        
        for alarm in activeAlarms {
            if alarm.isRepeatAlarm {
                // リピートアラーム: 曜日数 × 最大10回 × 2通知（30秒×2）
                let dayCount = alarm.selectedDays.isEmpty ? 1 : alarm.selectedDays.count
                estimatedNotifications += dayCount * 10 * 2
            } else if !alarm.selectedDays.isEmpty {
                // 週次アラーム: 曜日数 × 2通知（30秒×2）
                estimatedNotifications += alarm.selectedDays.count * 2
            } else {
                // 単発アラーム: 2通知（30秒×2）
                estimatedNotifications += 2
            }
        }
        
        return AlarmStatistics(
            totalAlarms: alarms.count,
            activeAlarms: activeAlarms.count,
            inactiveAlarms: inactiveAlarms.count,
            repeatAlarms: repeatAlarms.count,
            weeklyAlarms: weeklyAlarms.count,
            singleAlarms: singleAlarms.count,
            estimatedNotifications: estimatedNotifications
        )
    }
    
    // 🆕 通知数チェックと警告
    func checkNotificationLimits() {
        let stats = getAlarmStatistics()
        
        print("📊 アラーム統計:")
        print("   総アラーム数: \(stats.totalAlarms)")
        print("   アクティブ: \(stats.activeAlarms)")
        print("   推定通知数: \(stats.estimatedNotifications)/64")
        
        if stats.estimatedNotifications > 60 {
            print("⚠️ 警告: 推定通知数が上限を超えています")
            print("💡 推奨: アラーム数を減らすか、リピート間隔を長くしてください")
        } else if stats.estimatedNotifications > 45 {
            print("💡 情報: 通知数が多めです。注意してください")
        }
    }
    
    // 🆕 最適化提案
    func getOptimizationSuggestions() -> [String] {
        var suggestions: [String] = []
        let stats = getAlarmStatistics()
        
        if stats.estimatedNotifications > 60 {
            suggestions.append("通知数が上限を超えています。アラーム数を減らしてください。")
        }
        
        if stats.repeatAlarms > 3 {
            suggestions.append("リピートアラームが多すぎます。間隔を長くするか数を減らしてください。")
        }
        
        let weeklyAlarmsWithManyDays = alarms.filter { $0.isEnabled && $0.selectedDays.count > 5 }
        if !weeklyAlarmsWithManyDays.isEmpty {
            suggestions.append("毎日設定されたアラームが複数あります。統合を検討してください。")
        }
        
        if suggestions.isEmpty {
            suggestions.append("現在の設定は最適化されています。")
        }
        
        return suggestions
    }
    
    // MARK: - 既存メソッド（後方互換性のため残す）
    
    private func scheduleNotifications(for alarm: AlarmModel) {
        // 🆕 優先度管理システムを使用
        NotificationManager.shared.scheduleAlarmWithPriority(alarm)
    }
    
    private func cancelNotifications(for alarm: AlarmModel) {
        NotificationManager.shared.cancel(alarm: alarm)
    }
    
    // 🆕 デバッグ用メソッド
    func printAlarmInfo() {
        print("📋 アラーム詳細情報:")
        for (index, alarm) in alarms.enumerated() {
            let status = alarm.isEnabled ? "✅" : "❌"
            let type = alarm.isRepeatAlarm ? "リピート" : (!alarm.selectedDays.isEmpty ? "週次" : "単発")
            let days = alarm.selectedDays.isEmpty ? "なし" : alarm.selectedDays.map { $0.label }.joined(separator: ",")
            
            print("   \(index + 1). \(status) \(alarm.label)")
            print("      タイプ: \(type)")
            print("      曜日: \(days)")
            print("      時刻: \(formatTime(alarm.time))")
            
            if alarm.isRepeatAlarm {
                let start = alarm.repeatStartTime.map { formatTime($0) } ?? "不明"
                let end = alarm.repeatEndTime.map { formatTime($0) } ?? "不明"
                let interval = alarm.repeatInterval ?? 0
                print("      リピート: \(start)〜\(end) (\(interval)分間隔)")
            }
        }
        
        let stats = getAlarmStatistics()
        print("\n📊 統計:")
        print("   推定通知数: \(stats.estimatedNotifications)/64")
        
        // 最適化提案を表示
        let suggestions = getOptimizationSuggestions()
        print("\n💡 最適化提案:")
        for suggestion in suggestions {
            print("   - \(suggestion)")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 🆕 アラーム統計構造体

struct AlarmStatistics {
    let totalAlarms: Int
    let activeAlarms: Int
    let inactiveAlarms: Int
    let repeatAlarms: Int
    let weeklyAlarms: Int
    let singleAlarms: Int
    let estimatedNotifications: Int
}
