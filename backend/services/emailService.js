/**
 * Email Service
 * Handles sending email notifications (e.g. leave requests, reports) using Nodemailer.
 */

const nodemailer = require('nodemailer');

// Configure the transporter with environment variables (will be configured in next stages)
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.mailtrap.io',
  port: parseInt(process.env.SMTP_PORT || '2525', 10),
  auth: {
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
  },
});

/**
 * Sends an email message.
 * @param {string} to - Recipient email.
 * @param {string} subject - Email subject line.
 * @param {string} text - Plain text body.
 * @param {string} html - HTML body content.
 * @returns {Promise<object>} The nodemailer send result.
 */
async function sendEmail({ to, subject, text, html }) {
  // Implementation stub for later use
  console.log(`Sending email to ${to}: "${subject}"`);
  
  // Return a mock result
  return {
    messageId: `mock-email-id-${Date.now()}`,
    accepted: [to],
  };
}

module.exports = {
  sendEmail,
  transporter,
};
