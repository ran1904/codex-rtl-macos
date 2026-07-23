import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';

function decodeClientFrame(buffer) {
  const payloadLength = buffer[1] & 0x7f;
  let offset = 2;
  let length = payloadLength;
  if (payloadLength === 126) { length = buffer.readUInt16BE(offset); offset += 2; }
  if (payloadLength === 127) throw new Error('Unexpectedly large WebSocket test frame.');
  const mask = buffer.subarray(offset, offset + 4); offset += 4;
  const body = buffer.subarray(offset, offset + length);
  return JSON.parse(Buffer.from(body.map((byte, index) => byte ^ mask[index % 4])).toString('utf8'));
}

function encodeServerFrame(value) {
  const body = Buffer.from(JSON.stringify(value));
  if (body.length >= 126) throw new Error('Test response is unexpectedly large.');
  return Buffer.concat([Buffer.from([0x81, body.length]), body]);
}

let received;
const server = createServer((request, response) => {
  if (request.url !== '/json') { response.writeHead(404).end(); return; }
  const port = server.address().port;
  response.setHeader('content-type', 'application/json');
  response.end(JSON.stringify([{
    id: 'codex-test', type: 'page', title: 'Codex', url: 'app://codex/test',
    webSocketDebuggerUrl: `ws://127.0.0.1:${port}/devtools/page/codex-test`
  }]));
});

server.on('upgrade', (request, socket) => {
  const accept = createHash('sha1')
    .update(`${request.headers['sec-websocket-key']}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
    .digest('base64');
  socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  let data = Buffer.alloc(0);
  socket.on('data', (chunk) => {
    data = Buffer.concat([data, chunk]);
    try {
      received = decodeClientFrame(data);
      socket.write(encodeServerFrame({ id: received.id, result: { result: { value: true } } }));
      setTimeout(() => socket.end(), 10);
    } catch (error) {
      if (error.code === 'ERR_OUT_OF_RANGE') return;
      throw error;
    }
  });
});

await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
const child = spawn(process.execPath, ['inject.mjs', `--port=${port}`], { stdio: 'pipe' });
let stderr = '';
child.stderr.on('data', (chunk) => { stderr += chunk; });
const exitCode = await new Promise((resolve) => child.on('exit', resolve));
server.close();

assert.equal(exitCode, 0, stderr);
assert.equal(received.method, 'Runtime.evaluate');
assert.match(received.params.expression, /__LOCAL_CODEX_RTL_CSS__/);
assert.match(received.params.expression, /localCodexRtlOverride/);
assert.match(received.params.expression, /unicode-bidi/);
console.log('OK: injector completed a local DevTools Protocol round trip and applied the RTL runtime.');
