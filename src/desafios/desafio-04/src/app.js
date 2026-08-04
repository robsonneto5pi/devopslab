'use strict';

const http = require('http');
const os   = require('os');

const PORT    = parseInt(process.env.PORT || '3000', 10);
const ENV     = process.env.NODE_ENV || 'development';
const WARM_UP = 3000; // ms

const state = {
  startTime: Date.now(),
  requests:  0,
  ready:     false,
};

setTimeout(() => { state.ready = true; }, WARM_UP);

// ── helpers ──────────────────────────────────────────────
function uptime()   { return Math.floor((Date.now() - state.startTime) / 1000); }
function hostname() { return os.hostname(); }

function json(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

function text(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'text/plain; version=0.0.4', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

// ── request handler ───────────────────────────────────────
function handler(req, res) {
  state.requests++;

  const url = req.url.split('?')[0];

  if (req.method === 'GET' && url === '/') {
    return json(res, 200, {
      app:      'DevOps Lab — Desafio 4',
      version:  'v1.0',
      env:      ENV,
      uptime:   uptime(),
      requests: state.requests,
      hostname: hostname(),
    });
  }

  if (req.method === 'GET' && url === '/health') {
    return json(res, 200, {
      status:    'ok',
      uptime:    uptime(),
      timestamp: new Date().toISOString(),
      env:       ENV,
    });
  }

  if (req.method === 'GET' && url === '/health/ready') {
    if (!state.ready) return json(res, 503, { status: 'not_ready' });
    return json(res, 200, { status: 'ready' });
  }

  if (req.method === 'GET' && url === '/metrics') {
    const heapUsed = process.memoryUsage().heapUsed;
    const body = [
      `# HELP app_requests_total Total number of HTTP requests`,
      `# TYPE app_requests_total counter`,
      `app_requests_total ${state.requests}`,
      `# HELP app_uptime_seconds Application uptime in seconds`,
      `# TYPE app_uptime_seconds gauge`,
      `app_uptime_seconds ${uptime()}`,
      `# HELP nodejs_heap_used_bytes Node.js heap memory used`,
      `# TYPE nodejs_heap_used_bytes gauge`,
      `nodejs_heap_used_bytes ${heapUsed}`,
      '',
    ].join('\n');
    return text(res, 200, body);
  }

  return json(res, 404, { error: 'not found', path: url });
}

// ── server ────────────────────────────────────────────────
const server = http.createServer(handler);

server.listen(PORT, () => {
  console.log(`[devops-app] listening on port ${PORT} (${ENV})`);
});

// ── graceful shutdown ─────────────────────────────────────
function shutdown(signal) {
  console.log(`[devops-app] received ${signal} — shutting down gracefully`);
  server.close(() => {
    console.log('[devops-app] server closed');
    process.exit(0);
  });
  setTimeout(() => { process.exit(1); }, 10000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
