const express = require('express');
const router  = express.Router();
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getApp } = require('firebase-admin/app');
const { verifyToken, requireRole } = require('../middleware/verifyToken');

const db = () => getFirestore(getApp(), 'default');

// Every route in this file requires super_admin
router.use(verifyToken, requireRole('super_admin'));

// ── List all companies ────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const snap = await db().collection('companies').orderBy('createdAt', 'desc').get();
    res.json({ companies: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Create company + HR admin user ────────────────────────────────────────────
router.post('/create', async (req, res) => {
  const {
    name, companyType, industry, address, contactPerson,
    hrAdminEmail, hrAdminPhone,
    employeeCount, monthlyPrice, tinNumber, tempPassword,
    firstBranchName, firstBranchLocation, firstBranchCode,
  } = req.body;

  if (!name || !hrAdminEmail || !tempPassword)
    return res.status(400).json({ error: 'name, hrAdminEmail and tempPassword are required' });
  if (tempPassword.length < 8)
    return res.status(400).json({ error: 'Temporary password must be at least 8 characters' });

  const store = db();
  const isMulti = companyType === 'multi_branch';

  try {
    // 1. Firestore company doc
    const coRef = store.collection('companies').doc();
    const slug  = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    await coRef.set({
      name, slug,
      companyType: isMulti ? 'multi_branch' : 'single',
      industry:      industry      || '',
      address:       address       || '',
      contactPerson: contactPerson || '',
      hrAdminEmail,
      hrAdminPhone:  hrAdminPhone  || '',
      employeeCount: parseInt(employeeCount) || 0,
      monthlyPrice:  parseInt(monthlyPrice)  || 0,
      tinNumber:     tinNumber     || '',
      status: 'active',
      createdAt: FieldValue.serverTimestamp(),
    });

    // 2. Firebase Auth user
    const role        = isMulti ? 'group_hr_admin' : 'hr_admin';
    const displayName = contactPerson || `${name} HR Admin`;
    const hrUser = await getAuth().createUser({ email: hrAdminEmail, password: tempPassword, displayName });
    await getAuth().setCustomUserClaims(hrUser.uid, {
      role, companyId: coRef.id, companyName: name,
      companyType: isMulti ? 'multi_branch' : 'single', displayName,
    });
    await getAuth().revokeRefreshTokens(hrUser.uid);

    // 3. First branch (multi-branch only)
    let branchResult = null;
    if (isMulti && firstBranchName) {
      const brRef = coRef.collection('branches').doc();
      await brRef.set({
        name: firstBranchName,
        location: firstBranchLocation || '',
        code:     firstBranchCode     || '',
        companyId: coRef.id,
        status: 'active',
        createdAt: FieldValue.serverTimestamp(),
      });
      branchResult = { branchId: brRef.id, name: firstBranchName };
    }

    res.json({
      success: true,
      companyId:    coRef.id,
      companyName:  name,
      hrAdminUid:   hrUser.uid,
      hrAdminEmail,
      role,
      branch: branchResult,
    });
  } catch (e) {
    console.error('Create company:', e);
    if (e.code === 'auth/email-already-exists')
      return res.status(400).json({ error: 'That email address is already registered' });
    res.status(500).json({ error: e.message });
  }
});

// ── Get single company ────────────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    const doc = await db().collection('companies').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Company not found' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Update company fields ─────────────────────────────────────────────────────
router.put('/:id', async (req, res) => {
  const allowed = ['name','industry','address','contactPerson','hrAdminPhone',
                   'employeeCount','monthlyPrice','tinNumber'];
  const patch = {};
  allowed.forEach(k => { if (req.body[k] !== undefined) patch[k] = req.body[k]; });
  patch.updatedAt = FieldValue.serverTimestamp();
  try {
    await db().collection('companies').doc(req.params.id).update(patch);
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Activate / Suspend ────────────────────────────────────────────────────────
router.put('/:id/status', async (req, res) => {
  const { status } = req.body;
  if (!['active', 'suspended'].includes(status))
    return res.status(400).json({ error: 'status must be active or suspended' });
  try {
    await db().collection('companies').doc(req.params.id).update({
      status,
      updatedAt: FieldValue.serverTimestamp(),
    });
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Add payment ───────────────────────────────────────────────────────────────
router.post('/:id/payment', async (req, res) => {
  const { date, amount, reference, method } = req.body;
  if (!date || !amount) return res.status(400).json({ error: 'date and amount are required' });
  const store = db();
  try {
    const payRef = store.collection('companies').doc(req.params.id).collection('payments').doc();
    const batch  = store.batch();
    batch.set(payRef, {
      date, amount: parseInt(amount),
      reference: reference || '',
      method:    method    || 'bank_transfer',
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.update(store.collection('companies').doc(req.params.id), {
      lastPaymentDate:   date,
      lastPaymentAmount: parseInt(amount),
    });
    await batch.commit();
    res.json({ success: true, paymentId: payRef.id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Get payments ──────────────────────────────────────────────────────────────
router.get('/:id/payments', async (req, res) => {
  try {
    const snap = await db().collection('companies').doc(req.params.id)
      .collection('payments').orderBy('createdAt', 'desc').get();
    res.json({ payments: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── List branches ─────────────────────────────────────────────────────────────
router.get('/:id/branches', async (req, res) => {
  try {
    const snap = await db().collection('companies').doc(req.params.id)
      .collection('branches').orderBy('createdAt').get();
    res.json({ branches: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Add branch + optional branch_hr_admin ─────────────────────────────────────
router.post('/:id/branches', async (req, res) => {
  const { name, location, code, branchAdminEmail, branchAdminPassword, branchAdminName } = req.body;
  if (!name) return res.status(400).json({ error: 'Branch name is required' });

  const store = db();
  try {
    const coDoc = await store.collection('companies').doc(req.params.id).get();
    if (!coDoc.exists) return res.status(404).json({ error: 'Company not found' });
    const co = coDoc.data();

    const brRef = store.collection('companies').doc(req.params.id).collection('branches').doc();
    await brRef.set({
      name, location: location || '', code: code || '',
      companyId: req.params.id,
      status: 'active',
      createdAt: FieldValue.serverTimestamp(),
    });

    let adminResult = null;
    if (branchAdminEmail && branchAdminPassword) {
      const dName = branchAdminName || `${name} HR Admin`;
      const brUser = await getAuth().createUser({
        email: branchAdminEmail, password: branchAdminPassword, displayName: dName,
      });
      await getAuth().setCustomUserClaims(brUser.uid, {
        role: 'branch_hr_admin',
        companyId: req.params.id, branchId: brRef.id,
        companyName: co.name, companyType: 'multi_branch', displayName: dName,
      });
      await getAuth().revokeRefreshTokens(brUser.uid);
      adminResult = { uid: brUser.uid, email: branchAdminEmail };
    }

    res.json({ success: true, branchId: brRef.id, admin: adminResult });
  } catch (e) {
    if (e.code === 'auth/email-already-exists')
      return res.status(400).json({ error: 'That email is already registered' });
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
