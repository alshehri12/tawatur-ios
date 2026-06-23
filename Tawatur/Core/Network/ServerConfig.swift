import Foundation

final class ServerConfig {

    static let shared = ServerConfig()
    private init() {}

    private let udKey = "tawatur_server_host"
    // Points to the ngrok public URL — works over WiFi and cellular for TestFlight.
    private let defaultHost = "https://giggle-subsonic-reliant.ngrok-free.dev"

    /// Stored value is either:
    ///   - A plain LAN IP:   "192.168.100.9"           → http://IP:8000/api/v1/
    ///   - A full URL:       "https://xxx.ngrok-free.app" → https://xxx.ngrok-free.app/api/v1/
    var serverHost: String {
        get { UserDefaults.standard.string(forKey: udKey) ?? defaultHost }
        set {
            var v = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { return }
            // Strip trailing slashes so URL construction is consistent
            while v.hasSuffix("/") { v = String(v.dropLast()) }
            UserDefaults.standard.set(v, forKey: udKey)
        }
    }

    var baseURL: URL {
        if serverHost.hasPrefix("http") {
            // Full URL (e.g. ngrok, production server)
            return URL(string: "\(serverHost)/api/v1/")!
        } else {
            // Plain LAN IP — local dev
            return URL(string: "http://\(serverHost):8000/api/v1/")!
        }
    }

    /// Host string for NWConnection ping (hostname or IP only, no scheme/port)
    var pingHost: String {
        if serverHost.hasPrefix("http") {
            return URL(string: serverHost)?.host ?? defaultHost
        }
        return serverHost
    }

    /// Port for NWConnection ping
    var pingPort: UInt16 {
        if serverHost.hasPrefix("https") { return 443 }
        if serverHost.hasPrefix("http"),
           let port = URL(string: serverHost)?.port { return UInt16(port) }
        return 8000
    }

    /// Called by ServerDiscovery when it finds a new LAN IP.
    /// Ignored if the current host is an external URL (ngrok / production).
    func updateFromDiscovery(ip: String) {
        guard !serverHost.hasPrefix("http") ||
              serverHost.contains("192.168") ||
              serverHost.contains("10.0") ||
              serverHost.contains("172.") else { return }
        serverHost = ip
    }

    // Legacy accessor kept for ProfileView
    var serverIP: String {
        get { serverHost }
        set { serverHost = newValue }
    }
}
