//
//  GoalProgressCard.swift
//  HabitTracker
//
//  Reusable card showing goal progress
//

import SwiftUI

struct GoalProgressCard: View {
    let progress: GoalProgress

    var body: some View {
        HStack(spacing: 14) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(progressColor.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(progress.progressFraction, 1.0))
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress.progressFraction)

                Text(percentageText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(progress.goal.categoryName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(progress.goal.kind == .target ? "Target" : "Limit")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(progress.goal.kind == .target ? Color.green : Color.orange)
                        .clipShape(Capsule())
                }

                Text(progressDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(progress.periodLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if progress.isAchieved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    private var progressColor: Color {
        if progress.goal.kind == .limit || progress.goal.comparison == .atMost {
            // For limits: green when under, orange when close, red when over
            if progress.progressFraction > 1.0 { return .red }
            if progress.progressFraction > 0.8 { return .orange }
            return .green
        } else {
            // For targets: green when achieved, orange when partial, red when low
            if progress.isAchieved { return .green }
            if progress.progressFraction > 0.5 { return .orange }
            return .red
        }
    }

    private var percentageText: String {
        let pct = min(progress.progressFraction * 100, 999)
        return String(format: "%.0f%%", pct)
    }

    private var progressDescription: String {
        let currentText = GoalFormatters.formatGoalValue(progress.currentValue, goal: progress.goal)
        let goalText = GoalFormatters.formatGoalValue(progress.goal.value, goal: progress.goal)
        let unitText = GoalFormatters.formatGoalUnit(progress.goal)

        let comparisonText: String
        switch progress.goal.comparison {
        case .atLeast: comparisonText = "\u{2265}"  // ≥
        case .atMost: comparisonText = "\u{2264}"   // ≤
        case .exactly: comparisonText = "="
        }

        if unitText.isEmpty {
            return "\(currentText) / \(comparisonText) \(goalText)"
        }
        return "\(currentText) / \(comparisonText) \(goalText) \(unitText)"
    }
}
