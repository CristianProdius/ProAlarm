//
//  AppIntents.swift
//  ProAlarm
//
//  App Intents for Water Alarm Live Activities
//

import AlarmKit
import AppIntents
import SwiftData

// MARK: - Snooze Intent

struct SnoozeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze"
    static var description: IntentDescription = "Snooze the alarm for 3 minutes"

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID) else {
            throw NSError(domain: "Invalid UUID string", code: 0, userInfo: nil)
        }

        // Cancel current alarm (snooze will be handled by app when opened)
        try? AlarmManager.shared.cancel(id: uuid)

        return .result()
    }
}

// MARK: - Wake Up Intent (Opens App)

struct WakeUpIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Wake Up"
    static var description: IntentDescription = "Open the app to complete proof and stop alarm"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        // Just open the app - don't stop the alarm
        // User must complete proof in the app to stop
        return .result()
    }
}

// MARK: - Legacy Intents (for backwards compatibility)

struct PauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause"
    static var description: IntentDescription = "Pause a countdown"

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID) else {
            throw NSError(domain: "Invalid UUID string", code: 0, userInfo: nil)
        }

        try AlarmManager.shared.pause(id: uuid)
        return .result()
    }
}

struct StopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var description: IntentDescription = "Stop a countdown"

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID) else {
            throw NSError(domain: "Invalid UUID string", code: 0, userInfo: nil)
        }

        try AlarmManager.shared.stop(id: uuid)
        return .result()
    }
}

struct ResumeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume"
    static var description: IntentDescription = "Resume a countdown"

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID) else {
            throw NSError(domain: "Invalid UUID string", code: 0, userInfo: nil)
        }

        try AlarmManager.shared.resume(id: uuid)
        return .result()
    }
}

struct OpenAlarmAppIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open App"
    static var description: IntentDescription = "Opens the App"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        // Just open the app without stopping alarm
        return .result()
    }
}
