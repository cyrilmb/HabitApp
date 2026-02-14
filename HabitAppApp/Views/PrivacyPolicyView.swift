//
//  PrivacyPolicyView.swift
//  HabitTracker
//
//  Privacy policy for App Store compliance
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Last updated: \(Self.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                policySection(
                    title: "Data Collected",
                    content: """
                    Habit Tracker collects only the data you explicitly enter:
                    \u{2022} Activity logs (activity type, start/end times, notes)
                    \u{2022} Substance logs (substance type, method, dosage, notes)
                    \u{2022} Biometric data (weight, heart rate, mood, sleep, etc.)
                    \u{2022} Category preferences and settings

                    If you sign in with Apple, we receive a unique identifier and optionally your email address. We do not collect names, locations, or device identifiers beyond what is required for authentication.
                    """
                )

                policySection(
                    title: "Data Storage",
                    content: """
                    Your data is stored securely in Google Firebase (Cloud Firestore). Data is associated with your user account and protected by Firebase Authentication. All data is transmitted over encrypted HTTPS connections.

                    Data is stored on Google Cloud servers. For more information, see Google's privacy policy at https://policies.google.com/privacy.
                    """
                )

                policySection(
                    title: "Authentication",
                    content: """
                    You can use the app anonymously or sign in with your Apple ID. Anonymous accounts store data on our servers but are not linked to any personal identity. Signing in with Apple allows you to recover your data if you sign out or switch devices.
                    """
                )

                policySection(
                    title: "Third-Party Sharing",
                    content: """
                    We do not sell, share, or transfer your personal data to any third parties. Your data is used solely to provide the app's functionality to you.
                    """
                )

                policySection(
                    title: "Data Deletion",
                    content: """
                    You can delete your account and all associated data at any time from the Account screen within the app. When you delete your account, all data is permanently removed from our servers.
                    """
                )

                policySection(
                    title: "Contact",
                    content: """
                    If you have questions about this privacy policy or your data, please contact us at:

                    your-email@example.com

                    Please replace this with your actual contact email before publishing.
                    """
                )
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private static var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
