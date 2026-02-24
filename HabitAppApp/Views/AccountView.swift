//
//  AccountView.swift
//  HabitTracker
//
//  Account management: account type, link Apple, sign out, delete
//

import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true
    @AppStorage("hasSeenTooltips") private var hasSeenTooltips = true
    @State private var isLinking = false
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?
    @State private var showPrivacyPolicy = false
    @State private var isExporting = false
    @State private var exportFileURL: URL?

    private let appleSignInHelper = AppleSignInHelper()

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: firebaseService.isAnonymous ? "person.fill.questionmark" : "apple.logo")
                        .font(.title2)
                        .foregroundColor(firebaseService.isAnonymous ? .orange : .primary)
                        .frame(width: 40)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(firebaseService.isAnonymous ? "Anonymous Account" : "Apple ID")
                            .font(.headline)
                        Text(firebaseService.isAnonymous
                             ? "Your data is not backed up"
                             : "Your data is linked to your Apple ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Account")
            }

            if firebaseService.isAnonymous {
                Section {
                    Button(action: linkAppleAccount) {
                        HStack {
                            if isLinking {
                                ProgressView()
                            } else {
                                Image(systemName: "apple.logo")
                                Text("Link Apple Account")
                            }
                        }
                    }
                    .disabled(isLinking)
                } header: {
                    Text("Upgrade Account")
                } footer: {
                    Text("Link your Apple ID to back up your data and sign in on other devices. Your existing data will be preserved.")
                }
            }

            if let errorMessage {
                Section {
                    HStack {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                        Spacer()
                        Button("Retry") {
                            self.errorMessage = nil
                            linkAppleAccount()
                        }
                        .font(.caption)
                    }
                }
            }

            Section {
                Button(action: exportData) {
                    HStack {
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Data")
                        }
                    }
                }
                .disabled(isExporting)
            } header: {
                Text("Data")
            } footer: {
                Text("Export all your data as a JSON file.")
            }

            Section {
                Button(action: {
                    hasSeenOnboarding = false
                    hasSeenTooltips = false
                }) {
                    HStack {
                        Image(systemName: "book.fill")
                        Text("Show Walkthrough")
                    }
                }
            } footer: {
                Text("Replay the intro pages and feature tour.")
            }

            Section {
                Button(action: { showPrivacyPolicy = true }) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Privacy Policy")
                    }
                }
            }

            Section {
                Button(action: signOut) {
                    HStack {
                        if isSigningOut {
                            ProgressView()
                        } else {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
                .disabled(isSigningOut)
            } footer: {
                if firebaseService.isAnonymous {
                    Text("Warning: Signing out of an anonymous account will permanently lose all your data.")
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(role: .destructive, action: { showDeleteAlert = true }) {
                    HStack {
                        if isDeletingAccount {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                    }
                }
                .disabled(isDeletingAccount)
            } footer: {
                Text("This will permanently delete your account and sign you out.")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicyView()
            }
        }
        .sheet(isPresented: Binding(
            get: { exportFileURL != nil },
            set: { if !$0 { exportFileURL = nil } }
        )) {
            if let url = exportFileURL {
                ActivityShareSheet(items: [url])
            }
        }
        .alert("Delete Account?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This will permanently delete your account. This cannot be undone.")
        }
    }

    private func exportData() {
        isExporting = true
        errorMessage = nil

        Task {
            do {
                let url = try await DataExportService.exportAllData()
                await MainActor.run {
                    exportFileURL = url
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to export data. Please try again."
                    isExporting = false
                }
            }
        }
    }

    private func linkAppleAccount() {
        isLinking = true
        errorMessage = nil

        Task {
            do {
                let result = try await appleSignInHelper.signIn()
                try await firebaseService.linkAppleAccount(idToken: result.idToken, nonce: result.nonce)
                await MainActor.run {
                    isLinking = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to link Apple account: \(error.localizedDescription)"
                    isLinking = false
                }
            }
        }
    }

    private func signOut() {
        isSigningOut = true
        do {
            try firebaseService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
        isSigningOut = false
    }

    private func deleteAccount() {
        isDeletingAccount = true
        errorMessage = nil

        Task {
            do {
                try await firebaseService.deleteAccount()
                await MainActor.run {
                    isDeletingAccount = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete account: \(error.localizedDescription)"
                    isDeletingAccount = false
                }
            }
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        AccountView()
    }
}
