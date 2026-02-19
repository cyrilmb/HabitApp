//
//  DrugLog.swift
//  HabitApp
//
//  Data model for drug/substance consumption tracking
//

import Foundation
import FirebaseFirestore

struct DrugLog: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var categoryName: String // e.g., "Alcohol", "Cannabis"
    var method: String // e.g., "Beer", "Wine", "Shot", "Joint", "Vape"
    var dosage: Double? // Optional amount
    var dosageUnit: String? // e.g., "oz", "mg", "drinks"
    var timestamp: Date
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String, categoryName: String, method: String, dosage: Double? = nil, dosageUnit: String? = nil, timestamp: Date = Date()) {
        self.userId = userId
        self.categoryName = categoryName
        self.method = method
        self.dosage = dosage
        self.dosageUnit = dosageUnit
        self.timestamp = timestamp
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// Category for drug types with predefined methods
struct DrugCategory: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var name: String // e.g., "Alcohol", "Cannabis"
    var methods: [String] // e.g., ["Beer", "Wine", "Shot"]
    var defaultDosageUnit: String? // e.g., "drinks", "mg"
    var createdAt: Date
    
    init(userId: String, name: String, methods: [String], defaultDosageUnit: String? = nil) {
        self.userId = userId
        self.name = name
        self.methods = methods
        self.defaultDosageUnit = defaultDosageUnit
        self.createdAt = Date()
    }
    
}
