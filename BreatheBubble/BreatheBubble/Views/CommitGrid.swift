import SwiftUI

// MARK: - Commit Grid View
struct CommitGridView: View {
    @Bindable var settings: AppSettings
    
    private let daysToShow = 90
    private let columns = 13
    private let boxSpacing: CGFloat = 3
    
    private var dateRange: [Date] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        var dates: [Date] = []
        
        for i in 0..<daysToShow {
            if let date = calendar.date(byAdding: .day, value: -i, to: endDate) {
                dates.append(date)
            }
        }
        
        return dates.reversed()
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: boxSpacing), count: columns), spacing: boxSpacing) {
            ForEach(dateRange, id: \.self) { date in
                DayBox(date: date, settings: settings)
            }
        }
    }
}

// MARK: - Day Box
struct DayBox: View {
    let date: Date
    @Bindable var settings: AppSettings
    
    @State private var isHovered = false
    
    private var completionPercentage: Double {
        settings.getCompletionPercentage(for: date)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var gridColor: Color {
        let baseColor = Color(red: 53/255.0, green: 211/255.0, blue: 153/255.0)
        let opacity = max(0.15, completionPercentage)
        return baseColor.opacity(opacity)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(gridColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isToday ? Color.orange : Color.clear, lineWidth: 1.5)
            )
            .help(tooltipText)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private var tooltipText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let completions = settings.getCompletions(for: date)
        let completionCounts = completions.map { "\($0.key.displayName): \($0.value)" }.joined(separator: ", ")
        
        if completionCounts.isEmpty {
            return "\(formatter.string(from: date)): No activities completed"
        } else {
            return "\(formatter.string(from: date)): \(completionCounts)"
        }
    }
}

// MARK: - Preview
#Preview {
    CommitGridView(settings: AppSettings.shared)
        .padding()
        .frame(width: 400)
}

