//
//  AnalyticsViewModel.swift
//  HabitTracker
//
//  ViewModel for processing and presenting analytics data
//

import Foundation
import Combine

class AnalyticsViewModel: ObservableObject {
    @Published var isLoading = false
    
    // Activity Data
    @Published var activityTimeData: [ActivityTimeData] = []
    @Published var activityTrendData: [TrendData] = []
    @Published var totalActivities = 0
    @Published var totalActivityTime = "0h"
    @Published var mostTrackedActivity = "-"
    @Published var averageDuration = "-"
    
    // Substance Data
    @Published var substanceCountData: [SubstanceCountData] = []
    @Published var substanceTrendData: [SubstanceTrendData] = []
    @Published var totalSubstances = 0
    @Published var mostUsedSubstance = "-"
    @Published var averageSubstancePerDay = "-"
    @Published var topMethod = "-"
    
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
    
    func loadData(for timeRange: TimeRange, date: Date = Date()) {
        isLoading = true
        
        Task {
            do {
                async let activitiesTask   = FirebaseService.shared.fetchActivities()
                async let drugLogsTask     = FirebaseService.shared.fetchDrugLogs()
                async let biometricsTask   = FirebaseService.shared.fetchBiometrics()
                async let categoriesTask   = FirebaseService.shared.fetchActivityCategories()

                let (fetchedActivities, fetchedDrugLogs, fetchedBiometrics, fetchedCategories) =
                    try await (activitiesTask, drugLogsTask, biometricsTask, categoriesTask)

                await MainActor.run {
                    let (start, end) = self.windowBounds(for: timeRange, anchor: date)
                    self.categories  = fetchedCategories
                    self.activities  = fetchedActivities.filter  { $0.startTime >= start && $0.startTime < end }
                    self.drugLogs    = fetchedDrugLogs.filter    { $0.timestamp  >= start && $0.timestamp  < end }
                    self.biometrics  = fetchedBiometrics.filter  { $0.timestamp  >= start && $0.timestamp  < end }

                    self.processActivityData()
                    self.processSubstanceData()
                    self.processBiometricData()
                    self.processMoodData()
                    self.isLoading = false
                }
            } catch {
                print("Error loading analytics data: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    // MARK: - Window Bounds

    /// Returns the [start, end) interval for a given range anchored on `anchor`.
    /// For Day/Week/Month/Year the window is the calendar unit that contains the anchor.
    /// For All Time it spans the entire epoch → far future.
    private func windowBounds(for range: TimeRange, anchor: Date) -> (Date, Date) {
        let cal = Calendar.current
        switch range {
        case .day:
            let start = cal.startOfDay(for: anchor)
            let end   = cal.date(byAdding: .day,   value: 1, to: start)!
            return (start, end)
        case .week:
            // Locale-aware week start
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
            let start = cal.date(from: comps) ?? cal.startOfDay(for: anchor)
            let end   = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
        case .month:
            let comps = cal.dateComponents([.year, .month], from: anchor)
            let start = cal.date(from: comps) ?? cal.startOfDay(for: anchor)
            let end   = cal.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        case .year:
            let comps = cal.dateComponents([.year], from: anchor)
            let start = cal.date(from: comps) ?? cal.startOfDay(for: anchor)
            let end   = cal.date(byAdding: .year,  value: 1, to: start)!
            return (start, end)
        case .all:
            return (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 99999999999))
        }
    }
    
    // MARK: - Process Activity Data
    
    private func processActivityData() {
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
                colorHex: color
            )
        }
        .sorted { $0.hours > $1.hours }
        mostTrackedActivity = activityTimeData.first?.name ?? "-"
        
        let dailyGroups = Dictionary(grouping: activities) { Calendar.current.startOfDay(for: $0.startTime) }
        activityTrendData = dailyGroups.map { TrendData(date: $0.key, minutes: $0.value.reduce(0.0) { $0 + $1.duration } / 60) }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - Process Substance Data
    
    private func processSubstanceData() {
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
        totalBiometrics = biometrics.count
        
        // Weight
        let weightData = biometrics.filter { $0.type == .weight }.sorted { $0.timestamp > $1.timestamp }
        if let latest = weightData.first {
            latestWeight = String(format: "%.1f lbs", latest.value)
            if let oldest = weightData.last, weightData.count > 1 {
                let change = latest.value - oldest.value
                weightChange = String(format: "%@%.1f lbs", change >= 0 ? "+" : "", change)
            } else { weightChange = "-" }
        } else { latestWeight = "-"; weightChange = "-" }
        
        weightTrendData = weightData.map { BiometricTrendData(date: $0.timestamp, value: $0.value) }.sorted { $0.date < $1.date }
        
        // Sleep duration
        let sleepData = biometrics.filter { $0.type == .sleepDuration }.sorted { $0.timestamp < $1.timestamp }
        sleepTrendData = sleepData.map { BiometricTrendData(date: $0.timestamp, value: $0.value) }
        averageSleep = sleepData.isEmpty ? "-" : String(format: "%.1fh", sleepData.reduce(0.0) { $0 + $1.value } / Double(sleepData.count))
        
        // Bed & Wake times — convert to fractional hour-of-day for the chart.
        // Bed times after midnight (< 6 AM) are mapped to hour + 24 so the
        // chart keeps them visually adjacent to the preceding evening.
        let cal = Calendar.current
        var points: [BedWakeDataPoint] = []
        
        for b in biometrics where b.type == .bedTime {
            let h = cal.component(.hour, from: b.timestamp)
            let m = cal.component(.minute, from: b.timestamp)
            var hour = Double(h) + Double(m) / 60.0
            if h < 6 { hour += 24 }   // wrap early-morning bed times
            points.append(BedWakeDataPoint(date: cal.startOfDay(for: b.timestamp), hour: hour, type: "Bed Time"))
        }
        for w in biometrics where w.type == .wakeTime {
            let h = cal.component(.hour, from: w.timestamp)
            let m = cal.component(.minute, from: w.timestamp)
            points.append(BedWakeDataPoint(date: cal.startOfDay(for: w.timestamp), hour: Double(h) + Double(m) / 60.0, type: "Wake Time"))
        }
        bedWakeTimeData = points.sorted { $0.date < $1.date }
    }

    // MARK: - Process Mood Data

    private func processMoodData() {
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
            "High Energy\n+ Pleasant": "#34C759",
            "High Energy\n+ Unpleasant": "#FF3B30",
            "Low Energy\n+ Pleasant": "#007AFF",
            "Low Energy\n+ Unpleasant": "#8E8E93",
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
}

// MARK: - Chart Data Models

struct ActivityTimeData: Identifiable {
    let id = UUID()
    let name: String
    let hours: Double
    let colorHex: String  // Activity's color
}

struct TrendData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
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

enum TimeRange: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All Time"
}
