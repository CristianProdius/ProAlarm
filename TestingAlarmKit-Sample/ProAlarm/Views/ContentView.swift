//
//  ContentView.swift
//  ProAlarm
//
//  Main view showing alarm list and navigation
//

import SwiftUI
import AlarmKit
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ViewModel.self) var viewModel
    @Environment(\.scenePhase) var scenePhase

    @Query(sort: [SortDescriptor(\WaterAlarm.alarmHour), SortDescriptor(\WaterAlarm.alarmMinute)])
    private var alarms: [WaterAlarm]

    @State private var showAlarmEditor = false
    @State private var editingAlarm: WaterAlarm?
    @State private var showStreakView = false
    @State private var showSettings = false
    @State private var alarmToDelete: WaterAlarm?
    @State private var showDeleteConfirmation = false
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Show ringing view if alarm is firing
                if viewModel.currentlyRingingAlarm != nil {
                    RingingView()
                } else {
                    mainContent
                }
            }
            .navigationTitle("Water Alarm")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        streakButton
                        settingsButton
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showAlarmEditor) {
                AlarmEditView(alarm: editingAlarm)
            }
            .sheet(isPresented: $showStreakView) {
                StreakView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Delete Alarm?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    alarmToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let alarm = alarmToDelete {
                        viewModel.deleteWaterAlarm(alarm)
                        alarmToDelete = nil
                    }
                }
            } message: {
                if let alarm = alarmToDelete {
                    Text("Delete the alarm for \(alarm.formattedTime)?\(alarm.label.map { " (\($0))" } ?? "")")
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unexpected error occurred.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.setupModelContext(modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Check for missed days when app becomes active
                viewModel.streakData?.checkForMissedDay()
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if alarms.isEmpty {
            emptyState
        } else {
            alarmList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 80))
                .foregroundStyle(.gray.opacity(0.5))

            Text("No Alarms")
                .font(.title2)
                .foregroundStyle(.gray)

            Text("Tap + to create your first water alarm")
                .font(.subheadline)
                .foregroundStyle(.gray.opacity(0.7))

            Button {
                editingAlarm = nil
                showAlarmEditor = true
            } label: {
                Label("Add Alarm", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var alarmList: some View {
        List {
            ForEach(alarms) { alarm in
                AlarmListCell(alarm: alarm)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingAlarm = alarm
                        showAlarmEditor = true
                    }
            }
            .onDelete(perform: deleteAlarms)
        }
        .listStyle(.plain)
    }

    private var addButton: some View {
        Button {
            editingAlarm = nil
            showAlarmEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
        }
    }

    private var streakButton: some View {
        Button {
            showStreakView = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(viewModel.streakData?.currentStreak ?? 0)")
                    .fontWeight(.semibold)
            }
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(.gray)
        }
    }

    private func deleteAlarms(at offsets: IndexSet) {
        // Get the first alarm to delete and show confirmation
        if let index = offsets.first {
            alarmToDelete = alarms[index]
            showDeleteConfirmation = true
        }
    }
}

// MARK: - Alarm List Cell

struct AlarmListCell: View {
    @Bindable var alarm: WaterAlarm
    @Environment(ViewModel.self) var viewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Time display
                Text(alarm.formattedTime)
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .foregroundStyle(alarm.isEnabled ? .white : .gray)

                // Label and repeat info
                HStack(spacing: 8) {
                    if let label = alarm.label, !label.isEmpty {
                        Text(label)
                            .font(.subheadline)
                            .foregroundStyle(alarm.isEnabled ? .white.opacity(0.8) : .gray.opacity(0.6))
                    }

                    Text(alarm.formattedRepeatDays)
                        .font(.caption)
                        .foregroundStyle(alarm.isEnabled ? .white.opacity(0.5) : .gray.opacity(0.4))
                }

                // Proof requirements indicator
                HStack(spacing: 6) {
                    if alarm.requiresPhoto {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan.opacity(0.7))
                    }
                    if alarm.requiresQRCode {
                        Image(systemName: "qrcode")
                            .font(.caption2)
                            .foregroundStyle(.purple.opacity(0.7))
                    }
                    if alarm.difficultyLevel > 1 {
                        HStack(spacing: 2) {
                            ForEach(0..<alarm.difficultyLevel, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundStyle(.yellow.opacity(0.7))
                    }
                }
            }

            Spacer()

            // Toggle switch
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in viewModel.toggleAlarm(alarm) }
            ))
            .labelsHidden()
            .tint(.green)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
        .environment(ViewModel())
        .modelContainer(for: [WaterAlarm.self, ProofRecord.self, StreakData.self])
}
