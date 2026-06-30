const axios = require('axios');

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const MODEL = process.env.OPENROUTER_MODEL || 'google/gemma-2-9b-it:free';

async function generateCompletion(prompt, systemPrompt = '') {
  const response = await axios.post(
    OPENROUTER_URL,
    {
      model: MODEL,
      messages: [
        ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
        { role: 'user', content: prompt },
      ],
    },
    {
      headers: {
        Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://hrnova.rw',
        'X-Title': 'HRNova',
      },
    }
  );

  return response.data.choices[0]?.message?.content || '';
}

// Scaffold functions — implemented in later parts
async function generateAttendanceReport(data) {
  // Part 9
  return generateCompletion(`Generate an HR attendance report for Rwanda: ${JSON.stringify(data)}`);
}

async function screenCv(cvText, jobRequirements) {
  // Part 10
  return generateCompletion(
    `Screen this CV against job requirements:\n\nJob: ${jobRequirements}\n\nCV: ${cvText}`,
    'You are an expert HR recruiter in Rwanda. Score CVs 0-100 and provide structured feedback.'
  );
}

async function generatePerformanceReview(data) {
  // Part 8
  return generateCompletion(`Generate a performance review: ${JSON.stringify(data)}`);
}

module.exports = { generateCompletion, generateAttendanceReport, screenCv, generatePerformanceReview };
