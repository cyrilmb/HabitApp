//
//  TimerActivityAttributes.swift
//  HabitApp
//

import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timerStartDate: Date
        var isPaused: Bool
        var elapsedAtPause: TimeInterval
    }

    var activityName: String
}
