/**
 * AI Service
 * Handles interfacing with OpenRouter API to generate HR reports.
 */

const axios = require('axios');

/**
 * Generates an HR report based on a prompt and input data.
 * @param {string} prompt - The prompt instructions.
 * @param {object} data - The data context for the report.
 * @returns {Promise<string>} The AI generated report content.
 */
async function generateReport(prompt, data) {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY is not configured in the environment.');
  }

  // Implementation stub for later stages
  console.log('Generating AI report using OpenRouter API...');
  
  // Return a mock response for validation purposes
  return `Mock AI Report for: ${data.reportName || 'HR Summary'}\nGenerated at: ${new Date().toISOString()}`;
}

module.exports = {
  generateReport,
};
