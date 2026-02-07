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

    // MARK: - In-Memory Cache

    private struct CacheEntry {
        let data: Any
        let timestamp: Date
        var isValid: Bool { Date().timeIntervalSince(timestamp) < 60 }
    }

    private var cache: [String: CacheEntry] = [:]

    private func cacheKey(_ collection: String, type: String? = nil, since: Date? = nil, limit: Int? = nil) -> String {
        var key = collection
        if let type = type { key += "_type:\(type)" }
        if let since = since { key += "_since:\(Int(since.timeIntervalSince1970))" }
        if let limit = limit { key += "_limit:\(limit)" }
        return key
    }

    private func invalidateCache(for collection: String) {
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
    
    var userId: String {
        return currentUser?.uid ?? ""
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
        if let entry = cache[key], entry.isValid, let data = entry.data as? [Activity] {
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
        cache[key] = CacheEntry(data: results, timestamp: Date())
        return results
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
    }
    
    func fetchActivityCategories() async throws -> [ActivityCategory] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("activityCategories")
            .order(by: "name")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: ActivityCategory.self)
        }
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
        if let entry = cache[key], entry.isValid, let data = entry.data as? [DrugLog] {
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
        cache[key] = CacheEntry(data: results, timestamp: Date())
        return results
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
    }
    
    func fetchDrugCategories() async throws -> [DrugCategory] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("drugCategories")
            .order(by: "name")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: DrugCategory.self)
        }
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
        if let entry = cache[key], entry.isValid, let data = entry.data as? [Biometric] {
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
        cache[key] = CacheEntry(data: results, timestamp: Date())
        return results
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
    
    // MARK: - Activity Category Management
    
    func deleteActivityCategory(_ categoryId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("activityCategories")
            .document(categoryId)
            .delete()
    }
    
    func deleteActivitiesByCategory(_ categoryName: String) async throws {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("categoryName", isEqualTo: categoryName)
            .getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }
}
