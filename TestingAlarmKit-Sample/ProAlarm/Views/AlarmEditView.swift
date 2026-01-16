//
//  AlarmEditView.swift
//  ProAlarm
//
//  View for creating and editing water alarms
//

import SwiftUI
import SwiftData

struct AlarmEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ViewModel.self) var viewModel

    // Alarm being edited (nil for new alarm)
    let alarm: WaterAlarm?

    // Form state
    @State private var alarmHour: Int = 7
    @State private var alarmMinute: Int = 0
    @State private var label: String = ""
    @State private var repeatDays: Set<Int> = []
    @State private var requiresPhoto: Bool = true
    @State private var requiresQRCode: Bool = false
    @State private var qrCodeIdentifier: String?
    @State private var difficultyLevel: Int = 1

    @State private var showQRSetup = false
    @State private var selectedTime = Date()

    private var isNewAlarm: Bool { alarm == nil }

    var body: some View {
        NavigationStack {
            Form {
                // Time Picker Section
                Section {
                    DatePicker(
                        "Alarm Time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                // Label Section
                Section("Label") {
                    TextField("Alarm name (optional)", text: $label)
                }

                // Repeat Days Section
                Section("Repeat") {
                    RepeatDaySelector(selectedDays: $repeatDays)
                }

                // Proof Requirements Section
                Section("Proof Requirements") {
                    Toggle("Photo Required", isOn: $requiresPhoto)

                    Toggle("QR Code Required", isOn: $requiresQRCode)

                    if requiresQRCode {
                        Button {
                            showQRSetup = true
                        } label: {
                            HStack {
                                Text("Setup QR Code")
                                Spacer()
                                if qrCodeIdentifier != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                }

                // Difficulty Section
                Section {
                    Picker("Difficulty Level", selection: $difficultyLevel) {
                        Text("Easy").tag(1)
                        Text("Medium").tag(2)
                        Text("Hard").tag(3)
                        Text("Extreme").tag(4)
                    }
                } header: {
                    Text("Difficulty")
                } footer: {
                    Text(difficultyDescription)
                        .font(.caption)
                }

                // Delete Button (for existing alarms)
                if !isNewAlarm {
                    Section {
                        Button(role: .destructive) {
                            deleteAlarm()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Alarm")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNewAlarm ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAlarm()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showQRSetup) {
                QRCodeSetupView(qrCodeIdentifier: $qrCodeIdentifier)
            }
            .onAppear {
                loadAlarmData()
            }
            .onChange(of: selectedTime) { _, newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                alarmHour = components.hour ?? 7
                alarmMinute = components.minute ?? 0
            }
        }
    }

    private var difficultyDescription: String {
        switch difficultyLevel {
        case 1:
            return "Photo proof only. Snooze allowed."
        case 2:
            return "Photo proof + 10 second wait. Snooze allowed."
        case 3:
            return "Photo + QR scan required. Snooze allowed."
        case 4:
            return "Photo + QR scan + 10 second wait. No snooze!"
        default:
            return ""
        }
    }

    private func loadAlarmData() {
        guard let existingAlarm = alarm else {
            // Set default time to next hour
            let now = Date()
            let components = Calendar.current.dateComponents([.hour, .minute], from: now)
            alarmHour = (components.hour ?? 7) + 1
            if alarmHour >= 24 { alarmHour = 7 }
            alarmMinute = 0
            updateSelectedTime()
            return
        }

        alarmHour = existingAlarm.alarmHour
        alarmMinute = existingAlarm.alarmMinute
        label = existingAlarm.label ?? ""
        repeatDays = Set(existingAlarm.repeatDays)
        requiresPhoto = existingAlarm.requiresPhoto
        requiresQRCode = existingAlarm.requiresQRCode
        qrCodeIdentifier = existingAlarm.qrCodeIdentifier
        difficultyLevel = existingAlarm.difficultyLevel

        updateSelectedTime()
    }

    private func updateSelectedTime() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = alarmHour
        components.minute = alarmMinute
        selectedTime = Calendar.current.date(from: components) ?? Date()
    }

    private func saveAlarm() {
        let waterAlarm: WaterAlarm

        if let existingAlarm = alarm {
            // Update existing
            existingAlarm.alarmHour = alarmHour
            existingAlarm.alarmMinute = alarmMinute
            existingAlarm.label = label.isEmpty ? nil : label
            existingAlarm.repeatDays = Array(repeatDays).sorted()
            existingAlarm.requiresPhoto = requiresPhoto
            existingAlarm.requiresQRCode = requiresQRCode
            existingAlarm.qrCodeIdentifier = qrCodeIdentifier
            existingAlarm.difficultyLevel = difficultyLevel
            waterAlarm = existingAlarm
        } else {
            // Create new
            waterAlarm = WaterAlarm(
                label: label.isEmpty ? nil : label,
                alarmHour: alarmHour,
                alarmMinute: alarmMinute,
                repeatDays: Array(repeatDays).sorted(),
                isEnabled: true,
                requiresPhoto: requiresPhoto,
                requiresQRCode: requiresQRCode,
                qrCodeIdentifier: qrCodeIdentifier,
                difficultyLevel: difficultyLevel
            )
        }

        viewModel.saveWaterAlarm(waterAlarm)
        dismiss()
    }

    private func deleteAlarm() {
        guard let existingAlarm = alarm else { return }
        viewModel.deleteWaterAlarm(existingAlarm)
        dismiss()
    }
}

// MARK: - Repeat Day Selector

struct RepeatDaySelector: View {
    @Binding var selectedDays: Set<Int>

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { day in
                    DayButton(
                        label: dayLabels[day],
                        isSelected: selectedDays.contains(day)
                    ) {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Quick select buttons
            HStack(spacing: 12) {
                QuickSelectButton(title: "Weekdays") {
                    selectedDays = [1, 2, 3, 4, 5]
                }
                QuickSelectButton(title: "Weekends") {
                    selectedDays = [0, 6]
                }
                QuickSelectButton(title: "Every Day") {
                    selectedDays = [0, 1, 2, 3, 4, 5, 6]
                }
                QuickSelectButton(title: "Clear") {
                    selectedDays = []
                }
            }
        }
    }
}

struct DayButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundStyle(isSelected ? .white : .gray)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct QuickSelectButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AlarmEditView(alarm: nil)
        .environment(ViewModel())
        .modelContainer(for: [WaterAlarm.self])
}
