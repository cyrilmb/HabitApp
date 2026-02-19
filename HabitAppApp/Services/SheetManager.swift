//
//  SheetManager.swift
//  HabitTracker
//
//  Manages sheet dismissal and toast notifications across the app
//

import SwiftUI
import Combine

enum SheetType {
    case activity
    case substance
    case biometric
}

class SheetManager: ObservableObject {
    static let shared = SheetManager()

    @Published var activeSheetToDismiss: SheetType?
    @Published var showToast = false

    private var toastTask: Task<Void, Never>?

    private init() {}

    /// Dismiss the sheet for the given type and show a confirmation toast.
    func dismissAndToast(_ type: SheetType) {
        activeSheetToDismiss = type
        presentToast()
    }

    /// Show just the toast (no sheet dismissal). Used after timer completion.
    func showToastOnly() {
        presentToast()
    }

    /// Called by the consumer after acting on `activeSheetToDismiss`.
    func clearDismiss() {
        activeSheetToDismiss = nil
    }

    private func presentToast() {
        toastTask?.cancel()
        showToast = true
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                withAnimation {
                    showToast = false
                }
            }
        }
    }
}
