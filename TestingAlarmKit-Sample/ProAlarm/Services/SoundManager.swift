//
//  SoundManager.swift
//  ProAlarm
//
//  Manages alarm sounds and vibration with volume escalation
//

import AVFoundation
import Combine
import UIKit

class SoundManager: ObservableObject {
    static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?
    private var escalationTimer: Timer?
    private var vibrationTimer: Timer?

    @Published var currentVolume: Float = 0.5
    @Published var isPlaying: Bool = false

    // Escalation settings
    private let initialVolume: Float = 0.5
    private let maxVolume: Float = 1.0
    private let escalationDelay: TimeInterval = 10.0     // Start escalation after 10 seconds
    private let escalationDuration: TimeInterval = 10.0  // Reach max volume over 10 seconds

    private var escalationStartTime: Date?

    private init() {
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("SoundManager: Failed to configure audio session - \(error)")
        }
    }

    // MARK: - Start Alarm Sound

    /// Starts the alarm sound loop with gradual volume escalation
    func startAlarmSound() {
        guard !isPlaying else { return }

        // Try to load custom alarm sound, fallback to system sound
        if let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "m4a") {
            loadAndPlaySound(url: soundURL)
        } else if let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") {
            loadAndPlaySound(url: soundURL)
        } else if let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "mp3") {
            loadAndPlaySound(url: soundURL)
        } else {
            // Use system sound as fallback
            startSystemSoundLoop()
        }

        isPlaying = true
        currentVolume = initialVolume

        // Start vibration
        startVibration(aggressive: false)

        // Schedule escalation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + escalationDelay) { [weak self] in
            self?.startEscalation()
        }
    }

    private func loadAndPlaySound(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1  // Loop indefinitely
            audioPlayer?.volume = initialVolume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("SoundManager: Failed to load sound - \(error)")
            startSystemSoundLoop()
        }
    }

    private var systemSoundTimer: Timer?

    private func startSystemSoundLoop() {
        // Play system alert sound repeatedly
        playSystemSound()
        systemSoundTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.playSystemSound()
        }
    }

    private func playSystemSound() {
        // System alert sound ID 1005 is a classic alarm sound
        AudioServicesPlaySystemSound(1005)
    }

    // MARK: - Volume Escalation

    private func startEscalation() {
        guard isPlaying else { return }

        escalationStartTime = Date()

        escalationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateEscalation()
        }

        // Switch to aggressive vibration
        startVibration(aggressive: true)
    }

    private func updateEscalation() {
        guard let startTime = escalationStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / escalationDuration, 1.0)

        currentVolume = initialVolume + Float(progress) * (maxVolume - initialVolume)
        audioPlayer?.volume = currentVolume

        if progress >= 1.0 {
            escalationTimer?.invalidate()
            escalationTimer = nil
        }
    }

    /// Manually trigger escalation (e.g., when user ignores alarm)
    func escalateVolume() {
        guard isPlaying, escalationTimer == nil else { return }
        startEscalation()
    }

    // MARK: - Stop Alarm Sound

    func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil

        systemSoundTimer?.invalidate()
        systemSoundTimer = nil

        escalationTimer?.invalidate()
        escalationTimer = nil
        escalationStartTime = nil

        stopVibration()

        isPlaying = false
        currentVolume = initialVolume
    }

    // MARK: - Vibration

    private func startVibration(aggressive: Bool) {
        stopVibration()

        let interval: TimeInterval = aggressive ? 0.5 : 1.0

        vibrationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.triggerVibration(aggressive: aggressive)
        }

        // Trigger immediately
        triggerVibration(aggressive: aggressive)
    }

    func triggerVibration(aggressive: Bool) {
        if aggressive {
            // Heavy impact for aggressive vibration
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()

            // Also play system vibration
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        } else {
            // Medium impact for normal vibration
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    private func stopVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    // MARK: - Snooze Sound

    /// Play a short sound for snooze confirmation
    func playSnoozeSound() {
        AudioServicesPlaySystemSound(1057)  // Short tick sound
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    // MARK: - Success Sound

    /// Play a success sound when alarm is stopped
    func playSuccessSound() {
        AudioServicesPlaySystemSound(1025)  // Short success sound
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
