// CertificateModel.swift — API response models for the certificates domain

import Foundation

struct Certificate: Decodable, Identifiable {
    let id: String
    let certificateNumber: String
    let certificateType: String
    let certificateTypeDisplay: String
    let isValid: Bool
    let verificationUrl: String
    let qrCodeUrl: String
    let pdfUrl: String
    let productSummary: CertProductSummary
    let issuedAt: Date
}

struct CertProductSummary: Decodable {
    let id: String
    let brand: String
    let model: String
    let categoryDisplay: String
    let trustScore: Int
    let trustLevel: String
}

// ── Public verification response ──────────────────────────────────────────────

struct CertificateVerification: Decodable {
    let certificateNumber: String
    let certificateTypeDisplay: String
    let isValid: Bool
    let issuedAt: Date
    let product: VerifyProductInfo
    let verificationMessage: String
}

struct VerifyProductInfo: Decodable {
    let brand: String
    let model: String
    let categoryDisplay: String
    let trustScore: Int
    let trustLevelDisplay: String
    let chainIntegrity: Int
    let totalOwners: Int
}
