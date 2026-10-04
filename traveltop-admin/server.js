const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = 3001;
const DATA_FILE = path.join(__dirname, 'data.json');

// ── Middleware ────────────────────────────────────────────────────
app.use(cors({ origin: '*' }));
app.use(express.json());

// ── SSE client tracking ───────────────────────────────────────────
const sseClients = new Set();

function broadcastUpdate(data) {
  const payload = `data: ${JSON.stringify(data)}\n\n`;
  sseClients.forEach(client => {
    try { client.write(payload); } catch (_) { sseClients.delete(client); }
  });
}

// ── Helpers ───────────────────────────────────────────────────────
function readData() {
  return JSON.parse(fs.readFileSync(DATA_FILE, 'utf-8'));
}
function writeData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf-8');
}

// ── REST API ──────────────────────────────────────────────────────

// GET all data
app.get('/api/data', (req, res) => {
  res.json(readData());
});

// PUT full data replace
app.put('/api/data', (req, res) => {
  writeData(req.body);
  broadcastUpdate(req.body);
  res.json({ ok: true });
});

// PATCH splash
app.patch('/api/splash', (req, res) => {
  const data = readData();
  data.splash = { ...data.splash, ...req.body };
  writeData(data);
  broadcastUpdate(data);
  res.json({ ok: true });
});

// PATCH categories
app.put('/api/categories', (req, res) => {
  const data = readData();
  data.categories = req.body;
  writeData(data);
  broadcastUpdate(data);
  res.json({ ok: true });
});

// POST new destination
app.post('/api/destinations', (req, res) => {
  const data = readData();
  const item = { id: 'd' + Date.now(), ...req.body };
  data.destinations.push(item);
  writeData(data);
  broadcastUpdate(data);
  res.json(item);
});

// PUT update destination
app.put('/api/destinations/:id', (req, res) => {
  const data = readData();
  const idx = data.destinations.findIndex(d => d.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'Not found' });
  data.destinations[idx] = { ...data.destinations[idx], ...req.body };
  writeData(data);
  broadcastUpdate(data);
  res.json(data.destinations[idx]);
});

// DELETE destination
app.delete('/api/destinations/:id', (req, res) => {
  const data = readData();
  data.destinations = data.destinations.filter(d => d.id !== req.params.id);
  writeData(data);
  broadcastUpdate(data);
  res.json({ ok: true });
});

// POST new agent
app.post('/api/agents', (req, res) => {
  const data = readData();
  const item = { id: 'a' + Date.now(), ...req.body };
  data.agents.push(item);
  writeData(data);
  broadcastUpdate(data);
  res.json(item);
});

// PUT update agent
app.put('/api/agents/:id', (req, res) => {
  const data = readData();
  const idx = data.agents.findIndex(a => a.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'Not found' });
  data.agents[idx] = { ...data.agents[idx], ...req.body };
  writeData(data);
  broadcastUpdate(data);
  res.json(data.agents[idx]);
});

// DELETE agent
app.delete('/api/agents/:id', (req, res) => {
  const data = readData();
  data.agents = data.agents.filter(a => a.id !== req.params.id);
  writeData(data);
  broadcastUpdate(data);
  res.json({ ok: true });
});

// SSE stream for real-time push to Flutter app
app.get('/api/events', (req, res) => {
  res.set({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*',
  });
  res.flushHeaders();

  // Send current data immediately on connect
  const data = readData();
  res.write(`data: ${JSON.stringify(data)}\n\n`);

  sseClients.add(res);
  console.log(`SSE client connected. Total: ${sseClients.size}`);

  // Keep-alive ping every 20s
  const ping = setInterval(() => {
    try { res.write(': ping\n\n'); } catch (_) {}
  }, 20000);

  req.on('close', () => {
    sseClients.delete(res);
    clearInterval(ping);
    console.log(`SSE client disconnected. Total: ${sseClients.size}`);
  });
});

// Admin panel
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'admin.html'));
});

app.get('/', (req, res) => res.redirect('/admin'));

app.listen(PORT, () => {
  console.log(`\n✅ TravelTop Admin Server running at http://localhost:${PORT}`);
  console.log(`   Admin Dashboard : http://localhost:${PORT}/admin`);
  console.log(`   API Data        : http://localhost:${PORT}/api/data`);
  console.log(`   SSE Events      : http://localhost:${PORT}/api/events\n`);
});
