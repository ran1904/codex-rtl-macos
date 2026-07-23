import AppKit
import Foundation

@MainActor
public final class RTLController {
    public var onStateChange: ((RTLState) -> Void)?

    public private(set) var state: RTLState = .codexClosed {
        didSet {
            if oldValue != state {
                onStateChange?(state)
            }
        }
    }

    private let port: Int
    private let processService: CodexProcessService
    private let client: DevToolsClient
    private let assets: InjectionAssets
    private var monitorTask: Task<Void, Never>?
    private var desiredRTL = true
    private var refreshInProgress = false

    public convenience init(port: Int = 9224) throws {
        try self.init(
            port: port,
            processService: CodexProcessService(),
            client: nil,
            assets: nil
        )
    }

    init(
        port: Int = 9224,
        processService: CodexProcessService? = nil,
        client: DevToolsClient? = nil,
        assets: InjectionAssets? = nil
    ) throws {
        self.port = port
        self.processService = processService ?? CodexProcessService()
        self.client = client ?? DevToolsClient(port: port)
        self.assets = try assets ?? InjectionAssets.load()
    }

    public func start() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            guard let self else { return }
            if !processService.isRunning {
                await launchCodexWithRTL()
            } else {
                await refresh()
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await refresh()
            }
        }
    }

    public func refresh() async {
        guard !refreshInProgress else { return }
        refreshInProgress = true
        defer { refreshInProgress = false }

        guard processService.isRunning else {
            state = .codexClosed
            return
        }

        do {
            let targets = try await client.codexTargets()
            guard !targets.isEmpty else {
                state = .connecting
                return
            }

            var everyTargetActive = true
            for target in targets {
                let isActive = (try? await client.evaluate(InjectionPayload.status, in: target)) == true
                everyTargetActive = everyTargetActive && isActive
                if desiredRTL, !isActive {
                    let payload = try InjectionPayload.activate(using: assets)
                    guard try await client.evaluate(payload, in: target) else {
                        throw CodexRTLError.rendererRejected
                    }
                }
            }

            state = desiredRTL ? .active : (everyTargetActive ? .active : .connectedInactive)
        } catch CodexRTLError.devToolsUnavailable {
            state = .needsRestart
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    public func enableRTL() async {
        desiredRTL = true
        await refresh()
    }

    public func disableRTL() async {
        desiredRTL = false
        do {
            let targets = try await client.codexTargets()
            for target in targets {
                _ = try await client.evaluate(InjectionPayload.deactivate, in: target)
            }
            state = .connectedInactive
        } catch CodexRTLError.devToolsUnavailable {
            state = processService.isRunning ? .needsRestart : .codexClosed
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    public func launchCodexWithRTL() async {
        desiredRTL = true
        state = .connecting
        do {
            try await processService.launch(port: port)
            try await waitForDevTools()
            await refresh()
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    public func restartCodexWithRTL() async {
        desiredRTL = true
        state = .connecting
        do {
            try await processService.terminateGracefully()
            try await processService.launch(port: port)
            try await waitForDevTools()
            await refresh()
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    public func stop() async {
        monitorTask?.cancel()
        monitorTask = nil
        await disableRTL()
    }

    private func waitForDevTools() async throws {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if let targets = try? await client.codexTargets(), !targets.isEmpty {
                return
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        throw CodexRTLError.requestTimedOut
    }
}
