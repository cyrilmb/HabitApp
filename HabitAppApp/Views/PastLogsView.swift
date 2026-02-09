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
        switch logItem.content {
        case .activity(let a):
            selectedActivityToEdit = a
        case .drugLog(let d):
            selectedDrugLogToEdit = d
        case .biometric(let b):
            selectedBiometricToEdit = b
        }
    }

    private func deleteLog(_ logItem: LogItem) {
        switch logItem.content {
        case .activity(let a):
            viewModel.deleteActivity(a)
        case .drugLog(let d):
            viewModel.deleteDrugLog(d)
        case .biometric(let b):
            viewModel.deleteBiometric(b)
        }
    }
    
    // MARK: - Formatters

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func formatSectionHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.sectionDateFormatter.string(from: date)
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
        if case .biometric(let b) = logItem.content {
            return b.type == .bedTime || b.type == .wakeTime
        }
        return false
    }
    
    private var title: String {
        switch logItem.content {
        case .activity(let a): return a.categoryName
        case .drugLog(let d): return d.categoryName
        case .biometric(let b): return b.type.rawValue
        }
    }

    private var subtitle: String {
        switch logItem.content {
        case .activity: return "Activity"
        case .drugLog(let d): return d.method
        case .biometric: return "Biometric"
        }
    }

    private var iconName: String {
        switch logItem.content {
        case .activity: return "timer"
        case .drugLog: return "pill.fill"
        case .biometric(let b): return b.type.icon
        }
    }

    private var iconColor: Color {
        switch logItem.content {
        case .activity: return .blue
        case .drugLog: return .purple
        case .biometric: return .red
        }
    }
    
    private var detailText: String? {
        switch logItem.content {
        case .activity(let a):
            return a.formattedDuration
        case .drugLog(let d):
            if let dosage = d.dosage, let unit = d.dosageUnit {
                return "\(String(format: "%.1f", dosage)) \(unit)"
            }
            return nil
        case .biometric(let b):
            if b.type == .mood {
                return nearestEmotionLabel(
                    pleasantness: b.value,
                    energy: b.secondaryValue ?? 0
                )
            } else if b.type == .bedTime || b.type == .wakeTime {
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute, .second], from: b.timestamp)
                let isMidnight = (comps.hour == 0 && comps.minute == 0 && comps.second == 0)
                let displayDate = isMidnight ? b.createdAt : b.timestamp
                return Self.timeFormatter.string(from: displayDate)
            } else {
                return "\(String(format: "%.1f", b.value)) \(b.unit)"
            }
        }
    }
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
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
                await MainActor.run { [weak self] in self?.isLoading = false }
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
                await MainActor.run { [weak self] in self?.isLoading = false }
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
            }
        }
    }
}

#Preview {
    NavigationStack {
        PastLogsView()
    }
}
