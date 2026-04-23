const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const pty = require('node-pty');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);

// ── Base path support (子目录反代) ──
// 设置 BASE_PATH=/ssh 后，所有路由和静态资源自动挂载到 /ssh 下
const BASE_PATH = (process.env.BASE_PATH || '').replace(/\/+$/, '') || '';
console.log(`  📂 Base path: ${BASE_PATH || '/'}`);

const PORT = process.env.PORT || 9111;
const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

const FILES = {
  servers: path.join(DATA_DIR, 'servers.json'),
  commands: path.join(DATA_DIR, 'commands.json'),
  notes: path.join(DATA_DIR, 'notes.json'),
  settings: path.join(DATA_DIR, 'settings.json'),
};

function readJSON(f, fb = []) { try { if (fs.existsSync(f)) return JSON.parse(fs.readFileSync(f, 'utf-8')); } catch (e) {} return fb; }
function writeJSON(f, d) { fs.writeFileSync(f, JSON.stringify(d, null, 2), 'utf-8'); }

app.use(express.json({ limit: '10mb' }));

// ── API Router ──
const api = express.Router();

// Auth
api.post('/auth', (req, res) => {
  const settings = readJSON(FILES.settings, { password: '123456' });
  const pwd = req.body.password || '';
  if (pwd === (settings.password || '123456')) return res.json({ ok: true });
  return res.status(401).json({ ok: false, error: '密码错误' });
});
api.get('/auth/check', (req, res) => {
  const settings = readJSON(FILES.settings, { password: '123456' });
  res.json({ hasPassword: true, hint: '请输入密码' });
});

// Upload
api.post('/upload', (req, res) => {
  const chunks = []; req.on('data', c => chunks.push(c));
  req.on('end', () => {
    const ext = req.headers['x-ext'] || 'png';
    const name = `bg_${Date.now()}.${ext}`;
    fs.writeFileSync(path.join(DATA_DIR, name), Buffer.concat(chunks));
    res.json({ url: `${BASE_PATH}/api/files/${name}` });
  });
});
api.get('/files/:name', (req, res) => {
  const p = path.join(DATA_DIR, req.params.name);
  if (!fs.existsSync(p)) return res.status(404).end();
  res.sendFile(p);
});

// Servers
api.get('/servers', (req, res) => res.json(readJSON(FILES.servers)));
api.post('/servers', (req, res) => {
  const { name, host, port, user, type, auth, password, keyPath } = req.body;
  if (!name) return res.status(400).json({ error: 'name required' });
  const servers = readJSON(FILES.servers);
  const item = { id: uuidv4(), name, host: host || 'localhost', port: port || 22, user: user || 'root', type: type || 'local', auth: auth || 'password', password: password || '', keyPath: keyPath || '', createdAt: Date.now() };
  servers.push(item); writeJSON(FILES.servers, servers); res.json(item);
});
api.put('/servers/:id', (req, res) => {
  const servers = readJSON(FILES.servers);
  const idx = servers.findIndex(s => s.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'not found' });
  servers[idx] = { ...servers[idx], ...req.body, id: req.params.id };
  writeJSON(FILES.servers, servers); res.json(servers[idx]);
});
api.delete('/servers/:id', (req, res) => {
  writeJSON(FILES.servers, readJSON(FILES.servers).filter(s => s.id !== req.params.id)); res.json({ ok: true });
});

// Commands
api.get('/commands', (req, res) => res.json(readJSON(FILES.commands)));
api.post('/commands', (req, res) => {
  const { name, command, category } = req.body;
  if (!name || !command) return res.status(400).json({ error: 'name and command required' });
  const commands = readJSON(FILES.commands);
  const item = { id: uuidv4(), name, command, category: category || 'general', createdAt: Date.now() };
  commands.push(item); writeJSON(FILES.commands, commands); res.json(item);
});
api.put('/commands/:id', (req, res) => {
  const commands = readJSON(FILES.commands);
  const idx = commands.findIndex(c => c.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'not found' });
  commands[idx] = { ...commands[idx], ...req.body, id: req.params.id };
  writeJSON(FILES.commands, commands); res.json(commands[idx]);
});
api.delete('/commands/:id', (req, res) => {
  writeJSON(FILES.commands, readJSON(FILES.commands).filter(c => c.id !== req.params.id)); res.json({ ok: true });
});

// Notes
api.get('/notes', (req, res) => res.json(readJSON(FILES.notes)));
api.post('/notes', (req, res) => {
  const { title, content } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });
  const notes = readJSON(FILES.notes);
  const item = { id: uuidv4(), title, content: content || '', updatedAt: Date.now(), createdAt: Date.now() };
  notes.push(item); writeJSON(FILES.notes, notes); res.json(item);
});
api.put('/notes/:id', (req, res) => {
  const notes = readJSON(FILES.notes);
  const idx = notes.findIndex(n => n.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'not found' });
  notes[idx] = { ...notes[idx], ...req.body, id: req.params.id, updatedAt: Date.now() };
  writeJSON(FILES.notes, notes); res.json(notes[idx]);
});
api.delete('/notes/:id', (req, res) => {
  writeJSON(FILES.notes, readJSON(FILES.notes).filter(n => n.id !== req.params.id)); res.json({ ok: true });
});

// Settings
api.get('/settings', (req, res) => {
  const s = readJSON(FILES.settings, { theme: 'dark', password: '123456', bg: { type: 'color', value: '#0f0f1a', opacity: 1 } });
  res.json({ ...s, password: undefined });
});
api.put('/settings', (req, res) => {
  const current = readJSON(FILES.settings, { theme: 'dark', password: '123456', bg: { type: 'color', value: '#0f0f1a', opacity: 1 } });
  const updated = { ...current, ...req.body };
  writeJSON(FILES.settings, updated);
  res.json({ ...updated, password: undefined });
});

// ── Export / Import ──
api.get('/export', (req, res) => {
  const settings = readJSON(FILES.settings, {});
  res.json({
    version: 1,
    exportedAt: new Date().toISOString(),
    servers: readJSON(FILES.servers),
    commands: readJSON(FILES.commands),
    notes: readJSON(FILES.notes),
    settings: { ...settings, password: undefined },
  });
});
api.post('/import', (req, res) => {
  const data = req.body;
  if (!data || typeof data !== 'object') return res.status(400).json({ error: 'invalid data' });
  if (Array.isArray(data.servers)) writeJSON(FILES.servers, data.servers);
  if (Array.isArray(data.commands)) writeJSON(FILES.commands, data.commands);
  if (Array.isArray(data.notes)) writeJSON(FILES.notes, data.notes);
  if (data.settings && typeof data.settings === 'object') {
    const current = readJSON(FILES.settings, { password: '123456' });
    writeJSON(FILES.settings, { ...current, ...data.settings, password: current.password });
  }
  res.json({ ok: true, counts: { servers: (data.servers||[]).length, commands: (data.commands||[]).length, notes: (data.notes||[]).length } });
});

// ── Mount routes ──
app.use(`${BASE_PATH}/api`, api);

// ── Inject config into index.html and serve ──
const indexTemplate = fs.readFileSync(path.join(__dirname, 'public', 'index.html'), 'utf-8');
app.get(`${BASE_PATH}/`, (req, res) => {
  const injected = indexTemplate.replace(
    '<head>',
    `<head>\n<script>window.__BASE_PATH__ = "${BASE_PATH}";</script>`
  );
  res.type('html').send(injected);
});
app.get(`${BASE_PATH}`, (req, res) => res.redirect(`${BASE_PATH}/`));

// Static files (CDN assets in index.html are absolute, no issue)
app.use(BASE_PATH, express.static(path.join(__dirname, 'public')));

// ── WebSocket terminal ──
const wss = new WebSocket.Server({ noServer: true });

server.on('upgrade', (req, socket, head) => {
  const reqPath = req.url.split('?')[0];
  if (reqPath === `${BASE_PATH}/ws` || (BASE_PATH === '' && reqPath === '/ws')) {
    wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws, req));
  } else {
    socket.destroy();
  }
});

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://localhost');
  const shell = process.env.SHELL || '/bin/bash';
  const ptyProcess = pty.spawn(shell, [], {
    name: 'xterm-256color', cols: parseInt(url.searchParams.get('cols')) || 120, rows: parseInt(url.searchParams.get('rows')) || 30,
    cwd: process.env.HOME || '/root', env: { ...process.env, TERM: 'xterm-256color', COLORTERM: 'truecolor' },
  });

  let outputBuf = '';
  let flushTimer = null;
  function flushOutput() {
    if (outputBuf.length > 0) {
      try { ws.send(outputBuf); } catch (e) {}
      outputBuf = '';
    }
    flushTimer = null;
  }
  ptyProcess.onData(data => {
    outputBuf += data;
    if (!flushTimer) flushTimer = setTimeout(flushOutput, 8);
  });
  ptyProcess.onExit(({ exitCode }) => {
    flushOutput();
    try { ws.send(JSON.stringify({ type: 'exit', code: exitCode })); } catch (e) {}
    ws.close();
  });

  ws.on('message', msg => {
    const s = msg.toString();
    if (s[0] === '{') {
      try {
        const p = JSON.parse(s);
        if (p.type === 'resize') { ptyProcess.resize(p.cols || 120, p.rows || 30); return; }
        if (p.type === 'input') { ptyProcess.write(p.data); return; }
      } catch (e) {}
    }
    ptyProcess.write(s);
  });
  ws.on('close', () => { if (flushTimer) clearTimeout(flushTimer); ptyProcess.kill(); });
});

server.listen(PORT, '0.0.0.0', () => console.log(`\n  🚀 WebSSH → http://0.0.0.0:${PORT}${BASE_PATH}\n`));
