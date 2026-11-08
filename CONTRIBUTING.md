# Contributing to Vaulta

Thanks for helping! Small fixes and focused improvements are very welcome.

## Set up
1. Follow **Getting Started** in `README.md` (you need your own free Firebase project).
2. `flutter pub get`

## Before you open a pull request
```bash
flutter analyze
flutter test
# if you touched firestore.rules:
cd rules_tests && npm install
npx firebase emulators:exec --only firestore --project vaulta-test "node --test firestore.test.js"
```

## Guidelines
- Money is always **integer paise**, never doubles.
- Anything a club must be able to trust (bills, income, reimbursements) is enforced in `firestore.rules` too, with a test.
- Keep pull requests small and describe what changed and why. Add a test when you fix a bug.
- Don't commit secrets or local config (see `.gitignore`).
- Use the **Explore demo** mode to try your change without touching real data.
