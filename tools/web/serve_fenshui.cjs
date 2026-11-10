const http = require('node:http');
const https = require('node:https');
const fs = require('node:fs');
const path = require('node:path');
const root = fs.realpathSync(process.argv[2]);
const port = Number(process.argv[3] || 8086);
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.ico':'image/x-icon','.svg':'image/svg+xml','.json':'application/json'};
const handler = (req,res) => {
  if (!['GET','HEAD'].includes(req.method)) { res.writeHead(405); return res.end(); }
  let name;
  try { name = decodeURIComponent(new URL(req.url,'http://localhost').pathname); } catch { res.writeHead(400); return res.end(); }
  name = name === '/' ? 'index.html' : name.slice(1);
  // Godot导出的公开文件均在同一层，不提供目录枚举、仓库或任意磁盘路径。
  if (!name || name !== path.basename(name) || name.includes('..') || name.includes('\\')) { res.writeHead(404); return res.end(); }
  const file = path.join(root,name);
  fs.stat(file,(error,stat) => {
    if (error || !stat.isFile()) { res.writeHead(404); return res.end(); }
    res.writeHead(200,{'Content-Type':types[path.extname(name)] || 'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});
    if (req.method === 'HEAD') return res.end();
    const stream=fs.createReadStream(file);
    stream.on('error',()=>res.destroy());stream.pipe(res);
  });
};
const server = process.argv[4] ? https.createServer({cert:fs.readFileSync(process.argv[4]),key:fs.readFileSync(process.argv[5])},handler) : http.createServer(handler);
server.on('error',error=>{console.error(error);process.exit(1);});
server.listen(port,'0.0.0.0',()=>console.log(JSON.stringify({ready:true,pid:process.pid,root,port,started_at:new Date().toISOString()})));
