//
//  InputLimits.swift
//  HabitTracker
//
//  Central input validation limits
//

import Foundation

enum InputLimits {
    static let categoryName = 100
    static let methodName = 50
    static let notes = 1000
    static let dosageUnit = 20

    // Biometric numeric ranges
    static let weightRange = 1.0...1500.0
    static let heartRateRange = 20.0...300.0
    static let temperatureRange = 80.0...115.0
    static let bloodPressureRange = 40.0...300.0
    static let sleepDurationRange = 0.0...24.0
}
