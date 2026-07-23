# Contributing

Thank you for helping improve Codex RTL Helper.

## Before proposing a change

- Search existing issues to avoid duplicates.
- Do not include screenshots, logs, or examples that contain conversation content or personal information.
- Preserve the project's boundaries: local presentation changes only, no ChatGPT file modifications, no telemetry, and no connection to a non-loopback target.

## Development environment

You need macOS 13 or later, Swift 6, and Node.js 22 or later.

Run:

```sh
sh ./scripts/test.sh
node self-test.mjs
node integration-test.mjs
node inject.mjs --dry-run
sh ./scripts/build-app.sh
```

## Pull requests

Prefer a small, focused change with a clear explanation. Every pull request should describe:

- The problem being solved.
- How the change was tested.
- Whether it changes security assumptions, selectors, or RTL/LTR behavior.

Any change that affects code, commands, file paths, or terminal output must keep them LTR.
