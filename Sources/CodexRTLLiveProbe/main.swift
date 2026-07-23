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
              host.innerHTML = [
                '<p>בדיקת RTL with English 123.</p>',
                '<span id="codex-rtl-live-probe-ui">בדיקת חלונית RTL עם Step 2 / 6.</span>',
                '<h2 id="codex-rtl-live-probe-heading">ההגדרה <span id="codex-rtl-live-probe-inline">המומלצת</span></h2>',
                '<p id="codex-rtl-live-probe-markdown">הרץ את <span id="codex-rtl-live-probe-inline-code" data-markdown-copy="inline-code">npm test</span> מתוך התיקייה.</p>',
                '<div data-turn-key="streaming-probe-turn">',
                '<div data-user-message-bubble="true">כתוב תשובה בעברית.</div>',
                '<div id="codex-rtl-live-probe-stream" data-response-annotation-target="streaming-probe">',
                '<h4>ChatGPT said:</h4>',
                '<div id="codex-rtl-live-probe-stream-text"></div>',
                '</div>',
                '</div>',
                '<div data-turn-key="english-output-probe-turn">',
                '<div data-user-message-bubble="true">ענה באנגלית.</div>',
                '<div id="codex-rtl-live-probe-english" data-response-annotation-target="english-output-probe">',
                '<h4>ChatGPT said:</h4>',
                '<div id="codex-rtl-live-probe-english-text"></div>',
                '</div>',
                '</div>',
                '<pre><code>npm test</code></pre>'
              ].join('');
              document.body.append(host);
              return true;
            })()
            """
            guard try await client.evaluate(addSample, in: target) else {
                throw CodexRTLError.rendererRejected
            }

            try await Task.sleep(nanoseconds: 300_000_000)
            let verifyPromptDirection = """
            (() => {
              const streaming = document.getElementById('codex-rtl-live-probe-stream');
              const streamingText = document.getElementById('codex-rtl-live-probe-stream-text');
              const english = document.getElementById('codex-rtl-live-probe-english');
              const streamingStyle = streaming ? getComputedStyle(streaming) : null;
              const streamingTextStyle = streamingText ? getComputedStyle(streamingText) : null;
              const englishStyle = english ? getComputedStyle(english) : null;
              return streaming?.dataset.localCodexRtlResponse === 'true'
                && streaming?.dataset.localCodexRtlHint === 'prompt'
                && streamingStyle?.direction === 'rtl'
                && streamingStyle?.textAlign === 'right'
                && streamingTextStyle?.direction === 'rtl'
                && streamingTextStyle?.textAlign === 'right'
                && !streamingText?.textContent
                && english?.dataset.localCodexRtlResponse === 'true'
                && english?.dataset.localCodexRtlHint === 'prompt'
                && english?.lang === 'he'
                && englishStyle?.direction === 'rtl';
            })()
            """
            guard try await client.evaluate(verifyPromptDirection, in: target) else {
                throw CodexRTLError.rendererRejected
            }

            let streamSample = """
            (() => {
              const streamingText = document.getElementById('codex-rtl-live-probe-stream-text');
              const englishText = document.getElementById('codex-rtl-live-probe-english-text');
              if (!streamingText || !englishText) return false;
              streamingText.append(document.createTextNode('היא '));
              streamingText.append(document.createTextNode('תצטרך לעבור בדיקה בזמן streaming.'));
              englishText.append(document.createTextNode('This response is intentionally written in English.'));
              return true;
            })()
            """
            guard try await client.evaluate(streamSample, in: target) else {
                throw CodexRTLError.rendererRejected
            }

            try await Task.sleep(nanoseconds: 300_000_000)
            let verifyComputedStyles = """
            (() => {
              const host = document.getElementById('codex-rtl-live-probe');
              const prose = host?.querySelector('p');
              const uiText = host?.querySelector('#codex-rtl-live-probe-ui');
              const heading = host?.querySelector('#codex-rtl-live-probe-heading');
              const inlineText = host?.querySelector('#codex-rtl-live-probe-inline');
              const inlineCode = host?.querySelector('#codex-rtl-live-probe-inline-code');
              const streaming = host?.querySelector('#codex-rtl-live-probe-stream');
              const streamingText = host?.querySelector('#codex-rtl-live-probe-stream-text');
              const english = host?.querySelector('#codex-rtl-live-probe-english');
              const code = host?.querySelector('code');
              const proseStyle = prose ? getComputedStyle(prose) : null;
              const uiTextStyle = uiText ? getComputedStyle(uiText) : null;
              const headingStyle = heading ? getComputedStyle(heading) : null;
              const inlineTextStyle = inlineText ? getComputedStyle(inlineText) : null;
              const inlineCodeStyle = inlineCode ? getComputedStyle(inlineCode) : null;
              const streamingStyle = streaming ? getComputedStyle(streaming) : null;
              const streamingTextStyle = streamingText ? getComputedStyle(streamingText) : null;
              const englishStyle = english ? getComputedStyle(english) : null;
              const codeStyle = code ? getComputedStyle(code) : null;
              const valid = proseStyle?.direction === 'rtl'
                && proseStyle?.textAlign === 'right'
                && uiText?.dataset.localCodexRtlProse === 'true'
                && uiTextStyle?.direction === 'rtl'
                && uiTextStyle?.textAlign === 'right'
                && heading?.textContent === 'ההגדרה המומלצת'
                && headingStyle?.direction === 'rtl'
                && inlineText?.dataset.localCodexRtlProse !== 'true'
                && !inlineText?.hasAttribute('dir')
                && inlineTextStyle?.direction === 'rtl'
                && inlineCode?.dataset.localCodexRtlCode === 'true'
                && inlineCode?.dir === 'ltr'
                && inlineCodeStyle?.direction === 'ltr'
                && streaming?.dataset.localCodexRtlResponse === 'true'
                && streamingStyle?.direction === 'rtl'
                && streamingStyle?.textAlign === 'right'
                && streamingTextStyle?.direction === 'rtl'
                && streamingTextStyle?.textAlign === 'right'
                && english?.dataset.localCodexRtlHint === 'output'
                && english?.dataset.localCodexRtlResponse !== 'true'
                && english?.dir === 'auto'
                && !english?.hasAttribute('lang')
                && englishStyle?.direction === 'ltr'
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
