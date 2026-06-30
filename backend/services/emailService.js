// Brevo email service — cloud only (9,000/month free tier)
// Full implementation in Part 9

async function sendEmail({ to, subject, htmlContent, textContent }) {
  // Scaffold — implemented in Part 9
  console.log(`[EmailService] Would send to ${to}: ${subject}`);
  return { messageId: 'scaffold' };
}

async function sendLeaveNotification({ employeeEmail, managerEmail, employeeName, leaveType, startDate, endDate, status }) {
  // Scaffold
  return sendEmail({
    to: managerEmail,
    subject: `Leave ${status}: ${employeeName}`,
    htmlContent: `<p>${employeeName} has requested ${leaveType} leave from ${startDate} to ${endDate}.</p>`,
  });
}

async function sendPayslipEmail({ employeeEmail, employeeName, payrollMonth, payslipUrl }) {
  // Scaffold
  return sendEmail({
    to: employeeEmail,
    subject: `Your payslip for ${payrollMonth}`,
    htmlContent: `<p>Dear ${employeeName}, your payslip for ${payrollMonth} is ready.</p>`,
  });
}

module.exports = { sendEmail, sendLeaveNotification, sendPayslipEmail };
