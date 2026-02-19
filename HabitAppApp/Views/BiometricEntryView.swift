//
//  BiometricEntryView.swift
//  HabitTracker
//
//  Quick button-based biometric logging view
//

import SwiftUI
import Combine

struct BiometricEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedType: BiometricType?
    @State private var showValueEntry = false
    @State private var enabledTypes: [BiometricType] = []
    @State private var showEditTypes = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)

                            Text("Biometric Data")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Select type to log")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top)

                        // Biometric Type Buttons
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(enabledTypes, id: \.self) { type in
                                BiometricTypeButton(type: type) {
                                    selectedType = type
                                    showValueEntry = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Log Biometric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEditTypes = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .navigationDestination(isPresented: $showValueEntry) {
                if let type = selectedType {
                    if type == .mood {
                        MoodEntryView()
                    } else {
                        BiometricValueEntryView(type: type)
                    }
                }
            }
            .sheet(isPresented: $showEditTypes) {
                EditBiometricTypesView(enabledTypes: enabledTypes) {
                    loadPreferences()
                }
            }
            .task {
                loadPreferences()
            }
        }
    }

    private func loadPreferences() {
        Task {
            do {
                let types = try await FirebaseService.shared.fetchBiometricTypePreferences()
                await MainActor.run {
                    enabledTypes = types
                }
            } catch {
                await MainActor.run {
                    enabledTypes = Array(BiometricType.allCases)
                }
            }
        }
    }
}

// MARK: - Biometric Type Button

struct BiometricTypeButton: View {
    let type: BiometricType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(colorForBiometricType(type))

                Text(type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BiometricEntryView()
}
