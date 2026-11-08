# Security policy

## Reporting a vulnerability

Please **don't open a public issue** for security problems.
Use GitHub's **Report a vulnerability** button (Security tab → Advisories) or email `<aryan.verma2512@gmail.com>`.
Include what you found, how to reproduce it, and which version you tested. You'll get a reply as soon as possible.

## What is protected, and how

Vaulta's data protection is enforced by the Firebase security rules in `firestore.rules`, not by the app's buttons:

- a club can only read and write its own data;
- unverified emails have no access;
- bills, income, events and receipts can't be deleted; voided bills are frozen;
- history logs and budget changes are append-only; server time is required for timestamps.

The rules have automated tests in `rules_tests/`. If you change the rules, run them.

## Known limits

- "Done by" is chosen in the app. The shared club login means it is an audit aid, not proof of identity.
- Anyone who has a build connected to a Firebase project can register a club in that project. If you host a public build, enable Firebase App Check and keep an eye on usage.

## Keep secrets out of the repository

Never commit `lib/firebase_options.dart`, `google_config.dart`, `google-services.json`, `key.properties` or any keystore (`*.jks`). They are in `.gitignore`.
