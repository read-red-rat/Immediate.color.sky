import Foundation

enum Weekday: Int, CaseIterable, Identifiable, Codable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { self.rawValue }
    var label: String {
        switch self {
        case .sunday: return "日"
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        }
    }
}


struct AlarmModel: Identifiable, Codable, Equatable {
    let id: UUID
    var time: Date
    var selectedDays: Set<Weekday>
    var isEnabled: Bool
    var label: String
    var soundName: String
    var isVibrationOnly: Bool
    var isRepeatAlarm: Bool
    var repeatStartTime: Date?
    var repeatEndTime: Date?
    var repeatInterval: Int?
}
