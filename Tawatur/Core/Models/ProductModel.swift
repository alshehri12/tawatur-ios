// ProductModel.swift — API response models for the products domain

import Foundation

// ── Product ───────────────────────────────────────────────────────────────────

struct Product: Decodable, Identifiable {
    let id: String
    let category: String
    let categoryDisplay: String
    let brand: String
    let model: String
    let condition: String
    let conditionDisplay: String
    let trustScore: Int
    let trustLevel: String
    let trustLevelDisplay: String
    let chainIntegrity: Int
    let totalOwners: Int
    let currentOwnerSince: Date?
    let registeredAt: Date

    // Owner-only fields (nil for non-owners)
    let imei1: String?
    let imei2: String?
    let serialNumber: String?
    let notes: String?
}

// ── Ownership history ─────────────────────────────────────────────────────────

struct OwnershipRecord: Decodable, Identifiable {
    let id: String
    let transferType: String
    let transferTypeDisplay: String
    let startDate: Date
    let endDate: Date?
    let isCurrent: Bool
    let ownerVerified: Bool
}

struct OwnershipHistory: Decodable {
    let totalOwners: Int
    let firstRecordedDate: Date?
    let latestTransferDate: Date?
    let chainIntegrity: Int
    let verifiedTransferCount: Int
    let trustScore: Int
    let trustLevel: String
    let trustLevelDisplay: String
    let timeline: [OwnershipRecord]
}

// ── Trust score breakdown ─────────────────────────────────────────────────────

struct TrustScoreDetail: Decodable {
    let trustScore: Int
    let trustLevel: String
    let trustLevelDisplay: String
    let chainIntegrity: Int
    let breakdown: TrustBreakdown
}

struct TrustBreakdown: Decodable {
    let baseScore: Int
    let verifiedTransfersBonus: Int
    let chainIntegrityBonus: Int
    let fraudAlertPenalty: Int
    let verifiedOwners: Int
    let activeFraudAlerts: Int
}

// ── Product lookup response ───────────────────────────────────────────────────

extension Product {
    var trustColor: Color {
        switch trustLevel {
        case "excellent": return .tSuccess
        case "high":      return .tSuccess.opacity(0.7)
        case "medium":    return .tWarning
        default:          return .tDanger
        }
    }

    var categoryIcon: String {
        switch category {
        case "smartphone":     return "iphone"
        case "tablet":         return "ipad"
        case "laptop":         return "laptopcomputer"
        case "smartwatch":     return "applewatch"
        case "gaming_console": return "gamecontroller"
        case "camera":         return "camera"
        default:               return "cube"
        }
    }
}

import SwiftUI
