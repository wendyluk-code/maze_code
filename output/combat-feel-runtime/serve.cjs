const {createServer}=require('./profile-server.cjs');
const server=createServer();server.on('error',e=>{console.error(e);process.exitCode=1});
server.listen(8777,'127.0.0.1',()=>console.log(JSON.stringify({url:'http://127.0.0.1:8777/',pid:process.pid})));
process.on('SIGINT',()=>server.close());
