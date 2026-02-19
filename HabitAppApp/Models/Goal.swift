//
//  Goal.swift
//  HabitTracker
//
//  Data model for user goals
//

import Foundation
import FirebaseFirestore

struct Goal: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var categoryType: GoalCategoryType
    var categoryName: String
    var kind: GoalKind
    var comparison: GoalComparison
    var value: Double
    var unit: String
    var period: GoalPeriod?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(userId: String, categoryType: GoalCategoryType, categoryName: String, kind: GoalKind, comparison: GoalComparison, value: Double, unit: String, period: GoalPeriod?, isActive: Bool = true) {
        self.userId = userId
        self.categoryType = categoryType
        self.categoryName = categoryName
        self.kind = kind
        self.comparison = comparison
        self.value = value
        self.unit = unit
        self.period = period
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum GoalCategoryType: String, Codable, CaseIterable {
    case activity, substance, biometric
}

enum GoalKind: String, Codable, CaseIterable {
    case target
    case limit
}

enum GoalComparison: String, Codable, CaseIterable {
    case atLeast, atMost, exactly
}

/// UI-only enum for substance goal input mode (not persisted)
enum SubstanceGoalMode: String {
    case frequency  // unit = "times"
    case dosage     // unit = dosage unit like "mg", "drinks"
}

enum GoalPeriod: String, Codable, CaseIterable {
    case daily, weekly, monthly, yearly

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}
