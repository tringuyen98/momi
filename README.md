# Momi

Native personal app for preparation for pregnancy and pregnancy. iOS 18+, Swift 6, SwiftUI, SwiftData, Vision/VisionKit and local notifications. No external Swift dependencies, account, backend, analytics or cloud OCR.

The original `../Momi mobile app prototype/` is unchanged. This project reimplements its flows in native SwiftUI; it does not embed the HTML prototype.

## Open and run

1. Install full Xcode with an iOS SDK. Command Line Tools alone cannot build this app.
2. Open `Momi.xcodeproj` and select the **Momi** scheme.
3. For a simulator, select an installed iPhone simulator and Run.
4. For a device, select your Apple development team in **Signing & Capabilities**, choose a unique bundle identifier, connect the iPhone, enable Developer Mode if requested, and Run.
5. Use a real device to check camera scanning, Face ID, notification actions and background/lock-screen behavior.

No production user data is preloaded. Onboarding creates a fresh profile; all products, doses, vaccine appointments and records are entered or confirmed by the user.

```sh
# Once full Xcode is selected:
xcodebuild -project Momi.xcodeproj -scheme Momi \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

# Swift Testing suite (requires Xcode's test libraries):
swift test --package-path MomiCore

# Same core assertions, also works with Command Line Tools:
python3 scripts/generate_core_checks.py
swift run --package-path MomiCore MomiCoreChecks
```

`scripts/generate_project.py` regenerates the Xcode project after adding source files. It uses only Python's standard library. If you change signing in Xcode, rerunning this generator resets the generated signing settings; reselect your team afterward. The shared scheme is included.

## Implemented code

- Four tabs, onboarding, preparation/pregnancy stage, due-date-based age estimate, and stage change history.
- Checklist CRUD, groups, completion/undo/archive, dates and reminders.
- Supplements with ingredients, versioned schedules, weekday/time slots, end dates, pause/resume intervals, intake history and snooze.
- Local notification scheduling, authenticated lock-screen intake actions, privacy-preserving notification text, authorization status and coverage display.
- Vaccine records and individual doses, appointment links, multi-page native document scan, photo/PDF import, on-device OCR, editable review and optional duplicate merging.
- Medical appointments, questions, reschedule/cancel/complete and linked health records.
- Image/PDF attachments, Quick Look, journal, daily symptoms and period-start logs.
- Small bundled Vietnamese knowledge/food library with source links, bookmarks, preferences, allergen tags and meal planning.
- Device authentication lock, encrypted backup/restore, intake CSV export and iOS PDF visit summary.
- App icon, Info.plist, privacy manifest and a generated shared Xcode scheme.

## Architecture

`MomiCore` contains Codable/Sendable domain records and pure scheduling, validation, conservative OCR parsing, export and encrypted backup logic. It has no UI or persistence-runtime dependency.

`Momi/Features` contains SwiftUI views and local form drafts. `AppStore` serializes mutations on the main actor; it saves first and only then publishes new state. Save failure leaves the previous visible state intact.

`Persistence` stores each domain record as its own SwiftData row (`StoredEntity`: stable key, kind, encoded payload). This deliberate small-app choice keeps the domain portable and allows a complete backup to use the same models. It is not a single JSON file or UserDefaults database. The physical envelope is stable; domain payloads use schema version 1. Before changing persisted domain fields, add compatible decoding/migrations and migration tests; never reset an existing store on decode failure.

Attachments live in Application Support with relative filenames. Metadata is kept in the database. Imported files are staged before the database commit; abandoned files are cleaned at the next launch. No health content is written to diagnostics.

## Important behavior

### Intake history

- Occurrence identity is schedule ID + slot ID + local calendar day.
- Recorded intake snapshots include product name, amount, scheduled time and recorded time.
- Editing a schedule takes effect tomorrow or later, preserving today's schedule and past history.
- Pause/resume takes effect at the current instant and is represented by intervals, so earlier occurrences are retained.
- Notification actions are idempotent and stale notifications cannot create records for a removed occurrence.
- Unrecorded does not mean skipped. The app gives no catch-up dosing advice.

### Notification coverage

The first implementation schedules a bounded queue of one-shot notifications, up to 60 total. Up to 20 slots are reserved for the nearest appointment/task reminders; remaining slots cover the nearest intake occurrences in the next 14 days. Coverage and truncation are visible in the app. Reconciliation runs on successful edits and foreground activation. Snoozes retain the original occurrence, including across midnight.

**The app must be reopened before the displayed coverage end to extend daily reminders.** It does not claim unlimited delivery without reopening, guaranteed background refresh, or delivery overriding Focus/system settings. Timezone changes are reconciled when the app next becomes active. Test these cases on the intended device before daily reliance.

### OCR

Vision runs on device. Supported languages are queried rather than assuming Vietnamese recognition works on every OS/device. The native camera handles multipage capture and cropping. PDFs with usable embedded text use it directly; otherwise pages are rendered for OCR.

The initial parser is intentionally conservative: it creates **one draft**, fills recognizable labels, separates labelled injection dates from follow-up dates, and retains all recognized text. For a sheet with several vaccinations, the user adds more draft rows and checks them against the original. It does not yet reconstruct arbitrary table rows, reliably read handwriting, or automatically associate multiple vaccines with dates. Every row must be confirmed. Calendar dates are validated, and vaccine schedules are never inferred.

Per-file import limit: 30 MB. PDF/scan limit: 20 pages per operation. Test on actual Vietnamese vaccine cards; machine-generated images are not enough to establish accuracy.

### Backup and export

`.momi` backups include the versioned data snapshot and original attachment bytes. Encryption uses AES-GCM with a random salt and PBKDF2-HMAC-SHA256 (210,000 rounds). The password is never persisted. No password recovery is available. Restore validates schema, dates, IDs, references and filenames; attachments are staged under fresh names before committing the database. The old database remains unchanged if staging or commit fails.

Backup size limit: 250 MB. Saving a backup requires choosing a Files destination; creating an in-memory archive alone is not reported as successful export. Files may be saved in iCloud Drive by the user, but there is no automatic iCloud/CloudKit sync.

PDF/CSV exports are readable, unencrypted sharing formats and cannot restore the app. PDF summaries do not embed original medical images.

### Content and scope

The content library is a small initial set, with source links and no claim of clinical review. It needs Vietnamese clinician review and expansion before being treated as comprehensive pregnancy guidance. Food filters use the sample recipe's main allergens, not a certified allergen database. Cycle features record observations; fertility prediction and HealthKit integration are not implemented. There is no AI diagnosis, prescription generation or automatic supplement dosage recommendation.

## Validation on the implementation machine

- Verified on 2026-10-23 with Xcode 27.1 (27A9275); first-launch components installed successfully.
- Full iOS Simulator build succeeded, including SwiftData macros and all iOS-only services. Build log: `/tmp/momi-xcode-build.log`.
- Full iPhone device build succeeded with signing disabled. This checks compilation/linking; installation still requires selecting a development team. Build log: `/tmp/momi-device-build.log`.
- `swift test --package-path Momi/MomiCore --scratch-path /tmp/momi-xcode-tests` passed all 15 Swift Testing tests. Test log: `/tmp/momi-core-tests.log`.
- Fixed AppStore initialization to initialize its notification service before accessing observable state for attachment cleanup.
- Simulator launch and UI/runtime checks remain pending: no iOS Simulator runtime was installed. An iOS runtime download was started with `xcodebuild -downloadPlatform iOS`; progress is in `/tmp/momi-runtime-download.log`. Once installed, select an iPhone simulator in Xcode and Run.
- Camera/OCR accuracy, notification delivery, persistence across app launches, and device authentication still require the acceptance checks below. A successful build alone does not establish those behaviors.

## Device acceptance checks before use

1. Create records, force quit, relaunch and verify data/attachments.
2. Test two daily intake times, a weekday-only schedule, marking from notification, snooze over midnight, pause/resume, schedule edit and history.
3. Deny/allow notifications; verify reschedule/cancel removes old requests. Verify queue coverage when many reminders exist.
4. Scan a real multipage vaccine card, fix an ambiguous date, merge a duplicate, create a confirmed appointment and mark the linked dose as given.
5. Export backup, restore into a separate test installation, and compare records plus image/PDF contents. Test wrong password and corrupted files.
6. Verify Face ID/passcode, app switcher cover, camera permission denial, Dynamic Type, keyboard and VoiceOver on the actual iPhone.
7. Verify CSV/PDF exports and all dates/times in Asia/Ho_Chi_Minh and after a timezone change.
