# SkillCheck

Knowledge assessment and learning progress app. Built incrementally as a Flutter portfolio project.

## Features

Phase 1: Home, Assessments, Progress and Profile navigation; Material 3 light/dark themes; session-only appearance selection. Screens are placeholders. Authentication, quizzes and backend are not implemented.

## Screenshots

Screenshots will be added after the assessment flow is implemented. Run the foundation preview locally for now.

## Tech stack

Flutter 3.47.4 / Dart 3.13.3, Material 3, flutter_riverpod 3.4.3, go_router 18.0.1, flutter_lints and flutter_test.

Planned dependencies: Supabase, fl_chart, simple local preferences. They will be added only when needed.

## Architecture

Feature-based: app configuration in app/, feature UI in features/, reusable widgets in shared/. Data and domain layers will be introduced when needed.

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
    assessments/presentation/
    progress/presentation/
    profile/presentation/
  shared/widgets/
test/
android/
ios/
windows/
```

## Database

File responsibilities: [Phase 1 inventory](docs/phase-1-files.md).

Not connected. Supabase schema, authentication, repositories and RLS are scheduled for Phase 4.

## Getting started

Use Flutter stable compatible with Dart 3.13.3 or newer.

```sh
git clone https://github.com/Dias074/skillcheck.git
cd skillcheck
flutter pub get
flutter doctor
flutter devices
flutter emulators --launch Pixel_9_Pro
flutter run -d emulator-5554
```

Windows requires Visual Studio with Desktop development with C++. For Android, start an emulator or connect a device and run `flutter run -d <device-id>`. iOS requires macOS/Xcode. Windows is included for local preview; Android/iOS are the mobile targets.

Use your own emulator ID from `flutter emulators` and device ID from
`flutter devices`; the commands above show this development machine.
For Windows, use `flutter run -d windows`.

Known local Windows build issue: a Command Processor AutoRun command that prints
CP1251 text (such as `chcp 1251`) can cause Flutter's UTF-8 decoder to fail.
This machine has that configuration. Android is the alternative local run target.

## Environment variables

None required in Phase 1. Environment files and signing keys are ignored. A safe configuration example will be added with the backend. Never put Supabase service-role credentials in the client.

## Testing

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Widget tests cover navigation, theme changes, unknown-route recovery and small-screen layout with enlarged text.

Phase 1 verification: static analysis clean, all four widget tests pass,
Android debug APK builds successfully. Windows build is blocked by the
local encoding issue described above. iOS has not been built on this Windows host.

Manual checks: visit each tab, click Explore assessments, select System/Light/Dark in Profile, and resize the window to test scrolling.

## Roadmap

- [x] Phase 1: Foundation, themes and navigation
- [ ] Phase 2: Domain models and scoring
- [ ] Phase 3: Local assessment prototype
- [ ] Phase 4: Supabase, authentication and RLS
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
