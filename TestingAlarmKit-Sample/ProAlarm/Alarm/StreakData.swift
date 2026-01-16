//
//  StreakData.swift
//  ProAlarm
//
//  Tracks streak and statistics for alarm completions
//

import Foundation
import SwiftData

@Model
class StreakData: Identifiable {
    @Attribute(.unique) var id = UUID()

    // Current consecutive days streak
    var currentStreak: Int

    // Longest streak ever achieved
    var longestStreak: Int

    // Date of last completion (for streak calculation)
    var lastCompletionDate: Date?

    // Total number of completions all time
    var totalCompletions: Int

    // Total missed alarms (for difficulty adjustment)
    var missedCount: Int

    init(
        id: UUID = UUID(),
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletionDate: Date? = nil,
        totalCompletions: Int = 0,
        missedCount: Int = 0
    ) {
        self.id = id
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletionDate = lastCompletionDate
        self.totalCompletions = totalCompletions
        self.missedCount = missedCount
    }

    // Record a new completion
    func recordCompletion() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = lastCompletionDate {
            let lastDay = calendar.startOfDay(for: lastDate)

            // Check if this is consecutive
            if let dayAfterLast = calendar.date(byAdding: .day, value: 1, to: lastDay),
               calendar.isDate(dayAfterLast, inSameDayAs: today) {
                // Consecutive day - increment streak
                currentStreak += 1
            } else if calendar.isDate(lastDay, inSameDayAs: today) {
                // Same day - don't increment (already counted)
                return
            } else {
                // Streak broken - reset to 1
                currentStreak = 1
            }
        } else {
            // First completion
            currentStreak = 1
        }

        // Update longest streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        // Update last completion date and total
        lastCompletionDate = Date()
        totalCompletions += 1
    }

    // Check and handle missed day (call on app launch)
    func checkForMissedDay() {
        guard let lastDate = lastCompletionDate else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)

        // If more than 1 day has passed, streak is broken
        if let dayAfterLast = calendar.date(byAdding: .day, value: 1, to: lastDay),
           today > dayAfterLast {
            currentStreak = 0
            missedCount += 1
        }
    }

    // Calculate recommended difficulty adjustment
    func recommendedDifficultyChange() -> Int {
        // If missed recently, suggest increasing difficulty
        let calendar = Calendar.current

        if let lastDate = lastCompletionDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let today = calendar.startOfDay(for: Date())

            // Missed yesterday
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               lastDay < yesterday {
                return 1 // Increase difficulty
            }
        }

        // Consistent for 3+ days, suggest decreasing
        if currentStreak >= 3 {
            return -1 // Decrease difficulty
        }

        return 0 // No change
    }

    // Streak status message
    var streakMessage: String {
        if currentStreak == 0 {
            return "Start your streak today!"
        } else if currentStreak == 1 {
            return "1 day - Keep it going!"
        } else {
            return "\(currentStreak) days in a row!"
        }
    }

    // Check if completed yesterday (for AI motivation context)
    var wasCompletedYesterday: Bool {
        guard let lastDate = lastCompletionDate else { return false }
        let calendar = Calendar.current
        return calendar.isDateInYesterday(lastDate) || calendar.isDateInToday(lastDate)
    }
}
