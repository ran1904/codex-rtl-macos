import Foundation

public struct InjectionAssets {
    public let css: String
    public let direction: String
    public let runtime: String

    public init(css: String, direction: String, runtime: String) {
        self.css = css
        self.direction = direction
        self.runtime = runtime
    }

    public static func load() throws -> InjectionAssets {
        try load(bundle: .module)
    }

    static func load(bundle: Bundle) throws -> InjectionAssets {
        try InjectionAssets(
            css: read("rtl-style", extension: "css", bundle: bundle),
            direction: read("direction", extension: "js", bundle: bundle),
            runtime: read("rtl-runtime", extension: "js", bundle: bundle)
        )
    }

    private static func read(_ name: String, extension fileExtension: String, bundle: Bundle) throws -> String {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            throw CodexRTLError.missingResource("\(name).\(fileExtension)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

public enum InjectionPayload {
    public static func activate(using assets: InjectionAssets) throws -> String {
        let css = try jsonLiteral(assets.css)
        let direction = try jsonLiteral(assets.direction)
        let runtime = try jsonLiteral(assets.runtime)

        return """
        (() => {
          window.__LOCAL_CODEX_RTL_CSS__ = \(css);
          (0, eval)(\(direction));
          (0, eval)(\(runtime));
          return window.__LOCAL_CODEX_RTL_ACTIVE__ === true;
        })()
        """
    }

    public static let status = "window.__LOCAL_CODEX_RTL_ACTIVE__ === true"

    public static let deactivate = """
    (() => {
      window.__LOCAL_CODEX_RTL_OBSERVER__?.disconnect();
      delete window.__LOCAL_CODEX_RTL_OBSERVER__;
      if (window.__LOCAL_CODEX_RTL_CLICK_HANDLER__) {
        document.removeEventListener('click', window.__LOCAL_CODEX_RTL_CLICK_HANDLER__, true);
        delete window.__LOCAL_CODEX_RTL_CLICK_HANDLER__;
      }
      if (window.__LOCAL_CODEX_RTL_INPUT_HANDLER__) {
        document.removeEventListener('input', window.__LOCAL_CODEX_RTL_INPUT_HANDLER__, true);
        delete window.__LOCAL_CODEX_RTL_INPUT_HANDLER__;
      }
      document.getElementById('local-codex-rtl-style')?.remove();
      document.querySelectorAll('[data-local-codex-rtl-control="true"]').forEach((node) => node.remove());
      document.querySelectorAll('[data-local-codex-rtl-managed="true"]').forEach((node) => {
        node.removeAttribute('dir');
        node.removeAttribute('lang');
        delete node.dataset.localCodexRtlManaged;
        delete node.dataset.localCodexRtlProse;
        delete node.dataset.localCodexRtlResponse;
        delete node.dataset.localCodexRtlHint;
        delete node.dataset.localCodexRtlInput;
      });
      document.querySelectorAll('[data-local-codex-rtl-code="true"]').forEach((node) => {
        node.removeAttribute('dir');
        delete node.dataset.localCodexRtlCode;
      });
      delete document.documentElement.dataset.localCodexRtlRoot;
      window.__LOCAL_CODEX_RTL_ACTIVE__ = false;
      return true;
    })()
    """

    private static func jsonLiteral(_ value: String) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let literal = String(data: data, encoding: .utf8) else {
            throw CodexRTLError.invalidResponse
        }
        return literal
    }
}
