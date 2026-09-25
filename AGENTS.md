# Development workflow

- Do not launch or use the Android emulator. The development laptop has 8 GB RAM.
- Use Flutter Web / Chrome for current manual UI verification: `flutter run -d chrome`.
- After implementing a phase, run `dart format lib test`, `flutter analyze`, and `flutter test`, then verify relevant UI in Chrome when possible.
- Emulator verification is not a requirement for completing a phase.
- Preserve full Android compatibility. Share application logic across platforms; do not introduce web-specific architecture or features solely for testing.
- Reserve final Android testing for a physical phone connected by the user after the main development phases.
- Use Chrome/Web in testing instructions and learning reports. Do not recommend launching an emulator.
- Complete only the explicitly authorized phase, provide the agreed learning report, then stop. Phase 4 is complete; do not start Phase 5 without an explicit request.
- Do not commit or push unless explicitly requested.
