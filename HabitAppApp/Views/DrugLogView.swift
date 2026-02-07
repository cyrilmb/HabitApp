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
                Image(systemName: iconForCategory(category.name))
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(colorForCategory(category.name).gradient)
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
    
    private func iconForCategory(_ name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("alcohol") {
            return "wineglass"
        } else if lowercased.contains("cannabis") || lowercased.contains("marijuana") {
            return "leaf"
        } else if lowercased.contains("caffeine") || lowercased.contains("coffee") {
            return "cup.and.saucer"
        } else if lowercased.contains("tobacco") || lowercased.contains("nicotine") {
            return "smoke"
        } else {
            return "pill"
        }
    }
    
    private func colorForCategory(_ name: String) -> Color {
        let lowercased = name.lowercased()
        if lowercased.contains("alcohol") {
            return .red
        } else if lowercased.contains("cannabis") {
            return .green
        } else if lowercased.contains("caffeine") {
            return .brown
        } else if lowercased.contains("tobacco") {
            return .gray
        } else {
            return .purple
        }
    }
}

// MARK: - Method Selection View

struct DrugMethodSelectionView: View {
    @State private var category: DrugCategory

    @Environment(\.dismiss) var dismiss
    @State private var showAddMethod = false
    @State private var showEditMethods = false
    @State private var showDosageEntry = false
    @State private var selectedMethod: String?

    init(category: DrugCategory) {
        self._category = State(initialValue: category)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: iconForCategory(category.name))
                            .font(.system(size: 50))
                            .foregroundColor(colorForCategory(category.name))

                        Text(category.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Select method")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // Method Buttons
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(category.methods, id: \.self) { method in
                            MethodButton(method: method) {
                                selectedMethod = method
                                showDosageEntry = true
                            }
                        }

                        // Add Method Button
                        Button(action: { showAddMethod = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                Text("Add Method")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.green, style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                        }
                        .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Select Method")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showEditMethods = true
                }
            }
        }
        .sheet(isPresented: $showAddMethod, onDismiss: reloadCategory) {
            AddMethodView(category: category)
        }
        .sheet(isPresented: $showEditMethods, onDismiss: reloadCategory) {
            EditMethodsView(category: category)
        }
        .navigationDestination(isPresented: $showDosageEntry) {
            if let method = selectedMethod {
                DosageEntryView(category: category, method: method)
            }
        }
    }

    private func reloadCategory() {
        Task {
            do {
                let categories = try await FirebaseService.shared.fetchDrugCategories()
                if let updated = categories.first(where: { $0.id == category.id }) {
                    await MainActor.run {
                        category = updated
                    }
                }
            } catch {
                print("Error reloading category: \(error)")
            }
        }
    }
    
    private func iconForCategory(_ name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("alcohol") { return "wineglass" }
        else if lowercased.contains("cannabis") { return "leaf" }
        else if lowercased.contains("caffeine") { return "cup.and.saucer" }
        else if lowercased.contains("tobacco") { return "smoke" }
        else { return "pill" }
    }
    
    private func colorForCategory(_ name: String) -> Color {
        let lowercased = name.lowercased()
        if lowercased.contains("alcohol") { return .red }
        else if lowercased.contains("cannabis") { return .green }
        else if lowercased.contains("caffeine") { return .brown }
        else if lowercased.contains("tobacco") { return .gray }
        else { return .purple }
    }
}

struct MethodButton: View {
    let method: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconForMethod(method))
                    .font(.title)
                
                Text(method)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private func iconForMethod(_ method: String) -> String {
        let lowercased = method.lowercased()
        if lowercased.contains("beer") { return "mug" }
        else if lowercased.contains("wine") { return "wineglass" }
        else if lowercased.contains("shot") { return "wineglass.fill" }
        else if lowercased.contains("cocktail") { return "cup.and.saucer.fill" }
        else if lowercased.contains("joint") { return "flame" }
        else if lowercased.contains("vape") { return "cloud" }
        else if lowercased.contains("edible") { return "fork.knife" }
        else if lowercased.contains("pipe") { return "circle.circle" }
        else if lowercased.contains("coffee") { return "cup.and.saucer" }
        else if lowercased.contains("tea") { return "cup.and.saucer" }
        else { return "circle.fill" }
    }
}

// MARK: - Add Method View

struct AddMethodView: View {
    let category: DrugCategory
    
    @Environment(\.dismiss) var dismiss
    @State private var methodName = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Method name", text: $methodName)
                        .autocapitalization(.words)
                } header: {
                    Text("New Method for \(category.name)")
                } footer: {
                    Text("e.g., Bowl, Bong, Tincture, etc.")
                }
            }
            .navigationTitle("Add Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMethod()
                    }
                    .disabled(methodName.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func addMethod() {
        isSaving = true
        
        var updatedCategory = category
        updatedCategory.methods.append(methodName)
        
        Task {
            do {
                try await FirebaseService.shared.saveDrugCategory(updatedCategory)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error adding method: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Dosage Entry View

struct DosageEntryView: View {
    let category: DrugCategory
    let method: String
    
    @Environment(\.dismiss) var dismiss
    @State private var dosage: String = ""
    @State private var timestamp: Date = Date()
    @State private var notes: String = ""
    @State private var isSaving = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Substance")
                    Spacer()
                    Text(category.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Method")
                    Spacer()
                    Text(method)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                HStack {
                    TextField("Amount (optional)", text: $dosage)
                        .keyboardType(.decimalPad)
                    
                    if let unit = category.defaultDosageUnit {
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Dosage")
            } footer: {
                if let unit = category.defaultDosageUnit {
                    Text("Enter amount in \(unit)")
                }
            }
            
            Section {
                DatePicker("When", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
            }
            
            Section {
                TextEditor(text: $notes)
                    .frame(height: 80)
            } header: {
                Text("Notes (Optional)")
            }
        }
        .navigationTitle("Log Details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(action: saveDrugLog) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.purple.gradient)
                .cornerRadius(12)
            }
            .disabled(isSaving)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func saveDrugLog() {
        isSaving = true
        
        let userId = FirebaseService.shared.userId
        let dosageValue = Double(dosage)
        
        var log = DrugLog(
            userId: userId,
            categoryName: category.name,
            method: method,
            dosage: dosageValue,
            dosageUnit: category.defaultDosageUnit,
            timestamp: timestamp
        )
        
        log.notes = notes.isEmpty ? nil : notes
        
        Task {
            do {
                try await FirebaseService.shared.saveDrugLog(log)
                await MainActor.run {
                    isSaving = false
                    SheetManager.shared.dismissAndToast(.substance)
                }
            } catch {
                print("Error saving drug log: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Create Category View (same as before but cleaner)

struct CreateDrugCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    @State private var methods: [String] = [""]
    @State private var dosageUnit = ""
    
    let onSave: (DrugCategory) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $categoryName)
                        .autocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    Text("e.g., Alcohol, Cannabis, Caffeine")
                }
                
                Section {
                    ForEach(methods.indices, id: \.self) { index in
                        HStack {
                            TextField("Method \(index + 1)", text: $methods[index])
                                .autocapitalization(.words)
                            
                            if methods.count > 1 {
                                Button(action: { methods.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Button(action: { methods.append("") }) {
                        Label("Add Method", systemImage: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Methods of Use")
                } footer: {
                    Text("e.g., Beer, Wine, Shot (for Alcohol)")
                }
                
                Section {
                    TextField("Unit (optional)", text: $dosageUnit)
                } header: {
                    Text("Dosage Unit")
                } footer: {
                    Text("e.g., drinks, mg, oz")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Templates")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                TemplateButton(name: "Alcohol") {
                                    categoryName = "Alcohol"
                                    methods = ["Beer", "Wine", "Shot", "Cocktail"]
                                    dosageUnit = "drinks"
                                }
                                
                                TemplateButton(name: "Cannabis") {
                                    categoryName = "Cannabis"
                                    methods = ["Joint", "Vape", "Edible", "Pipe"]
                                    dosageUnit = "mg"
                                }
                                
                                TemplateButton(name: "Caffeine") {
                                    categoryName = "Caffeine"
                                    methods = ["Coffee", "Tea", "Energy Drink"]
                                    dosageUnit = "mg"
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Substance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        !categoryName.isEmpty && methods.contains(where: { !$0.isEmpty })
    }
    
    private func saveCategory() {
        let userId = FirebaseService.shared.userId
        let validMethods = methods.filter { !$0.isEmpty }
        
        let category = DrugCategory(
            userId: userId,
            name: categoryName,
            methods: validMethods,
            defaultDosageUnit: dosageUnit.isEmpty ? nil : dosageUnit
        )
        
        onSave(category)
        dismiss()
    }
}

struct TemplateButton: View {
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(8)
        }
    }
}

// MARK: - ViewModel

class DrugLogViewModel: ObservableObject {
    @Published var categories: [DrugCategory] = []
    @Published var isLoading = false
    
    func loadCategories() {
        isLoading = true
        
        Task {
            do {
                let loadedCategories = try await FirebaseService.shared.fetchDrugCategories()
                await MainActor.run {
                    self.categories = loadedCategories
                    self.isLoading = false
                    
                    if self.categories.isEmpty {
                        self.createDefaultCategories()
                    }
                }
            } catch {
                print("Error loading drug categories: \(error)")
                await MainActor.run {
                    self.isLoading = false
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
            }
        }
    }
    
    private func createDefaultCategories() {
        let userId = FirebaseService.shared.userId
        let defaults = [
            DrugCategory.alcoholCategory(userId: userId),
            DrugCategory.cannabisCategory(userId: userId)
        ]
        
        Task {
            for category in defaults {
                do {
                    try await FirebaseService.shared.saveDrugCategory(category)
                    await MainActor.run {
                        self.categories.append(category)
                    }
                } catch {
                    print("Error creating default category: \(error)")
                }
            }
        }
    }
}

#Preview {
    DrugLogView()
}

// MARK: - Edit Methods View

struct EditMethodsView: View {
    let category: DrugCategory
    
    @Environment(\.dismiss) var dismiss
    @State private var methods: [String]
    @State private var isSaving = false
    
    init(category: DrugCategory) {
        self.category = category
        self._methods = State(initialValue: category.methods)
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(methods.indices, id: \.self) { index in
                    HStack {
                        TextField("Method name", text: $methods[index])
                            .autocapitalization(.words)
                        
                        Button(action: { methods.remove(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Button(action: { methods.append("") }) {
                    Label("Add Method", systemImage: "plus.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .navigationTitle("Edit Methods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving || methods.filter { !$0.isEmpty }.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        
        var updatedCategory = category
        updatedCategory.methods = methods.filter { !$0.isEmpty }
        
        Task {
            do {
                try await FirebaseService.shared.saveDrugCategory(updatedCategory)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving methods: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}
