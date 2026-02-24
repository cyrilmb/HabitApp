//
//  DailyHabit.swift
//  HabitTracker
//
//  Data models for daily habit checklist feature
//

import Foundation
import FirebaseFirestore

struct DailyHabit: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var name: String
    var icon: String           // SF Symbol name
    var colorHex: String       // hex color for the icon background
    var sortOrder: Int
    var createdAt: Date
}

struct HabitCompletion: Identifiable, Codable {
    @DocumentID var id: String?
    var habitId: String
    var userId: String
    var date: String           // "yyyy-MM-dd" for easy querying
    var completedAt: Date
}
