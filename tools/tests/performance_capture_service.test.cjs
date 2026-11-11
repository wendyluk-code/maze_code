const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {handlePerformanceCapture} = require('../web/performance_capture.cjs');

test('仅接收本机同源采集，定期更新同一记录，错误请求不写入', async (t) => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'maze-perf-test-'));
  const server = http.createServer((req, res) => {
    if (!handlePerformanceCapture(req, res, dir)) { res.writeHead(404); res.end(); }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => { await new Promise(resolve => server.close(resolve)); await fs.rm(dir, {recursive:true, force:true}); });
  const base = 'http://127.0.0.1:' + server.address().port;
  const send = (body, origin = base) => fetch(base + '/__performance_capture', {
    method:'POST', headers:{'content-type':'application/json', origin}, body:JSON.stringify(body),
  });
  assert.equal((await send({session:'sample', samples:[{frame_ms:20}]}, 'https://untrusted.example')).status, 403);
  assert.equal((await send({session:'../other', samples:[]})).status, 400);
  assert.equal((await send({session:'sample', samples:[{frame_ms:20}]})).status, 200);
  assert.equal((await send({session:'sample', samples:[{frame_ms:40}]})).status, 200);
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(dir, 'sample.json'), 'utf8')).samples, [{frame_ms:40}]);
  assert.deepEqual(await fs.readdir(dir), ['sample.json']);
});
