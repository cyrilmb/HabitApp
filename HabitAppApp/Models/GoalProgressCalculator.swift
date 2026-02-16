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
        if goal.value > 0 {
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
            // Periodic: filter by time window
            matching = biometrics.filter {
                $0.type == matchingType && $0.timestamp >= start && $0.timestamp < end
            }
        } else {
            // One-time: use most recent value
            matching = biometrics.filter { $0.type == matchingType }
        }

        guard !matching.isEmpty else { return 0 }

        if goal.period == nil {
            // One-time: return latest value
            let sorted = matching.sorted { $0.timestamp > $1.timestamp }
            return sorted.first?.value ?? 0
        } else {
            // Periodic: return average
            let sum = matching.reduce(0.0) { $0 + $1.value }
            return sum / Double(matching.count)
        }
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
