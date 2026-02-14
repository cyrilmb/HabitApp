//
//  AuthView.swift
//  HabitTracker
//
//  Authentication screen for user sign-in
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var isLoading = false
    @State private var isAppleLoading = false
    @State private var errorMessage: String?
    @State private var showPrivacyPolicy = false

    private let appleSignInHelper = AppleSignInHelper()

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

                // Sign in buttons
                VStack(spacing: 16) {
                    // Apple Sign In (primary)
                    Button(action: signInWithApple) {
                        HStack {
                            if isAppleLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "apple.logo")
                                Text("Sign in with Apple")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isAppleLoading || isLoading)

                    // Anonymous sign in (secondary)
                    Button(action: signInAnonymously) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Continue without account")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .disabled(isLoading || isAppleLoading)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal)
                    }

                    // Privacy policy link
                    Button(action: { showPrivacyPolicy = true }) {
                        Text("Privacy Policy")
                            .font(.caption)
                            .underline()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicyView()
            }
        }
    }

    private func signInWithApple() {
        isAppleLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await appleSignInHelper.signIn()
                try await firebaseService.signInWithApple(idToken: result.idToken, nonce: result.nonce)
            } catch {
                errorMessage = "Apple sign in failed. Please try again."
                print("Apple sign in error: \(error.localizedDescription)")
            }
            isAppleLoading = false
        }
    }

    private func signInAnonymously() {
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
