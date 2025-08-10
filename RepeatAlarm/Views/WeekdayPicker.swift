import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Weekday>
    
    var body: some View {
        HStack {
            ForEach(Weekday.allCases, id: \.rawValue) { day in
                Button(action: {
                    toggleDay(day)
                }) {
                    Text(day.label)
                        .padding(8)
                        .background(selectedDays.contains(day) ? Color.accentColor : Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func toggleDay(_ day: Weekday) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}
