//
//  StreakView.swift
//  ProAlarm
//
//  View showing streak statistics and completion calendar
//

import SwiftUI
import SwiftData

struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ViewModel.self) var viewModel

    @Query(sort: \ProofRecord.completedAt, order: .reverse)
    private var proofRecords: [ProofRecord]

    @State private var selectedMonth = Date()
    @State private var showHistory = false
    @State private var showAchievements = false
    @State private var weeklyInsight: ProgressSummary?
    @State private var isLoadingInsight = false

    private var streak: StreakData? {
        viewModel.streakData
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak display
                    streakCard

                    // AI Weekly Insight (Apple Intelligence)
                    if AppSettings.shared.aiMessagesEnabled {
                        aiInsightCard
                    }

                    // Statistics
                    statisticsSection

                    // Calendar
                    calendarSection

                    // Recent completions
                    recentCompletionsSection
                }
                .padding()
            }
            .task {
                await loadWeeklyInsight()
            }
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAchievements = true
                    } label: {
                        Label("Achievements", systemImage: "trophy.fill")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showAchievements) {
                AchievementsView()
            }
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        VStack(spacing: 16) {
            // Flame icon
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Streak count
            Text("\(streak?.currentStreak ?? 0)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(streak?.streakMessage ?? "Start your streak!")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - AI Insight Card

    private var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("Weekly Insight")
                    .font(.headline)
                Spacer()
                if isLoadingInsight {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let insight = weeklyInsight {
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.headline)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(insight.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !insight.insights.isEmpty {
                        Divider()
                        ForEach(insight.insights.prefix(3), id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                Text(item)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let recommendation = insight.recommendation {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(recommendation)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.top, 4)
                    }
                }
            } else if !isLoadingInsight {
                Text("Complete more alarms to see insights")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.1))
        )
    }

    private func loadWeeklyInsight() async {
        guard AppSettings.shared.aiMessagesEnabled else { return }
        guard proofRecords.count >= 3 else { return } // Need some data

        isLoadingInsight = true

        let summarizer = ProgressSummarizer()
        weeklyInsight = await summarizer.generateWeeklySummary(
            records: proofRecords,
            streakData: streak
        )

        isLoadingInsight = false
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(spacing: 16) {
            // Primary stats row
            HStack(spacing: 16) {
                StatCard(
                    title: "Total",
                    value: "\(streak?.totalCompletions ?? 0)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatCard(
                    title: "Best Streak",
                    value: "\(streak?.longestStreak ?? 0)",
                    icon: "trophy.fill",
                    color: .yellow
                )

                StatCard(
                    title: "This Month",
                    value: "\(completionsThisMonth)",
                    icon: "calendar",
                    color: .blue
                )
            }

            // Secondary stats row
            HStack(spacing: 16) {
                StatCard(
                    title: "On Time %",
                    value: "\(onTimePercentage)%",
                    icon: "clock.fill",
                    color: .cyan
                )

                StatCard(
                    title: "This Week",
                    value: "\(completionsThisWeek)",
                    icon: "7.square.fill",
                    color: .purple
                )

                StatCard(
                    title: "Avg Level",
                    value: String(format: "%.1f", averageDifficulty),
                    icon: "star.fill",
                    color: .orange
                )
            }

            // Week comparison
            weekComparisonView
        }
    }

    private var completionsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return proofRecords.filter {
            calendar.isDate($0.completedAt, equalTo: now, toGranularity: .month)
        }.count
    }

    private var completionsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        return proofRecords.filter {
            calendar.isDate($0.completedAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
    }

    private var completionsLastWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else { return 0 }
        return proofRecords.filter {
            calendar.isDate($0.completedAt, equalTo: lastWeek, toGranularity: .weekOfYear)
        }.count
    }

    private var onTimePercentage: Int {
        guard !proofRecords.isEmpty else { return 0 }
        let onTimeCount = proofRecords.filter { $0.wasOnTime }.count
        return Int((Double(onTimeCount) / Double(proofRecords.count)) * 100)
    }

    private var averageDifficulty: Double {
        guard !proofRecords.isEmpty else { return 0 }
        let total = proofRecords.reduce(0) { $0 + $1.difficultyLevel }
        return Double(total) / Double(proofRecords.count)
    }

    private var weekComparisonView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Week Comparison")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text("This week: \(completionsThisWeek)")
                        .font(.subheadline)

                    Text("vs")
                        .foregroundStyle(.secondary)

                    Text("Last week: \(completionsLastWeek)")
                        .font(.subheadline)

                    if completionsThisWeek > completionsLastWeek {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                    } else if completionsThisWeek < completionsLastWeek {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Image(systemName: "equal.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calendar")
                    .font(.headline)

                Spacer()

                // Month navigation
                HStack(spacing: 16) {
                    Button {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Text(monthYearString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(minWidth: 120)

                    Button {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
                }
            }

            CalendarGridView(
                month: selectedMonth,
                completionData: completionDataByDate
            )

            // Calendar legend
            HStack(spacing: 16) {
                LegendItem(color: .green, label: "On time")
                LegendItem(color: .orange, label: "Snoozed")
                LegendItem(color: .accentColor.opacity(0.3), label: "Today")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private var completionDataByDate: [Date: CompletionStatus] {
        var data: [Date: CompletionStatus] = [:]
        for record in proofRecords {
            let date = Calendar.current.startOfDay(for: record.completedAt)
            // If already has a completion, keep the "best" one (on time beats snoozed)
            if let existing = data[date] {
                if record.wasOnTime && existing == .snoozed {
                    data[date] = .onTime
                }
            } else {
                data[date] = record.wasOnTime ? .onTime : .snoozed
            }
        }
        return data
    }

    // MARK: - Recent Completions

    private var recentCompletionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.headline)

                Spacer()

                Button("View All") {
                    showHistory = true
                }
                .font(.subheadline)
            }

            if proofRecords.isEmpty {
                Text("No completions yet. Wake up with your first alarm!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(proofRecords.prefix(5)) { record in
                    RecentCompletionRow(record: record)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Completion Status

enum CompletionStatus {
    case onTime
    case snoozed
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    let month: Date
    let completionData: [Date: CompletionStatus]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            // Day headers
            HStack {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            completionStatus: completionData[calendar.startOfDay(for: date)],
                            isToday: calendar.isDateInToday(date)
                        )
                    } else {
                        Text("")
                            .frame(height: 32)
                    }
                }
            }
        }
    }

    private var daysInMonth: [Date?] {
        let interval = calendar.dateInterval(of: .month, for: month)!
        let firstDay = interval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        var current = firstDay
        while current < interval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return days
    }
}

struct CalendarDayCell: View {
    let date: Date
    let completionStatus: CompletionStatus?
    let isToday: Bool

    private let calendar = Calendar.current

    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.subheadline)
            .fontWeight(isToday ? .bold : .regular)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(backgroundColor)
            )
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        if let status = completionStatus {
            switch status {
            case .onTime:
                return .green
            case .snoozed:
                return .orange
            }
        } else if isToday {
            return .accentColor.opacity(0.3)
        }
        return .clear
    }

    private var foregroundColor: Color {
        if completionStatus != nil {
            return .white
        }
        return .primary
    }
}

// MARK: - Recent Completion Row

struct RecentCompletionRow: View {
    let record: ProofRecord

    var body: some View {
        HStack {
            // Check icon
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.formattedDate)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    if record.wasOnTime {
                        Label("On time", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Label("Snoozed", systemImage: "moon.zzz")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    if record.qrCodeScanned {
                        Label("QR", systemImage: "qrcode")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
            }

            Spacer()

            // Difficulty level
            HStack(spacing: 2) {
                ForEach(0..<record.difficultyLevel, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                }
            }
            .foregroundStyle(.yellow)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    StreakView()
        .environment(ViewModel())
        .modelContainer(for: [ProofRecord.self, StreakData.self])
}
