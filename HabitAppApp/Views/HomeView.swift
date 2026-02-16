//
//  HomeView.swift
//  HabitTracker
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var sheetManager = SheetManager.shared
    @ObservedObject private var timerService = TimerService.shared
    @State private var showActivitySheet = false
    @State private var showDrugSheet = false
    @State private var showBiometricSheet = false
    @State private var navigateToPastLogs = false
    @State private var navigateToDataDisplay = false
    @State private var navigateToGoals = false
    @State private var showTimerSheet = false
    @State private var timerSheetActivity: Activity?  // Capture activity for timer sheet
    @State private var iconIndex = 0
    @State private var iconTimer: Timer?

    private let cyclingIcons = [
        ("pause.fill", "Pause"),
        ("rectangle.and.pencil.and.ellipsis", "Record"),
        ("paperplane.fill", "Act"),
        ("brain.head.profile.fill", "Reflect"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    VStack(spacing: 12) {
                        Image(systemName: cyclingIcons[iconIndex].0)
                            .font(.system(size: 60))
                            .foregroundStyle(.indigo)
                            .frame(width: 80, height: 80)
                            .contentTransition(.symbolEffect(.replace))
                            .id(iconIndex)

                        Text(cyclingIcons[iconIndex].1)
                            .font(.title)
                            .fontWeight(.bold)
                            .contentTransition(.numericText())

                        Text("Track your daily activities and habits")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .onAppear {
                        guard iconTimer == nil else { return }
                        iconTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                            withAnimation(.easeInOut(duration: 0.6)) {
                                iconIndex = (iconIndex + 1) % cyclingIcons.count
                            }
                        }
                    }
                    .onDisappear {
                        iconTimer?.invalidate()
                        iconTimer = nil
                    }

                    Spacer()

                    VStack(spacing: 20) {
                        ActionButton(
                            icon: "timer",
                            title: "Log Activity",
                            subtitle: "Track time spent on activities",
                            color: .blue
                        ) { showActivitySheet = true }

                        ActionButton(
                            icon: "pill",
                            title: "Log Substance",
                            subtitle: "Record drug or alcohol use",
                            color: .purple
                        ) { showDrugSheet = true }

                        ActionButton(
                            icon: "heart.text.square",
                            title: "Log Biometric",
                            subtitle: "Enter health data",
                            color: .red
                        ) { showBiometricSheet = true }
                    }
                    .padding(.horizontal)

                    Spacer()

                    HStack(spacing: 20) {
                        NavigationButton(
                            icon: "list.bullet.clipboard",
                            title: "Past Logs",
                            action: { navigateToPastLogs = true }
                        )
                        NavigationButton(
                            icon: "target",
                            title: "Goals",
                            action: { navigateToGoals = true }
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

                // Toast overlay
                VStack {
                    if sheetManager.showToast {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text("Saved!")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .animation(.easeOut(duration: 0.3), value: sheetManager.showToast)
                .allowsHitTesting(false)
                
                // Floating timer button - top right corner
                if timerService.isRunning {
                    TimerPillView {
                        timerSheetActivity = timerService.currentActivity
                        showTimerSheet = true
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AccountView()) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToPastLogs) {
                PastLogsView()
            }
            .navigationDestination(isPresented: $navigateToGoals) {
                GoalsView()
            }
            .navigationDestination(isPresented: $navigateToDataDisplay) {
                DataDisplayView()
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivitySelectionView()
            }
            .sheet(isPresented: $showDrugSheet) {
                DrugLogView()
            }
            .sheet(isPresented: $showBiometricSheet) {
                BiometricEntryView()
            }
            .sheet(isPresented: $showTimerSheet) {
                if let activity = timerSheetActivity {
                    NavigationStack {
                        ActivityTimerView(activity: activity)
                    }
                }
            }
            .onChange(of: sheetManager.activeSheetToDismiss) { _, newValue in
                guard let which = newValue else { return }
                switch which {
                case .activity:
                    showActivitySheet = false
                    showTimerSheet = false  // Also close timer sheet if open
                case .substance:
                    showDrugSheet = false
                case .biometric:
                    showBiometricSheet = false
                }
                sheetManager.clearDismiss()
            }
        }
    }
}

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

struct TimerPillView: View {
    @ObservedObject private var timerService = TimerService.shared
    let onTap: () -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timerService.currentActivity?.categoryName ?? "Activity")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(timerService.formatTime(timerService.elapsedTime))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.gradient)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
            Spacer()
        }
    }
}

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

#Preview {
    HomeView()
}
