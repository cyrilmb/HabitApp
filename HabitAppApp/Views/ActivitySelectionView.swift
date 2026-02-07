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
                
                Text(category.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
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

// MARK: - Create Category View

struct CreateCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    @State private var selectedColor = "#007AFF"
    @State private var notificationEnabled = false
    @State private var notificationInterval: TimeInterval = 300 // 5 minutes default
    
    let onSave: (ActivityCategory) -> Void
    
    private let colorOptions = [
        // Reds
        "#FF3B30", "#DC143C", "#C0392B", "#8B0000",
        // Oranges
        "#FF9500", "#FF6347", "#E67E22", "#D35400",
        // Yellows
        "#FFD700", "#F39C12", "#F1C40F", "#D4AC0D",
        // Greens
        "#34C759", "#2ECC71", "#27AE60", "#1E8449",
        // Blues
        "#007AFF", "#3498DB", "#2980B9", "#1F618D",
        // Purples
        "#5856D6", "#9B59B6", "#8E44AD", "#6C3483",
        // Pinks
        "#FF2D55", "#E91E63", "#EC407A", "#AD1457",
        // Neutrals
        "#2C3E50", "#34495E", "#7F8C8D", "#95A5A6",
        "#BDC3C7", "#D5DBDB", "#ECF0F1", "#F8F9FA"
    ]
    
    private let notificationOptions: [(String, TimeInterval)] = [
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Activity Name", text: $categoryName)
                        .autocapitalization(.words)
                } header: {
                    Text("Name")
                }
                
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(colorOptions, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .blue)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: selectedColor == colorHex ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }
                
                Section {
                    Toggle("Enable Notifications", isOn: $notificationEnabled)
                    
                    if notificationEnabled {
                        Picker("Interval", selection: $notificationInterval) {
                            ForEach(notificationOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }
                    }
                } header: {
                    Text("Timer Notifications")
                } footer: {
                    Text("Get reminded while your timer is running")
                }
            }
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
        }
    }
    
    private func saveCategory() {
        let userId = FirebaseService.shared.userId
        let category = ActivityCategory(
            userId: userId,
            name: categoryName,
            colorHex: selectedColor,
            notificationInterval: notificationEnabled ? notificationInterval : nil
        )
        onSave(category)
        dismiss()
    }
}

// MARK: - ViewModel

class ActivitySelectionViewModel: ObservableObject {
    @Published var categories: [ActivityCategory] = []
    @Published var isLoading = false
    
    func loadCategories() {
        isLoading = true
        
        Task {
            do {
                let loadedCategories = try await FirebaseService.shared.fetchActivityCategories()
                await MainActor.run {
                    self.categories = loadedCategories
                    self.isLoading = false
                }
            } catch {
                print("Error loading categories: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func addCategory(_ category: ActivityCategory) {
        categories.append(category)
        
        // Save to Firebase
        Task {
            do {
                try await FirebaseService.shared.saveActivityCategory(category)
            } catch {
                print("Error saving category: \(error)")
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

// MARK: - Edit Categories View

struct EditCategoriesView: View {
    let categories: [ActivityCategory]
    let onUpdate: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: ActivityCategory?
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button(action: {
                        selectedCategory = category
                        showEditSheet = true
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: category.colorHex ?? "#007AFF") ?? .blue)
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let interval = category.notificationInterval {
                                    Text("Notifications every \(formatInterval(interval))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No notifications")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Edit Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let category = selectedCategory {
                    EditCategoryView(category: category) {
                        onUpdate()
                        showEditSheet = false
                    }
                }
            }
        }
    }
    
    private func formatInterval(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Edit Single Category View

struct EditCategoryView: View {
    let category: ActivityCategory
    let onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var categoryName: String
    @State private var selectedColor: String
    @State private var notificationEnabled: Bool
    @State private var notificationInterval: TimeInterval
    @State private var showDeleteAlert = false
    @State private var deleteAllLogs = false
    @State private var isDeleting = false
    @State private var isSaving = false
    
    init(category: ActivityCategory, onSave: @escaping () -> Void) {
        self.category = category
        self.onSave = onSave
        self._categoryName = State(initialValue: category.name)
        self._selectedColor = State(initialValue: category.colorHex ?? "#007AFF")
        self._notificationEnabled = State(initialValue: category.notificationInterval != nil)
        self._notificationInterval = State(initialValue: category.notificationInterval ?? 300)
    }
    
    private let colorOptions = [
        // Reds
        "#FF3B30", "#DC143C", "#C0392B", "#8B0000",
        // Oranges
        "#FF9500", "#FF6347", "#E67E22", "#D35400",
        // Yellows
        "#FFD700", "#F39C12", "#F1C40F", "#D4AC0D",
        // Greens
        "#34C759", "#2ECC71", "#27AE60", "#1E8449",
        // Blues
        "#007AFF", "#3498DB", "#2980B9", "#1F618D",
        // Purples
        "#5856D6", "#9B59B6", "#8E44AD", "#6C3483",
        // Pinks
        "#FF2D55", "#E91E63", "#EC407A", "#AD1457",
        // Neutrals
        "#2C3E50", "#34495E", "#7F8C8D", "#95A5A6",
        "#BDC3C7", "#D5DBDB", "#ECF0F1", "#F8F9FA"
    ]
    
    private let notificationOptions: [(String, TimeInterval)] = [
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Activity Name", text: $categoryName)
                        .autocapitalization(.words)
                } header: {
                    Text("Name")
                }
                
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(colorOptions, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .blue)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: selectedColor == colorHex ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }
                
                Section {
                    Toggle("Enable Notifications", isOn: $notificationEnabled)
                    
                    if notificationEnabled {
                        Picker("Interval", selection: $notificationInterval) {
                            ForEach(notificationOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }
                    }
                } header: {
                    Text("Timer Notifications")
                } footer: {
                    Text("Get reminded while your timer is running")
                }
                
                Section {
                    Toggle("Delete all past logs", isOn: $deleteAllLogs)
                        .foregroundColor(.red)
                    
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                            } else {
                                Text("Delete Activity")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("Danger Zone")
                } footer: {
                    if deleteAllLogs {
                        Text("⚠️ This will permanently delete this activity category and all \(category.name) logs")
                    } else {
                        Text("This will delete the activity category but keep past logs")
                    }
                }
            }
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(categoryName.isEmpty || isSaving)
                }
            }
            .alert("Delete Activity?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteCategory()
                }
            } message: {
                if deleteAllLogs {
                    Text("This will permanently delete \(category.name) and all past logs. This cannot be undone.")
                } else {
                    Text("This will delete \(category.name) but keep past logs.")
                }
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        
        var updatedCategory = category
        updatedCategory.name = categoryName
        updatedCategory.colorHex = selectedColor
        updatedCategory.notificationInterval = notificationEnabled ? notificationInterval : nil
        
        Task {
            do {
                try await FirebaseService.shared.saveActivityCategory(updatedCategory)
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            } catch {
                print("Error saving category: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    private func deleteCategory() {
        isDeleting = true
        
        Task {
            do {
                // Delete category
                if let categoryId = category.id {
                    try await FirebaseService.shared.deleteActivityCategory(categoryId)
                }
                
                // Delete all logs if requested
                if deleteAllLogs {
                    try await FirebaseService.shared.deleteActivitiesByCategory(category.name)
                }
                
                await MainActor.run {
                    isDeleting = false
                    onSave()
                    dismiss()
                }
            } catch {
                print("Error deleting category: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
}
