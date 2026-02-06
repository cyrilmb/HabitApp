//
//  Biometric.swift
//  HabitApp
//
//  Data model for biometric/health data tracking
//

import Foundation
import FirebaseFirestore

struct Biometric: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var type: BiometricType
    var value: Double
    var unit: String
    var timestamp: Date
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String, type: BiometricType, value: Double, unit: String, timestamp: Date = Date()) {
        self.userId = userId
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.createdAt = Date()
        self.updatedAt = Date()
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
    case other = "Other"
    
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
        case .other:
            return ""
        }
    }
    
    var icon: String {
        switch self {
        case .weight:
            return "scalemass"
        case .bedTime, .wakeTime:
            return "bed.double"
        case .sleepDuration:
            return "moon.zzz"
        case .bloodPressure:
            return "heart.text.square"
        case .heartRate:
            return "heart"
        case .temperature:
            return "thermometer"
        case .other:
            return "chart.line.uptrend.xyaxis"
        }
    }
}
