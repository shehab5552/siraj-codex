# SIRAJ P0 — Stage Implementation Report Template

> انسخ هذا النموذج لكل مهمة أو مرحلة، واستبدل الحقول بين الأقواس بنتائج فعلية مثبتة. لا تسجل PASS دون تشغيل الاختبار.

## 1. Task Metadata
- **Task ID:** B-XX
- **Official Mapping:** TK-XX / TC-XX / Gate Gx
- **Stage:** [اسم المهمة]
- **Date:** [YYYY-MM-DD]
- **Status:** PASS / FAIL / BLOCKED / CANNOT_JUDGE
- **Executor:** B — Flutter / Android
- **Baseline Commit:** [SHA]
- **Implementation Commit(s):** [SHA(s)]
- **Documentation Commit:** [SHA]
- **GitHub Branch / Remote:** main / origin

## 2. Objective and Acceptance Criteria
- **Objective:** [ما الذي يجب تحقيقه]
- **Approved Criteria:** [معايير القبول من الخطة الرسمية]
- **Dependencies:** [متطلبات A وC أو المهام الأخرى]

## 3. Actual Implementation
| File / Component | Change | Why |
|---|---|---|
| `lib/...` | [ما تغير] | [السبب] |

## 4. Tests and Evidence
| Test ID / Command | Expected | Actual | Status | Evidence |
|---|---|---|---|---|
| `flutter analyze` | No issues | [...] | [...] | [سجل] |
| `flutter test` | All passed | [...] | [...] | [سجل] |
| [Android integration test] | [...] | [...] | [...] | [لقطة/Logs] |

- **Device:** [model, Android, ABI]
- **Resource Versions (if applicable):** [dataset/model/index]
- **Known Issues:** [لا شيء / وصف دقيق]
- **Not Implemented / Out of Scope:** [...]

## 5. Git and Delivery
- **Code Commit:** `[SHA]` — `[message]`
- **Documentation Commit:** `[SHA]` — `[message]`
- **Push Verified:** [true/false; `git status -sb`]
- **PDF Report:** `docs/reports/B-XX.pdf`
- **Markdown Report:** `docs/reports/B-XX.md`

## 6. Handoff
- **Next Task:** B-XX
- **Required Inputs:** [...]
- **Stop/Go Decision:** [مستند إلى المعايير]

---
### Workflow checklist
- [ ] مطابقة التنفيذ مع المواصفة الرسمية والتعديلات المعتمدة
- [ ] مراجعة Diff والتأكد من غياب الأسرار
- [ ] نجاح الاختبارات المطلوبة بأدلة
- [ ] Commit للكود برقم المهمة
- [ ] تقرير Markdown وPDF بنفس نتائج الاختبارات
- [ ] Commit للتوثيق وPush إلى GitHub
- [ ] تأكيد التزامن `git status -sb` وتسجيل SHA
