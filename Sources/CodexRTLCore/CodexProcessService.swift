import AppKit
import Foundation

@MainActor
final class CodexProcessService {
    static let bundleIdentifier = "com.openai.codex"
    static let applicationURL = URL(fileURLWithPath: "/Applications/ChatGPT.app")

    var runningApplications: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier)
            .filter { !$0.isTerminated }
    }

    var isRunning: Bool {
        !runningApplications.isEmpty
    }

    func launch(port: Int) async throws {
        guard FileManager.default.isExecutableFile(
            atPath: Self.applicationURL.appendingPathComponent("Contents/MacOS/ChatGPT").path
        ) else {
            throw CodexRTLError.codexNotInstalled
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = [
            "--remote-debugging-address=127.0.0.1",
            "--remote-debugging-port=\(port)"
        ]
        configuration.createsNewApplicationInstance = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(
                at: Self.applicationURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func terminateGracefully(timeoutSeconds: Double = 12) async throws {
        for application in runningApplications {
            application.terminate()
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while isRunning, Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        if isRunning {
            throw CodexRTLError.codexDidNotQuit
        }
    }
}
