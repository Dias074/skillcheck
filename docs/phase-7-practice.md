# Phase 7 — Weak Topic Practice

Phase 7 complete. Manual verification passed on Android and Chrome, as
reported by the user on 2026-10-05. No Phase 8 work.

Verification on 2026-10-05: `dart format lib test` completed;
`flutter analyze --no-pub` reported no issues;
`flutter test --no-pub --concurrency=2` passed all 100 tests (10 new practice tests).
Manual verification confirmed:

- Launch from a confirmed Weak Area;
- Previous/Next navigation and selected-answer preservation;
- Skipped questions and correct result/scoring;
- Review of correct/skipped answers with explanations;
- No practice entries in assessment history or changes to averages, progress
  or Weak Areas;
- Resume after switching tabs;
- Session cleared after logout/login;
- Normal Assessment flow still works.

## Architecture and scope

Progress offers one Practice weak topics button per category with a confirmed
weak topic, following the existing category filter. The launch page explains
that practice is temporary and lets the user resume or replace a previous
practice. A regular assessment remains in its own provider, unaffected.

`AssessmentController` has an immutable `SessionMode`: assessment or practice.
Two Riverpod providers create separate instances of the same controller. Both
reuse the answer selection, navigation, locking, session model and scorer.
Question, result and review screens accept an explicit practice flag, choosing
the matching provider and routes. Existing assessment routes default to normal
mode. The Phase 2 domain models and AssessmentScorer are unchanged.

## Selection and data flow

Confirmed Weak Area in Progress → practice launch → authenticated repository
reads of current Supabase questions and the user's saved answers → existing
TopicPerformanceCalculator and WeakAreaPolicy → PracticeQuestionSelector →
practice controller → shared question UI → AssessmentScorer → result → review.

Selection rechecks evidence at launch; it does not trust a topic ID supplied by
the UI. Only the selected category and confirmed weak topics qualify. Phase 6
policy remains below 60% with at least 5 answers, 2 answered attempts and 2
distinct questions. No history, other users' answers, good topics and
insufficient evidence cannot create a practice session.

Sessions contain 2–5 distinct existing bank questions, exclusively from weak
topics. Topics sort by lowest performance first (topic ID breaks ties).
Question IDs sort within each topic; round-robin selection gives each topic a
turn before taking another question from the same topic. Duplicates are removed.
Fewer than two available questions produces a normal explanatory state, without
filling the session with unrelated questions. Selection is deterministic; repeat
practice can repeat questions. It is not spaced repetition or AI.

## Persistence and security

Practice is intentionally NOT saved. The Phase 5 attempts schema has no attempt
type, and its aggregates feed history, averages and Weak Areas. Practice submit
scores in memory and never calls saveAttempt or invalidates history/analysis.
Improvement must be demonstrated by a later regular assessment. No migration,
new table, bank copy or RLS changes are required.

Existing authenticated repositories/RLS remain in use. Account changes reset
both session providers; generation and user checks reject late loads. Refresh,
restart or logout discards practice, including its result/review. Navigating
between tabs preserves it. No new dependency or platform-specific code.

## Manual verification — Chrome

Run `flutter run -d chrome --web-port 7357 --dart-define-from-file=config/supabase.local.json`.
Use the ignored local config; never copy credentials into this document.

1. Sign in to the Phase 6 test account with confirmed weak topics. Open Progress.
   Confirm category-specific buttons, selected-category filtering and All categories.
2. If needed on a separate test account, complete English three times, answering
   both grammar questions incorrectly and vocabulary correctly. This produces
   enough real grammar evidence. Do not fabricate database records.
3. Note history count, average, chart and Weak Areas. Start English practice.
   With the original bank expect two grammar questions and no vocabulary question.
4. Select an answer, Next, Previous; confirm preservation. Clear an answer,
   leave a question skipped, and finish. Check points, percentage and counts.
   With first grammar question correct and second skipped: 1/3, 33.3%, 1 correct,
   0 incorrect, 1 skipped.
5. Review shows question, chosen answer/skipped, correct answer and explanation.
   Return to Progress; history, averages and Weak Areas must be unchanged.
6. Switch tabs during practice, return and Resume practice. Start again only
   after reading the replacement notice. A regular unfinished assessment must
   retain its answers independently.
7. Refresh or sign out: practice is cleared. Sign into another account: no
   previous user's practice should be visible. Protected routes still require login.
8. An account without enough evidence has no practice button. A direct visit to
   `/#/progress/practice/start/english` explains insufficient evidence on Start.
   Loading, repository failure/retry and insufficient bank coverage are also
   covered by automated tests; do not delete production questions to simulate them.
9. Complete a normal assessment and confirm its usual save/history behavior.

Automated coverage: selection/filtering/evidence/isolation, duplicate questions,
round-robin ordering, five-question cap, minimum content, weighted scoring,
correct/incorrect/skipped, repeat submission, independent assessment state,
zero practice saves, auth changes/late responses, launch/loading/error/empty,
routes/result/review and category buttons. Existing tests remain regression checks.
