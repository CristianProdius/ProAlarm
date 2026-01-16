//
//  WaterAlarmMetadata.swift
//  ProAlarm
//
//  AlarmKit metadata for Water Alarm
//

import AlarmKit

// Build Settings -> Swift Compiler - Concurrency -> Default Actor -> nonisolated
// Set this struct to nonisolated - Allows it to run on any thread, not confined to a specific actor
// Sendable - Indicates the type is safe to pass between concurrency domains (e.g., tasks or actors)
nonisolated struct WaterAlarmData: AlarmMetadata {
    let alarmId: UUID
    let waterAlarmId: UUID      // Reference to WaterAlarm model
    let alarmHour: Int
    let alarmMinute: Int
    let label: String?
    let requiresPhoto: Bool
    let requiresQRCode: Bool
    let qrCodeIdentifier: String?
    let difficultyLevel: Int
    let snoozeAllowed: Bool
    let isSnooze: Bool          // True if this is a snoozed alarm

    init(
        alarmId: UUID = UUID(),
        waterAlarmId: UUID,
        alarmHour: Int,
        alarmMinute: Int,
        label: String? = nil,
        requiresPhoto: Bool = true,
        requiresQRCode: Bool = false,
        qrCodeIdentifier: String? = nil,
        difficultyLevel: Int = 1,
        snoozeAllowed: Bool = true,
        isSnooze: Bool = false
    ) {
        self.alarmId = alarmId
        self.waterAlarmId = waterAlarmId
        self.alarmHour = alarmHour
        self.alarmMinute = alarmMinute
        self.label = label
        self.requiresPhoto = requiresPhoto
        self.requiresQRCode = requiresQRCode
        self.qrCodeIdentifier = qrCodeIdentifier
        self.difficultyLevel = difficultyLevel
        self.snoozeAllowed = snoozeAllowed
        self.isSnooze = isSnooze
    }

    // Create from WaterAlarm model
    static func from(_ alarm: WaterAlarm, isSnooze: Bool = false) -> WaterAlarmData {
        WaterAlarmData(
            alarmId: UUID(),
            waterAlarmId: alarm.id,
            alarmHour: alarm.alarmHour,
            alarmMinute: alarm.alarmMinute,
            label: alarm.label,
            requiresPhoto: alarm.requiresPhoto,
            requiresQRCode: alarm.requiresQRCode || alarm.qrRequiredForDifficulty,
            qrCodeIdentifier: alarm.qrCodeIdentifier,
            difficultyLevel: alarm.difficultyLevel,
            snoozeAllowed: alarm.snoozeAllowed && !alarm.snoozeUsed,
            isSnooze: isSnooze
        )
    }

    // Formatted time string
    var formattedTime: String {
        let hour12 = alarmHour % 12 == 0 ? 12 : alarmHour % 12
        let period = alarmHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", hour12, alarmMinute, period)
    }
}
