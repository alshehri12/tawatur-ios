// TokenManager.swift — Secure JWT token storage using the iOS Keychain.
// Only this class reads/writes tokens — nothing else should touch raw token strings.

import Foundation
import Security

final class TokenManager {

    static let shared = TokenManager()
    private init() {}

    private let accessKey  = "sa.tawatur.access_token"
    private let refreshKey = "sa.tawatur.refresh_token"

    // ── Read ──────────────────────────────────────────────────────────────────
    var accessToken: String?  { Keychain.get(accessKey) }
    var refreshToken: String? { Keychain.get(refreshKey) }

    // ── Write ─────────────────────────────────────────────────────────────────
    func save(access: String, refresh: String) {
        Keychain.set(access,  forKey: accessKey)
        Keychain.set(refresh, forKey: refreshKey)
    }

    func updateAccess(_ token: String) {
        Keychain.set(token, forKey: accessKey)
    }

    // ── Delete (on logout) ────────────────────────────────────────────────────
    func clear() {
        Keychain.delete(accessKey)
        Keychain.delete(refreshKey)
    }
}

// ── Keychain wrapper ──────────────────────────────────────────────────────────

private enum Keychain {

    static func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData   as String: data,
        ]
        SecItemDelete(query as CFDictionary)           // Remove existing before adding
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData  as String: kCFBooleanTrue!,
            kSecMatchLimit  as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
