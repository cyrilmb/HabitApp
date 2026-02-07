import SwiftUI
import FirebaseCore

@main
struct HabitTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            let timerService = TimerService.shared
            switch newPhase {
            case .background:
                if timerService.isRunning {
                    timerService.scheduleBackgroundNotification()
                }
            case .active:
                timerService.cancelBackgroundNotification()
                timerService.recalculateElapsedTime()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
