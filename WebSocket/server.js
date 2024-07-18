const http = require('http');
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');

// 创建 HTTP 服务器
const server = http.createServer((request, response) => {
  let filePath = '.' + request.url;
  if (filePath === './') {
    filePath = './client.html';
  }

  const extname = String(path.extname(filePath)).toLowerCase();
  const mimeTypes = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.wasm': 'application/wasm',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
  };

  const contentType = mimeTypes[extname] || 'application/octet-stream';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      if (error.code === 'ENOENT') {
        response.writeHead(404, { 'Content-Type': 'text/plain' });
        response.end('404 Not Found', 'utf-8');
      } else {
        response.writeHead(500);
        response.end(`Sorry, check with the site admin for error: ${error.code}`);
      }
    } else {
      response.writeHead(200, {
        'Content-Type': contentType,
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
      });
      response.end(content, 'utf-8');
    }
  });
});

// 创建 WebSocket 服务器并附加到 HTTP 服务器上
const wss = new WebSocket.Server({ server });

wss.on('connection', ws => {
  console.log('Client connected');

  ws.on('message', message => {
    console.log(`Received: ${message}`);
    ws.send('Hello from server');
  });

  ws.on('close', () => {
    console.log('Client disconnected');
  });
});

// 启动 HTTP 服务器
server.listen(8080, () => {
  console.log('Server running at http://127.0.0.1:8080/');
});