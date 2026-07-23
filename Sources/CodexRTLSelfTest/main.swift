import Foundation
import CodexRTLCore

struct SelfTestFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw SelfTestFailure(description: message)
    }
}

do {
    try require(
        LoopbackPolicy.isAllowedHTTP(
            URL(string: "http://127.0.0.1:9224/json")!,
            port: 9224
        ),
        "Expected loopback HTTP endpoint was rejected."
    )
    try require(
        LoopbackPolicy.isAllowedWebSocket(
            URL(string: "ws://127.0.0.1:9224/devtools/page/abc")!,
            port: 9224
        ),
        "Expected loopback WebSocket endpoint was rejected."
    )
    try require(
        !LoopbackPolicy.isAllowedHTTP(
            URL(string: "https://example.com:9224/json")!,
            port: 9224
        ),
        "External HTTP endpoint was accepted."
    )
    try require(
        !LoopbackPolicy.isAllowedWebSocket(
            URL(string: "ws://127.0.0.1:9225/devtools/page/abc")!,
            port: 9224
        ),
        "Wrong WebSocket port was accepted."
    )

    let target = DevToolsTarget(
        id: "abc",
        title: "Codex",
        type: "page",
        url: "app://-/index.html",
        webSocketDebuggerUrl: "ws://127.0.0.1:9224/devtools/page/abc"
    )
    try require(target.isCodexRenderer, "Codex renderer was not recognized.")

    let worker = DevToolsTarget(
        id: "worker",
        title: "Codex Worker",
        type: "worker",
        url: "app://-/worker.js",
        webSocketDebuggerUrl: "ws://127.0.0.1:9224/devtools/page/worker"
    )
    try require(!worker.isCodexRenderer, "Worker was incorrectly recognized as a renderer.")
    let unrelatedPage = DevToolsTarget(
        id: "other",
        title: "Other App",
        type: "page",
        url: "app://-/index.html",
        webSocketDebuggerUrl: "ws://127.0.0.1:9224/devtools/page/other"
    )
    try require(!unrelatedPage.isCodexRenderer, "Unrelated app page was recognized as Codex.")
    let misleadingPage = DevToolsTarget(
        id: "misleading",
        title: "Codex documentation",
        type: "page",
        url: "app://-/index.html?codex=true",
        webSocketDebuggerUrl: "ws://127.0.0.1:9224/devtools/page/misleading"
    )
    try require(!misleadingPage.isCodexRenderer, "A substring-only Codex target was accepted.")

    let assets = InjectionAssets(
        css: "body::before { content: \"שלום\"; }",
        direction: "window.directionReady = true;",
        runtime: "window.__LOCAL_CODEX_RTL_ACTIVE__ = true;"
    )
    let payload = try InjectionPayload.activate(using: assets)
    try require(payload.contains("__LOCAL_CODEX_RTL_ACTIVE__ === true"), "Payload omits activation acknowledgement.")
    try require(payload.contains(#"content: \"שלום\""#), "Payload does not JSON-escape local assets.")
    try require(!payload.contains("https://"), "Payload unexpectedly contains an external endpoint.")
    try require(InjectionPayload.deactivate.contains("disconnect()"), "Cleanup omits observer shutdown.")
    try require(
        InjectionPayload.deactivate.contains("removeEventListener"),
        "Cleanup omits event-listener removal."
    )
    try require(
        InjectionPayload.deactivate.contains("__LOCAL_CODEX_RTL_CLICK_HANDLER__"),
        "Cleanup omits the click handler."
    )
    try require(
        InjectionPayload.deactivate.contains("__LOCAL_CODEX_RTL_INPUT_HANDLER__"),
        "Cleanup omits the input handler."
    )
    try require(
        InjectionPayload.deactivate.contains("__LOCAL_CODEX_RTL_ACTIVE__ = false"),
        "Cleanup omits inactive acknowledgement."
    )

    let bundledAssets = try InjectionAssets.load()
    try require(bundledAssets.css.contains("unicode-bidi"), "Bundled CSS is incomplete.")
    try require(bundledAssets.direction.contains("classifyDirection"), "Bundled direction classifier is incomplete.")
    try require(bundledAssets.runtime.contains("MutationObserver"), "Bundled runtime is incomplete.")

    print("OK: Codex RTL Helper loopback, target selection, payload, cleanup, and bundled assets passed.")
} catch {
    fputs("SELF-TEST FAILED: \(error)\n", stderr)
    exit(1)
}
