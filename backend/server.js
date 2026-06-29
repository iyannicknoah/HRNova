require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initializeApp, cert } = require('firebase-admin/app');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[HTTP] ${req.method} ${req.url} - Body:`, JSON.stringify(req.body));
  next();
});

// Initialize Firebase Admin SDK
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './serviceAccount.json';
const resolvedPath = path.resolve(__dirname, serviceAccountPath);

if (fs.existsSync(resolvedPath)) {
  try {
    initializeApp({
      credential: cert(require(resolvedPath)),
    });
    console.log('Firebase Admin SDK initialized successfully.');
  } catch (error) {
    console.error('Error initializing Firebase Admin SDK:', error.message);
  }
} else {
  console.error(`CRITICAL: Firebase Service Account file not found at ${resolvedPath}`);
}

// Routes
const authRouter = require('./routes/auth');
app.use('/api/auth', authRouter);

const storageRoutes = require('./routes/storage');
app.use('/api/storage', storageRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date() });
});

// Root route
app.get('/', (req, res) => {
  res.send('HRNova Express Backend is Running!');
});

// Start Server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
