import SwiftUI

struct AlarmEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var alarm: AlarmModel?
    
    @State private var time = Date()
    @State private var label = ""
    @State private var selectedDays: Set<Weekday> = []
    @State private var soundName = "Radar" // デフォルトを変更
    @State private var isVibrationOnly = false
    @State private var isRepeatAlarm = false
    @State private var repeatStartTime = Date()
    @State private var repeatEndTime = Date()
    @State private var repeatInterval = 30
    
    var body: some View {
        NavigationView {
            Form {
                DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)
                
                Section(header: Text("ラベル")) {
                    TextField("アラーム名", text: $label)
                }
                
                Section(header: Text("曜日")) {
                    WeekdayPicker(selectedDays: $selectedDays)
                }
                
                Section(header: Text("リピート設定")) {
                    Toggle("リピートアラーム", isOn: $isRepeatAlarm)
                    
                    if isRepeatAlarm {
                        DatePicker("開始時刻", selection: $repeatStartTime, displayedComponents: .hourAndMinute)
                        DatePicker("終了時刻", selection: $repeatEndTime, displayedComponents: .hourAndMinute)
                        
                        Stepper(value: $repeatInterval, in: 1...120, step: 1) {
                            Text("間隔: \(repeatInterval)分")
                        }
                    }
                }
                
                Section(header: Text("サウンド")) {
                    Toggle("バイブのみ", isOn: $isVibrationOnly)
                    
                    if !isVibrationOnly {
                        Picker("サウンド", selection: $soundName) {
                            ForEach(SoundManager.shared.availableSounds, id: \.self) { sound in
                                Text(sound).tag(sound)
                            }
                        }
                        
                        // サウンドテストボタン
                        Button("🔊 サウンドテスト") {
                            print("🧪 サウンドテスト実行: \(soundName)")
                            SoundManager.shared.playSound(named: soundName)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // デバッグセクション
                Section(header: Text("デバッグ")) {
                    Button("🔍 サウンドファイル確認") {
                        NotificationManager.shared.checkAndPrepareSoundFiles()
                    }
                    
                    Button("📋 通知一覧表示") {
                        NotificationManager.shared.printScheduledNotifications()
                    }
                    
                    Button("🧪 全サウンドテスト") {
                        SoundManager.shared.testAllSounds()
                    }
                }
            }
            .navigationTitle(alarm == nil ? "新規アラーム" : "アラーム編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        print("💾 アラーム保存開始")
                        print("   - 時刻: \(time)")
                        print("   - ラベル: \(label)")
                        print("   - 曜日: \(selectedDays)")
                        print("   - サウンド: \(soundName)")
                        print("   - バイブのみ: \(isVibrationOnly)")
                        print("   - リピート: \(isRepeatAlarm)")
                        
                        let newAlarm = AlarmModel(
                            id: alarm?.id ?? UUID(),
                            time: time,
                            selectedDays: selectedDays,
                            isEnabled: true,
                            label: label,
                            soundName: soundName,
                            isVibrationOnly: isVibrationOnly,
                            isRepeatAlarm: isRepeatAlarm,
                            repeatStartTime: isRepeatAlarm ? repeatStartTime : nil,
                            repeatEndTime: isRepeatAlarm ? repeatEndTime : nil,
                            repeatInterval: isRepeatAlarm ? repeatInterval : nil
                        )
                        
                        AlarmManager.shared.saveAlarm(newAlarm)
                        
                        // 保存後に通知一覧を表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationManager.shared.printScheduledNotifications()
                        }
                        
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 通知許可を確認
                NotificationManager.shared.requestAuthorization()
                
                // サウンドファイル確認
                NotificationManager.shared.checkAndPrepareSoundFiles()
                
                // 編集時読み込み
                if let alarm = alarm {
                    print("✏️ アラーム編集モード")
                    time = alarm.time
                    label = alarm.label
                    selectedDays = alarm.selectedDays
                    soundName = alarm.soundName
                    isVibrationOnly = alarm.isVibrationOnly
                    isRepeatAlarm = alarm.isRepeatAlarm
                    repeatStartTime = alarm.repeatStartTime ?? Date()
                    repeatEndTime = alarm.repeatEndTime ?? Date()
                    repeatInterval = alarm.repeatInterval ?? 30
                } else {
                    print("➕ アラーム新規作成モード")
                    // デフォルト値設定
                    if selectedDays.isEmpty {
                        selectedDays = [.monday, .tuesday, .wednesday, .thursday, .friday] // 平日をデフォルト
                    }
                }
            }
        }
    }
}
