# HRNova — System Overview

A full-stack HR management platform built for Rwanda-based organizations (factories, schools, clinics, NGOs, hotels, polytechnics). One Flutter codebase serves three different surfaces depending on who's logged in; a Node.js backend handles anything that needs a service account, a third-party API key, or a scheduled job.

---

## 1. The Three Apps (One Codebase)

`lib/core/router/app_router.dart` decides which surface a logged-in user lands on, based on their **role** and, for two roles, the **platform** (web vs mobile):

| Surface | Who | Entry route |
|---|---|---|
| **Web Dashboard** | hr_admin, group_hr_admin, branch_hr_admin, manager, director, finance_manager, super_admin | `/dashboard` (sidebar shell) |
| **Guard Mode** | hr_admin / branch_hr_admin, but **only when on a mobile device** | `/guard` — QR-scan check-in/out kiosk |
| **Employee Mobile App** | employee | `/mobile-home` |

`super_admin` bypasses all of this and goes straight to `/super-admin` — the platform-owner console, separate from any single company's data.

---

## 2. Roles

Defined in `lib/core/constants/app_constants.dart`:

`super_admin`, `hr_admin`, `group_hr_admin`, `branch_hr_admin`, `finance_manager`, `manager`, `director`, `employee`, `administration`

Company types:
- **Type 1 (single)** — one location, one HR admin.
- **Type 2 (multi_branch)** — `group_hr_admin` sees all branches; `branch_hr_admin` is scoped to one.

Role gating happens in two places:
- **Frontend**: `app_router.dart` redirect logic — e.g. `manager` is explicitly blocked from `/payroll`, `/recruitment`, `/branches`, `/departments`, `/super-admin`, `/reports`, `/nova-ai`.
- **Backend**: `requireRole()` middleware on protected routes (e.g. `backend/routes/employees.js`).

**Every Firestore query is scoped to `companyId`.** Company A's data is never visible to Company B — this is the core tenancy boundary of the whole system.

---

## 3. Data Model

Centralized in `lib/core/services/firebase_service.dart`. Everything company-specific lives under `companies/{companyId}/...`:

```
companies/{companyId}/
  employees/
  attendance/
  leave_requests/
  leaves_calendar/
  payroll/{YYYY-MM}/
    payslips/{employeeId}
  performance/
  reports/
  job_postings/
    applications/
  settings/config
  branches/
  notifications/
  expense_claims/

super_admin/companies_registry   ← platform-wide company list (separate tree)
```

---

## 4. Feature Modules (`lib/features/`)

| Module | What it does |
|---|---|
| **auth** | Login, suspension screen, Firebase Auth + custom-claims role/session handling |
| **dashboard** | Company-wide KPI/metrics overview |
| **employees** | Employee list, add/edit, 6-tab profile (Profile, QR Code, Attendance, Leave, Payroll, Loans) |
| **attendance** | Web attendance screen + **Guard Mode** (QR-scan check-in/out kiosk on mobile) |
| **leave** | Leave requests + HR approval flow (also reachable via WhatsApp, see §7) |
| **payroll** | Run payroll, review/adjust payslips, approve, export, email — see [payroll_formulas.md](payroll_formulas.md) and [payroll_leave_treatment.md](payroll_leave_treatment.md) for the exact math. Client-side engine, no dedicated backend route. |
| **performance** | Performance reviews, AI-assisted scoring |
| **reports** | AI-generated daily/weekly/monthly/anomaly reports (`reports_screen.dart`) + **Nova AI** conversational chat over company data (`nova_ai_screen.dart`) |
| **recruitment** | Job postings, candidate pipeline, AI CV screening, shortlist/decline |
| **public** | Unauthenticated job board + public apply form + confirmation screen — the public-facing half of recruitment |
| **departments** | Department management |
| **branches** | Branch management (multi-branch companies) |
| **settings** | Company configuration + first-run onboarding wizard |
| **super_admin** | Platform-wide company management + cost/usage analytics |
| **mobile** | Employee-facing mobile app shell (splash, onboarding, home) |

---

## 5. Backend (`backend/`)

Node.js service — handles anything needing a service-account key, a third-party API, file storage, or a cron schedule. Flutter talks to Firestore directly for most CRUD; it calls the backend for privileged/external operations.

**Routes:**

| File | Purpose |
|---|---|
| `auth.js` | Set/refresh Firebase custom claims, create/delete users |
| `storage.js` | Upload/delete photos, CVs, certificates → Cloudflare R2 |
| `companies.js` | Company CRUD, status, payments, branches (super-admin) |
| `branches.js` | Branch CRUD, status toggling |
| `employees.js` | Employee CRUD, QR lookup, status, loans |
| `exports.js` | RRA PAYE export, payroll Excel export, send-payslip email |
| `ai.js` | Performance review generation (Gemini-backed) |
| `reports.js` | Daily/weekly/monthly/group reports, Nova AI `/ask`, anomaly checks |
| `recruitment.js` | Public job board/apply + authenticated job/application CRUD, AI screening |
| `costAnalytics.js` | Usage/cost analytics for super admin |

**Services:**

| File | Purpose |
|---|---|
| `aiService.js` | Google Gemini wrapper (`gemini-2.0-flash`) — reports, reviews, CV screening, anomaly alerts |
| `aiScreeningService.js` | CV screening pipeline for job applications |
| `dataProcessor.js` | Pre-processes Firestore data into summaries before sending to AI (never raw docs) |
| `emailService.js` | Transactional email via Brevo — leave, payslips, reports, performance reminders |
| `rraExportService.js` | Rwanda Revenue Authority PAYE + RSSB export generation |
| `storageService.js` | Cloudflare R2 (S3-compatible) upload/delete |
| `whatsappService.js` / `whatsappPortalService.js` | WhatsApp bot for leave requests (Kinyarwanda + English) — **built but not currently mounted as a live route/webhook in `server.js`** |

> Note: no dedicated `payroll.js` backend route exists — payroll runs client-side directly against Firestore.

---

## 6. Automation — Cron Jobs (`backend/server.js`)

| Job | Schedule | Purpose |
|---|---|---|
| Morning report | 09:30, Mon–Sat | AI daily report to HR/managers |
| Evening report | 17:30, Mon–Sat | AI end-of-day report |
| Weekly report | 17:30 Fri | AI weekly summary → HR Admin + Manager + Director |
| Monthly report | 20:00, last day of month | AI monthly summary |
| Weekly anomaly check | 08:00 Mon | Sick-Monday pattern, burnout risk, chronic lateness, frequent absence, low dept attendance |
| Performance reminder | 09:00, 25th of month | Nudges upcoming review cycle |
| Midnight photo cleanup | 00:00 daily | Deletes stale uploaded photos |

---

## 7. AI Features

- **Nova AI** — conversational chat, answers questions about company data using pre-processed summaries (never raw Firestore docs sent to the model).
- **AI Reports** — daily/weekly/monthly/group narrative reports, delivered by email on the cron schedule above.
- **Anomaly Detection** — 5 automated checks (burnout risk, chronic lateness, frequent absence, sick-Monday pattern, low department attendance).
- **AI CV Screening** — scores/ranks recruitment applications automatically.
- **AI Performance Reviews** — assists in generating review content/scoring.
- Provider: **Google Gemini** (`gemini-2.0-flash`) via `GEMINI_API_KEY`.

---

## 8. Payroll — Quick Reference

Payroll has its own detailed docs since the math has several moving parts:
- [payroll_formulas.md](payroll_formulas.md) — every formula, step by step (base salary by salary type, overtime, absent/late deductions, RSSB, PAYE, loans, net salary, employer cost).
- [payroll_leave_treatment.md](payroll_leave_treatment.md) — how leave days are (and aren't) paid, and the inconsistency between fixed-monthly vs daily/hourly employees.

Rwanda 2025 statutory rates used (do not change without a legal update):
- PAYE: 0–60k = 0%, 60k–100k = 20% above 60k, 100k–200k = 8,000 + 30% above 100k, >200k = 38,000 + 30% above 200k
- RSSB Pension: 6% employee + 6% employer
- RSSB Maternity: 0.3% employee + 0.3% employer
- RSSB Occupational Hazard: 2% employer only

---

## 9. Tech Stack

- **Frontend**: Flutter (web + Android from one codebase), `flutter_riverpod` for state, `go_router` for navigation
- **Backend**: Node.js, port 3000 in local dev
- **Database**: Firebase Firestore
- **Auth**: Firebase Auth with custom claims (role, companyId, branchId, employeeId)
- **File storage**: Cloudflare R2 (never Firebase Storage)
- **Email**: Brevo (9,000/month free tier — cloud only, not local dev)
- **AI**: Google Gemini (`gemini-2.0-flash`)
- **Messaging**: WhatsApp bot for leave requests (Kinyarwanda + English) — service exists, webhook not currently live

---

## 10. Known Gaps / Things Worth Fixing

- **No paid/unpaid leave distinction** — fixed-monthly employees are effectively paid through leave, daily/hourly-rate employees are not, purely as a side effect of the salary-type formula, not a deliberate policy (see [payroll_leave_treatment.md](payroll_leave_treatment.md)).
- **No half-day concept** in attendance/payroll — a day is only ever full-present, absent, or on-leave.
- **WhatsApp integration** is built (service files exist) but not wired into a live webhook route.
- **No dedicated payroll backend route** — all payroll calculation happens client-side against Firestore directly, unlike every other feature which goes through the Node backend for privileged operations.
