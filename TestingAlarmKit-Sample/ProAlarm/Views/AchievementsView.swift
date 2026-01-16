//
//  AchievementsView.swift
//  ProAlarm
//
//  Display achievement badges
//

import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var unlockedAchievements: [UnlockedAchievement]

    private var unlockedTypes: Set<AchievementType> {
        Set(unlockedAchievements.compactMap { $0.type })
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress summary
                    progressHeader

                    // Achievement grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AchievementType.allCases, id: \.self) { achievement in
                            AchievementCard(
                                achievement: achievement,
                                isUnlocked: unlockedTypes.contains(achievement),
                                unlockedDate: unlockedDate(for: achievement)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Achievements")
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

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("\(unlockedTypes.count) / \(AchievementType.allCases.count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Achievements Unlocked")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(), value: progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding()
    }

    private var progress: CGFloat {
        guard !AchievementType.allCases.isEmpty else { return 0 }
        return CGFloat(unlockedTypes.count) / CGFloat(AchievementType.allCases.count)
    }

    private func unlockedDate(for type: AchievementType) -> Date? {
        unlockedAchievements.first { $0.type == type }?.unlockedAt
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: AchievementType
    let isUnlocked: Bool
    let unlockedDate: Date?

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? achievementColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)

                Image(systemName: achievement.icon)
                    .font(.system(size: 30))
                    .foregroundStyle(isUnlocked ? achievementColor : Color.gray.opacity(0.4))
            }

            // Title
            Text(achievement.title)
                .font(.headline)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)

            // Description
            Text(achievement.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Unlocked date
            if let date = unlockedDate {
                Text(date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Text("Locked")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isUnlocked ? achievementColor.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.6)
    }

    private var achievementColor: Color {
        switch achievement.color {
        case "cyan": return .cyan
        case "orange": return .orange
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        case "green": return .green
        default: return .gray
        }
    }
}

#Preview {
    AchievementsView()
}
