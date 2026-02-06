//
//  Biometric.swift
//  HabitTracker
//
//  Data model for biometric/health data tracking
//

import Foundation
import FirebaseFirestore

struct Biometric: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var type: BiometricType
    var customTypeName: String? // For custom biometric types
    var value: Double
    var secondaryValue: Double?
    var unit: String
    var timestamp: Date
    var notes: String?
    var pairedSleepId: String? // ID of the sleep duration this is paired with
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String, type: BiometricType, value: Double, unit: String, timestamp: Date = Date(), customTypeName: String? = nil, secondaryValue: Double? = nil) {
        self.userId = userId
        self.type = type
        self.customTypeName = customTypeName
        self.value = value
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.timestamp = timestamp
        self.pairedSleepId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var displayName: String {
        customTypeName ?? type.rawValue
    }
}

// Custom biometric type definition
struct BiometricTypeDefinition: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var name: String
    var unit: String
    var icon: String // SF Symbol name
    var createdAt: Date
    
    init(userId: String, name: String, unit: String, icon: String = "chart.xyaxis.line") {
        self.userId = userId
        self.name = name
        self.unit = unit
        self.icon = icon
        self.createdAt = Date()
    }
}

enum BiometricType: String, Codable, CaseIterable {
    case weight = "Weight"
    case bedTime = "Bed Time"
    case wakeTime = "Wake Time"
    case sleepDuration = "Sleep Duration"
    case bloodPressure = "Blood Pressure"
    case heartRate = "Heart Rate"
    case temperature = "Temperature"
    case mood = "Mood"

    var defaultUnit: String {
        switch self {
        case .weight:
            return "lbs"
        case .bedTime, .wakeTime:
            return "time"
        case .sleepDuration:
            return "hours"
        case .bloodPressure:
            return "mmHg"
        case .heartRate:
            return "bpm"
        case .temperature:
            return "°F"
        case .mood:
            return "mood"
        }
    }

    var icon: String {
        switch self {
        case .weight:
            return "scalemass"
        case .bedTime:
            return "bed.double"
        case .wakeTime:
            return "sun.max.fill"
        case .sleepDuration:
            return "moon.zzz"
        case .bloodPressure:
            return "heart.text.square"
        case .heartRate:
            return "heart"
        case .temperature:
            return "thermometer"
        case .mood:
            return "face.smiling"
        }
    }
}
