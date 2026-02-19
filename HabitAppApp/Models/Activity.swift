//
//  Activity.swift
//  HabitApp
//
//  Created by Cyril Malle-Barlow on 1/30/26.
//
//  Data model for activity tracking with timer
//

import Foundation
import FirebaseFirestore

struct Activity: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var categoryName: String
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval // in seconds
    var isActive: Bool // true if timer is still running
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Computed property for formatted duration
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    // Initialize new activity
    init(userId: String, categoryName: String, startTime: Date = Date()) {
        self.userId = userId
        self.categoryName = categoryName
        self.startTime = startTime
        self.duration = 0
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// Category for organizing activities
struct ActivityCategory: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var name: String
    var colorHex: String? // Optional color for UI
    var notificationInterval: TimeInterval? // Optional reminder interval in seconds
    var createdAt: Date

    init(userId: String, name: String, colorHex: String? = nil, notificationInterval: TimeInterval? = nil) {
        self.userId = userId
        self.name = name
        self.colorHex = colorHex
        self.notificationInterval = notificationInterval
        self.createdAt = Date()
    }
}
