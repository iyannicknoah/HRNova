const pdfParse = require('pdf-parse');
const { getFirestore } = require('firebase-admin/firestore');
const { s3, BUCKET } = require('./storageService');
const { GetObjectCommand } = require('@aws-sdk/client-s3');
const { callGemini } = require('./aiService');

async function _downloadBuffer(key) {
  const res = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
  const chunks = [];
  for await (const chunk of res.Body) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function screenApplication(applicationId, companyId, jobId) {
  const db = getFirestore('default');

  const [appSnap, jobSnap] = await Promise.all([
    db.collection('companies').doc(companyId).collection('applications').doc(applicationId).get(),
    db.collection('companies').doc(companyId).collection('jobs').doc(jobId).get(),
  ]);

  if (!appSnap.exists || !jobSnap.exists) {
    throw new Error('Application or job not found');
  }

  const app = appSnap.data();
  const job = jobSnap.data();

  // Download and parse CV PDF
  let cvText = '';
  if (app.cvKey) {
    try {
      const buffer = await _downloadBuffer(app.cvKey);
      const parsed = await pdfParse(buffer);
      cvText = parsed.text?.slice(0, 6000) || '';
    } catch (err) {
      console.error('[Screening] CV parse error:', err.message);
      cvText = 'CV text could not be extracted.';
    }
  }

  const prompt = `You are an expert HR recruiter in Rwanda. Score this job application strictly and objectively.

JOB DETAILS:
Title: ${job.title}
Department: ${job.department}
Required Experience: ${job.minExperience || 0}+ years
Required Skills: ${(job.requiredSkills || []).join(', ') || 'Not specified'}
Requirements: ${job.requirements || 'Not specified'}
AI Screening Criteria: ${job.aiCriteria || 'None provided'}

APPLICANT:
Name: ${app.applicantName}
Years of Experience: ${app.yearsExperience || 0}
Cover Letter: ${app.coverLetter || 'Not provided'}

CV TEXT:
${cvText || 'No CV provided'}

Score the applicant on a scale of 0-100 for each dimension:
- qualificationScore: Does their education and background match the role?
- experienceScore: Do they have the required years and type of experience?
- skillsScore: Do they have the required technical/professional skills?
- communicationScore: Is their cover letter and writing clear and professional?

Then give an overall totalScore (weighted average).

Recommendation rules:
- "accept" if totalScore >= 75
- "review" if totalScore >= 50
- "reject" if totalScore < 50

Return ONLY valid JSON, no markdown, no explanation:
{
  "totalScore": number,
  "qualificationScore": number,
  "experienceScore": number,
  "skillsScore": number,
  "communicationScore": number,
  "recommendation": "accept" | "review" | "reject",
  "strengths": ["strength 1", "strength 2", "strength 3"],
  "concerns": ["concern 1", "concern 2"],
  "aiSummary": "2-3 sentence professional assessment in simple English"
}`;

  const raw = await callGemini(prompt, 600);

  // Extract JSON from response (Gemini sometimes wraps in markdown)
  const jsonMatch = raw.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error('AI returned invalid JSON: ' + raw.slice(0, 200));

  const scores = JSON.parse(jsonMatch[0]);

  // Validate
  const total = Math.round(Math.max(0, Math.min(100, Number(scores.totalScore) || 0)));
  const update = {
    aiScore: total,
    aiQualificationScore: Math.round(Math.max(0, Math.min(100, Number(scores.qualificationScore) || 0))),
    aiExperienceScore: Math.round(Math.max(0, Math.min(100, Number(scores.experienceScore) || 0))),
    aiSkillsScore: Math.round(Math.max(0, Math.min(100, Number(scores.skillsScore) || 0))),
    aiCommunicationScore: Math.round(Math.max(0, Math.min(100, Number(scores.communicationScore) || 0))),
    aiRecommendation: ['accept', 'review', 'reject'].includes(scores.recommendation) ? scores.recommendation : 'review',
    aiStrengths: Array.isArray(scores.strengths) ? scores.strengths.slice(0, 3) : [],
    aiConcerns: Array.isArray(scores.concerns) ? scores.concerns.slice(0, 2) : [],
    aiSummary: typeof scores.aiSummary === 'string' ? scores.aiSummary : '',
    screenedAt: new Date(),
  };

  await appSnap.ref.update(update);

  // HR admin notification
  try {
    await db.collection('companies').doc(companyId).collection('notifications').add({
      type: 'new_application',
      title: 'New Application Screened',
      message: `${app.applicantName} applied for ${job.title} — AI Score: ${total}/100`,
      targetRole: 'hr_admin',
      jobId,
      applicationId,
      aiScore: total,
      read: false,
      createdAt: new Date().toISOString(),
    });
  } catch (_) {}

  return update;
}

module.exports = { screenApplication };
