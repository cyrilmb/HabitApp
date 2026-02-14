import SwiftUI
import FirebaseCore

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

@main
struct HabitTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if canImport(FirebaseAppCheck)
        AppCheck.setAppCheckProviderFactory(HabitAppCheckProviderFactory())
        #endif
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
