//
//  DataExportService.swift
//  HabitTracker
//
//  Exports all user data as a JSON file for data portability
//

import Foundation

struct DataExportService {

    struct ExportData: Encodable {
        let exportDate: Date
        let activities: [Activity]
        let activityCategories: [ActivityCategory]
        let drugLogs: [DrugLog]
        let drugCategories: [DrugCategory]
        let biometrics: [Biometric]
        let goals: [Goal]
    }

    static func exportAllData() async throws -> URL {
        let service = FirebaseService.shared

        async let activities = service.fetchActivities()
        async let activityCategories = service.fetchActivityCategories()
        async let drugLogs = service.fetchDrugLogs()
        async let drugCategories = service.fetchDrugCategories()
        async let biometrics = service.fetchBiometrics()
        async let goals = service.fetchGoals()

        let exportData = try await ExportData(
            exportDate: Date(),
            activities: activities,
            activityCategories: activityCategories,
            drugLogs: drugLogs,
            drugCategories: drugCategories,
            biometrics: biometrics,
            goals: goals
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(exportData)

        let fileName = "HabitApp-Export-\(Self.filenameDateString()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)

        return tempURL
    }

    private static func filenameDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
