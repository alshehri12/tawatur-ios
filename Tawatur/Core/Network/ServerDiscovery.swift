// ServerDiscovery.swift
// On every app launch: sends a UDP broadcast to find the backend automatically.
// Strategy (in order):
//   1. Unicast to the stored IP  — instant if IP hasn't changed
//   2. Subnet broadcast          — finds the new IP after a DHCP change
// If either succeeds, ServerConfig is updated silently.
// Falls back to the last known IP stored in UserDefaults if both fail.

import Foundation
import Darwin

final class ServerDiscovery {

    static let shared = ServerDiscovery()
    private init() {}

    private let port: UInt16 = 45678
    private let request  = "TAWATUR_DISCOVER"
    private let prefix   = "TAWATUR_BACKEND:"

    // Call once at app startup — runs entirely in the background.
    // Skips UDP scan if the current host is an external URL (ngrok / production server).
    func discoverAndUpdate() {
        let currentHost = ServerConfig.shared.serverHost
        // Don't scan if already pointing at an external server
        guard !currentHost.hasPrefix("https://"),
              !(currentHost.hasPrefix("http://") && !currentHost.contains("192.168") && !currentHost.contains("10.0") && !currentHost.contains("172.")) else {
            print("[Discovery] External host configured — skipping LAN scan")
            return
        }

        DispatchQueue.global(qos: .background).async {
            // 1. Fast path: unicast to last-known IP (works when IP hasn't changed)
            let storedIP = ServerConfig.shared.pingHost
            if let found = self.sendUDP(to: storedIP, timeoutSecs: 1) {
                if found != storedIP {
                    ServerConfig.shared.updateFromDiscovery(ip: found)
                    print("[Discovery] IP updated via unicast: \(found)")
                }
                return
            }

            // 2. Slow path: subnet broadcast (finds backend after DHCP reassignment)
            if let localIP = self.localWiFiIP(),
               let broadcast = self.subnetBroadcast(from: localIP),
               let found = self.sendUDP(to: broadcast, timeoutSecs: 2) {
                ServerConfig.shared.updateFromDiscovery(ip: found)
                print("[Discovery] IP updated via broadcast: \(found)")
                return
            }

            print("[Discovery] Backend not found — using stored host: \(storedIP)")
        }
    }

    // ── UDP send/receive ──────────────────────────────────────────────────────

    private func sendUDP(to host: String, timeoutSecs: Int) -> String? {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { Darwin.close(sock) }

        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))

        var tv = timeval(tv_sec: timeoutSecs, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port   = port.bigEndian
        inet_pton(AF_INET, host, &dest.sin_addr)

        let sent: Int = request.withCString { ptr in
            withUnsafePointer(to: &dest) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(sock, ptr, strlen(ptr), 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }

        var buf = [UInt8](repeating: 0, count: 256)
        let received = recv(sock, &buf, buf.count - 1, 0)
        guard received > 0 else { return nil }

        let response = String(bytes: buf[..<received], encoding: .utf8) ?? ""
        guard response.hasPrefix(prefix) else { return nil }

        let ip = String(response.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ip.isEmpty ? nil : ip
    }

    // ── Network helpers ───────────────────────────────────────────────────────

    private func subnetBroadcast(from ip: String) -> String? {
        var parts = ip.split(separator: ".").map(String.init)
        guard parts.count == 4 else { return nil }
        parts[3] = "255"
        return parts.joined(separator: ".")
    }

    private func localWiFiIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var cursor = ifaddr
        while let ptr = cursor {
            let iface = ptr.pointee
            if iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: iface.ifa_name)
                if name.hasPrefix("en") {        // en0 = Wi-Fi on iPhone
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(iface.ifa_addr,
                                socklen_t(iface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: hostname)
                    if !ip.hasPrefix("127.") && !ip.isEmpty { return ip }
                }
            }
            cursor = iface.ifa_next
        }
        return nil
    }
}
