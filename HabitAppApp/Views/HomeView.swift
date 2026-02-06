//
//  HomeView.swift
//  HabitTracker
//
//  Main home screen with options to log activities, drugs, and biometrics
//

import SwiftUI

struct HomeView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var showActivitySheet = false
    @State private var showDrugSheet = false
    @State private var showBiometricSheet = false
    @State private var navigateToPastLogs = false
    @State private var navigateToDataDisplay = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Welcome header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Habit Tracker")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Track your daily activities and habits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Main action buttons
                    VStack(spacing: 20) {
                        // Log Activity Button
                        ActionButton(
                            icon: "timer",
                            title: "Log Activity",
                            subtitle: "Track time spent on activities",
                            color: .blue
                        ) {
                            showActivitySheet = true
                        }
                        
                        // Log Drug Button
                        ActionButton(
                            icon: "pill",
                            title: "Log Substance",
                            subtitle: "Record drug or alcohol use",
                            color: .purple
                        ) {
                            showDrugSheet = true
                        }
                        
                        // Biometric Button
                        ActionButton(
                            icon: "heart.text.square",
                            title: "Log Biometric",
                            subtitle: "Enter health data",
                            color: .red
                        ) {
                            showBiometricSheet = true
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Bottom navigation buttons
                    HStack(spacing: 20) {
                        NavigationButton(
                            icon: "list.bullet.clipboard",
                            title: "Past Logs",
                            action: { navigateToPastLogs = true }
                        )
                        
                        NavigationButton(
                            icon: "chart.bar.fill",
                            title: "Analytics",
                            action: { navigateToDataDisplay = true }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationDestination(isPresented: $navigateToPastLogs) {
                PastLogsView()
            }
            .navigationDestination(isPresented: $navigateToDataDisplay) {
                DataDisplayView()
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivitySelectionSheet()
            }
            .sheet(isPresented: $showDrugSheet) {
                DrugLogSheet()
            }
            .sheet(isPresented: $showBiometricSheet) {
                BiometricPlaceholderView()
            }
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation Button Component
struct NavigationButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder Views (to be built in later milestones)

struct ActivitySelectionSheet: View {
    var body: some View {
        Text("Activity Selection - Coming in Milestone 2")
            .font(.headline)
            .padding()
    }
}

struct DrugLogSheet: View {
    var body: some View {
        Text("Drug Log - Coming in Milestone 3")
            .font(.headline)
            .padding()
    }
}

struct BiometricPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Biometric Logging")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Coming in Milestone 5")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct PastLogsView: View {
    var body: some View {
        Text("Past Logs - Coming in Milestone 4")
            .font(.headline)
            .navigationTitle("Past Logs")
    }
}

struct DataDisplayView: View {
    var body: some View {
        Text("Analytics - Coming in Milestone 5")
            .font(.headline)
            .navigationTitle("Analytics")
    }
}

#Preview {
    HomeView()
}
