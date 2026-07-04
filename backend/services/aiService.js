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

async function generatePerformanceReview({ employeeName, jobTitle, criteria, scores, overallScore }) {
  const criteriaLines = criteria.map(c => `- ${c.name} (${c.weight}%): ${scores[c.name]}/5`).join('\n');
  const prompt = `Write a professional 2-3 sentence performance review for ${employeeName}, ${jobTitle}.\nScores:\n${criteriaLines}\nOverall: ${overallScore.toFixed(1)}/5.\nBe specific and constructive. Do not use bullet points.`;
  return generateCompletion(prompt, 'You are an expert HR professional writing concise, fair, and constructive performance reviews.');
}

async function generateAnnualPerformance({ employee, monthlyScores, attendanceSummary }) {
  const months = monthlyScores.map(m => `${m.month}: ${m.score.toFixed(1)}/5`).join(', ');
  const prompt = `Write a professional annual performance narrative for ${employee.name}, ${employee.jobTitle} in ${employee.department}.\nMonthly scores: ${months}\nAttendance: ${JSON.stringify(attendanceSummary)}\nInclude: quarterly averages, best/worst month, trend analysis, attendance correlation, and a clear recommendation level (Exceeds/Meets/Needs Improvement). Write 3-4 paragraphs.`;
  return generateCompletion(prompt, 'You are an expert HR manager writing comprehensive annual performance reports.');
}

module.exports = { generateCompletion, generateAttendanceReport, screenCv, generatePerformanceReview, generateAnnualPerformance };
