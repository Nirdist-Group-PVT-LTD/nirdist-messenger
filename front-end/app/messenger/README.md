# messenger

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Windows / Chrome launch issue

If `flutter run` fails with an error like `Application Control policy has blocked this file` for `impellerc.exe`, that is a machine policy issue, not an app bug.

Recommended actions:

1. Ask IT or your device admin to allowlist the Flutter engine executable at `C:\flutter\bin\cache\artifacts\engine\windows-x64\impellerc.exe`.
2. Run the app on a machine without that policy.
3. Use the static API test console at `..\..\web-test\index.html` to verify backend behavior while Flutter is blocked.
