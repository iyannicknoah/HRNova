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

  // Reserve a company ID and an employee-doc ID locally (no write yet) so
  // the Auth user's custom claims can reference both before anything is
  // written to Firestore.
  const coRef  = store.collection('companies').doc();
  const empRef = coRef.collection('employees').doc();
  const role        = isMulti ? 'group_hr_admin' : 'hr_admin';
  const displayName = contactPerson || `${name} HR Admin`;
  const qrCode = `${coRef.id}_${empRef.id}`;

  let hrUser;
  try {
    // 1. Firebase Auth user — created first. If this fails, nothing has
    //    been written to Firestore, so there's no orphaned company left
    //    behind with no matching account.
    hrUser = await getAuth().createUser({ email: hrAdminEmail, password: tempPassword, displayName });
    await getAuth().setCustomUserClaims(hrUser.uid, {
      role, companyId: coRef.id, companyName: name,
      companyType: isMulti ? 'multi_branch' : 'single', displayName,
      employeeId: empRef.id,
    });
    await getAuth().revokeRefreshTokens(hrUser.uid);
  } catch (e) {
    console.error('Create company (auth step):', e);
    if (e.code === 'auth/email-already-exists')
      return res.status(400).json({ error: 'That email address is already registered' });
    return res.status(500).json({ error: e.message });
  }

  try {
    // 2. Firestore company doc
    const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
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

    // 4. Employee doc for the HR admin — same shape/defaults as a normal
    //    employee created via the Add Employee flow, but only pre-filled
    //    with what's known at this point. `profileComplete: false` marks
    //    it as needing the follow-up completion step in the UI.
    const [empFirstName, ...empLastNameParts] = displayName.trim().split(/\s+/);
    await empRef.set({
      firstName: empFirstName || '',
      lastName: empLastNameParts.join(' '),
      email: hrAdminEmail,
      phone: hrAdminPhone || '',
      role,
      companyId: coRef.id,
      qrCode,
      department: '',
      jobTitle: '',
      nationalId: '',
      emergencyContact: '',
      contractType: 'permanent',
      startDate: new Date().toISOString(),
      rssbNumber: '',
      salaryType: 'fixed_monthly',
      salaryAmount: 0,
      dailyRate: 0,
      hourlyRate: 0,
      transportAllowance: 0,
      housingAllowance: 0,
      bankAccount: '',
      bankCode: '',
      leaveBalances: { annual: 18, sick: 10, maternity: 84, paternity: 4 },
      loans: [],
      status: 'active',
      profileComplete: false,
      uid: hrUser.uid,
      initialPassword: tempPassword,
      createdAt: FieldValue.serverTimestamp(),
    });

    res.json({
      success: true,
      companyId:    coRef.id,
      companyName:  name,
      hrAdminUid:   hrUser.uid,
      hrAdminEmail,
      employeeId:   empRef.id,
      role,
      branch: branchResult,
    });
  } catch (e) {
    // Firestore write failed after the Auth account was already created —
    // delete the orphaned Auth user so a retry doesn't hit
    // "email already exists" for an account that never actually got a company.
    console.error('Create company (firestore step):', e);
    await getAuth().deleteUser(hrUser.uid).catch(() => {});
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
                   'employeeCount','monthlyPrice','tinNumber','companyType',
                   'billingStatus','billingStatusPeriod'];
  const patch = {};
  allowed.forEach(k => { if (req.body[k] !== undefined) patch[k] = req.body[k]; });
  patch.updatedAt = FieldValue.serverTimestamp();
  try {
    await db().collection('companies').doc(req.params.id).update(patch);
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Delete company (cascades: all Auth accounts + all Firestore data) ─────────
router.delete('/:id', async (req, res) => {
  const store = db();
  const companyId = req.params.id;
  try {
    const coDoc = await store.collection('companies').doc(companyId).get();
    if (!coDoc.exists) return res.status(404).json({ error: 'Company not found' });
    const co = coDoc.data();

    // 1. Collect and delete every Firebase Auth account tied to this company:
    //    the company's own HR admin, every employee (incl. managers/branch HR
    //    admins added as employees), and every branch's HR admin.
    const uidsToDelete = new Set();
    const emailsToDelete = new Set();

    if (co.hrAdminEmail) emailsToDelete.add(co.hrAdminEmail);

    const empSnap = await store.collection('companies').doc(companyId).collection('employees').get();
    empSnap.docs.forEach(d => {
      const emp = d.data();
      if (emp.uid) uidsToDelete.add(emp.uid);
      else if (emp.email) emailsToDelete.add(emp.email);
    });

    const branchSnap = await store.collection('companies').doc(companyId).collection('branches').get();
    branchSnap.docs.forEach(d => {
      const br = d.data();
      if (br.branchHrAdminUid) uidsToDelete.add(br.branchHrAdminUid);
      else if (br.branchHrAdminEmail) emailsToDelete.add(br.branchHrAdminEmail);
    });

    for (const email of emailsToDelete) {
      try {
        const user = await getAuth().getUserByEmail(email.trim().toLowerCase());
        uidsToDelete.add(user.uid);
      } catch (_) { /* already gone / never existed — fine */ }
    }
    await Promise.allSettled([...uidsToDelete].map(uid => getAuth().deleteUser(uid)));

    // 2. Recursively delete the company document and every subcollection
    //    (employees, branches, payments, payroll, attendance, leave, etc.)
    await store.recursiveDelete(store.collection('companies').doc(companyId));

    console.log(`[Companies] Deleted company ${companyId} (${co.name}) — ${uidsToDelete.size} auth accounts removed`);
    res.json({ success: true, authAccountsDeleted: uidsToDelete.size });
  } catch (e) {
    console.error('Delete company:', e);
    res.status(500).json({ error: e.message });
  }
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
      // Reserve the employee-doc ID before creating the Auth user so its
      // custom claims can reference it, same pattern as company creation.
      const empRef = store.collection('companies').doc(req.params.id).collection('employees').doc();
      const qrCode = `${req.params.id}_${empRef.id}`;
      let brUser;
      try {
        brUser = await getAuth().createUser({
          email: branchAdminEmail, password: branchAdminPassword, displayName: dName,
        });
        await getAuth().setCustomUserClaims(brUser.uid, {
          role: 'branch_hr_admin',
          companyId: req.params.id, branchId: brRef.id,
          companyName: co.name, companyType: 'multi_branch', displayName: dName,
          employeeId: empRef.id,
        });
        await getAuth().revokeRefreshTokens(brUser.uid);

        // Employee doc for the branch HR admin — same shape/defaults as a
        // normal employee, pre-filled with what's known here.
        const [empFirstName, ...empLastNameParts] = dName.trim().split(/\s+/);
        await empRef.set({
          firstName: empFirstName || '',
          lastName: empLastNameParts.join(' '),
          email: branchAdminEmail,
          phone: '',
          role: 'branch_hr_admin',
          companyId: req.params.id,
          branchId: brRef.id,
          qrCode,
          department: '',
          jobTitle: '',
          nationalId: '',
          emergencyContact: '',
          contractType: 'permanent',
          startDate: new Date().toISOString(),
          rssbNumber: '',
          salaryType: 'fixed_monthly',
          salaryAmount: 0,
          dailyRate: 0,
          hourlyRate: 0,
          transportAllowance: 0,
          housingAllowance: 0,
          bankAccount: '',
          bankCode: '',
          leaveBalances: { annual: 18, sick: 10, maternity: 84, paternity: 4 },
          loans: [],
          status: 'active',
          profileComplete: false,
          uid: brUser.uid,
          initialPassword: branchAdminPassword,
          createdAt: FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Roll back the Auth user if it was created but the employee doc
        // write (or claims) failed, mirroring company creation's safety net.
        if (brUser) await getAuth().deleteUser(brUser.uid).catch(() => {});
        throw e;
      }
      adminResult = { uid: brUser.uid, email: branchAdminEmail, employeeId: empRef.id };
    }

    res.json({ success: true, branchId: brRef.id, admin: adminResult });
  } catch (e) {
    if (e.code === 'auth/email-already-exists')
      return res.status(400).json({ error: 'That email is already registered' });
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
