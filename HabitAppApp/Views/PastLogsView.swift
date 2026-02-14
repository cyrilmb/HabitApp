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
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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

#Preview {
    NavigationStack {
        PastLogsView()
    }
}
