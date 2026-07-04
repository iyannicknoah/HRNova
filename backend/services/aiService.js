const axios = require('axios');

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const MODEL = process.env.OPENROUTER_MODEL || 'google/gemma-2-9b-it:free';

const _headers = {
  Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
  'Content-Type': 'application/json',
  'HTTP-Referer': 'https://hrnova.rw',
  'X-Title': 'HRNova',
};

async function callOpenRouter(prompt, maxTokens = 800) {
  try {
    const response = await axios.post(
      OPENROUTER_URL,
      { model: MODEL, max_tokens: maxTokens, messages: [{ role: 'user', content: prompt }] },
      { headers: _headers, timeout: 30000 }
    );
    return response.data.choices[0]?.message?.content?.trim() || '';
  } catch (err) {
    if (err.code === 'ECONNABORTED' || err.message?.includes('timeout')) {
      throw new Error('AI service timed out. Please try again.');
    }
    throw new Error('AI service unavailable. Please try again later.');
  }
}

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
    { headers: _headers, timeout: 30000 }
  );
  return response.data.choices[0]?.message?.content || '';
}

async function generateReport(summaryData, reportType, companyName, isGroup = false) {
  if (isGroup) {
    const { overall, branches } = summaryData;
    const overallRate = overall.attendanceRate ?? overall.avgAttendanceRate ?? 0;
    const totalPresent = overall.presentCount ?? overall.totalPresent ?? 0;
    const totalActive = overall.totalActive ?? 0;
    const branchLines = branches.map(b => {
      const rate = b.attendanceRate ?? b.avgAttendanceRate ?? 0;
      const emoji = rate >= 90 ? 'GOOD' : rate >= 70 ? 'WARN' : 'LOW';
      const present = b.presentCount ?? b.totalPresent ?? 0;
      const total = b.totalActive ?? 0;
      return `[${emoji}] ${b.branchName}: ${present}/${total} present — ${rate}%`;
    }).join('\n');

    const prompt = `You are an HR analytics expert. Write a professional group HR daily report for ${companyName}.

OVERALL: ${totalPresent} of ${totalActive} present (${overallRate}%)
BY BRANCH:
${branchLines}

Write a concise professional report (3-4 paragraphs): overall attendance summary, branch-by-branch highlights, notable patterns, and one recommendation. Rwanda HR context. Professional tone only.`;

    return callOpenRouter(prompt, 700);
  }

  if (reportType === 'END_OF_DAY') {
    const prompt = `You are a professional HR analyst. Write a brief end-of-day attendance summary for ${companyName}.

DATA:
${JSON.stringify(summaryData, null, 2)}

Write a concise end-of-day summary (2-3 paragraphs): total check-outs vs check-ins, any employees still logged in, overall hours overview, and any anomalies or concerns. Keep it short and factual. Rwanda HR context.`;
    return callOpenRouter(prompt, 500);
  }

  const typeLabel = { daily: 'Morning Attendance', weekly: 'Weekly Attendance', monthly: 'Monthly HR Summary' }[reportType] || 'HR';

  const prompt = `You are a professional HR analyst. Write a ${typeLabel} report for ${companyName}.

DATA:
${JSON.stringify(summaryData, null, 2)}

Write a concise professional report (3-4 paragraphs): attendance overview, notable patterns (departments with low attendance, frequent latecomers), leave and payroll highlights if available, and one actionable recommendation. Rwanda HR context. Do not list every number — highlight key insights only.`;

  return callOpenRouter(prompt, 700);
}

async function answerQuestion(question, contextData, companyName) {
  const prompt = `You are Nova, an AI HR assistant for ${companyName}. Answer the following HR question using the provided data.

QUESTION: ${question}

DATA:
${JSON.stringify(contextData, null, 2)}

Answer concisely and directly (under 150 words). If data is insufficient, say so honestly.`;

  return callOpenRouter(prompt, 400);
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

async function screenCv(cvText, jobRequirements) {
  return generateCompletion(
    `Screen this CV against job requirements:\n\nJob: ${jobRequirements}\n\nCV: ${cvText}`,
    'You are an expert HR recruiter in Rwanda. Score CVs 0-100 and provide structured feedback.'
  );
}

async function generateAnomalyAlert(anomalies, companyName) {
  if (!anomalies || anomalies.length === 0) {
    return 'No anomalies detected. All HR patterns are normal.';
  }
  const prompt = `You are HR assistant for ${companyName}. Review these HR anomalies and write a brief professional alert (under 200 words). Be specific about each person/department. Suggest one action per anomaly type.

Anomalies:
${JSON.stringify(anomalies, null, 2)}`;
  return callOpenRouter(prompt, 400);
}

module.exports = { callOpenRouter, generateReport, answerQuestion, generateCompletion, generatePerformanceReview, generateAnnualPerformance, screenCv, generateAnomalyAlert };
