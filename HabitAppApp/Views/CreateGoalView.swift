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
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Specialized inputs
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 0
    @State private var substanceMode: SubstanceGoalMode = .frequency
    @State private var selectedDrugCategory: DrugCategory?
    @State private var weightUnit: String = "lbs"
    @State private var selectedTime: Date = GoalFormatters.dateFromFractionalHours(22.0)
    @State private var sleepHours: Int = 8
    @State private var sleepMinutes: Int = 0
    @State private var moodAxis: String = "pleasantness"
    @State private var moodValue: Double = 0.5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                // Bottom action buttons
                VStack(spacing: 12) {
                    if step < 3 {
                        Button {
                            step += 1
                        } label: {
                            Text("Next")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAdvance)
                    } else {
                        Button {
                            Task { await saveGoal() }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Text("Save Goal")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave || isSaving)
                    }

                    if step > 1 {
                        Button("Back") { step -= 1 }
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadCategories() }
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
                            selectedDrugCategory = cat
                            unit = cat.defaultDosageUnit ?? "times"
                            substanceMode = (cat.defaultDosageUnit != nil) ? .dosage : .frequency
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
                        applyBiometricDefaults(for: type)
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

            // Specialized value input
            valueInputSection

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

    // MARK: - Specialized Value Inputs

    @ViewBuilder
    private var valueInputSection: some View {
        let biometricType = BiometricType(rawValue: categoryName)

        if categoryType == .activity {
            activityDurationInput
        } else if categoryType == .substance {
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
            let biometricType = BiometricType(rawValue: categoryName)
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
        let biometricType = BiometricType(rawValue: categoryName)
        guard !categoryName.isEmpty else { return false }

        if categoryType == .activity {
            return true
        } else if categoryType == .substance {
            guard let val = Double(value), val >= 0 else { return false }
            return true
        } else if biometricType == .bedTime || biometricType == .wakeTime {
            return true // DatePicker always valid
        } else if biometricType == .sleepDuration {
            return true
        } else if biometricType == .weight {
            guard let val = Double(value), val >= 0 else { return false }
            return true
        } else if biometricType == .mood {
            return true // Slider always valid
        } else {
            guard let val = Double(value), val >= 0 else { return false }
            return !unit.isEmpty
        }
    }

    private func applyDefaults(for type: GoalCategoryType) {
        switch type {
        case .activity:
            kind = .target
            comparison = .atLeast
            unit = "hours"
            hasPeriod = true
            durationHours = 1
            durationMinutes = 0
        case .substance:
            kind = .limit
            comparison = .atMost
            unit = "times"
            hasPeriod = true
            substanceMode = .frequency
        case .biometric:
            kind = .target
            comparison = .atLeast
            unit = ""
            hasPeriod = false
        }
    }

    private func applyBiometricDefaults(for type: BiometricType) {
        unit = type.defaultUnit
        switch type {
        case .bedTime:
            selectedTime = GoalFormatters.dateFromFractionalHours(22.0) // 10:00 PM
            comparison = .atMost
            kind = .target
            hasPeriod = true
            period = .daily
        case .wakeTime:
            selectedTime = GoalFormatters.dateFromFractionalHours(7.0) // 7:00 AM
            comparison = .atMost
            kind = .target
            hasPeriod = true
            period = .daily
        case .sleepDuration:
            sleepHours = 8
            sleepMinutes = 0
            comparison = .atLeast
            kind = .target
            hasPeriod = true
            period = .daily
        case .weight:
            weightUnit = "lbs"
            hasPeriod = false
        case .mood:
            moodAxis = "pleasantness"
            moodValue = 0.5
            comparison = .atLeast
            kind = .target
            hasPeriod = true
            period = .daily
        default:
            break
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

    private func saveGoal() async {
        let biometricType = BiometricType(rawValue: categoryName)
        let finalValue: Double
        let finalUnit: String

        if categoryType == .activity {
            finalValue = GoalFormatters.decimalHoursFromComponents(hours: durationHours, minutes: durationMinutes)
            finalUnit = "hours"
        } else if categoryType == .substance {
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

        let goal = Goal(
            userId: FirebaseService.shared.userId,
            categoryType: categoryType,
            categoryName: categoryName,
            kind: kind,
            comparison: comparison,
            value: finalValue,
            unit: finalUnit,
            period: (categoryType == .biometric && !hasPeriod) ? nil : period
        )
        isSaving = true
        do {
            try await FirebaseService.shared.saveGoal(goal)
            dismiss()
        } catch {
            errorMessage = "Failed to save goal: \(error.localizedDescription)"
            isSaving = false
        }
    }
}
