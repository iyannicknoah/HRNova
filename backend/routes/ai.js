const express = require('express');
const router = express.Router();
const verifyToken = require('../middleware/verifyToken');
const { generatePerformanceReview, generateAnnualPerformance } = require('../services/aiService');

// POST /api/ai/generate-review
router.post('/generate-review', verifyToken, async (req, res) => {
  try {
    const { employeeName, jobTitle, criteria, scores, overallScore } = req.body;
    if (!employeeName || !criteria || !scores) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    const review = await generatePerformanceReview({ employeeName, jobTitle, criteria, scores, overallScore });
    res.json({ review });
  } catch (e) {
    console.error('AI review error:', e.message);
    res.status(500).json({ error: 'Failed to generate review. Please try again.' });
  }
});

// POST /api/ai/annual-performance
router.post('/annual-performance', verifyToken, async (req, res) => {
  try {
    const { employee, monthlyScores, attendanceSummary } = req.body;
    if (!employee || !monthlyScores) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    const narrative = await generateAnnualPerformance({
      employee,
      monthlyScores,
      attendanceSummary: attendanceSummary || {},
    });
    res.json({ narrative });
  } catch (e) {
    console.error('Annual performance error:', e.message);
    res.status(500).json({ error: 'Failed to generate annual report. Please try again.' });
  }
});

module.exports = router;
