//
//  BiometricValueEntryView.swift
//  HabitTracker
//
//  Value entry view for biometric data and sleep logic ViewModel
//

import SwiftUI
import Combine

struct BiometricValueEntryView: View {
    let type: BiometricType

    @Environment(\.dismiss) var dismiss
    @State private var value: String = ""
    @State private var notes: String = ""
    @State private var sleepTime: Date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @StateObject private var viewModel = BiometricEntryViewModel()

    init(type: BiometricType) {
        self.type = type
        _viewModel = StateObject(wrappedValue: BiometricEntryViewModel())
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(colorForBiometricType(type))
                    Text(type.rawValue)
                        .font(.headline)
                }
            }

            if type == .bedTime || type == .wakeTime {
                sleepTimeSection
            } else if type == .sleepDuration {
                sleepDurationSection
            } else {
                valueInputSection
            }

            Section {
                TextEditor(text: $notes)
                    .frame(height: 80)
                    .onChange(of: notes) { _, new in
                        if new.count > InputLimits.notes {
                            notes = String(new.prefix(InputLimits.notes))
                        }
                    }
            } header: {
                Text("Notes (Optional)")
            }
        }
        .navigationTitle("Enter Value")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: saveBiometric) {
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
                .background(Color.red.gradient)
                .cornerRadius(12)
            }
            .disabled(!canSave || isSaving)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            viewModel.loadRecentSleepLogs()
        }
    }

    // MARK: - Input Sections

    private var valueInputSection: some View {
        Section {
            HStack {
                TextField("Value", text: $value)
                    .keyboardType(.decimalPad)
                    .font(.title3)

                Text(type.defaultUnit)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Value")
        } footer: {
            Text(footerText)
        }
    }

    private var sleepTimeSection: some View {
        Section {
            DatePicker(
                type == .bedTime ? "Bed Time" : "Wake Time",
                selection: $sleepTime,
                displayedComponents: [.date, .hourAndMinute]
            )
        } header: {
            Text("Time")
        } footer: {
            Text("Sleep duration will be calculated automatically if you log both bed time and wake time")
        }
    }

    private var sleepDurationSection: some View {
        Section {
            HStack {
                TextField("Hours", text: $value)
                    .keyboardType(.decimalPad)
                    .font(.title3)

                Text("hours")
                    .foregroundColor(.secondary)
            }

            DatePicker("Date", selection: $sleepTime, displayedComponents: [.date])
        } header: {
            Text("Duration")
        } footer: {
            Text("Enter total sleep duration in hours (e.g., 7.5)")
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        if type == .bedTime || type == .wakeTime {
            return true
        }
        return !value.isEmpty && Double(value) != nil
    }

    private var footerText: String {
        switch type {
        case .weight:
            return "Enter your weight in pounds"
        case .heartRate:
            return "Enter your heart rate in beats per minute"
        case .temperature:
            return "Enter your body temperature in Fahrenheit"
        case .bloodPressure:
            return "Enter systolic blood pressure (e.g., 120)"
        default:
            return "Enter a numeric value"
        }
    }

    // MARK: - Save

    private func saveBiometric() {
        isSaving = true
        let userId = FirebaseService.shared.userId

        Task {
            do {
                if type == .bedTime {
                    let bedTime = Biometric(
                        userId: userId,
                        type: .bedTime,
                        value: 0,
                        unit: "time",
                        timestamp: sleepTime
                    )
                    var finalBedTime = bedTime
                    finalBedTime.notes = notes.isEmpty ? nil : notes

                    try await FirebaseService.shared.saveBiometric(finalBedTime)
                    print("✅ Saved bed time: \(sleepTime)")

                    await viewModel.checkAndCreateSleepDuration()

                } else if type == .wakeTime {
                    let wakeTime = Biometric(
                        userId: userId,
                        type: .wakeTime,
                        value: 0,
                        unit: "time",
                        timestamp: sleepTime
                    )
                    var finalWakeTime = wakeTime
                    finalWakeTime.notes = notes.isEmpty ? nil : notes

                    try await FirebaseService.shared.saveBiometric(finalWakeTime)
                    print("✅ Saved wake time: \(sleepTime)")

                    await viewModel.checkAndCreateSleepDuration()

                } else {
                    guard let numericValue = Double(value) else {
                        await MainActor.run { isSaving = false }
                        return
                    }

                    let timestamp = type == .sleepDuration ? sleepTime : Date()

                    let biometric = Biometric(
                        userId: userId,
                        type: type,
                        value: numericValue,
                        unit: type.defaultUnit,
                        timestamp: timestamp
                    )
                    var finalBiometric = biometric
                    finalBiometric.notes = notes.isEmpty ? nil : notes

                    try await FirebaseService.shared.saveBiometric(finalBiometric)
                    print("✅ Saved \(type.rawValue): \(numericValue)")
                }

                await MainActor.run {
                    isSaving = false
                    SheetManager.shared.dismissAndToast(.biometric)
                }
            } catch {
                print("Error saving biometric: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save. Please try again."
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - View Model for Sleep Logic

class BiometricEntryViewModel: ObservableObject {
    @Published var createdSleepDuration = false

    private var recentBedTimes: [Biometric] = []
    private var recentWakeTimes: [Biometric] = []
    private var existingSleepDurations: [Biometric] = []

    func loadRecentSleepLogs() {
        Task {
            do {
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let recentBiometrics = try await FirebaseService.shared.fetchBiometrics(since: sevenDaysAgo)

                await MainActor.run {
                    self.recentBedTimes = recentBiometrics
                        .filter { $0.type == .bedTime && $0.pairedSleepId == nil }
                        .sorted { $0.timestamp > $1.timestamp }

                    self.recentWakeTimes = recentBiometrics
                        .filter { $0.type == .wakeTime && $0.pairedSleepId == nil }
                        .sorted { $0.timestamp > $1.timestamp }

                    self.existingSleepDurations = recentBiometrics
                        .filter { $0.type == .sleepDuration }
                }
            } catch {
                print("Error loading sleep logs: \(error)")
            }
        }
    }

    func checkAndCreateSleepDuration() async {
        createdSleepDuration = false
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        do {
            let recentBiometrics = try await FirebaseService.shared.fetchBiometrics(since: sevenDaysAgo)

            recentBedTimes = recentBiometrics
                .filter { $0.type == .bedTime && $0.pairedSleepId == nil }
                .sorted { $0.timestamp > $1.timestamp }

            recentWakeTimes = recentBiometrics
                .filter { $0.type == .wakeTime && $0.pairedSleepId == nil }
                .sorted { $0.timestamp > $1.timestamp }

            existingSleepDurations = recentBiometrics
                .filter { $0.type == .sleepDuration }

        } catch {
            print("Error reloading sleep data: \(error)")
            return
        }

        guard let pair = findMatchingSleepPair() else { return }

        let duration = pair.wakeTime.timeIntervalSince(pair.bedTime) / 3600
        guard duration >= 1 && duration <= 16 else { return }

        let calendar = Calendar.current
        let sleepDate = calendar.startOfDay(for: pair.wakeTime)

        let alreadyExists = existingSleepDurations.contains {
            calendar.isDate($0.timestamp, inSameDayAs: sleepDate)
        }
        if alreadyExists { return }

        let userId = FirebaseService.shared.userId
        var sleepDuration = Biometric(
            userId: userId,
            type: .sleepDuration,
            value: duration,
            unit: "hours",
            timestamp: sleepDate
        )
        sleepDuration.notes = "Auto-calculated from bed/wake times"

        do {
            try await FirebaseService.shared.saveBiometric(sleepDuration)

            let updated = try await FirebaseService.shared.fetchBiometrics(type: .sleepDuration, since: sevenDaysAgo)
            guard let created = updated.first(where: {
                $0.type == .sleepDuration && calendar.isDate($0.timestamp, inSameDayAs: sleepDate)
            }), let sleepId = created.id else { return }

            if var bed = pair.bedTimeBiometric {
                bed.pairedSleepId = sleepId
                try await FirebaseService.shared.saveBiometric(bed)
            }
            if var wake = pair.wakeTimeBiometric {
                wake.pairedSleepId = sleepId
                try await FirebaseService.shared.saveBiometric(wake)
            }

            await MainActor.run {
                createdSleepDuration = true
            }
        } catch {
            print("Error saving sleep duration: \(error)")
        }
    }

    private func findMatchingSleepPair() -> (bedTime: Date, wakeTime: Date, bedTimeBiometric: Biometric?, wakeTimeBiometric: Biometric?)? {
        guard let latestWake = recentWakeTimes.first else { return nil }

        for bed in recentBedTimes {
            guard bed.timestamp < latestWake.timestamp else { continue }

            let hours = latestWake.timestamp.timeIntervalSince(bed.timestamp) / 3600
            if hours >= 1 && hours <= 16 {
                return (
                    bedTime: bed.timestamp,
                    wakeTime: latestWake.timestamp,
                    bedTimeBiometric: bed,
                    wakeTimeBiometric: latestWake
                )
            }
        }

        return nil
    }
}
