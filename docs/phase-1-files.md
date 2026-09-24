# Phase 1 files

| File | Responsibility | Used by |
| --- | --- | --- |
| lib/main.dart | Entry point and ProviderScope | Flutter runtime |
| lib/app/app.dart | MaterialApp.router and reactive themes | main.dart |
| lib/app/router/app_router.dart | Routes, tab branches, fallback and router lifetime | app.dart |
| lib/app/router/main_navigation.dart | Shared app bar and bottom navigation | app_router.dart |
| lib/app/theme/app_theme.dart | Material 3 light/dark colors and card styling | app.dart |
| lib/app/theme/theme_mode_provider.dart | Session-only appearance state | app.dart, profile_screen.dart |
| lib/features/home/presentation/home_screen.dart | Welcome and assessment link | app_router.dart |
| lib/features/assessments/presentation/assessments_screen.dart | Planned subjects placeholder | app_router.dart |
| lib/features/progress/presentation/progress_screen.dart | Progress placeholder without fake results | app_router.dart |
| lib/features/profile/presentation/profile_screen.dart | Account placeholder and theme control | app_router.dart |
| lib/shared/widgets/page_content.dart | Scrollable page with constrained width | All feature screens |
| lib/shared/widgets/feature_placeholder.dart | Consistent card with optional action | Screens and route fallback |
| test/app_test.dart | Four behavioral widget tests | flutter test |
| pubspec.yaml | App metadata, SDK and dependencies | Flutter/Dart tooling |
| pubspec.lock | Locked dependency versions | flutter pub get |
| analysis_options.yaml | Flutter lints | flutter analyze |
| .gitignore | Excludes artifacts, local config and signing keys | Git |
| .metadata | Generated Flutter platform metadata | Flutter tooling |
| README.md | Status, setup and roadmap | Developers |
| docs/phase-1-files.md | This file inventory | Developers |

## Generated platform hosts

- Android: Gradle build/settings and wrapper configuration; manifests; Kotlin MainActivity; launcher icons; launch backgrounds; styles; platform .gitignore. Application label changed to SkillCheck.
- iOS: Xcode project/workspace and shared scheme; Flutter build configuration; AppDelegate and SceneDelegate; bridging header; Info.plist; storyboards; app icons and launch assets; RunnerTests template; platform .gitignore. Requires macOS/Xcode to build.
- Windows: CMake configuration; plugin registration; C++ runner and window utilities; resource/manifest/icon files; platform .gitignore. Window title changed to SkillCheck.

All platform files come from the standard Flutter template and host the same Dart app. Generated counter code and its test were replaced. Local SDK paths, caches, generated plugin files and build outputs are not committed.
