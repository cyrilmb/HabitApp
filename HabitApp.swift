import SwiftUI
import FirebaseCore

@main
struct HabitApp: App {
    
    // Initialize Firebase when app launches
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
