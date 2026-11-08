<div align="center">

<img src="assets/icon/app_icon.png" width="112" alt="Vaulta logo">

# Vaulta

### Secure Finance Management for College Clubs

A cross-platform Flutter app for managing **club budgets, income, event expenses, bills, receipts, reimbursements and reports**, built for **many clubs**, each signing in with its own club email.

**Built with Flutter · Firebase (Auth + Firestore, free Spark plan) · Riverpod**

[![CI](https://github.com/<you>/vaulta/actions/workflows/ci.yml/badge.svg)](https://github.com/<you>/vaulta/actions/workflows/ci.yml)
![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Spark_plan-FFCA28?logo=firebase&logoColor=black)

[Download the demo](../../releases/latest) · [Getting started](#getting-started) · [Changelog](CHANGELOG.md)

</div>

---

## 📥 Try it

Download the **demo APK** from the [latest release](../../releases/latest) and install it on an Android phone. It opens a fictional **Demo Club** with sample data (events, bills, reimbursements, charts). No account, no internet, nothing is saved or sent anywhere.

To run Vaulta for a **real club**, build it against **your own free Firebase project** (see [Getting started](#getting-started)). The released demo APK is not connected to any backend.

<!-- Screenshots: add images to docs/screenshots and see docs/screenshots/README.md -->

---

## ✨ Why Vaulta?

Club finances usually live in spreadsheets, WhatsApp groups and paper receipts. Vaulta puts the whole workflow in one place:

**Budget + Income → Events → Bills → Receipts → Reimbursements → Reports → Audit Trail**

Every club's data is private to that club, every record is traceable, and sensitive rules are enforced by **Firebase Security Rules**, not just by hiding buttons.

---

## 🚀 Features

| Feature | Description |
| --- | --- |
| 🏫 **Multi-club** | Any club can register; each club only ever sees its own data |
| 📧 **Club-email login** | One account per club, with email verification and password reset by email |
| 🔵 **Google sign-in** | "Continue with Google" using the club's Google account (new clubs just name their club) |
| 📊 **Dashboard** | "Hi, club" greeting, remaining balance, quick actions, **Total spent** and **Reimbursements** compartments, recent transactions |
| 🚨 **Budget alerts** | Warning at 80% of funds used, red alert at 100% |
| 💵 **Income tracking** | Sponsorships, fees, grants: the balance is `budget + income − spending` |
| 🎪 **Event-based expenses** | Every bill belongs to an event |
| ✏️ **Edit events** | Rename an event or change its date or description; every bill and report shows the new name |
| 🏷️ **Expense categories** | Editable per club |
| 🧾 **Digital receipts** | Camera, gallery or image/PDF; photos are auto-shrunk and stored privately in Firestore |
| 💱 **Event reimbursements** | Each event asks *"Is reimbursement available, and how much?"*. It lowers that event's expenditure, and Vaulta tracks how much has been received and how much is still left |
| 📈 **Charts** | Monthly expenditure (6 or 12 months) and event-wise expenditure, under *Charts* in the side panel |
| 🔎 **Search & filters** | By text, event, category and status |
| 📝 **Audit trail** | Every create, edit, void and reimbursement is logged (who, when, what) |
| 📤 **Excel + PDF reports** | Full backup, event report, monthly report |
| 🔐 **App lock** | Fingerprint / face / PIN when opening the app |
| 🎬 **Explore demo** | A button on the sign-in screen that opens the app with made-up sample data (never saved to Firebase) |
| ✨ **Launch animation** | The V slides up, "Vaulta" and the tagline fade in, then it fades into the app (tap to skip) |
| 🌗 **Light & dark mode** | Two modes in a teal and sand palette, switchable from the side panel |
| 🧭 **Side panel navigation** | Slide-out menu on phones, permanent sidebar on wide screens, plus the Vaulta logo (top right) that jumps to Home from any page. The phone's Back button steps back through the pages you visited |
| 📴 **Offline-friendly** | Firestore caches data on mobile; changes sync when you're back online |

---

## 🔑 How club login works

```text
Club registers (club name + club email + password)
        │
        ▼
Verification email  ──►  Club taps the link
        │
        ▼
Vaulta creates the club profile  ──►  Club signs in on any device
```

- One Firebase account = one club. Its `uid` is the club's ID.
- There are **no President / Treasurer roles**. Whoever has the club login can manage the club's finances.
- Because the login is shared, every action asks **"Done by"**, picked from the **team names** the club saves in *Settings*. The audit trail records that name.

---

## 🎬 Demo mode

The sign-in screen has an **Explore demo** button. It opens Vaulta as a fictional club called **Demo Club** (nine events, about thirty bills, income, reimbursements, budget history and charts). It runs entirely in memory:

- nothing is read from or written to Firebase, and there is no demo account or password;
- you can add, edit and void records to try the app; they reset when you tap **Exit demo** or restart the app;
- hide the button with `demoEnabled = false`, or change the club name with `demoClubName`, in `lib/core/constants/demo_config.dart`;
- the sample data lives in `lib/demo/demo_store.dart`.

---

## 🔐 Security

> **Hiding a button is not security.** Authorization is enforced by Firebase.

Defined in [`firestore.rules`](firestore.rules):

- 🏫 A club can only read/write `clubs/{its own uid}/...`. Other clubs' data is unreachable
- 📧 Unverified emails have no access at all
- 🚫 Bills, income, events and the club profile **cannot be deleted**
- 🧊 **Voided bills are frozen**; they cannot be edited or un-voided
- 💵 Amounts must be **positive integers** (paise); floats, zero and negatives are rejected
- ⏱️ `createdAt` / `updatedAt` / history timestamps must equal the **server time**, so they can't be faked
- 📝 Bill history and budget log are **append-only**
- 💱 Reimbursement amounts must be whole paise ≥ 0; money **received** is append-only (it can only be voided) and must point at a real event
- 💰 Income can only be voided, never edited
- 🔒 Receipts are private to the club, with no public links. Only JPEG images or PDFs up to 700 KB are accepted, and receipts can't be edited or deleted

> ⚠️ **Honest limitation.** Without Cloud Functions, "who did it" (`doneBy`) is typed or selected by the club in the app, not verified by the server. This is fine for a trusted club team, but it is an audit aid, not proof of identity.

---

## 💱 How reimbursements work

When you create an event, Vaulta asks **"Reimbursement available?"** and, if yes, **how much**.

```text
Event expenditure = bills total − reimbursement amount     (never below zero)
Received          = reimbursement money that has actually arrived (you record each payment)
Left to receive   = reimbursement amount − received          (promised, not here yet)
Left to use       = received − what the event's bills needed (here, but nothing has needed it yet)
```

- **Total spent** on the dashboard is the sum of every event's expenditure *after* reimbursement.
- **Remaining balance** = budget + income − total spent.
- The **Reimbursements** compartment shows **left to use** and **left to receive**, and the Reimbursements page tracks both for every event.
- Money you received but didn't need (*left to use*) is added to your funds, so the remaining balance matches the cash you really have.
- Receiving money is recorded as append-only entries (voidable, never deleted).

> Because the reimbursement amount lowers spending as soon as it is entered, the balance counts money that may not have arrived yet. The *left to receive* figure tells you how much of it is still outstanding.

---

## 💵 Financial Accuracy

All money is stored as **integer paise**, never floating-point.

```text
₹1        →      100 paise
₹1,250    →  125,000 paise
₹50,000   → 5,000,000 paise
```

Voided bills and voided income are excluded from every total.

---

## 🏗️ Architecture

```text
┌─────────────────────────────┐
│      Flutter Application    │
│  Screens → Riverpod → Repos │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│          Firebase           │
│     Auth · Firestore        │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│   Security Rules (server)   │
└─────────────────────────────┘
```

### Firestore layout

```text
clubs/{clubId}                 name, email, totalBudget, categories[], members[]
  ├─ events/{id}               name, date, description,
  │                            reimbursementAvailable, reimbursementAmount
  ├─ bills/{id}                eventId, amount, reason, category, receiptPath,
  │   │                        doneBy, status, reimbursement, timestamps
  │   └─ history/{id}          append-only audit log
  ├─ income/{id}               amount, source, type, status
  ├─ reimbursements/{id}       money received: eventId, amount, date, doneBy, status
  ├─ receipts/{id}             data (bytes ≤ 700 KB), contentType, name
  └─ budgetLog/{id}            append-only: old → new budget, who, why
```


---

## 🛠️ Tech Stack

| Layer | Technology |
| --- | --- |
| UI | Flutter, Dart, Material 3 |
| State | Riverpod |
| Backend | Firebase Auth, Cloud Firestore (free Spark plan) |
| Reports | `excel`, `pdf`, `share_plus` |
| Images | `image` (receipt compression) |
| Font | Roboto Condensed (bundled in `assets/fonts`, SIL Open Font License) |
| Device | `image_picker`, `file_picker`, `local_auth`, `shared_preferences` |

> Navigation uses Flutter's built-in `Navigator` with an auth gate (sign-in → verify email → lock → app). Switching to `go_router` later is straightforward.

---

## 📁 Project Structure

```text
lib/
├── main.dart · app.dart · firebase_options.dart (generated)
├── core/          constants, errors, theme, utils (money, formatters, chart data)
├── models/        club, event, bill, income, logs, summary
├── services/      auth, app lock, export (Excel + PDF)
├── repositories/  club, event, bill, income
├── providers/     Riverpod providers
├── screens/       auth, shell, dashboard, events, bills, income, charts,
│                  reimbursements, reports, settings
└── widgets/       shared widgets

firestore.rules · firebase.json
rules_tests/       security-rule tests (Firebase emulator)
test/              Dart unit tests
```

---

<a name="getting-started"></a>

## ⚙️ Getting Started

### Prerequisites
Flutter SDK, Android Studio, Chrome, Git, Node.js (for rule tests), and a Google account.

### 1. Create the platform folders
This repository ships only the shared code. In the project folder run:

```bash
flutter create . --project-name vaulta --org <your.reverse.domain>   # e.g. io.github.yourname
rm test/widget_test.dart      # generated sample test that doesn't match this app
flutter pub get
```

### 2. Create your local config files
Your keys stay on your computer, so these files are **not** in the repository. Copy the templates:

```bash
copy .firebaserc.example .firebaserc
copy lib\core\constants\google_config.dart.example lib\core\constants\google_config.dart
```
(On macOS/Linux use `cp` and forward slashes.) You'll fill in `.firebaserc` in step 5 and `google_config.dart` in step 7. `lib/firebase_options.dart` is generated for you in step 4.

### 3. Create a Firebase project
1. [console.firebase.google.com](https://console.firebase.google.com) → **Add project**.
2. **Build → Authentication → Get started** → enable **Email/Password**.
3. **Build → Firestore Database → Create database** (production mode).

> **Stay on the free Spark plan.** Do **not** open the *Storage* tab or upgrade to Blaze. Vaulta doesn't use Firebase Storage; receipts are kept in Firestore.

### 4. Connect the app
```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
flutterfire configure        # generates lib/firebase_options.dart (git-ignored)
```

### 5. Deploy the security rules  (do this before real use)
```bash
# put your project id in .firebaserc first
firebase deploy --only firestore:rules,firestore:indexes
```

### 6. Platform settings

**Android**
- `android/app/build.gradle(.kts)`: set `minSdk = 23`.
- `android/app/src/main/AndroidManifest.xml`: add
  `<uses-permission android:name="android.permission.INTERNET"/>`,
  `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`, and set `android:label="Vaulta"`.
- `MainActivity` must extend `FlutterFragmentActivity` (required by `local_auth`):
  ```kotlin
  import io.flutter.embedding.android.FlutterFragmentActivity
  class MainActivity : FlutterFragmentActivity()
  ```

**iOS** (`ios/Runner/Info.plist`): add `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSFaceIDUsageDescription`.

### 7. (Optional) Turn on Google sign-in
1. Firebase console → **Authentication → Sign-in method → Google → Enable** (choose a support email, Save).
2. **Chrome / web:** nothing else to do. The Google button works straight away.
3. **Android app:**
   - Get your debug SHA-1:
     `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`
     (if `keytool` isn't found, use the one in Android Studio: `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`).
   - Firebase console → Project settings → **Your apps → Android app → Add fingerprint** → paste the SHA-1.
   - Back in **Authentication → Sign-in method → Google**, copy the **Web client ID**
     and paste it into `lib/core/constants/google_config.dart`.
   - If you later sign the release APK with your own keystore, add that keystore's SHA-1 as well.
4. Rebuild the app.

### 8. (Optional) App icon
```bash
dart run flutter_launcher_icons
```
This generates the Android, iOS and web icons from `assets/icon/`.

### 9. (Optional) Native launch screen
```bash
dart run flutter_native_splash:create
```
Run it once. It makes the first blink after tapping the app icon navy with the V (instead of white), so it flows straight into the animated intro. Then uninstall the app and run it again.

### 10. Run
```bash
flutter run -d chrome
flutter run -d <device-id>
```

First launch: **Register** your club → open the verification email → **I've verified** → *More → Settings*: set the **club budget**, **categories**, and **team names**.

---

## 🧪 Testing

```bash
flutter analyze
flutter test                      # money, charts, reimbursements and demo-data unit tests

# Security-rule tests (need Java + Firebase emulators)
cd rules_tests && npm install
npx firebase emulators:exec --only firestore --project vaulta-test "node --test firestore.test.js"
```

The Firestore suite has **31 checks** covering isolation between clubs, unverified users, fake timestamps, bad amounts, frozen voided bills, no deletion, append-only logs, receipt limits, event reimbursements and received-money entries. GitHub Actions runs `flutter analyze` and `flutter test` on every push.

---

## 📦 Build APK

1. Raise `version:` in `pubspec.yaml` (the number after `+` must increase).
2. Build:

```bash
# Connected to YOUR Firebase project (share only with people you trust)
flutter build apk --release

# Backend-free demo build, safe to share publicly (no Firebase, no sign-in, no data)
flutter build apk --release --dart-define=DEMO_ONLY=true
```
3. Output: `build/app/outputs/flutter-apk/app-release.apk`

Sign release builds with **your own keystore** and keep it safe; the full steps are in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md). Always build with the same keystore so people can update over the old version.

> A build connected to your Firebase project lets anyone who has the APK register a club in your project and use your free daily quota. For public sharing, prefer the demo build.

---

## 🆓 Free-plan limits (Firebase Spark)

Firestore's free quota is shared by **all clubs in your Firebase project**:

| Limit (per day / total) | Free allowance |
| --- | --- |
| Stored data | 1 GiB total (≈ 4,000-8,000 receipt photos at 100-250 KB each) |
| Document reads | 50,000 / day |
| Document writes | 20,000 / day |

This is plenty for a handful to a few dozen small clubs. If Vaulta grows past that, Firebase pauses access when a daily quota runs out; it does not charge you on Spark. Options then are upgrading to Blaze with a budget cap, or moving receipts to a separate image host.

---

## 💾 Backups

Firestore has no free automatic backup. Use **More → Reports & export → Full backup** once a month and keep the Excel file in Google Drive. Receipt images are not included in the Excel file; it lists each receipt's file name.

---

## 🩺 Troubleshooting

| Problem | Fix |
| --- | --- |
| "Firebase is not configured" | Run `flutterfire configure` |
| "Not allowed" errors | Verify your email, sign in again, and make sure rules are deployed. A **voided bill is locked by design** |
| Verification email missing | Check spam, then tap **Resend email** |
| Receipt won't attach | PDFs must be under 700 KB (photos are shrunk automatically). Make sure the rules are deployed |
| App locks when I open the camera | Update to the latest code; the lock pauses while pickers are open |
| App lock option greyed out | Device has no screen lock/biometrics set, or you're on web |

---

## 🗺️ Roadmap

### Completed
- [x] Multi-club registration with verified club email
- [x] Dashboard, budget alerts, categories
- [x] Events, bills, receipts, search and filters
- [x] Income tracking
- [x] Event-level reimbursement tracking (expected, received, left)
- [x] Teal UI with side panel, light and dark mode
- [x] Charts: monthly and event-wise expenditure
- [x] Google sign-in
- [x] Vaulta logo and app icon
- [x] Budget change log and bill audit trail
- [x] Excel and PDF reports, full backup
- [x] App lock, dark mode
- [x] Firestore security rules with automated tests

### Possible next steps
- [ ] Per-event budgets
- [ ] Academic-year archive
- [ ] Verified per-member sign-in (needs Cloud Functions)
- [ ] Automated monthly backup (needs Cloud Functions)
- [ ] Platform-owner admin panel to approve new clubs

---

## 🤝 Contributing & security

Pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Please report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## 📄 License

The source code is released under the [MIT License](LICENSE).
The **Vaulta name, logo and app icon** are not covered by that licence. Fonts and other third-party assets are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

<div align="center">

### 🛡️ Vaulta
**Secure • Transparent • Accountable**

Built with **Flutter + Firebase**

</div>
