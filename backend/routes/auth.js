const express = require('express');
const router = express.Router();
const { getAuth } = require('firebase-admin/auth');
const { verifyToken, requireRole } = require('../middleware/verifyToken');

// ── POST /api/auth/set-claims ──────────────────────────────────────────────
// Sets Firebase Auth custom claims for a user.
// Accessible by super_admin or via X-Setup-Key header for initial setup.
router.post('/set-claims', async (req, res) => {
  try {
    // Allow initial setup via secret key
    const setupKey = req.headers['x-setup-key'];
    const isSetupKey = setupKey && setupKey === (process.env.SETUP_KEY || 'hrnova-setup-2026');

    if (!isSetupKey) {
      // Must be authenticated super_admin
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authorization required' });
      }
      const token = authHeader.split('Bearer ')[1];
      const decoded = await getAuth().verifyIdToken(token);
      if (!decoded.isSuperAdmin && decoded.role !== 'super_admin') {
        return res.status(403).json({ error: 'Super admin access required' });
      }
    }

    const { uid, role, companyId, branchId, companyType, isSuperAdmin, displayName } = req.body;

    if (!uid || !role) {
      return res.status(400).json({ error: 'uid and role are required' });
    }

    const claims = { role };
    if (companyId) claims.companyId = companyId;
    if (branchId) claims.branchId = branchId;
    if (companyType) claims.companyType = companyType;
    if (isSuperAdmin) claims.isSuperAdmin = true;
    if (displayName) claims.displayName = displayName;

    await getAuth().setCustomUserClaims(uid, claims);

    // Force token refresh on next sign-in by revoking existing sessions
    await getAuth().revokeRefreshTokens(uid);

    console.log(`[Auth] Claims set for ${uid}: ${JSON.stringify(claims)}`);
    res.json({ success: true, uid, claims });
  } catch (err) {
    console.error('[Auth] set-claims error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /api/auth/create-user ─────────────────────────────────────────────
// Creates a Firebase Auth user and sets custom claims.
// Callable by hr_admin, branch_hr_admin, group_hr_admin, super_admin.
router.post('/create-user', verifyToken, async (req, res) => {
  try {
    const { role: callerRole } = req;
    const allowedCallers = ['super_admin', 'hr_admin', 'group_hr_admin', 'branch_hr_admin'];

    if (!allowedCallers.includes(callerRole)) {
      return res.status(403).json({ error: 'Insufficient permissions to create users' });
    }

    const { email, password, role, companyId, branchId, companyType, displayName, employeeId } = req.body;

    if (!email || !password || !role || !companyId) {
      return res.status(400).json({
        error: 'email, password, role, and companyId are required',
      });
    }

    // HR admin can only create users in their own company
    if (callerRole !== 'super_admin' && req.companyId !== companyId) {
      return res.status(403).json({ error: 'Cannot create users in another company' });
    }

    // Create Firebase Auth user
    const userRecord = await getAuth().createUser({
      email: email.trim().toLowerCase(),
      password,
      displayName: displayName || email.split('@')[0],
    });

    // Set custom claims
    const claims = { role, companyId };
    if (employeeId) claims.employeeId = employeeId;
    if (branchId) claims.branchId = branchId;
    if (companyType) claims.companyType = companyType;
    if (displayName) claims.displayName = displayName;

    await getAuth().setCustomUserClaims(userRecord.uid, claims);

    console.log(`[Auth] User created: ${userRecord.uid} (${email}) role=${role}`);
    res.json({ success: true, uid: userRecord.uid, email: userRecord.email });
  } catch (err) {
    console.error('[Auth] create-user error:', err);

    if (err.code === 'auth/email-already-exists') {
      return res.status(409).json({ error: 'This email is already registered' });
    }
    if (err.code === 'auth/weak-password') {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }
    res.status(500).json({ error: err.message });
  }
});

// ── POST /api/auth/refresh-claims ─────────────────────────────────────────
// Forces a claims refresh for the calling user (call after role changes).
router.post('/refresh-claims', verifyToken, async (req, res) => {
  try {
    await getAuth().revokeRefreshTokens(req.uid);
    res.json({ success: true, message: 'Claims refresh scheduled. Re-sign in to apply.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
