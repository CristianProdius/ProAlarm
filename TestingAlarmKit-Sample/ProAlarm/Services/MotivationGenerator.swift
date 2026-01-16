//
//  MotivationGenerator.swift
//  ProAlarm
//
//  Uses Apple's on-device Foundation Models (iOS 26+) to generate
//  personalized motivational messages. Falls back to templates for older iOS.
//

import Foundation
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Wake Up Context

struct WakeUpContext {
    let currentStreak: Int
    let dayOfWeek: String
    let timeOfDay: TimeOfDay
    let wasOnTimeYesterday: Bool
    let alarmLabel: String?
    let totalCompletions: Int
    let missedDays: Int

    enum TimeOfDay: String {
        case earlyMorning = "early morning"  // 4-6 AM
        case morning = "morning"              // 6-9 AM
        case lateMorning = "late morning"     // 9-12 PM
        case afternoon = "afternoon"          // 12-6 PM
        case evening = "evening"              // 6-9 PM
        case night = "night"                  // 9 PM - 4 AM

        static func from(hour: Int) -> TimeOfDay {
            switch hour {
            case 4..<6: return .earlyMorning
            case 6..<9: return .morning
            case 9..<12: return .lateMorning
            case 12..<18: return .afternoon
            case 18..<21: return .evening
            default: return .night
            }
        }
    }

    static func current(
        streak: Int,
        wasOnTimeYesterday: Bool = true,
        alarmLabel: String? = nil,
        totalCompletions: Int = 0,
        missedDays: Int = 0
    ) -> WakeUpContext {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayOfWeek = dayFormatter.string(from: now)

        return WakeUpContext(
            currentStreak: streak,
            dayOfWeek: dayOfWeek,
            timeOfDay: TimeOfDay.from(hour: hour),
            wasOnTimeYesterday: wasOnTimeYesterday,
            alarmLabel: alarmLabel,
            totalCompletions: totalCompletions,
            missedDays: missedDays
        )
    }
}

// MARK: - Motivation Generator

@Observable
@MainActor
class MotivationGenerator {

    var currentMessage: String?
    var isGenerating = false

    private var foundationModelsAvailable: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    // MARK: - Wake Up Messages

    func generateWakeUpMessage(context: WakeUpContext) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        if #available(iOS 26.0, *) {
            if let aiMessage = await generateWithFoundationModels(context: context) {
                currentMessage = aiMessage
                return aiMessage
            }
        }

        // Fallback to templates
        let message = selectTemplate(for: context)
        currentMessage = message
        return message
    }

    // MARK: - Streak Celebration Messages

    func generateStreakCelebration(streak: Int) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        if #available(iOS 26.0, *) {
            if let aiMessage = await generateStreakMessageWithAI(streak: streak) {
                currentMessage = aiMessage
                return aiMessage
            }
        }

        // Fallback to templates
        let message = streakTemplate(for: streak)
        currentMessage = message
        return message
    }

    // MARK: - Weekly Insight

    func generateWeeklyInsight(
        completions: Int,
        onTimePercentage: Double,
        bestDay: String?,
        currentStreak: Int
    ) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        if #available(iOS 26.0, *) {
            if let aiMessage = await generateInsightWithAI(
                completions: completions,
                onTimePercentage: onTimePercentage,
                bestDay: bestDay,
                currentStreak: currentStreak
            ) {
                currentMessage = aiMessage
                return aiMessage
            }
        }

        // Fallback
        return weeklyInsightTemplate(
            completions: completions,
            onTimePercentage: onTimePercentage,
            bestDay: bestDay
        )
    }

    // MARK: - Foundation Models Integration (iOS 26+)

    @available(iOS 26.0, *)
    private func generateWithFoundationModels(context: WakeUpContext) async -> String? {
        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()

            var prompt = "Generate a short, encouraging wake-up message (1-2 sentences max). "
            prompt += "It's \(context.dayOfWeek) \(context.timeOfDay.rawValue). "

            if context.currentStreak > 0 {
                prompt += "The user is on a \(context.currentStreak)-day streak. "
            }

            if let label = context.alarmLabel {
                prompt += "Their alarm is labeled '\(label)'. "
            }

            if !context.wasOnTimeYesterday {
                prompt += "They missed yesterday, so encourage them to bounce back. "
            }

            prompt += "Keep it brief, friendly, and motivating. No emojis."

            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("Foundation Models error: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    @available(iOS 26.0, *)
    private func generateStreakMessageWithAI(streak: Int) async -> String? {
        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()

            let prompt = """
            Generate a celebration message for reaching a \(streak)-day wake-up streak.
            Keep it to 1-2 sentences. Be encouraging but not over the top.
            No emojis.
            """

            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("Foundation Models error: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    @available(iOS 26.0, *)
    private func generateInsightWithAI(
        completions: Int,
        onTimePercentage: Double,
        bestDay: String?,
        currentStreak: Int
    ) async -> String? {
        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()

            var prompt = "Generate a brief weekly progress insight (2-3 sentences). "
            prompt += "Stats: \(completions) alarm completions this week, "
            prompt += "\(Int(onTimePercentage))% on time. "

            if let best = bestDay {
                prompt += "Best day was \(best). "
            }

            if currentStreak > 0 {
                prompt += "Current streak: \(currentStreak) days. "
            }

            prompt += "Give constructive feedback without being preachy. No emojis."

            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("Foundation Models error: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Fallback Templates

    private func selectTemplate(for context: WakeUpContext) -> String {
        // Streak-based messages
        if context.currentStreak > 0 {
            return streakAwareTemplate(context)
        }

        // Day of week messages
        return dayBasedTemplate(context)
    }

    private func streakAwareTemplate(_ context: WakeUpContext) -> String {
        let streak = context.currentStreak

        switch streak {
        case 1:
            return "Day 1 starts now. Let's build this habit!"
        case 2:
            return "Day 2! Yesterday's effort is today's foundation."
        case 3...4:
            return "Day \(streak)! You're building real momentum."
        case 5...6:
            return "Day \(streak)! Almost at a week - keep going!"
        case 7:
            return "One full week! You've proven you can do this."
        case 8...13:
            return "\(streak) days strong. This is becoming routine!"
        case 14:
            return "Two weeks! Habits are forming."
        case 15...20:
            return "Day \(streak) - consistency is your superpower."
        case 21...29:
            return "\(streak) days! You're in the habit zone now."
        case 30:
            return "30 days! A full month of commitment."
        case 31...59:
            return "\(streak)-day streak. This is who you are now."
        case 60...89:
            return "\(streak) days. You've transformed your mornings."
        case 90...364:
            return "\(streak) days! You're in the elite club now."
        default:
            return "\(streak) days! Absolutely incredible dedication."
        }
    }

    private func dayBasedTemplate(_ context: WakeUpContext) -> String {
        let day = context.dayOfWeek.lowercased()

        switch day {
        case "monday":
            return "Monday sets the tone. Start strong!"
        case "tuesday":
            return "Tuesday momentum - keep yesterday's energy going."
        case "wednesday":
            return "Midweek milestone. You're halfway there!"
        case "thursday":
            return "Thursday push - weekend is almost here."
        case "friday":
            return "Friday finish line in sight. Strong end to the week!"
        case "saturday":
            return "Weekend doesn't mean rest for champions."
        case "sunday":
            return "Sunday sets up next week's success."
        default:
            return "Rise and conquer the day!"
        }
    }

    private func streakTemplate(for streak: Int) -> String {
        switch streak {
        case 7:
            return "A full week! You've built a real routine."
        case 14:
            return "Two weeks strong! This is becoming second nature."
        case 21:
            return "21 days - the classic habit milestone!"
        case 30:
            return "One month! You've transformed your mornings."
        case 60:
            return "60 days of commitment. Truly impressive."
        case 90:
            return "90 days! A quarter year of consistency."
        case 100:
            return "Triple digits! 100 days of dedication."
        case 365:
            return "A FULL YEAR! Legendary achievement unlocked."
        default:
            if streak % 50 == 0 {
                return "\(streak) days! Another milestone crushed."
            } else if streak % 10 == 0 {
                return "\(streak) days and counting. Keep it up!"
            }
            return "Day \(streak)! Every day counts."
        }
    }

    private func weeklyInsightTemplate(
        completions: Int,
        onTimePercentage: Double,
        bestDay: String?
    ) -> String {
        var insight = "This week: \(completions) alarms completed"

        if onTimePercentage >= 90 {
            insight += " with excellent \(Int(onTimePercentage))% on-time rate."
        } else if onTimePercentage >= 70 {
            insight += " at \(Int(onTimePercentage))% on time. Good progress!"
        } else {
            insight += ". Room to improve your timing."
        }

        if let best = bestDay {
            insight += " \(best)s seem to be your strongest."
        }

        return insight
    }
}

// MARK: - Difficulty Recommendation

extension MotivationGenerator {

    func generateDifficultyRecommendation(
        currentLevel: Int,
        recentSuccessRate: Double,
        currentStreak: Int
    ) -> String? {
        // Recommend increase
        if currentLevel < 4 && recentSuccessRate > 0.9 && currentStreak >= 7 {
            return "You've been crushing it! Ready to try Level \(currentLevel + 1)?"
        }

        // Recommend decrease
        if currentLevel > 1 && recentSuccessRate < 0.5 {
            return "Struggling a bit? Level \(currentLevel - 1) might help rebuild momentum."
        }

        return nil
    }
}
