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

// ── MORNING REPORT — 9:30 AM Monday to Saturday ──────────────────────────────
cron.schedule('30 9 * * 1-6', async () => {
  console.log('[Cron] Running morning report cron:', new Date().toISOString());
  try {
    const db = getFirestore();
    const companiesSnap = await db.collection('companies').where('status', '==', 'active').get();
    for (const companyDoc of companiesSnap.docs) {
      try {
        const companyId   = companyDoc.id;
        const companyName = companyDoc.data().name || 'Company';
        const companyType = companyDoc.data().companyType || 'single';
        const today       = new Date().toISOString().split('T')[0];
        const settingsDoc = await db.collection('companies').doc(companyId)
          .collection('settings').doc('config').get();
        const settings = settingsDoc.data() || {};

        let report;
        if (companyType === 'multi_branch') {
          const groupSummary = await dataProcessor.buildGroupSummary(db, companyId, today);
          groupSummary.companyName = companyName;
          report = await aiService.generateReport(groupSummary, 'GROUP_DAILY', companyName, true);
          await db.collection('companies').doc(companyId).collection('reports').add({
            type: 'group_daily', report, summary: groupSummary,
            generatedAt: new Date(), sentAt: new Date(), auto: true,
          });
        } else {
          const summary = await dataProcessor.buildDailySummary(db, companyId, today);
          summary.companyName = companyName;
          report = await aiService.generateReport(summary, 'daily', companyName);
          await db.collection('companies').doc(companyId).collection('reports').add({
            type: 'daily', report, summary,
            generatedAt: new Date(), sentAt: new Date(), auto: true,
          });
        }

        const recipients = [];
        if (settings.hrAdminEmail) recipients.push({ email: settings.hrAdminEmail, name: 'HR Admin' });
        if (settings.managerEmail)  recipients.push({ email: settings.managerEmail,  name: 'Manager' });
        if (recipients.length > 0) {
          await sendReportEmail(recipients, companyType === 'multi_branch' ? 'group_daily' : 'daily', report, companyName);
        }
        console.log(`[Cron] Morning report sent for: ${companyName}`);
      } catch (err) {
        console.error(`[Cron] Morning report failed for ${companyDoc.id}:`, err.message);
      }
    }
  } catch (err) {
    console.error('[Cron] Morning cron error:', err.message);
  }
});

// ── END OF DAY REPORT — 5:30 PM Monday to Saturday ───────────────────────────
cron.schedule('30 17 * * 1-6', async () => {
  console.log('[Cron] Running end of day report cron:', new Date().toISOString());
  try {
    const db = getFirestore();
    const companiesSnap = await db.collection('companies').where('status', '==', 'active').get();
    for (const companyDoc of companiesSnap.docs) {
      try {
        const companyId   = companyDoc.id;
        const companyName = companyDoc.data().name || 'Company';
        const today       = new Date().toISOString().split('T')[0];
        const settingsDoc = await db.collection('companies').doc(companyId)
          .collection('settings').doc('config').get();
        const settings = settingsDoc.data() || {};

        const summary = await dataProcessor.buildDailySummary(db, companyId, today);
        summary.companyName = companyName;
        const report = await aiService.generateReport(summary, 'END_OF_DAY', companyName);
        await db.collection('companies').doc(companyId).collection('reports').add({
          type: 'end_of_day', report, summary,
          generatedAt: new Date(), sentAt: new Date(), auto: true,
        });

        const recipients = [];
        if (settings.hrAdminEmail) recipients.push({ email: settings.hrAdminEmail, name: 'HR Admin' });
        if (settings.managerEmail)  recipients.push({ email: settings.managerEmail,  name: 'Manager' });
        if (recipients.length > 0) {
          await sendReportEmail(recipients, 'end_of_day', report, companyName);
        }
        console.log(`[Cron] End of day report sent for: ${companyName}`);
      } catch (err) {
        console.error(`[Cron] End of day report failed for ${companyDoc.id}:`, err.message);
      }
    }
  } catch (err) {
    console.error('[Cron] Evening cron error:', err.message);
  }
});

// ── MIDNIGHT PHOTO DELETION — 00:00 daily ────────────────────────────────────
cron.schedule('0 0 * * *', async () => {
  console.log('[Cron] Running midnight photo deletion job...');
  try {
    const db  = getFirestore();
    const now = new Date();

    const companiesSnap = await db.collection('companies').get();
    for (const company of companiesSnap.docs) {
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
          console.log(`[Cron] Marked photos deleted for ${company.id}/${doc.id}`);
        }
      }
    }
    console.log('[Cron] Photo deletion job complete.');
  } catch (e) {
    console.error('[Cron] Photo deletion error:', e.message);
  }
});

// ── WEEKLY ANOMALY CHECK — Monday 8:00 AM ────────────────────────────────────
cron.schedule('0 8 * * 1', async () => {
  console.log('[Cron] Running weekly anomaly check:', new Date().toISOString());
  try {
    const db = getFirestore();
    const companiesSnap = await db.collection('companies').where('status', '==', 'active').get();
    for (const companyDoc of companiesSnap.docs) {
      try {
        const companyId = companyDoc.id;
        const companyName = companyDoc.data().name || 'Company';
        const result = await dataProcessor.buildAnomalySummary(db, companyId);
        if (result.anomalies.length > 0) {
          const alert = await aiService.generateAnomalyAlert(result.anomalies, companyName);
          await db.collection('companies').doc(companyId).collection('reports').add({
            type: 'anomaly_alert', report: alert, anomalies: result.anomalies,
            generatedAt: new Date(), auto: true,
          });
          const settingsDoc = await db.collection('companies').doc(companyId)
            .collection('settings').doc('config').get();
          const settings = settingsDoc.data() || {};
          if (settings.hrAdminEmail) {
            await sendReportEmail(
              [{ email: settings.hrAdminEmail, name: 'HR Admin' }],
              'anomaly_alert', alert, companyName
            );
          }
          console.log(`[Cron] Anomaly alert sent for: ${companyName} (${result.anomalies.length} anomalies)`);
        } else {
          console.log(`[Cron] No anomalies for: ${companyName}`);
        }
      } catch (err) {
        console.error(`[Cron] Anomaly check failed for ${companyDoc.id}:`, err.message);
      }
    }
  } catch (err) {
    console.error('[Cron] Anomaly cron error:', err.message);
  }
});

// ── WEEKLY REPORT — Every Monday at 9:30 AM ───────────────────────────────────
cron.schedule('30 9 * * 1', async () => {
  console.log('[Cron] Running weekly report cron:', new Date().toISOString());
  try {
    const db = getFirestore();
    const today = new Date();
    const diff = today.getDay() || 7;
    const monday = new Date(today);
    monday.setDate(today.getDate() - diff + 1);
    const startDate = monday.toISOString().split('T')[0];
    const companiesSnap = await db.collection('companies').where('status', '==', 'active').get();
    for (const companyDoc of companiesSnap.docs) {
      try {
        const companyId = companyDoc.id;
        const companyName = companyDoc.data().name || 'Company';
        const settingsDoc = await db.collection('companies').doc(companyId).collection('settings').doc('config').get();
        const settings = settingsDoc.data() || {};
        const summary = await dataProcessor.buildWeeklySummary(db, companyId, startDate);
        summary.companyName = companyName;
        const report = await aiService.generateReport(summary, 'weekly', companyName);
        await db.collection('companies').doc(companyId).collection('reports').add({
          type: 'weekly', report, summary, startDate,
          generatedAt: new Date(), sentAt: new Date(), auto: true,
        });
        const recipients = [];
        if (settings.hrAdminEmail) recipients.push({ email: settings.hrAdminEmail, name: 'HR Admin' });
        if (settings.managerEmail)  recipients.push({ email: settings.managerEmail,  name: 'Manager' });
        if (settings.directorEmail) recipients.push({ email: settings.directorEmail, name: 'Director' });
        if (recipients.length > 0) {
          await sendReportEmail(recipients, 'weekly', report, companyName);
        }
        console.log(`[Cron] Weekly report sent for: ${companyName}`);
      } catch (err) {
        console.error(`[Cron] Weekly failed for ${companyDoc.id}:`, err.message);
      }
    }
  } catch (err) {
    console.error('[Cron] Weekly cron error:', err.message);
  }
});

// ── MONTHLY REPORT — Last day of month at 8:00 PM ────────────────────────────
cron.schedule('0 20 28-31 * *', async () => {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  if (tomorrow.getDate() !== 1) return; // only last day of month
  console.log('[Cron] Running monthly report cron:', new Date().toISOString());
  try {
    const db = getFirestore();
    const month = now.toISOString().slice(0, 7);
    const companiesSnap = await db.collection('companies').where('status', '==', 'active').get();
    for (const companyDoc of companiesSnap.docs) {
      try {
        const companyId = companyDoc.id;
        const companyName = companyDoc.data().name || 'Company';
        const settingsDoc = await db.collection('companies').doc(companyId).collection('settings').doc('config').get();
        const settings = settingsDoc.data() || {};
        const summary = await dataProcessor.buildMonthlySummary(db, companyId, month);
        summary.companyName = companyName;
        const report = await aiService.generateReport(summary, 'monthly', companyName);
        const deletionDate = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);
        await db.collection('companies').doc(companyId).collection('reports').add({
          type: 'monthly', report, summary, month,
          photoDeletionDate: deletionDate, photosDeleted: false,
          generatedAt: new Date(), sentAt: new Date(), auto: true,
        });
        const recipients = [];
        if (settings.hrAdminEmail) recipients.push({ email: settings.hrAdminEmail, name: 'HR Admin' });
        if (settings.managerEmail)  recipients.push({ email: settings.managerEmail,  name: 'Manager' });
        if (settings.directorEmail) recipients.push({ email: settings.directorEmail, name: 'Director' });
        if (recipients.length > 0) {
          await sendReportEmail(recipients, 'monthly', report, companyName);
        }
        console.log(`[Cron] Monthly report sent for: ${companyName}`);
      } catch (err) {
        console.error(`[Cron] Monthly failed for ${companyDoc.id}:`, err.message);
      }
    }
  } catch (err) {
    console.error('[Cron] Monthly cron error:', err.message);
  }
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`HRNova API running on http://localhost:${PORT}`);
  console.log(`Health: http://localhost:${PORT}/api/health`);
});

module.exports = app;
