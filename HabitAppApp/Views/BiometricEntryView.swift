//
//  BiometricEntryView.swift
//  HabitTracker
//
//  Quick button-based biometric logging view
//

import SwiftUI
import Combine

struct BiometricEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedType: BiometricType?
    @State private var showValueEntry = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            
                            Text("Biometric Data")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Select type to log")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top)
                        
                        // Biometric Type Buttons
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(BiometricType.allCases, id: \.self) { type in
                                BiometricTypeButton(type: type) {
                                    selectedType = type
                                    showValueEntry = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Log Biometric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $showValueEntry) {
                if let type = selectedType {
                    if type == .mood {
                        MoodEntryView()
                    } else {
                        BiometricValueEntryView(type: type)
                    }
                }
            }
        }
    }
}

// MARK: - Biometric Type Button

struct BiometricTypeButton: View {
    let type: BiometricType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(colorForType(type))
                
                Text(type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private func colorForType(_ type: BiometricType) -> Color {
        switch type {
        case .weight:
            return .green
        case .bedTime, .wakeTime:
            return .blue
        case .sleepDuration:
            return .indigo
        case .heartRate:
            return .red
        case .bloodPressure:
            return .orange
        case .temperature:
            return .pink
        case .mood:
            return .yellow
        }
    }
}

// MARK: - Value Entry View

struct BiometricValueEntryView: View {
    let type: BiometricType
    
    @Environment(\.dismiss) var dismiss
    @State private var value: String = ""
    @State private var notes: String = ""
    @State private var sleepTime: Date = Date()
    @State private var isSaving = false
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
                        .foregroundColor(colorForType(type))
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
            } header: {
                Text("Notes (Optional)")
            }
        }
        .navigationTitle("Enter Value")
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func colorForType(_ type: BiometricType) -> Color {
        switch type {
        case .weight:
            return .green
        case .bedTime, .wakeTime:
            return .blue
        case .sleepDuration:
            return .indigo
        case .heartRate:
            return .red
        case .bloodPressure:
            return .orange
        case .temperature:
            return .pink
        case .mood:
            return .yellow
        }
    }

    // MARK: - Save
    
    private func saveBiometric() {
        isSaving = true
        let userId = FirebaseService.shared.userId
        
        Task {
            do {
                if type == .bedTime {
                    // For sleep times, value is redundant - we use timestamp
                    let bedTime = Biometric(
                        userId: userId,
                        type: .bedTime,
                        value: 0,  // Not used for sleep times
                        unit: "time",
                        timestamp: sleepTime
                    )
                    var finalBedTime = bedTime
                    finalBedTime.notes = notes.isEmpty ? nil : notes
                    
                    try await FirebaseService.shared.saveBiometric(finalBedTime)
                    print("✅ Saved bed time: \(sleepTime)")
                    
                    await viewModel.checkAndCreateSleepDuration()
                    
                } else if type == .wakeTime {
                    // For sleep times, value is redundant - we use timestamp
                    let wakeTime = Biometric(
                        userId: userId,
                        type: .wakeTime,
                        value: 0,  // Not used for sleep times
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
                print("❌ Error saving biometric: \(error)")
                await MainActor.run {
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
        let localHour = calendar.component(.hour, from: pair.bedTime)
        
        // Determine which day this sleep belongs to.
        // Bed times between midnight and 6 AM count as the previous day.
        var sleepDate: Date
        if localHour >= 0 && localHour < 6 {
            sleepDate = calendar.startOfDay(for: pair.bedTime)
            sleepDate = calendar.date(byAdding: .day, value: -1, to: sleepDate) ?? sleepDate
        } else {
            sleepDate = calendar.startOfDay(for: pair.bedTime)
        }
        
        // Don't create a duplicate for the same night
        let alreadyExists = existingSleepDurations.contains {
            calendar.isDate($0.timestamp, inSameDayAs: sleepDate)
        }
        if alreadyExists { return }
        
        // Create the sleep duration entry
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
            
            // Fetch back to get the document ID of the new sleep duration
            let updated = try await FirebaseService.shared.fetchBiometrics(type: .sleepDuration, since: sevenDaysAgo)
            guard let created = updated.first(where: {
                $0.type == .sleepDuration && calendar.isDate($0.timestamp, inSameDayAs: sleepDate)
            }), let sleepId = created.id else { return }
            
            // Mark the bed and wake entries as paired so they aren't re-checked
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
        
        // Walk bed times (newest first) and find the first one that sits
        // before this wake time within a 1–16 hour window.
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

#Preview {
    BiometricEntryView()
}
