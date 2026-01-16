//
//  SettingsView.swift
//  ProAlarm
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Alarm Defaults
                Section {
                    Picker("Snooze Duration", selection: $settings.snoozeDuration) {
                        ForEach(AppSettings.snoozeDurationOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }

                    Picker("Default Difficulty", selection: $settings.defaultDifficulty) {
                        Text("Level 1 - Easy").tag(1)
                        Text("Level 2 - Medium").tag(2)
                        Text("Level 3 - Hard").tag(3)
                        Text("Level 4 - Extreme").tag(4)
                    }
                } header: {
                    Text("Alarm Defaults")
                } footer: {
                    Text("These settings apply to new alarms.")
                }

                // MARK: - Reminders
                Section {
                    Toggle("Pre-Alarm Reminder", isOn: $settings.preAlarmReminderEnabled)

                    if settings.preAlarmReminderEnabled {
                        Picker("Reminder Time", selection: $settings.preAlarmReminderMinutes) {
                            ForEach(AppSettings.reminderMinuteOptions, id: \.self) { minutes in
                                Text("\(minutes) min before").tag(minutes)
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Get a notification before your alarm rings.")
                }

                // MARK: - Storage
                Section {
                    Picker("Keep Proof Photos", selection: $settings.photoRetentionDays) {
                        ForEach(AppSettings.photoRetentionOptions, id: \.days) { option in
                            Text(option.label).tag(option.days)
                        }
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Old proof photos will be automatically deleted.")
                }

                // MARK: - Feedback
                Section {
                    Toggle("Haptic Feedback", isOn: $settings.hapticFeedbackEnabled)
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Vibration feedback when completing actions.")
                }

                // MARK: - Apple Intelligence
                Section {
                    Toggle("Awake Detection", isOn: $settings.awakeDetectionEnabled)

                    if settings.awakeDetectionEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sensitivity")
                                Spacer()
                                Text(sensitivityLabel)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.awakeSensitivity, in: 0.5...0.9, step: 0.1)
                        }
                    }

                    Toggle("AI Messages", isOn: $settings.aiMessagesEnabled)
                } header: {
                    Label("Apple Intelligence", systemImage: "brain.head.profile")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Awake Detection uses the camera to verify your eyes are open when taking proof photos.")
                        if settings.awakeDetectionEnabled {
                            Text("Higher sensitivity requires clearer eye visibility.")
                        }
                        Text("AI Messages generates personalized wake-up motivation using on-device intelligence.")
                    }
                }

                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // MARK: - Danger Zone
                Section {
                    Button("Reset All Settings", role: .destructive) {
                        resetSettings()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var sensitivityLabel: String {
        switch settings.awakeSensitivity {
        case 0.5..<0.6: return "Low"
        case 0.6..<0.7: return "Medium-Low"
        case 0.7..<0.8: return "Medium"
        case 0.8..<0.9: return "Medium-High"
        default: return "High"
        }
    }

    private func resetSettings() {
        settings.snoozeDuration = 3
        settings.defaultDifficulty = 1
        settings.photoRetentionDays = 7
        settings.hapticFeedbackEnabled = true
        settings.preAlarmReminderEnabled = false
        settings.preAlarmReminderMinutes = 30
        // Apple Intelligence
        settings.awakeDetectionEnabled = true
        settings.aiMessagesEnabled = true
        settings.awakeSensitivity = 0.7
    }
}

#Preview {
    SettingsView()
}
