// TransactionModel.swift — API response models for the transactions domain

import Foundation

struct Transaction: Decodable, Identifiable {
    let id: String
    let transactionType: String
    let transactionTypeDisplay: String
    let status: String
    let statusDisplay: String
    let price: Double?
    let deviceCondition: String?
    let createdAt: Date
    let expiresAt: Date
    let approvedAt: Date?
    let productSummary: ProductSummary
    let isInitiator: Bool?
    let role: String?               // "buyer" | "seller"
    let counterpartyName: String?   // seller's name if I'm the buyer, buyer's name if I'm the seller

    // Detail-only fields
    let notes: String?
    let sellerTerms: String?
    let sellerFullName: String?
    let sellerIdNumber: String?
    let sellerMobile: String?
    let sellerCity: String?
    let certificateId: String?
    let certificatePdfUrl: String?
    let confirmUrl: String?
    let auditLogs: [AuditLogEntry]?
}

struct ProductSummary: Decodable {
    let id: String
    let brand: String
    let model: String
    let categoryDisplay: String
}

struct AuditLogEntry: Decodable, Identifiable {
    var id = UUID()
    let action: String
    let oldStatus: String
    let newStatus: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case action, oldStatus, newStatus, timestamp
    }
}

// ── Status helpers ────────────────────────────────────────────────────────────

extension Transaction {
    var isPending: Bool  { status == "pending" }
    var isApproved: Bool { status == "approved" }
    var isExpired: Bool  { status == "expired" }
    var isSellerRole: Bool { role == "seller" }
    var roleLabel: String { isSellerRole ? "بيع" : "شراء" }

    var statusColor: Color {
        switch status {
        case "approved":  return .tSuccess
        case "rejected":  return .tDanger
        case "cancelled": return .tSubtext
        case "expired":   return .tSubtext
        default:          return .tWarning
        }
    }
}

import SwiftUI
