//
//  AuthView.swift
//  HabitTracker
//
//  Authentication screen for user sign-in
//

import SwiftUI

struct AuthView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App icon and title
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                    
                    Text("Habit Tracker")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Track your daily habits and progress")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Sign in button
                VStack(spacing: 20) {
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.blue)
                            } else {
                                Image(systemName: "person.circle.fill")
                                Text("Get Started")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal)
                    }
                    
                    Text("Your data is private and secure")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await firebaseService.signInAnonymously()
            } catch {
                errorMessage = "Failed to sign in. Please try again."
                print("Sign in error: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
}

#Preview {
    AuthView()
}
