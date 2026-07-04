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

const LEAVE_TYPES_RW = { '1': 'annual', '2': 'sick', '3': 'emergency', '4': 'unpaid' };
const LEAVE_LABELS_RW = {
  annual: 'Impushya za buri mwaka',
  sick: "Uruhushya rw'uburwayi",
  emergency: "Uruhushya rw'ibyihutirwa",
  unpaid: 'Uruhushya rudafite umushahara',
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

  const isKinyarwanda = ['URUHUSHYA', 'IMPUSHYA'].includes(upper);

  // Cancel at any point (including Kinyarwanda cancel words)
  const session = await getSession(phone);
  if (['CANCEL', 'STOP', 'QUIT', 'HAGARIKA', 'OYA'].includes(upper)) {
    const cancelMsg = (session?.lang === 'rw')
      ? '✅ Gusaba uruhushya guhagaritswe.\nSubiza URUHUSHYA niba ushaka kongera.'
      : '❌ Leave request cancelled.\n\nSend *LEAVE* anytime to start a new request.';
    await clearSession(phone);
    await sendMessage(phone, cancelMsg);
    return;
  }

  // ── Kinyarwanda trigger ───────────────────────────────────────────────────
  if (isKinyarwanda || (!session && upper === 'URUHUSHYA') || (!session && upper === 'IMPUSHYA')) {
    await sendMessage(phone,
      `Muraho! 👋 Murakaza neza kuri HRNova.\n\n` +
      `Hitamo icyo ushaka:\n` +
      `1️⃣ Gusaba uruhushya\n` +
      `2️⃣ Kureba impushya nsigaranye\n\n` +
      `Subiza 1 cyangwa 2.`
    );
    await saveSession(phone, { step: 'rw_menu', companyId, lang: 'rw' });
    return;
  }

  // ── Kinyarwanda menu step ─────────────────────────────────────────────────
  if (session && session.step === 'rw_menu') {
    if (text === '2') {
      // Balance check
      const employee = await findEmployee(phone, session.companyId);
      const balances = employee?.leaveBalances || {};
      const annual = balances.annual ?? 18;
      const sick = balances.sick ?? 10;
      await sendMessage(phone,
        `Impushya zawe nsigaranye:\n\n` +
        `📅 Impushya za buri mwaka: ${annual} iminsi\n` +
        `🏥 Uruhushya rw'uburwayi: ${sick} iminsi\n` +
        `👶 Uruhushya rw'inda: 84 iminsi (amategeko ya Rwanda)\n` +
        `👨 Uruhushya rw'se: 4 iminsi (amategeko ya Rwanda)\n\n` +
        `Niba ufite ikibazo, vugana na HR wawe.`
      );
      await clearSession(phone);
      return;
    }
    if (text === '1') {
      await sendMessage(phone,
        `Ni ubuhe bwoko bw'uruhushya usaba?\n\n` +
        `1️⃣ Impushya za buri mwaka\n` +
        `2️⃣ Uruhushya rw'uburwayi\n` +
        `3️⃣ Uruhushya rw'ibyihutirwa\n` +
        `4️⃣ Uruhushya rudafite umushahara\n\n` +
        `Subiza 1, 2, 3, cyangwa 4.\n` +
        `Subiza HAGARIKA niba ushaka guhagarika.`
      );
      await saveSession(phone, { step: 1, lang: 'rw', companyId: session.companyId });
      return;
    }
    await sendMessage(phone, 'Subiza 1 cyangwa 2.');
    return;
  }

  // ── English trigger (no session) ─────────────────────────────────────────
  if (!session || upper === 'LEAVE') {
    await sendMessage(phone,
      `👋 Welcome to HRNova Leave Portal!\n\nPlease select your leave type:\n\n` +
      `1️⃣ Annual Leave\n2️⃣ Sick Leave\n3️⃣ Maternity Leave\n4️⃣ Paternity Leave\n5️⃣ Unpaid Leave\n6️⃣ Emergency Leave\n\n` +
      `Reply with the number (1-6) or send *CANCEL* to quit.\n\n` +
      `_Kinyarwanda: Subiza URUHUSHYA_`
    );
    await saveSession(phone, { step: 1, companyId });
    return;
  }

  const isRw = session.lang === 'rw';

  // ── Step 1: Receive leave type ────────────────────────────────────────────
  if (session.step === 1) {
    const leaveType = isRw ? LEAVE_TYPES_RW[text] : LEAVE_TYPES[text];
    if (!leaveType) {
      await sendMessage(phone, isRw
        ? '⚠️ Subiza inomero iri hagati ya 1 na 4.'
        : '⚠️ Please reply with a number between 1 and 6.');
      return;
    }
    const label = isRw ? LEAVE_LABELS_RW[leaveType] : LEAVE_LABELS[leaveType];
    await sendMessage(phone, isRw
      ? `✅ *${label}* wahisemo.\n\nNi ryari uruhushya rugomba gutangira?\nAndika itariki: DD/MM/YYYY\nUrugero: 25/06/2026`
      : `✅ *${label}* selected.\n\nWhen does your leave start?\nReply with the date in format: *DD/MM/YYYY*\n\n_Example: 15/07/2026_`
    );
    await saveSession(phone, { ...session, step: 2, leaveType });
    return;
  }

  // ── Step 2: Receive start date ────────────────────────────────────────────
  if (session.step === 2) {
    const startDate = parseDate(text);
    if (!startDate) {
      await sendMessage(phone, isRw
        ? '⚠️ Itariki si yo. Andika: DD/MM/YYYY'
        : '⚠️ Invalid date format. Please use *DD/MM/YYYY*.\n\nExample: *15/07/2026*');
      return;
    }
    if (startDate < new Date()) {
      await sendMessage(phone, isRw
        ? '⚠️ Itariki yarangiye. Andika itariki izaza.'
        : '⚠️ Start date cannot be in the past. Please enter a future date.');
      return;
    }
    await sendMessage(phone, isRw
      ? `📅 Itariki yo gutangira: *${fmtDate(startDate)}*\n\nNi ryari uruhushya rugomba kurangira?\nAndika itariki: DD/MM/YYYY\nCyangwa subiza RIMWE niba ari umunsi umwe gusa.`
      : `📅 Start date: *${fmtDate(startDate)}*\n\nWhen does your leave end?\nReply with: *DD/MM/YYYY*`
    );
    await saveSession(phone, { ...session, step: 3, startDate: startDate.toISOString() });
    return;
  }

  // ── Step 3: Receive end date + show summary ───────────────────────────────
  if (session.step === 3) {
    const startDate = new Date(session.startDate);
    // Allow RIMWE (Kinyarwanda for "once/one day") to mean same day
    let endDate;
    if (isRw && upper === 'RIMWE') {
      endDate = startDate;
    } else {
      endDate = parseDate(text);
    }
    if (!endDate) {
      await sendMessage(phone, isRw
        ? '⚠️ Itariki si yo. Andika: DD/MM/YYYY'
        : '⚠️ Invalid date format. Please use *DD/MM/YYYY*.');
      return;
    }
    if (endDate < startDate) {
      await sendMessage(phone, isRw
        ? '⚠️ Itariki yo kurangira igomba kuba nyuma y\'itariki yo gutangira.'
        : '⚠️ End date must be on or after the start date.');
      return;
    }
    const totalDays = workingDaysBetween(startDate, endDate);
    const label = isRw ? (LEAVE_LABELS_RW[session.leaveType] || session.leaveType) : (LEAVE_LABELS[session.leaveType] || session.leaveType);

    await sendMessage(phone, isRw
      ? `📋 *Incamake y'ubusabe bwawe*\n\n` +
        `📌 Ubwoko: *${label}*\n` +
        `📅 Gutangira: *${fmtDate(startDate)}*\n` +
        `📅 Kurangira: *${fmtDate(endDate)}*\n` +
        `🗓️ Iminsi: *${totalDays}*\n\n` +
        `Subiza *YEGO* kwemeza cyangwa *HAGARIKA* guhagarika.`
      : `📋 *Leave Request Summary*\n\n` +
        `📌 Type: *${label}*\n` +
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
    const confirmed = ['YES', 'Y', 'CONFIRM', 'YEGO'].includes(upper);
    if (!confirmed) {
      await sendMessage(phone, isRw
        ? 'Subiza *YEGO* kwemeza cyangwa *HAGARIKA* guhagarika.'
        : 'Reply *YES* to confirm your leave request, or *CANCEL* to cancel.');
      return;
    }

    const employee = await findEmployee(phone, session.companyId);
    if (!employee) {
      await sendMessage(phone, isRw
        ? '⚠️ Inomero yawe telefone ntabwo ibaruwe mu sisitemu. Vugana na HR wawe.'
        : '⚠️ Your phone number is not registered in our system. Please contact HR for assistance.'
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

    await sendMessage(phone, isRw
      ? `✅ *Ubusabe bwatanzwe neza!*\n\n` +
        `Ubusabe bwawe bwoherejwe kuri HR.\n` +
        `Numero: #${requestId.substring(0, 8).toUpperCase()}\n\n` +
        `Uzabwirwa igihe bwemejwe.\n\n` +
        `Subiza URUHUSHYA niba ushaka kongera gusaba.`
      : `✅ *Leave request submitted successfully!*\n\n` +
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
    'Send *LEAVE* to request leave, or *CANCEL* to cancel.\n_Kinyarwanda: Subiza URUHUSHYA_'
  );
}

async function sendWhatsAppMessage(to, message) {
  return sendMessage(to, message);
}

module.exports = { handleIncomingMessage, sendWhatsAppMessage, sendMessage };
