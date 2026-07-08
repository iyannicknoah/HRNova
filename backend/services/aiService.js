const axios = require('axios');

const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

async function callGemini(prompt, maxTokens = 800) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY not configured.');

  try {
    const response = await axios.post(
      `${GEMINI_URL}?key=${apiKey}`,
      {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { maxOutputTokens: maxTokens, temperature: 0.7 },
      },
      { timeout: 30000 }
    );
    const text = response.data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) throw new Error('Empty response from Gemini');
    return text.trim();
  } catch (err) {
    const status = err.response?.status;
    if (status === 429) throw new Error('AI service is rate-limited. Please try again in a few minutes.');
    if (status === 503) throw new Error('AI service is temporarily unavailable. Please try again later.');
    if (err.code === 'ECONNABORTED' || err.message?.includes('timeout')) {
      throw new Error('AI service timed out. Please try again later.');
    }
    // Surface Gemini error detail if present
    const detail = err.response?.data?.error?.message;
    throw new Error(detail || err.message || 'AI service unavailable.');
  }
}

// Keep legacy alias so any future callers using callOpenRouter still work
const callOpenRouter = callGemini;

async function generateCompletion(prompt, systemPrompt = '') {
  return callGemini(
    systemPrompt ? `${systemPrompt}\n\n${prompt}` : prompt,
    800
  );
}

const MARKDOWN_RULE = `Format rules:
- Use ## for section headings
- Bold key numbers like **12** or **85%**
- Write in complete paragraphs — no bullet lists for narrative
- Do not add placeholder text like [Insert Date] or [Your Name]
- Do not repeat the title in the body

Language rules:
- Use simple, clear English that anyone can understand
- Use short sentences — one idea per sentence
- Avoid complex words; use everyday language
- Write like you are explaining to a colleague, not writing an academic paper
- Be direct and friendly in tone`;

async function generateReport(summaryData, reportType, companyName, isGroup = false) {
  const now = new Date();
  const hour = now.getHours();
  const timeOfDay = hour < 12 ? 'Morning' : hour < 17 ? 'Afternoon' : 'Evening';
  const todayStr = now.toLocaleDateString('en-RW', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

  // ── Group daily briefing ────────────────────────────────────────────────────
  if (isGroup) {
    const { overall, branches } = summaryData;
    const overallRate  = overall.attendanceRate ?? overall.avgAttendanceRate ?? 0;
    const totalPresent = overall.presentCount ?? overall.totalPresent ?? 0;
    const totalActive  = overall.totalActive ?? 0;
    const totalAbsent  = overall.absentCount ?? overall.totalAbsent ?? 0;
    const totalLate    = overall.lateCount   ?? overall.totalLate   ?? 0;
    const branchLines  = (branches || []).map(b => {
      const rate    = b.attendanceRate ?? b.avgAttendanceRate ?? 0;
      const present = b.presentCount   ?? b.totalPresent ?? 0;
      const total   = b.totalActive    ?? 0;
      const status  = rate >= 90 ? '✅ Excellent' : rate >= 75 ? '⚠️ Moderate' : '🔴 Low';
      return `- **${b.branchName}**: ${present} of ${total} present — **${rate}%** (${status})`;
    }).join('\n');

    const prompt = `You are the Group HR Assistant for ${companyName}. Write a professional ${timeOfDay} Group Attendance Briefing for ${todayStr}.

## Key Figures
- Total active employees across all branches: **${totalActive}**
- Present today: **${totalPresent}** (**${overallRate}%** attendance rate)
- Absent: **${totalAbsent}** | Late: **${totalLate}**

## Branch Breakdown
${branchLines || 'No branch data available.'}

${MARKDOWN_RULE}

Write 3 paragraphs: (1) overall attendance summary with actual numbers, (2) branch highlights — name the best and worst performing branches with their rates, (3) one clear actionable recommendation for management. Rwanda HR context. Professional tone.`;

    return callGemini(prompt, 1500);
  }

  // ── End of day ──────────────────────────────────────────────────────────────
  if (reportType === 'END_OF_DAY') {
    const d = summaryData;
    const prompt = `You are a professional HR analyst for ${companyName}. Write an End of Day Attendance Summary for ${todayStr}.

## Attendance Figures
- Active employees: **${d.totalActive ?? 0}**
- Checked in: **${(d.presentCount ?? 0) + (d.lateCount ?? 0)}** | On time: **${d.presentCount ?? 0}** | Late: **${d.lateCount ?? 0}**
- Absent: **${d.absentCount ?? 0}** | On leave: **${d.onLeaveCount ?? 0}**
- Overall attendance rate: **${d.attendanceRate ?? 0}%**

${MARKDOWN_RULE}

Write 2 concise paragraphs: (1) end-of-day summary referencing the exact numbers above, (2) any notable patterns or anomalies to flag for tomorrow. Rwanda HR context.`;
    return callGemini(prompt, 1200);
  }

  // ── Daily ───────────────────────────────────────────────────────────────────
  if (reportType === 'daily') {
    const d = summaryData;
    const lateNames   = (d.lateEmployees   || []).slice(0, 5).map(e => e.name || e).join(', ') || 'None';
    const absentNames = (d.absentEmployees || []).slice(0, 5).map(e => e.name || e).join(', ') || 'None';
    const deptLines   = Object.entries(d.departmentBreakdown || {})
      .map(([dept, info]) => `- **${dept}**: ${info.present ?? 0}/${info.total ?? 0} present`)
      .join('\n') || '- No department breakdown available';

    const prompt = `You are a professional HR analyst for ${companyName}. Write a ${timeOfDay} Daily Attendance Report for ${todayStr}.

## Attendance Summary
- Active employees: **${d.totalActive ?? 0}**
- Present (on time): **${d.presentCount ?? 0}**
- Late arrivals: **${d.lateCount ?? 0}**
- Absent: **${d.absentCount ?? 0}**
- On leave: **${d.onLeaveCount ?? 0}**
- Attendance rate: **${d.attendanceRate ?? 0}%**

## Late Employees
${lateNames}

## Absent Employees
${absentNames}

## By Department
${deptLines}

${MARKDOWN_RULE}

Write 3 paragraphs using the exact numbers above: (1) attendance overview for today, (2) late and absent employee highlights by name and department, (3) one specific recommendation based on today's data. Rwanda HR context.`;

    return callGemini(prompt, 1500);
  }

  // ── Weekly ──────────────────────────────────────────────────────────────────
  if (reportType === 'weekly') {
    const w = summaryData;
    const dailyLines = (w.dailyBreakdown || [])
      .map(d => `- ${d.date}: **${d.present ?? 0}** present, **${d.absent ?? 0}** absent, rate **${d.rate ?? 0}%**`)
      .join('\n') || '- No daily breakdown available';

    const trend = w.avgRate > (w.prevAvgRate ?? w.avgRate)
      ? `📈 Up from last week (${w.prevAvgRate ?? 'N/A'}%)`
      : w.avgRate < (w.prevAvgRate ?? w.avgRate)
        ? `📉 Down from last week (${w.prevAvgRate ?? 'N/A'}%)`
        : 'Stable compared to last week';

    const prompt = `You are a professional HR analyst for ${companyName}. Write a Weekly Attendance Report Summary for the week starting ${w.startDate ?? 'this week'}.

## Weekly Figures
- Active employees: **${w.totalActive ?? 0}**
- Total present records this week: **${w.totalPresent ?? 0}**
- Total late: **${w.totalLate ?? 0}** | Total absent: **${w.totalAbsent ?? 0}**
- Average weekly attendance rate: **${w.avgRate ?? 0}%**
- Trend: ${trend}

## Daily Breakdown
${dailyLines}

${MARKDOWN_RULE}

Write 3 paragraphs: (1) weekly attendance overview with exact figures, (2) daily pattern analysis — which days had lowest and highest attendance and why this matters, (3) one specific recommendation for next week. Rwanda HR context.`;

    return callGemini(prompt, 1500);
  }

  // ── Monthly ─────────────────────────────────────────────────────────────────
  const m = summaryData;
  const leaveLines = Object.entries(m.leaveByType || {})
    .map(([type, days]) => `- ${type}: **${days}** days`)
    .join('\n') || '- No leave recorded this month';

  const prompt = `You are a professional HR analyst for ${companyName}. Write a Monthly HR Report for ${m.month ?? 'this month'}.

## Attendance
- Active employees: **${m.totalActive ?? 0}** | Working days: **${m.workingDays ?? 0}**
- Total present records: **${m.totalPresent ?? 0}** | Total absent: **${m.totalAbsent ?? 0}** | Total late: **${m.totalLate ?? 0}**
- Average monthly attendance rate: **${m.avgAttendanceRate ?? 0}%**

## Leave
${leaveLines}

## Payroll
- Employees on payroll: **${m.payrollCount ?? 0}**
- Total net salary paid: **RWF ${(m.payrollTotal ?? 0).toLocaleString()}**

## Performance
${m.avgPerformance ? `- Average performance score: **${m.avgPerformance}/5** across **${m.performanceCount}** employees reviewed` : '- No performance reviews recorded this month'}

${MARKDOWN_RULE}

Write 4 paragraphs: (1) monthly attendance overview with exact numbers, (2) leave and payroll highlights, (3) performance insights, (4) two clear recommendations for next month. Rwanda HR context.`;

  return callGemini(prompt, 2000);
}

async function answerQuestion(question, contextData, companyName) {
  const prompt = `You are Nova, the AI HR assistant for ${companyName}. You have full access to the company's HR data shown below.

COMPANY DATA:
${JSON.stringify(contextData, null, 2)}

USER QUESTION: ${question}

Instructions:
- Answer directly using the real numbers from the data above
- Use simple, clear English — short sentences
- Bold important numbers like **12 employees** or **85%**
- If you list items, use bullet points with *
- If the data clearly answers the question, give a specific answer — do not say "I don't have enough data" when the data is there
- If the question is truly outside the data provided, say what you do know and suggest what report to run
- Keep the answer short and helpful — under 200 words
- Do not repeat the question back`;

  return callGemini(prompt, 800);
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
  return callGemini(prompt, 400);
}

module.exports = {
  callGemini, callOpenRouter, generateReport, answerQuestion,
  generateCompletion, generatePerformanceReview, generateAnnualPerformance,
  screenCv, generateAnomalyAlert,
};
