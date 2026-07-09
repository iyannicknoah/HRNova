const express = require('express');
const router = express.Router();
const multer = require('multer');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { verifyToken } = require('../middleware/verifyToken');
const { uploadFile, buildKey } = require('../services/storageService');
const { screenApplication } = require('../services/aiScreeningService');
const {
  sendApplicationConfirmationEmail,
  sendInterviewInvitationEmail,
  sendRejectionEmail,
} = require('../services/emailService');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 6 * 1024 * 1024 } });

// ── Slug helpers ──────────────────────────────────────────────────────────────
function slugify(text) {
  return text.toLowerCase().trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 60);
}

// ── PUBLIC: upload CV (no auth — called from public apply form) ───────────────
router.post('/upload-cv', upload.single('cv'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file provided' });
    if (req.file.mimetype !== 'application/pdf') {
      return res.status(400).json({ error: 'Only PDF files are accepted' });
    }

    const { companyId, jobId, applicantName } = req.body;
    if (!companyId || !jobId) return res.status(400).json({ error: 'companyId and jobId are required' });

    const safeName = slugify(applicantName || 'applicant');
    const filename = `${Date.now()}_${safeName}.pdf`;
    const key = buildKey(companyId, `cvs/${jobId}`, filename);
    const url = await uploadFile(key, req.file.buffer, 'application/pdf');

    res.json({ url, key });
  } catch (err) {
    console.error('[upload-cv]', err);
    res.status(500).json({ error: err.message || 'Upload failed' });
  }
});

// ── PUBLIC: job board for company ─────────────────────────────────────────────
router.get('/public/company/:companySlug', async (req, res) => {
  try {
    const db = getFirestore('default');
    const { companySlug } = req.params;

    const snap = await db.collection('companies')
      .where('slug', '==', companySlug)
      .where('status', '==', 'active')
      .limit(1).get();

    if (snap.empty) return res.status(404).json({ error: 'Company not found' });

    const companyDoc = snap.docs[0];
    const company = companyDoc.data();
    const companyId = companyDoc.id;

    const jobsSnap = await db.collection('companies').doc(companyId)
      .collection('jobs')
      .where('status', '==', 'open')
      .orderBy('createdAt', 'desc')
      .get();

    const jobs = jobsSnap.docs.map(d => ({ id: d.id, ...d.data() }));

    res.json({
      company: {
        id: companyId,
        name: company.name,
        industry: company.industry || '',
        slug: company.slug || companySlug,
      },
      jobs,
    });
  } catch (err) {
    console.error('[public-jobs]', err);
    res.status(500).json({ error: err.message });
  }
});

// ── PUBLIC: single job details ─────────────────────────────────────────────────
router.get('/public/job/:companySlug/:jobSlug', async (req, res) => {
  try {
    const db = getFirestore('default');
    const { companySlug, jobSlug } = req.params;

    const compSnap = await db.collection('companies')
      .where('slug', '==', companySlug)
      .limit(1).get();
    if (compSnap.empty) return res.status(404).json({ error: 'Company not found' });

    const companyId = compSnap.docs[0].id;
    const companyName = compSnap.docs[0].data().name || '';

    const jobSnap = await db.collection('companies').doc(companyId)
      .collection('jobs')
      .where('jobSlug', '==', jobSlug)
      .where('status', '==', 'open')
      .limit(1).get();

    if (jobSnap.empty) return res.status(404).json({ error: 'Job not found or no longer open' });

    const job = { id: jobSnap.docs[0].id, ...jobSnap.docs[0].data() };
    res.json({ job, companyId, companyName });
  } catch (err) {
    console.error('[public-job]', err);
    res.status(500).json({ error: err.message });
  }
});

// ── PUBLIC: submit application ────────────────────────────────────────────────
router.post('/public/apply', async (req, res) => {
  try {
    const db = getFirestore('default');
    const { companyId, jobId, jobTitle, applicantName, email, phone,
            yearsExperience, coverLetter, cvUrl, cvKey, certUrl, certKey, companyName } = req.body;

    if (!companyId || !jobId || !applicantName || !email || !phone) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const appRef = await db.collection('companies').doc(companyId)
      .collection('applications').add({
        companyId, jobId,
        jobTitle: jobTitle || '',
        applicantName, email, phone,
        yearsExperience: Number(yearsExperience) || 0,
        coverLetter: coverLetter || '',
        cvUrl: cvUrl || null,
        cvKey: cvKey || null,
        certUrl: certUrl || null,
        certKey: certKey || null,
        status: 'pending',
        rejectionConfirmedByHR: false,
        aiStrengths: [],
        aiConcerns: [],
        appliedAt: new Date(),
      });

    // Increment totalApplications on job
    try {
      await db.collection('companies').doc(companyId)
        .collection('jobs').doc(jobId)
        .update({ totalApplications: FieldValue.increment(1) });
    } catch (_) {}

    // Async: send confirmation email (fire and forget)
    if (email) {
      sendApplicationConfirmationEmail({
        applicantEmail: email,
        applicantName,
        jobTitle: jobTitle || 'the position',
        companyName: companyName || 'the company',
      }).catch(e => console.error('[apply email]', e.message));
    }

    // Async: trigger AI screening (fire and forget)
    if (cvKey) {
      screenApplication(appRef.id, companyId, jobId)
        .catch(e => console.error('[screening]', e.message));
    }

    res.json({ applicationId: appRef.id, message: 'Application submitted successfully' });
  } catch (err) {
    console.error('[apply]', err);
    res.status(500).json({ error: err.message });
  }
});

// ── All routes below require auth ─────────────────────────────────────────────
router.use(verifyToken);

// ── Jobs CRUD ─────────────────────────────────────────────────────────────────

// GET /api/recruitment/jobs
router.get('/jobs', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.query.companyId || req.user.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    const snap = await db.collection('companies').doc(companyId)
      .collection('jobs')
      .orderBy('createdAt', 'desc')
      .get();

    const jobs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json({ jobs });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/recruitment/jobs/:jobId
router.get('/jobs/:jobId', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.query.companyId || req.user.companyId;
    const doc = await db.collection('companies').doc(companyId)
      .collection('jobs').doc(req.params.jobId).get();
    if (!doc.exists) return res.status(404).json({ error: 'Job not found' });
    res.json({ job: { id: doc.id, ...doc.data() } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/recruitment/jobs — create job
router.post('/jobs', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.body.companyId || req.user.companyId;
    if (!companyId) return res.status(400).json({ error: 'companyId required' });

    const { title, status } = req.body;
    if (!title) return res.status(400).json({ error: 'title is required' });

    // Get company info for slug generation
    const companyDoc = await db.collection('companies').doc(companyId).get();
    const companyName = companyDoc.data()?.name || '';

    let companySlug = companyDoc.data()?.slug;
    if (!companySlug) {
      companySlug = slugify(companyName);
      await db.collection('companies').doc(companyId).update({ slug: companySlug });
    }
    const jobSlug = slugify(title) + '-' + Date.now().toString(36);
    const publicUrl = `https://hrnova-6b7d8.web.app/apply/${companySlug}/${jobSlug}`;

    const jobData = {
      companyId,
      title: req.body.title,
      department: req.body.department || '',
      description: req.body.description || '',
      requirements: req.body.requirements || '',
      requiredSkills: req.body.requiredSkills || [],
      minExperience: Number(req.body.minExperience) || 0,
      aiCriteria: req.body.aiCriteria || '',
      salaryMin: req.body.salaryMin ? Number(req.body.salaryMin) : null,
      salaryMax: req.body.salaryMax ? Number(req.body.salaryMax) : null,
      showSalary: req.body.showSalary === true || req.body.showSalary === 'true',
      deadline: req.body.deadline || null,
      status: status || 'draft',
      companySlug,
      jobSlug,
      publicUrl,
      companyName,
      totalApplications: 0,
      shortlistedCount: 0,
      createdAt: new Date(),
    };

    const ref = await db.collection('companies').doc(companyId).collection('jobs').add(jobData);
    res.json({ jobId: ref.id, publicUrl, companySlug, jobSlug });
  } catch (err) {
    console.error('[create-job]', err);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/recruitment/jobs/:jobId — update job
router.put('/jobs/:jobId', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.body.companyId || req.user.companyId;

    const allowed = ['title', 'department', 'description', 'requirements',
      'requiredSkills', 'minExperience', 'aiCriteria', 'salaryMin', 'salaryMax',
      'showSalary', 'deadline', 'status'];

    const update = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) update[key] = req.body[key];
    }
    update.updatedAt = new Date();

    await db.collection('companies').doc(companyId)
      .collection('jobs').doc(req.params.jobId).update(update);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Applications ──────────────────────────────────────────────────────────────

// GET /api/recruitment/jobs/:jobId/applications
router.get('/jobs/:jobId/applications', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.query.companyId || req.user.companyId;

    const snap = await db.collection('companies').doc(companyId)
      .collection('applications')
      .where('jobId', '==', req.params.jobId)
      .orderBy('appliedAt', 'desc')
      .get();

    const applications = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    // Sort by AI score descending (nulls last)
    applications.sort((a, b) => (b.aiScore ?? -1) - (a.aiScore ?? -1));

    res.json({ applications });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/recruitment/applications/:appId
router.get('/applications/:appId', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.query.companyId || req.user.companyId;

    const snap = await db.collection('companies').doc(companyId)
      .collection('applications').doc(req.params.appId).get();

    if (!snap.exists) return res.status(404).json({ error: 'Application not found' });
    res.json({ application: { id: snap.id, ...snap.data() } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/recruitment/applications/:appId/shortlist
router.put('/applications/:appId/shortlist', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.body.companyId || req.user.companyId;
    const { jobId, sendInvite, interviewDate, interviewTime, interviewLocation } = req.body;

    const appRef = db.collection('companies').doc(companyId)
      .collection('applications').doc(req.params.appId);

    const update = { status: 'shortlisted', shortlistedAt: new Date() };
    if (interviewDate) update.interviewDate = interviewDate;
    if (interviewTime) update.interviewTime = interviewTime;
    if (interviewLocation) update.interviewLocation = interviewLocation;

    await appRef.update(update);

    // Increment shortlistedCount on job
    if (jobId) {
      await db.collection('companies').doc(companyId)
        .collection('jobs').doc(jobId)
        .update({ shortlistedCount: FieldValue.increment(1) });
    }

    // Send interview invitation email if requested
    if (sendInvite && interviewDate) {
      const appSnap = await appRef.get();
      const app = appSnap.data();
      const jobSnap = jobId
        ? await db.collection('companies').doc(companyId).collection('jobs').doc(jobId).get()
        : null;

      await appRef.update({ interviewInviteSentAt: new Date() });

      sendInterviewInvitationEmail({
        applicantEmail: app.email,
        applicantName: app.applicantName,
        jobTitle: app.jobTitle || jobSnap?.data()?.title || 'the position',
        companyName: jobSnap?.data()?.companyName || '',
        interviewDate,
        interviewTime: interviewTime || '',
        interviewLocation: interviewLocation || 'To be communicated',
      }).catch(e => console.error('[interview invite]', e.message));
    }

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/recruitment/applications/:appId/decline
// Marks rejectionConfirmedByHR: true — does NOT send email
router.put('/applications/:appId/decline', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.body.companyId || req.user.companyId;

    await db.collection('companies').doc(companyId)
      .collection('applications').doc(req.params.appId)
      .update({ status: 'declined', rejectionConfirmedByHR: true, declinedAt: new Date() });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/recruitment/jobs/:jobId/send-rejections
// Sends rejection emails to all HR-confirmed declined applicants who haven't been emailed yet
router.post('/jobs/:jobId/send-rejections', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.body.companyId || req.user.companyId;

    const snap = await db.collection('companies').doc(companyId)
      .collection('applications')
      .where('jobId', '==', req.params.jobId)
      .where('status', '==', 'declined')
      .where('rejectionConfirmedByHR', '==', true)
      .get();

    const toSend = snap.docs.filter(d => !d.data().rejectionSentAt);

    const results = await Promise.allSettled(
      toSend.map(async (doc) => {
        const app = doc.data();
        await sendRejectionEmail({
          applicantEmail: app.email,
          applicantName: app.applicantName,
          jobTitle: app.jobTitle || 'the position',
          companyName: req.body.companyName || '',
        });
        await doc.ref.update({ rejectionSentAt: new Date() });
      })
    );

    const sent = results.filter(r => r.status === 'fulfilled').length;
    const failed = results.filter(r => r.status === 'rejected').length;

    res.json({ sent, failed, total: toSend.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/recruitment/screen-application (re-trigger AI screening)
router.post('/screen-application', async (req, res) => {
  const { applicationId, companyId, jobId } = req.body;
  if (!applicationId || !companyId || !jobId) {
    return res.status(400).json({ error: 'applicationId, companyId, jobId required' });
  }
  // Trigger async, respond immediately
  screenApplication(applicationId, companyId, jobId)
    .catch(e => console.error('[screen-application]', e.message));

  res.json({ message: 'Screening started' });
});

// GET /api/recruitment/stats — dashboard metrics
router.get('/stats', async (req, res) => {
  try {
    const db = getFirestore('default');
    const companyId = req.query.companyId || req.user.companyId;

    const [jobsSnap, appsSnap] = await Promise.all([
      db.collection('companies').doc(companyId).collection('jobs').get(),
      db.collection('companies').doc(companyId).collection('applications').get(),
    ]);

    const jobs = jobsSnap.docs.map(d => d.data());
    const apps = appsSnap.docs.map(d => d.data());

    res.json({
      openPositions: jobs.filter(j => j.status === 'open').length,
      totalApplications: apps.length,
      shortlisted: apps.filter(a => a.status === 'shortlisted').length,
      hired: apps.filter(a => a.status === 'hired').length,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
