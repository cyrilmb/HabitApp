//
//  PastLogsViewModel.swift
//  HabitTracker
//
//  ViewModel and supporting types for PastLogsView
//

import SwiftUI
import Combine

// MARK: - Log Filter Enum

enum LogFilter: String, CaseIterable {
    case all = "All"
    case activities = "Activities"
    case substances = "Substances"
    case biometrics = "Biometrics"

    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .activities:
            return "timer"
        case .substances:
            return "pill"
        case .biometrics:
            return "heart.text.square"
        }
    }
}

// MARK: - Log Item (Unified Model)

struct LogItem: Identifiable {
    let id: String
    let date: Date
    let content: Content

    enum Content {
        case activity(Activity)
        case drugLog(DrugLog)
        case biometric(Biometric)
    }

    // Convenience accessors for backwards compatibility
    var activity: Activity? {
        if case .activity(let a) = content { return a }
        return nil
    }
    var drugLog: DrugLog? {
        if case .drugLog(let d) = content { return d }
        return nil
    }
    var biometric: Biometric? {
        if case .biometric(let b) = content { return b }
        return nil
    }

    init(activity: Activity) {
        self.id = activity.id ?? UUID().uuidString
        self.date = activity.startTime
        self.content = .activity(activity)
    }

    init(drugLog: DrugLog) {
        self.id = drugLog.id ?? UUID().uuidString
        self.date = drugLog.timestamp
        self.content = .drugLog(drugLog)
    }

    init(biometric: Biometric) {
        self.id = biometric.id ?? UUID().uuidString
        self.date = biometric.timestamp
        self.content = .biometric(biometric)
    }

    /// The date used for section grouping. Bed times between midnight and 6 AM
    /// are shifted to the previous day so they appear with that evening's logs.
    var groupDate: Date {
        if case .biometric(let b) = content, b.type == .bedTime {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            if hour >= 0 && hour < 6 {
                return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
            }
        }
        return date
    }
}

// MARK: - ViewModel

class PastLogsViewModel: ObservableObject {
    @Published var allLogs: [LogItem] = []
    @Published var filteredLogs: [LogItem] = []
    @Published var groupedLogs: [Date: [LogItem]] = [:]
    @Published var isLoading = false
    @Published var hasMoreLogs = true
    @Published var errorMessage: String?

    private let pageSize = 50
    private var lastActivityDate: Date?
    private var lastDrugLogDate: Date?
    private var lastBiometricDate: Date?

    var selectedFilter: LogFilter = .all {
        didSet { recomputeFilteredLogs() }
    }

    var searchText: String = "" {
        didSet { recomputeFilteredLogs() }
    }

    func loadLogs() {
        isLoading = true
        lastActivityDate = nil
        lastDrugLogDate = nil
        lastBiometricDate = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                async let activities = FirebaseService.shared.fetchActivities(limit: self.pageSize)
                async let drugLogs = FirebaseService.shared.fetchDrugLogs(limit: self.pageSize)
                async let biometrics = FirebaseService.shared.fetchBiometrics(limit: self.pageSize)

                let (loadedActivities, loadedDrugLogs, loadedBiometrics) = try await (activities, drugLogs, biometrics)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let activityItems = loadedActivities.map { LogItem(activity: $0) }
                    let drugLogItems = loadedDrugLogs.map { LogItem(drugLog: $0) }
                    let biometricItems = loadedBiometrics.map { LogItem(biometric: $0) }

                    self.allLogs = (activityItems + drugLogItems + biometricItems).sorted { $0.date > $1.date }
                    self.lastActivityDate = loadedActivities.last?.startTime
                    self.lastDrugLogDate = loadedDrugLogs.last?.timestamp
                    self.lastBiometricDate = loadedBiometrics.last?.timestamp
                    self.hasMoreLogs = loadedActivities.count == self.pageSize
                        || loadedDrugLogs.count == self.pageSize
                        || loadedBiometrics.count == self.pageSize
                    self.recomputeFilteredLogs()
                    self.isLoading = false
                }
            } catch {
                print("Error loading logs: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to load logs. Please try again."
                    self?.isLoading = false
                }
            }
        }
    }

    func loadMoreLogs() {
        guard hasMoreLogs, !isLoading else { return }
        isLoading = true

        Task { [weak self] in
            guard let self else { return }
            do {
                var newActivities: [Activity] = []
                var newDrugLogs: [DrugLog] = []
                var newBiometrics: [Biometric] = []

                if let cursor = lastActivityDate {
                    newActivities = try await FirebaseService.shared.fetchActivities(before: cursor, limit: pageSize)
                }
                if let cursor = lastDrugLogDate {
                    newDrugLogs = try await FirebaseService.shared.fetchDrugLogs(before: cursor, limit: pageSize)
                }
                if let cursor = lastBiometricDate {
                    newBiometrics = try await FirebaseService.shared.fetchBiometrics(before: cursor, limit: pageSize)
                }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let activityItems = newActivities.map { LogItem(activity: $0) }
                    let drugLogItems = newDrugLogs.map { LogItem(drugLog: $0) }
                    let biometricItems = newBiometrics.map { LogItem(biometric: $0) }

                    self.allLogs.append(contentsOf: activityItems + drugLogItems + biometricItems)
                    self.allLogs.sort { $0.date > $1.date }

                    if let last = newActivities.last { self.lastActivityDate = last.startTime }
                    if let last = newDrugLogs.last { self.lastDrugLogDate = last.timestamp }
                    if let last = newBiometrics.last { self.lastBiometricDate = last.timestamp }

                    self.hasMoreLogs = newActivities.count == self.pageSize
                        || newDrugLogs.count == self.pageSize
                        || newBiometrics.count == self.pageSize
                    self.recomputeFilteredLogs()
                    self.isLoading = false
                }
            } catch {
                print("Error loading more logs: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to load more logs."
                    self?.isLoading = false
                }
            }
        }
    }

    func refreshLogs() async {
        await MainActor.run { isLoading = true }

        do {
            async let activities = FirebaseService.shared.fetchActivities(limit: pageSize)
            async let drugLogs = FirebaseService.shared.fetchDrugLogs(limit: pageSize)
            async let biometrics = FirebaseService.shared.fetchBiometrics(limit: pageSize)

            let (loadedActivities, loadedDrugLogs, loadedBiometrics) = try await (activities, drugLogs, biometrics)

            await MainActor.run {
                let activityItems = loadedActivities.map { LogItem(activity: $0) }
                let drugLogItems = loadedDrugLogs.map { LogItem(drugLog: $0) }
                let biometricItems = loadedBiometrics.map { LogItem(biometric: $0) }

                self.allLogs = (activityItems + drugLogItems + biometricItems).sorted { $0.date > $1.date }
                self.hasMoreLogs = loadedActivities.count == self.pageSize
                    || loadedDrugLogs.count == self.pageSize
                    || loadedBiometrics.count == self.pageSize
                self.recomputeFilteredLogs()
                self.isLoading = false
            }
        } catch {
            print("Error refreshing logs: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to refresh logs."
                self.isLoading = false
            }
        }
    }

    private func recomputeFilteredLogs() {
        var logs = allLogs

        switch selectedFilter {
        case .all:
            break
        case .activities:
            logs = logs.filter { if case .activity = $0.content { return true }; return false }
        case .substances:
            logs = logs.filter { if case .drugLog = $0.content { return true }; return false }
        case .biometrics:
            logs = logs.filter { if case .biometric = $0.content { return true }; return false }
        }

        if !searchText.isEmpty {
            logs = logs.filter { logItem in
                switch logItem.content {
                case .activity(let a):
                    return a.categoryName.localizedCaseInsensitiveContains(searchText)
                case .drugLog(let d):
                    return d.categoryName.localizedCaseInsensitiveContains(searchText) ||
                           d.method.localizedCaseInsensitiveContains(searchText)
                case .biometric(let b):
                    return b.type.rawValue.localizedCaseInsensitiveContains(searchText)
                }
            }
        }

        filteredLogs = logs
        groupedLogs = Dictionary(grouping: logs) { logItem in
            Calendar.current.startOfDay(for: logItem.groupDate)
        }
    }

    func updateActivity(_ activity: Activity) {
        if let index = allLogs.firstIndex(where: { $0.id == activity.id }) {
            allLogs[index] = LogItem(activity: activity)
            recomputeFilteredLogs()
        }
    }

    func updateDrugLog(_ drugLog: DrugLog) {
        if let index = allLogs.firstIndex(where: { $0.id == drugLog.id }) {
            allLogs[index] = LogItem(drugLog: drugLog)
            recomputeFilteredLogs()
        }
    }

    func updateBiometric(_ biometric: Biometric) {
        if let index = allLogs.firstIndex(where: { $0.id == biometric.id }) {
            allLogs[index] = LogItem(biometric: biometric)
            recomputeFilteredLogs()
        }
    }

    func deleteActivity(_ activity: Activity) {
        Task { [weak self] in
            do {
                try await FirebaseService.shared.deleteActivity(activity)
                await MainActor.run { [weak self] in
                    self?.allLogs.removeAll { $0.id == activity.id }
                    self?.recomputeFilteredLogs()
                }
            } catch {
                print("Error deleting activity: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to delete activity."
                }
            }
        }
    }

    func deleteDrugLog(_ drugLog: DrugLog) {
        Task { [weak self] in
            do {
                try await FirebaseService.shared.deleteDrugLog(drugLog)
                await MainActor.run { [weak self] in
                    self?.allLogs.removeAll { $0.id == drugLog.id }
                    self?.recomputeFilteredLogs()
                }
            } catch {
                print("Error deleting drug log: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to delete substance log."
                }
            }
        }
    }

    func deleteBiometric(_ biometric: Biometric) {
        Task { [weak self] in
            do {
                try await FirebaseService.shared.deleteBiometric(biometric)
                await MainActor.run { [weak self] in
                    self?.allLogs.removeAll { $0.id == biometric.id }
                    self?.recomputeFilteredLogs()
                }
            } catch {
                print("Error deleting biometric: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to delete biometric."
                }
            }
        }
    }
}
