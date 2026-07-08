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
    const name  = await _companyName(db, companyId);

    // Always load full company snapshot — no keyword guessing
    const [
      empSnap, branchSnap, deptSnap, pendingLeaveSnap, approvedLeaveSnap,
      perfSnap, payrollSnap, todayAttSnap,
    ] = await Promise.all([
      db.collection('companies').doc(companyId).collection('employees').get().catch(() => ({ docs: [] })),
      db.collection('companies').doc(companyId).collection('branches').get().catch(() => ({ docs: [] })),
      db.collection('companies').doc(companyId).collection('departments').get().catch(() => ({ docs: [] })),
      db.collection('companies').doc(companyId).collection('leave_requests').where('status', '==', 'pending').get().catch(() => ({ docs: [], size: 0 })),
      db.collection('companies').doc(companyId).collection('leave_requests').where('status', '==', 'approved').where('startDate', '>=', `${month}-01`).get().catch(() => ({ docs: [] })),
      db.collection('companies').doc(companyId).collection('performance').where('month', '==', month).get().catch(() => ({ docs: [] })),
      db.collection('companies').doc(companyId).collection('payroll_runs').where('month', '==', month).limit(1).get().catch(() => ({ docs: [] })),
      db.collection('companies').doc(companyId).collection('attendance').where('date', '==', today).get().catch(() => ({ docs: [] })),
    ]);

    // Employees
    const allEmps = empSnap.docs.map(d => d.data());
    const activeEmps = allEmps.filter(e => e.status === 'active');
    const filteredEmps = branchId ? activeEmps.filter(e => e.branchId === branchId) : activeEmps;

    // Departments breakdown
    const deptMap = {};
    for (const e of filteredEmps) {
      const dept = e.department || 'Unknown';
      deptMap[dept] = (deptMap[dept] || 0) + 1;
    }

    // Branches
    const branches = branchSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    const branchEmpCount = {};
    for (const b of branches) {
      branchEmpCount[b.name || b.id] = activeEmps.filter(e => e.branchId === b.id).length;
    }

    // Today's attendance
    const todayRecs = branchId
      ? todayAttSnap.docs.filter(d => d.data().branchId === branchId)
      : todayAttSnap.docs;
    const presentToday = todayRecs.filter(d => d.data().checkInTime && !d.data().isAbsent).length;
    const lateToday    = todayRecs.filter(d => d.data().isLate && !d.data().isAbsent).length;
    const absentToday  = todayRecs.filter(d => d.data().isAbsent).length;
    const onLeaveToday = todayRecs.filter(d => d.data().isOnLeave).length;
    const totalToday   = filteredEmps.length;
    const attRateToday = totalToday > 0 ? ((presentToday / totalToday) * 100).toFixed(1) : 0;

    // Leave
    const pendingLeaves = pendingLeaveSnap.docs
      .filter(d => !branchId || d.data().branchId === branchId)
      .map(d => ({ employee: d.data().employeeName, type: d.data().leaveType, days: d.data().totalDays, dept: d.data().department }));
    const approvedLeaveByType = {};
    for (const d of approvedLeaveSnap.docs) {
      const t = d.data().leaveType || 'other';
      approvedLeaveByType[t] = (approvedLeaveByType[t] || 0) + (d.data().totalDays || 1);
    }

    // Performance
    const perfRecs = branchId
      ? perfSnap.docs.filter(d => d.data().branchId === branchId)
      : perfSnap.docs;
    const scores = perfRecs.map(d => d.data().overallScore || 0).filter(s => s > 0);
    const avgScore = scores.length > 0 ? (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(2) : null;
    const topPerformers = perfRecs
      .map(d => d.data())
      .sort((a, b) => (b.overallScore || 0) - (a.overallScore || 0))
      .slice(0, 5)
      .map(r => `${r.employeeName} (${r.department}): ${r.overallScore}/5`);
    const needsImprovement = perfRecs
      .map(d => d.data())
      .filter(r => (r.overallScore || 5) < 3)
      .map(r => `${r.employeeName} (${r.department}): ${r.overallScore}/5`);

    // Payroll
    const payroll = payrollSnap.docs[0]?.data() || null;

    // Build the full context object for Nova
    const ctx = {
      companyName: name,
      today,
      currentMonth: month,
      employees: {
        total: allEmps.length,
        active: filteredEmps.length,
        byDepartment: deptMap,
        list: filteredEmps.slice(0, 30).map(e => ({
          name: e.fullName || e.name,
          department: e.department,
          branch: e.branchName || branches.find(b => b.id === e.branchId)?.name,
          jobTitle: e.jobTitle,
          status: e.status,
        })),
      },
      branches: {
        total: branches.length,
        list: branches.map(b => b.name || b.id),
        employeesPerBranch: branchEmpCount,
      },
      todayAttendance: {
        date: today,
        totalEmployees: totalToday,
        present: presentToday,
        late: lateToday,
        absent: absentToday,
        onLeave: onLeaveToday,
        attendanceRate: `${attRateToday}%`,
      },
      leave: {
        pendingCount: pendingLeaves.length,
        pendingRequests: pendingLeaves.slice(0, 10),
        approvedThisMonth: approvedLeaveByType,
      },
      performance: scores.length > 0 ? {
        month,
        reviewedCount: scores.length,
        averageScore: avgScore,
        topPerformers,
        needsImprovement,
        excellent: scores.filter(s => s >= 4.5).length,
        good: scores.filter(s => s >= 3 && s < 4.5).length,
        poor: scores.filter(s => s < 3).length,
      } : { month, message: 'No performance reviews recorded this month' },
      payroll: payroll ? {
        month,
        employeesOnPayroll: payroll.employeeCount,
        totalNetPaid: `RWF ${Math.round(payroll.totalNet || 0).toLocaleString()}`,
        totalGross: `RWF ${Math.round(payroll.totalGross || 0).toLocaleString()}`,
        totalPAYE: `RWF ${Math.round(payroll.totalPAYE || 0).toLocaleString()}`,
        totalRSSB: `RWF ${Math.round(payroll.totalRSSB || 0).toLocaleString()}`,
      } : { month, message: 'No payroll run found for this month' },
    };

    const { answerQuestion } = require('../services/aiService');
    const answer = await answerQuestion(question, ctx, name);
    res.json({ answer });
  } catch (e) {
    console.error('[Reports] ask:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /api/reports/performance ───────────────────────────────────────────
router.post('/performance', verifyToken, async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.body.companyId || req.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    const month = req.body.month || _currentMonth();
    const branchId = req.body.branchId || null;

    let pQ = db.collection('companies').doc(companyId).collection('performance')
      .where('month', '==', month);
    if (branchId) pQ = pQ.where('branchId', '==', branchId);

    const [pSnap, name] = await Promise.all([pQ.get(), _companyName(db, companyId)]);
    const records = pSnap.docs.map(d => d.data());
    const scores = records.map(r => r.overallScore || 0).filter(s => s > 0);
    const avg = scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0;

    const summary = {
      month, branchId,
      totalReviewed: records.length,
      averageScore: +avg.toFixed(2),
      excellent: scores.filter(s => s >= 4.5).length,
      good: scores.filter(s => s >= 3 && s < 4.5).length,
      poor: scores.filter(s => s < 3).length,
      topPerformers: records
        .sort((a, b) => (b.overallScore || 0) - (a.overallScore || 0))
        .slice(0, 5)
        .map(r => ({ name: r.employeeName, department: r.department, score: r.overallScore })),
    };

    const { callGemini } = require('../services/aiService');
    const tops = summary.topPerformers.map(p => `- **${p.name}** (${p.department}): **${p.score}/5**`).join('\n') || '- No top performers recorded';
    const prompt = `You are a professional HR analyst for ${name}. Write a Performance Review Report for ${month}.

## Performance Figures
- Employees reviewed: **${summary.totalReviewed}**
- Average performance score: **${summary.averageScore}/5**
- Excellent ratings (≥4.5): **${summary.excellent}**
- Good ratings (3–4.5): **${summary.good}**
- Needs improvement (<3): **${summary.poor}**

## Top Performers
${tops}

Format rules:
- Use ## for section headings
- Bold key numbers like **12** or **4.2/5**
- Write in complete paragraphs — no bullet lists for narrative
- Do not repeat the title in the body
- Use simple, clear English — short sentences, everyday words
- Write like you are explaining to a colleague, not writing an academic paper

Write 3 paragraphs: (1) overall performance summary using the exact numbers, (2) highlight the top performers by name and mention anyone who needs improvement, (3) one clear and practical recommendation for next month. Rwanda HR context.`;

    const report = await callGemini(prompt, 1500);

    const docId = branchId ? `${month}_performance_${branchId}` : `${month}_performance`;
    await db.collection('companies').doc(companyId).collection('reports').doc(docId).set({
      type: 'performance', month, branchId: branchId || null, summary, report,
      generatedAt: new Date(), generatedBy: req.uid,
    });

    res.json({ report, summary, docId });
  } catch (e) {
    console.error('[Reports] performance:', e.message);
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
