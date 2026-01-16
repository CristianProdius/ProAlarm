//
//  ViewModel.swift
//  ProAlarm
//
//  Main view model for Water Alarm app
//

import AlarmKit
import SwiftUI
import ActivityKit
import SwiftData

@Observable
class ViewModel {
    typealias AlarmConfiguration = AlarmManager.AlarmConfiguration<WaterAlarmData>
    typealias AlarmsMap = [UUID: (Alarm, WaterAlarmData)]
    typealias AlarmActivity = Activity<AlarmAttributes<WaterAlarmData>>

    // MARK: - Alarm State
    @MainActor var alarmsMap = AlarmsMap()
    @ObservationIgnored private let alarmManager = AlarmManager.shared
    @ObservationIgnored var modelContext: ModelContext?

    @MainActor var hasScheduledAlarms: Bool {
        !alarmsMap.isEmpty
    }

    @MainActor var activity: Activity<AlarmAttributes<WaterAlarmData>>?

    // MARK: - Ringing State
    @MainActor var currentlyRingingAlarm: WaterAlarm?
    @MainActor var currentRingingMetadata: WaterAlarmData?
    @MainActor var isProofCompleted: Bool = false
    @MainActor var ringingStartTime: Date?
    @MainActor var capturedProofPhoto: UIImage?
    @MainActor var isQRVerified: Bool = false
    @MainActor var waitTimeRemaining: Int = 0
    @ObservationIgnored private var waitTimeTask: Task<Void, Never>?

    // MARK: - Apple Intelligence State
    @MainActor var awakenessValidationState: ValidationState = .idle
    @MainActor var validationRetryCount: Int = 0
    @MainActor var lastAwakenessScore: Float?
    @MainActor var validationBypassed: Bool = false
    @MainActor var motivationalMessage: String?
    @ObservationIgnored let awakenessValidator = AwakenessValidator(sensitivity: AppSettings.shared.awakeSensitivity)
    @ObservationIgnored let motivationGenerator = MotivationGenerator()

    // MARK: - Error State
    @MainActor var errorMessage: String?

    // MARK: - Streak Data
    @MainActor var streakData: StreakData?

    // MARK: - Initialization

    init() {
        observeAlarms()
    }

    // MARK: - Model Context Setup

    func setupModelContext(_ context: ModelContext) {
        self.modelContext = context
        Task { @MainActor in
            loadStreakData()
            cleanupOldProofPhotos()
        }
    }

    // MARK: - Water Alarm Management

    /// Fetch all water alarms from SwiftData
    @MainActor
    func fetchWaterAlarms() -> [WaterAlarm] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<WaterAlarm>(sortBy: [SortDescriptor(\.alarmHour), SortDescriptor(\.alarmMinute)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Save a new or updated water alarm
    @MainActor
    func saveWaterAlarm(_ alarm: WaterAlarm) {
        guard let context = modelContext else { return }

        // Check if alarm already exists
        let alarmId = alarm.id
        let existingDescriptor = FetchDescriptor<WaterAlarm>(predicate: #Predicate { $0.id == alarmId })
        if let existing = try? context.fetch(existingDescriptor).first {
            // Update existing
            existing.label = alarm.label
            existing.alarmHour = alarm.alarmHour
            existing.alarmMinute = alarm.alarmMinute
            existing.repeatDays = alarm.repeatDays
            existing.isEnabled = alarm.isEnabled
            existing.requiresPhoto = alarm.requiresPhoto
            existing.requiresQRCode = alarm.requiresQRCode
            existing.qrCodeIdentifier = alarm.qrCodeIdentifier
            existing.difficultyLevel = alarm.difficultyLevel
        } else {
            // Insert new
            context.insert(alarm)
        }

        try? context.save()

        // Schedule or unschedule based on enabled state
        if alarm.isEnabled {
            scheduleWaterAlarm(alarm)
        } else {
            unscheduleWaterAlarm(alarm)
        }
    }

    /// Delete a water alarm
    @MainActor
    func deleteWaterAlarm(_ alarm: WaterAlarm) {
        guard let context = modelContext else { return }

        // Unschedule first
        unscheduleWaterAlarm(alarm)

        // Delete from SwiftData
        let alarmId = alarm.id
        let descriptor = FetchDescriptor<WaterAlarm>(predicate: #Predicate { $0.id == alarmId })
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    /// Toggle alarm enabled state
    @MainActor
    func toggleAlarm(_ alarm: WaterAlarm) {
        alarm.isEnabled.toggle()

        if alarm.isEnabled {
            scheduleWaterAlarm(alarm)
        } else {
            unscheduleWaterAlarm(alarm)
        }

        try? modelContext?.save()
    }

    // MARK: - AlarmKit Scheduling

    /// Calculate seconds until the target time (hour:minute)
    private func secondsUntilTime(hour: Int, minute: Int) -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()

        var targetComponents = calendar.dateComponents([.year, .month, .day], from: now)
        targetComponents.hour = hour
        targetComponents.minute = minute
        targetComponents.second = 0

        guard var targetDate = calendar.date(from: targetComponents) else {
            return 60 // Fallback: 1 minute
        }

        // If target time has passed today, schedule for tomorrow
        if targetDate <= now {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }

        return targetDate.timeIntervalSince(now)
    }

    /// Schedule a water alarm with AlarmKit
    func scheduleWaterAlarm(_ alarm: WaterAlarm) {
        let metadata = WaterAlarmData.from(alarm)
        let attributes = AlarmAttributes(
            presentation: alarmPresentation(for: alarm),
            metadata: metadata,
            tintColor: Color.accentColor
        )

        let id = UUID()
        let duration = secondsUntilTime(hour: alarm.alarmHour, minute: alarm.alarmMinute)
        let sound = AlertConfiguration.AlertSound.default

        let alarmConfiguration = AlarmConfiguration(
            countdownDuration: .init(preAlert: duration, postAlert: nil),
            attributes: attributes,
            sound: sound
        )

        Task {
            do {
                guard await requestAuthorization() else {
                    await MainActor.run {
                        errorMessage = "Unable to schedule alarm. Please enable alarm permissions in Settings."
                    }
                    print("Not authorized to schedule alarm")
                    return
                }

                let scheduledAlarm = try await alarmManager.schedule(id: id, configuration: alarmConfiguration)

                await MainActor.run {
                    alarmsMap[id] = (scheduledAlarm, metadata)
                    alarm.scheduledAlarmId = id
                    try? modelContext?.save()
                    print("Scheduled water alarm \(id) for \(alarm.formattedTime) in \(Int(duration/60)) minutes")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to schedule alarm. Please try again."
                }
                print("Error scheduling alarm: \(error)")
            }
        }
    }

    /// Unschedule a water alarm
    func unscheduleWaterAlarm(_ alarm: WaterAlarm) {
        guard let scheduledId = alarm.scheduledAlarmId else { return }

        try? alarmManager.cancel(id: scheduledId)

        Task { @MainActor in
            alarmsMap[scheduledId] = nil
            alarm.scheduledAlarmId = nil
            try? modelContext?.save()
            print("Unscheduled water alarm \(scheduledId)")
        }
    }

    /// Unschedule by AlarmKit ID
    func unscheduleAlarm(with alarmID: UUID) {
        try? alarmManager.cancel(id: alarmID)
        Task { @MainActor in
            alarmsMap[alarmID] = nil

            // Clear ringing state if this was the ringing alarm
            if currentRingingMetadata?.alarmId == alarmID {
                clearRingingState()
            }
        }
    }

    // MARK: - Snooze

    /// Snooze the currently ringing alarm for 3 minutes
    @MainActor
    func snoozeCurrentAlarm() {
        guard let alarm = currentlyRingingAlarm,
              let metadata = currentRingingMetadata,
              metadata.snoozeAllowed,
              !alarm.snoozeUsed else {
            print("Snooze not allowed")
            return
        }

        // Mark snooze as used
        alarm.snoozeUsed = true
        try? modelContext?.save()

        // Cancel current alarm
        if let scheduledId = alarm.scheduledAlarmId {
            try? alarmManager.cancel(id: scheduledId)
            alarmsMap[scheduledId] = nil
        }

        // Schedule snooze alarm for 3 minutes from now
        let snoozeMinutes = 3
        let now = Date()
        let snoozeTime = Calendar.current.date(byAdding: .minute, value: snoozeMinutes, to: now) ?? now
        let snoozeHour = Calendar.current.component(.hour, from: snoozeTime)
        let snoozeMinute = Calendar.current.component(.minute, from: snoozeTime)

        let snoozeMetadata = WaterAlarmData(
            waterAlarmId: alarm.id,
            alarmHour: snoozeHour,
            alarmMinute: snoozeMinute,
            label: alarm.label,
            requiresPhoto: alarm.requiresPhoto,
            requiresQRCode: alarm.requiresQRCode || alarm.qrRequiredForDifficulty,
            qrCodeIdentifier: alarm.qrCodeIdentifier,
            difficultyLevel: alarm.difficultyLevel,
            snoozeAllowed: false,  // No second snooze
            isSnooze: true
        )

        let attributes = AlarmAttributes(
            presentation: alarmPresentation(for: alarm, isSnooze: true),
            metadata: snoozeMetadata,
            tintColor: Color.orange
        )

        let snoozeId = UUID()
        let snoozeDuration = TimeInterval(snoozeMinutes * 60)
        let sound = AlertConfiguration.AlertSound.default

        let snoozeConfig = AlarmConfiguration(
            countdownDuration: .init(preAlert: snoozeDuration, postAlert: nil),
            attributes: attributes,
            sound: sound
        )

        // Clear ringing state
        clearRingingState()
        SoundManager.shared.stopAlarmSound()
        SoundManager.shared.playSnoozeSound()

        Task {
            do {
                let scheduledSnooze = try await alarmManager.schedule(id: snoozeId, configuration: snoozeConfig)
                await MainActor.run {
                    alarmsMap[snoozeId] = (scheduledSnooze, snoozeMetadata)
                    alarm.scheduledAlarmId = snoozeId
                    try? modelContext?.save()
                    print("Snoozed alarm, will ring at \(snoozeMetadata.formattedTime)")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to schedule snooze. The alarm will not ring again."
                }
                print("Error scheduling snooze: \(error)")
            }
        }
    }

    // MARK: - Proof Completion

    /// Set captured photo for proof (triggers validation if enabled)
    @MainActor
    func setCapturedPhoto(_ image: UIImage) {
        capturedProofPhoto = image

        // Trigger awakeness validation if enabled
        if AppSettings.shared.awakeDetectionEnabled {
            Task {
                await validateCapturedPhoto(image)
            }
        } else {
            checkProofCompletion()
        }
    }

    // MARK: - Awakeness Validation

    /// Validate the captured photo for awakeness
    @MainActor
    func validateCapturedPhoto(_ image: UIImage) async {
        awakenessValidationState = .validating

        // Update sensitivity from settings
        awakenessValidator.updateSensitivity(AppSettings.shared.awakeSensitivity)

        let result = await awakenessValidator.validatePhoto(image)

        if result.isAwake {
            awakenessValidationState = .passed(score: result.awakenessScore)
            lastAwakenessScore = result.awakenessScore
            validationBypassed = false

            // Small delay to show success state
            try? await Task.sleep(nanoseconds: 800_000_000)
            checkProofCompletion()
        } else {
            validationRetryCount += 1
            awakenessValidationState = .failed(
                reason: result.failureReason ?? .poorQuality,
                retryCount: validationRetryCount
            )
            // Don't mark proof complete - user needs to retake
        }
    }

    /// Retry photo capture after failed validation
    @MainActor
    func retryPhotoCapture() {
        capturedProofPhoto = nil
        awakenessValidationState = .idle
    }

    /// Bypass validation after max retries (affects achievements)
    @MainActor
    func bypassValidation() {
        validationBypassed = true
        awakenessValidationState = .passed(score: 0)
        lastAwakenessScore = 0
        checkProofCompletion()
    }

    /// Reset validation state
    @MainActor
    func resetValidationState() {
        awakenessValidationState = .idle
        validationRetryCount = 0
        lastAwakenessScore = nil
        validationBypassed = false
    }

    // MARK: - Motivational Messages

    /// Generate motivational message for alarm
    @MainActor
    func generateMotivationalMessage() async {
        guard AppSettings.shared.aiMessagesEnabled else {
            motivationalMessage = nil
            return
        }

        let context = WakeUpContext.current(
            streak: streakData?.currentStreak ?? 0,
            wasOnTimeYesterday: streakData?.wasCompletedYesterday ?? true,
            alarmLabel: currentlyRingingAlarm?.label,
            totalCompletions: streakData?.totalCompletions ?? 0,
            missedDays: streakData?.missedCount ?? 0
        )

        motivationalMessage = await motivationGenerator.generateWakeUpMessage(context: context)
    }

    /// Set QR verified
    @MainActor
    func setQRVerified(_ verified: Bool) {
        isQRVerified = verified
        checkProofCompletion()
    }

    /// Start wait time countdown if required by difficulty
    @MainActor
    func startWaitTimeIfNeeded() {
        guard let alarm = currentlyRingingAlarm else { return }

        let waitTime = alarm.waitTimeForDifficulty
        if waitTime > 0 {
            waitTimeRemaining = waitTime
            startWaitTimeCountdown()
        }
    }

    private func startWaitTimeCountdown() {
        // Cancel any existing countdown
        waitTimeTask?.cancel()

        waitTimeTask = Task { @MainActor in
            while waitTimeRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                waitTimeRemaining -= 1
            }
            if !Task.isCancelled {
                checkProofCompletion()
            }
        }
    }

    /// Cancel wait time countdown
    @MainActor
    func cancelWaitTimeCountdown() {
        waitTimeTask?.cancel()
        waitTimeTask = nil
    }

    /// Check if all proof requirements are met
    @MainActor
    private func checkProofCompletion() {
        guard let alarm = currentlyRingingAlarm else { return }

        var requirementsMet = true

        // Photo required?
        if alarm.requiresPhoto && capturedProofPhoto == nil {
            requirementsMet = false
        }

        // QR required (by setting or difficulty)?
        if (alarm.requiresQRCode || alarm.qrRequiredForDifficulty) && !isQRVerified {
            requirementsMet = false
        }

        // Wait time complete?
        if alarm.waitTimeForDifficulty > 0 && waitTimeRemaining > 0 {
            requirementsMet = false
        }

        isProofCompleted = requirementsMet
    }

    /// Complete the alarm after proof is done
    @MainActor
    func completeAlarm() {
        guard isProofCompleted,
              let alarm = currentlyRingingAlarm else { return }

        // Save proof photo
        var photoPath: String?
        if let photo = capturedProofPhoto {
            photoPath = PhotoStorageManager.shared.saveProofPhoto(photo, alarmId: alarm.id)
        }

        // Create proof record with awakeness data
        let proofRecord = ProofRecord(
            alarmId: alarm.id,
            completedAt: Date(),
            photoPath: photoPath,
            qrCodeScanned: isQRVerified,
            difficultyLevel: alarm.difficultyLevel,
            wasOnTime: !alarm.snoozeUsed,
            awakenessScore: lastAwakenessScore,
            validationBypassed: validationBypassed
        )

        modelContext?.insert(proofRecord)

        // Update streak
        streakData?.recordCompletion()

        // Adjust difficulty based on streak
        updateDifficultyBasedOnStreak(for: alarm)

        // Reset snooze for next time
        alarm.snoozeUsed = false

        try? modelContext?.save()

        // Check for achievements
        checkAchievements(latestProof: proofRecord)

        // Stop alarm
        if let scheduledId = alarm.scheduledAlarmId {
            unscheduleAlarm(with: scheduledId)
        }

        // Stop sound and clear state
        SoundManager.shared.stopAlarmSound()
        SoundManager.shared.playSuccessSound()
        clearRingingState()

        // Reschedule if repeating
        if !alarm.repeatDays.isEmpty {
            scheduleWaterAlarm(alarm)
        }

        print("Alarm completed successfully")
    }

    /// Check and unlock achievements
    @MainActor
    private func checkAchievements(latestProof: ProofRecord) {
        guard let context = modelContext else { return }

        // Setup achievement manager
        AchievementManager.shared.setup(context: context)

        // Fetch all proof records
        let descriptor = FetchDescriptor<ProofRecord>()
        let allProofs = (try? context.fetch(descriptor)) ?? []

        // Check for new achievements
        AchievementManager.shared.checkAndUnlockAchievements(
            streakData: streakData,
            latestProof: latestProof,
            allProofs: allProofs
        )
    }

    /// Clear ringing state
    @MainActor
    func clearRingingState() {
        // Cancel any running countdown
        cancelWaitTimeCountdown()

        currentlyRingingAlarm = nil
        currentRingingMetadata = nil
        isProofCompleted = false
        ringingStartTime = nil
        capturedProofPhoto = nil
        isQRVerified = false
        waitTimeRemaining = 0

        // Reset Apple Intelligence state
        resetValidationState()
        motivationalMessage = nil
    }

    // MARK: - Adaptive Difficulty

    @MainActor
    private func updateDifficultyBasedOnStreak(for alarm: WaterAlarm) {
        guard let streak = streakData else { return }

        let change = streak.recommendedDifficultyChange()

        if change > 0 {
            // Increase difficulty (missed yesterday)
            alarm.difficultyLevel = min(alarm.difficultyLevel + 1, 4)
        } else if change < 0 && streak.currentStreak >= 3 {
            // Decrease difficulty (consistent for 3+ days)
            alarm.difficultyLevel = max(alarm.difficultyLevel - 1, 1)
        }
    }

    // MARK: - Streak Management

    @MainActor
    private func loadStreakData() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<StreakData>()
        if let existing = try? context.fetch(descriptor).first {
            streakData = existing
            streakData?.checkForMissedDay()
        } else {
            // Create new streak data
            let newStreak = StreakData()
            context.insert(newStreak)
            try? context.save()
            streakData = newStreak
        }
    }

    // MARK: - Cleanup

    private func cleanupOldProofPhotos() {
        PhotoStorageManager.shared.cleanupOldPhotos(olderThan: 7)
    }

    // MARK: - Alarm Presentation

    private func alarmPresentation(for alarm: WaterAlarm, isSnooze: Bool = false) -> AlarmPresentation {
        let title = alarm.label ?? "Water Alarm"
        let alertTitle = isSnooze ? "Snooze - \(title)" : title

        let alertContent = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alertTitle),
            stopButton: .wakeUpButton  // Opens app, doesn't stop
        )

        return AlarmPresentation(alert: alertContent)
    }

    // MARK: - Alarm Updates Observer

    private func observeAlarms() {
        Task {
            for await incomingAlarms in alarmManager.alarmUpdates {
                await updateAlarmState(with: incomingAlarms)
            }
        }
    }

    @MainActor
    private func updateAlarmState(with remoteAlarms: [Alarm]) {
        // Update existing alarm states
        for updated in remoteAlarms {
            if let existing = alarmsMap[updated.id] {
                alarmsMap[updated.id] = (updated, existing.1)
            }

            // Check if alarm is alerting (ringing)
            if case .alerting = updated.state {
                handleAlarmRinging(updated)
            }
        }

        // Remove completed alarms
        let knownAlarmIDs = Set(alarmsMap.keys)
        let incomingAlarmIDs = Set(remoteAlarms.map(\.id))
        let removedAlarmsIDs = knownAlarmIDs.subtracting(incomingAlarmIDs)

        for id in removedAlarmsIDs {
            alarmsMap[id] = nil
        }
    }

    @MainActor
    private func handleAlarmRinging(_ alarm: Alarm) {
        guard let (_, metadata) = alarmsMap[alarm.id] else { return }

        // Find the WaterAlarm
        guard let context = modelContext else { return }
        let targetId = metadata.waterAlarmId
        let descriptor = FetchDescriptor<WaterAlarm>(predicate: #Predicate { $0.id == targetId })

        guard let waterAlarm = try? context.fetch(descriptor).first else { return }

        // Set ringing state
        currentlyRingingAlarm = waterAlarm
        currentRingingMetadata = metadata
        ringingStartTime = Date()
        isProofCompleted = false

        // Start alarm sound
        SoundManager.shared.startAlarmSound()

        // Generate motivational message (Apple Intelligence)
        Task {
            await generateMotivationalMessage()
        }

        print("Alarm ringing: \(waterAlarm.formattedTime)")
    }

    // MARK: - Authorization

    private func requestAuthorization() async -> Bool {
        switch alarmManager.authorizationState {
        case .notDetermined:
            do {
                let state = try await alarmManager.requestAuthorization()
                return state == .authorized
            } catch {
                print("Error requesting authorization: \(error)")
                return false
            }
        case .authorized:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - Alarm Button Extensions

extension AlarmButton {
    static var wakeUpButton: Self {
        AlarmButton(text: "Wake Up", textColor: .white, systemImageName: "sunrise.fill")
    }

    static var snoozeButton: Self {
        AlarmButton(text: "Snooze", textColor: .white, systemImageName: "moon.zzz.fill")
    }
}
