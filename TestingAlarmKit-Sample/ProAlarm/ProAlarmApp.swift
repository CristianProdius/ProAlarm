//
//  ProAlarmApp.swift
//  ProAlarm
//
//  Water Alarm App Entry Point
//

import SwiftUI
import SwiftData
import AVFoundation
import AppIntents

@main
struct ProAlarmApp: App {
    // Register App Shortcuts for Siri
    static var appShortcutsProvider: any AppShortcutsProvider.Type {
        AlarmShortcuts.self
    }
    let container: ModelContainer

    init() {
        // Include all Water Alarm models
        let schema = Schema([
            WaterAlarm.self,
            ProofRecord.self,
            StreakData.self,
            UnlockedAchievement.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, allowsSave: true)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("Model Container created successfully.")
        } catch {
            fatalError("Could not create Model Container: \(error.localizedDescription)")
        }

        // Configure audio session for alarm sounds
        configureAudioSession()
    }

    var body: some Scene {
        let viewModel = ViewModel()

        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
        .modelContainer(container)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}
