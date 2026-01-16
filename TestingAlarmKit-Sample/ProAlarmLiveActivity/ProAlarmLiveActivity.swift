//
//  ProAlarmLiveActivity.swift
//  ProAlarmLiveActivityExtension
//
//  Live Activity widget for Water Alarm
//

import ActivityKit
import WidgetKit
import SwiftUI
import AlarmKit

struct ProAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<WaterAlarmData>.self) { context in
            lockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.cyan.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    alarmTitle(attributes: context.attributes)
                        .padding(.trailing, 6)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    bottomView(attributes: context.attributes)
                        .padding(.horizontal, 2)
                }
            } compactLeading: {
                Text(context.attributes.metadata?.formattedTime ?? "")
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } compactTrailing: {
                Image(systemName: "alarm.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(.cyan)
            }
            .keylineTint(.cyan)
        }
    }

    // MARK: - Lock Screen View

    func lockScreenView(attributes: AlarmAttributes<WaterAlarmData>, state: AlarmPresentationState) -> some View {
        VStack {
            HStack(alignment: .top) {
                alarmTitle(attributes: attributes)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            bottomView(attributes: attributes)
        }
        .padding(.all, 12)
    }

    // MARK: - Bottom View

    func bottomView(attributes: AlarmAttributes<WaterAlarmData>) -> some View {
        HStack {
            // Left side: time display
            VStack(alignment: .leading) {
                Text("Water Alarm")
                    .font(.system(size: 28, weight: .bold))
                Text(attributes.metadata?.formattedTime ?? "")
                    .font(.subheadline)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)

            Spacer()

            // Right side: AlarmKit provides default controls
            // The "Wake Up" button is configured in AlarmPresentation
        }
    }

    // MARK: - Alarm Title

    func alarmTitle(attributes: AlarmAttributes<WaterAlarmData>) -> some View {
        let label = attributes.metadata?.label ?? "Water Alarm"
        return Text(label)
            .font(.title3)
            .fontWeight(.medium)
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: AlarmAttributes<WaterAlarmData>.preview) {
    ProAlarmLiveActivity()
} contentStates: {
    AlarmPresentationState.preview
}

// MARK: - Preview Data

extension AlarmAttributes<WaterAlarmData> {
    static var preview: AlarmAttributes<WaterAlarmData> {
        AlarmAttributes(
            presentation: AlarmPresentation(
                alert: .init(
                    title: "Water Alarm",
                    stopButton: AlarmButton(text: "Wake Up", textColor: .white, systemImageName: "sunrise.fill")
                )
            ),
            metadata: WaterAlarmData(
                waterAlarmId: UUID(),
                alarmHour: 7,
                alarmMinute: 0,
                label: "Morning Water",
                requiresPhoto: true,
                snoozeAllowed: true
            ),
            tintColor: .cyan
        )
    }
}

extension AlarmPresentationState {
    static var preview: AlarmPresentationState {
        // Preview state - actual state comes from AlarmKit at runtime
        fatalError("Preview state not available")
    }
}
