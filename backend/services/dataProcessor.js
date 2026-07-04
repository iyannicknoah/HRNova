// ── Data Processor — builds clean summaries for AI (never raw Firestore docs) ──

function _dateStr(d) {
  const dt = d instanceof Date ? d : new Date(d + 'T00:00:00');
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`;
}

async function buildDailySummary(db, companyId, date, branchId = null) {
  const dateKey = typeof date === 'string' ? date : _dateStr(date);
  const base = db.collection('companies').doc(companyId);

  let attQ = base.collection('attendance').where('date', '==', dateKey);
  let empQ = base.collection('employees').where('status', '==', 'active');
  let calQ = base.collection('leaves_calendar').where('date', '==', dateKey);
  if (branchId) {
    attQ = attQ.where('branchId', '==', branchId);
    empQ = empQ.where('branchId', '==', branchId);
    calQ = calQ.where('branchId', '==', branchId);
  }

  const [attSnap, empSnap, calSnap] = await Promise.all([attQ.get(), empQ.get(), calQ.get()]);

  const totalActive  = empSnap.size;
  const records      = attSnap.docs.map(d => d.data());
  const onLeaveIds   = new Set(calSnap.docs.map(d => d.data().employeeId).filter(Boolean));
  const presentCount = records.filter(r => r.status === 'on_time' || r.status === 'present').length;
  const lateCount    = records.filter(r => r.status === 'late').length;
  const onLeaveCount = onLeaveIds.size;
  const absentCount  = Math.max(0, totalActive - presentCount - lateCount - onLeaveCount);
  const attendanceRate = totalActive > 0
    ? Math.round(((presentCount + lateCount) / totalActive) * 100) : 0;

  const empMap = {};
  empSnap.docs.forEach(d => { empMap[d.id] = d.data(); });

  const lateEmployees = records
    .filter(r => r.status === 'late')
    .map(r => ({
      name: r.employeeName ||
        `${empMap[r.employeeId]?.firstName || ''} ${empMap[r.employeeId]?.lastName || ''}`.trim() || r.employeeId,
      department: r.department || empMap[r.employeeId]?.department || '',
    }));

  const presentIds = new Set(
    records.filter(r => ['on_time', 'present', 'late'].includes(r.status)).map(r => r.employeeId)
  );
  const absentEmployees = empSnap.docs
    .filter(d => !presentIds.has(d.id) && !onLeaveIds.has(d.id))
    .slice(0, 10)
    .map(d => ({
      name: `${d.data().firstName || ''} ${d.data().lastName || ''}`.trim(),
      department: d.data().department || '',
    }));

  const deptTotals = {}, deptPresent = {};
  empSnap.docs.forEach(d => {
    const dept = d.data().department || 'Unknown';
    deptTotals[dept] = (deptTotals[dept] || 0) + 1;
  });
  records.filter(r => ['on_time', 'present', 'late'].includes(r.status)).forEach(r => {
    const dept = r.department || empMap[r.employeeId]?.department || 'Unknown';
    deptPresent[dept] = (deptPresent[dept] || 0) + 1;
  });
  const departmentBreakdown = Object.keys(deptTotals).map(dept => ({
    department: dept,
    total: deptTotals[dept],
    present: deptPresent[dept] || 0,
    rate: Math.round(((deptPresent[dept] || 0) / deptTotals[dept]) * 100),
  }));

  return { date: dateKey, totalActive, presentCount, lateCount, absentCount, onLeaveCount, attendanceRate, lateEmployees, absentEmployees, departmentBreakdown };
}

async function buildWeeklySummary(db, companyId, startDate, branchId = null) {
  const start = new Date(typeof startDate === 'string' ? startDate + 'T00:00:00' : startDate);
  const days  = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start); d.setDate(d.getDate() + i); return _dateStr(d);
  });
  const dailies = await Promise.all(days.map(d => buildDailySummary(db, companyId, d, branchId)));
  const avgRate = Math.round(dailies.reduce((a, b) => a + b.attendanceRate, 0) / 7);

  // Previous week comparison
  const prevStart = new Date(start); prevStart.setDate(prevStart.getDate() - 7);
  const prevDays  = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(prevStart); d.setDate(d.getDate() + i); return _dateStr(d);
  });
  const prevDailies  = await Promise.all(prevDays.map(d => buildDailySummary(db, companyId, d, branchId)));
  const prevAvgRate  = Math.round(prevDailies.reduce((a, b) => a + b.attendanceRate, 0) / 7);

  // Leave activity this week
  const base = db.collection('companies').doc(companyId);
  let leaveQ = base.collection('leave_requests')
    .where('requestedAt', '>=', start)
    .where('requestedAt', '<=', new Date(start.getTime() + 7 * 24 * 3600 * 1000));
  if (branchId) leaveQ = leaveQ.where('branchId', '==', branchId);
  const leaveSnap = await leaveQ.get().catch(() => ({ docs: [] }));
  const leaveActivity = leaveSnap.docs.slice(0, 8).map(d => ({
    employee: d.data().employeeName,
    type: d.data().leaveType,
    status: d.data().status,
  }));

  return {
    startDate: days[0], endDate: days[6],
    avgAttendanceRate: avgRate,
    weekOnWeekChange: avgRate - prevAvgRate,
    totalPresent:  dailies.reduce((a, b) => a + b.presentCount, 0),
    totalLate:     dailies.reduce((a, b) => a + b.lateCount, 0),
    totalAbsent:   dailies.reduce((a, b) => a + b.absentCount, 0),
    totalOnLeave:  dailies.reduce((a, b) => a + b.onLeaveCount, 0),
    dailyBreakdown: dailies.map(d => ({ date: d.date, rate: d.attendanceRate, present: d.presentCount, absent: d.absentCount })),
    leaveActivity,
  };
}

async function buildMonthlySummary(db, companyId, month, branchId = null) {
  const [year, mon] = month.split('-').map(Number);
  const daysInMonth = new Date(year, mon, 0).getDate();
  const days = Array.from({ length: daysInMonth }, (_, i) => _dateStr(new Date(year, mon - 1, i + 1)));
  const dailies  = await Promise.all(days.map(d => buildDailySummary(db, companyId, d, branchId)));
  const avgRate  = Math.round(dailies.reduce((a, b) => a + b.attendanceRate, 0) / daysInMonth);

  const base       = db.collection('companies').doc(companyId);
  const monthStart = new Date(year, mon - 1, 1);
  const monthEnd   = new Date(year, mon, 0, 23, 59, 59);

  // Leave by type (approved this month)
  let leaveQ = base.collection('leave_requests').where('status', '==', 'approved');
  if (branchId) leaveQ = leaveQ.where('branchId', '==', branchId);
  const leaveSnap = await leaveQ.get().catch(() => ({ docs: [] }));
  const leaveByType = {};
  leaveSnap.docs.forEach(d => {
    const data = d.data();
    const reqAt = data.requestedAt?.toDate ? data.requestedAt.toDate() : new Date(data.requestedAt);
    if (reqAt >= monthStart && reqAt <= monthEnd) {
      const t = data.leaveType || 'other';
      leaveByType[t] = (leaveByType[t] || 0) + (data.totalDays || 1);
    }
  });

  // Payroll totals
  let payQ = base.collection('payroll').where('month', '==', month);
  if (branchId) payQ = payQ.where('branchId', '==', branchId);
  const paySnap = await payQ.get().catch(() => ({ docs: [], size: 0 }));
  const payrollTotal = paySnap.docs
    .filter(d => ['approved', 'paid'].includes(d.data().status))
    .reduce((a, d) => a + (d.data().netSalary || 0), 0);

  // Performance averages
  let perfQ = base.collection('performance').where('month', '==', month);
  if (branchId) perfQ = perfQ.where('branchId', '==', branchId);
  const perfSnap = await perfQ.get().catch(() => ({ docs: [] }));
  const scores = perfSnap.docs.map(d => d.data().overallScore || 0).filter(s => s > 0);
  const avgPerformance = scores.length > 0
    ? (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(2) : null;

  return {
    month,
    workingDays: daysInMonth,
    avgAttendanceRate: avgRate,
    totalPresent: dailies.reduce((a, b) => a + b.presentCount, 0),
    totalAbsent:  dailies.reduce((a, b) => a + b.absentCount, 0),
    totalLate:    dailies.reduce((a, b) => a + b.lateCount, 0),
    leaveByType,
    payrollTotal: Math.round(payrollTotal),
    payrollCount: paySnap.size,
    avgPerformance,
    performanceCount: scores.length,
  };
}

async function buildGroupSummary(db, companyId, reportType, date) {
  const branchSnap = await db.collection('companies').doc(companyId).collection('branches').get();
  const branches   = branchSnap.docs.map(d => ({ id: d.id, name: d.data().name || d.id }));

  const build = (branchId) => {
    if (reportType === 'daily')  return buildDailySummary(db, companyId, date, branchId);
    if (reportType === 'weekly') return buildWeeklySummary(db, companyId, date, branchId);
    return buildMonthlySummary(db, companyId, date, branchId);
  };

  const [overall, branchResults] = await Promise.all([
    build(null),
    Promise.all(branches.map(async b => ({ branchId: b.id, branchName: b.name, ...await build(b.id) }))),
  ]);

  return { overall, branches: branchResults, reportType, date };
}

module.exports = { buildDailySummary, buildWeeklySummary, buildMonthlySummary, buildGroupSummary };
