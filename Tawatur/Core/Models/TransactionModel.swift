// TransactionModel.swift — API response models for the transactions domain

import Foundation

struct Transaction: Decodable, Identifiable {
    let id: String
    let transactionType: String
    let transactionTypeDisplay: String
    let status: String
    let statusDisplay: String
    let price: Double?
    let createdAt: Date
    let expiresAt: Date
    let approvedAt: Date?
    let productSummary: ProductSummary
    let isInitiator: Bool?

    // Detail-only fields
    let notes: String?
    let linkToken: String?
    let shareLink: String?
    let initiatorInfo: PartyInfo?
    let recipientInfo: PartyInfo?
    let auditLogs: [AuditLogEntry]?
}

struct ProductSummary: Decodable {
    let id: String
    let brand: String
    let model: String
    let categoryDisplay: String
}

struct PartyInfo: Decodable {
    let userType: String
    let verificationStatus: String
    let businessName: String?
}

struct AuditLogEntry: Decodable, Identifiable {
    var id = UUID()       // local only — not from API
    let action: String
    let oldStatus: String
    let newStatus: String
    let timestamp: Date

    // Custom decoding because `id` is generated locally
    enum CodingKeys: String, CodingKey {
        case action, oldStatus, newStatus, timestamp
    }
}

// ── Resolve link response (public endpoint) ───────────────────────────────────

struct TransactionLinkInfo: Decodable {
    let transactionId: String
    let status: String
    let product: LinkProductInfo
    let transactionTypeDisplay: String
    let price: Double?
    let expiresAt: Date
    let requiresAuth: Bool
}

struct LinkProductInfo: Decodable {
    let brand: String
    let model: String
    let categoryDisplay: String
    let trustScore: Int
    let trustLevel: String
}

// ── Status helpers ────────────────────────────────────────────────────────────

extension Transaction {
    var isPending: Bool  { status == "pending" }
    var isApproved: Bool { status == "approved" }
    var isExpired: Bool  { status == "expired" }

    var statusColor: Color {
        switch status {
        case "approved":  return .tSuccess
        case "rejected":  return .tDanger
        case "cancelled": return .tSubtext
        case "expired":   return .tSubtext
        default:          return .tWarning   // pending
        }
    }
}

import SwiftUI
