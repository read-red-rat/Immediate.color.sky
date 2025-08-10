import Foundation
import UserNotifications
import UIKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // 🆕 通知最適化のための設定
    private let maxNotificationCount = 60 // 安全マージンを持って60個まで
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 通知許可エラー: \(error)")
                } else {
                    print("✅ 通知許可: \(granted)")
                    if !granted {
                        print("⚠️ 通知が許可されていません。設定で許可してください。")
                    }
                }
            }
        }
    }
    
    // MARK: - 🆕 30秒×2通知システム
    
    func schedule(alarm: AlarmModel) {
        cancel(alarm: alarm)
        
        if alarm.isRepeatAlarm {
            scheduleOptimizedRepeatAlarm(alarm)
        } else if !alarm.selectedDays.isEmpty {
            scheduleOptimizedWeeklyAlarm(alarm)
        } else {
            scheduleOptimizedSingleAlarm(alarm)
        }
    }
    
    // 🆕 最適化されたリピートアラーム（通知数を大幅削減）
    private func scheduleOptimizedRepeatAlarm(_ alarm: AlarmModel) {
        guard let startTime = alarm.repeatStartTime,
              let endTime = alarm.repeatEndTime,
              let interval = alarm.repeatInterval else {
            print("❌ リピートアラーム情報が不完全: \(alarm.label)")
            return
        }
        
        print("🔄 最適化リピートアラーム スケジュール: \(alarm.label)")
        
        if !alarm.selectedDays.isEmpty {
            for weekday in alarm.selectedDays {
                if let nextOccurrence = getNextOccurrence(for: weekday, time: startTime, from: Date()) {
                    scheduleOptimizedRepeatSequence(
                        alarm: alarm,
                        baseDate: nextOccurrence,
                        startTime: startTime,
                        endTime: endTime,
                        interval: interval,
                        weekday: weekday
                    )
                }
            }
        } else {
            scheduleOptimizedRepeatSequence(
                alarm: alarm,
                baseDate: getNextSingleOccurrence(time: startTime),
                startTime: startTime,
                endTime: endTime,
                interval: interval,
                weekday: nil
            )
        }
    }
    
    private func scheduleOptimizedRepeatSequence(
        alarm: AlarmModel,
        baseDate: Date,
        startTime: Date,
        endTime: Date,
        interval: Int,
        weekday: Weekday?
    ) {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute else { return }
        
        guard let actualStartTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: baseDate),
              let actualEndTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: baseDate) else {
            return
        }
        
        let finalEndTime: Date
        if actualEndTime <= actualStartTime {
            finalEndTime = calendar.date(byAdding: .day, value: 1, to: actualEndTime) ?? actualEndTime
        } else {
            finalEndTime = actualEndTime
        }
        
        // 🆕 通知数を制限（最大10個まで）
        var alarmTimes: [Date] = []
        var currentTime = actualStartTime
        let maxAlarms = 10 // 通知数を制限
        
        while currentTime <= finalEndTime && alarmTimes.count < maxAlarms {
            alarmTimes.append(currentTime)
            currentTime = calendar.date(byAdding: .minute, value: interval, to: currentTime) ?? currentTime
        }
        
        print("📅 \(weekday?.label ?? "単発")曜日: \(alarmTimes.count)個のアラーム（最適化済み）")
        
        // 各時刻に30秒×2の通知をスケジュール
        for (index, alarmTime) in alarmTimes.enumerated() {
            schedule60SecAlarmNotifications(
                alarm: alarm,
                at: alarmTime,
                sequenceNumber: index + 1,
                totalCount: alarmTimes.count,
                weekday: weekday
            )
        }
    }
    
    // 🆕 60秒アラーム（30秒×2通知）のスケジュール
    private func schedule60SecAlarmNotifications(
        alarm: AlarmModel,
        at date: Date,
        sequenceNumber: Int = 1,
        totalCount: Int = 1,
        weekday: Weekday?
    ) {
        print("🔊 60秒アラーム（30秒×2）スケジュール開始: \(alarm.label)")
        
        // 1回目の通知（0秒後）
        scheduleAlarmNotification(
            alarm: alarm,
            at: date,
            notificationPart: 1,
            sequenceNumber: sequenceNumber,
            totalCount: totalCount,
            weekday: weekday
        )
        
        // 2回目の通知（30秒後）
        let secondNotificationTime = Calendar.current.date(byAdding: .second, value: 30, to: date) ?? date
        scheduleAlarmNotification(
            alarm: alarm,
            at: secondNotificationTime,
            notificationPart: 2,
            sequenceNumber: sequenceNumber,
            totalCount: totalCount,
            weekday: weekday
        )
        
        print("✅ 60秒アラーム（30秒×2）スケジュール完了: \(formatDate(date))")
    }
    
    // 🆕 個別の30秒通知スケジュール
    private func scheduleAlarmNotification(
        alarm: AlarmModel,
        at date: Date,
        notificationPart: Int, // 1 or 2
        sequenceNumber: Int = 1,
        totalCount: Int = 1,
        weekday: Weekday?
    ) {
        let content = UNMutableNotificationContent()
        
        // 通知の内容設定
        if notificationPart == 1 {
            content.title = "⏰ \(alarm.label)"
            if alarm.isRepeatAlarm {
                content.body = "リピートアラーム (\(sequenceNumber)/\(totalCount)) - タップして停止"
            } else {
                content.body = "アラームが鳴っています - タップして停止"
            }
        } else {
            content.title = "⏰ \(alarm.label) (継続)"
            content.body = "アラーム継続中 - タップして停止"
        }
        
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.threadIdentifier = alarm.id.uuidString
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "isMainAlarm": true,
            "isRepeatAlarm": alarm.isRepeatAlarm,
            "sequenceNumber": sequenceNumber,
            "totalCount": totalCount,
            "weekday": weekday?.rawValue ?? 0,
            "scheduledTime": date.timeIntervalSince1970,
            "notificationPart": notificationPart, // 🆕 通知の順番
            "is60SecAlarm": true // 🆕 60秒アラームの識別子
        ]
        
        // 🆕 30秒音声ファイルを使用
        if alarm.isVibrationOnly {
            content.sound = nil
        } else {
            // 30秒版の音声ファイルを使用
            let mediumSoundName = "alarm_30sec_\(alarm.soundName).mp3"
            
            // ファイルが存在するかチェック
            if Bundle.main.url(forResource: "alarm_30sec_\(alarm.soundName)", withExtension: "mp3") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(mediumSoundName))
                print("🔊 30秒音声使用 (Part \(notificationPart)): \(mediumSoundName)")
            } else {
                // フォールバック: 通常の音声（できるだけ長めのものを使用）
                if alarm.soundName == "default" {
                    content.sound = UNNotificationSound.default
                } else {
                    content.sound = UNNotificationSound(named: UNNotificationSoundName("\(alarm.soundName).mp3"))
                }
                print("🔊 通常音声使用 (Part \(notificationPart)): \(alarm.soundName).mp3")
            }
        }
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let identifier = generate60SecNotificationId(
            alarmId: alarm.id,
            weekday: weekday,
            sequence: sequenceNumber,
            part: notificationPart
        )
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 30秒通知スケジュールエラー (Part \(notificationPart)): \(error)")
            } else {
                let weekdayLabel = weekday?.label ?? "単発"
                print("✅ 30秒通知スケジュール (Part \(notificationPart), \(weekdayLabel)-\(sequenceNumber)): \(self.formatDate(date))")
            }
        }
    }
    
    // 🆕 週次アラームの最適化
    private func scheduleOptimizedWeeklyAlarm(_ alarm: AlarmModel) {
        let now = Date()
        
        for weekday in alarm.selectedDays {
            if let targetDate = getNextOccurrence(for: weekday, time: alarm.time, from: now) {
                schedule60SecAlarmNotifications(
                    alarm: alarm,
                    at: targetDate,
                    weekday: weekday
                )
            }
        }
    }
    
    // 🆕 単発アラームの最適化
    private func scheduleOptimizedSingleAlarm(_ alarm: AlarmModel) {
        let targetDate = getNextSingleOccurrence(time: alarm.time)
        schedule60SecAlarmNotifications(
            alarm: alarm,
            at: targetDate,
            weekday: nil
        )
    }
    
    // MARK: - 🆕 60秒アラーム制御システム
    
    /// フォアグラウンド復帰時に60秒アラーム通知を停止
    func stopActiveAlarmNotificationsOnForegroundReturn() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let active60SecAlarms = notifications.filter { notification in
                let userInfo = notification.request.content.userInfo
                return userInfo["is60SecAlarm"] as? Bool == true
            }
            
            if !active60SecAlarms.isEmpty {
                let identifiers = active60SecAlarms.map { $0.request.identifier }
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
                
                // 未配信の2回目通知もキャンセル
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
                
                DispatchQueue.main.async {
                    print("🔕 フォアグラウンド復帰: 60秒アラーム通知停止 (\(identifiers.count)件)")
                }
            }
        }
    }
    
    /// 特定の60秒アラームを完全停止
    func stop60SecAlarmNotifications(for alarmId: UUID) {
        // 配信済み通知を削除
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let targetNotifications = notifications.filter { notification in
                let userInfo = notification.request.content.userInfo
                if let userAlarmId = userInfo["alarmId"] as? String,
                   let is60SecAlarm = userInfo["is60SecAlarm"] as? Bool {
                    return userAlarmId == alarmId.uuidString && is60SecAlarm
                }
                return false
            }
            
            let deliveredIds = targetNotifications.map { $0.request.identifier }
            if !deliveredIds.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: deliveredIds)
                print("🔕 配信済み60秒アラーム削除: \(deliveredIds.count)件")
            }
        }
        
        // 未配信の通知もキャンセル
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let targetRequests = requests.filter { request in
                let userInfo = request.content.userInfo
                if let userAlarmId = userInfo["alarmId"] as? String,
                   let is60SecAlarm = userInfo["is60SecAlarm"] as? Bool {
                    return userAlarmId == alarmId.uuidString && is60SecAlarm
                }
                return false
            }
            
            let pendingIds = targetRequests.map { $0.identifier }
            if !pendingIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIds)
                print("🔕 未配信60秒アラーム削除: \(pendingIds.count)件")
            }
        }
        
        print("🔕 60秒アラーム完全停止: \(alarmId)")
    }
    
    // MARK: - バイブレーション強化（フォアグラウンド時のみ）
    
    func enhanceVibrationForAlarm(_ alarmId: UUID) {
        // アプリがフォアグラウンドの場合のみバイブレーション強化
        guard UIApplication.shared.applicationState == .active else {
            print("⚠️ バックグラウンド中のためバイブレーション強化スキップ")
            return
        }
        
        print("📳 バイブレーション強化開始")
        
        // 複数回のバイブレーション
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
            }
        }
        
        // 15秒後にさらに強化バイブレーション
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
    
    // MARK: - 🆕 通知停止システム（通知のみ）
    
    func stopAllActiveNotifications() {
        // 配信済み通知をすべて削除
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🔕 すべてのアクティブ通知を停止")
    }
    
    func stopNotificationsForAlarm(_ alarmId: UUID) {
        // 60秒アラーム専用の停止処理を使用
        stop60SecAlarmNotifications(for: alarmId)
    }
    
    // MARK: - Helper Methods
    
    private func generate60SecNotificationId(
        alarmId: UUID,
        weekday: Weekday?,
        sequence: Int,
        part: Int
    ) -> String {
        if let weekday = weekday {
            return "\(alarmId.uuidString)-60sec-\(weekday.rawValue)-\(sequence)-part\(part)"
        } else {
            return "\(alarmId.uuidString)-60sec-single-\(sequence)-part\(part)"
        }
    }
    
    private func generateOptimizedNotificationId(
        alarmId: UUID,
        weekday: Weekday?,
        sequence: Int
    ) -> String {
        if let weekday = weekday {
            return "\(alarmId.uuidString)-opt-\(weekday.rawValue)-\(sequence)"
        } else {
            return "\(alarmId.uuidString)-opt-single-\(sequence)"
        }
    }
    
    private func getNextOccurrence(for weekday: Weekday, time: Date, from currentDate: Date) -> Date? {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        guard let hour = timeComponents.hour, let minute = timeComponents.minute else {
            return nil
        }
        
        guard let todayAtTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: currentDate) else {
            return nil
        }
        
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        
        if currentWeekday == weekday.rawValue {
            if todayAtTime > currentDate {
                return todayAtTime
            } else {
                return calendar.date(byAdding: .day, value: 7, to: todayAtTime)
            }
        } else {
            var daysToAdd = (weekday.rawValue - currentWeekday + 7) % 7
            if daysToAdd == 0 {
                daysToAdd = 7
            }
            
            guard let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: currentDate),
                  let scheduledTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate) else {
                return nil
            }
            
            return scheduledTime
        }
    }
    
    private func getNextSingleOccurrence(time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        guard let todayTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                            minute: timeComponents.minute ?? 0,
                                            second: 0,
                                            of: now) else { return time }
        
        if todayTime > now {
            return todayTime
        } else {
            return calendar.date(byAdding: .day, value: 1, to: todayTime) ?? todayTime
        }
    }
    
    func cancel(alarm: AlarmModel) {
        var identifiers: [String] = []
        
        // 基本ID
        identifiers.append(alarm.id.uuidString)
        identifiers.append("\(alarm.id.uuidString)-main")
        
        // 60秒アラームID（Part 1 & 2）
        for weekday in Weekday.allCases {
            for sequence in 1...20 {
                for part in 1...2 {
                    identifiers.append(generate60SecNotificationId(
                        alarmId: alarm.id,
                        weekday: weekday,
                        sequence: sequence,
                        part: part
                    ))
                }
            }
        }
        
        // 単発60秒アラームID
        for sequence in 1...20 {
            for part in 1...2 {
                identifiers.append(generate60SecNotificationId(
                    alarmId: alarm.id,
                    weekday: nil,
                    sequence: sequence,
                    part: part
                ))
            }
        }
        
        // 最適化ID（後方互換性）
        for weekday in Weekday.allCases {
            for sequence in 1...20 {
                identifiers.append(generateOptimizedNotificationId(
                    alarmId: alarm.id,
                    weekday: weekday,
                    sequence: sequence
                ))
            }
        }
        
        // 単発ID（後方互換性）
        for sequence in 1...20 {
            identifiers.append(generateOptimizedNotificationId(
                alarmId: alarm.id,
                weekday: nil,
                sequence: sequence
            ))
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        
        // 配信済み通知も削除
        stop60SecAlarmNotifications(for: alarm.id)
        
        print("🗑 アラーム通知キャンセル（60秒版）: \(alarm.label)")
    }
    
    // MARK: - 🆕 音声ファイルの動的チェックと作成支援（30秒版追加）
    
    func checkAndPrepareSoundFiles() {
        let soundNames = ["Radar", "Beacon", "Chimes", "Reflection"]
        var availableShortSounds: [String] = []
        var available30SecSounds: [String] = []
        var available60SecSounds: [String] = []
        
        print("🔊 音声ファイル確認開始...")
        
        for soundName in soundNames {
            // 短い音声ファイルのチェック
            if Bundle.main.url(forResource: soundName, withExtension: "mp3") != nil {
                availableShortSounds.append(soundName)
                print("✅ 短い音声OK: \(soundName).mp3")
            } else {
                print("❌ 短い音声なし: \(soundName).mp3")
            }
            
            // 30秒音声ファイルのチェック（重要）
            let mediumSoundName = "alarm_30sec_\(soundName)"
            if Bundle.main.url(forResource: mediumSoundName, withExtension: "mp3") != nil {
                available30SecSounds.append(mediumSoundName)
                print("✅ 30秒音声OK: \(mediumSoundName).mp3")
            } else {
                print("⚠️ 30秒音声なし: \(mediumSoundName).mp3")
            }
            
            // 60秒音声ファイルのチェック（参考用）
            let longSoundName = "alarm_60sec_\(soundName)"
            if Bundle.main.url(forResource: longSoundName, withExtension: "mp3") != nil {
                available60SecSounds.append(longSoundName)
                print("✅ 60秒音声OK: \(longSoundName).mp3")
            } else {
                print("⚠️ 60秒音声なし: \(longSoundName).mp3")
            }
        }
        
        print("📊 音声ファイル確認結果:")
        print("   短い音声: \(availableShortSounds.count)/\(soundNames.count)")
        print("   30秒音声: \(available30SecSounds.count)/\(soundNames.count) ⭐ 重要")
        print("   60秒音声: \(available60SecSounds.count)/\(soundNames.count) (参考)")
        
        if available30SecSounds.count < soundNames.count {
            print("💡 30秒音声ファイルの作成方法:")
            print("   1. 元の音声ファイルを30秒にループまたは延長")
            print("   2. ファイル名を 'alarm_30sec_[元の名前].mp3' に変更")
            print("   3. Xcodeプロジェクトに追加")
            print("   例: Radar.mp3 → alarm_30sec_Radar.mp3")
            print("   ⚠️ 30秒音声が重要：60秒鳴動（30秒×2）に使用")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // MARK: - 既存メソッドとの互換性
    
    func printScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                print("📋 登録中の通知一覧（全 \(requests.count) 件）:")
                for request in requests {
                    var triggerInfo = "不明"
                    if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                        if let nextTriggerDate = calendarTrigger.nextTriggerDate() {
                            triggerInfo = self.formatDate(nextTriggerDate)
                        }
                    }
                    
                    let userInfo = request.content.userInfo
                    let is60SecAlarm = userInfo["is60SecAlarm"] as? Bool ?? false
                    let part = userInfo["notificationPart"] as? Int ?? 0
                    let partInfo = is60SecAlarm ? " [60秒Part\(part)]" : ""
                    
                    print("  \(request.content.title)\(partInfo) - \(triggerInfo)")
                }
                
                if requests.count > 50 {
                    print("⚠️ 警告: 通知数が多すぎます (\(requests.count)/64)")
                }
            }
        }
    }
    
    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("=== 📱 通知設定詳細確認 ===")
                print("認証状況: \(settings.authorizationStatus)")
                print("アラート: \(settings.alertSetting)")
                print("音声: \(settings.soundSetting)")
                print("バッジ: \(settings.badgeSetting)")
                print("============================")
            }
        }
    }
    
    // 🆕 通知数チェック
    func checkNotificationCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests.count)
            }
        }
    }
    
    // 🆕 古い通知のクリーンアップ
    func cleanupOldNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let now = Date()
            let expiredIds = requests.compactMap { request -> String? in
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let triggerDate = trigger.nextTriggerDate(),
                   triggerDate < now {
                    return request.identifier
                }
                return nil
            }
            
            if !expiredIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: expiredIds)
                print("🧹 期限切れ通知をクリーンアップ: \(expiredIds.count)件")
            }
        }
    }
    
    // MARK: - 🆕 通知優先度管理システム
    
    /// 全アラームを優先度順（遠い順）で再スケジュール
    func rescheduleAllAlarmsWithPriority() {
        print("🔄 通知優先度管理: 全アラーム再スケジュール開始")
        
        // 既存の通知をすべてクリア
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑 既存通知をすべてクリア")
        
        // アクティブなアラームを取得
        let activeAlarms = AlarmManager.shared.alarms.filter { $0.isEnabled }
        print("📋 アクティブアラーム数: \(activeAlarms.count)")
        
        // 各アラームの通知を生成（まだスケジュールしない）
        var allNotificationRequests: [PrioritizedNotificationRequest] = []
        
        for alarm in activeAlarms {
            let notificationRequests = generateNotificationRequests(for: alarm)
            allNotificationRequests.append(contentsOf: notificationRequests)
        }
        
        print("📊 生成された通知総数: \(allNotificationRequests.count)")
        
        // 現在時刻から遠い順にソート
        allNotificationRequests.sort { request1, request2 in
            guard let date1 = request1.scheduledDate,
                  let date2 = request2.scheduledDate else {
                return false
            }
            return date1 > date2 // 遠い日時が先に来るように（降順）
        }
        
        // 64個制限を考慮してスケジュール
        scheduleNotificationsWithLimit(requests: allNotificationRequests)
    }
    
    /// アラーム追加時の優先度考慮スケジュール
    func scheduleAlarmWithPriority(_ alarm: AlarmModel) {
        print("🆕 優先度考慮アラーム追加: \(alarm.label)")
        rescheduleAllAlarmsWithPriority()
    }
    
    /// アラーム削除時の最適化
    func removeAlarmWithOptimization(_ alarm: AlarmModel) {
        print("🗑 アラーム削除最適化: \(alarm.label)")
        cancel(alarm: alarm)
        rescheduleAllAlarmsWithPriority()
    }
    
    // MARK: - 🆕 通知リクエスト生成システム
    
    private func generateNotificationRequests(for alarm: AlarmModel) -> [PrioritizedNotificationRequest] {
        var requests: [PrioritizedNotificationRequest] = []
        
        if alarm.isRepeatAlarm {
            requests.append(contentsOf: generateRepeatAlarmRequests(alarm))
        } else if !alarm.selectedDays.isEmpty {
            requests.append(contentsOf: generateWeeklyAlarmRequests(alarm))
        } else {
            requests.append(contentsOf: generateSingleAlarmRequests(alarm))
        }
        
        return requests
    }
    
    private func generateRepeatAlarmRequests(_ alarm: AlarmModel) -> [PrioritizedNotificationRequest] {
        guard let startTime = alarm.repeatStartTime,
              let endTime = alarm.repeatEndTime,
              let interval = alarm.repeatInterval else {
            print("❌ リピートアラーム情報が不完全")
            return []
        }
        
        var requests: [PrioritizedNotificationRequest] = []
        
        if !alarm.selectedDays.isEmpty {
            // 曜日指定のリピートアラーム
            for weekday in alarm.selectedDays {
                if let nextOccurrence = getNextOccurrence(for: weekday, time: startTime, from: Date()) {
                    let sequenceRequests = generateRepeatSequenceRequests(
                        alarm: alarm,
                        baseDate: nextOccurrence,
                        startTime: startTime,
                        endTime: endTime,
                        interval: interval,
                        weekday: weekday
                    )
                    requests.append(contentsOf: sequenceRequests)
                }
            }
        } else {
            // 単発リピートアラーム
            let nextOccurrence = getNextSingleOccurrence(time: startTime)
            let sequenceRequests = generateRepeatSequenceRequests(
                alarm: alarm,
                baseDate: nextOccurrence,
                startTime: startTime,
                endTime: endTime,
                interval: interval,
                weekday: nil
            )
            requests.append(contentsOf: sequenceRequests)
        }
        
        return requests
    }
    
    private func generateRepeatSequenceRequests(
        alarm: AlarmModel,
        baseDate: Date,
        startTime: Date,
        endTime: Date,
        interval: Int,
        weekday: Weekday?
    ) -> [PrioritizedNotificationRequest] {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute else { return [] }
        
        guard let actualStartTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: baseDate),
              let actualEndTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: baseDate) else {
            return []
        }
        
        let finalEndTime: Date
        if actualEndTime <= actualStartTime {
            finalEndTime = calendar.date(byAdding: .day, value: 1, to: actualEndTime) ?? actualEndTime
        } else {
            finalEndTime = actualEndTime
        }
        
        // アラーム時刻を計算（制限付き）
        var alarmTimes: [Date] = []
        var currentTime = actualStartTime
        let maxAlarms = 10 // 通知数制限
        
        while currentTime <= finalEndTime && alarmTimes.count < maxAlarms {
            alarmTimes.append(currentTime)
            currentTime = calendar.date(byAdding: .minute, value: interval, to: currentTime) ?? currentTime
        }
        
        // 各時刻に対してリクエストを生成
        var requests: [PrioritizedNotificationRequest] = []
        for (index, alarmTime) in alarmTimes.enumerated() {
            let sequenceRequests = generate60SecAlarmRequests(
                alarm: alarm,
                at: alarmTime,
                sequenceNumber: index + 1,
                totalCount: alarmTimes.count,
                weekday: weekday
            )
            requests.append(contentsOf: sequenceRequests)
        }
        
        return requests
    }
    
    private func generateWeeklyAlarmRequests(_ alarm: AlarmModel) -> [PrioritizedNotificationRequest] {
        var requests: [PrioritizedNotificationRequest] = []
        let now = Date()
        
        for weekday in alarm.selectedDays {
            if let targetDate = getNextOccurrence(for: weekday, time: alarm.time, from: now) {
                let weekdayRequests = generate60SecAlarmRequests(
                    alarm: alarm,
                    at: targetDate,
                    weekday: weekday
                )
                requests.append(contentsOf: weekdayRequests)
            }
        }
        
        return requests
    }
    
    private func generateSingleAlarmRequests(_ alarm: AlarmModel) -> [PrioritizedNotificationRequest] {
        let targetDate = getNextSingleOccurrence(time: alarm.time)
        return generate60SecAlarmRequests(
            alarm: alarm,
            at: targetDate,
            weekday: nil
        )
    }
    
    private func generate60SecAlarmRequests(
        alarm: AlarmModel,
        at date: Date,
        sequenceNumber: Int = 1,
        totalCount: Int = 1,
        weekday: Weekday?
    ) -> [PrioritizedNotificationRequest] {
        var requests: [PrioritizedNotificationRequest] = []
        
        // Part 1 (0秒後)
        if let request1 = createNotificationRequest(
            alarm: alarm,
            at: date,
            notificationPart: 1,
            sequenceNumber: sequenceNumber,
            totalCount: totalCount,
            weekday: weekday
        ) {
            requests.append(PrioritizedNotificationRequest(
                request: request1,
                scheduledDate: date,
                priority: calculatePriority(date: date, alarm: alarm, part: 1)
            ))
        }
        
        // Part 2 (30秒後)
        let secondNotificationTime = Calendar.current.date(byAdding: .second, value: 30, to: date) ?? date
        if let request2 = createNotificationRequest(
            alarm: alarm,
            at: secondNotificationTime,
            notificationPart: 2,
            sequenceNumber: sequenceNumber,
            totalCount: totalCount,
            weekday: weekday
        ) {
            requests.append(PrioritizedNotificationRequest(
                request: request2,
                scheduledDate: secondNotificationTime,
                priority: calculatePriority(date: secondNotificationTime, alarm: alarm, part: 2)
            ))
        }
        
        return requests
    }
    
    private func createNotificationRequest(
        alarm: AlarmModel,
        at date: Date,
        notificationPart: Int,
        sequenceNumber: Int = 1,
        totalCount: Int = 1,
        weekday: Weekday?
    ) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        
        // 通知の内容設定
        if notificationPart == 1 {
            content.title = "⏰ \(alarm.label)"
            if alarm.isRepeatAlarm {
                content.body = "リピートアラーム (\(sequenceNumber)/\(totalCount)) - タップして停止"
            } else {
                content.body = "アラームが鳴っています - タップして停止"
            }
        } else {
            content.title = "⏰ \(alarm.label) (継続)"
            content.body = "アラーム継続中 - タップして停止"
        }
        
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.threadIdentifier = alarm.id.uuidString
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "isMainAlarm": true,
            "isRepeatAlarm": alarm.isRepeatAlarm,
            "sequenceNumber": sequenceNumber,
            "totalCount": totalCount,
            "weekday": weekday?.rawValue ?? 0,
            "scheduledTime": date.timeIntervalSince1970,
            "notificationPart": notificationPart,
            "is60SecAlarm": true
        ]
        
        // 音声設定
        if alarm.isVibrationOnly {
            content.sound = nil
        } else {
            let mediumSoundName = "alarm_30sec_\(alarm.soundName).mp3"
            
            if Bundle.main.url(forResource: "alarm_30sec_\(alarm.soundName)", withExtension: "mp3") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(mediumSoundName))
            } else {
                if alarm.soundName == "default" {
                    content.sound = UNNotificationSound.default
                } else {
                    content.sound = UNNotificationSound(named: UNNotificationSoundName("\(alarm.soundName).mp3"))
                }
            }
        }
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let identifier = generate60SecNotificationId(
            alarmId: alarm.id,
            weekday: weekday,
            sequence: sequenceNumber,
            part: notificationPart
        )
        
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
    
    // MARK: - 🆕 優先度計算システム
    
    private func calculatePriority(date: Date, alarm: AlarmModel, part: Int) -> Double {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        
        // 基本優先度: 時間が遠いほど高い優先度
        var priority = timeInterval
        
        // Part 1の方が高優先度（アラーム開始）
        if part == 1 {
            priority += 1.0
        }
        
        // リピートアラームは少し高優先度
        if alarm.isRepeatAlarm {
            priority += 0.5
        }
        
        return priority
    }
    
    // MARK: - 🆕 制限付きスケジューリング
    
    private func scheduleNotificationsWithLimit(requests: [PrioritizedNotificationRequest]) {
        let maxNotifications = 60 // 安全マージン（64 - 4）
        let requestsToSchedule = Array(requests.prefix(maxNotifications))
        
        print("📊 通知スケジューリング詳細:")
        print("   生成総数: \(requests.count)")
        print("   スケジュール予定: \(requestsToSchedule.count)")
        print("   スキップ: \(requests.count - requestsToSchedule.count)")
        
        if requests.count > maxNotifications {
            print("⚠️ 警告: \(requests.count - maxNotifications)個の通知がスキップされます")
            
            // スキップされる通知の情報を表示
            let skippedRequests = Array(requests.dropFirst(maxNotifications))
            print("🚫 スキップされる通知:")
            for (index, skipped) in skippedRequests.enumerated() {
                if index < 5 { // 最初の5個だけ表示
                    let dateStr = skipped.scheduledDate.map { formatDate($0) } ?? "不明"
                    print("   - \(skipped.request.content.title) at \(dateStr)")
                }
            }
            if skippedRequests.count > 5 {
                print("   ... 他 \(skippedRequests.count - 5)件")
            }
        }
        
        // 実際にスケジュールを実行
        var scheduledCount = 0
        var failedCount = 0
        
        let group = DispatchGroup()
        
        for prioritizedRequest in requestsToSchedule {
            group.enter()
            
            UNUserNotificationCenter.current().add(prioritizedRequest.request) { error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ 通知スケジュールエラー: \(error)")
                    failedCount += 1
                } else {
                    scheduledCount += 1
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ 通知スケジューリング完了:")
            print("   成功: \(scheduledCount)")
            print("   失敗: \(failedCount)")
            print("   総計: \(scheduledCount + failedCount)")
            
            // デバッグ用: スケジュールされた通知の確認
            self.printScheduledNotifications()
        }
    }
    
    // MARK: - 🆕 既存メソッドの override
    
    /// 🆕 既存のscheduleメソッドを優先度管理版で上書き
    func scheduleWithPriority(alarm: AlarmModel) {
        print("🔄 優先度管理版 schedule() 呼び出し: \(alarm.label)")
        scheduleAlarmWithPriority(alarm)
    }
    
    // MARK: - 🆕 通知数監視システム
    
    func monitorNotificationCount() {
        checkNotificationCount { count in
            print("📊 現在の通知数: \(count)/64")
            
            if count >= 60 {
                print("⚠️ 警告: 通知数が上限に近づいています")
                self.optimizeNotifications()
            } else if count >= 50 {
                print("💡 情報: 通知数が多めです。最適化を検討してください")
            }
        }
    }
    
    private func optimizeNotifications() {
        print("🔄 通知最適化実行")
        rescheduleAllAlarmsWithPriority()
    }
    
    // MARK: - 🆕 デバッグ用メソッド
    
    func printNotificationPriorities() {
        let activeAlarms = AlarmManager.shared.alarms.filter { $0.isEnabled }
        var allRequests: [PrioritizedNotificationRequest] = []
        
        for alarm in activeAlarms {
            let requests = generateNotificationRequests(for: alarm)
            allRequests.append(contentsOf: requests)
        }
        
        allRequests.sort { $0.priority > $1.priority }
        
        print("📊 通知優先度一覧（遠い順）:")
        for (index, request) in allRequests.enumerated() {
            if index < 20 { // 最初の20個だけ表示
                let dateStr = request.scheduledDate.map { formatDate($0) } ?? "不明"
                let title = request.request.content.title
                print("   \(index + 1). \(title) - \(dateStr) (優先度: \(String(format: "%.1f", request.priority)))")
            }
        }
        
        if allRequests.count > 20 {
            print("   ... 他 \(allRequests.count - 20)件")
        }
    }
}

// MARK: - 🆕 優先度付き通知リクエスト構造体

struct PrioritizedNotificationRequest {
    let request: UNNotificationRequest
    let scheduledDate: Date?
    let priority: Double
    
    init(request: UNNotificationRequest, scheduledDate: Date?, priority: Double) {
        self.request = request
        self.scheduledDate = scheduledDate
        self.priority = priority
    }
}
