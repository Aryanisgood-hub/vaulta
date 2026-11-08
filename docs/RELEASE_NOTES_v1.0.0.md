# Vaulta v1.0.0

**Secure finance management for college clubs.** Track budgets, income, event expenses, bills with receipts, reimbursements and reports, for many clubs, each signing in with its own account.

## Highlights
- 🏫 Many clubs, fully separated: sign in with a club email or Google account
- 📊 Dashboard with remaining balance, budget alerts, total spent and reimbursements
- 🎪 Events with **reimbursements**: expected amount, received, **left to receive**, **left to use**
- 🧾 Bills with categories, search and filters, and photo or PDF receipts
- 📈 Charts: monthly expenditure and event-wise expenditure
- 🔒 Voided records are frozen, nothing is ever deleted, full audit trail
- 📤 Excel and PDF reports, full backup
- 🌗 Light and dark themes, app lock, side-panel navigation

## Download

| File | What it is |
| --- | --- |
| `Vaulta-demo-v1.0.0.apk` | **Try it right away.** Opens a fictional "Demo Club" with sample data. No account, no internet needed, nothing is saved or sent anywhere. |
| Source code | Build your own copy connected to **your own free Firebase project** (see the README). |

**Install (Android):** download the APK, open it, and allow installs from your browser or file manager if Android asks. If Play Protect warns you, choose *Install anyway* (the app isn't on the Play Store).

**SHA-256 (Vaulta-demo-v1.0.0.apk):** `<paste the checksum here>`

## Using it for a real club
The demo APK doesn't store anything. To run Vaulta for a real club you build the app against your own Firebase project (free Spark plan is enough). Step-by-step instructions are in the [README](../README.md).

## Known limits
- "Done by" is picked in the app; with one shared club login it is an audit aid, not proof of identity.
- The free Firebase plan has daily limits (50,000 reads and 20,000 writes) shared by every club in your project.
- Receipts are stored in Firestore: photos are shrunk to under 700 KB and PDFs must be under 700 KB.
- Android only for now (iOS needs extra setup and has not been tested).

Full list of changes: [CHANGELOG](../CHANGELOG.md).
