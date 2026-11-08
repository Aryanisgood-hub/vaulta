# Release checklist (v1.0.0)

Work through this top to bottom. Commands are for Windows Command Prompt.

## 0. Decide first
- [ ] **App id.** The Android id is probably still `com.yourclub.vaulta` (from `flutter create --org com.yourclub`). Once people install the app, changing it makes it a *different* app. If you want something real (for example `io.github.<you>.vaulta`), change it **now**, then run `flutterfire configure` again and add your SHA-1 to the new Android app in Firebase.
- [ ] **Your GitHub username.** Replace `<you>` in the badge links at the top of `README.md` (two places) with your username.
- [ ] **Licence holder.** Open `LICENSE` and replace `<YOUR NAME>`. Also fill `<YOUR EMAIL>` in `SECURITY.md`. Prefer a different licence? Swap the file and the README line.
- [ ] **Logo terms.** If the logo came from an AI image tool, check that tool's terms allow public and commercial use. The README says the name and logo are *not* under the MIT licence; edit that if you disagree.
- [ ] **Which APK to publish** (see the next section). Recommended: the **demo-only** APK.

### Which APK is safe to publish?
| Build | Command | Notes |
| --- | --- | --- |
| **Demo-only** (recommended) | `flutter build apk --release --dart-define=DEMO_ONLY=true` | No Firebase, no sign-in, no data. Safe for anyone to install. |
| Full | `flutter build apk --release` | Connected to **your** Firebase. Anyone with the file can create clubs in your project and use up your free daily quota. Only share it with people you trust. |

## 1. Check the code works
```bat
flutter pub get
flutter analyze
flutter test
cd rules_tests
npm install
npx firebase emulators:exec --only firestore --project vaulta-test "node --test firestore.test.js"
cd ..
```
- [ ] No analyzer **errors** (warnings and lints are okay for now)
- [ ] All Dart tests pass
- [ ] All 31 rule tests pass
- [ ] Open the app: register a club, add an event with reimbursement, add a bill with receipt, record a reimbursement, open both charts, export a report
- [ ] Register a **second** club and confirm it can't see the first club's data
- [ ] Try **Explore demo** and the demo-only build

## 2. Make sure no secrets are published
```bat
git init
git add .
git status
```
Look at the list. These must **not** appear: `lib/firebase_options.dart`, `google_config.dart`, `.firebaserc`, `google-services.json`, `key.properties`, any `.jks` or `.keystore`, `.apk` files. Then scan the staged files:

```bat
git grep --cached -n -I -E "AIza[0-9A-Za-z_-]{20,}|PRIVATE KEY|storePassword|keyPassword" -- . ":(exclude)docs/RELEASE_CHECKLIST.md"
git grep --cached -n -I "googleusercontent" -- . ":(exclude)README.md" ":(exclude)*.example" ":(exclude)docs/RELEASE_CHECKLIST.md"
```
- [ ] Both commands print nothing
- [ ] `firebase.json`: if it contains a `"flutter": { ... }` block with your project id and app ids, you can delete that block before committing (they are not passwords, but there's no reason to publish them; `flutterfire configure` recreates it)
- [ ] If you ever committed a secret by mistake, **change it** (rotate the key); deleting the file later doesn't remove it from history.

## 3. Sign your release build
By default release builds use the debug key. Create your own key once and **back it up** (lose it and nobody can update the app):

```bat
keytool -genkey -v -keystore %USERPROFILE%\vaulta-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vaulta
```
Create `android\key.properties` (git-ignored):
```
storePassword=<your password>
keyPassword=<your password>
keyAlias=vaulta
storeFile=C:\\Users\\<you>\\vaulta-release.jks
```
In `android\app\build.gradle.kts` add at the top `import java.util.Properties` and `import java.io.FileInputStream`, then:
```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) keystoreProperties.load(FileInputStream(keystorePropertiesFile))

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("release") }
    }
}
```
(Merge into your existing `android { ... }` block; don't duplicate it.)
Then add the **release key's SHA-1** in Firebase (Project settings → Your apps → Android → Add fingerprint) so Google sign-in works in the full build:
```bat
keytool -list -v -keystore %USERPROFILE%\vaulta-release.jks -alias vaulta | findstr SHA1
```
- [ ] Release key created and backed up somewhere safe (not in the repo)

## 4. Build the files
```bat
flutter clean
flutter pub get
flutter build apk --release --dart-define=DEMO_ONLY=true
copy build\app\outputs\flutter-apk\app-release.apk Vaulta-demo-v1.0.0.apk
certutil -hashfile Vaulta-demo-v1.0.0.apk SHA256
```
- [ ] Install `Vaulta-demo-v1.0.0.apk` on a phone (uninstall older versions first) and check it opens straight into Demo Club
- [ ] Paste the SHA-256 into `docs/RELEASE_NOTES_v1.0.0.md`
- [ ] Don't commit the `.apk`; attach it to the release instead

## 5. Put it on GitHub
1. On github.com click **New repository** → name it `vaulta` → Public → **don't** add a README or licence (you already have them).
2. Then:
```bat
git add .
git commit -m "Vaulta v1.0.0"
git branch -M main
git remote add origin https://github.com/<you>/vaulta.git
git push -u origin main
```
3. On the repository page: **About** (gear icon) → add a description, e.g. *Secure finance management for college clubs: budgets, events, bills, reimbursements and reports. Flutter + Firebase.* Add topics: `flutter`, `firebase`, `dart`, `finance`, `college-clubs`, `expense-tracker`, `riverpod`.
4. **Settings → General → Social preview** → upload `docs/social-preview.png`.
5. Check the **Actions** tab: the CI run should be green. If it fails, open it and read the first error.
6. **Settings → Code security** → enable *Private vulnerability reporting*.

## 6. Publish the release
```bat
git tag -a v1.0.0 -m "Vaulta v1.0.0"
git push origin v1.0.0
```
1. Repository → **Releases** → **Draft a new release** → choose tag `v1.0.0`.
2. Title: `Vaulta v1.0.0`. Paste the text from `docs/RELEASE_NOTES_v1.0.0.md` into the description.
3. Drag in `Vaulta-demo-v1.0.0.apk`.
4. Tick **Set as the latest release** → **Publish release**.
- [ ] Download the APK from the release page on your phone and install it once to confirm

## 7. After publishing
- [ ] Add the screenshots (see `docs/screenshots/README.md`) and push
- [ ] Add the repository link to your LinkedIn post
- [ ] Watch the Firebase **Usage** tab for the first weeks if you shared a full build
- [ ] Consider turning on **Firebase App Check** before sharing any build that is connected to your Firebase project
