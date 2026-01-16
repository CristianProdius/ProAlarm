//
//  AlarmManagementIntents.swift
//  ProAlarm
//
//  Siri App Intents for voice control of alarm management.
//  "Hey Siri, what's my alarm streak?"
//  "Hey Siri, when's my next alarm?"
//  "Hey Siri, turn off my morning alarm"
//

import AppIntents
import SwiftData

// MARK: - Get Streak Intent
// "Hey Siri, what's my alarm streak?"

struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Alarm Streak"
    static var description: IntentDescription = "Check your current wake-up streak"

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: StreakData.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<StreakData>()
        let streakRecords = try context.fetch(descriptor)

        guard let streakData = streakRecords.first else {
            return .result(dialog: "You haven't started tracking your wake-up streak yet. Complete your first alarm to begin!")
        }

        let streak = streakData.currentStreak
        let longest = streakData.longestStreak

        if streak == 0 {
            if longest > 0 {
                return .result(dialog: "Your streak is currently at zero. Your best streak was \(longest) days. Time to start a new one!")
            } else {
                return .result(dialog: "You don't have an active streak yet. Complete an alarm tomorrow morning to start!")
            }
        }

        var message = "You're on a \(streak)-day streak!"

        if streak == longest && streak >= 7 {
            message += " That's your best streak ever!"
        } else if longest > streak {
            message += " Your best is \(longest) days."
        }

        if streak >= 30 {
            message += " Amazing dedication!"
        } else if streak >= 7 {
            message += " Keep it up!"
        }

        return .result(dialog: "\(message)")
    }
}

// MARK: - Next Alarm Intent
// "Hey Siri, when's my next alarm?"

struct NextAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Next Alarm"
    static var description: IntentDescription = "Check when your next alarm is scheduled"

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: WaterAlarm.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<WaterAlarm>(
            predicate: #Predicate { $0.isEnabled }
        )
        let alarms = try context.fetch(descriptor)

        guard !alarms.isEmpty else {
            return .result(dialog: "You don't have any alarms set. Open ProAlarm to create one!")
        }

        // Find the next alarm based on current time
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now) - 1 // 0-6

        var nextAlarm: WaterAlarm?
        var nextAlarmMinutes: Int = Int.max

        for alarm in alarms {
            // Check if alarm is for today or a future day
            let alarmMinutes = alarm.alarmHour * 60 + alarm.alarmMinute
            let nowMinutes = currentHour * 60 + currentMinute

            if alarm.repeatDays.isEmpty {
                // One-time alarm
                if alarmMinutes > nowMinutes {
                    let diff = alarmMinutes - nowMinutes
                    if diff < nextAlarmMinutes {
                        nextAlarmMinutes = diff
                        nextAlarm = alarm
                    }
                }
            } else {
                // Repeating alarm - find next occurrence
                for dayOffset in 0..<7 {
                    let checkDay = (currentWeekday + dayOffset) % 7
                    if alarm.repeatDays.contains(checkDay) {
                        var diff = dayOffset * 24 * 60 + (alarmMinutes - nowMinutes)
                        if dayOffset == 0 && alarmMinutes <= nowMinutes {
                            continue // Already passed today
                        }
                        if diff < 0 {
                            diff += 7 * 24 * 60 // Next week
                        }
                        if diff < nextAlarmMinutes {
                            nextAlarmMinutes = diff
                            nextAlarm = alarm
                        }
                        break
                    }
                }
            }
        }

        guard let alarm = nextAlarm else {
            return .result(dialog: "All your alarms have already passed for today. Check back tomorrow!")
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let alarmDate = calendar.date(
            bySettingHour: alarm.alarmHour,
            minute: alarm.alarmMinute,
            second: 0,
            of: now
        ) ?? now

        let timeString = timeFormatter.string(from: alarmDate)

        // Calculate relative time
        let hours = nextAlarmMinutes / 60
        let minutes = nextAlarmMinutes % 60

        var relativeTime = ""
        if hours > 0 {
            relativeTime = "\(hours) hour\(hours == 1 ? "" : "s")"
            if minutes > 0 {
                relativeTime += " and \(minutes) minute\(minutes == 1 ? "" : "s")"
            }
        } else {
            relativeTime = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }

        let label = alarm.label?.isEmpty == false ? " (\(alarm.label!))" : ""

        return .result(dialog: "Your next alarm\(label) is at \(timeString), in about \(relativeTime).")
    }
}

// MARK: - Toggle Alarm Intent
// "Hey Siri, turn off my morning alarm"

struct ToggleAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Alarm"
    static var description: IntentDescription = "Enable or disable an alarm"

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Alarm Name", description: "The label of the alarm to toggle")
    var alarmName: String?

    @Parameter(title: "Enable", description: "Whether to enable or disable the alarm")
    var enable: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Turn \(\.$alarmName) alarm \(\.$enable)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: WaterAlarm.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<WaterAlarm>()
        let alarms = try context.fetch(descriptor)

        // Find matching alarm by name
        var targetAlarm: WaterAlarm?

        if let name = alarmName?.lowercased() {
            targetAlarm = alarms.first { alarm in
                alarm.label?.lowercased().contains(name) == true
            }
        }

        // If no name specified or not found, use the first alarm
        if targetAlarm == nil && alarms.count == 1 {
            targetAlarm = alarms.first
        }

        guard let alarm = targetAlarm else {
            if alarms.isEmpty {
                return .result(dialog: "You don't have any alarms set up yet.")
            } else {
                return .result(dialog: "I couldn't find an alarm with that name. Try specifying the exact alarm label.")
            }
        }

        alarm.isEnabled = enable
        try context.save()

        let actionWord = enable ? "enabled" : "disabled"
        let label = alarm.label?.isEmpty == false ? "\(alarm.label!) alarm" : "alarm"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let alarmDate = Calendar.current.date(
            bySettingHour: alarm.alarmHour,
            minute: alarm.alarmMinute,
            second: 0,
            of: Date()
        ) ?? Date()
        let timeString = timeFormatter.string(from: alarmDate)

        return .result(dialog: "Your \(label) at \(timeString) has been \(actionWord).")
    }
}

// MARK: - Get Stats Intent
// "Hey Siri, how am I doing with my alarms?"

struct GetStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Alarm Stats"
    static var description: IntentDescription = "Get your alarm completion statistics"

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: StreakData.self, ProofRecord.self)
        let context = ModelContext(container)

        // Fetch streak data
        let streakDescriptor = FetchDescriptor<StreakData>()
        let streakRecords = try context.fetch(streakDescriptor)
        let streakData = streakRecords.first

        // Fetch recent completions
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let proofDescriptor = FetchDescriptor<ProofRecord>(
            predicate: #Predicate { $0.completedAt >= oneWeekAgo }
        )
        let recentRecords = try context.fetch(proofDescriptor)

        let weeklyCompletions = recentRecords.count
        let onTimeCount = recentRecords.filter { $0.wasOnTime }.count
        let onTimeRate = weeklyCompletions > 0 ?
            Int(Double(onTimeCount) / Double(weeklyCompletions) * 100) : 0

        var message = "This week you've completed \(weeklyCompletions) alarm\(weeklyCompletions == 1 ? "" : "s")"

        if weeklyCompletions > 0 {
            message += " with a \(onTimeRate)% on-time rate."
        } else {
            message += "."
        }

        if let streak = streakData, streak.currentStreak > 0 {
            message += " You're on a \(streak.currentStreak)-day streak!"
        }

        return .result(dialog: "\(message)")
    }
}

// MARK: - Create Alarm Intent
// "Hey Siri, set an alarm for 7 AM"

struct CreateAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Alarm"
    static var description: IntentDescription = "Create a new wake-up alarm"

    static var openAppWhenRun: Bool = true  // Open app to complete setup

    @Parameter(title: "Hour", description: "The hour for the alarm (1-12 or 0-23)")
    var hour: Int

    @Parameter(title: "Minute", description: "The minute for the alarm (0-59)")
    var minute: Int?

    @Parameter(title: "AM/PM", description: "Morning or evening")
    var isPM: Bool?

    @Parameter(title: "Label", description: "A name for this alarm")
    var label: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Set alarm for \(\.$hour):\(\.$minute) \(\.$isPM) called \(\.$label)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let container = try ModelContainer(for: WaterAlarm.self)
        let context = ModelContext(container)

        var alarmHour = hour
        let alarmMinute = minute ?? 0

        // Convert to 24-hour format if needed
        if let pm = isPM {
            if pm && alarmHour < 12 {
                alarmHour += 12
            } else if !pm && alarmHour == 12 {
                alarmHour = 0
            }
        }

        // Validate
        guard alarmHour >= 0 && alarmHour < 24 && alarmMinute >= 0 && alarmMinute < 60 else {
            return .result(
                opensIntent: OpenAlarmAppIntent(alarmID: ""),
                dialog: "Invalid time. Please specify a valid hour and minute."
            )
        }

        let alarm = WaterAlarm(
            label: label,
            alarmHour: alarmHour,
            alarmMinute: alarmMinute,
            repeatDays: [],
            isEnabled: true
        )

        context.insert(alarm)
        try context.save()

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let alarmDate = Calendar.current.date(
            bySettingHour: alarmHour,
            minute: alarmMinute,
            second: 0,
            of: Date()
        ) ?? Date()
        let timeString = timeFormatter.string(from: alarmDate)

        let labelText = label != nil ? " called \(label!)" : ""

        return .result(
            opensIntent: OpenAlarmAppIntent(alarmID: alarm.id.uuidString),
            dialog: "I've created an alarm for \(timeString)\(labelText). Opening ProAlarm to finish setup."
        )
    }
}
