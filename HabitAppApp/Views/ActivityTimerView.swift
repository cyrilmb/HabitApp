//
//  ActivityTimerView.swift
//  HabitTracker
//
//  Timer screen with start, pause, resume, and end controls
//

import SwiftUI

struct ActivityTimerView: View {
    let activity: Activity
    var notificationInterval: TimeInterval? = nil

    @ObservedObject private var timerService = TimerService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var completedActivity: Activity?
    @State private var showCancelAlert = false
    @State private var activityWasSaved = false  // Track if completion saved successfully
    @State private var activityWasDiscarded = false  // Track if completion was discarded
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Activity name
                VStack(spacing: 8) {
                    Text(activity.categoryName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(timerService.isPaused ? "Paused" : timerService.isRunning ? "In Progress" : "Ready to Start")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Timer display
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 280, height: 280)
                    
                    Circle()
                        .trim(from: 0, to: timerService.isRunning ? 1 : 0)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 280, height: 280)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: timerService.isRunning)
                    
                    VStack(spacing: 8) {
                        Text(timerService.formatTime(timerService.elapsedTime))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        
                        if timerService.isRunning {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(timerService.isPaused ? Color.orange : Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Text(timerService.isPaused ? "Paused" : "Running")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Control buttons
                VStack(spacing: 16) {
                    if !timerService.isRunning {
                        // Start button
                        Button(action: startTimer) {
                            Text("Start")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.green.gradient)
                                .cornerRadius(16)
                        }
                    } else if timerService.isPaused {
                        // Resume and End buttons
                        HStack(spacing: 16) {
                            Button(action: resumeTimer) {
                                Label("Resume", systemImage: "play.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(Color.green.gradient)
                                    .cornerRadius(16)
                            }
                            
                            Button(action: endTimer) {
                                Label("End", systemImage: "checkmark")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(Color.blue.gradient)
                                    .cornerRadius(16)
                            }
                        }
                    } else {
                        // Pause and End buttons
                        HStack(spacing: 16) {
                            Button(action: pauseTimer) {
                                Label("Pause", systemImage: "pause.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(Color.orange.gradient)
                                    .cornerRadius(16)
                            }
                            
                            Button(action: endTimer) {
                                Label("End", systemImage: "checkmark")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(Color.blue.gradient)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    
                    // Cancel button
                    Button(action: { showCancelAlert = true }) {
                        Text("Cancel Activity")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(timerService.isRunning)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if timerService.isRunning {
                    Button("Cancel") {
                        showCancelAlert = true
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Cancel Activity?", isPresented: $showCancelAlert) {
            Button("Continue Timer", role: .cancel) { }
            Button("Discard", role: .destructive) {
                cancelTimer()
            }
        } message: {
            Text("Are you sure you want to discard this activity?")
        }
        .sheet(item: $completedActivity) { activity in
            NavigationStack {
                ActivityCompletionView(
                    activity: activity,
                    onSaved: {
                        print("🟢 onSaved callback fired - setting activityWasSaved = true")
                        activityWasSaved = true
                    },
                    onDiscarded: {
                        print("🟠 onDiscarded callback fired - setting activityWasDiscarded = true")
                        activityWasDiscarded = true
                    }
                )
                .interactiveDismissDisabled(true)  // Prevent accidental swipe-down
                .onAppear {
                    print("🟡 ActivityCompletionView appeared")
                }
                .onDisappear {
                    print("🔴 ActivityCompletionView disappeared - saved: \(activityWasSaved), discarded: \(activityWasDiscarded)")
                    
                    // Close timer and show appropriate UI
                    if activityWasSaved {
                        print("✅ Completion closed after save - dismissing timer and showing toast")
                        dismiss()  // Close timer sheet
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            SheetManager.shared.showToastOnly()
                        }
                        activityWasSaved = false
                    } else if activityWasDiscarded {
                        print("🗑️ Completion closed after discard - dismissing timer, no toast")
                        dismiss()  // Close timer sheet
                        activityWasDiscarded = false
                    }
                }
            }
        }
        // Scene phase handling is done at app level in HabitTrackerApp
    }
    
    // MARK: - Timer Controls
    
    private func startTimer() {
        timerService.startTimer(for: activity, notificationInterval: notificationInterval)
    }
    
    private func pauseTimer() {
        timerService.pauseTimer()
    }
    
    private func resumeTimer() {
        timerService.resumeTimer()
    }
    
    private func endTimer() {
        print("🔵 endTimer called")
        if let completed = timerService.endTimer() {
            print("🔵 Got completed activity: \(completed.categoryName), id: \(completed.id ?? "nil")")
            completedActivity = completed
            print("🔵 Set completedActivity - should trigger sheet")
        } else {
            print("🔵 ❌ timerService.endTimer() returned nil!")
        }
    }
    
    private func cancelTimer() {
        timerService.cancelTimer()
        dismiss()
    }
    
}

#Preview {
    NavigationStack {
        ActivityTimerView(activity: Activity(userId: "preview", categoryName: "Exercise"))
    }
}
