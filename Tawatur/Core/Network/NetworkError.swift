// NetworkError.swift — All API error cases

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case unauthorized          // 401 — token expired and refresh failed
    case noInternet            // device has no network
    case serverUnreachable     // host found but server not responding / DNS failed
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidURL:                        return "عنوان الطلب غير صالح."
        case .invalidResponse:                   return "استجابة غير صالحة من الخادم."
        case .httpError(_, let msg):             return msg
        case .decodingError(let d):              return "خطأ في تحليل البيانات: \(d)"
        case .unauthorized:                      return "انتهت جلستك. يرجى تسجيل الدخول مجدداً."
        case .noInternet:                        return "الرجاء الاتصال بالإنترنت"
        case .serverUnreachable:                 return "الرجاء الاتصال بالإنترنت"
        case .timedOut:                          return "الرجاء الاتصال بالإنترنت"
        }
    }
}

// ── Backend error shape ────────────────────────────────────────────────────────

struct APIError: Decodable {
    let detail: String?
    let nonFieldErrors: [String]?

    var message: String {
        detail ?? nonFieldErrors?.first ?? "حدث خطأ غير متوقع."
    }
}
