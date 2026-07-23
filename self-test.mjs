import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const read = (name) => readFileSync(new URL(name, import.meta.url), 'utf8');
const direction = read('./src/direction.js');
const runtime = read('./src/rtl-runtime.js');
const injector = read('./inject.mjs');
const launcher = read('./run.sh');
const css = read('./src/rtl-style.css');

const context = { window: {} };
vm.runInNewContext(direction, context);
const classify = context.window.__LOCAL_CODEX_RTL_CLASSIFY__;
assert.equal(classify('תשובה עם Next.js ו-TypeScript'), 'rtl');
assert.equal(classify('English response with 123'), 'ltr');
assert.equal(classify('פקודת npm install נשארת בקריאה נכונה'), 'rtl');
assert.equal(classify(''), 'ltr');

assert.match(launcher, /127\.0\.0\.1/);
assert.match(launcher, /ChatGPT is already running/);
assert.doesNotMatch(launcher, /rm\s|codesign|asar|curl|wget/);
assert.match(injector, /http:\/\/127\.0\.0\.1:\$\{port\}\/json/);
assert.match(injector, /Refusing a DevTools target/);
assert.doesNotMatch(injector, /https:\/\/(?!127\.0\.0\.1)/);
assert.match(runtime, /MutationObserver/);
assert.match(runtime, /localCodexRtlCode/);
assert.match(runtime, /localCodexRtlOverride/);
assert.match(runtime, /__LOCAL_CODEX_RTL_CLICK_HANDLER__/);
assert.match(runtime, /__LOCAL_CODEX_RTL_INPUT_HANDLER__/);
assert.match(runtime, /pendingRoots/);
assert.match(css, /unicode-bidi: isolate/);
console.log('OK: direction, isolation, local-only, and no-app-write safeguards passed.');
