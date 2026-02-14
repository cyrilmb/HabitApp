//
//  AppCheckProviderFactory.swift
//  HabitTracker
//
//  App Check provider using App Attest with DeviceCheck fallback.
//
//  MANUAL STEP: In Xcode, add the "FirebaseAppCheck" product from the existing
//  firebase-ios-sdk SPM package to the HabitApp target. Then add the
//  "App Attest" capability. Until then, this file is conditionally compiled.
//

import FirebaseCore

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck

class HabitAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
    }
}
#endif
