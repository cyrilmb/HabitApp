//
//  GoalProgress.swift
//  HabitTracker
//
//  Progress tracking for goals
//

import Foundation

struct GoalProgress: Identifiable {
    var id: String { goal.id ?? UUID().uuidString }
    var goal: Goal
    var currentValue: Double
    var progressFraction: Double
    var periodLabel: String
    var isAchieved: Bool
}
