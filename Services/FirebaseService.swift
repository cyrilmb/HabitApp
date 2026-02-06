//
//  FirebaseService.swift
//  HabitTracker
//
//  Central service for all Firebase operations
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
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
            // Update existing activity
            try activityRef.document(id).setData(from: activity, merge: true)
        } else {
            // Create new activity
            _ = try activityRef.addDocument(from: activity)
        }
    }
    
    func fetchActivities() async throws -> [Activity] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("activities")
            .order(by: "startTime", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: Activity.self)
        }
    }
    
    func deleteActivity(_ activity: Activity) async throws {
        guard let id = activity.id else { return }
        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(id)
            .delete()
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
    }
    
    func fetchDrugLogs() async throws -> [DrugLog] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("drugLogs")
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: DrugLog.self)
        }
    }
    
    func deleteDrugLog(_ log: DrugLog) async throws {
        guard let id = log.id else { return }
        try await db.collection("users")
            .document(userId)
            .collection("drugLogs")
            .document(id)
            .delete()
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
    }
    
    func fetchBiometrics(type: BiometricType? = nil) async throws -> [Biometric] {
        var query: Query = db.collection("users")
            .document(userId)
            .collection("biometrics")
        
        if let type = type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }
        
        let snapshot = try await query
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: Biometric.self)
        }
    }
    
    func deleteBiometric(_ biometric: Biometric) async throws {
        guard let id = biometric.id else { return }
        try await db.collection("users")
            .document(userId)
            .collection("biometrics")
            .document(id)
            .delete()
    }
}
