/**
 * WhatsApp Leave Portal — 5-step conversational flow
 * Sessions stored in Firestore: whatsapp_sessions/{phone}
 *
 * Steps:
 *  0 → greet + show leave type menu
 *  1 → got leave type, ask start date (DD/MM/YYYY)
 *  2 → got start date, ask end date
 *  3 → got end date, show summary + confirm
 *  4 → confirmed → create leave request, end session
 */

const axios = require('axios');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getApp } = require('firebase-admin/app');

const db = () => getFirestore(getApp(), 'default');

const WA_TOKEN = process.env.WHATSAPP_TOKEN;
const WA_PHONE_ID = process.env.WHATSAPP_PHONE_NUMBER_ID;
const WA_API = `https://graph.facebook.com/v19.0/${WA_PHONE_ID}/messages`;

const LEAVE_TYPES = {
  '1': 'annual',
  '2': 'sick',
  '3': 'maternity',
  '4': 'paternity',
  '5': 'unpaid',
  '6': 'emergency',
};

const LEAVE_LABELS = {
  annual: 'Annual Leave',
  sick: 'Sick Leave',
  maternity: 'Maternity Leave (84 days)',
  paternity: 'Paternity Leave (4 days)',
  unpaid: 'Unpaid Leave',
  emergency: 'Emergency Leave',
};

// ── Send WhatsApp text message ─────────────────────────────────────────────────
async function sendMessage(to, text) {
  if (!WA_TOKEN || !WA_PHONE_ID) {
    console.log(`[WhatsApp] Would send to ${to}: ${text}`);
    return;
  }
  await axios.post(
    WA_API,
    {
      messaging_product: 'whatsapp',
      to,
      type: 'text',
      text: { body: text },
    },
    {
      headers: {
        Authorization: `Bearer ${WA_TOKEN}`,
        'Content-Type': 'application/json',
      },
    }
  );
}

// ── Get or create session ──────────────────────────────────────────────────────
async function getSession(phone) {
  const ref = db().collection('whatsapp_sessions').doc(phone);
  const doc = await ref.get();
  if (!doc.exists) return null;
  const data = doc.data();
  // Expire sessions older than 30 minutes
  if (data.updatedAt) {
    const age = Date.now() - data.updatedAt.toMillis();
    if (age > 30 * 60 * 1000) {
      await ref.delete();
      return null;
    }
  }
  return data;
}

async function saveSession(phone, data) {
  await db().collection('whatsapp_sessions').doc(phone).set({
    ...data,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function clearSession(phone) {
  await db().collection('whatsapp_sessions').doc(phone).delete();
}

// ── Find employee by phone ─────────────────────────────────────────────────────
async function findEmployee(phone, companyId) {
  const snap = await db()
    .collection('companies')
    .doc(companyId)
    .collection('employees')
    .where('phone', '==', phone)
    .where('status', '==', 'active')
    .limit(1)
    .get();
  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() };
}

// ── Parse date from DD/MM/YYYY ────────────────────────────────────────────────
function parseDate(str) {
  const m = str.trim().match(/^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$/);
  if (!m) return null;
  const d = new Date(parseInt(m[3]), parseInt(m[2]) - 1, parseInt(m[1]));
  if (isNaN(d.getTime())) return null;
  return d;
}

function fmtDate(d) {
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
}

// ── Working days calculator (simplified) ──────────────────────────────────────
function workingDaysBetween(start, end) {
  const HOLIDAYS = new Set([
    '01-01','01-02','02-01','04-07','05-01',
    '07-01','07-04','08-15','12-25','12-26',
  ]);
  let count = 0;
  const cur = new Date(start);
  while (cur <= end) {
    const wd = cur.getDay();
    const mmdd = `${String(cur.getMonth() + 1).padStart(2,'0')}-${String(cur.getDate()).padStart(2,'0')}`;
    if (wd !== 0 && wd !== 6 && !HOLIDAYS.has(mmdd)) count++;
    cur.setDate(cur.getDate() + 1);
  }
  return count;
}

// ── Create leave request in Firestore ────────────────────────────────────────
async function createLeaveRequest({ companyId, employeeId, employeeName, branchId, leaveType, startDate, endDate, totalDays }) {
  const ref = db().collection('companies').doc(companyId).collection('leave_requests').doc();
  await ref.set({
    companyId,
    employeeId,
    employeeName,
    leaveType,
    startDate: startDate.toISOString(),
    endDate: endDate.toISOString(),
    totalDays,
    reason: `Requested via WhatsApp portal`,
    status: 'pending',
    source: 'whatsapp_portal',
    ...(branchId ? { branchId } : {}),
    requestedAt: FieldValue.serverTimestamp(),
  });

  // Notify HR
  await db().collection('companies').doc(companyId).collection('notifications').add({
    type: 'leave_request',
    title: 'New Leave Request (WhatsApp)',
    body: `${employeeName} requested ${LEAVE_LABELS[leaveType] || leaveType} (${totalDays} days) via WhatsApp`,
    employeeId,
    leaveRequestId: ref.id,
    targetRole: 'hr_admin',
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  return ref.id;
}

// ── Main handler ──────────────────────────────────────────────────────────────
async function handleIncomingMessage(phone, messageText, companyId) {
  const text = messageText.trim();
  const upper = text.toUpperCase();

  // Cancel at any point
  if (upper === 'CANCEL' || upper === 'STOP' || upper === 'QUIT') {
    await clearSession(phone);
    await sendMessage(phone,
      '❌ Leave request cancelled.\n\nSend *LEAVE* anytime to start a new request.'
    );
    return;
  }

  const session = await getSession(phone);

  // ── Step 0: No session or trigger word ───────────────────────────────────
  if (!session || upper === 'LEAVE') {
    await sendMessage(phone,
      `👋 Welcome to HRNova Leave Portal!\n\nPlease select your leave type:\n\n` +
      `1️⃣ Annual Leave\n2️⃣ Sick Leave\n3️⃣ Maternity Leave\n4️⃣ Paternity Leave\n5️⃣ Unpaid Leave\n6️⃣ Emergency Leave\n\n` +
      `Reply with the number (1-6) or send *CANCEL* to quit.`
    );
    await saveSession(phone, { step: 1, companyId });
    return;
  }

  // ── Step 1: Receive leave type ────────────────────────────────────────────
  if (session.step === 1) {
    const leaveType = LEAVE_TYPES[text];
    if (!leaveType) {
      await sendMessage(phone, '⚠️ Please reply with a number between 1 and 6.');
      return;
    }
    await sendMessage(phone,
      `✅ *${LEAVE_LABELS[leaveType]}* selected.\n\nWhen does your leave start?\n` +
      `Reply with the date in format: *DD/MM/YYYY*\n\n_Example: 15/07/2026_`
    );
    await saveSession(phone, { ...session, step: 2, leaveType });
    return;
  }

  // ── Step 2: Receive start date ────────────────────────────────────────────
  if (session.step === 2) {
    const startDate = parseDate(text);
    if (!startDate) {
      await sendMessage(phone, '⚠️ Invalid date format. Please use *DD/MM/YYYY*.\n\nExample: *15/07/2026*');
      return;
    }
    if (startDate < new Date()) {
      await sendMessage(phone, '⚠️ Start date cannot be in the past. Please enter a future date.');
      return;
    }
    await sendMessage(phone,
      `📅 Start date: *${fmtDate(startDate)}*\n\nWhen does your leave end?\nReply with: *DD/MM/YYYY*`
    );
    await saveSession(phone, { ...session, step: 3, startDate: startDate.toISOString() });
    return;
  }

  // ── Step 3: Receive end date + show summary ───────────────────────────────
  if (session.step === 3) {
    const endDate = parseDate(text);
    const startDate = new Date(session.startDate);
    if (!endDate) {
      await sendMessage(phone, '⚠️ Invalid date format. Please use *DD/MM/YYYY*.');
      return;
    }
    if (endDate < startDate) {
      await sendMessage(phone, '⚠️ End date must be on or after the start date.');
      return;
    }
    const totalDays = workingDaysBetween(startDate, endDate);

    await sendMessage(phone,
      `📋 *Leave Request Summary*\n\n` +
      `📌 Type: *${LEAVE_LABELS[session.leaveType]}*\n` +
      `📅 From: *${fmtDate(startDate)}*\n` +
      `📅 To: *${fmtDate(endDate)}*\n` +
      `🗓️ Working Days: *${totalDays}*\n\n` +
      `Reply *YES* to confirm or *CANCEL* to cancel.`
    );
    await saveSession(phone, { ...session, step: 4, endDate: endDate.toISOString(), totalDays });
    return;
  }

  // ── Step 4: Confirm ───────────────────────────────────────────────────────
  if (session.step === 4) {
    if (upper !== 'YES' && upper !== 'Y' && upper !== 'CONFIRM') {
      await sendMessage(phone, 'Reply *YES* to confirm your leave request, or *CANCEL* to cancel.');
      return;
    }

    const employee = await findEmployee(phone, session.companyId);
    if (!employee) {
      await sendMessage(phone,
        '⚠️ Your phone number is not registered in our system. Please contact HR for assistance.'
      );
      await clearSession(phone);
      return;
    }

    const startDate = new Date(session.startDate);
    const endDate = new Date(session.endDate);

    const requestId = await createLeaveRequest({
      companyId: session.companyId,
      employeeId: employee.id,
      employeeName: `${employee.firstName} ${employee.lastName}`,
      branchId: employee.branchId,
      leaveType: session.leaveType,
      startDate,
      endDate,
      totalDays: session.totalDays,
    });

    await sendMessage(phone,
      `✅ *Leave request submitted successfully!*\n\n` +
      `Your request has been sent to HR for approval.\n` +
      `Reference: #${requestId.substring(0, 8).toUpperCase()}\n\n` +
      `You will be notified once it is reviewed.\n\n` +
      `Send *LEAVE* anytime to submit another request.`
    );
    await clearSession(phone);
    return;
  }

  // Fallback
  await sendMessage(phone,
    'Send *LEAVE* to request leave, or *CANCEL* to cancel an ongoing request.'
  );
}

async function sendWhatsAppMessage(to, message) {
  return sendMessage(to, message);
}

module.exports = { handleIncomingMessage, sendWhatsAppMessage, sendMessage };
