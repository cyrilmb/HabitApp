//
//  DrugLogView.swift
//  HabitTracker
//
//  Quick button-based substance logging view
//

import SwiftUI
import Combine

struct DrugLogView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = DrugLogViewModel()

    @State private var showCreateCategory = false
    @State private var selectedCategory: DrugCategory?
    @State private var showMethodSelection = false

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
            .navigationTitle("Log Substance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCreateCategory) {
                CreateDrugCategoryView { newCategory in
                    viewModel.addCategory(newCategory)
                }
            }
            .navigationDestination(isPresented: $showMethodSelection) {
                if let category = selectedCategory {
                    DrugMethodSelectionView(category: category)
                }
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
                viewModel.loadCategories()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pill.circle")
                .font(.system(size: 80))
                .foregroundColor(.purple.opacity(0.5))

            Text("No Substances Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first substance category to start tracking")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showCreateCategory = true }) {
                Label("Create Substance", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple.gradient)
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
                Button(action: { showCreateCategory = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)

                        Text("Create New Substance")
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
                    SubstanceCategoryButton(category: category) {
                        selectedCategory = category
                        showMethodSelection = true
                    }
                }
            }
        }
    }
}

// MARK: - Substance Category Button

struct SubstanceCategoryButton: View {
    let category: DrugCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: iconForSubstanceCategory(category.name))
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(colorForSubstanceCategory(category.name).gradient)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(category.methods.count) methods")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ViewModel

class DrugLogViewModel: ObservableObject {
    @Published var categories: [DrugCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadCategories() {
        isLoading = true

        Task { [weak self] in
            do {
                let loadedCategories = try await FirebaseService.shared.fetchDrugCategories()
                await MainActor.run { [weak self] in
                    self?.categories = loadedCategories
                    self?.isLoading = false
                }
            } catch {
                print("Error loading drug categories: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to load substances."
                    self?.isLoading = false
                }
            }
        }
    }

    func addCategory(_ category: DrugCategory) {
        categories.append(category)

        Task {
            do {
                try await FirebaseService.shared.saveDrugCategory(category)
            } catch {
                print("Error saving drug category: \(error)")
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to save substance."
                }
            }
        }
    }
}

#Preview {
    DrugLogView()
}
