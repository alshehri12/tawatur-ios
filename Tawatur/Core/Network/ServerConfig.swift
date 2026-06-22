import Foundation

final class ServerConfig {

    static let shared = ServerConfig()
    private init() {}

    private let udKey = "tawatur_dev_server_ip"
    private let defaultIP = "192.168.100.9"

    var serverIP: String {
        get { UserDefaults.standard.string(forKey: udKey) ?? defaultIP }
        set {
            let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            UserDefaults.standard.set(cleaned, forKey: udKey)
        }
    }

    var baseURL: URL {
        URL(string: "http://\(serverIP):8000/api/v1/")!
    }
}
