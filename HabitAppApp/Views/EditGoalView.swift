//
//  EditGoalView.swift
//  HabitTracker
//
//  Edit an existing goal
//

import SwiftUI

struct EditGoalView: View {
    @Environment(\.dismiss) var dismiss

    let goal: Goal
    let onSave: (Goal) -> Void

    @State private var kind: GoalKind
    @State private var comparison: GoalComparison
    @State private var value: String
    @State private var unit: String
    @State private var period: GoalPeriod
    @State private var hasPeriod: Bool
    @State private var isActive: Bool

    init(goal: Goal, onSave: @escaping (Goal) -> Void) {
        self.goal = goal
        self.onSave = onSave
        _kind = State(initialValue: goal.kind)
        _comparison = State(initialValue: goal.comparison)
        _value = State(initialValue: goal.value == floor(goal.value) ? String(format: "%.0f", goal.value) : String(format: "%.1f", goal.value))
        _unit = State(initialValue: goal.unit)
        _period = State(initialValue: goal.period ?? .daily)
        _hasPeriod = State(initialValue: goal.period != nil)
        _isActive = State(initialValue: goal.isActive)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Category info (read-only)
                Section {
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(goal.categoryName)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(typeLabel)
                            .foregroundColor(.secondary)
                    }
                }

                // Kind picker
                if goal.categoryType == .substance || goal.categoryType == .biometric {
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
                if goal.categoryType == .biometric {
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

                // Active toggle
                Section {
                    Toggle("Active", isOn: $isActive)
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGoal() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var typeLabel: String {
        switch goal.categoryType {
        case .activity: return "Activity"
        case .substance: return "Substance"
        case .biometric: return "Biometric"
        }
    }

    private var canSave: Bool {
        guard let val = Double(value), val > 0 else { return false }
        return !unit.isEmpty
    }

    private func saveGoal() {
        guard let val = Double(value) else { return }
        var updated = goal
        updated.kind = kind
        updated.comparison = comparison
        updated.value = val
        updated.unit = unit
        updated.period = (goal.categoryType == .biometric && !hasPeriod) ? nil : period
        updated.isActive = isActive
        updated.updatedAt = Date()
        onSave(updated)
        dismiss()
    }
}
