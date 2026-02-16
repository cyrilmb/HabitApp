//
//  CreateGoalView.swift
//  HabitTracker
//
//  Multi-step goal creation form
//

import SwiftUI

struct CreateGoalView: View {
    @Environment(\.dismiss) var dismiss
    @State private var step = 1

    // Step 1: Category type
    @State private var categoryType: GoalCategoryType = .activity

    // Step 2: Specific category
    @State private var categoryName = ""
    @State private var activityCategories: [ActivityCategory] = []
    @State private var drugCategories: [DrugCategory] = []

    // Step 3: Goal details
    @State private var kind: GoalKind = .target
    @State private var comparison: GoalComparison = .atLeast
    @State private var value: String = ""
    @State private var unit: String = ""
    @State private var period: GoalPeriod = .daily
    @State private var hasPeriod = true

    let onSave: (Goal) -> Void

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case 1:
                    step1CategoryType
                case 2:
                    step2CategoryPicker
                default:
                    step3GoalDetails
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step < 3 {
                        Button("Next") { step += 1 }
                            .disabled(!canAdvance)
                    } else {
                        Button("Save") { saveGoal() }
                            .disabled(!canSave)
                    }
                }
                if step > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { step -= 1 }
                    }
                }
            }
            .task { await loadCategories() }
        }
    }

    // MARK: - Step Views

    private var step1CategoryType: some View {
        Section {
            ForEach(GoalCategoryType.allCases, id: \.self) { type in
                HStack {
                    Image(systemName: iconFor(type))
                        .foregroundColor(colorFor(type))
                        .frame(width: 30)
                    Text(labelFor(type))
                    Spacer()
                    if categoryType == type {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    categoryType = type
                    categoryName = ""
                    applyDefaults(for: type)
                }
            }
        } header: {
            Text("What type of goal?")
        }
    }

    private var step2CategoryPicker: some View {
        Section {
            switch categoryType {
            case .activity:
                if activityCategories.isEmpty {
                    Text("No activity categories yet. Create one first.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(activityCategories) { cat in
                        HStack {
                            Text(cat.name)
                            Spacer()
                            if categoryName == cat.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            categoryName = cat.name
                            unit = "hours"
                        }
                    }
                }
            case .substance:
                if drugCategories.isEmpty {
                    Text("No substance categories yet. Create one first.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(drugCategories) { cat in
                        HStack {
                            Text(cat.name)
                            Spacer()
                            if categoryName == cat.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            categoryName = cat.name
                            unit = cat.defaultDosageUnit ?? "times"
                        }
                    }
                }
            case .biometric:
                ForEach(BiometricType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                            .frame(width: 30)
                        Text(type.rawValue)
                        Spacer()
                        if categoryName == type.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        categoryName = type.rawValue
                        unit = type.defaultUnit
                    }
                }
            }
        } header: {
            Text("Choose a category")
        }
    }

    private var step3GoalDetails: some View {
        Group {
            // Kind picker (for substances and biometrics)
            if categoryType == .substance || categoryType == .biometric {
                Section {
                    Picker("Goal Type", selection: $kind) {
                        Text("Target").tag(GoalKind.target)
                        Text("Limit").tag(GoalKind.limit)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newKind in
                        comparison = newKind == .target ? .atLeast : .atMost
                    }
                } header: {
                    Text("Goal Type")
                } footer: {
                    Text(kind == .target ? "Aim to reach this value" : "Aim to stay under this value")
                }
            }

            // Comparison
            Section {
                Picker("Comparison", selection: $comparison) {
                    Text("At least").tag(GoalComparison.atLeast)
                    Text("At most").tag(GoalComparison.atMost)
                    Text("Exactly").tag(GoalComparison.exactly)
                }
            } header: {
                Text("Comparison")
            }

            // Value & Unit
            Section {
                HStack {
                    TextField("Value", text: $value)
                        .keyboardType(.decimalPad)
                    Text(unit)
                        .foregroundColor(.secondary)
                }
                TextField("Unit", text: $unit)
            } header: {
                Text("Goal Value")
            }

            // Period
            if categoryType == .biometric {
                Section {
                    Toggle("Recurring Goal", isOn: $hasPeriod)
                    if hasPeriod {
                        Picker("Period", selection: $period) {
                            ForEach(GoalPeriod.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                    }
                } header: {
                    Text("Frequency")
                } footer: {
                    Text(hasPeriod ? "Track progress over each period" : "One-time target (e.g., target weight)")
                }
            } else {
                Section {
                    Picker("Period", selection: $period) {
                        ForEach(GoalPeriod.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                } header: {
                    Text("Frequency")
                }
            }
        }
    }

    // MARK: - Logic

    private var stepTitle: String {
        switch step {
        case 1: return "New Goal"
        case 2: return "Select Category"
        default: return "Configure Goal"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 1: return true
        case 2: return !categoryName.isEmpty
        default: return false
        }
    }

    private var canSave: Bool {
        guard let val = Double(value), val > 0 else { return false }
        return !categoryName.isEmpty && !unit.isEmpty
    }

    private func applyDefaults(for type: GoalCategoryType) {
        switch type {
        case .activity:
            kind = .target
            comparison = .atLeast
            unit = "hours"
            hasPeriod = true
        case .substance:
            kind = .limit
            comparison = .atMost
            unit = "times"
            hasPeriod = true
        case .biometric:
            kind = .target
            comparison = .atLeast
            unit = ""
            hasPeriod = false
        }
    }

    private func iconFor(_ type: GoalCategoryType) -> String {
        switch type {
        case .activity: return "timer"
        case .substance: return "pill"
        case .biometric: return "heart.text.square"
        }
    }

    private func colorFor(_ type: GoalCategoryType) -> Color {
        switch type {
        case .activity: return .blue
        case .substance: return .purple
        case .biometric: return .red
        }
    }

    private func labelFor(_ type: GoalCategoryType) -> String {
        switch type {
        case .activity: return "Activity"
        case .substance: return "Substance"
        case .biometric: return "Biometric"
        }
    }

    private func loadCategories() async {
        do {
            activityCategories = try await FirebaseService.shared.fetchActivityCategories()
            drugCategories = try await FirebaseService.shared.fetchDrugCategories()
        } catch {
            print("Error loading categories: \(error)")
        }
    }

    private func saveGoal() {
        guard let val = Double(value) else { return }
        let goal = Goal(
            userId: FirebaseService.shared.userId,
            categoryType: categoryType,
            categoryName: categoryName,
            kind: kind,
            comparison: comparison,
            value: val,
            unit: unit,
            period: (categoryType == .biometric && !hasPeriod) ? nil : period
        )
        onSave(goal)
        dismiss()
    }
}
