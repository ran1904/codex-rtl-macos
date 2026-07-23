# Codex RTL Helper for macOS

## Product goal

Provide a convenient RTL fix for Hebrew and Arabic Codex output through a small local menu bar app. The user should not need to open Terminal, run scripts, or change their normal workflow beyond launching Codex through Codex RTL Helper when RTL support is needed.

Codex RTL Helper packages the existing local direction-detection mechanism as a native, self-contained macOS app.

## Approved decisions

- Use a clean menu bar icon with no persistent window and no Dock icon.
- Name the app `Codex RTL Helper`.
- Keep the implementation local and user-owned, with no external service or third-party package.
- Do not modify `/Applications/ChatGPT.app`, its signature, or `app.asar`.
- Ask for confirmation before quitting and reopening Codex when it is already running without the required local connection.
- Prove the live connection against the installed Codex version before building the menu bar interface.

## User experience

The icon communicates state through color:

- Gray: Codex is not running.
- Orange: Codex is running, but RTL is not active.
- Green: the connection is ready and RTL is active.
- Red: an error requires attention.

Clicking the icon opens a compact menu with:

- Enable RTL.
- Disable RTL.
- Open Codex.
- Check Connection.
- A short explanation of the latest error.
- Quit Codex RTL Helper.

When Codex is closed, **Open Codex with RTL** starts it with a local development connection restricted to `127.0.0.1`, then applies the RTL layer. When Codex is already running normally, Codex RTL Helper requests confirmation before restarting it. Canceling leaves Codex unchanged.

## Architecture

The app is written in Swift and uses `NSStatusItem` for the menu bar. Node.js is not required at runtime.

The implementation is divided into these components:

1. `CodexProcessService` detects whether Codex is running, launches it with the required local arguments, and coordinates restart confirmation.
2. `DevToolsConnection` discovers Codex targets through loopback only, validates every WebSocket URL, and performs the injection.
3. `RTLInjectionService` bundles `direction.js`, `rtl-runtime.js`, and `rtl-style.css` as internal resources and verifies that the renderer accepted the layer.
4. `StatusController` maps process and connection state to the icon color and available actions.
5. `ConnectionMonitor` detects new windows or renderers and reapplies the layer without aggressive polling.

## Data flow

Codex RTL Helper reads only technical metadata from the local DevTools endpoint: renderer entries, titles, internal URLs, and target identifiers. It does not copy, store, or transmit conversation content.

After selecting an eligible renderer, Codex RTL Helper sends the local RTL assets and receives a Boolean activation result. The icon becomes green only after the renderer confirms activation.

## Privacy and security

- Restrict every connection to `127.0.0.1` and the configured port.
- Reject non-local WebSocket URLs.
- Store no cookies, tokens, conversation content, or usage data.
- Install no browser extension and run no independent updater.
- Do not modify or re-sign the Codex or ChatGPT app bundle.
- Disabling Codex RTL Helper must not require deleting or restoring Codex.

A local DevTools port still allows another process running under the same user to attempt a renderer connection. Codex RTL Helper documents this risk, enables the endpoint only when needed, and stops relying on it after the user fully quits the Codex instance launched through Codex RTL Helper.

## Error handling

- If Codex is already running normally, request confirmation before restarting it.
- If the configured port is occupied, report a clear error or select an available local port.
- If no Codex renderer is found, wait for a bounded interval and offer another check.
- If an update changes the interface, turn the icon red and do not report success.
- If the connection drops, retry a bounded number of times and never enter an infinite loop.
- If injection fails, leave Codex running without visual changes.

## Validation strategy

Implementation proceeds through measurable gates:

1. A live connection probe confirms that the installed Codex build accepts the DevTools arguments and exposes a local endpoint.
2. An injection test verifies that the RTL layer activates in the visible window.
3. Unit tests cover state detection, loopback URL validation, renderer selection, and status transitions.
4. Integration tests cover a mock endpoint and mock WebSocket connection.
5. Visual testing covers Hebrew, Arabic, mixed English and numbers, lists, headings, inline code, code blocks, and the composer.
6. Lifecycle testing covers launch, quit, renderer reload, new windows, and disabling RTL.

## First-version boundaries

The first version does not include launch at login, automatic updates, a floating character, usage analytics, or support for other apps. These features are not required to solve the RTL problem and should be considered only after real-world use.

## Feasibility risk

The main risk was that the installed Codex build might not expose DevTools when launched with standard arguments. In that case, a menu bar app could not adjust the DOM without a more invasive approach.

The implementation therefore began with the smallest possible read-only feasibility probe. If it had failed, the alternatives would have been a separate floating reading panel that does not modify Codex or a modified app copy requiring re-signing and ongoing maintenance after updates.
