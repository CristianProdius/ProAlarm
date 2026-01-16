//
//  ProgressSummarizer.swift
//  ProAlarm
//
//  Analyzes user patterns and generates AI-powered progress reports.
//  Uses Foundation Models (iOS 26+) with fallback to template-based summaries.
//

import Foundation
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Progress Summary

struct ProgressSummary {
    let period: SummaryPeriod
    let headline: String
    let details: String
    let insights: [String]
    let recommendation: String?
    let generatedAt: Date

    enum SummaryPeriod: String {
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
}

// MARK: - Pattern Analysis

struct PatternAnalysis {
    let bestDay: String?
    let worstDay: String?
    let bestTimeRange: String?
    let avgSnoozeCount: Double
    let onTimePercentage: Double
    let completionsByDay: [String: Int]
    let difficultyProgression: [Int]
    let streakHistory: [Int]
}

// MARK: - Difficulty Recommendation

struct DifficultyRecommendation {
    let suggestedLevel: Int
    let reason: String
    let isIncrease: Bool
}

// MARK: - Progress Summarizer

@Observable
@MainActor
class ProgressSummarizer {

    var currentSummary: ProgressSummary?
    var isGenerating = false

    // MARK: - Generate Weekly Summary

    func generateWeeklySummary(
        records: [ProofRecord],
        streakData: StreakData?
    ) async -> ProgressSummary {
        isGenerating = true
        defer { isGenerating = false }

        let analysis = analyzePatterns(records: records, days: 7)

        if #available(iOS 26.0, *) {
            if let aiSummary = await generateWithAI(
                analysis: analysis,
                period: .weekly,
                streakData: streakData
            ) {
                currentSummary = aiSummary
                return aiSummary
            }
        }

        let summary = generateTemplateSummary(
            analysis: analysis,
            period: .weekly,
            streakData: streakData
        )
        currentSummary = summary
        return summary
    }

    // MARK: - Generate Monthly Summary

    func generateMonthlySummary(
        records: [ProofRecord],
        streakData: StreakData?
    ) async -> ProgressSummary {
        isGenerating = true
        defer { isGenerating = false }

        let analysis = analyzePatterns(records: records, days: 30)

        if #available(iOS 26.0, *) {
            if let aiSummary = await generateWithAI(
                analysis: analysis,
                period: .monthly,
                streakData: streakData
            ) {
                currentSummary = aiSummary
                return aiSummary
            }
        }

        let summary = generateTemplateSummary(
            analysis: analysis,
            period: .monthly,
            streakData: streakData
        )
        currentSummary = summary
        return summary
    }

    // MARK: - Pattern Analysis

    private func analyzePatterns(records: [ProofRecord], days: Int) -> PatternAnalysis {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentRecords = records.filter { $0.completedAt >= cutoffDate }

        var completionsByDay: [String: Int] = [:]
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        for record in recentRecords {
            let dayName = dayFormatter.string(from: record.completedAt)
            completionsByDay[dayName, default: 0] += 1
        }

        let sortedDays = completionsByDay.sorted { $0.value > $1.value }
        let bestDay = sortedDays.first?.key
        let worstDay = sortedDays.last?.key

        let onTimeCount = recentRecords.filter { $0.wasOnTime }.count
        let onTimePercentage = recentRecords.isEmpty ? 0 :
            Double(onTimeCount) / Double(recentRecords.count) * 100

        var hourCounts: [Int: Int] = [:]
        for record in recentRecords {
            let hour = calendar.component(.hour, from: record.completedAt)
            hourCounts[hour, default: 0] += 1
        }

        let bestHour = hourCounts.max(by: { $0.value < $1.value })?.key
        var bestTimeRange: String? = nil
        if let hour = bestHour {
            let nextHour = (hour + 1) % 24
            bestTimeRange = "\(hour % 12 == 0 ? 12 : hour % 12)-\(nextHour % 12 == 0 ? 12 : nextHour % 12) \(hour < 12 ? "AM" : "PM")"
        }

        let difficultyProgression = recentRecords
            .sorted { $0.completedAt < $1.completedAt }
            .map { $0.difficultyLevel }

        let snoozedCount = recentRecords.filter { !$0.wasOnTime }.count
        let avgSnooze = recentRecords.isEmpty ? 0 :
            Double(snoozedCount) / Double(recentRecords.count)

        return PatternAnalysis(
            bestDay: bestDay,
            worstDay: worstDay,
            bestTimeRange: bestTimeRange,
            avgSnoozeCount: avgSnooze,
            onTimePercentage: onTimePercentage,
            completionsByDay: completionsByDay,
            difficultyProgression: difficultyProgression,
            streakHistory: []
        )
    }

    // MARK: - AI Generation (iOS 26+)

    @available(iOS 26.0, *)
    private func generateWithAI(
        analysis: PatternAnalysis,
        period: ProgressSummary.SummaryPeriod,
        streakData: StreakData?
    ) async -> ProgressSummary? {
        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()

            var prompt = """
            Generate a \(period.rawValue.lowercased()) progress summary for an alarm app user.

            Stats:
            - On-time rate: \(Int(analysis.onTimePercentage))%
            - Best performing day: \(analysis.bestDay ?? "N/A")
            - Worst performing day: \(analysis.worstDay ?? "N/A")
            - Average snooze rate: \(Int(analysis.avgSnoozeCount * 100))%
            """

            if let streak = streakData {
                prompt += "\n- Current streak: \(streak.currentStreak) days"
                prompt += "\n- Best streak ever: \(streak.longestStreak) days"
            }

            prompt += """

            Provide:
            1. A brief headline (5-8 words)
            2. A 2-3 sentence summary
            3. 2-3 specific insights
            4. One actionable recommendation

            Format as JSON:
            {"headline": "...", "details": "...", "insights": ["...", "..."], "recommendation": "..."}
            """

            let response = try await session.respond(to: prompt)

            if let data = response.content.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                return ProgressSummary(
                    period: period,
                    headline: json["headline"] as? String ?? "Your \(period.rawValue) Progress",
                    details: json["details"] as? String ?? "",
                    insights: json["insights"] as? [String] ?? [],
                    recommendation: json["recommendation"] as? String,
                    generatedAt: Date()
                )
            }
            return nil
        } catch {
            print("Foundation Models error: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Template-Based Summary

    private func generateTemplateSummary(
        analysis: PatternAnalysis,
        period: ProgressSummary.SummaryPeriod,
        streakData: StreakData?
    ) -> ProgressSummary {
        let totalCompletions = analysis.completionsByDay.values.reduce(0, +)

        let headline: String
        if analysis.onTimePercentage >= 90 {
            headline = "Exceptional \(period.rawValue) Performance"
        } else if analysis.onTimePercentage >= 70 {
            headline = "Solid \(period.rawValue) Progress"
        } else if analysis.onTimePercentage >= 50 {
            headline = "Room for Improvement"
        } else {
            headline = "Let's Get Back on Track"
        }

        var details = "You completed \(totalCompletions) alarms"
        details += " with a \(Int(analysis.onTimePercentage))% on-time rate."
        if let streak = streakData, streak.currentStreak > 0 {
            details += " You're on a \(streak.currentStreak)-day streak!"
        }

        var insights: [String] = []
        if let bestDay = analysis.bestDay {
            insights.append("\(bestDay)s are your strongest performance day.")
        }
        if analysis.avgSnoozeCount < 0.2 {
            insights.append("Great snooze discipline - you're getting up right away.")
        } else if analysis.avgSnoozeCount > 0.5 {
            insights.append("Try reducing snooze usage for better mornings.")
        }
        if let bestTime = analysis.bestTimeRange {
            insights.append("You're most consistent around \(bestTime).")
        }

        let recommendation: String?
        if analysis.onTimePercentage < 70 {
            recommendation = "Focus on getting up without snooze this week."
        } else if let worstDay = analysis.worstDay,
                  let count = analysis.completionsByDay[worstDay], count == 0 {
            recommendation = "Work on consistency on \(worstDay)s."
        } else if analysis.onTimePercentage >= 90,
                  let streak = streakData, streak.currentStreak >= 7 {
            recommendation = "Consider increasing the difficulty level!"
        } else {
            recommendation = nil
        }

        return ProgressSummary(
            period: period,
            headline: headline,
            details: details,
            insights: insights,
            recommendation: recommendation,
            generatedAt: Date()
        )
    }

    // MARK: - Smart Difficulty Recommendation

    func analyzeDifficultyRecommendation(
        records: [ProofRecord],
        currentLevel: Int,
        currentStreak: Int
    ) -> DifficultyRecommendation? {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentRecords = records.filter { $0.completedAt >= oneWeekAgo }

        guard recentRecords.count >= 5 else { return nil }

        let successRate = Double(recentRecords.filter { $0.wasOnTime }.count) /
                         Double(recentRecords.count)

        if currentLevel < 4 && successRate >= 0.9 && currentStreak >= 7 {
            return DifficultyRecommendation(
                suggestedLevel: currentLevel + 1,
                reason: "You've been very consistent! Ready for a bigger challenge?",
                isIncrease: true
            )
        }

        if currentLevel > 1 && successRate < 0.5 && recentRecords.count >= 7 {
            return DifficultyRecommendation(
                suggestedLevel: currentLevel - 1,
                reason: "Let's rebuild your streak with a more manageable level.",
                isIncrease: false
            )
        }

        return nil
    }
}
