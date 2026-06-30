const express = require('express');
const router = express.Router();
const multer = require('multer');
const { verifyToken } = require('../middleware/verifyToken');
const storageService = require('../services/storageService');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// Upload profile photo → Cloudflare R2
// POST /api/storage/upload-photo
router.post('/upload-photo', verifyToken, upload.single('photo'), async (req, res) => {
  // Scaffold — implementation in Part 4
  res.json({ message: 'upload-photo scaffold' });
});

// Upload CV → Cloudflare R2
// POST /api/storage/upload-cv
router.post('/upload-cv', upload.single('cv'), async (req, res) => {
  // Scaffold — implementation in Part 10
  res.json({ message: 'upload-cv scaffold' });
});

// Delete file from R2
// DELETE /api/storage/delete
router.delete('/delete', verifyToken, async (req, res) => {
  // Scaffold
  res.json({ message: 'delete scaffold' });
});

module.exports = router;
