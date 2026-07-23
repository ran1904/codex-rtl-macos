import Dispatch
import Foundation
import CodexRTLCore

let port = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 9234

Task {
    do {
        let client = DevToolsClient(port: port)
        let targets = try await client.codexTargets()
        guard !targets.isEmpty else {
            throw CodexRTLError.noCodexRenderer
        }

        let assets = try InjectionAssets.load()
        let payload = try InjectionPayload.activate(using: assets)
        var verifiedRealHebrewContent = false
        for target in targets {
            guard try await client.evaluate(payload, in: target) else {
                throw CodexRTLError.rendererRejected
            }
            guard try await client.evaluate(InjectionPayload.status, in: target) else {
                throw CodexRTLError.rendererRejected
            }

            let addSample = """
            (() => {
              document.getElementById('codex-rtl-live-probe')?.remove();
              const host = document.createElement('article');
              host.id = 'codex-rtl-live-probe';
              host.dataset.messageAuthorRole = 'assistant';
              host.innerHTML = '<p>בדיקת RTL with English 123.</p><pre><code>npm test</code></pre>';
              document.body.append(host);
              return true;
            })()
            """
            guard try await client.evaluate(addSample, in: target) else {
                throw CodexRTLError.rendererRejected
            }

            try await Task.sleep(nanoseconds: 300_000_000)
            let verifyComputedStyles = """
            (() => {
              const host = document.getElementById('codex-rtl-live-probe');
              const prose = host?.querySelector('p');
              const code = host?.querySelector('code');
              const proseStyle = prose ? getComputedStyle(prose) : null;
              const codeStyle = code ? getComputedStyle(code) : null;
              const valid = proseStyle?.direction === 'rtl'
                && proseStyle?.textAlign === 'right'
                && codeStyle?.direction === 'ltr'
                && codeStyle?.textAlign === 'left';
              host?.remove();
              return valid;
            })()
            """
            guard try await client.evaluate(verifyComputedStyles, in: target) else {
                throw CodexRTLError.rendererRejected
            }

            let verifyRealHebrewContent = """
            (() => Array.from(document.querySelectorAll('[data-local-codex-rtl-prose="true"]')).some((node) => {
              const text = node.innerText || node.textContent || '';
              const style = getComputedStyle(node);
              return /[\\u0590-\\u05FF]/.test(text)
                && style.direction === 'rtl'
                && style.textAlign === 'right';
            }))()
            """
            if try await client.evaluate(verifyRealHebrewContent, in: target) {
                verifiedRealHebrewContent = true
            }
        }

        guard verifiedRealHebrewContent else {
            throw CodexRTLError.rendererRejected
        }

        print(
            "OK: native Swift client connected to \(targets.count) Codex renderer(s), "
                + "confirmed RTL/LTR computed styles, and verified real Hebrew conversation content."
        )
        exit(0)
    } catch {
        fputs("LIVE PROBE FAILED: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

dispatchMain()
