// UserModel.swift — API response models for the accounts domain

import Foundation

// ── User profile (returned by /auth/me/ and login/register endpoints) ─────────

struct UserProfile: Decodable, Identifiable {
    let id: String
    let userType: String               // "individual" | "business"
    let identitySubmitted: Bool
    let absherVerified: Bool
    let businessName: String?
    let crSubmitted: Bool
    let wathiqVerified: Bool
    let verificationStatus: String     // "unverified" | "pending" | "verified"
    let canTransact: Bool
    let dateJoined: Date
}

// ── Auth response (login + register return this) ──────────────────────────────

struct AuthResponse: Decodable {
    let access: String
    let refresh: String
    let user: UserProfile
    let detail: String?
}

// ── OTP response ──────────────────────────────────────────────────────────────

struct OTPResponse: Decodable {
    let detail: String
    let otp: String?          // Only present in DEBUG mode on the backend
}

// ── Verification status helper ────────────────────────────────────────────────

extension UserProfile {
    var isIndividual: Bool { userType == "individual" }
    var isBusiness: Bool   { userType == "business" }

    var verificationBadge: String {
        switch verificationStatus {
        case "verified": return "موثق ✓"
        case "pending":  return "قيد المراجعة"
        default:         return "غير موثق"
        }
    }

    var userTypeLabel: String {
        isIndividual ? "فرد" : "جهة تجارية"
    }
}
