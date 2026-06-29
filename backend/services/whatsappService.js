/**
 * WhatsApp Service
 * Handles sending WhatsApp notifications to employees and managers.
 */

/**
 * Sends a WhatsApp message.
 * @param {string} phoneNumber - Recipient phone number (with country code).
 * @param {string} message - Message body content.
 * @returns {Promise<boolean>} Resolves to true if message was sent successfully.
 */
async function sendWhatsAppMessage(phoneNumber, message) {
  // Implementation stub for later integration with WhatsApp API
  console.log(`Sending WhatsApp message to ${phoneNumber}: "${message}"`);
  return true;
}

module.exports = {
  sendWhatsAppMessage,
};
