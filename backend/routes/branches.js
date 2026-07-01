const express = require('express');
const router  = express.Router();
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getApp } = require('firebase-admin/app');
const { verifyToken, requireRole } = require('../middleware/verifyToken');

const db = () => getFirestore(getApp(), 'default');

// Group HR Admin (and hr_admin for read)
router.use(verifyToken, requireRole('group_hr_admin', 'hr_admin', 'super_admin'));

// ── List branches for the calling company ────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const snap = await db()
      .collection('companies').doc(req.companyId)
      .collection('branches').orderBy('createdAt').get();
    res.json({ branches: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Create branch + optional branch_hr_admin account ────────────────────────
router.post('/', requireRole('group_hr_admin', 'hr_admin', 'super_admin'), async (req, res) => {
  const { name, location, branchCode, adminEmail, adminPassword, adminName } = req.body;
  if (!name) return res.status(400).json({ error: 'Branch name is required' });

  const companyId = req.companyId;
  const store = db();

  try {
    const coDoc = await store.collection('companies').doc(companyId).get();
    const coName = coDoc.data()?.name ?? '';

    const brRef = store.collection('companies').doc(companyId).collection('branches').doc();
    await brRef.set({
      name,
      location:   location   || '',
      branchCode: branchCode || '',
      companyId,
      isActive: true,
      employeeCount: 0,
      createdAt: FieldValue.serverTimestamp(),
    });

    let adminResult = null;
    if (adminEmail && adminPassword) {
      const dName = adminName || `${name} HR Admin`;
      const brUser = await getAuth().createUser({
        email: adminEmail, password: adminPassword, displayName: dName,
      });
      await getAuth().setCustomUserClaims(brUser.uid, {
        role: 'branch_hr_admin',
        companyId, branchId: brRef.id,
        companyName: coName, companyType: 'multi_branch', displayName: dName,
      });
      await getAuth().revokeRefreshTokens(brUser.uid);
      await brRef.update({ branchHrAdminUid: brUser.uid, branchHrAdminEmail: adminEmail });
      adminResult = { uid: brUser.uid, email: adminEmail };
    }

    res.json({ success: true, branchId: brRef.id, admin: adminResult });
  } catch (e) {
    if (e.code === 'auth/email-already-exists')
      return res.status(400).json({ error: 'That email is already registered' });
    res.status(500).json({ error: e.message });
  }
});

// ── Update branch ────────────────────────────────────────────────────────────
router.put('/:branchId', requireRole('group_hr_admin', 'super_admin'), async (req, res) => {
  const allowed = ['name', 'location', 'branchCode'];
  const patch = {};
  allowed.forEach(k => { if (req.body[k] !== undefined) patch[k] = req.body[k]; });
  patch.updatedAt = FieldValue.serverTimestamp();
  try {
    await db().collection('companies').doc(req.companyId)
      .collection('branches').doc(req.params.branchId).update(patch);
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Activate / Suspend branch ─────────────────────────────────────────────────
router.put('/:branchId/status', requireRole('group_hr_admin', 'super_admin'), async (req, res) => {
  const { isActive } = req.body;
  if (typeof isActive !== 'boolean')
    return res.status(400).json({ error: 'isActive must be true or false' });
  try {
    await db().collection('companies').doc(req.companyId)
      .collection('branches').doc(req.params.branchId)
      .update({ isActive, updatedAt: FieldValue.serverTimestamp() });
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
