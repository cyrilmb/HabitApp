//
//  BiometricHelpers.swift
//  HabitTracker
//
//  Shared color mapping for biometric types
//

import SwiftUI

func colorForBiometricType(_ type: BiometricType) -> Color {
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
