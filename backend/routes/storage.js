/**
 * Storage Routes — /api/storage
 * Handles photo uploads to Cloudflare R2 and batch deletions.
 */

const express = require('express');
const router = express.Router();
const multer = require('multer');
const storageService = require('../services/storageService');
const verifyToken = require('../middleware/verifyToken');

// Use memory storage so we get req.file.buffer
const upload = multer({ storage: multer.memoryStorage() });

/**
 * POST /api/storage/upload-photo
 * Upload an attendance photo (check-in or check-out) to Cloudflare R2.
 *
 * Body (multipart/form-data):
 *   - photo: file (image/jpeg)
 *   - companyId: string
 *   - employeeId: string
 *   - photoType: 'checkin' | 'checkout'
 *
 * Returns: { url, key }
 */
router.post('/upload-photo', verifyToken, upload.single('photo'), async (req, res) => {
  try {
    const { companyId, employeeId, photoType } = req.body;

    if (!req.file) {
      return res.status(400).json({ error: 'No photo file provided.' });
    }
    if (!companyId || !employeeId || !photoType) {
      return res.status(400).json({ error: 'Missing required fields: companyId, employeeId, photoType.' });
    }

    // Build a date-partitioned key
    const now = new Date();
    const dateStr = now.toISOString().slice(0, 10); // YYYY-MM-DD
    const key = `${companyId}/attendance/${dateStr}/${employeeId}_${photoType}_${now.getTime()}.jpg`;

    const url = await storageService.uploadFile(req.file.buffer, key, 'image/jpeg');

    console.log(`[Storage Route] Photo uploaded — key: ${key}, size: ${req.file.buffer.length} bytes`);
    return res.status(200).json({ url, key });
  } catch (err) {
    console.error('[Storage Route] Upload error:', err);
    return res.status(500).json({ error: 'Failed to upload photo.', details: err.message });
  }
});

/**
 * DELETE /api/storage/delete-batch
 * Delete multiple R2 objects at once.
 *
 * Body: { keys: string[] }
 * Returns: { deleted: number }
 */
router.delete('/delete-batch', verifyToken, async (req, res) => {
  try {
    const { keys } = req.body;

    if (!Array.isArray(keys) || keys.length === 0) {
      return res.status(400).json({ error: 'keys must be a non-empty array.' });
    }

    await storageService.deleteFiles(keys);
    return res.status(200).json({ deleted: keys.length });
  } catch (err) {
    console.error('[Storage Route] Delete batch error:', err);
    return res.status(500).json({ error: 'Failed to delete files.', details: err.message });
  }
});

module.exports = router;
