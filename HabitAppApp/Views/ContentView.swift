//
//  ContentView.swift
//  HabitTracker
//
//  Main content view that shows auth or home based on user state
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                if !hasSeenOnboarding {
                    OnboardingView()
                } else {
                    HomeView()
                }
            } else {
                AuthView()
            }
        }
    }
}

#Preview {
    ContentView()
}
