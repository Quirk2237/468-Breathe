import SwiftUI

// MARK: - Commit Grid View
struct CommitGridView: View {
    @Bindable var settings: AppSettings
    
    private let daysToShow = 90
    private let boxSize: CGFloat = 10
    private let boxSpacing: CGFloat = 2
    
    private var dateRange: [Date] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        return (0..<daysToShow).compactMap { i in
            calendar.date(byAdding: .day, value: -(daysToShow - 1 - i), to: endDate)
        }
    }
    
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: boxSize, maximum: boxSize), spacing: boxSpacing)],
            spacing: boxSpacing
        ) {
            ForEach(dateRange, id: \.self) { date in
                DayBox(date: date, settings: settings)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
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
    
    private var completions: [ActivityType: Int] {
        settings.getCompletions(for: date)
    }
    
    private var totalCompletions: Int {
        completions.values.reduce(0, +)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private var dayTimes: DayTimes? {
        settings.getDayTimes(for: date)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(gridColor)
            .frame(width: 10, height: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isToday ? Color.orange : Color.clear, lineWidth: 1)
            )
            .onHover { hovering in
                isHovered = hovering
            }
            .popover(isPresented: $isHovered, arrowEdge: .top) {
                DayBoxPopover(
                    date: formattedDate,
                    completions: completions,
                    totalCompletions: totalCompletions,
                    isToday: isToday,
                    dayTimes: dayTimes
                )
            }
    }
}

// MARK: - Day Box Popover
struct DayBoxPopover: View {
    let date: String
    let completions: [ActivityType: Int]
    let totalCompletions: Int
    let isToday: Bool
    let dayTimes: DayTimes?
    
    private let accentColor = Color(red: 53/255.0, green: 211/255.0, blue: 153/255.0)
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date header
            HStack {
                Text(date)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if isToday {
                    Text("Today")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(3)
                }
            }
            
            // Day times with sun/moon icons
            if let times = dayTimes, (times.startTime != nil || times.endTime != nil) {
                HStack(spacing: 12) {
                    // Start time
                    HStack(spacing: 4) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        
                        if let startTime = times.startTime {
                            Text(timeFormatter.string(from: startTime))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.primary)
                        } else {
                            Text("--:--")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // End time
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.indigo)
                        
                        if let endTime = times.endTime {
                            Text(timeFormatter.string(from: endTime))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.primary)
                        } else {
                            Text("--:--")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
            }
            
            if totalCompletions == 0 {
                Text("No activities completed")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                // Exercise breakdown
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(ActivityType.allCases) { activity in
                        if let count = completions[activity], count > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: activity.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(accentColor)
                                    .frame(width: 14)
                                
                                Text(activity.displayName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text("×\(count)")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(accentColor)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(minWidth: 140)
    }
}

// MARK: - Preview
#Preview {
    CommitGridView(settings: AppSettings.shared)
        .padding()
        .frame(width: 400)
}

