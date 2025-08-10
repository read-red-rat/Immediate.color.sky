import SwiftUI
import UserNotifications

struct AlarmListView: View {
    @StateObject private var manager = AlarmManager.shared
    @State private var showingEditView = false
    @State private var selectedAlarm: AlarmModel?
    @State private var tappedAlarmID: UUID?
    @State private var rippleLocation: CGPoint = .zero
    
    var body: some View {
        NavigationView {
            List {
                ForEach(manager.alarms) { alarm in
                    AlarmRowView(
                        alarm: alarm,
                        tappedAlarmID: $tappedAlarmID,
                        rippleLocation: $rippleLocation,
                        selectedAlarm: $selectedAlarm,
                        showingEditView: $showingEditView,
                        manager: manager
                    )
                }
                .onDelete(perform: deleteAlarms)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("アラーム")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("デバッグ") {
                        NotificationManager.shared.printScheduledNotifications()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedAlarm = nil
                        showingEditView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                AlarmEditView(alarm: $selectedAlarm)
            }
            .onAppear {
                // 通知許可を確実に取得
                NotificationManager.shared.requestAuthorization()
                
                // 既存のアラームを再スケジュール
                for alarm in manager.alarms {
                    if alarm.isEnabled {
                        NotificationManager.shared.schedule(alarm: alarm)
                    }
                }
            }
        }
    }
    
    private func deleteAlarms(at offsets: IndexSet) {
        withAnimation {
            manager.deleteAlarm(at: offsets)
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// アラーム行のビューを分離
struct AlarmRowView: View {
    let alarm: AlarmModel
    @Binding var tappedAlarmID: UUID?
    @Binding var rippleLocation: CGPoint
    @Binding var selectedAlarm: AlarmModel?
    @Binding var showingEditView: Bool
    let manager: AlarmManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alarm.label)
                        .font(.title3)
                        .bold()
                    
                    // 曜日表示
                    HStack {
                        Text("曜日: ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formattedDays)
                            .font(.subheadline)
                    }
                    
                    // 時間表示
                    if alarm.isRepeatAlarm {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("時間範囲: ")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formattedTimeRange)
                                    .font(.subheadline)
                            }
                            
                            HStack {
                                Text("間隔: ")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formattedInterval)
                                    .font(.subheadline)
                            }
                        }
                    } else {
                        HStack {
                            Text("時刻: ")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formattedTime(alarm.time))
                                .font(.subheadline)
                        }
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { newValue in
                        manager.toggleAlarm(alarm, isOn: newValue)
                    }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 8)
            .background(
                // リップルエフェクトを背景として配置
                RippleEffect(
                    isVisible: tappedAlarmID == alarm.id,
                    location: rippleLocation
                )
            )
            .onTapGesture { location in
                rippleLocation = location
                
                withAnimation(.easeOut(duration: 0.6)) {
                    tappedAlarmID = alarm.id
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedAlarm = alarm
                    showingEditView = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    tappedAlarmID = nil
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if let index = manager.alarms.firstIndex(where: { $0.id == alarm.id }) {
                    withAnimation {
                        manager.deleteAlarm(at: IndexSet([index]))
                    }
                }
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    // 計算プロパティとして分離
    private var formattedDays: String {
        alarm.selectedDays
            .sorted(by: { $0.rawValue < $1.rawValue })
            .map { $0.label }
            .joined(separator: " ")
    }
    
    private var formattedTimeRange: String {
        if let start = alarm.repeatStartTime, let end = alarm.repeatEndTime {
            return "\(formattedTime(start)) - \(formattedTime(end))"
        }
        return ""
    }
    
    private var formattedInterval: String {
        return "\(alarm.repeatInterval ?? 0) 分"
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// リップルエフェクトのカスタムビュー
struct RippleEffect: View {
    let isVisible: Bool
    let location: CGPoint
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            if isVisible {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: animationProgress * 300, height: animationProgress * 300)
                    .position(location)
                    .opacity(1 - animationProgress)
                    .animation(.easeOut(duration: 0.6), value: animationProgress)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isVisible) { newValue in
            if newValue {
                animationProgress = 0
                withAnimation(.easeOut(duration: 0.6)) {
                    animationProgress = 1
                }
            }
        }
    }
}

// タップ位置を取得するためのカスタムTapGesture
extension View {
    func onTapGesture(perform action: @escaping (CGPoint) -> Void) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    action(value.location)
                }
        )
    }
}
