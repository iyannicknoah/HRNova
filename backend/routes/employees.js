const express = require('express');
const router = express.Router();
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getApp } = require('firebase-admin/app');
const { FieldValue } = require('firebase-admin/firestore');
const { verifyToken, requireRole } = require('../middleware/verifyToken');

const db = () => getFirestore(getApp(), 'default');

router.use(verifyToken);

const employeesRef = (companyId) =>
  db().collection('companies').doc(companyId).collection('employees');

const settingsRef = (companyId) =>
  db().collection('companies').doc(companyId).collection('settings').doc('config');

// GET /api/employees
router.get('/', async (req, res) => {
  try {
    const { companyId, role, branchId } = req;

    let query = employeesRef(companyId).where('status', '!=', 'deleted');

    if ((role === 'branch_hr_admin' || role === 'manager') && branchId) {
      query = employeesRef(companyId)
        .where('branchId', '==', branchId)
        .where('status', '!=', 'deleted');
    } else {
      if (req.query.status) query = query.where('status', '==', req.query.status);
      if (req.query.department) query = query.where('department', '==', req.query.department);
      if (req.query.branchId) query = query.where('branchId', '==', req.query.branchId);
    }

    const snap = await query.orderBy('firstName').get();
    const employees = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    res.json(employees);
  } catch (err) {
    console.error('GET /employees:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/employees/qr/:qrCode  (must be before /:employeeId)
router.get('/qr/:qrCode', async (req, res) => {
  try {
    const snap = await employeesRef(req.companyId)
      .where('qrCode', '==', req.params.qrCode)
      .limit(1)
      .get();
    if (snap.empty) return res.status(404).json({ error: 'Employee not found' });
    const doc = snap.docs[0];
    res.json({ id: doc.id, ...doc.data() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/employees/:employeeId
router.get('/:employeeId', async (req, res) => {
  try {
    const doc = await employeesRef(req.companyId).doc(req.params.employeeId).get();
    if (!doc.exists) return res.status(404).json({ error: 'Employee not found' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/employees
router.post('/', requireRole('hr_admin', 'group_hr_admin', 'branch_hr_admin', 'super_admin'), async (req, res) => {
  try {
    const { companyId } = req;
    const { role: empRole, email, firstName, lastName, ...rest } = req.body;

    const settingsDoc = await settingsRef(companyId).get();
    const settings = settingsDoc.data() || {};
    const leaveBalances = {
      annual:    settings.annualLeaveDays ?? 18,
      sick:      settings.sickLeaveDays ?? 10,
      maternity: 84,
      paternity: 4,
    };

    const docRef = employeesRef(companyId).doc();
    const docId = docRef.id;
    const qrCode = `${companyId}_${docId}`;

    await docRef.set({
      ...rest,
      firstName,
      lastName,
      email: email || '',
      role: empRole || 'employee',
      companyId,
      qrCode,
      status: 'active',
      leaveBalances,
      loans: [],
      createdAt: new Date().toISOString(),
    });

    let tempPassword = null;
    if (email) {
      try {
        // Generate a readable temp password: first 4 of companyId + @ + first 6 of docId
        tempPassword = `${companyId.substring(0, 4)}@${docId.substring(0, 6)}`;
        const authUser = await getAuth().createUser({
          email,
          password: tempPassword,
          displayName: `${firstName} ${lastName}`,
        });
        const claims = {
          companyId,
          role: empRole || 'employee',
          employeeId: docId,
        };
        // Propagate companyType so Flutter can detect multi-branch
        if (settings.companyType) claims.companyType = settings.companyType;
        // Manager in multi-branch: set branchId claim so they only see their branch
        if (empRole === 'manager' && rest.branchId) {
          claims.branchId = rest.branchId;
        }
        await getAuth().setCustomUserClaims(authUser.uid, claims);
        await docRef.update({ uid: authUser.uid });
      } catch (authErr) {
        console.warn('Auth account creation failed (non-fatal):', authErr.message);
        tempPassword = null;
      }
    }

    res.status(201).json({ id: docId, qrCode, tempPassword });
  } catch (err) {
    console.error('POST /employees:', err);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/employees/:employeeId
router.put('/:employeeId', requireRole('hr_admin', 'group_hr_admin', 'branch_hr_admin', 'super_admin'), async (req, res) => {
  try {
    // Strip immutable fields
    const { id, qrCode, createdAt, companyId: _cid, ...updates } = req.body;
    await employeesRef(req.companyId).doc(req.params.employeeId).update({
      ...updates,
      updatedAt: new Date().toISOString(),
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/employees/:employeeId/status
router.put('/:employeeId/status', requireRole('hr_admin', 'group_hr_admin', 'super_admin'), async (req, res) => {
  try {
    const { status } = req.body;
    if (!['active', 'inactive', 'deleted'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status value' });
    }
    await employeesRef(req.companyId).doc(req.params.employeeId).update({
      status,
      updatedAt: new Date().toISOString(),
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/employees/:employeeId/loans
router.post('/:employeeId/loans', requireRole('hr_admin', 'group_hr_admin', 'super_admin', 'finance_manager'), async (req, res) => {
  try {
    const { description, totalAmount, monthlyDeduction } = req.body;
    if (!description || !totalAmount) {
      return res.status(400).json({ error: 'description and totalAmount are required' });
    }
    const loan = {
      description,
      totalAmount: Number(totalAmount),
      monthlyDeduction: Number(monthlyDeduction) || 0,
      amountPaid: 0,
      startDate: new Date().toISOString(),
    };
    await employeesRef(req.companyId).doc(req.params.employeeId).update({
      loans: FieldValue.arrayUnion(loan),
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
