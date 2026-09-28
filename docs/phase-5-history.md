# Phase 5: Progress and assessment history

Status: the user confirmed that the migration was applied and the complete SQL
test passed through its final ROLLBACK on 2026-09-28. Flutter persistence,
Progress, filtering and the chart are implemented. Phase 5 manual verification
was confirmed by the user: assessment history saves to Supabase, appears in
Progress and remains available after browser refresh and signing in again.
Phase 5 is complete. Phase 6 has not started.

Local verification: `dart format lib test tool`, `flutter analyze --no-pub`
and `flutter test --no-pub --concurrency=2` passed (76 tests). No real accounts
or live assessment history were created by the automated tests.

## Manual database step

Already completed for the current project. These steps are only for a new setup.

1. Open `supabase/migrations/20260928000100_assessment_history.sql`.
2. Copy the entire file, including BEGIN and COMMIT.
3. In the existing Supabase project, open SQL Editor > New query, paste and Run.
4. Expect successful execution and two empty public tables:
   `assessment_attempts` and `assessment_attempt_answers`, both with RLS enabled.
   The `save_assessment_attempt` function should also exist.
5. In a separate query, run the entire `supabase/tests/phase5_history_rls.sql`.
   Expect successful execution without exceptions. Its final ROLLBACK removes
   all synthetic test accounts and history. If any statement fails, run
   `ROLLBACK;` before another query and report the error without credentials.

Apply this new migration only once. Do not rerun the Phase 4 migrations.
No database password or service_role key is required in Flutter or chat.

## Design and contract for the Flutter implementation

- Attempts store the AssessmentScorer result, category and start/completion times.
  Percentage is generated from score/max_score to prevent inconsistent storage.
- Answers store references to questions/options, correctness and earned points.
  Include one row per question, with a null selected option for skipped questions.
  Text/options are not duplicated. Foreign keys prevent removing referenced
  questions/options; persisted totals remain unchanged if content is later edited.
- Composite `(user_id, id)` keys preserve the existing string Assessment.id
  without allowing one account to reserve another account's attempt ID.
  The application must retain the same ID and frozen result when retrying saves.
- `save_assessment_attempt(p_attempt, p_answers)` takes a JSON object and array.
  It derives the owner from auth.uid(), saves both tables in one transaction,
  validates totals/category consistency and rolls back on any error.
  A successful retry returns the existing ID without inserting again. The first
  successful payload wins; callers must never reuse an ID for a different attempt.
- The RPC is SECURITY INVOKER: normal grants and RLS still apply. Authenticated
  users can insert/read only their own rows. No client update/delete is granted.
  The answer's composite FK and RLS bind it to the same owner's attempt.
- Direct own-row inserts are permitted by RLS; the app must use the RPC for atomic
  submission. This is a learning app, not an anti-cheat system: client-calculated
  results are not trusted examination credentials, and answer keys remain readable.
- Indexes support newest-first history per user, optionally filtered by category.
- User-specific provider state must be cleared on account changes. A failed save
  must retain the result for retry; Progress must refresh after a successful save.

## Flutter implementation

`QuestionScreen → AssessmentController → AssessmentScorer → AssessmentResult
→ ProgressRepository → save_assessment_attempt RPC → PostgreSQL + RLS`

After confirmation, the result screen opens and the user's history provider is
invalidated. A rebuild or repeated Submit uses the same pending Future. Retry
keeps the same random attempt ID, completion time and frozen answers. A timeout
does not prove that the server failed to commit; the same ID makes retry safe.
The request explicitly retains the submitting account's token, and late results
cannot overwrite another account's controller state.

If saving cannot be confirmed, the UI shows an error and Retry saving. Another
attempt cannot replace that result until saved. Logout warns before discarding
an unconfirmed result. There is no offline disk queue: do not refresh/close the
browser with an unsaved result. Unfinished attempts and the current answer-review
screen remain session-local. Persisted history summaries survive restart; opening
historical answer review is outside this phase's UI scope.

`Supabase history → ProgressRepository → account-scoped Riverpod providers
→ ProgressSummary → ProgressScreen / HistoryList / ProgressChart`

History is fetched in pages of 500, newest first, and displayed 20 rows at a time
with Show more history. Filtering and summaries use the loaded persisted history,
not sample records. Average percentage is the arithmetic mean of each attempt's
percentage, rounded only for display. The selected category applies to totals,
average, category summary, chart and history. Refresh history fetches again.

The fl_chart line graph shows up to ten recent attempts in chronological order.
Horizontal spacing represents attempts, not elapsed time; tooltips show dates,
category and percentage. No data shows an empty state; one result shows a value
without implying a trend. Dates are stored as timestamptz/UTC and displayed locally.

`http` is a dev dependency for mocked HTTP tests; no new production networking
layer was added. Flutter also regenerated the Windows plugin registration for
the already existing app_links and url_launcher dependencies during pub get.

## Manual Chrome verification

Run from the project directory:

```powershell
flutter run -d chrome --no-pub --web-port 7357 --dart-define-from-file=config/supabase.local.json
```

1. Sign in with an account without saved attempts. Progress should show 0,
   Average: — and an empty state, without a chart or fabricated history.
2. Start English, select goes, then False, skip the third question and submit.
   Wait for Saved to your history. Expect 1/4 points, 25%, counts 1/1/1.
   Review answers should still work.
3. Progress should show one attempt and a 25% average. Refresh Chrome, sign out
   and back in, then restart the app: the saved item must remain.
4. Complete another English assessment with all answers correct: totals become
   2 and the average 62.5% for a previously empty account. A two-point chart appears.
5. Complete a different category. Filter by English, the other category, a category
   without attempts, and All categories. Check totals, averages, chart and history.
6. Load questions, disconnect the network, then Submit. Wait for the error (up to
   20 seconds). Reconnect and Retry saving. There must be only one history record.
   While unsaved, starting another attempt is blocked and logout shows a warning.
7. Refresh history with the network disconnected: check the error and Retry history.
   Restore the network and retry. Do not refresh the entire page during an unsaved attempt.
8. Sign out and sign in as another account: no previous user's data/filter may
   appear. Return to the first account and confirm its history remains.
9. Resize Chrome to a narrow phone-sized window, try dark mode and chart tooltips.
   Native testing remains reserved for a physical phone, never an emulator.

The SQL RLS test already checks ownership, anonymous denial, duplicate saves,
foreign option rejection, rollback and immutable history. Dart/widget/HTTP tests
cover summaries, filters, save/retry, account switching, pagination and UI states.

## References

- https://supabase.com/docs/guides/database/functions
- https://supabase.com/docs/guides/database/postgres/row-level-security
