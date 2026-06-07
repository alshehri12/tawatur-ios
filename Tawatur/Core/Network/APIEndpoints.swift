// APIEndpoints.swift — Every backend endpoint defined in one place.
// Views and ViewModels call APIClient.shared.request(.someEndpoint) — never build URLs elsewhere.

import Foundation

enum HTTPMethod: String {
    case GET, POST, PATCH, DELETE
}

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: [String: Any?]?
    let requiresAuth: Bool

    init(_ path: String,
         method: HTTPMethod = .GET,
         body: [String: Any?]? = nil,
         requiresAuth: Bool = true) {
        self.path = path
        self.method = method
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

// ── Auth ──────────────────────────────────────────────────────────────────────

extension APIEndpoint {
    static func requestOTP(phone: String, purpose: String) -> APIEndpoint {
        .init("auth/request-otp/", method: .POST,
              body: ["phone_number": phone, "purpose": purpose],
              requiresAuth: false)
    }

    static func login(phone: String, otp: String) -> APIEndpoint {
        .init("auth/login/", method: .POST,
              body: ["phone_number": phone, "otp": otp, "purpose": "login"],
              requiresAuth: false)
    }

    static func registerIndividual(phone: String, otp: String,
                                   nationalId: String?, iqama: String?) -> APIEndpoint {
        .init("auth/register/individual/", method: .POST,
              body: ["phone_number": phone, "otp": otp,
                     "national_id": nationalId, "iqama": iqama],
              requiresAuth: false)
    }

    static func registerBusiness(phone: String, otp: String,
                                  crNumber: String, businessName: String) -> APIEndpoint {
        .init("auth/register/business/", method: .POST,
              body: ["phone_number": phone, "otp": otp,
                     "cr_number": crNumber, "business_name": businessName],
              requiresAuth: false)
    }

    static var me: APIEndpoint        { .init("auth/me/") }
    static var tokenRefresh: APIEndpoint { .init("auth/token/refresh/", method: .POST, requiresAuth: false) }

    static func logout(refresh: String) -> APIEndpoint {
        .init("auth/logout/", method: .POST, body: ["refresh": refresh])
    }

    static func verifyIndividual(nationalId: String?, iqama: String?) -> APIEndpoint {
        .init("auth/verify/individual/", method: .POST,
              body: ["national_id": nationalId, "iqama": iqama])
    }

    static func verifyBusiness(crNumber: String, businessName: String) -> APIEndpoint {
        .init("auth/verify/business/", method: .POST,
              body: ["cr_number": crNumber, "business_name": businessName])
    }
}

// ── Products ──────────────────────────────────────────────────────────────────

extension APIEndpoint {
    static var myProducts: APIEndpoint { .init("products/my/") }

    static func productDetail(id: String) -> APIEndpoint { .init("products/\(id)/") }

    static func ownershipHistory(id: String) -> APIEndpoint {
        .init("products/\(id)/ownership-history/")
    }

    static func trustScore(id: String) -> APIEndpoint {
        .init("products/\(id)/trust-score/")
    }

    static func productLookup(imei: String? = nil, serial: String? = nil) -> APIEndpoint {
        var params = ""
        if let i = imei    { params = "?imei=\(i)" }
        if let s = serial  { params = "?serial=\(s)" }
        return .init("products/lookup/\(params)")
    }

    static func createProduct(category: String, brand: String, model: String,
                               condition: String, imei1: String?, imei2: String?,
                               serial: String?, notes: String?) -> APIEndpoint {
        .init("products/", method: .POST,
              body: ["category": category, "brand": brand, "model": model,
                     "condition": condition, "imei_1": imei1, "imei_2": imei2,
                     "serial_number": serial, "notes": notes])
    }
}

// ── Transactions ──────────────────────────────────────────────────────────────

extension APIEndpoint {
    static var myTransactions: APIEndpoint { .init("transactions/my/") }

    static func transactionDetail(id: String) -> APIEndpoint {
        .init("transactions/\(id)/")
    }

    static func resolveLink(token: String) -> APIEndpoint {
        .init("transactions/link/\(token)/", requiresAuth: false)
    }

    static func createTransaction(productId: String, recipientPhone: String,
                                   type: String, price: Double?, notes: String?) -> APIEndpoint {
        .init("transactions/", method: .POST,
              body: ["product_id": productId, "recipient_phone": recipientPhone,
                     "transaction_type": type, "price": price, "notes": notes])
    }

    static func approveTransaction(id: String) -> APIEndpoint {
        .init("transactions/\(id)/approve/", method: .POST)
    }

    static func rejectTransaction(id: String) -> APIEndpoint {
        .init("transactions/\(id)/reject/", method: .POST)
    }

    static func cancelTransaction(id: String) -> APIEndpoint {
        .init("transactions/\(id)/cancel/", method: .POST)
    }
}

// ── Certificates ──────────────────────────────────────────────────────────────

extension APIEndpoint {
    static var myCertificates: APIEndpoint { .init("certificates/") }

    static func certificateDetail(id: String) -> APIEndpoint {
        .init("certificates/\(id)/")
    }

    static func generateCertificate(productId: String) -> APIEndpoint {
        .init("certificates/generate/", method: .POST, body: ["product_id": productId])
    }

    static func verifyCertificate(number: String) -> APIEndpoint {
        .init("verify/\(number)/", requiresAuth: false)
    }
}
