//
//  GoalFormatters.swift
//  HabitTracker
//
//  Centralized conversion and formatting helpers for goal values
//

import Foundation

enum GoalFormatters {

    // MARK: - Time of Day (fractional hours <-> display)

    /// 22.5 → "10:30 PM"
    static func formatFractionalHoursAsTime(_ hours: Double) -> String {
        let normalizedHours = hours.truncatingRemainder(dividingBy: 24)
        let h = Int(normalizedHours)
        let m = Int((normalizedHours - Double(h)) * 60)
        let date = Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// Extracts fractional hours from a Date (e.g., 10:30 PM → 22.5)
    static func fractionalHoursFromDate(_ date: Date) -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
    }

    /// Constructs a Date with just hour/minute from fractional hours (for DatePicker binding)
    static func dateFromFractionalHours(_ hours: Double) -> Date {
        let normalizedHours = hours.truncatingRemainder(dividingBy: 24)
        let h = Int(normalizedHours)
        let m = Int((normalizedHours - Double(h)) * 60)
        return Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
    }

    // MARK: - Duration (decimal hours <-> h:m components)

    /// 2.5 → "2h 30m"
    static func formatDecimalHoursAsDuration(_ hours: Double) -> String {
        let totalMinutes = Int(round(hours * 60))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 && m > 0 {
            return "\(h)h \(m)m"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)m"
        }
    }

    /// (2, 30) → 2.5
    static func decimalHoursFromComponents(hours: Int, minutes: Int) -> Double {
        Double(hours) + Double(minutes) / 60.0
    }

    /// 2.5 → (2, 30)
    static func componentsFromDecimalHours(_ hours: Double) -> (hours: Int, minutes: Int) {
        let totalMinutes = Int(round(hours * 60))
        return (totalMinutes / 60, totalMinutes % 60)
    }

    // MARK: - Weight Conversion

    static func lbsToKg(_ lbs: Double) -> Double {
        lbs / 2.20462
    }

    static func kgToLbs(_ kg: Double) -> Double {
        kg * 2.20462
    }

    // MARK: - Unified Formatting

    /// Routes to the appropriate formatter based on goal type/unit
    static func formatGoalValue(_ value: Double, goal: Goal) -> String {
        let biometricType = BiometricType(rawValue: goal.categoryName)

        // Time-of-day (bed/wake time)
        if goal.unit == "time" || biometricType == .bedTime || biometricType == .wakeTime {
            return formatFractionalHoursAsTime(value)
        }

        // Duration (activity hours or sleep duration)
        if goal.unit == "hours" && (goal.categoryType == .activity || biometricType == .sleepDuration) {
            return formatDecimalHoursAsDuration(value)
        }

        // Mood axes
        if goal.unit == "pleasantness" || goal.unit == "energy" {
            return String(format: "%+.2f", value)
        }

        // Default numeric formatting
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    /// Returns the display unit string (empty for types where the format is self-evident)
    static func formatGoalUnit(_ goal: Goal) -> String {
        let biometricType = BiometricType(rawValue: goal.categoryName)

        // Time-of-day and duration formats are self-describing
        if goal.unit == "time" || biometricType == .bedTime || biometricType == .wakeTime {
            return ""
        }
        if goal.unit == "hours" && (goal.categoryType == .activity || biometricType == .sleepDuration) {
            return ""
        }

        return goal.unit
    }
}
