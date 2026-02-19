//
//  AppConstants.swift
//  HabitTracker
//
//  Shared constants used across views
//

import Foundation

enum AppConstants {
    static let colorOptions = [
        // Reds
        "#FF3B30", "#DC143C", "#C0392B", "#8B0000",
        // Oranges
        "#FF9500", "#FF6347", "#E67E22", "#D35400",
        // Yellows
        "#FFD700", "#F39C12", "#F1C40F", "#D4AC0D",
        // Greens
        "#34C759", "#2ECC71", "#27AE60", "#1E8449",
        // Blues
        "#007AFF", "#3498DB", "#2980B9", "#1F618D",
        // Purples
        "#5856D6", "#9B59B6", "#8E44AD", "#6C3483",
        // Pinks
        "#FF2D55", "#E91E63", "#EC407A", "#AD1457",
        // Neutrals
        "#2C3E50", "#34495E", "#7F8C8D", "#95A5A6",
        "#BDC3C7", "#D5DBDB", "#ECF0F1", "#F8F9FA"
    ]

    static let notificationOptions: [(String, TimeInterval)] = [
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("Custom", -1)
    ]
}
