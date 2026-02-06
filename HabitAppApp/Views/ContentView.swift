//
//  ContentView.swift
//  HabitTracker
//
//  Main content view that shows auth or home based on user state
//

import SwiftUI

struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                HomeView()
            } else {
                AuthView()
            }
        }
    }
}

#Preview {
    ContentView()
}
