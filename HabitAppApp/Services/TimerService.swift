//
//  TimerService.swift
//  HabitTracker
//

import Foundation
import Combine
import UserNotifications

class TimerService: ObservableObject {
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
        print("Timer started for: \(activity.categoryName)")
    }

    func pauseTimer() {
        guard isRunning, !isPaused else { return }

        pausedTime = Date()
        isPaused = true
        timer?.invalidate()
        timer = nil

        persistState()
        print("Timer paused at: \(formatTime(elapsedTime))")
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
        print("Timer resumed")
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
        print("Timer ended. Duration: \(formatTime(activity.duration))")
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
        print("Timer cancelled")
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
            print("Timer restored (paused) - elapsed: \(formatTime(elapsedTime))")
        } else {
            isPaused = false
            elapsedTime = Date().timeIntervalSince(Date(timeIntervalSince1970: savedStartTime)) + accumulatedTime
            startTimerLoop()
            print("Timer restored (running) - elapsed: \(formatTime(elapsedTime))")
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleBackgroundNotification() {
        guard let activity = currentActivity,
              let interval = notificationInterval else { return }

        let content = UNMutableNotificationContent()
        content.title = "Timer Running"
        content.body = "Your \(activity.categoryName) timer is still running"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "timer-running", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelBackgroundNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer-running"])
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
            print("Timer restarted after background - elapsed: \(formatTime(elapsedTime))")
        }
    }
}
