const express = require('express');
const path = require('path');
const fs = require('fs');
const router = express.Router();
const { getFirestore } = require('firebase-admin/firestore');
const { getApp } = require('firebase-admin/app');
const { GoogleAuth } = require('google-auth-library');
const { verifyToken, requireRole } = require('../middleware/verifyToken');

const db = () => getFirestore(getApp(), 'default');

router.use(verifyToken, requireRole('super_admin'));

// ── Firestore Blaze pricing (multi-region, USD) + daily free tier ─────────────
const PRICE_PER_100K = { reads: 0.06, writes: 0.18, deletes: 0.02 };
const FREE_TIER_DAILY = { reads: 50000, writes: 20000, deletes: 20000 };
const USD_TO_RWF = parseFloat(process.env.USD_TO_RWF || '1450');

const METRICS = {
  reads: 'firestore.googleapis.com/document/read_count',
  writes: 'firestore.googleapis.com/document/write_count',
  deletes: 'firestore.googleapis.com/document/delete_count',
};

let _auth = null;
function monitoringAuth() {
  if (_auth) return _auth;
  const saPath = path.join(__dirname, '..',
    process.env.FIREBASE_PRIVATE_KEY_PATH || './hrnova-6b7d8-firebase-adminsdk-fbsvc-75268fae3e.json');
  _auth = new GoogleAuth({
    ...(fs.existsSync(saPath) ? { keyFile: saPath } : {}),
    scopes: ['https://www.googleapis.com/auth/monitoring.read'],
  });
  return _auth;
}

/// Fetch a metric as a map of daily sums: { 'YYYY-MM-DD': count }.
/// Sums across all time series (labels like op type / database id).
async function fetchDailySums(projectId, metricType, startIso, endIso, token) {
  const params = new URLSearchParams({
    filter: `metric.type="${metricType}"`,
    'interval.startTime': startIso,
    'interval.endTime': endIso,
    'aggregation.alignmentPeriod': '86400s',
    'aggregation.perSeriesAligner': 'ALIGN_SUM',
    'aggregation.crossSeriesReducer': 'REDUCE_SUM',
  });
  const url = `https://monitoring.googleapis.com/v3/projects/${projectId}/timeSeries?${params}`;
  const resp = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`Monitoring API ${resp.status}: ${body.slice(0, 300)}`);
  }
  const json = await resp.json();
  const daily = {};
  for (const series of json.timeSeries || []) {
    for (const pt of series.points || []) {
      // Points are aligned to period end; attribute to the day the period covers
      const end = new Date(pt.interval.endTime);
      const day = new Date(end.getTime() - 1).toISOString().slice(0, 10);
      const v = parseInt(pt.value.int64Value ?? pt.value.doubleValue ?? 0, 10) || 0;
      daily[day] = (daily[day] || 0) + v;
    }
  }
  return daily;
}

const _SHORT_MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

/// Parse a payment's "MMM yyyy" date string (e.g. "Jul 2026") into a
/// "YYYY-MM" key. Returns null if it doesn't match that format.
function _parsePaymentMonth(date) {
  const m = /^([A-Za-z]{3})\s+(\d{4})$/.exec((date || '').trim());
  if (!m) return null;
  const idx = _SHORT_MONTHS.findIndex((s) => s.toLowerCase() === m[1].toLowerCase());
  if (idx === -1) return null;
  return `${m[2]}-${String(idx + 1).padStart(2, '0')}`;
}

function estDailyCostUsd(reads, writes, deletes) {
  const billable = (n, free) => Math.max(0, n - free);
  return billable(reads, FREE_TIER_DAILY.reads) * PRICE_PER_100K.reads / 100000 +
         billable(writes, FREE_TIER_DAILY.writes) * PRICE_PER_100K.writes / 100000 +
         billable(deletes, FREE_TIER_DAILY.deletes) * PRICE_PER_100K.deletes / 100000;
}

// ── GET /api/cost-analytics ───────────────────────────────────────────────────
// Live usage from Cloud Monitoring + earnings from payments, aggregated
// per day (30d) and per month (6mo) with estimated Firestore cost.
router.get('/', async (req, res) => {
  try {
    const projectId = process.env.FIREBASE_PROJECT_ID || 'hrnova-6b7d8';
    const auth = monitoringAuth();
    const client = await auth.getClient();
    const token = (await client.getAccessToken()).token;

    const now = new Date();
    const start = new Date(now);
    start.setDate(start.getDate() - 185); // ~6 months of daily points

    // Monitoring API refuses to serve projects without a billing account
    // (Spark plan). Degrade gracefully: earnings/profit still work, usage
    // shows an "enable billing" notice until the project is on Blaze.
    let reads = {}, writes = {}, deletes = {};
    let monitoringUnavailable = null;
    try {
      [reads, writes, deletes] = await Promise.all([
        fetchDailySums(projectId, METRICS.reads, start.toISOString(), now.toISOString(), token),
        fetchDailySums(projectId, METRICS.writes, start.toISOString(), now.toISOString(), token),
        fetchDailySums(projectId, METRICS.deletes, start.toISOString(), now.toISOString(), token),
      ]);
    } catch (e) {
      monitoringUnavailable = /billing/i.test(e.message)
          ? 'billing_required'
          : (e.message || 'monitoring_failed').slice(0, 200);
      console.warn('[CostAnalytics] monitoring unavailable:', monitoringUnavailable);
    }

    // Merge into per-day rows
    const allDays = [...new Set([...Object.keys(reads), ...Object.keys(writes), ...Object.keys(deletes)])].sort();
    const dailyRows = allDays.map((d) => {
      const r = reads[d] || 0, w = writes[d] || 0, x = deletes[d] || 0;
      return { date: d, reads: r, writes: w, deletes: x, estCostUsd: estDailyCostUsd(r, w, x) };
    });

    const todayKey = now.toISOString().slice(0, 10);
    const today = dailyRows.find((r) => r.date === todayKey) ||
        { date: todayKey, reads: 0, writes: 0, deletes: 0, estCostUsd: 0 };

    // ── Earnings: all payments across companies, grouped by month ────────────
    // Each payment's `date` field is written by the Billing page's Add
    // Payment dialog as "MMM yyyy" (e.g. "Jul 2026"), not an ISO date —
    // parse that exact format rather than assuming YYYY-MM-DD.
    const paySnap = await db().collectionGroup('payments').get();
    const earningsByMonth = {};
    paySnap.docs.forEach((doc) => {
      const p = doc.data();
      const month = _parsePaymentMonth(p.date);
      if (!month) return;
      earningsByMonth[month] = (earningsByMonth[month] || 0) + (parseInt(p.amount, 10) || 0);
    });

    // ── Monthly aggregation: last 6 calendar months ───────────────────────────
    const months = [];
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      months.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
    }
    const monthly = months.map((m) => {
      const rows = dailyRows.filter((r) => r.date.startsWith(m));
      const estCostUsd = rows.reduce((s, r) => s + r.estCostUsd, 0);
      const estCostRwf = estCostUsd * USD_TO_RWF;
      const earningsRwf = earningsByMonth[m] || 0;
      const halfEarningsRwf = earningsRwf / 2;
      return {
        month: m,
        estCostUsd: +estCostUsd.toFixed(4),
        estCostRwf: Math.round(estCostRwf),
        earningsRwf,
        halfEarningsRwf: Math.round(halfEarningsRwf),
        profitRwf: Math.round(halfEarningsRwf - estCostRwf),
      };
    });

    res.json({
      updatedAt: now.toISOString(),
      plan: 'spark',
      monitoringUnavailable,
      usdToRwf: USD_TO_RWF,
      freeTierDaily: FREE_TIER_DAILY,
      today: { ...today, estCostUsd: +today.estCostUsd.toFixed(4) },
      daily30: dailyRows.slice(-30).map((r) => ({ ...r, estCostUsd: +r.estCostUsd.toFixed(4) })),
      monthly,
    });
  } catch (e) {
    console.error('[CostAnalytics] error:', e);
    res.status(500).json({ error: e.message || 'Cost analytics failed' });
  }
});

module.exports = router;
