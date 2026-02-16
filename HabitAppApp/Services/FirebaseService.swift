//
//  FirebaseService.swift
//  HabitTracker
//
//  Central service for all Firebase operations
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    // MARK: - In-Memory Cache (thread-safe)

    private struct CacheEntry {
        let data: Any
        let timestamp: Date
        var isValid: Bool { Date().timeIntervalSince(timestamp) < 60 }
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheLock = NSLock()

    private func cacheKey(_ collection: String, type: String? = nil, since: Date? = nil, limit: Int? = nil) -> String {
        var key = collection
        if let type = type { key += "_type:\(type)" }
        if let since = since { key += "_since:\(Int(since.timeIntervalSince1970))" }
        if let limit = limit { key += "_limit:\(limit)" }
        return key
    }

    private func getCachedValue(for key: String) -> CacheEntry? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[key]
    }

    private func setCachedValue(_ entry: CacheEntry, for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[key] = entry
        // Evict stale entries to prevent unbounded growth
        if cache.count > 50 {
            cache = cache.filter { $0.value.isValid }
        }
    }

    private func invalidateCache(for collection: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache = cache.filter { !$0.key.hasPrefix(collection) }
    }

    private init() {
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isAuthenticated = user != nil
        }
    }
    
    // MARK: - Authentication
    
    func signInAnonymously() async throws {
        let result = try await auth.signInAnonymously()
        print("User signed in anonymously: \(result.user.uid)")
    }
    
    func signOut() throws {
        try auth.signOut()
    }

    var isAnonymous: Bool {
        currentUser?.isAnonymous ?? true
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        try await auth.signIn(with: credential)
    }

    func linkAppleAccount(idToken: String, nonce: String) async throws {
        guard let user = auth.currentUser else { return }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        try await user.link(with: credential)
    }

    func deleteAccount() async throws {
        guard let user = auth.currentUser else { return }
        try await user.delete()
    }
    
    var userId: String {
        guard let uid = currentUser?.uid, !uid.isEmpty else {
            preconditionFailure("FirebaseService.userId accessed before authentication")
        }
        return uid
    }

    /// Safe check before performing operations that need auth
    var isReady: Bool {
        currentUser?.uid != nil
    }
    
    // MARK: - Activity Operations
    
    func saveActivity(_ activity: Activity) async throws {
        let activityRef = db.collection("users").document(userId).collection("activities")

        if let id = activity.id {
            try activityRef.document(id).setData(from: activity, merge: true)
        } else {
            _ = try activityRef.addDocument(from: activity)
        }
        invalidateCache(for: "activities")
    }
    
    func fetchActivities(since: Date? = nil, limit: Int? = nil) async throws -> [Activity] {
        let key = cacheKey("activities", since: since, limit: limit)
        if let entry = getCachedValue(for: key), entry.isValid, let data = entry.data as? [Activity] {
            return data
        }

        var query: Query = db.collection("users")
            .document(userId)
            .collection("activities")

        if let since = since {
            query = query.whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: since))
        }

        query = query.order(by: "startTime", descending: true)

        if let limit = limit {
            query = query.limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        let results = snapshot.documents.compactMap { try? $0.data(as: Activity.self) }
        setCachedValue(CacheEntry(data: results, timestamp: Date()), for: key)
        return results
    }
    
    /// Fetch activities older than `before` (cursor-based pagination).
    func fetchActivities(before: Date, limit: Int) async throws -> [Activity] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("startTime", isLessThan: Timestamp(date: before))
            .order(by: "startTime", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Activity.self) }
    }

    func deleteActivity(_ activity: Activity) async throws {
        guard let id = activity.id else { return }
        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(id)
            .delete()
        invalidateCache(for: "activities")
    }
    
    // MARK: - Activity Category Operations
    
    func saveActivityCategory(_ category: ActivityCategory) async throws {
        let categoryRef = db.collection("users").document(userId).collection("activityCategories")

        if let id = category.id {
            try categoryRef.document(id).setData(from: category, merge: true)
        } else {
            _ = try categoryRef.addDocument(from: category)
        }
        invalidateCache(for: "activityCategories")
    }

    func fetchActivityCategories() async throws -> [ActivityCategory] {
        let key = cacheKey("activityCategories")
        if let entry = getCachedValue(for: key), entry.isValid, let data = entry.data as? [ActivityCategory] {
            return data
        }

        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("activityCategories")
            .order(by: "name")
            .getDocuments()

        let results = snapshot.documents.compactMap { document in
            try? document.data(as: ActivityCategory.self)
        }
        setCachedValue(CacheEntry(data: results, timestamp: Date()), for: key)
        return results
    }
    
    // MARK: - Drug Log Operations
    
    func saveDrugLog(_ log: DrugLog) async throws {
        let logRef = db.collection("users").document(userId).collection("drugLogs")

        if let id = log.id {
            try logRef.document(id).setData(from: log, merge: true)
        } else {
            _ = try logRef.addDocument(from: log)
        }
        invalidateCache(for: "drugLogs")
    }
    
    func fetchDrugLogs(since: Date? = nil, limit: Int? = nil) async throws -> [DrugLog] {
        let key = cacheKey("drugLogs", since: since, limit: limit)
        if let entry = getCachedValue(for: key), entry.isValid, let data = entry.data as? [DrugLog] {
            return data
        }

        var query: Query = db.collection("users")
            .document(userId)
            .collection("drugLogs")

        if let since = since {
            query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: since))
        }

        query = query.order(by: "timestamp", descending: true)

        if let limit = limit {
            query = query.limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        let results = snapshot.documents.compactMap { try? $0.data(as: DrugLog.self) }
        setCachedValue(CacheEntry(data: results, timestamp: Date()), for: key)
        return results
    }
    
    /// Fetch drug logs older than `before` (cursor-based pagination).
    func fetchDrugLogs(before: Date, limit: Int) async throws -> [DrugLog] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("drugLogs")
            .whereField("timestamp", isLessThan: Timestamp(date: before))
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: DrugLog.self) }
    }

    func deleteDrugLog(_ log: DrugLog) async throws {
        guard let id = log.id else { return }
        try await db.collection("users")
            .document(userId)
            .collection("drugLogs")
            .document(id)
            .delete()
        invalidateCache(for: "drugLogs")
    }
    
    // MARK: - Drug Category Operations
    
    func saveDrugCategory(_ category: DrugCategory) async throws {
        let categoryRef = db.collection("users").document(userId).collection("drugCategories")

        if let id = category.id {
            try categoryRef.document(id).setData(from: category, merge: true)
        } else {
            _ = try categoryRef.addDocument(from: category)
        }
        invalidateCache(for: "drugCategories")
    }

    func fetchDrugCategories() async throws -> [DrugCategory] {
        let key = cacheKey("drugCategories")
        if let entry = getCachedValue(for: key), entry.isValid, let data = entry.data as? [DrugCategory] {
            return data
        }

        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("drugCategories")
            .order(by: "name")
            .getDocuments()

        let results = snapshot.documents.compactMap { document in
            try? document.data(as: DrugCategory.self)
        }
        setCachedValue(CacheEntry(data: results, timestamp: Date()), for: key)
        return results
    }

    func deleteDrugCategory(_ categoryId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("drugCategories")
            .document(categoryId)
            .delete()
    }

    // MARK: - Biometric Operations
    
    func saveBiometric(_ biometric: Biometric) async throws {
        let biometricRef = db.collection("users").document(userId).collection("biometrics")

        if let id = biometric.id {
            try biometricRef.document(id).setData(from: biometric, merge: true)
        } else {
            _ = try biometricRef.addDocument(from: biometric)
        }
        invalidateCache(for: "biometrics")
    }
    
    func fetchBiometrics(type: BiometricType? = nil, since: Date? = nil, limit: Int? = nil) async throws -> [Biometric] {
        let key = cacheKey("biometrics", type: type?.rawValue, since: since, limit: limit)
        if let entry = getCachedValue(for: key), entry.isValid, let data = entry.data as? [Biometric] {
            return data
        }

        var query: Query = db.collection("users")
            .document(userId)
            .collection("biometrics")

        if let type = type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }

        if let since = since {
            query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: since))
        }

        query = query.order(by: "timestamp", descending: true)

        if let limit = limit {
            query = query.limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        let results = snapshot.documents.compactMap { try? $0.data(as: Biometric.self) }
        setCachedValue(CacheEntry(data: results, timestamp: Date()), for: key)
        return results
    }
    
    /// Fetch biometrics older than `before` (cursor-based pagination).
    func fetchBiometrics(before: Date, limit: Int) async throws -> [Biometric] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("biometrics")
            .whereField("timestamp", isLessThan: Timestamp(date: before))
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Biometric.self) }
    }

    func deleteBiometric(_ biometric: Biometric) async throws {
        guard let id = biometric.id else { return }
        try await db.collection("users")
            .document(userId)
            .collection("biometrics")
            .document(id)
            .delete()
        invalidateCache(for: "biometrics")
    }
    
    // MARK: - Biometric Type Preferences

    func fetchBiometricTypePreferences() async throws -> [BiometricType] {
        let docRef = db.collection("users").document(userId)
            .collection("preferences").document("biometricTypes")

        let snapshot = try await docRef.getDocument()

        guard let data = snapshot.data(),
              let rawValues = data["enabledTypes"] as? [String] else {
            return Array(BiometricType.allCases)
        }

        let types = rawValues.compactMap { BiometricType(rawValue: $0) }
        return types.isEmpty ? Array(BiometricType.allCases) : types
    }

    func saveBiometricTypePreferences(_ types: [BiometricType]) async throws {
        let docRef = db.collection("users").document(userId)
            .collection("preferences").document("biometricTypes")

        try await docRef.setData([
            "enabledTypes": types.map { $0.rawValue }
        ])
    }

    // MARK: - Activity Category Management
    
    func deleteActivityCategory(_ categoryId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("activityCategories")
            .document(categoryId)
            .delete()
    }
    
    // MARK: - Goal Operations

    func saveGoal(_ goal: Goal) async throws {
        let goalRef = db.collection("users").document(userId).collection("goals")

        if let id = goal.id {
            try goalRef.document(id).setData(from: goal, merge: true)
        } else {
            _ = try goalRef.addDocument(from: goal)
        }
        invalidateCache(for: "goals")
    }

    func fetchGoals(for categoryType: GoalCategoryType? = nil) async throws -> [Goal] {
        let key = cacheKey("goals", type: categoryType?.rawValue)
        if let entry = getCachedValue(for: key), entry.isValid, let data = entry.data as? [Goal] {
            return data
        }

        var query: Query = db.collection("users")
            .document(userId)
            .collection("goals")

        if let categoryType = categoryType {
            query = query.whereField("categoryType", isEqualTo: categoryType.rawValue)
        }

        let snapshot = try await query.getDocuments()
        let results = snapshot.documents.compactMap { try? $0.data(as: Goal.self) }
        setCachedValue(CacheEntry(data: results, timestamp: Date()), for: key)
        return results
    }

    func deleteGoal(_ goalId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("goals")
            .document(goalId)
            .delete()
        invalidateCache(for: "goals")
    }

    // MARK: - Activity Category Management

    func deleteActivitiesByCategory(_ categoryName: String) async throws {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("categoryName", isEqualTo: categoryName)
            .getDocuments()

        // Use batched writes (max 500 per batch) instead of sequential deletes
        let batchSize = 500
        for chunk in stride(from: 0, to: snapshot.documents.count, by: batchSize) {
            let batch = db.batch()
            let end = min(chunk + batchSize, snapshot.documents.count)
            for i in chunk..<end {
                batch.deleteDocument(snapshot.documents[i].reference)
            }
            try await batch.commit()
        }
        invalidateCache(for: "activities")
    }
}
