const express = require('express');
const router  = express.Router();
const { getFirestore } = require('firebase-admin/firestore');
const { verifyToken }  = require('../middleware/verifyToken');
const { buildDailySummary, buildWeeklySummary, buildMonthlySummary, buildGroupSummary } = require('../services/dataProcessor');
const { generateReport, answerQuestion } = require('../services/aiService');
const { sendEmail } = require('../services/emailService');

// ── helpers ──────────────────────────────────────────────────────────────────

function _today()        { return new Date().toISOString().split('T')[0]; }
function _currentMonth() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}
function _weekStart() {
  const d = new Date();
  const day = d.getDay() || 7;            // Sunday→7 so Monday is base
  d.setDate(d.getDate() - day + 1);
  return d.toISOString().split('T')[0];
}

async function _companyName(db, companyId) {
  try {
    const doc = await db.collection('companies').doc(companyId).get();
    return doc.data()?.name || 'Your Company';
  } catch { return 'Your Company'; }
}

async function _emailReport(db, companyId, reportText, typeLabel, toEmail) {
  try {
    const to = toEmail || (await db.collection('companies').doc(companyId).get()).data()?.adminEmail;
    if (!to) return;
    await sendEmail({
      to,
      toName: 'HR Admin',
      subject: `HRNova ${typeLabel} Report — ${new Date().toLocaleDateString('en-RW')}`,
      htmlContent: `<!DOCTYPE html><html><body style="font-family:sans-serif;max-width:620px;margin:auto;padding:24px">
        <h2 style="color:#1e3a5f;margin:0 0 4px">HRNova ${typeLabel} Report</h2>
        <p style="color:#64748b;font-size:12px;margin:0 0 16px">Generated ${new Date().toLocaleString('en-RW')}</p>
        <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:20px;white-space:pre-line;color:#0f172a;font-size:14px;line-height:1.75">${reportText}</div>
        <p style="color:#94a3b8;font-size:11px;margin-top:16px">Automated report from HRNova • Rwanda</p>
      </body></html>`,
    });
  } catch (e) { console.error('[Reports] email error:', e.message); }
}

// ── POST /api/reports/daily ──────────────────────────────────────────────────
router.post('/daily', verifyToken, async (req, res) => {
  try {
    const db        = getFirestore('default');
    const companyId = req.body.companyId || req.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    const date     = req.body.date     || _today();
    const branchId = req.body.branchId || null;

    const [summary, name] = await Promise.all([
      buildDailySummary(db, companyId, date, branchId),
      _companyName(db, companyId),
    ]);
    const report = await generateReport(summary, 'daily', name);

    const docId = branchId ? `${date}_daily_${branchId}` : `${date}_daily`;
    await db.collection('companies').doc(companyId).collection('reports').doc(docId).set({
      type: 'daily', date, branchId: branchId || null, summary, report,
      generatedAt: new Date(), generatedBy: req.uid,
    });

    _emailReport(db, companyId, report, 'Daily', req.user?.email);
    res.json({ report, summary, docId });
  } catch (e) {
    console.error('[Reports] daily:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /api/reports/weekly ─────────────────────────────────────────────────
router.post('/weekly', verifyToken, async (req, res) => {
  try {
    const db        = getFirestore('default');
    const companyId = req.body.companyId || req.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    const startDate = req.body.startDate || _weekStart();
    const branchId  = req.body.branchId  || null;

    const [summary, name] = await Promise.all([
      buildWeeklySummary(db, companyId, startDate, branchId),
      _companyName(db, companyId),
    ]);
    const report = await generateReport(summary, 'weekly', name);

    const docId = branchId ? `${startDate}_weekly_${branchId}` : `${startDate}_weekly`;
    await db.collection('companies').doc(companyId).collection('reports').doc(docId).set({
      type: 'weekly', startDate, branchId: branchId || null, summary, report,
      generatedAt: new Date(), generatedBy: req.uid,
    });

    _emailReport(db, companyId, report, 'Weekly', req.user?.email);
    res.json({ report, summary, docId });
  } catch (e) {
    console.error('[Reports] weekly:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /api/reports/monthly ────────────────────────────────────────────────
router.post('/monthly', verifyToken, async (req, res) => {
  try {
    const db        = getFirestore('default');
    const companyId = req.body.companyId || req.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    const month    = req.body.month    || _currentMonth();
    const branchId = req.body.branchId || null;

    const [summary, name] = await Promise.all([
      buildMonthlySummary(db, companyId, month, branchId),
      _companyName(db, companyId),
    ]);
    const report = await generateReport(summary, 'monthly', name);

    const deletionDate = new Date();
    deletionDate.setDate(deletionDate.getDate() + 14);

    const docId = branchId ? `${month}_monthly_${branchId}` : `${month}_monthly`;
    await db.collection('companies').doc(companyId).collection('reports').doc(docId).set({
      type: 'monthly', month, branchId: branchId || null, summary, report,
      photoDeletionDate: deletionDate, photosDeleted: false,
      generatedAt: new Date(), generatedBy: req.uid,
    });

    _emailReport(db, companyId, report, 'Monthly', req.user?.email);
    res.json({ report, summary, docId, photoDeletionDate: deletionDate.toISOString() });
  } catch (e) {
    console.error('[Reports] monthly:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /api/reports/group-daily ────────────────────────────────────────────
router.post('/group-daily', verifyToken, async (req, res) => {
  try {
    if (!['group_hr_admin', 'super_admin'].includes(req.role)) {
      return res.status(403).json({ error: 'Group HR Admin access required' });
    }
    const db        = getFirestore('default');
    const companyId = req.body.companyId || req.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    const date = req.body.date || _today();

    const [groupData, name] = await Promise.all([
      buildGroupSummary(db, companyId, 'daily', date),
      _companyName(db, companyId),
    ]);
    const report = await generateReport(groupData, 'daily', name, true);

    const docId = `${date}_group_daily`;
    await db.collection('companies').doc(companyId).collection('reports').doc(docId).set({
      type: 'group_daily', date, summary: groupData, report,
      generatedAt: new Date(), generatedBy: req.uid,
    });

    _emailReport(db, companyId, report, 'Group Daily', req.user?.email);
    res.json({ report, summary: groupData, docId });
  } catch (e) {
    console.error('[Reports] group-daily:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /api/reports/ask ────────────────────────────────────────────────────
router.post('/ask', verifyToken, async (req, res) => {
  try {
    const db        = getFirestore('default');
    const companyId = req.body.companyId || req.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    const { question, branchId } = req.body;
    if (!question?.trim()) return res.status(400).json({ error: 'question required' });

    const today = _today();
    const month = _currentMonth();

    const weekStartFn = () => {
      const d = new Date();
      const day = d.getDay() || 7;
      d.setDate(d.getDate() - day + 1);
      return d.toISOString().split('T')[0];
    };

    const name = await _companyName(db, companyId);
    const q    = question.toLowerCase();
    const ctx  = { today, month };

    // Populate context based on question keywords
    if (q.includes('today') || q.includes('present') || q.includes('absent') || q.includes('attendance')) {
      ctx.todayAttendance = await buildDailySummary(db, companyId, today, branchId || null);
    }
    if (q.includes('leave') || q.includes('pending')) {
      let lQ = db.collection('companies').doc(companyId).collection('leave_requests')
        .where('status', '==', 'pending');
      if (branchId) lQ = lQ.where('branchId', '==', branchId);
      const lSnap = await lQ.get().catch(() => ({ docs: [], size: 0 }));
      ctx.pendingLeaves = lSnap.size;
      ctx.pendingLeaveDetails = lSnap.docs.slice(0, 5).map(d => ({
        employee: d.data().employeeName,
        type: d.data().leaveType,
        days: d.data().totalDays,
      }));
    }
    if (q.includes('performance') || q.includes('score')) {
      let pQ = db.collection('companies').doc(companyId).collection('performance')
        .where('month', '==', month);
      if (branchId) pQ = pQ.where('branchId', '==', branchId);
      const pSnap = await pQ.get().catch(() => ({ docs: [] }));
      const scores = pSnap.docs.map(d => d.data().overallScore || 0).filter(s => s > 0);
      ctx.performance = {
        month, scoredCount: scores.length,
        avgScore: scores.length > 0 ? (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(2) : null,
      };
    }
    if (q.includes('employee') || q.includes('staff') || q.includes('active')) {
      let eQ = db.collection('companies').doc(companyId).collection('employees')
        .where('status', '==', 'active');
      if (branchId) eQ = eQ.where('branchId', '==', branchId);
      const eSnap = await eQ.get().catch(() => ({ size: 0 }));
      ctx.activeEmployees = eSnap.size;
    }
    if (q.includes('week') && !q.includes('month')) {
      ctx.weekSummary = await buildWeeklySummary(db, companyId, weekStartFn(), branchId || null);
    }
    if (q.includes('month') || q.includes('monthly')) {
      ctx.monthlySummary = await buildMonthlySummary(db, companyId, month, branchId || null);
    }

    const answer = await answerQuestion(question, ctx, name);
    res.json({ answer, context: ctx });
  } catch (e) {
    console.error('[Reports] ask:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── GET /api/reports/list ────────────────────────────────────────────────────
router.get('/list', verifyToken, async (req, res) => {
  try {
    const db        = getFirestore('default');
    const companyId = req.query.companyId || req.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    let q = db.collection('companies').doc(companyId).collection('reports')
      .orderBy('generatedAt', 'desc').limit(20);
    if (req.query.type) q = q.where('type', '==', req.query.type);
    const snap    = await q.get();
    const reports = snap.docs.map(d => ({
      id: d.id, ...d.data(),
      generatedAt: d.data().generatedAt?.toDate?.()?.toISOString(),
    }));
    res.json({ reports });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── POST /api/reports/anomaly-check ─────────────────────────────────────────
router.post('/anomaly-check', verifyToken, async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.body.companyId || req.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });
    const { buildAnomalySummary } = require('../services/dataProcessor');
    const { generateAnomalyAlert } = require('../services/aiService');
    const name = await _companyName(db, companyId);
    const result = await buildAnomalySummary(db, companyId);
    const alert = await generateAnomalyAlert(result.anomalies, name);
    await db.collection('companies').doc(companyId).collection('reports').add({
      type: 'anomaly_alert', report: alert, anomalies: result.anomalies,
      generatedAt: new Date(), generatedBy: req.uid,
    });
    _emailReport(db, companyId, alert, 'HR Anomaly Alert', req.user?.email);
    res.json({ alert, anomalies: result.anomalies });
  } catch (e) {
    console.error('[Reports] anomaly-check:', e.message);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
