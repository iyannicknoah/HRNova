const Brevo = require('@getbrevo/brevo');

const api = new Brevo.TransactionalEmailsApi();
api.authentications['apiKey'].apiKey = process.env.BREVO_API_KEY ?? '';

const SENDER = { name: 'HRNovva', email: 'noreply@hrnova.rw' };

function escHtml(s) {
  return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Converts AI markdown output to clean email HTML
function markdownToHtml(md) {
  if (!md) return '';
  const inlineBold = (text) => text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  const lines = md.split('\n');
  let html = '';
  let inList = false;

  for (const line of lines) {
    if (line.startsWith('## ')) {
      if (inList) { html += '</ul>'; inList = false; }
      html += `<h3 style="font-size:15px;font-weight:700;color:#0f172a;margin:20px 0 8px;padding-bottom:6px;border-bottom:1px solid #e2e8f0">${inlineBold(escHtml(line.slice(3)))}</h3>`;
    } else if (/^[*\-] /.test(line)) {
      if (!inList) { html += '<ul style="padding-left:18px;margin:8px 0">'; inList = true; }
      html += `<li style="color:#334155;font-size:14px;line-height:1.75;margin:4px 0">${inlineBold(line.replace(/^[*\-] /, ''))}</li>`;
    } else if (line.trim() === '') {
      if (inList) { html += '</ul>'; inList = false; }
    } else {
      if (inList) { html += '</ul>'; inList = false; }
      html += `<p style="color:#334155;font-size:14px;line-height:1.75;margin:8px 0">${inlineBold(line)}</p>`;
    }
  }
  if (inList) html += '</ul>';
  return html;
}

const HTML_WRAPPER = (content, companyName) => `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f0f4f8; }
    .wrapper { max-width: 580px; margin: 32px auto; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.12); }
    .header { background: #0A1628; padding: 28px 32px; }
    .company-name { font-size: 22px; font-weight: 800; color: #fff; letter-spacing: -0.3px; }
    .logo-sub { font-size: 12px; font-weight: 600; color: #64748b; margin-top: 3px; }
    .logo-sub span { color: #94a3b8; }
    .logo-sub em { color: #3B82F6; font-style: normal; }
    .logo { font-size: 22px; font-weight: 800; }
    .logo span { color: #fff; }
    .logo em { color: #3B82F6; font-style: normal; }
    .tagline { color: #475569; font-size: 12px; margin-top: 4px; }
    .body { background: #fff; padding: 32px; }
    .body h2 { font-size: 20px; color: #0f172a; margin-bottom: 8px; }
    .body p { color: #475569; font-size: 14px; line-height: 1.6; margin-bottom: 12px; }
    .detail-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 24px; margin: 20px 0; }
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
      ${companyName
        ? `<div class="company-name">${escHtml(companyName)}</div>
           <div class="logo-sub"><span>HR</span><em>Nova</em> &bull; HR Management</div>`
        : `<div class="logo"><span>HR</span><em>Nova</em></div>`}
      <div class="tagline">Your HR Team, Supercharged</div>
    </div>
    <div class="body">${content}</div>
    <div class="footer">
      <p>Automated message from HRNovva. Do not reply.</p>
      <p style="margin-top:6px">© ${new Date().getFullYear()} HRNovva • Rwanda</p>
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

async function sendPayslipEmail({ employeeEmail, employeeName, payrollMonth, pdfBase64, pdfFilename }) {
  const content = `
    <h2>Your Payslip is Ready</h2>
    <p>Dear <strong>${employeeName}</strong>,</p>
    <p>Your payslip for <strong>${payrollMonth}</strong> is attached to this email as a PDF.</p>
    <div class="detail-card">
      <div class="detail-row">
        <span class="detail-label">Period</span>
        <span class="detail-value">${payrollMonth}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Employee</span>
        <span class="detail-value">${employeeName}</span>
      </div>
    </div>
    <p>Please keep this payslip for your records. Contact HR if you have any questions.</p>`;

  if (!process.env.BREVO_API_KEY) {
    console.log(`[Email] No API key — skipping payslip send to ${employeeEmail}`);
    return { messageId: 'no-api-key' };
  }

  try {
    const payload = {
      subject: `Your Payslip for ${payrollMonth}`,
      htmlContent: HTML_WRAPPER(content),
      sender: SENDER,
      to: [{ email: employeeEmail, name: employeeName }],
    };

    // Attach PDF if provided (Brevo accepts base64 content)
    if (pdfBase64) {
      payload.attachment = [{
        content: pdfBase64,
        name: pdfFilename || `Payslip_${payrollMonth}.pdf`,
      }];
    }

    const result = await api.sendTransacEmail(payload);
    console.log(`[Email] Payslip sent to ${employeeEmail} for ${payrollMonth}`);
    return result;
  } catch (err) {
    console.error('[Email] Payslip send error:', err?.response?.body ?? err.message);
    throw err;
  }
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

async function sendReportEmail(recipients, reportType, reportContent, companyName) {
  if (!process.env.BREVO_API_KEY) {
    console.log(`[Email] No API key — skipping report email (${reportType})`);
    return { messageId: 'no-api-key' };
  }

  const typeLabels = {
    daily: 'Morning Attendance Report',
    weekly: 'Weekly HR Summary',
    monthly: 'Monthly HR Report',
    group_daily: 'Group Morning Report',
    end_of_day: 'End of Day Summary',
    end_of_day_branch: 'Branch End of Day Summary',
    'Morning Attendance': 'Morning Attendance Report',
    'End of Day Summary': 'End of Day Summary',
    'Group Morning Attendance': 'Group Morning Report',
  };
  const typeLabel = typeLabels[reportType] || reportType;
  const dateStr = new Date().toLocaleDateString('en-RW', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });

  const renderedReport = markdownToHtml(reportContent);
  const content = `
    <h2>&#128202; ${typeLabel}</h2>
    <p style="color:#64748b;font-size:13px;margin-bottom:16px">${escHtml(companyName)} &bull; ${dateStr}</p>
    <div class="detail-card">${renderedReport}</div>
    <p style="font-size:12px;color:#94a3b8;margin-top:16px">This report was automatically generated by HRNovva AI.</p>`;

  try {
    const result = await api.sendTransacEmail({
      subject: `${escHtml(companyName)} — ${typeLabel} — ${new Date().toLocaleDateString('en-RW')}`,
      htmlContent: HTML_WRAPPER(content, companyName),
      sender: SENDER,
      to: recipients.map(r => ({ email: r.email, name: r.name || r.email })),
    });
    console.log(`[Email] Report sent to ${recipients.map(r => r.email).join(', ')}: ${typeLabel}`);
    return result;
  } catch (err) {
    console.error('[Email] Report send error:', err?.response?.body ?? err.message);
    throw err;
  }
}

async function sendPerformanceReminderEmail({ managerEmail, managerName, unscoredCount, totalCount, month, companyName }) {
  const [year, mo] = month.split('-');
  const monthLabel = new Date(Number(year), Number(mo) - 1).toLocaleString('en-RW', { month: 'long', year: 'numeric' });
  const content = `
    <h2>⏰ Performance Scoring Reminder</h2>
    <p>Dear <strong>${managerName}</strong>,</p>
    <p>This is a reminder from <strong>${companyName}</strong> that you still have <strong>${unscoredCount}</strong> of <strong>${totalCount}</strong>
    employee${totalCount === 1 ? '' : 's'} to score for <strong>${monthLabel}</strong>.</p>
    <div class="detail-card">
      <div class="detail-row">
        <span class="detail-label">Company</span>
        <span class="detail-value">${companyName}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Month</span>
        <span class="detail-value">${monthLabel}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Already Scored</span>
        <span class="detail-value">${totalCount - unscoredCount} / ${totalCount}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Still Remaining</span>
        <span class="detail-value badge badge-red">${unscoredCount}</span>
      </div>
    </div>
    <p>Please log in to HRNovva and complete your performance reviews before the end of the month.</p>`;

  return sendEmail({
    to: managerEmail,
    toName: managerName,
    subject: `HRNovva — ${unscoredCount} employee${unscoredCount === 1 ? '' : 's'} still to score — ${monthLabel}`,
    htmlContent: HTML_WRAPPER(content),
  });
}

async function sendApplicationConfirmationEmail({ applicantEmail, applicantName, jobTitle, companyName }) {
  const content = `
    <h2>&#10003; Application Received</h2>
    <p>Dear <strong>${escHtml(applicantName)}</strong>,</p>
    <p>Thank you for applying to <strong>${escHtml(companyName)}</strong>. We have received your application for the position below.</p>
    <div class="detail-card">
      <div class="detail-row">
        <span class="detail-label">Position</span>
        <span class="detail-value">${escHtml(jobTitle)}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Company</span>
        <span class="detail-value">${escHtml(companyName)}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Status</span>
        <span class="detail-value"><span class="badge badge-blue">Under Review</span></span>
      </div>
    </div>
    <p>Our team will review your application and contact you if you are shortlisted. We appreciate your interest and wish you the best of luck.</p>`;

  return sendEmail({
    to: applicantEmail,
    toName: applicantName,
    subject: `Application Received — ${jobTitle} at ${companyName}`,
    htmlContent: HTML_WRAPPER(content, companyName),
  });
}

async function sendInterviewInvitationEmail({ applicantEmail, applicantName, jobTitle, companyName, interviewDate, interviewTime, interviewLocation }) {
  const content = `
    <h2>&#127881; Interview Invitation</h2>
    <p>Dear <strong>${escHtml(applicantName)}</strong>,</p>
    <p>Congratulations! We are pleased to invite you for an interview at <strong>${escHtml(companyName)}</strong> for the position of <strong>${escHtml(jobTitle)}</strong>.</p>
    <div class="detail-card">
      <div class="detail-row">
        <span class="detail-label">Position</span>
        <span class="detail-value">${escHtml(jobTitle)}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Date</span>
        <span class="detail-value">${escHtml(interviewDate)}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Time</span>
        <span class="detail-value">${escHtml(interviewTime || 'To be confirmed')}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Location</span>
        <span class="detail-value">${escHtml(interviewLocation || 'To be communicated')}</span>
      </div>
    </div>
    <p>Please confirm your attendance by replying to this email. If you need to reschedule, contact us as soon as possible.</p>
    <p>We look forward to meeting you. Good luck!</p>`;

  return sendEmail({
    to: applicantEmail,
    toName: applicantName,
    subject: `Interview Invitation — ${jobTitle} at ${companyName}`,
    htmlContent: HTML_WRAPPER(content, companyName),
  });
}

async function sendRejectionEmail({ applicantEmail, applicantName, jobTitle, companyName }) {
  const content = `
    <h2>Your Application Update</h2>
    <p>Dear <strong>${escHtml(applicantName)}</strong>,</p>
    <p>Thank you very much for taking the time to apply for the position of <strong>${escHtml(jobTitle)}</strong> at <strong>${escHtml(companyName)}</strong>.</p>
    <p>After careful review of all applications, we regret to inform you that we will not be moving forward with your application at this time.</p>
    <div class="detail-card">
      <div class="detail-row">
        <span class="detail-label">Position Applied</span>
        <span class="detail-value">${escHtml(jobTitle)}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Decision</span>
        <span class="detail-value"><span class="badge badge-red">Not Selected</span></span>
      </div>
    </div>
    <p>We appreciate your interest in joining our team. We encourage you to apply for future opportunities that match your skills and experience.</p>
    <p>We wish you all the best in your career journey.</p>`;

  return sendEmail({
    to: applicantEmail,
    toName: applicantName,
    subject: `Application Update — ${jobTitle} at ${companyName}`,
    htmlContent: HTML_WRAPPER(content, companyName),
  });
}

module.exports = {
  sendEmail, sendLeaveApprovalEmail, sendLeaveRejectionEmail, sendLeaveNotification,
  sendPayslipEmail, sendReportEmail, sendPerformanceReminderEmail,
  sendApplicationConfirmationEmail, sendInterviewInvitationEmail, sendRejectionEmail,
};
