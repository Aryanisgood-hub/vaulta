GITHUB RELEASE KIT

1. Copy EVERYTHING in this folder into your vaulta project folder ("Replace all").
   (It does not touch lib\firebase_options.dart, google_config.dart, .firebaserc or android\.)
2. flutter pub get
3. Open  docs\RELEASE_CHECKLIST.md  and follow it from the top.

Before you push, fill in:  <YOUR NAME> in LICENSE,  <YOUR EMAIL> in SECURITY.md,  <you> in README.md.

Build the safe public APK with:
   flutter build apk --release --dart-define=DEMO_ONLY=true
