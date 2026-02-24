import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UserNotifications

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

        let settings = Firestore.firestore().settings
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
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
                    UNUserNotificationCenter.current().setBadgeCount(1)
                }
            case .active:
                timerService.cancelBackgroundNotification()
                timerService.recalculateElapsedTime()
                // Clear badge when user returns to the app
                if !timerService.isRunning {
                    UNUserNotificationCenter.current().setBadgeCount(0)
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
