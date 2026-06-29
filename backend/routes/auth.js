const express = require('express');
const router = express.Router();
const { getAuth } = require('firebase-admin/auth');
const { getApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const verifyToken = require('../middleware/verifyToken');

// POST /api/auth/set-claims
// Only works if the calling user is a super admin
router.post('/set-claims', verifyToken, async (req, res) => {
  const { uid, role, companyId, isSuperAdmin } = req.body;

  if (!uid || !role) {
    return res.status(400).json({ error: 'Missing required parameters: uid, role' });
  }

  // Authorize check: caller must be a super_admin OR the bootstrapping initial admin
  const callerClaims = req.user;
  const isInitialAdminBootstrap = callerClaims.email === 'admin@hrnova.rw' && uid === callerClaims.uid;
  
  if (!callerClaims.isSuperAdmin && callerClaims.role !== 'super_admin' && !isInitialAdminBootstrap) {
    return res.status(403).json({ error: 'Forbidden: Only Super Admins can set user claims' });
  }

  try {
    const claims = { role, companyId };
    if (isSuperAdmin !== undefined) {
      claims.isSuperAdmin = isSuperAdmin;
    }

    await getAuth().setCustomUserClaims(uid, claims);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error setting custom claims:', error.message);
    return res.status(500).json({ error: 'Failed to set user claims: ' + error.message });
  }
});

// POST /api/auth/create-user
// Creates a Firebase Auth user and sets their custom claims immediately
// Also provisions the company document in Firestore atomically if details are provided
router.post('/create-user', async (req, res) => {
  const {
    email,
    password,
    role,
    companyId,
    displayName,
    companyName,
    industry,
    address,
    hrAdminPhone,
    employeeCount,
    monthlyPrice
  } = req.body;

  if (!email || !password || !role) {
    return res.status(400).json({ error: 'Missing required parameters: email, password, role' });
  }

  try {
    const db = getFirestore(getApp(), 'default');

    // 1. If company details are provided, provision the company document first
    if (companyName && companyId) {
      console.log(`Provisioning company document for ${companyName} (${companyId})...`);
      const companyRef = db.collection('companies').doc(companyId);
      await companyRef.set({
        name: companyName,
        industry: industry || 'Factory',
        address: address || '',
        contactPerson: displayName || '',
        hrAdminEmail: email,
        hrAdminPhone: hrAdminPhone || '',
        employeeCount: parseInt(employeeCount) || 0,
        monthlyPrice: parseInt(monthlyPrice) || 0,
        status: 'active',
        createdAt: new Date(),
      });
      console.log(`Successfully provisioned company ${companyName}.`);
    }

    // 2. Create the user in Firebase Auth
    const userRecord = await getAuth().createUser({
      email,
      password,
      displayName,
    });

    // 3. Set custom claims immediately
    const claims = { role, companyId };
    if (role === 'super_admin') {
      claims.isSuperAdmin = true;
    }
    
    await getAuth().setCustomUserClaims(userRecord.uid, claims);

    return res.status(201).json({
      uid: userRecord.uid,
      success: true,
    });
  } catch (error) {
    console.error('Error creating user:', error);
    // Attempt cleanup if company was created but user failed
    if (companyName && companyId) {
      try {
        const db = getFirestore(getApp(), 'default');
        await db.collection('companies').doc(companyId).delete();
        console.log(`Cleaned up company ${companyId} due to user creation failure.`);
      } catch (cleanupErr) {
        console.error('Error during cleanup:', cleanupErr.message);
      }
    }
    return res.status(500).json({ error: 'Failed to create user: ' + error.message });
  }
});

module.exports = router;
