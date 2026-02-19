//
//  GoalProgressCalculator.swift
//  HabitTracker
//
//  Calculates progress towards goals
//

import Foundation

enum GoalProgressCalculator {

    static func calculateProgress(
        goal: Goal,
        activities: [Activity],
        drugLogs: [DrugLog],
        biometrics: [Biometric],
        referenceDate: Date = Date()
    ) -> GoalProgress {
        let (start, end) = periodWindow(for: goal.period, referenceDate: referenceDate)
        let label = periodLabel(for: goal.period)

        let currentValue: Double
        switch goal.categoryType {
        case .activity:
            currentValue = calculateActivityValue(goal: goal, activities: activities, start: start, end: end)
        case .substance:
            currentValue = calculateSubstanceValue(goal: goal, drugLogs: drugLogs, start: start, end: end)
        case .biometric:
            currentValue = calculateBiometricValue(goal: goal, biometrics: biometrics, start: start, end: end)
        }

        let fraction: Double
        let biometricType = BiometricType(rawValue: goal.categoryName)
        if goal.unit == "time" || biometricType == .bedTime || biometricType == .wakeTime {
            // Time-of-day: fraction based on proximity (within 3h = 0%, exact = 100%)
            let maxDeviation = 3.0 // hours
            let diff = abs(normalizeTimeDiff(currentValue, goal.value))
            fraction = max(0, 1.0 - diff / maxDeviation)
        } else if goal.value != 0 {
            fraction = currentValue / goal.value
        } else {
            fraction = 0
        }

        let isAchieved: Bool
        switch goal.comparison {
        case .atLeast:
            isAchieved = currentValue >= goal.value
        case .atMost:
            isAchieved = currentValue <= goal.value
        case .exactly:
            isAchieved = abs(currentValue - goal.value) < 0.01
        }

        return GoalProgress(
            goal: goal,
            currentValue: currentValue,
            progressFraction: fraction,
            periodLabel: label,
            isAchieved: isAchieved
        )
    }

    // MARK: - Activity

    private static func calculateActivityValue(goal: Goal, activities: [Activity], start: Date, end: Date) -> Double {
        let matching = activities.filter {
            $0.categoryName == goal.categoryName && $0.startTime >= start && $0.startTime < end
        }
        let totalSeconds = matching.reduce(0.0) { $0 + $1.duration }
        if goal.unit == "minutes" {
            return totalSeconds / 60.0
        }
        return totalSeconds / 3600.0 // hours
    }

    // MARK: - Substance

    private static func calculateSubstanceValue(goal: Goal, drugLogs: [DrugLog], start: Date, end: Date) -> Double {
        let matching = drugLogs.filter {
            $0.categoryName == goal.categoryName && $0.timestamp >= start && $0.timestamp < end
        }
        // If the goal unit matches dosage (e.g., "mg"), sum dosages; otherwise count logs
        if let first = matching.first, first.dosageUnit == goal.unit, matching.allSatisfy({ $0.dosage != nil }) {
            return matching.reduce(0.0) { $0 + ($1.dosage ?? 0) }
        }
        return Double(matching.count)
    }

    // MARK: - Biometric

    private static func calculateBiometricValue(goal: Goal, biometrics: [Biometric], start: Date, end: Date) -> Double {
        let matchingType = BiometricType(rawValue: goal.categoryName)
        let matching: [Biometric]

        if goal.period != nil {
            matching = biometrics.filter {
                $0.type == matchingType && $0.timestamp >= start && $0.timestamp < end
            }
        } else {
            matching = biometrics.filter { $0.type == matchingType }
        }

        guard !matching.isEmpty else { return 0 }

        // Bed/Wake time: extract time-of-day from timestamp
        if matchingType == .bedTime || matchingType == .wakeTime || goal.unit == "time" {
            let times = matching.map { GoalFormatters.fractionalHoursFromDate($0.timestamp) }
            return averageTimeOfDay(times, isBedTime: matchingType == .bedTime)
        }

        // Mood: support energy axis via secondaryValue
        if matchingType == .mood && goal.unit == "energy" {
            let values = matching.compactMap { $0.secondaryValue }
            guard !values.isEmpty else { return 0 }
            return values.reduce(0, +) / Double(values.count)
        }

        // Weight: convert units if needed
        if matchingType == .weight {
            let extractValue: (Biometric) -> Double = { bio in
                // Biometric data stored in its own unit; convert if goal unit differs
                if goal.unit == "kg" && bio.unit == "lbs" {
                    return GoalFormatters.lbsToKg(bio.value)
                } else if goal.unit == "lbs" && bio.unit == "kg" {
                    return GoalFormatters.kgToLbs(bio.value)
                }
                return bio.value
            }

            if goal.period == nil {
                let sorted = matching.sorted { $0.timestamp > $1.timestamp }
                return extractValue(sorted.first!)
            } else {
                let sum = matching.reduce(0.0) { $0 + extractValue($1) }
                return sum / Double(matching.count)
            }
        }

        if goal.period == nil {
            let sorted = matching.sorted { $0.timestamp > $1.timestamp }
            return sorted.first?.value ?? 0
        } else {
            let sum = matching.reduce(0.0) { $0 + $1.value }
            return sum / Double(matching.count)
        }
    }

    /// Average time-of-day values, handling midnight crossing for bed times
    private static func averageTimeOfDay(_ times: [Double], isBedTime: Bool) -> Double {
        guard !times.isEmpty else { return 0 }
        if isBedTime {
            // Normalize: values < 6 hours are after-midnight bed times, shift by +24
            let normalized = times.map { $0 < 6 ? $0 + 24 : $0 }
            let avg = normalized.reduce(0, +) / Double(normalized.count)
            return avg.truncatingRemainder(dividingBy: 24)
        } else {
            return times.reduce(0, +) / Double(times.count)
        }
    }

    /// Shortest difference between two times of day (handles midnight wrap)
    private static func normalizeTimeDiff(_ a: Double, _ b: Double) -> Double {
        var diff = a - b
        if diff > 12 { diff -= 24 }
        if diff < -12 { diff += 24 }
        return diff
    }

    // MARK: - Period Window

    private static func periodWindow(for period: GoalPeriod?, referenceDate: Date) -> (Date, Date) {
        let cal = Calendar.current

        guard let period = period else {
            // One-time: span all time
            return (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 99999999999))
        }

        switch period {
        case .daily:
            let start = cal.startOfDay(for: referenceDate)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .weekly:
            let start = cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: referenceDate).date!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: referenceDate)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        case .yearly:
            let comps = cal.dateComponents([.year], from: referenceDate)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: .year, value: 1, to: start)!
            return (start, end)
        }
    }

    private static func periodLabel(for period: GoalPeriod?) -> String {
        guard let period = period else { return "Overall" }
        switch period {
        case .daily: return "Today"
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        case .yearly: return "This Year"
        }
    }
}
