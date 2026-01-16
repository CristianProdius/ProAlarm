//
//  AlarmShortcuts.swift
//  ProAlarm
//
//  Registers App Shortcuts for the Shortcuts app and Siri suggestions.
//

import AppIntents

struct AlarmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "What's my alarm streak in \(.applicationName)",
                "Check my \(.applicationName) streak",
                "How's my wake-up streak in \(.applicationName)",
                "What is my \(.applicationName) streak"
            ],
            shortTitle: "Check Streak",
            systemImageName: "flame.fill"
        )

        AppShortcut(
            intent: NextAlarmIntent(),
            phrases: [
                "When's my next alarm in \(.applicationName)",
                "What time is my \(.applicationName) alarm",
                "Next alarm in \(.applicationName)",
                "When does my \(.applicationName) go off"
            ],
            shortTitle: "Next Alarm",
            systemImageName: "alarm.fill"
        )

        AppShortcut(
            intent: GetStatsIntent(),
            phrases: [
                "How am I doing with \(.applicationName)",
                "Show my \(.applicationName) stats",
                "My \(.applicationName) statistics",
                "Check my alarm stats in \(.applicationName)"
            ],
            shortTitle: "View Stats",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: ToggleAlarmIntent(),
            phrases: [
                "Turn off my \(.applicationName) alarm",
                "Disable my alarm in \(.applicationName)",
                "Turn on my \(.applicationName) alarm",
                "Enable my alarm in \(.applicationName)"
            ],
            shortTitle: "Toggle Alarm",
            systemImageName: "power"
        )
    }
}
