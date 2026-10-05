# Architecture

SkillCheck uses feature folders and small application/domain services. It does
not require a separate abstraction for every widget or backend operation.

```text
main.dart → AppConfig → Supabase.initialize → ProviderScope → SkillCheckApp
→ MaterialApp.router / GoRouter → MainNavigation → screen

UI → Riverpod/Application → Repository interface → Supabase adapter → PostgreSQL/RLS
            ↓
      Pure Dart models / scoring / aggregation / selection
```

## Feature boundaries

| Feature | Responsibility | Main entry points under `lib/features/` |
| --- | --- | --- |
| Auth | Session events, forms, route protection | `auth/application/auth_providers.dart`, `auth/data/supabase_auth_repository.dart` |
| Assessments | Bank loading, answer state, submission, review | `assessments/application/assessment_controller.dart`, `assessments/domain/services/assessment_scorer.dart` |
| Progress | Save RPC, history, summary and filters | `progress/data/supabase_progress_repository.dart`, `progress/domain/progress_summary.dart` |
| Weak Areas | Topic evidence, weighted performance and policy | `weak_areas/domain/topic_performance.dart`, `weak_areas/data/supabase_topic_repository.dart` |
| Practice | Select existing weak-topic questions | `practice/domain/practice_question_selector.dart` |

Screens watch Riverpod state and delegate actions. Repository interfaces keep
Supabase/HTTP details out of domain logic and allow tests to supply fakes.
Concrete adapters map remote rows into domain models and expose safe failures.

## Assessment and practice

The AssessmentController owns an immutable AssessmentSession. Answer selection,
Previous/Next, skip handling and submission use the same engine in both modes.
AssessmentScorer is pure Dart: all available question points form the denominator;
only correct selections earn points. Submitted answers are locked.

Two providers create separate controller instances with an immutable SessionMode.
Assessment submission saves attempts/answers through the history repository and
refreshes history/topic providers. Retries reuse the attempt ID; the database RPC
is atomic and idempotent. Practice submission returns a local result and never
calls the save repository. A practice cannot replace an active normal assessment.

Practice rechecks the current user's saved evidence when starting. WeakAreaPolicy
requires 5 answers, 2 answered attempts and 2 different questions, below 60%.
PracticeQuestionSelector takes 2–5 distinct bank questions, round-robin across
weak topics (weakest first), without unrelated fallback questions. Insufficient
evidence/content is an expected empty state. These policies are outside widgets.

## Data lifetime and user isolation

- PostgreSQL stores content, profiles, completed assessment attempts and answers.
- Session selection, result/review, practice and theme preference live in memory.
- User-keyed providers and controller resets prevent reuse across auth changes;
  generation/user checks reject stale async responses after account changes.
- Repositories explicitly filter/pin user context; database RLS remains the actual
  ownership boundary. UI redirects alone do not prove database isolation.
- Topic analysis joins current question/category/topic metadata. Previously used
  content should be versioned instead of silently changing weights/topic IDs.

## Security and tests

Publishable keys identify a client project; they are not server secrets. RLS checks
the authenticated user's identity. Privileged keys must not be included in builds.
Question answer keys and local scoring are client-visible, so assessment results
are educational feedback, not trustworthy examination credentials.

Flutter tests use fake repositories and mock HTTP clients: no live project or
credentials. SQL checks in `supabase/tests/` test real RLS separately. UI tests
cover narrow layouts, large text, navigation and both themes; user verification
on Android and Chrome is recorded in phase reports.

CI runs formatting, analysis and tests only. It neither applies SQL nor deploys
the app, signs Android binaries, publishes releases or creates tags.
