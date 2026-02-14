//
//  ActivitySelectionView.swift
//  HabitTracker
//
//  Sheet for selecting or creating activity categories
//

import SwiftUI
import Combine

struct ActivitySelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ActivitySelectionViewModel()
    @ObservedObject private var timerService = TimerService.shared
    @State private var showCreateNew = false
    @State private var showEditCategories = false
    @State private var navigateToTimer = false
    @State private var selectedActivity: Activity?
    @State private var showTimerConflictAlert = false
    @State private var pendingCategoryName: String?
    @State private var selectedNotificationInterval: TimeInterval?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        ProgressView("Loading categories...")
                    } else if viewModel.categories.isEmpty {
                        emptyStateView
                    } else {
                        categoryListView
                    }
                }
                .padding()
            }
            .navigationTitle("Select Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showEditCategories = true
                    }
                    .disabled(viewModel.categories.isEmpty)
                }
            }
            .sheet(isPresented: $showCreateNew) {
                CreateCategoryView { newCategory in
                    viewModel.addCategory(newCategory)
                    // Automatically select the new category
                    startActivityTimer(categoryName: newCategory.name)
                }
            }
            .sheet(isPresented: $showEditCategories) {
                EditCategoriesView(categories: viewModel.categories) {
                    viewModel.loadCategories()
                }
            }
            .navigationDestination(isPresented: $navigateToTimer) {
                if let activity = selectedActivity {
                    ActivityTimerView(activity: activity, notificationInterval: selectedNotificationInterval)
                }
            }
            .onAppear {
                viewModel.loadCategories()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Timer Already Running", isPresented: $showTimerConflictAlert) {
                Button("Cancel", role: .cancel) {
                    pendingCategoryName = nil
                }
                Button("End & Start New") {
                    if let categoryName = pendingCategoryName {
                        endCurrentAndStartNew(categoryName: categoryName)
                    }
                }
            } message: {
                if let current = timerService.currentActivity?.categoryName,
                   let pending = pendingCategoryName {
                    Text("End \(current) timer and start timing \(pending)?")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "timer.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.5))

            Text("No Activities Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first activity category to start tracking")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showCreateNew = true }) {
                Label("Create Activity", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.gradient)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Category List

    private var categoryListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Create New Button
                Button(action: { showCreateNew = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)

                        Text("Create New Activity")
                            .font(.headline)

                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.vertical, 8)

                // Existing Categories
                ForEach(viewModel.categories) { category in
                    CategoryRow(category: category) {
                        startActivityTimer(categoryName: category.name)
                    }
                }
            }
        }
    }

    // MARK: - Helper

    private func startActivityTimer(categoryName: String) {
        // Check if timer is already running
        if timerService.isRunning {
            pendingCategoryName = categoryName
            showTimerConflictAlert = true
            return
        }

        let userId = FirebaseService.shared.userId
        let activity = Activity(userId: userId, categoryName: categoryName)
        selectedActivity = activity
        selectedNotificationInterval = viewModel.categories.first(where: { $0.name == categoryName })?.notificationInterval
        navigateToTimer = true
    }

    private func endCurrentAndStartNew(categoryName: String) {
        // End current timer and auto-save it
        if let completedActivity = timerService.endTimer() {
            Task {
                do {
                    try await FirebaseService.shared.saveActivity(completedActivity)
                    print("Auto-saved previous activity: \(completedActivity.categoryName)")
                } catch {
                    print("Error auto-saving: \(error)")
                    await MainActor.run {
                        viewModel.errorMessage = "Warning: previous activity could not be saved."
                    }
                }
            }
        }

        // Start new timer
        let userId = FirebaseService.shared.userId
        let activity = Activity(userId: userId, categoryName: categoryName)
        selectedActivity = activity
        selectedNotificationInterval = viewModel.categories.first(where: { $0.name == categoryName })?.notificationInterval
        navigateToTimer = true
        pendingCategoryName = nil
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: ActivityCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                // Color indicator
                Circle()
                    .fill(Color(hex: category.colorHex ?? "#007AFF") ?? .blue)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    if let interval = category.notificationInterval {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                            Text("Every \(formatInterval(interval))")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ViewModel

class ActivitySelectionViewModel: ObservableObject {
    @Published var categories: [ActivityCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadCategories() {
        isLoading = true

        Task { [weak self] in
            do {
                let loadedCategories = try await FirebaseService.shared.fetchActivityCategories()
                await MainActor.run { [weak self] in
                    self?.categories = loadedCategories
                    self?.isLoading = false
                }
            } catch {
                print("Error loading categories: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to load activities."
                    self?.isLoading = false
                }
            }
        }
    }

    func addCategory(_ category: ActivityCategory) {
        categories.append(category)

        Task {
            do {
                try await FirebaseService.shared.saveActivityCategory(category)
            } catch {
                print("Error saving category: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to save activity."
                }
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ActivitySelectionView()
}
