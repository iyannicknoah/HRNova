require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { initializeApp, cert, applicationDefault, getApps } = require('firebase-admin/app');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Firebase Admin init ──────────────────────────────────────────────────────
const serviceAccountPath = path.join(__dirname, process.env.FIREBASE_PRIVATE_KEY_PATH || './hrnova-6b7d8-firebase-adminsdk-fbsvc-75268fae3e.json');

if (!getApps().length) {
  if (fs.existsSync(serviceAccountPath)) {
    initializeApp({
      credential: cert(require(serviceAccountPath)),
    });
  } else {
    initializeApp({
      credential: applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID,
    });
  }
}

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/auth',      require('./routes/auth'));
app.use('/api/storage',   require('./routes/storage'));
app.use('/api/companies', require('./routes/companies'));
app.use('/api/branches',  require('./routes/branches'));
app.use('/api/employees', require('./routes/employees'));

// ── Health check ─────────────────────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), service: 'HRNova API' });
});

// ── 404 handler ───────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ── Error handler ─────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`HRNova API running on http://localhost:${PORT}`);
  console.log(`Health: http://localhost:${PORT}/api/health`);
});

module.exports = app;
