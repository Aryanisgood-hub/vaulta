# Changelog

All notable changes to Vaulta are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/).

## [1.0.0] - 2026-11-08

First public release.

### Added
- Multi-club accounts: each club signs in with its own email (verified) or Google account; data is isolated per club.
- Dashboard with remaining balance, budget alerts at 80% and 100%, total spent and reimbursements.
- Events (create and edit), bills with categories, search and filters, and digital receipts (photos are shrunk and kept in Firestore).
- Voiding instead of deleting, with a full audit trail for bills and budget changes.
- Income tracking.
- Event reimbursements: expected amount, money received, **left to receive** and **left to use**.
- Charts: monthly expenditure and event-wise expenditure.
- Excel and PDF reports, event and monthly reports, full backup.
- App lock (fingerprint, face or PIN), light and dark themes, side-panel navigation.
- Roboto Condensed font, animated launch screen, V app icon.
- **Explore demo** mode with sample data, and a backend-free `DEMO_ONLY` build option.
- Firestore security rules with 31 automated tests.
