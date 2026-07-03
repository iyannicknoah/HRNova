const express = require('express');
const router = express.Router();
const { getFirestore } = require('firebase-admin/firestore');
const { getApp } = require('firebase-admin/app');
const { verifyToken, requireRole } = require('../middleware/verifyToken');
const { generateRRAPayeExport, generateRSSBExport } = require('../services/rraExportService');
const { sendPayslipEmail } = require('../services/emailService');

const db = () => getFirestore(getApp(), 'default');
const ALLOWED = requireRole('hr_admin', 'director', 'finance_manager', 'super_admin');

router.use(verifyToken);

function _guardCompany(req, res, companyId) {
  if (req.role !== 'super_admin' && req.companyId !== companyId) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
}

// ── GET /api/exports/rra-paye/:companyId/:month ───────────────────────────────
router.get('/rra-paye/:companyId/:month', ALLOWED, async (req, res) => {
  try {
    const { companyId, month } = req.params;
    if (!_guardCompany(req, res, companyId)) return;

    const buffer = await generateRRAPayeExport(companyId, month);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="RRA_PAYE_${month}.xlsx"`);
    res.send(buffer);
  } catch (err) {
    console.error('[Exports] PAYE export error:', err);
    res.status(500).json({ error: err.message || 'Export failed' });
  }
});

// ── GET /api/exports/rssb/:companyId/:month ───────────────────────────────────
router.get('/rssb/:companyId/:month', ALLOWED, async (req, res) => {
  try {
    const { companyId, month } = req.params;
    if (!_guardCompany(req, res, companyId)) return;

    const buffer = await generateRSSBExport(companyId, month);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="RSSB_${month}.xlsx"`);
    res.send(buffer);
  } catch (err) {
    console.error('[Exports] RSSB export error:', err);
    res.status(500).json({ error: err.message || 'Export failed' });
  }
});

// ── POST /api/exports/send-payslip ────────────────────────────────────────────
// Body: { employeeId, payrollMonth, pdfBase64 }
// Flutter client generates the PDF and sends it base64-encoded so Brevo can attach it.
router.post('/send-payslip', ALLOWED, async (req, res) => {
  try {
    const { employeeId, payrollMonth, pdfBase64 } = req.body;
    const companyId = req.companyId;
    if (!employeeId || !payrollMonth || !companyId) {
      return res.status(400).json({ error: 'employeeId and payrollMonth are required' });
    }

    const fireDb = db();

    // Load employee for email address and name
    const empSnap = await fireDb.collection('companies').doc(companyId)
      .collection('employees').doc(employeeId).get();
    if (!empSnap.exists) return res.status(404).json({ error: 'Employee not found' });

    const emp = empSnap.data();
    const employeeEmail = emp.email || emp.workEmail;
    if (!employeeEmail) {
      return res.status(400).json({ error: 'Employee has no email address on file' });
    }

    const employeeName = `${emp.firstName ?? ''} ${emp.lastName ?? ''}`.trim();
    const monthLabel = new Date(payrollMonth + '-01')
      .toLocaleDateString('en-US', { year: 'numeric', month: 'long' });

    // Send via Brevo with PDF attachment
    await sendPayslipEmail({
      employeeEmail,
      employeeName,
      payrollMonth: monthLabel,
      pdfBase64: pdfBase64 || null,
      pdfFilename: `Payslip_${employeeName.replace(/\s+/g, '_')}_${payrollMonth}.pdf`,
    });

    // Mark email sent in Firestore
    await fireDb.collection('companies').doc(companyId)
      .collection('payroll').doc(payrollMonth)
      .collection('payslips').doc(employeeId)
      .update({ emailSent: true });

    res.json({ ok: true, sent: employeeEmail });
  } catch (err) {
    console.error('[Exports] Send payslip error:', err);
    res.status(500).json({ error: err.message || 'Send failed' });
  }
});

module.exports = router;
