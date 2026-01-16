//
//  Achievement.swift
//  ProAlarm
//
//  Achievement badges for gamification
//

import Foundation
import SwiftData
import UIKit

// MARK: - Achievement Definition

enum AchievementType: String, CaseIterable, Codable {
    case firstSip = "first_sip"
    case earlyBird = "early_bird"
    case weekWarrior = "week_warrior"
    case monthMaster = "month_master"
    case perfectScore = "perfect_score"
    case noExcuses = "no_excuses"

    var title: String {
        switch self {
        case .firstSip: return "First Sip"
        case .earlyBird: return "Early Bird"
        case .weekWarrior: return "Week Warrior"
        case .monthMaster: return "Month Master"
        case .perfectScore: return "Perfect Score"
        case .noExcuses: return "No Excuses"
        }
    }

    var description: String {
        switch self {
        case .firstSip: return "Complete your first alarm"
        case .earlyBird: return "Complete 5 alarms without snooze"
        case .weekWarrior: return "Achieve a 7-day streak"
        case .monthMaster: return "Achieve a 30-day streak"
        case .perfectScore: return "Complete a level 4 difficulty alarm"
        case .noExcuses: return "14 days with no snoozes"
        }
    }

    var icon: String {
        switch self {
        case .firstSip: return "drop.fill"
        case .earlyBird: return "sunrise.fill"
        case .weekWarrior: return "flame.fill"
        case .monthMaster: return "crown.fill"
        case .perfectScore: return "star.fill"
        case .noExcuses: return "bolt.fill"
        }
    }

    var color: String {
        switch self {
        case .firstSip: return "cyan"
        case .earlyBird: return "orange"
        case .weekWarrior: return "red"
        case .monthMaster: return "yellow"
        case .perfectScore: return "purple"
        case .noExcuses: return "green"
        }
    }
}

// MARK: - Unlocked Achievement Model

@Model
class UnlockedAchievement: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var achievementType: String  // AchievementType raw value
    var unlockedAt: Date

    init(type: AchievementType) {
        self.achievementType = type.rawValue
        self.unlockedAt = Date()
    }

    var type: AchievementType? {
        AchievementType(rawValue: achievementType)
    }
}

// MARK: - Achievement Manager

@Observable
class AchievementManager {
    static let shared = AchievementManager()

    @ObservationIgnored private var modelContext: ModelContext?

    private init() {}

    func setup(context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Check & Unlock

    func checkAndUnlockAchievements(
        streakData: StreakData?,
        latestProof: ProofRecord?,
        allProofs: [ProofRecord]
    ) {
        guard let context = modelContext else { return }

        // Get already unlocked achievements
        let descriptor = FetchDescriptor<UnlockedAchievement>()
        let unlocked = (try? context.fetch(descriptor)) ?? []
        let unlockedTypes = Set(unlocked.compactMap { $0.type })

        var newlyUnlocked: [AchievementType] = []

        // First Sip - Complete first alarm
        if !unlockedTypes.contains(.firstSip) && !allProofs.isEmpty {
            newlyUnlocked.append(.firstSip)
        }

        // Early Bird - 5 alarms without snooze
        if !unlockedTypes.contains(.earlyBird) {
            let onTimeCount = allProofs.filter { $0.wasOnTime }.count
            if onTimeCount >= 5 {
                newlyUnlocked.append(.earlyBird)
            }
        }

        // Week Warrior - 7-day streak
        if !unlockedTypes.contains(.weekWarrior) {
            if let streak = streakData, streak.currentStreak >= 7 || streak.longestStreak >= 7 {
                newlyUnlocked.append(.weekWarrior)
            }
        }

        // Month Master - 30-day streak
        if !unlockedTypes.contains(.monthMaster) {
            if let streak = streakData, streak.currentStreak >= 30 || streak.longestStreak >= 30 {
                newlyUnlocked.append(.monthMaster)
            }
        }

        // Perfect Score - Complete level 4 difficulty
        if !unlockedTypes.contains(.perfectScore) {
            let hasLevel4 = allProofs.contains { $0.difficultyLevel >= 4 }
            if hasLevel4 {
                newlyUnlocked.append(.perfectScore)
            }
        }

        // No Excuses - 14 consecutive days with no snoozes
        if !unlockedTypes.contains(.noExcuses) {
            let consecutiveNoSnooze = countConsecutiveNoSnoozeDays(proofs: allProofs)
            if consecutiveNoSnooze >= 14 {
                newlyUnlocked.append(.noExcuses)
            }
        }

        // Unlock new achievements
        for type in newlyUnlocked {
            let achievement = UnlockedAchievement(type: type)
            context.insert(achievement)

            // Haptic feedback
            AppSettings.shared.triggerNotificationHaptic(.success)
        }

        try? context.save()
    }

    private func countConsecutiveNoSnoozeDays(proofs: [ProofRecord]) -> Int {
        guard !proofs.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedProofs = proofs.sorted { $0.completedAt > $1.completedAt }

        var consecutiveDays = 0
        var currentDate = calendar.startOfDay(for: Date())

        for proof in sortedProofs {
            let proofDate = calendar.startOfDay(for: proof.completedAt)

            // Check if this proof is from the expected day
            if proofDate == currentDate || proofDate == calendar.date(byAdding: .day, value: -1, to: currentDate) {
                if proof.wasOnTime {
                    if proofDate == calendar.date(byAdding: .day, value: -1, to: currentDate) {
                        consecutiveDays += 1
                        currentDate = proofDate
                    } else if proofDate == currentDate && consecutiveDays == 0 {
                        consecutiveDays = 1
                    }
                } else {
                    break // Snooze used, streak broken
                }
            } else if proofDate < calendar.date(byAdding: .day, value: -1, to: currentDate)! {
                break // Gap in days, stop counting
            }
        }

        return consecutiveDays
    }

    // MARK: - Query

    func getUnlockedAchievements() -> [UnlockedAchievement] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<UnlockedAchievement>(sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func isUnlocked(_ type: AchievementType) -> Bool {
        let unlocked = getUnlockedAchievements()
        return unlocked.contains { $0.type == type }
    }
}
