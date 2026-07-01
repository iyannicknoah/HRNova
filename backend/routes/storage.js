const express = require('express');
const router = express.Router();
const multer = require('multer');
const { verifyToken } = require('../middleware/verifyToken');
const { uploadFile, deleteFile, buildKey } = require('../services/storageService');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// POST /api/storage/upload-photo
// Body: multipart form with field 'photo', plus companyId and employeeId
router.post('/upload-photo', verifyToken, upload.single('photo'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No photo file provided' });

    const companyId = req.body.companyId || req.user.companyId;
    const employeeId = req.body.employeeId || `unknown_${Date.now()}`;

    if (!companyId) return res.status(400).json({ error: 'companyId is required' });

    const ext = req.file.mimetype === 'image/png' ? 'png' : 'jpg';
    const filename = `${employeeId}_${Date.now()}.${ext}`;
    const key = buildKey(companyId, 'profiles', filename);

    const url = await uploadFile(key, req.file.buffer, req.file.mimetype);
    res.json({ url, key });
  } catch (err) {
    console.error('upload-photo error:', err);
    res.status(500).json({ error: err.message || 'Upload failed' });
  }
});

// POST /api/storage/delete-batch
// Body: { keys: string[] }
router.post('/delete-batch', verifyToken, async (req, res) => {
  try {
    const { keys } = req.body;
    if (!Array.isArray(keys) || keys.length === 0) {
      return res.status(400).json({ error: 'keys array is required' });
    }

    const results = await Promise.allSettled(keys.map((k) => deleteFile(k)));
    const deleted = results.filter((r) => r.status === 'fulfilled').length;
    const failed = results.filter((r) => r.status === 'rejected').length;

    res.json({ deleted, failed });
  } catch (err) {
    console.error('delete-batch error:', err);
    res.status(500).json({ error: err.message || 'Delete failed' });
  }
});

// POST /api/storage/upload-cv  (scaffold for Part 10)
router.post('/upload-cv', upload.single('cv'), async (_req, res) => {
  res.json({ message: 'upload-cv scaffold — Part 10' });
});

module.exports = router;
