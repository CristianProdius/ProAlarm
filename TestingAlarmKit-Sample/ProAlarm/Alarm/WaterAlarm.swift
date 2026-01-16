//
//  WaterAlarm.swift
//  ProAlarm
//
//  Water Alarm model for time-of-day alarms with proof requirements
//

import Foundation
import SwiftData

@Model
class WaterAlarm: Identifiable {
    @Attribute(.unique) var id = UUID()
    var label: String?

    // Time-of-day (stored as hour/minute)
    var alarmHour: Int          // 0-23
    var alarmMinute: Int        // 0-59

    // Repeat schedule (empty = one-time alarm)
    var repeatDays: [Int]       // [0-6] representing Sun-Sat
    var isEnabled: Bool

    // Proof settings
    var requiresPhoto: Bool
    var requiresQRCode: Bool
    var qrCodeIdentifier: String?

    // Snooze tracking (resets each firing)
    var snoozeUsed: Bool

    // Difficulty level (1-4)
    var difficultyLevel: Int

    var createdAt: Date

    // Track the AlarmKit alarm ID when scheduled
    var scheduledAlarmId: UUID?

    init(
        id: UUID = UUID(),
        label: String? = nil,
        alarmHour: Int = 7,
        alarmMinute: Int = 0,
        repeatDays: [Int] = [],
        isEnabled: Bool = true,
        requiresPhoto: Bool = true,
        requiresQRCode: Bool = false,
        qrCodeIdentifier: String? = nil,
        snoozeUsed: Bool = false,
        difficultyLevel: Int = 1,
        createdAt: Date = Date(),
        scheduledAlarmId: UUID? = nil
    ) {
        self.id = id
        self.label = label
        self.alarmHour = alarmHour
        self.alarmMinute = alarmMinute
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
        self.requiresPhoto = requiresPhoto
        self.requiresQRCode = requiresQRCode
        self.qrCodeIdentifier = qrCodeIdentifier
        self.snoozeUsed = snoozeUsed
        self.difficultyLevel = difficultyLevel
        self.createdAt = createdAt
        self.scheduledAlarmId = scheduledAlarmId
    }

    // Formatted time string (e.g., "7:00 AM")
    var formattedTime: String {
        let hour12 = alarmHour % 12 == 0 ? 12 : alarmHour % 12
        let period = alarmHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", hour12, alarmMinute, period)
    }

    // Formatted repeat days (e.g., "Mon, Wed, Fri" or "Every day")
    var formattedRepeatDays: String {
        if repeatDays.isEmpty {
            return "Once"
        }

        let sortedDays = repeatDays.sorted()

        if sortedDays == [0, 1, 2, 3, 4, 5, 6] {
            return "Every day"
        }

        if sortedDays == [1, 2, 3, 4, 5] {
            return "Weekdays"
        }

        if sortedDays == [0, 6] {
            return "Weekends"
        }

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return sortedDays.map { dayNames[$0] }.joined(separator: ", ")
    }

    // Check if snooze is allowed based on difficulty
    var snoozeAllowed: Bool {
        // Level 4 = no snooze allowed
        return difficultyLevel < 4
    }

    // Check if QR is required based on difficulty
    var qrRequiredForDifficulty: Bool {
        // Level 3 and 4 require QR
        return difficultyLevel >= 3
    }

    // Wait time in seconds based on difficulty
    var waitTimeForDifficulty: Int {
        // Level 2 and 4 require 10 second wait
        return (difficultyLevel == 2 || difficultyLevel == 4) ? 10 : 0
    }

    // Calculate next fire date from now
    func nextFireDate(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = alarmHour
        components.minute = alarmMinute
        components.second = 0

        guard let todayAlarmTime = calendar.date(from: components) else {
            return nil
        }

        // If no repeat days, check if today's time has passed
        if repeatDays.isEmpty {
            if todayAlarmTime > date {
                return todayAlarmTime
            } else {
                // Set for tomorrow
                return calendar.date(byAdding: .day, value: 1, to: todayAlarmTime)
            }
        }

        // Find next matching day
        let currentWeekday = calendar.component(.weekday, from: date) - 1 // 0 = Sunday
        let sortedDays = repeatDays.sorted()

        // Check if any remaining day this week
        for day in sortedDays {
            if day > currentWeekday || (day == currentWeekday && todayAlarmTime > date) {
                let daysToAdd = day - currentWeekday
                return calendar.date(byAdding: .day, value: daysToAdd, to: todayAlarmTime)
            }
        }

        // Wrap to next week
        if let firstDay = sortedDays.first {
            let daysToAdd = 7 - currentWeekday + firstDay
            return calendar.date(byAdding: .day, value: daysToAdd, to: todayAlarmTime)
        }

        return nil
    }
}
