const Brevo = require('@getbrevo/brevo');

const client = Brevo.ApiClient.instance;
client.authentications['api-key'].apiKey = process.env.BREVO_API_KEY;
const api = new Brevo.TransactionalEmailsApi();

const SENDER = { name: 'HRNova', email: 'noreply@hrnova.rw' };

const HTML_WRAPPER = (content) => `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f0f4f8; }
    .wrapper { max-width: 580px; margin: 32px auto; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.12); }
    .header { background: #0A1628; padding: 28px 32px; }
    .logo { font-size: 22px; font-weight: 800; }
    .logo span { color: #fff; }
    .logo em { color: #3B82F6; font-style: normal; }
    .tagline { color: #64748b; font-size: 12px; margin-top: 4px; }
    .body { background: #fff; padding: 32px; }
    .body h2 { font-size: 20px; color: #0f172a; margin-bottom: 8px; }
    .body p { color: #475569; font-size: 14px; line-height: 1.6; margin-bottom: 12px; }
    .detail-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; margin: 20px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #e2e8f0; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label { color: #64748b; font-size: 13px; }
    .detail-value { color: #0f172a; font-size: 13px; font-weight: 600; }
    .badge { display: inline-block; padding: 4px 12px; border-radius: 100px; font-size: 12px; font-weight: 600; }
    .badge-green { background: #dcfce7; color: #16a34a; }
    .badge-red { background: #fee2e2; color: #dc2626; }
    .badge-blue { background: #dbeafe; color: #2563eb; }
    .footer { background: #0A1628; padding: 20px 32px; text-align: center; }
    .footer p { color: #475569; font-size: 12px; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <div class="logo"><span>HR</span><em>Nova</em></div>
      <div class="tagline">Your HR Team, Supercharged</div>
    </div>
    <div class="body">${content}</div>
    <div class="footer">
      <p>Automated message from HRNova. Do not reply.</p>
      <p style="margin-top:6px">© ${new Date().getFullYear()} HRNova • Rwanda</p>
    </div>
  </div>
</body>
</html>`;

async function sendEmail({ to, toName, subject, htmlContent }) {
  if (!process.env.BREVO_API_KEY) {
    console.log(`[Email] No API key — skipping send to ${to}: ${subject}`);
    return { messageId: 'no-api-key' };
  }
  try {
    const result = await api.sendTransacEmail({
      subject,
      htmlContent,
      sender: SENDER,
      to: [{ email: to, name: toName || to }],
    });
    console.log(`[Email] Sent to ${to}: ${subject}`);
    return result;
  } catch (err) {
    console.error('[Email] Send error:', err?.response?.body ?? err.message);
    throw err;
  }
}

async function sendLeaveApprovalEmail({ employeeEmail, employeeName, leaveType, startDate, endDate, totalDays, approvedBy }) {
  const typeLabel = _typeLabel(leaveType);
  const content = `
    <h2>✅ Leave Request Approved</h2>
    <p>Dear <strong>${employeeName}</strong>,</p>
    <p>Your ${typeLabel} leave request has been approved. Please find the details below:</p>
    <div class="detail-card">
      <div class="detail-row">
        <span class="detail-label">Leave Type</span>
        <span class="detail-value"><span class="badge badge-blue">${typeLabel}</span></span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Start Date</span>
        <span class="detail-value">${startDate}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">End Date</span>
        <span class="detail-value">${endDate}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Total Days</span>
        <span class="detail-value">${totalDays} working day${totalDays !== 1 ? 's' : ''}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Status</span>
        <span class="detail-value"><span class="badge badge-green">Approved</span></span>
      </div>
      ${approvedBy ? `<div class="detail-row"><span class="detail-label">Approved By</span><span class="detail-value">${approvedBy}</span></div>` : ''}
    </div>
    <p>Enjoy your time off! Contact HR if you need any assistance.</p>`;

  return sendEmail({
    to: employeeEmail,
    toName: employeeName,
    subject: `Leave Approved — ${typeLabel} (${totalDays} days)`,
    htmlContent: HTML_WRAPPER(content),
  });
}

async function sendLeaveRejectionEmail({ employeeEmail, employeeName, leaveType, startDate, endDate, totalDays, reason }) {
  const typeLabel = _typeLabel(leaveType);
  const content = `
    <h2>❌ Leave Request Declined</h2>
    <p>Dear <strong>${employeeName}</strong>,</p>
    <p>Unfortunately, your ${typeLabel} leave request has been declined.</p>
    <div class="detail-card">
      <div class="detail-row">
        <span class="detail-label">Leave Type</span>
        <span class="detail-value">${typeLabel}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Requested Dates</span>
        <span class="detail-value">${startDate} – ${endDate}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Duration</span>
        <span class="detail-value">${totalDays} working day${totalDays !== 1 ? 's' : ''}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Status</span>
        <span class="detail-value"><span class="badge badge-red">Declined</span></span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Reason</span>
        <span class="detail-value">${reason || 'No reason provided'}</span>
      </div>
    </div>
    <p>If you have questions, please contact your HR administrator.</p>`;

  return sendEmail({
    to: employeeEmail,
    toName: employeeName,
    subject: `Leave Request Declined — ${typeLabel}`,
    htmlContent: HTML_WRAPPER(content),
  });
}

async function sendLeaveNotification({ employeeEmail, managerEmail, employeeName, leaveType, startDate, endDate, totalDays, status, reason }) {
  if (status === 'approved') {
    return sendLeaveApprovalEmail({ employeeEmail, employeeName, leaveType, startDate, endDate, totalDays });
  }
  if (status === 'rejected') {
    return sendLeaveRejectionEmail({ employeeEmail, employeeName, leaveType, startDate, endDate, totalDays, reason: reason || '' });
  }
}

async function sendPayslipEmail({ employeeEmail, employeeName, payrollMonth, payslipUrl }) {
  const content = `
    <h2>Your Payslip is Ready</h2>
    <p>Dear <strong>${employeeName}</strong>,</p>
    <p>Your payslip for <strong>${payrollMonth}</strong> is now available.</p>
    ${payslipUrl ? `<p style="margin:20px 0"><a href="${payslipUrl}" style="background:#3B82F6;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:600;display:inline-block">View Payslip</a></p>` : ''}
    <p>Contact HR if you have any questions about your payslip.</p>`;

  return sendEmail({
    to: employeeEmail,
    toName: employeeName,
    subject: `Your Payslip for ${payrollMonth}`,
    htmlContent: HTML_WRAPPER(content),
  });
}

function _typeLabel(type) {
  const labels = {
    annual: 'Annual Leave', sick: 'Sick Leave',
    maternity: 'Maternity Leave', paternity: 'Paternity Leave',
    unpaid: 'Unpaid Leave', emergency: 'Emergency Leave',
    compassionate: 'Compassionate Leave',
  };
  return labels[type] || type;
}

module.exports = { sendEmail, sendLeaveApprovalEmail, sendLeaveRejectionEmail, sendLeaveNotification, sendPayslipEmail };
