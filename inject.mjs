import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const args = new Set(process.argv.slice(2));
const portArg = [...args].find((value) => value.startsWith('--port='));
const port = Number(portArg?.slice('--port='.length) || process.env.CODEX_RTL_PORT || 9224);
const watch = args.has('--watch');
const dryRun = args.has('--dry-run');

if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  throw new Error('The DevTools port must be an integer from 1024 through 65535.');
}
if (typeof WebSocket !== 'function') throw new Error('Node.js 22+ is required for WebSocket support.');

const css = readFileSync(resolve(root, 'src', 'rtl-style.css'), 'utf8');
const direction = readFileSync(resolve(root, 'src', 'direction.js'), 'utf8');
const runtime = readFileSync(resolve(root, 'src', 'rtl-runtime.js'), 'utf8');

if (dryRun) {
  if (!runtime.includes('MutationObserver') || !css.includes('unicode-bidi') || !direction.includes('classifyDirection')) {
    throw new Error('Local RTL assets failed the integrity check.');
  }
  console.log('OK: local RTL assets are present.');
  process.exit(0);
}

const endpoint = `http://127.0.0.1:${port}/json`;
const injected = new Set();

function safeTargetSummary(target) {
  try {
    const url = new URL(target.url || 'about:blank');
    return `${target.title || '(untitled)'} — ${url.protocol}//${url.host}${url.pathname}`;
  } catch {
    return `${target.title || '(untitled)'} — (invalid local URL)`;
  }
}

function isCodexTarget(target) {
  return target?.type === 'page'
    && typeof target.webSocketDebuggerUrl === 'string'
    && String(target.title || '').trim().toLowerCase() === 'codex';
}

function assertLocalSocket(wsUrl) {
  const url = new URL(wsUrl);
  const localHost = ['127.0.0.1', 'localhost', '::1', '[::1]'].includes(url.hostname);
  if (url.protocol !== 'ws:' || !localHost || Number(url.port) !== port) {
    throw new Error('Refusing a DevTools target that is not this local loopback port.');
  }
}

async function targets() {
  const response = await fetch(endpoint);
  if (!response.ok) throw new Error(`DevTools returned HTTP ${response.status}.`);
  const contentLength = Number(response.headers.get('content-length') || 0);
  if (contentLength > 1_048_576) throw new Error('DevTools target list is too large.');
  const reader = response.body.getReader();
  const chunks = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > 1_048_576) {
      await reader.cancel();
      throw new Error('DevTools target list is too large.');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  let data;
  try {
    data = JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw new Error('DevTools returned invalid JSON.');
  }
  if (!Array.isArray(data) || data.length > 100) {
    throw new Error('DevTools returned an invalid target list.');
  }
  return data.filter((target) => target && typeof target === 'object');
}

function evaluate(wsUrl, expression) {
  assertLocalSocket(wsUrl);
  return new Promise((resolvePromise, rejectPromise) => {
    const socket = new WebSocket(wsUrl);
    const id = 1;
    const timer = setTimeout(() => {
      socket.close();
      rejectPromise(new Error('Timed out while applying the RTL layer.'));
    }, 8000);
    const finish = (result) => {
      clearTimeout(timer);
      socket.close();
      result instanceof Error ? rejectPromise(result) : resolvePromise(result);
    };
    socket.addEventListener('open', () => socket.send(JSON.stringify({
      id,
      method: 'Runtime.evaluate',
      params: { expression, awaitPromise: false, returnByValue: true }
    })));
    socket.addEventListener('error', () => finish(new Error('The local DevTools socket failed.')));
    socket.addEventListener('message', (event) => {
      let message;
      try {
        message = JSON.parse(String(event.data));
      } catch {
        finish(new Error('The local DevTools socket returned invalid JSON.'));
        return;
      }
      if (message.id !== id) return;
      if (message.error || message.result?.exceptionDetails) {
        finish(new Error('The renderer rejected the local RTL layer.'));
      } else {
        finish(message.result?.result?.value);
      }
    });
  });
}

async function injectOnce({ quiet = false } = {}) {
  const all = await targets();
  const candidates = all.filter(isCodexTarget);
  if (!candidates.length) {
    if (!quiet) {
      const known = all.filter((target) => target.type === 'page').map(safeTargetSummary).join('\n  ');
      throw new Error(`No Codex renderer found. Open a Codex task first. Known local pages:\n  ${known || '(none)'}`);
    }
    return false;
  }
  const expression = `(() => {
    window.__LOCAL_CODEX_RTL_CSS__ = ${JSON.stringify(css)};
    (0, eval)(${JSON.stringify(direction)});
    (0, eval)(${JSON.stringify(runtime)});
    return window.__LOCAL_CODEX_RTL_ACTIVE__ === true;
  })()`;
  for (const target of candidates) {
    if (injected.has(target.id)) continue;
    if (await evaluate(target.webSocketDebuggerUrl, expression) !== true) {
      throw new Error('The renderer did not acknowledge the RTL layer.');
    }
    injected.add(target.id);
    console.log(`Applied local RTL to: ${safeTargetSummary(target)}`);
  }
  return true;
}

if (!watch) {
  await injectOnce();
} else {
  console.log(`Watching only ${endpoint}; no content leaves this computer.`);
  const tick = () => injectOnce({ quiet: true }).catch((error) => {
    if (error.cause?.code !== 'ECONNREFUSED') console.error(error.message);
  });
  setInterval(tick, 1500);
  await tick();
}
