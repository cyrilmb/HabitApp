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

    @State private var kind: GoalKind
    @State private var comparison: GoalComparison
    @State private var value: String
    @State private var unit: String
    @State private var period: GoalPeriod
    @State private var hasPeriod: Bool
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Specialized inputs
    @State private var durationHours: Int
    @State private var durationMinutes: Int
    @State private var substanceMode: SubstanceGoalMode
    @State private var selectedDrugCategory: DrugCategory?
    @State private var weightUnit: String
    @State private var selectedTime: Date
    @State private var sleepHours: Int
    @State private var sleepMinutes: Int
    @State private var moodAxis: String
    @State private var moodValue: Double

    init(goal: Goal) {
        self.goal = goal
        _kind = State(initialValue: goal.kind)
        _comparison = State(initialValue: goal.comparison)
        _value = State(initialValue: goal.value == floor(goal.value) ? String(format: "%.0f", goal.value) : String(format: "%.1f", goal.value))
        _unit = State(initialValue: goal.unit)
        _period = State(initialValue: goal.period ?? .daily)
        _hasPeriod = State(initialValue: goal.period != nil)
        _isActive = State(initialValue: goal.isActive)

        // Initialize specialized inputs from goal values
        let biometricType = BiometricType(rawValue: goal.categoryName)
        let comps = GoalFormatters.componentsFromDecimalHours(goal.value)

        if goal.categoryType == .activity {
            _durationHours = State(initialValue: comps.hours)
            _durationMinutes = State(initialValue: comps.minutes)
        } else {
            _durationHours = State(initialValue: 0)
            _durationMinutes = State(initialValue: 0)
        }

        if biometricType == .sleepDuration {
            _sleepHours = State(initialValue: comps.hours)
            _sleepMinutes = State(initialValue: comps.minutes)
        } else {
            _sleepHours = State(initialValue: 8)
            _sleepMinutes = State(initialValue: 0)
        }

        if biometricType == .bedTime || biometricType == .wakeTime {
            _selectedTime = State(initialValue: GoalFormatters.dateFromFractionalHours(goal.value))
        } else {
            _selectedTime = State(initialValue: GoalFormatters.dateFromFractionalHours(22.0))
        }

        if biometricType == .weight {
            _weightUnit = State(initialValue: goal.unit)
        } else {
            _weightUnit = State(initialValue: "lbs")
        }

        if biometricType == .mood {
            _moodAxis = State(initialValue: goal.unit)
            _moodValue = State(initialValue: goal.value)
        } else {
            _moodAxis = State(initialValue: "pleasantness")
            _moodValue = State(initialValue: 0.5)
        }

        if goal.categoryType == .substance {
            _substanceMode = State(initialValue: goal.unit == "times" ? .frequency : .dosage)
        } else {
            _substanceMode = State(initialValue: .frequency)
        }

        _selectedDrugCategory = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                    // Specialized value input
                    valueInputSection

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

                // Bottom save button
                VStack(spacing: 0) {
                    Button {
                        Task { await saveGoal() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Save Changes")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave || isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadDrugCategory() }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Specialized Value Inputs

    @ViewBuilder
    private var valueInputSection: some View {
        let biometricType = BiometricType(rawValue: goal.categoryName)

        if goal.categoryType == .activity {
            activityDurationInput
        } else if goal.categoryType == .substance {
            substanceInput
        } else if biometricType == .bedTime || biometricType == .wakeTime {
            timeOfDayInput
        } else if biometricType == .sleepDuration {
            sleepDurationInput
        } else if biometricType == .weight {
            weightInput
        } else if biometricType == .mood {
            moodInput
        } else {
            genericValueInput
        }
    }

    private var activityDurationInput: some View {
        Section {
            HStack {
                Picker("Hours", selection: $durationHours) {
                    ForEach(0...24, id: \.self) { h in
                        Text("\(h)h").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Minutes", selection: $durationMinutes) {
                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                        Text("\(m)m").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 120)
        } header: {
            Text("Duration")
        }
    }

    private var substanceInput: some View {
        Section {
            if selectedDrugCategory?.defaultDosageUnit != nil {
                Picker("Mode", selection: $substanceMode) {
                    Text("Frequency").tag(SubstanceGoalMode.frequency)
                    Text("Dosage").tag(SubstanceGoalMode.dosage)
                }
                .pickerStyle(.segmented)
                .onChange(of: substanceMode) { _, newMode in
                    if newMode == .frequency {
                        unit = "times"
                    } else {
                        unit = selectedDrugCategory?.defaultDosageUnit ?? "mg"
                    }
                    value = ""
                }
            }

            HStack {
                TextField("Value", text: $value)
                    .keyboardType(.decimalPad)
                Text(substanceMode == .frequency ? "times" : (selectedDrugCategory?.defaultDosageUnit ?? unit))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Goal Value")
        }
    }

    private var timeOfDayInput: some View {
        Section {
            DatePicker(
                "Time",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        } header: {
            let biometricType = BiometricType(rawValue: goal.categoryName)
            Text(biometricType == .bedTime ? "Bed Time" : "Wake Time")
        }
    }

    private var sleepDurationInput: some View {
        Section {
            HStack {
                Picker("Hours", selection: $sleepHours) {
                    ForEach(0...16, id: \.self) { h in
                        Text("\(h)h").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Minutes", selection: $sleepMinutes) {
                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                        Text("\(m)m").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 120)
        } header: {
            Text("Sleep Duration")
        }
    }

    private var weightInput: some View {
        Section {
            Picker("Unit", selection: $weightUnit) {
                Text("lbs").tag("lbs")
                Text("kg").tag("kg")
            }
            .pickerStyle(.segmented)

            HStack {
                TextField("Weight", text: $value)
                    .keyboardType(.decimalPad)
                Text(weightUnit)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Target Weight")
        }
    }

    private var moodInput: some View {
        Section {
            Picker("Axis", selection: $moodAxis) {
                Text("Pleasantness").tag("pleasantness")
                Text("Energy").tag("energy")
            }
            .pickerStyle(.segmented)

            VStack(spacing: 8) {
                HStack {
                    Text(moodAxis == "pleasantness" ? "Unpleasant" : "Low Energy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%+.2f", moodValue))
                        .font(.headline)
                        .monospacedDigit()
                    Spacer()
                    Text(moodAxis == "pleasantness" ? "Pleasant" : "High Energy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $moodValue, in: -1...1, step: 0.05)
            }
        } header: {
            Text("Mood Target")
        }
    }

    private var genericValueInput: some View {
        Section {
            HStack {
                TextField("Value", text: $value)
                    .keyboardType(.decimalPad)
                Text(unit)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Goal Value")
        }
    }

    // MARK: - Helpers

    private var typeLabel: String {
        switch goal.categoryType {
        case .activity: return "Activity"
        case .substance: return "Substance"
        case .biometric: return "Biometric"
        }
    }

    private var canSave: Bool {
        let biometricType = BiometricType(rawValue: goal.categoryName)

        if goal.categoryType == .activity {
            return true
        } else if goal.categoryType == .substance {
            guard let val = Double(value), val >= 0 else { return false }
            return true
        } else if biometricType == .bedTime || biometricType == .wakeTime {
            return true
        } else if biometricType == .sleepDuration {
            return true
        } else if biometricType == .weight {
            guard let val = Double(value), val >= 0 else { return false }
            return true
        } else if biometricType == .mood {
            return true
        } else {
            guard let val = Double(value), val >= 0 else { return false }
            return !unit.isEmpty
        }
    }

    private func loadDrugCategory() async {
        guard goal.categoryType == .substance else { return }
        do {
            let categories = try await FirebaseService.shared.fetchDrugCategories()
            selectedDrugCategory = categories.first(where: { $0.name == goal.categoryName })
        } catch {
            print("Error loading drug category: \(error)")
        }
    }

    private func saveGoal() async {
        let biometricType = BiometricType(rawValue: goal.categoryName)
        let finalValue: Double
        let finalUnit: String

        if goal.categoryType == .activity {
            finalValue = GoalFormatters.decimalHoursFromComponents(hours: durationHours, minutes: durationMinutes)
            finalUnit = "hours"
        } else if goal.categoryType == .substance {
            guard let val = Double(value) else { return }
            finalValue = val
            finalUnit = substanceMode == .frequency ? "times" : (selectedDrugCategory?.defaultDosageUnit ?? unit)
        } else if biometricType == .bedTime || biometricType == .wakeTime {
            finalValue = GoalFormatters.fractionalHoursFromDate(selectedTime)
            finalUnit = "time"
        } else if biometricType == .sleepDuration {
            finalValue = GoalFormatters.decimalHoursFromComponents(hours: sleepHours, minutes: sleepMinutes)
            finalUnit = "hours"
        } else if biometricType == .weight {
            guard let val = Double(value) else { return }
            finalValue = val
            finalUnit = weightUnit
        } else if biometricType == .mood {
            finalValue = moodValue
            finalUnit = moodAxis
        } else {
            guard let val = Double(value) else { return }
            finalValue = val
            finalUnit = unit
        }

        var updated = goal
        updated.kind = kind
        updated.comparison = comparison
        updated.value = finalValue
        updated.unit = finalUnit
        updated.period = (goal.categoryType == .biometric && !hasPeriod) ? nil : period
        updated.isActive = isActive
        updated.updatedAt = Date()
        isSaving = true
        do {
            try await FirebaseService.shared.saveGoal(updated)
            dismiss()
        } catch {
            errorMessage = "Failed to save goal: \(error.localizedDescription)"
            isSaving = false
        }
    }
}
