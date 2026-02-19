//
//  TimeHelpers.swift
//  HabitTracker
//
//  Shared time formatting helpers
//

import Foundation

func formatInterval(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    if minutes >= 60 {
        return "\(minutes / 60)h"
    }
    return "\(minutes)m"
}
