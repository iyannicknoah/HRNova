require('dotenv').config();

const express       = require('express');
const cors          = require('cors');
const cron          = require('node-cron');
const { initializeApp, cert, applicationDefault, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage }   = require('firebase-admin/storage');
const fs   = require('fs');
const path = require('path');
const dataProcessor  = require('./services/dataProcessor');
const aiService      = require('./services/aiService');
const { sendReportEmail } = require('./services/emailService');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Firebase Admin init ──────────────────────────────────────────────────────
const serviceAccountPath = path.join(__dirname, process.env.FIREBASE_PRIVATE_KEY_PATH || './hrnova-6b7d8-firebase-adminsdk-fbsvc-75268fae3e.json');

if (!getApps().length) {
  if (fs.existsSync(serviceAccountPath)) {
    initializeApp({
      credential: cert(require(serviceAccountPath)),
    });
  } else {
    initializeApp({
      credential: applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID,
    });
  }
}

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/auth',      require('./routes/auth'));
app.use('/api/storage',   require('./routes/storage'));
app.use('/api/companies', require('./routes/companies'));
app.use('/api/branches',  require('./routes/branches'));
app.use('/api/employees', require('./routes/employees'));
app.use('/api/exports',   require('./routes/exports'));
app.use('/api/ai',        require('./routes/ai'));
app.use('/api/reports',   require('./routes/reports'));

// ── Health check ─────────────────────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), service: 'HRNova API' });
});

// ── 404 handler ───────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ── Error handler ─────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

// ── Cron helpers ─────────────────────────────────────────────────────────────
// Process companies in parallel batches so slow AI calls don't serialise all
// work but also don't flood OpenRouter's free-tier rate limit.
async function _runInBatches(docs, fn, batchSize = 3, batchDelay = 4000) {
  for (let i = 0; i < docs.length; i += batchSize) {
    const batch = docs.slice(i, i + batchSize);
    await Promise.allSettled(batch.map(fn));
    if (i + batchSize < docs.length) {
      await new Promise(r => setTimeout(r, batchDelay));
    }
  }
}

// Returns true if an auto report of the given type/key already exists today,
// preventing double-generation if the cron fires twice or the server restarts.
async function _alreadyGenerated(db, companyId, type, dateField, dateValue) {
  const snap = await db.collection('companies').doc(companyId)
    .collection('reports')
    .where('type', '==', type)
    .where(dateField, '==', dateValue)
    .where('auto', '==', true)
    .limit(1).get().catch(() => ({ empty: false }));
  return !snap.empty;
}

// Running guards — one per cron so they never overlap themselves
let _morningRunning = false;
let _eveningRunning = false;
let _anomalyRunning = false;
let _weeklyRunning  = false;
let _monthlyRunning = false;

// ── MORNING REPORT — 9:30 AM Monday to Saturday ──────────────────────────────
cron.schedule('30 9 * * 1-6', async () => {
  if (_morningRunning) { console.log('[Cron] Morning already running, skipping'); return; }
  _morningRunning = true;
  console.log('[Cron] Morning report start:', new Date().toISOString());
  try {
    const db    = getFirestore('default');
    const today = new Date().toISOString().split('T')[0];
    const snap  = await db.collection('companies').where('status', '==', 'active').get();

    await _runInBatches(snap.docs, async (companyDoc) => {
      const companyId   = companyDoc.id;
      const companyName = companyDoc.data().name || 'Company';
      const companyType = companyDoc.data().companyType || 'single';
      const reportType  = companyType === 'multi_branch' ? 'group_daily' : 'daily';
      try {
        if (await _alreadyGenerated(db, companyId, reportType, 'date', today)) {
          console.log(`[Cron] Morning report already sent for ${companyName}, skipping`);
          return;
        }
        const [settingsDoc, summary] = await Promise.all([
          db.collection('companies').doc(companyId).collection('settings').doc('config').get(),
          companyType === 'multi_branch'
            ? dataProcessor.buildGroupSummary(db, companyId, 'daily', today)
            : dataProcessor.buildDailySummary(db, companyId, today),
        ]);
        const settings = settingsDoc.data() || {};
        const report   = await aiService.generateReport(summary, companyType === 'multi_branch' ? 'daily' : 'daily', companyName, companyType === 'multi_branch');
        await db.collection('companies').doc(companyId).collection('reports').add({
          type: reportType, date: today, report, summary,
          generatedAt: new Date(), sentAt: new Date(), auto: true,
        });
        const recipients = [];
        if (settings.hrAdminEmail) recipients.push({ email: settings.hrAdminEmail, name: 'HR Admin' });
        if (settings.managerEmail)  recipients.push({ email: settings.managerEmail,  name: 'Manager' });
        if (recipients.length > 0) await sendReportEmail(recipients, reportType, report, companyName);
        console.log(`[Cron] Morning report sent: ${companyName}`);
      } catch (err) {
        console.error(`[Cron] Morning failed for ${companyId}:`, err.message);
      }
    });
  } catch (err) {
    console.error('[Cron] Morning cron error:', err.message);
  } finally {
    _morningRunning = false;
    console.log('[Cron] Morning report done:', new Date().toISOString());
  }
});

// ── END OF DAY REPORT — 5:30 PM Monday to Saturday ───────────────────────────
cron.schedule('30 17 * * 1-6', async () => {
  if (_eveningRunning) { console.log('[Cron] Evening already running, skipping'); return; }
  _eveningRunning = true;
  console.log('[Cron] Evening report start:', new Date().toISOString());
  try {
    const db    = getFirestore('default');
    const today = new Date().toISOString().split('T')[0];
    const snap  = await db.collection('companies').where('status', '==', 'active').get();

    await _runInBatches(snap.docs, async (companyDoc) => {
      const companyId   = companyDoc.id;
      const companyName = companyDoc.data().name || 'Company';
      try {
        if (await _alreadyGenerated(db, companyId, 'end_of_day', 'date', today)) {
          console.log(`[Cron] Evening report already sent for ${companyName}, skipping`);
          return;
        }
        const [settingsDoc, summary] = await Promise.all([
          db.collection('companies').doc(companyId).collection('settings').doc('config').get(),
          dataProcessor.buildDailySummary(db, companyId, today),
        ]);
        const settings = settingsDoc.data() || {};
        const report   = await aiService.generateReport(summary, 'END_OF_DAY', companyName);
        await db.collection('companies').doc(companyId).collection('reports').add({
          type: 'end_of_day', date: today, report, summary,
          generatedAt: new Date(), sentAt: new Date(), auto: true,
        });
        const recipients = [];
        if (settings.hrAdminEmail) recipients.push({ email: settings.hrAdminEmail, name: 'HR Admin' });
        if (settings.managerEmail)  recipients.push({ email: settings.managerEmail,  name: 'Manager' });
        if (recipients.length > 0) await sendReportEmail(recipients, 'end_of_day', report, companyName);
        console.log(`[Cron] Evening report sent: ${companyName}`);
      } catch (err) {
        console.error(`[Cron] Evening failed for ${companyId}:`, err.message);
      }
    });
  } catch (err) {
    console.error('[Cron] Evening cron error:', err.message);
  } finally {
    _eveningRunning = false;
    console.log('[Cron] Evening report done:', new Date().toISOString());
  }
});

// ── MIDNIGHT PHOTO DELETION — 00:00 daily ────────────────────────────────────
cron.schedule('0 0 * * *', async () => {
  console.log('[Cron] Photo deletion start...');
  try {
    const db  = getFirestore('default');
    const now = new Date();
    const snap = await db.collection('companies').get();
    for (const company of snap.docs) {
      try {
        const reportsSnap = await db.collection('companies').doc(company.id)
          .collection('reports')
          .where('type', '==', 'monthly')
          .where('photosDeleted', '==', false)
          .get();
        for (const doc of reportsSnap.docs) {
          const data = doc.data();
          const deletionDate = data.photoDeletionDate?.toDate
            ? data.photoDeletionDate.toDate()
            : new Date(data.photoDeletionDate);
          if (deletionDate <= now) {
            await doc.ref.update({ photosDeleted: true, photosDeletedAt: now });
          }
        }
      } catch (err) {
        console.error(`[Cron] Photo deletion error for ${company.id}:`, err.message);
      }
    }
    console.log('[Cron] Photo deletion done.');
  } catch (e) {
    console.error('[Cron] Photo deletion error:', e.message);
  }
});

// ── WEEKLY ANOMALY CHECK — Monday 8:00 AM ────────────────────────────────────
cron.schedule('0 8 * * 1', async () => {
  if (_anomalyRunning) { console.log('[Cron] Anomaly already running, skipping'); return; }
  _anomalyRunning = true;
  console.log('[Cron] Anomaly check start:', new Date().toISOString());
  try {
    const db   = getFirestore('default');
    const snap = await db.collection('companies').where('status', '==', 'active').get();

    await _runInBatches(snap.docs, async (companyDoc) => {
      const companyId   = companyDoc.id;
      const companyName = companyDoc.data().name || 'Company';
      try {
        const result = await dataProcessor.buildAnomalySummary(db, companyId);
        if (result.anomalies.length === 0) {
          console.log(`[Cron] No anomalies for ${companyName}`);
          return;
        }
        const [alert, settingsDoc] = await Promise.all([
          aiService.generateAnomalyAlert(result.anomalies, companyName),
          db.collection('companies').doc(companyId).collection('settings').doc('config').get(),
        ]);
        await db.collection('companies').doc(companyId).collection('reports').add({
          type: 'anomaly_alert', report: alert, anomalies: result.anomalies,
          generatedAt: new Date(), auto: true,
        });
        const settings = settingsDoc.data() || {};
        if (settings.hrAdminEmail) {
          await sendReportEmail([{ email: settings.hrAdminEmail, name: 'HR Admin' }], 'anomaly_alert', alert, companyName);
        }
        console.log(`[Cron] Anomaly alert sent: ${companyName} (${result.anomalies.length})`);
      } catch (err) {
        console.error(`[Cron] Anomaly failed for ${companyId}:`, err.message);
      }
    });
  } catch (err) {
    console.error('[Cron] Anomaly cron error:', err.message);
  } finally {
    _anomalyRunning = false;
  }
});

// ── WEEKLY REPORT — Every Monday at 9:30 AM ──────────────────────────────────
cron.schedule('30 9 * * 1', async () => {
  if (_weeklyRunning) { console.log('[Cron] Weekly already running, skipping'); return; }
  _weeklyRunning = true;
  console.log('[Cron] Weekly report start:', new Date().toISOString());
  try {
    const db     = getFirestore('default');
    const now    = new Date();
    const diff   = now.getDay() || 7;
    const monday = new Date(now);
    monday.setDate(now.getDate() - diff + 1);
    const startDate = monday.toISOString().split('T')[0];
    const snap = await db.collection('companies').where('status', '==', 'active').get();

    await _runInBatches(snap.docs, async (companyDoc) => {
      const companyId   = companyDoc.id;
      const companyName = companyDoc.data().name || 'Company';
      try {
        if (await _alreadyGenerated(db, companyId, 'weekly', 'startDate', startDate)) {
          console.log(`[Cron] Weekly already sent for ${companyName}, skipping`);
          return;
        }
        const [settingsDoc, summary] = await Promise.all([
          db.collection('companies').doc(companyId).collection('settings').doc('config').get(),
          dataProcessor.buildWeeklySummary(db, companyId, startDate),
        ]);
        const settings = settingsDoc.data() || {};
        const report   = await aiService.generateReport(summary, 'weekly', companyName);
        await db.collection('companies').doc(companyId).collection('reports').add({
          type: 'weekly', startDate, report, summary,
          generatedAt: new Date(), sentAt: new Date(), auto: true,
        });
        const recipients = [];
        if (settings.hrAdminEmail) recipients.push({ email: settings.hrAdminEmail, name: 'HR Admin' });
        if (settings.managerEmail)  recipients.push({ email: settings.managerEmail,  name: 'Manager' });
        if (settings.directorEmail) recipients.push({ email: settings.directorEmail, name: 'Director' });
        if (recipients.length > 0) await sendReportEmail(recipients, 'weekly', report, companyName);
        console.log(`[Cron] Weekly sent: ${companyName}`);
      } catch (err) {
        console.error(`[Cron] Weekly failed for ${companyId}:`, err.message);
      }
    });
  } catch (err) {
    console.error('[Cron] Weekly cron error:', err.message);
  } finally {
    _weeklyRunning = false;
    console.log('[Cron] Weekly report done:', new Date().toISOString());
  }
});

// ── MONTHLY REPORT — Last day of month at 8:00 PM ────────────────────────────
cron.schedule('0 20 28-31 * *', async () => {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  if (tomorrow.getDate() !== 1) return;
  if (_monthlyRunning) { console.log('[Cron] Monthly already running, skipping'); return; }
  _monthlyRunning = true;
  console.log('[Cron] Monthly report start:', new Date().toISOString());
  try {
    const db    = getFirestore('default');
    const month = now.toISOString().slice(0, 7);
    const snap  = await db.collection('companies').where('status', '==', 'active').get();

    await _runInBatches(snap.docs, async (companyDoc) => {
      const companyId   = companyDoc.id;
      const companyName = companyDoc.data().name || 'Company';
      try {
        if (await _alreadyGenerated(db, companyId, 'monthly', 'month', month)) {
          console.log(`[Cron] Monthly already sent for ${companyName}, skipping`);
          return;
        }
        const [settingsDoc, summary] = await Promise.all([
          db.collection('companies').doc(companyId).collection('settings').doc('config').get(),
          dataProcessor.buildMonthlySummary(db, companyId, month),
        ]);
        const settings     = settingsDoc.data() || {};
        const report       = await aiService.generateReport(summary, 'monthly', companyName);
        const deletionDate = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);
        await db.collection('companies').doc(companyId).collection('reports').add({
          type: 'monthly', month, report, summary,
          photoDeletionDate: deletionDate, photosDeleted: false,
          generatedAt: new Date(), sentAt: new Date(), auto: true,
        });
        const recipients = [];
        if (settings.hrAdminEmail) recipients.push({ email: settings.hrAdminEmail, name: 'HR Admin' });
        if (settings.managerEmail)  recipients.push({ email: settings.managerEmail,  name: 'Manager' });
        if (settings.directorEmail) recipients.push({ email: settings.directorEmail, name: 'Director' });
        if (recipients.length > 0) await sendReportEmail(recipients, 'monthly', report, companyName);
        console.log(`[Cron] Monthly sent: ${companyName}`);
      } catch (err) {
        console.error(`[Cron] Monthly failed for ${companyId}:`, err.message);
      }
    });
  } catch (err) {
    console.error('[Cron] Monthly cron error:', err.message);
  } finally {
    _monthlyRunning = false;
    console.log('[Cron] Monthly report done:', new Date().toISOString());
  }
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`HRNova API running on http://localhost:${PORT}`);
  console.log(`Health: http://localhost:${PORT}/api/health`);
});

module.exports = app;
