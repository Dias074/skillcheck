# Phase 6: Weak Areas Analysis

Status: Phase 6 complete. The user confirmed successful manual Chrome verification:
category filtering and All categories, correct Weak Areas calculations, and correct
history/chart display after category changes and signing in again.
No AI or practice mode was added. Phase 7 has not started.

Verification: formatting passed (70 files, no final changes), static analysis
reported no issues, and all 90 tests passed (14 added for Phase 6). Tests use
fake repositories or mocked HTTP; they do not claim live Supabase UI verification.

## Existing schema and security

No migration or remote SQL action is needed. Read the current user's
`assessment_attempt_answers`, joined to `questions`, `topics` and `categories`
through existing foreign keys. The Phase 5 RLS and table grants are unchanged.
The existing `supabase/tests/phase5_history_rls.sql` covers cross-user answer reads
and anonymous access. No privileged key is used.

The repository uses the current user's ID, pins that account's token, fetches all
pages and rejects unexpected owners. Providers reset on account changes and
discard late responses. A successful assessment save invalidates topic data.
Refresh history refreshes both history and topic analysis; a failed topic request
has its own retry button and does not replace the existing dashboard with an error.

Question topic/category and available points come from the CURRENT question bank;
earned points and correctness come from the PERSISTED answer. Phase 5 did not
snapshot per-answer maximum points or topic membership. Preserve these metadata
fields for questions already used in history; create new question IDs for revised
weights/topics. A historical snapshot/versioning migration would be required if
editing those fields becomes a requirement. The current bank has no editing UI.
Contradictory earned/available points produce a load error, not a silently clamped
percentage. This cannot detect all administrator edits (e.g. changing the weight
of a question previously answered incorrectly).

## Algorithm

`TopicPerformanceCalculator` aggregates all saved responses by topic. Duplicate
attempt/question pairs count once; responses from another user are excluded.
The current Progress category filter applies to the same data.

- answered = responses with a selected option;
- correct/incorrect = answered responses grouped by their saved correctness;
- skipped = responses with no selected option, reported separately;
- earned points = sum of saved earned points on answered questions;
- available points = sum of referenced question points on answered questions;
- percentage = earned / available * 100, unrounded until display;
- attempt count = distinct attempts containing that topic, including all-skipped appearances;
- answered attempt count = distinct attempts with at least one answer in that topic;
- distinct questions = different question IDs answered within the topic.

Skips do not establish weakness and do not enter the denominator. With no answers,
percentage is undefined and displayed as a dash. This intentionally differs from
the overall assessment percentage, which includes skipped questions in its maximum.

`WeakAreaPolicy` classifies a topic as weak only when ALL are true:

1. At least 5 answered responses.
2. At least 2 distinct attempts containing answered responses.
3. At least 2 different answered question IDs.
4. Weighted percentage strictly below 60% (exactly 60% is not weak).

These are transparent product heuristics, not validated statistical confidence
or a certified proficiency measure. They avoid judging a topic from one answer,
one session or repeated exposure to one question. With enough evidence and at
least 60%, status is satisfactory. Otherwise status is insufficient data.
Some sample topics contain only one question: repeating it will correctly remain
insufficient until the bank has another distinct question for that topic.

The policy is injected through Riverpod and owns classification; the UI only
renders the returned status and policy values. Thresholds or classification can
be changed independently of Supabase retrieval and widgets. No difficulty weight
or time decay is added in this phase.

## Flow and files

Authenticated user → SupabaseTopicRepository → saved answers + referenced metadata
→ account-scoped providers → TopicPerformanceCalculator → WeakAreaPolicy
→ WeakAreasSection inside Progress.

- `lib/features/weak_areas/domain/topic_performance.dart`: models, aggregation and policy.
- `lib/features/weak_areas/data/supabase_topic_repository.dart`: authenticated paginated query and mapping.
- `lib/features/weak_areas/application/weak_areas_providers.dart`: account lifecycle, policy injection and filtering.
- `lib/features/weak_areas/presentation/weak_areas_section.dart`: states, metrics and reasons.
- `test/features/weak_areas/`: domain, repository, provider and widget tests using fakes only in tests.

## Chrome manual verification

```powershell
flutter run -d chrome --no-pub --web-port 7357 --dart-define-from-file=config/supabase.local.json
```

1. Sign in and open Progress → Weak Areas. A new account shows no topic data.
2. For predictable counts, use an account without English history. Complete one
   English attempt: answer grammar questions 1 and 3 incorrectly, answer question 2
   correctly. Save, then open Progress. Grammar is 0/3 points with 2 answers and
   insufficient evidence; it must not be labelled weak yet.
3. Repeat this assessment twice more. Grammar now has 6 answers, 3 attempts,
   2 distinct questions and 0/9 points: it should be weak. Vocabulary remains
   insufficient because the sample bank contains only one distinct vocabulary question.
4. To check a strong topic independently, use another empty account and complete
   three English attempts correctly. Grammar should be satisfactory at 100%.
5. Select English, Kazakh, and All categories in Progress. Cards must follow the
   filter. A category with no answers shows no data, not a network error.
6. Submit an all-skipped attempt. The topic appearance count grows; answered,
   incorrect and available points do not grow. All-skipped history has no percentage.
7. Refresh Chrome, then sign out and use another account. Its topic data and
   category filter must not briefly show the previous user's values.
8. Disable the network and press Refresh history, then reconnect and retry.
   Topic request failures show Retry topic analysis; ordinary insufficient evidence
   does not show a Retry error. Check a narrow window and increased text size.

If the account already has attempts, calculations include ALL its persisted
responses, so the exact totals above will differ. No synthetic progress is seeded.
Native verification remains reserved for a physical phone; never launch an emulator.
