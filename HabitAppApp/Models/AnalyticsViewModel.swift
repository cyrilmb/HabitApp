//
//  AnalyticsViewModel.swift
//  HabitTracker
//
//  ViewModel for processing and presenting analytics data
//

import Foundation
import Combine
import SwiftUI

class AnalyticsViewModel: ObservableObject {
    @AppStorage("weightUnit") var weightUnit = "lbs"
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Activity Data
    @Published var activityTimeData: [ActivityTimeData] = []
    @Published var activityTrendData: [TrendData] = []
    @Published var totalActivities = 0
    @Published var totalActivityTime = "0h"
    @Published var mostTrackedActivity = "-"
    @Published var averageDuration = "-"
    @Published var activityTimeChange = "-"
    @Published var activityCountChange = "-"
    @Published var busiestDay = "-"
    
    // Substance Data
    @Published var substanceCountData: [SubstanceCountData] = []
    @Published var substanceTrendData: [SubstanceTrendData] = []
    @Published var totalSubstances = 0
    @Published var mostUsedSubstance = "-"
    @Published var averageSubstancePerDay = "-"
    @Published var topMethod = "-"
    @Published var substanceCountChange = "-"
    @Published var substanceTrend = "-"
    
    // Substance per-category filtering
    @Published var substanceCategories: [String] = []
    @Published var selectedSubstanceCategory: String = "All" {
        didSet { recomputeFilteredSubstanceData() }
    }
    @Published var filteredSubstanceCountData: [SubstanceCountData] = []
    @Published var filteredSubstanceTrendData: [SubstanceTrendData] = []
    @Published var filteredTotalCount = 0
    @Published var filteredDailyAvg = "-"
    
    // Biometric Data
    @Published var weightTrendData: [BiometricTrendData] = []
    @Published var sleepTrendData: [BiometricTrendData] = []
    @Published var bedWakeTimeData: [BedWakeDataPoint] = []
    @Published var totalBiometrics = 0
    @Published var latestWeight = "-"
    @Published var averageSleep = "-"
    @Published var weightChange = "-"
    @Published var sleepChange = "-"

    // Goal Progress
    @Published var goalProgressItems: [GoalProgress] = []

    // Habit Streak Data
    @Published var habitStreakData: [HabitStreakData] = []
    @Published var dailyHabitCompletionData: [DailyHabitCompletionData] = []
    @Published var goalStreakData: [GoalStreakData] = []
    @Published var totalHabits = 0
    @Published var periodCompletions = 0
    @Published var completionRate = "-"
    @Published var bestOverallStreak = "-"
    @Published var completionRateChange = "-"

    // Mood Data
    @Published var moodScatterData: [MoodScatterPoint] = []
    @Published var moodTrendData: [MoodTrendPoint] = []
    @Published var moodQuadrantData: [MoodQuadrantData] = []
    @Published var totalMoodEntries = 0
    @Published var averagePleasantness = "-"
    @Published var averageEnergy = "-"
    @Published var mostCommonQuadrant = "-"
    
    // Raw time-filtered arrays kept so filtered substance views can recompute
    private var activities: [Activity] = []
    private var drugLogs: [DrugLog] = []
    private var biometrics: [Biometric] = []
    private var categories: [ActivityCategory] = []
    private var dailyHabits: [DailyHabit] = []
    private var allHabitCompletions: [HabitCompletion] = []

    // Previous period arrays for comparative stats
    private var prevActivities: [Activity] = []
    private var prevDrugLogs: [DrugLog] = []
    private var prevBiometrics: [Biometric] = []
    private var isAllTime = false
    private var currentDayCount: Int?
    
    func loadData(for timeRange: TimeRange, date: Date = Date()) {
        isLoading = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let cal = Calendar.current
                let (start, _) = self.windowBounds(for: timeRange, anchor: date)

                // Fetch 2x the window so we have a previous period for comparisons
                let sinceDate: Date?
                if let days = timeRange.dayCount {
                    sinceDate = cal.date(byAdding: .day, value: -days, to: start)
                } else {
                    sinceDate = nil  // All Time
                }

                async let activitiesTask   = FirebaseService.shared.fetchActivities(since: sinceDate)
                async let drugLogsTask     = FirebaseService.shared.fetchDrugLogs(since: sinceDate)
                async let biometricsTask   = FirebaseService.shared.fetchBiometrics(since: sinceDate)
                async let categoriesTask   = FirebaseService.shared.fetchActivityCategories()

                let (fetchedActivities, fetchedDrugLogs, fetchedBiometrics, fetchedCategories) =
                    try await (activitiesTask, drugLogsTask, biometricsTask, categoriesTask)

                // Fetch goals, habits, and completions separately so a failure doesn't break analytics
                let fetchedGoals = (try? await FirebaseService.shared.fetchGoals()) ?? []
                let fetchedHabits = (try? await FirebaseService.shared.fetchDailyHabits()) ?? []
                let fetchedCompletions = (try? await FirebaseService.shared.fetchAllHabitCompletions()) ?? []

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let (start, end) = self.windowBounds(for: timeRange, anchor: date)
                    self.isAllTime = (timeRange == .all)
                    self.currentDayCount = timeRange.dayCount
                    self.categories  = fetchedCategories
                    self.activities  = fetchedActivities.filter  { $0.startTime >= start && $0.startTime < end }
                    self.drugLogs    = fetchedDrugLogs.filter    { $0.timestamp  >= start && $0.timestamp  < end }
                    self.biometrics  = fetchedBiometrics.filter  { $0.timestamp  >= start && $0.timestamp  < end }
                    self.dailyHabits = fetchedHabits
                    self.allHabitCompletions = fetchedCompletions

                    // Previous period arrays (everything before current window start)
                    if let days = timeRange.dayCount,
                       let prevStart = cal.date(byAdding: .day, value: -days, to: start) {
                        self.prevActivities = fetchedActivities.filter  { $0.startTime >= prevStart && $0.startTime < start }
                        self.prevDrugLogs   = fetchedDrugLogs.filter    { $0.timestamp  >= prevStart && $0.timestamp  < start }
                        self.prevBiometrics = fetchedBiometrics.filter  { $0.timestamp  >= prevStart && $0.timestamp  < start }
                    } else {
                        self.prevActivities = []
                        self.prevDrugLogs   = []
                        self.prevBiometrics = []
                    }

                    self.processActivityData()
                    self.processSubstanceData()
                    self.processBiometricData()
                    self.processMoodData()
                    self.processGoalProgress(goals: fetchedGoals, allActivities: fetchedActivities, allDrugLogs: fetchedDrugLogs, allBiometrics: fetchedBiometrics, date: date)
                    self.processHabitData(windowStart: start, windowEnd: end)
                    self.processGoalStreaks(goals: fetchedGoals, allActivities: fetchedActivities, allDrugLogs: fetchedDrugLogs, allBiometrics: fetchedBiometrics)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to load analytics data."
                    self?.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Window Bounds

    /// Returns the [start, end) interval for a given range anchored on `anchor`.
    /// The anchor is the last day of the window. The window rolls backward by `dayCount` days.
    /// For All Time it spans the entire epoch → far future.
    private func windowBounds(for range: TimeRange, anchor: Date) -> (Date, Date) {
        let cal = Calendar.current
        if let days = range.dayCount {
            let startOfAnchor = cal.startOfDay(for: anchor)
            let end   = cal.date(byAdding: .day, value: 1, to: startOfAnchor) ?? startOfAnchor
            let start = cal.date(byAdding: .day, value: -(days - 1), to: startOfAnchor) ?? startOfAnchor
            return (start, end)
        } else {
            // All Time
            return (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 99999999999))
        }
    }
    
    // MARK: - Process Activity Data
    
    private func processActivityData() {
        activityTimeData = []
        activityTrendData = []
        totalActivities = activities.count

        let totalSeconds = activities.reduce(0.0) { $0 + $1.duration }
        totalActivityTime = String(format: "%.1fh", totalSeconds / 3600)

        if !activities.isEmpty {
            let avgMin = (totalSeconds / Double(activities.count)) / 60
            averageDuration = avgMin >= 60 ? String(format: "%.1fh", avgMin / 60) : String(format: "%.0fm", avgMin)
        } else { averageDuration = "-" }

        let grouped = Dictionary(grouping: activities, by: { $0.categoryName })
        activityTimeData = grouped.map { categoryName, categoryActivities in
            // Find the category color
            let color = categories.first(where: { $0.name == categoryName })?.colorHex ?? "#007AFF"
            return ActivityTimeData(
                name: categoryName,
                hours: categoryActivities.reduce(0.0) { $0 + $1.duration } / 3600,
                count: categoryActivities.count,
                colorHex: color
            )
        }
        .sorted { $0.hours > $1.hours }
        mostTrackedActivity = activityTimeData.first?.name ?? "-"

        // Comparative stats vs previous period
        if !isAllTime && !prevActivities.isEmpty {
            let prevSeconds = prevActivities.reduce(0.0) { $0 + $1.duration }
            let timeDiffHours = (totalSeconds - prevSeconds) / 3600
            activityTimeChange = String(format: "%@%.1fh", timeDiffHours >= 0 ? "+" : "", timeDiffHours)

            let countDiff = activities.count - prevActivities.count
            activityCountChange = "\(countDiff >= 0 ? "+" : "")\(countDiff)"
        } else if !isAllTime && prevActivities.isEmpty && !activities.isEmpty {
            activityTimeChange = String(format: "+%.1fh", totalSeconds / 3600)
            activityCountChange = "+\(activities.count)"
        } else {
            activityTimeChange = "-"
            activityCountChange = "-"
        }

        // Busiest day
        let cal = Calendar.current
        let byDay = Dictionary(grouping: activities) { cal.startOfDay(for: $0.startTime) }
        if let (busiestDate, _) = byDay.max(by: { $0.value.reduce(0) { $0 + $1.duration } < $1.value.reduce(0) { $0 + $1.duration } }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            busiestDay = formatter.string(from: busiestDate)
        } else {
            busiestDay = "-"
        }

        // Per-activity daily trend data
        let byCategoryAndDay = Dictionary(grouping: activities) { activity in
            "\(activity.categoryName)||\(Calendar.current.startOfDay(for: activity.startTime).timeIntervalSince1970)"
        }
        activityTrendData = byCategoryAndDay.map { key, group in
            let name = group.first!.categoryName
            let date = Calendar.current.startOfDay(for: group.first!.startTime)
            let mins = group.reduce(0.0) { $0 + $1.duration } / 60
            return TrendData(date: date, minutes: mins, categoryName: name)
        }
        .sorted { $0.date < $1.date }
    }
    
    // MARK: - Process Substance Data
    
    private func processSubstanceData() {
        substanceCountData = []
        substanceTrendData = []
        filteredSubstanceCountData = []
        filteredSubstanceTrendData = []
        totalSubstances = drugLogs.count
        substanceCategories = Array(Set(drugLogs.map { $0.categoryName })).sorted()
        
        // Reset selection if it no longer exists in the data
        if selectedSubstanceCategory != "All" && !substanceCategories.contains(selectedSubstanceCategory) {
            selectedSubstanceCategory = "All"
        }
        
        // Full aggregates for the top stat cards
        let catGroups = Dictionary(grouping: drugLogs, by: { $0.categoryName })
        substanceCountData = catGroups.map { SubstanceCountData(name: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
        mostUsedSubstance   = substanceCountData.first?.name ?? "-"
        topMethod           = Dictionary(grouping: drugLogs, by: { $0.method }).max(by: { $0.value.count < $1.value.count })?.key ?? "-"
        
        if !drugLogs.isEmpty {
            let days = Set(drugLogs.map { Calendar.current.startOfDay(for: $0.timestamp) })
            averageSubstancePerDay = String(format: "%.1f", Double(drugLogs.count) / Double(max(days.count, 1)))
        } else { averageSubstancePerDay = "-" }

        // Comparative stats vs previous period
        if !isAllTime && !prevDrugLogs.isEmpty {
            let countDiff = drugLogs.count - prevDrugLogs.count
            substanceCountChange = "\(countDiff >= 0 ? "+" : "")\(countDiff)"
            if countDiff > 0 { substanceTrend = "\u{2191} Up" }
            else if countDiff < 0 { substanceTrend = "\u{2193} Down" }
            else { substanceTrend = "\u{2014} Same" }
        } else if !isAllTime && prevDrugLogs.isEmpty && !drugLogs.isEmpty {
            substanceCountChange = "+\(drugLogs.count)"
            substanceTrend = "\u{2191} Up"
        } else {
            substanceCountChange = "-"
            substanceTrend = "-"
        }

        let dailyGroups = Dictionary(grouping: drugLogs) { Calendar.current.startOfDay(for: $0.timestamp) }
        substanceTrendData = dailyGroups.map { SubstanceTrendData(date: $0.key, count: $0.value.count) }.sorted { $0.date < $1.date }

        recomputeFilteredSubstanceData()
    }
    
    private func recomputeFilteredSubstanceData() {
        let logs = selectedSubstanceCategory == "All"
            ? drugLogs
            : drugLogs.filter { $0.categoryName == selectedSubstanceCategory }
        
        // When a single category is selected, group by method; otherwise group by category
        if selectedSubstanceCategory != "All" {
            let methodGroups = Dictionary(grouping: logs, by: { $0.method })
            filteredSubstanceCountData = methodGroups.map { SubstanceCountData(name: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
        } else {
            let catGroups = Dictionary(grouping: logs, by: { $0.categoryName })
            filteredSubstanceCountData = catGroups.map { SubstanceCountData(name: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
        }
        
        filteredTotalCount = logs.count
        
        if !logs.isEmpty {
            let days = Set(logs.map { Calendar.current.startOfDay(for: $0.timestamp) })
            filteredDailyAvg = String(format: "%.1f", Double(logs.count) / Double(max(days.count, 1)))
        } else { filteredDailyAvg = "-" }
        
        let dailyGroups = Dictionary(grouping: logs) { Calendar.current.startOfDay(for: $0.timestamp) }
        filteredSubstanceTrendData = dailyGroups.map { SubstanceTrendData(date: $0.key, count: $0.value.count) }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Process Biometric Data
    
    private func processBiometricData() {
        weightTrendData = []
        sleepTrendData = []
        bedWakeTimeData = []
        totalBiometrics = biometrics.count
        
        // Weight
        let useKg = weightUnit == "kg"
        let unitLabel = useKg ? "kg" : "lbs"
        let weightData = biometrics.filter { $0.type == .weight }.sorted { $0.timestamp > $1.timestamp }
        if let latest = weightData.first {
            let displayVal = useKg ? GoalFormatters.lbsToKg(latest.value) : latest.value
            latestWeight = String(format: "%.1f %@", displayVal, unitLabel)
            if let oldest = weightData.last, weightData.count > 1 {
                let change = latest.value - oldest.value
                let displayChange = useKg ? GoalFormatters.lbsToKg(change) : change
                weightChange = String(format: "%@%.1f %@", displayChange >= 0 ? "+" : "", displayChange, unitLabel)
            } else { weightChange = "-" }
        } else { latestWeight = "-"; weightChange = "-" }

        weightTrendData = weightData.map {
            BiometricTrendData(date: $0.timestamp, value: useKg ? GoalFormatters.lbsToKg($0.value) : $0.value)
        }.sorted { $0.date < $1.date }
        
        // Sleep duration
        let sleepData = biometrics.filter { $0.type == .sleepDuration }.sorted { $0.timestamp < $1.timestamp }
        sleepTrendData = sleepData.map { BiometricTrendData(date: $0.timestamp, value: $0.value) }
        let currentAvgSleep = sleepData.isEmpty ? 0.0 : sleepData.reduce(0.0) { $0 + $1.value } / Double(sleepData.count)
        averageSleep = sleepData.isEmpty ? "-" : String(format: "%.1fh", currentAvgSleep)

        // Sleep change vs previous period
        let prevSleepData = prevBiometrics.filter { $0.type == .sleepDuration }
        if !isAllTime && !prevSleepData.isEmpty && !sleepData.isEmpty {
            let prevAvgSleep = prevSleepData.reduce(0.0) { $0 + $1.value } / Double(prevSleepData.count)
            let diff = currentAvgSleep - prevAvgSleep
            sleepChange = String(format: "%@%.1fh", diff >= 0 ? "+" : "", diff)
        } else {
            sleepChange = "-"
        }
        
        // Bed & Wake times — anchored to the wake day (the morning date).
        // The vertical gap between the two lines represents sleep duration.
        // Evening bed times are shifted forward one day to the wake day.
        // After-midnight bed times already fall on the wake day.
        // Wake times use their actual date (already the wake day).
        var cal = Calendar.current
        cal.timeZone = .current  // Ensure local timezone for hour extraction
        var points: [BedWakeDataPoint] = []

        for b in biometrics where b.type == .bedTime {
            let h = cal.component(.hour, from: b.timestamp)
            let m = cal.component(.minute, from: b.timestamp)
            var hour = Double(h) + Double(m) / 60.0
            var wakeDay = cal.startOfDay(for: b.timestamp)
            if h < 6 {
                // After-midnight bed time — already on the wake day
                hour += 24
            } else {
                // Evening bed time — shift forward to the wake day
                wakeDay = cal.date(byAdding: .day, value: 1, to: wakeDay) ?? wakeDay
            }
            points.append(BedWakeDataPoint(date: wakeDay, hour: hour, type: "Bed Time"))
        }
        for w in biometrics where w.type == .wakeTime {
            let h = cal.component(.hour, from: w.timestamp)
            let m = cal.component(.minute, from: w.timestamp)
            var hour = Double(h) + Double(m) / 60.0
            let wakeDay = cal.startOfDay(for: w.timestamp)
            if h < 12 {
                hour += 24  // Map to 24+ so it appears above bed time on the chart
            }
            points.append(BedWakeDataPoint(date: wakeDay, hour: hour, type: "Wake Time"))
        }
        bedWakeTimeData = points.sorted { $0.date < $1.date }
    }

    // MARK: - Process Goal Progress

    private func processGoalProgress(goals: [Goal], allActivities: [Activity], allDrugLogs: [DrugLog], allBiometrics: [Biometric], date: Date) {
        goalProgressItems = goals.filter { $0.isActive }.map { goal in
            GoalProgressCalculator.calculateProgress(
                goal: goal,
                activities: allActivities,
                drugLogs: allDrugLogs,
                biometrics: allBiometrics,
                referenceDate: date
            )
        }
    }

    // MARK: - Process Mood Data

    private func processMoodData() {
        moodScatterData = []
        moodTrendData = []
        moodQuadrantData = []

        let moodEntries = biometrics.filter { $0.type == .mood }
        totalMoodEntries = moodEntries.count

        // Scatter data
        moodScatterData = moodEntries.map {
            MoodScatterPoint(pleasantness: $0.value, energy: $0.secondaryValue ?? 0)
        }

        // Trend data: average pleasantness and energy per day
        let dailyGroups = Dictionary(grouping: moodEntries) { Calendar.current.startOfDay(for: $0.timestamp) }
        moodTrendData = dailyGroups.map { date, entries in
            let avgP = entries.reduce(0.0) { $0 + $1.value } / Double(entries.count)
            let avgE = entries.reduce(0.0) { $0 + ($1.secondaryValue ?? 0) } / Double(entries.count)
            return MoodTrendPoint(date: date, pleasantness: avgP, energy: avgE)
        }.sorted { $0.date < $1.date }

        // Quadrant distribution
        var quadrants: [String: Int] = [
            "High Energy\n+ Pleasant": 0,
            "High Energy\n+ Unpleasant": 0,
            "Low Energy\n+ Pleasant": 0,
            "Low Energy\n+ Unpleasant": 0,
        ]
        for entry in moodEntries {
            let p = entry.value
            let e = entry.secondaryValue ?? 0
            if p >= 0 && e >= 0 {
                quadrants["High Energy\n+ Pleasant", default: 0] += 1
            } else if p < 0 && e >= 0 {
                quadrants["High Energy\n+ Unpleasant", default: 0] += 1
            } else if p >= 0 && e < 0 {
                quadrants["Low Energy\n+ Pleasant", default: 0] += 1
            } else {
                quadrants["Low Energy\n+ Unpleasant", default: 0] += 1
            }
        }

        let quadrantColors: [String: String] = [
            "High Energy\n+ Pleasant": "#FFD60A",     // Yale yellow
            "High Energy\n+ Unpleasant": "#FF3B30",   // Yale red
            "Low Energy\n+ Pleasant": "#34C759",       // Yale green
            "Low Energy\n+ Unpleasant": "#007AFF",     // Yale blue
        ]

        moodQuadrantData = quadrants.map { key, count in
            MoodQuadrantData(quadrant: key, count: count, color: quadrantColors[key] ?? "#8E8E93")
        }.sorted { $0.count > $1.count }

        // Stat cards
        if !moodEntries.isEmpty {
            let avgP = moodEntries.reduce(0.0) { $0 + $1.value } / Double(moodEntries.count)
            let avgE = moodEntries.reduce(0.0) { $0 + ($1.secondaryValue ?? 0) } / Double(moodEntries.count)
            averagePleasantness = String(format: "%.2f", avgP)
            averageEnergy = String(format: "%.2f", avgE)
            mostCommonQuadrant = moodQuadrantData.first?.quadrant.replacingOccurrences(of: "\n", with: " ") ?? "-"
        } else {
            averagePleasantness = "-"
            averageEnergy = "-"
            mostCommonQuadrant = "-"
        }
    }

    // MARK: - Process Habit Data

    private func processHabitData(windowStart: Date, windowEnd: Date) {
        let habits = dailyHabits
        let completions = allHabitCompletions
        totalHabits = habits.count

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        // Group completions by habitId
        let completionsByHabit = Dictionary(grouping: completions, by: { $0.habitId })

        var streaks: [HabitStreakData] = []
        var bestOverall = 0

        for habit in habits {
            guard let habitId = habit.id else { continue }
            let habitCompletions = completionsByHabit[habitId] ?? []
            let dateStrings = Set(habitCompletions.map { $0.date })

            let currentStreak = calculateCurrentStreak(dates: dateStrings, today: todayStr, formatter: dateFormatter)
            let bestStreak = calculateBestStreak(dates: dateStrings, formatter: dateFormatter)
            bestOverall = max(bestOverall, bestStreak)

            streaks.append(HabitStreakData(
                habitName: habit.name,
                colorHex: habit.colorHex,
                icon: habit.icon,
                currentStreak: currentStreak,
                bestStreak: bestStreak
            ))
        }

        habitStreakData = streaks
        bestOverallStreak = bestOverall > 0 ? "\(bestOverall)d" : "-"

        // Daily completion data for bar chart (within window)
        let cal = Calendar.current
        var dailyData: [DailyHabitCompletionData] = []
        var day = windowStart
        let windowStartStr = dateFormatter.string(from: windowStart)
        let windowEndStr = dateFormatter.string(from: windowEnd)

        // Filter completions to window
        let windowCompletions = completions.filter { $0.date >= windowStartStr && $0.date < windowEndStr }
        let completionsByDate = Dictionary(grouping: windowCompletions, by: { $0.date })

        var totalPossible = 0
        var totalCompleted = 0

        while day < windowEnd {
            let dayStr = dateFormatter.string(from: day)
            let completedCount = completionsByDate[dayStr]?.count ?? 0
            let habitCount = habits.count
            dailyData.append(DailyHabitCompletionData(
                date: day,
                count: completedCount,
                total: habitCount
            ))
            totalPossible += habitCount
            totalCompleted += completedCount
            day = cal.date(byAdding: .day, value: 1, to: day) ?? windowEnd
        }

        dailyHabitCompletionData = dailyData
        periodCompletions = totalCompleted
        let currentRate = totalPossible > 0 ? Double(totalCompleted) / Double(totalPossible) * 100 : 0
        completionRate = totalPossible > 0 ? String(format: "%.0f%%", currentRate) : "-"

        // Completion rate change vs previous period
        if !isAllTime, let days = currentDayCount {
            let cal = Calendar.current
            let prevStart = cal.date(byAdding: .day, value: -days, to: windowStart) ?? windowStart
            let prevEndStr = dateFormatter.string(from: windowStart)
            let prevStartStr = dateFormatter.string(from: prevStart)
            let prevCompletions = completions.filter { $0.date >= prevStartStr && $0.date < prevEndStr }

            var prevDay = prevStart
            var prevTotalPossible = 0
            while prevDay < windowStart {
                prevTotalPossible += habits.count
                prevDay = cal.date(byAdding: .day, value: 1, to: prevDay) ?? windowStart
            }
            let prevRate = prevTotalPossible > 0 ? Double(prevCompletions.count) / Double(prevTotalPossible) * 100 : 0

            if prevTotalPossible > 0 && totalPossible > 0 {
                let diff = currentRate - prevRate
                completionRateChange = String(format: "%@%.0f%%", diff >= 0 ? "+" : "", diff)
            } else {
                completionRateChange = "-"
            }
        } else {
            completionRateChange = "-"
        }
    }

    private func calculateCurrentStreak(dates: Set<String>, today: String, formatter: DateFormatter) -> Int {
        let cal = Calendar.current
        guard let todayDate = formatter.date(from: today) else { return 0 }

        // Start from today or yesterday (if today isn't done yet)
        var startDate = todayDate
        if !dates.contains(today) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: todayDate) else { return 0 }
            startDate = yesterday
        }

        var streak = 0
        var checkDate = startDate
        while true {
            let checkStr = formatter.string(from: checkDate)
            if dates.contains(checkStr) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    private func calculateBestStreak(dates: Set<String>, formatter: DateFormatter) -> Int {
        guard !dates.isEmpty else { return 0 }
        let cal = Calendar.current
        let sortedDates = dates.compactMap { formatter.date(from: $0) }.sorted()
        guard !sortedDates.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for i in 1..<sortedDates.count {
            let daysBetween = cal.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            if daysBetween == 1 {
                current += 1
                best = max(best, current)
            } else if daysBetween > 1 {
                current = 1
            }
            // daysBetween == 0 means duplicate date, skip
        }
        return best
    }

    // MARK: - Process Goal Streaks

    private func processGoalStreaks(goals: [Goal], allActivities: [Activity], allDrugLogs: [DrugLog], allBiometrics: [Biometric]) {
        let cal = Calendar.current
        let today = Date()

        var streaks: [GoalStreakData] = []

        let periodicGoals = goals.filter { $0.isActive && $0.period != nil }

        for goal in periodicGoals {
            guard let period = goal.period else { continue }

            var currentStreak = 0
            var bestStreak = 0
            var runningStreak = 0
            var foundFirstMiss = false

            // Walk backward through periods
            // Limit goals only go back to creation date; targets use a 365-period cap
            let maxPeriods = 365
            for offset in 0..<maxPeriods {
                let refDate = shiftDate(today, by: -offset, period: period, cal: cal)

                // For limit goals, stop once we've gone past the goal's creation date
                if goal.kind == .limit && refDate < cal.startOfDay(for: goal.createdAt) {
                    break
                }

                let progress = GoalProgressCalculator.calculateProgress(
                    goal: goal,
                    activities: allActivities,
                    drugLogs: allDrugLogs,
                    biometrics: allBiometrics,
                    referenceDate: refDate
                )

                if progress.isAchieved {
                    runningStreak += 1
                    if !foundFirstMiss {
                        currentStreak = runningStreak
                    }
                    bestStreak = max(bestStreak, runningStreak)
                } else {
                    if !foundFirstMiss { foundFirstMiss = true }
                    runningStreak = 0
                }
            }

            let periodLabel: String
            switch period {
            case .daily: periodLabel = "days"
            case .weekly: periodLabel = "weeks"
            case .monthly: periodLabel = "months"
            case .yearly: periodLabel = "years"
            }

            streaks.append(GoalStreakData(
                goalName: goal.categoryName,
                categoryType: goal.categoryType,
                periodLabel: periodLabel,
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                isTarget: goal.kind == .target
            ))
        }

        goalStreakData = streaks
    }

    private func shiftDate(_ date: Date, by offset: Int, period: GoalPeriod, cal: Calendar) -> Date {
        switch period {
        case .daily:
            return cal.date(byAdding: .day, value: offset, to: date) ?? date
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: offset, to: date) ?? date
        case .monthly:
            return cal.date(byAdding: .month, value: offset, to: date) ?? date
        case .yearly:
            return cal.date(byAdding: .year, value: offset, to: date) ?? date
        }
    }
}

// MARK: - Chart Data Models

struct ActivityTimeData: Identifiable {
    let id = UUID()
    let name: String
    let hours: Double
    let count: Int        // Number of sessions
    let colorHex: String  // Activity's color
}

struct TrendData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
    let categoryName: String
}

struct SubstanceCountData: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct SubstanceTrendData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct BiometricTrendData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct BedWakeDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let hour: Double   // fractional hour of day (bed times after midnight mapped to 24+)
    let type: String   // "Bed Time" or "Wake Time"
}

struct MoodScatterPoint: Identifiable {
    let id = UUID()
    let pleasantness: Double  // x: -1 to +1
    let energy: Double        // y: -1 to +1
}

struct MoodTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let pleasantness: Double
    let energy: Double
}

struct MoodQuadrantData: Identifiable {
    let id = UUID()
    let quadrant: String
    let count: Int
    let color: String  // hex color
}

struct HabitStreakData: Identifiable {
    let id = UUID()
    let habitName: String
    let colorHex: String
    let icon: String
    let currentStreak: Int
    let bestStreak: Int
}

struct DailyHabitCompletionData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let total: Int
}

struct GoalStreakData: Identifiable {
    let id = UUID()
    let goalName: String
    let categoryType: GoalCategoryType
    let periodLabel: String
    let currentStreak: Int
    let bestStreak: Int
    let isTarget: Bool
}

enum TimeRange: String, CaseIterable {
    case day = "1D"
    case week = "7D"
    case month = "30D"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"

    /// Number of days in this rolling window (nil for All Time).
    var dayCount: Int? {
        switch self {
        case .day:       return 1
        case .week:      return 7
        case .month:     return 30
        case .sixMonths: return 182
        case .year:      return 365
        case .all:       return nil
        }
    }
}
