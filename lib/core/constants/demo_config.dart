/// "Explore demo" button on the sign-in screen.
/// It opens Vaulta with made-up sample data (nothing is read from or written to Firebase).
/// Set to false to hide the button.
const demoEnabled = true;

/// Name of the fictional club shown in the side panel.
const demoClubName = 'Demo Club';

/// Small "DEMO MODE" label under the club name in the side panel.
const demoBadge = true;

/// Backend-free build, safe to share publicly:
///   flutter build apk --release --dart-define=DEMO_ONLY=true
/// It never connects to Firebase and opens straight into the Demo Club.
const demoOnly = bool.fromEnvironment('DEMO_ONLY');
