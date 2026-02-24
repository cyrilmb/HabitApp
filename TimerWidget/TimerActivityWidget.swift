//
//  TimerActivityWidget.swift
//  TimerWidgetExtension
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TimerActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock Screen / StandBy banner
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.activityName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text("Paused")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    timerText(state: context.state)
                        .font(.system(.title, design: .monospaced))
                        .contentTransition(.numericText())
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                timerText(state: context.state)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minWidth: 40)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        HStack {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.activityName)
                    .font(.headline)

                if context.state.isPaused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Running")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            timerText(state: context.state)
                .font(.system(.title2, design: .monospaced))
                .contentTransition(.numericText())
        }
        .padding()
    }

    // MARK: - Timer Text

    @ViewBuilder
    private func timerText(state: TimerActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            // Show frozen time
            Text(formatElapsed(state.elapsedAtPause))
        } else {
            // Auto-counting timer from start date
            Text(state.timerStartDate, style: .timer)
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
