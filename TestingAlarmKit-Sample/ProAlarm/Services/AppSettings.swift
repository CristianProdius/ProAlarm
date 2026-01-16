//
//  AppSettings.swift
//  ProAlarm
//
//  UserDefaults wrapper for app settings
//

import Foundation
import UIKit

@Observable
class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let snoozeDuration = "snoozeDuration"
        static let defaultDifficulty = "defaultDifficulty"
        static let photoRetentionDays = "photoRetentionDays"
        static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
        static let preAlarmReminderEnabled = "preAlarmReminderEnabled"
        static let preAlarmReminderMinutes = "preAlarmReminderMinutes"
        // Apple Intelligence
        static let awakeDetectionEnabled = "awakeDetectionEnabled"
        static let aiMessagesEnabled = "aiMessagesEnabled"
        static let awakeSensitivity = "awakeSensitivity"
    }

    // MARK: - Snooze Duration

    var snoozeDuration: Int {
        get { defaults.integer(forKey: Keys.snoozeDuration).nonZeroOr(3) }
        set { defaults.set(newValue, forKey: Keys.snoozeDuration) }
    }

    static let snoozeDurationOptions = [1, 3, 5, 10]

    // MARK: - Default Difficulty

    var defaultDifficulty: Int {
        get { defaults.integer(forKey: Keys.defaultDifficulty).nonZeroOr(1) }
        set { defaults.set(newValue, forKey: Keys.defaultDifficulty) }
    }

    // MARK: - Photo Retention

    var photoRetentionDays: Int {
        get { defaults.integer(forKey: Keys.photoRetentionDays).nonZeroOr(7) }
        set { defaults.set(newValue, forKey: Keys.photoRetentionDays) }
    }

    static let photoRetentionOptions = [
        (days: 7, label: "1 Week"),
        (days: 14, label: "2 Weeks"),
        (days: 30, label: "1 Month"),
        (days: 0, label: "Forever")
    ]

    // MARK: - Haptic Feedback

    var hapticFeedbackEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.hapticFeedbackEnabled) == nil {
                return true // Default to enabled
            }
            return defaults.bool(forKey: Keys.hapticFeedbackEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.hapticFeedbackEnabled) }
    }

    // MARK: - Pre-Alarm Reminder

    var preAlarmReminderEnabled: Bool {
        get { defaults.bool(forKey: Keys.preAlarmReminderEnabled) }
        set { defaults.set(newValue, forKey: Keys.preAlarmReminderEnabled) }
    }

    var preAlarmReminderMinutes: Int {
        get { defaults.integer(forKey: Keys.preAlarmReminderMinutes).nonZeroOr(30) }
        set { defaults.set(newValue, forKey: Keys.preAlarmReminderMinutes) }
    }

    static let reminderMinuteOptions = [15, 30, 60]

    // MARK: - Apple Intelligence Settings

    var awakeDetectionEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.awakeDetectionEnabled) == nil {
                return true // Default to enabled
            }
            return defaults.bool(forKey: Keys.awakeDetectionEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.awakeDetectionEnabled) }
    }

    var aiMessagesEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.aiMessagesEnabled) == nil {
                return true // Default to enabled
            }
            return defaults.bool(forKey: Keys.aiMessagesEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.aiMessagesEnabled) }
    }

    var awakeSensitivity: Float {
        get {
            let value = defaults.float(forKey: Keys.awakeSensitivity)
            return value == 0 ? 0.7 : max(0.5, min(0.9, value)) // Default 0.7
        }
        set { defaults.set(max(0.5, min(0.9, newValue)), forKey: Keys.awakeSensitivity) }
    }

    // MARK: - Haptic Helper

    func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticFeedbackEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    private init() {}
}

// MARK: - Int Extension

private extension Int {
    func nonZeroOr(_ defaultValue: Int) -> Int {
        self == 0 ? defaultValue : self
    }
}
