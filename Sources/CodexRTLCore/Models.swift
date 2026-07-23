import AppKit
import Foundation

public enum RTLState: Equatable {
    case codexClosed
    case needsRestart
    case connecting
    case connectedInactive
    case active
    case failure(String)

    public var statusTitle: String {
        switch self {
        case .codexClosed:
            return "Codex is closed"
        case .needsRestart:
            return "Restart required"
        case .connecting:
            return "Connecting to Codex…"
        case .connectedInactive:
            return "RTL is off"
        case .active:
            return "RTL is active"
        case let .failure(message):
            return "Error: \(message)"
        }
    }

    public var symbolName: String {
        switch self {
        case .codexClosed:
            return "circle"
        case .needsRestart, .connecting:
            return "circle.dotted"
        case .connectedInactive:
            return "circle"
        case .active:
            return "circle.fill"
        case .failure:
            return "exclamationmark.circle.fill"
        }
    }

    public var tintColor: NSColor {
        switch self {
        case .codexClosed:
            return .secondaryLabelColor
        case .needsRestart, .connecting:
            return .systemOrange
        case .connectedInactive:
            return .secondaryLabelColor
        case .active:
            return .systemGreen
        case .failure:
            return .systemRed
        }
    }
}

public struct DevToolsTarget: Decodable, Equatable {
    public let id: String
    public let title: String
    public let type: String
    public let url: String
    public let webSocketDebuggerUrl: String?

    public init(id: String, title: String, type: String, url: String, webSocketDebuggerUrl: String?) {
        self.id = id
        self.title = title
        self.type = type
        self.url = url
        self.webSocketDebuggerUrl = webSocketDebuggerUrl
    }

    public var isCodexRenderer: Bool {
        guard type == "page", webSocketDebuggerUrl != nil else { return false }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("Codex") == .orderedSame
    }
}

public enum CodexRTLError: LocalizedError, Equatable {
    case invalidLoopbackURL
    case devToolsUnavailable
    case noCodexRenderer
    case rendererRejected
    case requestTimedOut
    case codexNotInstalled
    case codexDidNotQuit
    case missingResource(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidLoopbackURL:
            return "The local connection is invalid"
        case .devToolsUnavailable:
            return "Codex is open without an RTL connection"
        case .noCodexRenderer:
            return "No Codex window was found"
        case .rendererRejected:
            return "The Codex window rejected the RTL layer"
        case .requestTimedOut:
            return "The Codex connection timed out"
        case .codexNotInstalled:
            return "Codex is not installed at the expected path"
        case .codexDidNotQuit:
            return "Codex did not quit in time"
        case let .missingResource(name):
            return "Missing local resource: \(name)"
        case .invalidResponse:
            return "Codex returned an invalid response"
        }
    }
}
