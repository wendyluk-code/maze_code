const fs = require('node:fs');
const path = require('node:path');

// 8452 同时向局域网提供游戏，诊断写入仅允许本机同源网页调用。
function handlePerformanceCapture(req, res, directory) {
  if (req.url !== '/__performance_capture') return false;
  const reply = (status, value) => {
    res.writeHead(status, {'Content-Type':'application/json; charset=utf-8', 'Cache-Control':'no-store'});
    res.end(JSON.stringify(value));
  };
  if (req.method !== 'POST') { reply(405, {error:'method'}); return true; }
  const remote = req.socket.remoteAddress;
  const host = String(req.headers.host || '');
  const origin = String(req.headers.origin || '');
  if (!['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(remote) ||
      !/^(localhost|127[.]0[.]0[.]1):[0-9]+$/.test(host) ||
      !['http://' + host, 'https://' + host].includes(origin)) {
    reply(403, {error:'local_origin_required'}); return true;
  }
  if (!String(req.headers['content-type'] || '').startsWith('application/json')) {
    reply(400, {error:'content_type'}); return true;
  }
  let body = '', tooLarge = false;
  req.setEncoding('utf8');
  req.on('data', chunk => {
    if (tooLarge) return;
    body += chunk;
    if (body.length > 8 * 1024 * 1024) { tooLarge = true; body = ''; }
  });
  req.on('end', async () => {
    if (tooLarge) { reply(413, {error:'too_large'}); return; }
    let data;
    try { data = JSON.parse(body); } catch { reply(400, {error:'invalid_json'}); return; }
    if (!data || typeof data.session !== 'string' || !/^[a-zA-Z0-9_-]{1,80}$/.test(data.session) || !Array.isArray(data.samples)) {
      reply(400, {error:'invalid_capture'}); return;
    }
    try {
      await fs.promises.mkdir(directory, {recursive:true});
      const destination = path.join(directory, data.session + '.json');
      const temporary = path.join(directory, data.session + '.tmp');
      await fs.promises.writeFile(temporary, JSON.stringify(data));
      await fs.promises.rename(temporary, destination);
      reply(200, {saved:true, file:data.session + '.json'});
    } catch { reply(500, {error:'write_failed'}); }
  });
  return true;
}
module.exports = {handlePerformanceCapture};
