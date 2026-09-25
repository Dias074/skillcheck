# Phase 4 Supabase setup

## Status

Phase 4 implementation, two migrations and a database verification script are
present in the workspace, awaiting the user's separate commit instruction.
The user manually applied the schema/RLS and sample content migrations to the
remote project (5 categories, 15 questions). Real client configuration exists
only in the Git-ignored `config/supabase.local.json`. Tests use fake repositories.

Local checks: formatting, static analysis and all 61 tests pass; the web
release build succeeds. Chrome debug launch succeeds on port 7357.
On 2026-09-25 the user successfully verified registration with display name,
email confirmation, sign-in/session, profile data, logout, protected-route
redirects, password reset and sign-in with the new password. Live categories,
questions/options, Previous/Next, preserved answers, skips, scoring, results
and answer review also passed. Email confirmation is enabled; anonymous
content access was independently checked and denied (HTTP 401).

The dedicated two-user SQL RLS test below has not been reported as executed.
UI route checks do not prove cross-user database isolation. Native callbacks
remain for final physical-device testing. Phase 5 has not started.

## 1. Apply the schema and sample content

Already completed manually for the current project. The following instructions
are for a new setup; do not rerun the initial schema on the configured project.

The Supabase CLI is not installed/linked in this workspace. Do not improvise
with database credentials. In your existing **SkillCheck** project:

1. Open Supabase Dashboard → SQL Editor → New query.
2. Copy and run the entire `supabase/migrations/20260925000100_initial_schema.sql`.
3. In another query, run the entire `supabase/migrations/20260925000200_sample_content.sql`.
4. Check the five public tables and RLS policies in the dashboard.
5. Run `supabase/tests/phase4_rls.sql` in SQL Editor. It creates synthetic users
   inside a transaction, checks isolation/read-only content and rolls everything
   back. If a statement fails, run `ROLLBACK;` before trying another query.

Only apply the initial migration once to a project without these tables.
If similarly named tables already exist, inspect them before applying SQL.
The content migration inserts 5 categories, 15 questions and their topics/options.
It is educational sample content, never fabricated user history.
After applying a migration, preserve it unchanged and add a new migration for
future content updates. The generator is only for reproducing this initial seed.
The circular question/answer-key relationship is checked at COMMIT: run the
whole seed transaction, not individual question INSERT statements.

SQL Editor execution does not automatically record Supabase CLI migration
history. Keep these exact files as the source of truth. If CLI is introduced
later, reconcile migration history before any db push; do not rerun the initial
schema blindly. No database password or privileged key is needed in Flutter.

## 2. Local client configuration

Copy `config/supabase.example.json` to `config/supabase.local.json`.
Fill in ONLY:

- `SUPABASE_URL`: Project URL from the project's Connect/API settings.
- `SUPABASE_PUBLISHABLE_KEY`: the `sb_publishable_...` client key.
- `AUTH_REDIRECT_URL`: `http://localhost:7357/` for Chrome testing.

The local JSON is ignored by Git. The example contains placeholders.
Use `git check-ignore config/supabase.local.json` to verify the ignore rule.

Values are compiled into the client and are visible to users. RLS and the
authenticated user's token provide security. Never put a database password,
server secret or privileged key in this file. Do not add this file as a Flutter asset.

## 3. Auth dashboard settings

Enable email/password authentication and keep email confirmation enabled.
Set a minimum password length of at least 8 characters (the form also checks this).

In Authentication → URL Configuration:
- Site URL: `http://localhost:7357/`
- Allowed redirect URLs: `http://localhost:7357/`
- Also allow `http://localhost:7357/?flow=recovery` for password recovery.

Use the same host and port throughout. PKCE email callbacks should be opened
in the same browser/profile where registration or password reset was requested.
For expired/used links, request a new link. Delivery/rate limits depend on the
project's email configuration. Do not disable RLS to resolve an auth issue.

The callback query marks password recovery even if the SDK restores a session
before widgets subscribe. A passwordRecovery event also forces the reset form.
After updating the password the normal authenticated routes become available.
An authenticated user may also intentionally visit /reset-password to change
their password; possession of an authenticated session is still required.

## 4. Run in Chrome

```powershell
flutter pub get
dart format lib test tool
flutter analyze
flutter test
flutter run -d chrome --web-port 7357 --dart-define-from-file=config/supabase.local.json
```

On this Windows machine pub may finish dependency resolution and then report
that desktop plugins need symlink support. This is a host setup issue, not a
reason to change Android support. If packages are already resolved, the checks
and Chrome run can use `--no-pub`. For example:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter run -d chrome --no-pub --web-port 7357 --dart-define-from-file=config/supabase.local.json
```

Without valid configuration the app shows a setup screen; it does not fall back
to local questions or pretend to authenticate.

## 5. Manual checks

1. Register a test account, confirm its email, then sign in.
2. Check that profiles has exactly one row with that user's auth ID.
3. Refresh Chrome: authentication should restore.
4. Open Profile: email and display name come from the authenticated account/profile.
5. Change the theme; navigate all bottom tabs.
6. Open Assessments: categories and questions come from Supabase.
7. English: choose goes, then False, then skip question 3. Expect 1/4, 25%,
   one correct, one incorrect and one skipped. Review all explanations.
8. Log out: protected URLs redirect to login and the old attempt is cleared.
9. Request a reset email, follow the link in the same Chrome profile, set a
   new password and confirm that the new password works after logout.
10. With network disabled, category/question loading should show an error and
    retry. A category with no questions should show a useful empty message.

RLS verification requires two identities; use the SQL test plus separate
browser profiles if testing the API manually. A profile query with user A's
token must not return user B's profile; content writes must fail.

## Database design and limitations

- profiles.id references auth.users.id with cascade on account deletion.
- topics belongs to categories; questions has a composite topic/category FK
  so a question cannot claim a topic from another category.
- question_options belongs to questions. A deferred composite FK ensures that
  correct_option_id points to an option of that same question.
- Positive points, supported types/difficulty, nonblank content and ordering
  constraints reject invalid rows. Domain validation additionally verifies
  the option count (two for true/false, at least two for multiple choice).
- A database trigger creates profiles, including a migration backfill for
  users that already exist. Metadata display_name is only presentation data.
- Authenticated users read content but cannot write it. Profiles are private
  per auth.uid(); only display_name is writable by the owner. Anonymous roles
  receive no table grants. Trigger functions have a fixed search_path and
  no direct execute grant to clients.
- Answer keys/explanations are readable by signed-in clients because scoring
  and review remain local. This is not an anti-cheat/secure examination system.
- No assessment attempts, history or statistics are persisted in Phase 4.

## Android and iOS later

Do not launch an emulator. The Android manifest includes Internet permission
and the `com.dias.skillcheck://auth-callback/` link; iOS registers the same scheme.
For later physical-device testing use a separate ignored config file with
`AUTH_REDIRECT_URL` set to that URI and allow both it and
`com.dias.skillcheck://auth-callback/?flow=recovery` in Supabase.
Email/password login uses the same repository and domain logic on all platforms.
Native callback delivery still needs final verification on a physical device.

## References

- [Flutter initialization](https://supabase.com/docs/reference/dart/initializing)
- [Auth events](https://supabase.com/docs/reference/dart/auth-onauthstatechange)
- [Password recovery](https://supabase.com/docs/reference/dart/auth-resetpasswordforemail)
- [Profile triggers](https://supabase.com/docs/guides/auth/managing-user-data)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
