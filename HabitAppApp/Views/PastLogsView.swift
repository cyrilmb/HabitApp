//
//  PastLogsView.swift
//  HabitTracker
//
//  View for displaying, editing, and deleting past logs
//

import SwiftUI
import Combine

struct PastLogsView: View {
    @StateObject private var viewModel = PastLogsViewModel()
    @State private var selectedFilter: LogFilter = .all
    @State private var searchText = ""
    @State private var selectedActivityToEdit: Activity?
    @State private var selectedDrugLogToEdit: DrugLog?
    @State private var selectedBiometricToEdit: Biometric?
    @State private var showDeleteConfirmation = false
    @State private var logToDelete: LogItem?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(LogFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if viewModel.isLoading && viewModel.allLogs.isEmpty {
                    ProgressView("Loading logs...")
                        .frame(maxHeight: .infinity)
                } else if viewModel.filteredLogs.isEmpty {
                    emptyStateView
                } else {
                    logsList
                }
            }
        }
        .navigationTitle("Past Logs")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search logs...")
        .refreshable {
            await viewModel.refreshLogs()
        }
        .sheet(item: $selectedActivityToEdit, onDismiss: {
            viewModel.objectWillChange.send()
        }) { activity in
            EditActivityView(activity: activity) { updatedActivity in
                viewModel.updateActivity(updatedActivity)
            }
        }
        .sheet(item: $selectedDrugLogToEdit, onDismiss: {
            viewModel.objectWillChange.send()
        }) { drugLog in
            EditDrugLogView(drugLog: drugLog) { updatedLog in
                viewModel.updateDrugLog(updatedLog)
            }
        }
        .sheet(item: $selectedBiometricToEdit, onDismiss: {
            viewModel.objectWillChange.send()
        }) { biometric in
            EditBiometricView(biometric: biometric) { updatedBiometric in
                viewModel.updateBiometric(updatedBiometric)
            }
        }
        .confirmationDialog(
            "Delete this log?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let logItem = logToDelete {
                    deleteLog(logItem)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            viewModel.loadLogs()
        }
        .onChange(of: selectedFilter) { _, newValue in
            viewModel.selectedFilter = newValue
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.searchText = newValue
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedFilter.icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(selectedFilter == .all ? "No Logs Yet" : "No \(selectedFilter.rawValue)")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start tracking to see your logs here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Logs List
    
    private var logsList: some View {
        List {
            ForEach(viewModel.groupedLogs.keys.sorted(by: >), id: \.self) { date in
                Section(header: Text(formatSectionHeader(date))) {
                    ForEach(viewModel.groupedLogs[date] ?? [], id: \.id) { logItem in
                        LogRowView(logItem: logItem) {
                            editLog(logItem)
                        } onDelete: {
                            logToDelete = logItem
                            showDeleteConfirmation = true
                        }
                    }
                }
            }

            if viewModel.hasMoreLogs {
                Section {
                    Button {
                        viewModel.loadMoreLogs()
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Load More")
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Actions
    
    private func editLog(_ logItem: LogItem) {
        switch logItem.type {
        case .activity:
            selectedActivityToEdit = logItem.activity
        case .drugLog:
            selectedDrugLogToEdit = logItem.drugLog
        case .biometric:
            selectedBiometricToEdit = logItem.biometric
        }
    }
    
    private func deleteLog(_ logItem: LogItem) {
        switch logItem.type {
        case .activity:
            if let activity = logItem.activity {
                viewModel.deleteActivity(activity)
            }
        case .drugLog:
            if let drugLog = logItem.drugLog {
                viewModel.deleteDrugLog(drugLog)
            }
        case .biometric:
            if let biometric = logItem.biometric {
                viewModel.deleteBiometric(biometric)
            }
        }
    }
    
    // MARK: - Formatters
    
    private func formatSectionHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

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
    let type: LogType
    let date: Date
    let activity: Activity?
    let drugLog: DrugLog?
    let biometric: Biometric?
    
    enum LogType {
        case activity
        case drugLog
        case biometric
    }
    
    init(activity: Activity) {
        self.id = activity.id ?? UUID().uuidString
        self.type = .activity
        self.date = activity.startTime
        self.activity = activity
        self.drugLog = nil
        self.biometric = nil
    }
    
    init(drugLog: DrugLog) {
        self.id = drugLog.id ?? UUID().uuidString
        self.type = .drugLog
        self.date = drugLog.timestamp
        self.activity = nil
        self.drugLog = drugLog
        self.biometric = nil
    }
    
    init(biometric: Biometric) {
        self.id = biometric.id ?? UUID().uuidString
        self.type = .biometric
        self.date = biometric.timestamp
        self.activity = nil
        self.drugLog = nil
        self.biometric = biometric
    }
}

// MARK: - Log Row View

struct LogRowView: View {
    let logItem: LogItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icon
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(title)
                        .font(.headline)
                    
                    // Subtitle
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Time caption — hidden for bed/wake since the blue detail already shows it
                    if !isBedOrWake {
                        Text(formatTime(logItem.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Duration / Dosage / Time-of-day
                if let detail = detailText {
                    Text(detail)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }
    
    private var isBedOrWake: Bool {
        guard let b = logItem.biometric else { return false }
        return b.type == .bedTime || b.type == .wakeTime
    }
    
    private var title: String {
        switch logItem.type {
        case .activity:
            return logItem.activity?.categoryName ?? "Activity"
        case .drugLog:
            return logItem.drugLog?.categoryName ?? "Substance"
        case .biometric:
            return logItem.biometric?.type.rawValue ?? "Biometric"
        }
    }
    
    private var subtitle: String {
        switch logItem.type {
        case .activity:
            return "Activity"
        case .drugLog:
            if let method = logItem.drugLog?.method {
                return method
            }
            return "Substance"
        case .biometric:
            return "Biometric"
        }
    }
    
    private var iconName: String {
        switch logItem.type {
        case .activity:
            return "timer"
        case .drugLog:
            return "pill.fill"
        case .biometric:
            return logItem.biometric?.type.icon ?? "heart.text.square"
        }
    }
    
    private var iconColor: Color {
        switch logItem.type {
        case .activity:
            return .blue
        case .drugLog:
            return .purple
        case .biometric:
            return .red
        }
    }
    
    private var detailText: String? {
        switch logItem.type {
        case .activity:
            return logItem.activity?.formattedDuration
        case .drugLog:
            if let dosage = logItem.drugLog?.dosage,
               let unit = logItem.drugLog?.dosageUnit {
                return "\(String(format: "%.1f", dosage)) \(unit)"
            }
            return nil
        case .biometric:
            if let biometric = logItem.biometric {
                if biometric.type == .mood {
                    return nearestEmotionLabel(
                        pleasantness: biometric.value,
                        energy: biometric.secondaryValue ?? 0
                    )
                } else if biometric.type == .bedTime || biometric.type == .wakeTime {
                    // Use timestamp (the DatePicker value).  Fall back to
                    // createdAt when timestamp is exactly midnight — that
                    // pattern means an older save wrote startOfDay instead of
                    // the picker value.
                    let cal = Calendar.current
                    let comps = cal.dateComponents([.hour, .minute, .second], from: biometric.timestamp)
                    let isMidnight = (comps.hour == 0 && comps.minute == 0 && comps.second == 0)
                    let displayDate = isMidnight ? biometric.createdAt : biometric.timestamp

                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    return formatter.string(from: displayDate)
                } else {
                    return "\(String(format: "%.1f", biometric.value)) \(biometric.unit)"
                }
            }
            return nil
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

class PastLogsViewModel: ObservableObject {
    @Published var allLogs: [LogItem] = []
    @Published var filteredLogs: [LogItem] = []
    @Published var groupedLogs: [Date: [LogItem]] = [:]
    @Published var isLoading = false
    @Published var hasMoreLogs = true

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

        Task {
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
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func loadMoreLogs() {
        guard hasMoreLogs, !isLoading else { return }
        isLoading = true

        Task {
            do {
                // Fetch next page using cursor dates and limit+1 to detect more
                // We fetch items OLDER than the last seen date by using a "before" approach:
                // Since our queries order descending, we need items with dates before our cursors.
                // The `since` parameter uses >=, so we pass nil and handle with limit offset.
                // Instead, we fetch all from beginning with increased limit.
                let currentCount = allLogs.count
                let nextLimit = currentCount + pageSize

                async let activities = FirebaseService.shared.fetchActivities(limit: nextLimit)
                async let drugLogs = FirebaseService.shared.fetchDrugLogs(limit: nextLimit)
                async let biometrics = FirebaseService.shared.fetchBiometrics(limit: nextLimit)

                let (loadedActivities, loadedDrugLogs, loadedBiometrics) = try await (activities, drugLogs, biometrics)

                await MainActor.run {
                    let activityItems = loadedActivities.map { LogItem(activity: $0) }
                    let drugLogItems = loadedDrugLogs.map { LogItem(drugLog: $0) }
                    let biometricItems = loadedBiometrics.map { LogItem(biometric: $0) }

                    let newAll = (activityItems + drugLogItems + biometricItems).sorted { $0.date > $1.date }
                    self.hasMoreLogs = newAll.count > self.allLogs.count
                    self.allLogs = newAll
                    self.recomputeFilteredLogs()
                    self.isLoading = false
                }
            } catch {
                print("Error loading more logs: \(error)")
                await MainActor.run { self.isLoading = false }
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
            await MainActor.run { self.isLoading = false }
        }
    }

    private func recomputeFilteredLogs() {
        var logs = allLogs

        switch selectedFilter {
        case .all:
            break
        case .activities:
            logs = logs.filter { $0.type == .activity }
        case .substances:
            logs = logs.filter { $0.type == .drugLog }
        case .biometrics:
            logs = logs.filter { $0.type == .biometric }
        }

        if !searchText.isEmpty {
            logs = logs.filter { logItem in
                switch logItem.type {
                case .activity:
                    return logItem.activity?.categoryName.localizedCaseInsensitiveContains(searchText) ?? false
                case .drugLog:
                    if let drugLog = logItem.drugLog {
                        return drugLog.categoryName.localizedCaseInsensitiveContains(searchText) ||
                               drugLog.method.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                case .biometric:
                    return logItem.biometric?.type.rawValue.localizedCaseInsensitiveContains(searchText) ?? false
                }
            }
        }

        filteredLogs = logs
        groupedLogs = Dictionary(grouping: logs) { logItem in
            Calendar.current.startOfDay(for: logItem.date)
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
        Task {
            do {
                try await FirebaseService.shared.deleteActivity(activity)
                await MainActor.run {
                    allLogs.removeAll { $0.id == activity.id }
                    recomputeFilteredLogs()
                }
            } catch {
                print("Error deleting activity: \(error)")
            }
        }
    }

    func deleteDrugLog(_ drugLog: DrugLog) {
        Task {
            do {
                try await FirebaseService.shared.deleteDrugLog(drugLog)
                await MainActor.run {
                    allLogs.removeAll { $0.id == drugLog.id }
                    recomputeFilteredLogs()
                }
            } catch {
                print("Error deleting drug log: \(error)")
            }
        }
    }

    func deleteBiometric(_ biometric: Biometric) {
        Task {
            do {
                try await FirebaseService.shared.deleteBiometric(biometric)
                await MainActor.run {
                    allLogs.removeAll { $0.id == biometric.id }
                    recomputeFilteredLogs()
                }
            } catch {
                print("Error deleting biometric: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        PastLogsView()
    }
}
