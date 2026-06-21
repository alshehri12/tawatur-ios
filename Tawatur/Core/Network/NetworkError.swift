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
        case .invalidURL:        return "عنوان الطلب غير صالح."
        case .invalidResponse:   return "استجابة غير صالحة من الخادم."
        case .httpError(_, let msg): return msg
        case .decodingError(let d):  return "خطأ في تحليل البيانات: \(d)"
        case .unauthorized:      return "انتهت جلستك. يرجى تسجيل الدخول مجدداً."
        case .noInternet:        return "لا يوجد اتصال بالشبكة. تأكد من تفعيل الواي فاي."
        case .serverUnreachable: return "الخدمة غير متاحة حالياً. حاول مجدداً بعد قليل."
        case .timedOut:          return "انتهت مهلة الاتصال. تأكد من اتصالك بالشبكة وحاول مجدداً."
        }
    }
}

// ── Backend error shape ────────────────────────────────────────────────────────
// Handles all DRF error formats:
//   {"detail": "..."}                   → permission / auth errors
//   {"non_field_errors": ["..."]}        → cross-field validation errors
//   {"imei_1": ["..."], "brand": ["..."]} → per-field validation errors

struct APIError: Decodable {
    let detail: String?
    let nonFieldErrors: [String]?
    private let firstFieldError: String?

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)

        detail = try? c.decodeIfPresent(String.self, forKey: AnyKey(stringValue: "detail")!)

        // Accept both snake_case (raw JSON) and camelCase (convertFromSnakeCase decoder)
        nonFieldErrors =
            (try? c.decodeIfPresent([String].self, forKey: AnyKey(stringValue: "non_field_errors")!)) ??
            (try? c.decodeIfPresent([String].self, forKey: AnyKey(stringValue: "nonFieldErrors")!))

        // Grab the first message from any field-level error key
        var first: String?
        for key in c.allKeys {
            let k = key.stringValue
            guard k != "detail" && k != "non_field_errors" && k != "nonFieldErrors" else { continue }
            if let msgs = try? c.decode([String].self, forKey: key), let msg = msgs.first {
                first = msg; break
            } else if let msg = try? c.decode(String.self, forKey: key) {
                first = msg; break
            }
        }
        firstFieldError = first
    }

    var message: String {
        detail ?? nonFieldErrors?.first ?? firstFieldError ?? "حدث خطأ غير متوقع."
    }
}
