//
//  TimerService.swift
//  HabitTracker
//

import Foundation
import Combine
import UserNotifications
import UIKit
import ActivityKit

class TimerService: ObservableObject {
    // Typealias to avoid collision with app's Activity model
    private typealias LiveActivity = ActivityKit.Activity<TimerActivityAttributes>

    // Published properties that views can observe
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentActivity: Activity?

    private var timer: Timer?
    private var startTime: Date?
    private var pausedTime: Date?
    private var accumulatedTime: TimeInterval = 0
    /// Notification interval from the activity category (nil = notifications disabled)
    private(set) var notificationInterval: TimeInterval?
    private var liveActivity: LiveActivity?

    // MARK: - Persistence Keys

    private enum Keys {
        static let isRunning = "timer_isRunning"
        static let isPaused = "timer_isPaused"
        static let startTime = "timer_startTime"
        static let pausedTime = "timer_pausedTime"
        static let accumulatedTime = "timer_accumulatedTime"
        static let activityCategoryName = "timer_activityCategoryName"
        static let activityUserId = "timer_activityUserId"
        static let notificationInterval = "timer_notificationInterval"
    }

    // Singleton instance
    static let shared = TimerService()

    private init() {
        requestNotificationPermission()
        restoreState()
        reconnectLiveActivity()
    }

    // MARK: - Timer Controls

    func startTimer(for activity: Activity, notificationInterval: TimeInterval? = nil) {
        currentActivity = activity
        startTime = Date()
        accumulatedTime = 0
        elapsedTime = 0
        isRunning = true
        isPaused = false
        self.notificationInterval = notificationInterval

        persistState()
        startTimerLoop()
        updateBadge()
        startLiveActivity()
    }

    func pauseTimer() {
        guard isRunning, !isPaused else { return }

        pausedTime = Date()
        isPaused = true
        timer?.invalidate()
        timer = nil

        persistState()
        updateLiveActivityPaused()
    }

    func resumeTimer() {
        guard isRunning, isPaused else { return }

        if let pausedTime = pausedTime {
            let pauseDuration = Date().timeIntervalSince(pausedTime)
            startTime = startTime?.addingTimeInterval(pauseDuration)
        }

        isPaused = false
        pausedTime = nil

        persistState()
        startTimerLoop()
        updateLiveActivityResumed()
    }

    func endTimer() -> Activity? {
        guard var activity = currentActivity else { return nil }

        timer?.invalidate()
        timer = nil

        activity.duration = elapsedTime
        activity.endTime = Date()
        activity.isActive = false
        activity.updatedAt = Date()

        isRunning = false
        isPaused = false
        elapsedTime = 0
        accumulatedTime = 0
        startTime = nil
        currentActivity = nil
        notificationInterval = nil

        clearPersistedState()
        updateBadge()
        endLiveActivity()
        return activity
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil

        isRunning = false
        isPaused = false
        elapsedTime = 0
        accumulatedTime = 0
        startTime = nil
        currentActivity = nil
        notificationInterval = nil

        clearPersistedState()
        updateBadge()
        endLiveActivity()
    }

    // MARK: - Private Methods

    private func startTimerLoop() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }

        RunLoop.main.add(timer!, forMode: .common)
    }

    private func updateElapsedTime() {
        guard let startTime = startTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime) + accumulatedTime
    }

    // MARK: - State Persistence

    private func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(isRunning, forKey: Keys.isRunning)
        defaults.set(isPaused, forKey: Keys.isPaused)
        defaults.set(startTime?.timeIntervalSince1970, forKey: Keys.startTime)
        defaults.set(pausedTime?.timeIntervalSince1970, forKey: Keys.pausedTime)
        defaults.set(accumulatedTime, forKey: Keys.accumulatedTime)
        defaults.set(currentActivity?.categoryName, forKey: Keys.activityCategoryName)
        defaults.set(currentActivity?.userId, forKey: Keys.activityUserId)

        if let interval = notificationInterval {
            defaults.set(interval, forKey: Keys.notificationInterval)
        } else {
            defaults.removeObject(forKey: Keys.notificationInterval)
        }
    }

    private func clearPersistedState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.isRunning)
        defaults.removeObject(forKey: Keys.isPaused)
        defaults.removeObject(forKey: Keys.startTime)
        defaults.removeObject(forKey: Keys.pausedTime)
        defaults.removeObject(forKey: Keys.accumulatedTime)
        defaults.removeObject(forKey: Keys.activityCategoryName)
        defaults.removeObject(forKey: Keys.activityUserId)
        defaults.removeObject(forKey: Keys.notificationInterval)
    }

    private func restoreState() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Keys.isRunning) else { return }

        guard let categoryName = defaults.string(forKey: Keys.activityCategoryName),
              let userId = defaults.string(forKey: Keys.activityUserId) else {
            clearPersistedState()
            return
        }

        let savedStartTime = defaults.double(forKey: Keys.startTime)
        guard savedStartTime > 0 else {
            clearPersistedState()
            return
        }

        let restoredStart = Date(timeIntervalSince1970: savedStartTime)
        currentActivity = Activity(userId: userId, categoryName: categoryName, startTime: restoredStart)
        startTime = restoredStart
        accumulatedTime = defaults.double(forKey: Keys.accumulatedTime)
        isRunning = true

        let savedInterval = defaults.double(forKey: Keys.notificationInterval)
        notificationInterval = savedInterval > 0 ? savedInterval : nil

        let savedPaused = defaults.bool(forKey: Keys.isPaused)
        if savedPaused {
            let savedPausedTime = defaults.double(forKey: Keys.pausedTime)
            isPaused = true
            pausedTime = savedPausedTime > 0 ? Date(timeIntervalSince1970: savedPausedTime) : Date()
            // Recalculate elapsed up to the moment it was paused
            elapsedTime = (pausedTime ?? Date()).timeIntervalSince(Date(timeIntervalSince1970: savedStartTime)) + accumulatedTime
        } else {
            isPaused = false
            elapsedTime = Date().timeIntervalSince(Date(timeIntervalSince1970: savedStartTime)) + accumulatedTime
            startTimerLoop()
        }
    }
    
    // MARK: - Notifications & Badge

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleBackgroundNotification() {
        guard let activity = currentActivity else { return }
        let center = UNUserNotificationCenter.current()

        // Repeating reminder if the category has a notification interval
        if let interval = notificationInterval {
            let content = UNMutableNotificationContent()
            content.title = "Timer Running"
            content.body = "Your \(activity.categoryName) timer is still running"
            content.sound = .default
            content.badge = 1 as NSNumber

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
            center.add(UNNotificationRequest(identifier: "timer-running", content: content, trigger: trigger))
        }
    }

    func cancelBackgroundNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["timer-running"])
        center.removeDeliveredNotifications(withIdentifiers: ["timer-running"])
    }

    private func updateBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(self.isRunning ? 1 : 0)
        }
    }
    
    // MARK: - Live Activity

    private func startLiveActivity() {
        guard let startTime = startTime,
              let activityName = currentActivity?.categoryName else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TimerActivityAttributes(activityName: activityName)
        let state = TimerActivityAttributes.ContentState(
            timerStartDate: startTime,
            isPaused: false,
            elapsedAtPause: 0
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            liveActivity = try LiveActivity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    private func updateLiveActivityPaused() {
        guard let liveActivity else { return }
        let state = TimerActivityAttributes.ContentState(
            timerStartDate: startTime ?? Date(),
            isPaused: true,
            elapsedAtPause: elapsedTime
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await liveActivity.update(content)
        }
    }

    private func updateLiveActivityResumed() {
        guard let liveActivity, let startTime else { return }
        let state = TimerActivityAttributes.ContentState(
            timerStartDate: startTime,
            isPaused: false,
            elapsedAtPause: 0
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await liveActivity.update(content)
        }
    }

    private func endLiveActivity() {
        guard let liveActivity else { return }
        let state = TimerActivityAttributes.ContentState(
            timerStartDate: Date(),
            isPaused: true,
            elapsedAtPause: 0
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await liveActivity.end(content, dismissalPolicy: .immediate)
        }
        self.liveActivity = nil
    }

    /// Reconnect to an existing Live Activity after app relaunch, or clean up orphans
    private func reconnectLiveActivity() {
        let running = LiveActivity.activities
        if isRunning, let startTime {
            if let existing = running.first {
                liveActivity = existing
                // Update it to current state
                let state = TimerActivityAttributes.ContentState(
                    timerStartDate: startTime,
                    isPaused: isPaused,
                    elapsedAtPause: isPaused ? elapsedTime : 0
                )
                let content = ActivityContent(state: state, staleDate: nil)
                Task { await existing.update(content) }
            } else {
                startLiveActivity()
            }
        } else {
            // No timer running — end any orphaned activities
            for activity in running {
                let state = TimerActivityAttributes.ContentState(
                    timerStartDate: Date(),
                    isPaused: true,
                    elapsedAtPause: 0
                )
                let content = ActivityContent(state: state, staleDate: nil)
                Task { await activity.end(content, dismissalPolicy: .immediate) }
            }
        }
    }

    // MARK: - Helpers
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Background Recovery
    
    /// Called when app returns from background - recalculates correct time and restarts timer
    func recalculateElapsedTime() {
        guard isRunning, !isPaused, let startTime = startTime else { return }
        
        // Recalculate elapsed time from original start time
        elapsedTime = Date().timeIntervalSince(startTime) + accumulatedTime
        
        // Restart timer loop if iOS killed it
        if timer == nil {
            startTimerLoop()
        }
    }
}
