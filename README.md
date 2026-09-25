# SkillCheck

Knowledge assessment and learning progress app. Built incrementally as a Flutter portfolio project.

## Features

Home, Assessments, Progress and Profile navigation use Material 3 light/dark
themes. Progress remains a placeholder. Phase 4 adds Supabase email/password
authentication, private profiles and remotely loaded assessment content.
Phase 4 is complete: the user applied the schema/RLS and sample content migrations
and verified the live integration in Chrome. See [Supabase setup](docs/supabase-setup.md).

Phase 2 adds pure Dart assessment models and scoring with unit tests.
The scorer supports single-answer multiple choice and true/false questions,
weighted points, and separate correct/incorrect/unanswered counts.
Phase 3 introduced the reusable assessment flow:
five categories with three demo questions each, answer selection, Previous/Next,
optional skips, submission, weighted results and answer review.
Only one attempt is held in memory. Starting another replaces it; restarting
the app clears it. Logout also clears it. There is no persistent history or user progress.

## Screenshots

Screenshots will be added during portfolio preparation. Run the local prototype for now.

## Tech stack

Flutter 3.47.4 / Dart 3.13.3, Material 3, flutter_riverpod 3.4.3, go_router 18.0.1, flutter_lints and flutter_test.

Phase 4 adds the official supabase_flutter package (including its session
storage dependencies). Charts and standalone preference persistence remain future work.

## Architecture

Feature-based: app configuration in app/, feature UI in features/, reusable widgets in shared/. Assessment models and scoring live in features/assessments/domain/ and have no Flutter, Riverpod or backend dependencies.

Domain flow: Category → Topic → Question + QuestionOption; an Assessment
holds a fixed question snapshot. AssessmentScorer takes the assessment,
AssessmentAnswer selections and an explicit completion time, then returns
AssessmentResult. The UI calls an application-layer Riverpod controller,
which owns navigation within the attempt and delegates scoring to the domain.

Scoring: correct selections earn the question's positive integer points.
Incorrect and omitted/null selections earn zero; omitted/null selections
count as unanswered, not incorrect. Percentage is earned points divided by
all available points × 100, without rounding. Difficulty is metadata and
does not apply an extra multiplier. Empty assessments, duplicate IDs/answers,
foreign question/option references and completion before start are rejected.
Answer keys are available to authenticated clients for scoring/review;
this educational app is not a secure exam boundary.

```text
Assessment category → SupabaseAssessmentRepository → AssessmentController
→ user selections → AssessmentScorer → AssessmentResult
→ ResultScreen → AnswerReviewScreen
```

Sample content is seeded by versioned SQL. The former local source lives in
test/fixtures/ and is never used by production runtime. Phase 2 models and
scorer remain unchanged. Review is unavailable before submission;
after submission the controller rejects edits. Tab navigation preserves the
active attempt. Replacing an unfinished attempt requires confirmation.

```text
main → ProviderScope → SkillCheckApp → MaterialApp.router
     → GoRouter → MainNavigation → selected screen
```

The router owns the selected tab and preserves tab branches. Riverpod owns theme selection. Updating the theme does not recreate the router. Theme selection resets to System on restart.

## Project structure

```text
lib/
  main.dart
  app/
    app.dart
    router/
    theme/
  features/
    home/presentation/
    assessments/
      application/
      data/
      domain/models/
      domain/services/
      presentation/
    progress/presentation/
    profile/presentation/
    auth/
  shared/widgets/
test/
android/
ios/
windows/
web/
```

## Database

File responsibilities: [Phase 1 inventory](docs/phase-1-files.md).

Phase 4 provides migrations for profiles, categories, topics, questions and
question_options, a profile trigger and least-privilege RLS. These migrations
have been applied manually by the user to the configured project. For a new
project, follow [these instructions](docs/supabase-setup.md); do not reapply the
initial schema to the existing project. Assessment history remains future work.

## Getting started

Use Flutter stable compatible with Dart 3.13.3 or newer.

```sh
git clone https://github.com/Dias074/skillcheck.git
cd skillcheck
flutter pub get
flutter doctor
flutter devices
flutter run -d chrome --web-port 7357 --dart-define-from-file=config/supabase.local.json
```

Chrome/Web is the primary development and manual testing target on this 8 GB
RAM laptop. Do not launch or use the Android emulator. The web host runs the
same Flutter application; Android support and the shared architecture remain intact.

Final Android checks will use a physical phone after the main development
phases. When the user connects it, identify it with `flutter devices` and run
`flutter run -d <physical-device-id>`. iOS requires macOS/Xcode.
The existing Windows host requires Visual Studio with Desktop development with C++.

Known local Windows build issue: a Command Processor AutoRun command that prints
CP1251 text (such as `chcp 1251`) can cause Flutter's UTF-8 decoder to fail.
This machine has that configuration. Use Chrome for current manual verification.

## Environment variables

Copy config/supabase.example.json to the ignored config/supabase.local.json.
Set SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and AUTH_REDIRECT_URL.
The publishable client key is visible in the compiled app; security depends
on authentication and RLS. Never put server credentials in the client.
Without configuration, the app shows setup instructions.

## Testing

```sh
dart format lib test tool
flutter analyze
flutter test
flutter run -d chrome --web-port 7357 --dart-define-from-file=config/supabase.local.json
```

Widget tests cover navigation, theme changes, unknown-route recovery and small-screen layout with enlarged text.

Domain unit tests cover weighted scoring, both question types, skips, precision,
input order, invalid submissions, timestamps and immutable question snapshots.
Run only Phase 2 tests with:

```sh
flutter test test/features/assessments/domain
```

Phase 1 verification: static analysis clean, all four widget tests pass,
Android debug APK builds successfully. Windows build is blocked by the
local encoding issue described above. iOS has not been built on this Windows host.

Run these steps after each authorized phase. Emulator verification is not a
completion requirement. Use `flutter build web` when checking the web build is useful.

Manual checks in Chrome: visit each tab, click Explore assessments, select System/Light/Dark in Profile, and resize the browser window to test scrolling.

Phase 3 tests add controller lifecycle, answer preservation, submission,
review gating, category replacement, missing-session recovery, and the full
UI flow including a narrow layout with enlarged text.

Phase 3 verification: formatting and static analysis pass; all 49 tests pass.
The web build succeeds, and the user has manually verified the assessment
flow in Flutter Web / Chrome with no issues reported. Final Android testing
is reserved for a physical phone after the main development phases.

Manual assessment check in Chrome:

For a new installation, first apply migrations, configure redirect URLs and
sign in. The current local configuration and live integration have been verified.
Unit/widget tests use fake repositories and do not require a Supabase project.

Phase 4 manual verification (user, 2026-09-25): registration, email confirmation,
sign-in/session, profile email/display name, logout, protected-route redirects,
password recovery and sign-in with the new password all passed in Chrome.
The user also verified loading 5 categories and their questions/options from
Supabase, assessment navigation, answer preservation, skips, scoring, results
and answer review. Anonymous content access was separately checked and denied.
The dedicated two-user SQL RLS test has not been reported as executed; app
route protection alone does not prove database row isolation. Native checks
remain reserved for a physical phone. Phase 5 has not started.

1. Home → Explore assessments → Start English.
2. Select goes, Next, then False. Previous should preserve goes.
3. Return to question 2, Next, leave question 3 unanswered and Submit assessment.
4. Expect 1/4 points, 25.0%, 1 correct, 1 incorrect and 1 skipped.
5. Review answers: check the selection, correct answer and explanation for each question.
6. Return to categories and start another subject. During an unfinished attempt,
   switch tabs and return, or go back to categories and use Resume.
7. Restart the app: the local attempt is cleared.

## Roadmap

- [x] Phase 1: Foundation, themes and navigation
- [x] Phase 2: Domain models and scoring
- [x] Phase 3: Local assessment prototype
- [x] Phase 4: Supabase authentication, profiles and assessment content; live Chrome verification complete
- [ ] Phase 5: Progress history and charts
- [ ] Phase 6: Weak-topic analysis
- [ ] Phase 7: Rule-based practice
- [ ] Phase 8: UI polish and accessibility
- [ ] Phase 9: Portfolio preparation
- [ ] Future: AI recommendations

Planned language levels are educational estimates, not CEFR certification. Logic & Reasoning will not be presented as a validated IQ test.

## License

No license selected yet; planned for portfolio preparation.

## Author

Dias — Software Engineering student at Astana IT University, learning mobile development through dual education at WONK.
