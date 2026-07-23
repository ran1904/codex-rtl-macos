# Security Policy

## Supported versions

This is a temporary, unofficial workaround. Only the latest version on `main` is supported.

## Reporting a vulnerability

Do not open a public issue containing vulnerability details, conversation content, cookies, tokens, personal file paths, or other sensitive information.

Report vulnerabilities privately through
[GitHub Security Advisories](https://github.com/ran1904/codex-rtl-macos/security/advisories/new).
Include a short description, reproduction steps, and the potential impact without attaching personal information or secrets.

## Security boundary

The app opens a local Chrome DevTools endpoint on `127.0.0.1`. Other computers on the network cannot reach it, but another process running under the same local user may be able to connect. Quit ChatGPT and reopen it normally when you no longer need Codex RTL Helper.
