import Foundation

public enum LoopbackPolicy {
    public static func isAllowedHTTP(_ url: URL, port: Int) -> Bool {
        guard url.scheme == "http",
              url.host == "127.0.0.1",
              url.port == port else {
            return false
        }
        return true
    }

    public static func isAllowedWebSocket(_ url: URL, port: Int) -> Bool {
        guard url.scheme == "ws",
              ["127.0.0.1", "localhost", "::1"].contains(url.host ?? ""),
              url.port == port else {
            return false
        }
        return true
    }
}
