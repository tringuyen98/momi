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

- Four tabs, redesigned onboarding with a soft botanical mark, stage cards, optional dates, fixed bottom start button and an animated welcome-to-home transition; preparation/pregnancy stage, due-date-based age estimate, and stage change history. Pregnancy Journey follows the supplied design with a pink age/due-date card, horizontal week selector, Mother/Baby stage summaries, next examination appointment, stage-filtered checklist, and nutrition/journal/ultrasound shortcuts.
- Checklist CRUD, groups, completion/undo/archive, dates and reminders. Home includes undated/overdue/today tasks, plus a separate upcoming preview, derived from the same saved snapshot.
- Supplements with ingredients, optional structured quantity/unit per intake, 1–6 editable daily time slots, versioned schedules, weekdays, end dates, pause/resume intervals, intake history and snooze. Home uses “Lịch uống hôm nay”, with one compact card per product, separate check-off rows per time, reminder hours and direct edit/add controls. Active and paused products are both editable from the full product list. The editor uses a single numeric quantity/unit row with minus/plus controls; there is no free-text dose entry. Dates and optional notes/ingredients are collapsed sections. Legacy free-text amounts remain read-only reference text until the user explicitly supplies a numeric per-intake quantity; canceling preserves the original record.
- Local notification scheduling, authenticated lock-screen intake actions, privacy-preserving notification text, authorization status and coverage display.
- Vaccine records grouped by disease category, editable confirmed dose-plan counts, multiple numbered doses per record, and confirmed deletion of one dose or the entire record. Deleting a record cancels its scheduled appointments/reminders while preserving appointment history and shared attachments. Both manual entry and OCR review can select an existing record. Includes appointment links, multi-page native document scan, photo/PDF import, on-device OCR, editable review and optional duplicate merging.
- Medical appointments, questions, reschedule/cancel/complete and linked health records.
- Image/PDF attachments, Quick Look, journal, daily symptoms and period-start logs. Preparation mode includes a monthly calendar with recorded period days, predicted next period, estimated ovulation/fertile interval, persistent cycle settings, and period entry after onboarding. Accessible from Journey and Settings; the duplicate cycle card is removed from Home.
- Small bundled Vietnamese knowledge/food library with source links, bookmarks, preferences, allergen tags and meal planning.
- Device authentication lock, encrypted backup/restore, intake CSV export and iOS PDF visit summary.
- Ultrasound albums tied explicitly to weeks 0–42: photo/PDF import, native document-camera capture, local thumbnails/Quick Look, examination date, notes, edit/move/delete and encrypted backup/restore of original files. Changing the due date never silently reassigns stored photos. The complete album is also available from Mother’s Book, including after changing stages.
- App icon, Info.plist, privacy manifest and a generated shared Xcode scheme.

## Architecture

`MomiCore` contains Codable/Sendable domain records and pure scheduling, validation, conservative OCR parsing, export and encrypted backup logic. It has no UI or persistence-runtime dependency.

`Momi/Features` contains SwiftUI views and local form drafts. `AppStore` serializes mutations on the main actor; it saves first and only then publishes new state. Save failure leaves the previous visible state intact.

`Persistence` stores each domain record as its own SwiftData row (`StoredEntity`: stable key, kind, encoded payload). This deliberate small-app choice keeps the domain portable and allows a complete backup to use the same models. It is not a single JSON file or UserDefaults database. The physical envelope is stable; domain payloads use schema version 1. New ultrasound records use a separate `ultrasound` row kind; old backups without the `ultrasounds` key decode as an empty album. Added checklist stage/category/cycle fields are optional for legacy records. Before changing persisted domain fields, add compatible decoding/migrations and migration tests; never reset an existing store on decode failure.

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

The content library is a small initial set, with source links and no claim of clinical review. It needs Vietnamese clinician review and expansion before being treated as comprehensive pregnancy guidance. Food filters use the sample recipe's main allergens, not a certified allergen database. Cycle predictions are a calendar estimate, anchored to the latest recorded period, using an explicitly displayed default of 28 days until a user sets her cycle length. Estimated ovulation is about 14 days before the next predicted period (NHS); the estimated fertile interval spans five days before through one day after that estimate (ACOG). Defaults for period duration are shown as five days. Predictions do not roll forward through unrecorded periods and stop in pregnancy mode. This does not confirm ovulation or provide contraception guidance. Sources are linked in the cycle screen. HealthKit integration is not implemented. There is no AI diagnosis, prescription generation or automatic supplement dosage recommendation.

## Validation on the implementation machine

- Verified on 2026-10-23 with Xcode 27.1 (27A9275); first-launch components installed successfully.
- Full iOS Simulator build succeeded, including SwiftData macros and all iOS-only services. Build log: `/tmp/momi-xcode-build.log`.
- Full iPhone device build succeeded with signing disabled. This checks compilation/linking; installation still requires selecting a development team. Build log: `/tmp/momi-device-build.log`.
- `swift test --package-path Momi/MomiCore --scratch-path /tmp/momi-xcode-tests` passed all 31 Swift Testing tests, including gestational-week boundaries, weekly ultrasound associations, legacy backup decoding, image backup round trips, shared-file deletion safety, stage filtering, cycle predictions, undated checklist items, legacy record decoding, vaccine deletion/reminder cancellation/shared attachments, and backup round trips with the new optional fields. Test log: `/tmp/momi-core-tests.log`.
- Fixed AppStore initialization to initialize its notification service before accessing observable state for attachment cleanup.
- Simulator runtime download was cancelled at the user’s request. The previous app was tested by the user on a physical iPhone. The current pregnancy Journey/ultrasound/calendar/checklist/vaccine changes compile successfully for iPhone; on-device UI verification of these changes is still pending. Reconnect the iPhone, select it in Xcode, and Run (⌘R) with the same bundle identifier/team to update in place. Do not delete the installed app to update.
- Camera/OCR accuracy, notification delivery, persistence across app launches, and device authentication still require the acceptance checks below. A successful build alone does not establish those behaviors.

## Device acceptance checks before use

1. Create records, force quit, relaunch and verify data/attachments.
2. Test two daily intake times, a weekday-only schedule, marking from notification, snooze over midnight, pause/resume, schedule edit and history.
3. Deny/allow notifications; verify reschedule/cancel removes old requests. Verify queue coverage when many reminders exist.
4. Scan a real multipage vaccine card, fix an ambiguous date, merge a duplicate, create a confirmed appointment and mark the linked dose as given.
5. Export backup, restore into a separate test installation, and compare records plus image/PDF contents. Test wrong password and corrupted files.
6. Verify Face ID/passcode, app switcher cover, camera permission denial, Dynamic Type, keyboard and VoiceOver on the actual iPhone.
7. Verify CSV/PDF exports and all dates/times in Asia/Ho_Chi_Minh and after a timezone change.
8. Skip period entry during onboarding, then add it through Journey/Settings. Change cycle length, navigate calendar months and select a day. Confirm recorded days and estimated days have distinct legends. Switch to pregnancy mode and confirm fertility predictions disappear.
9. Add undated, today, overdue and future checklist tasks; return Home and check the correct sections. Complete a task on Home and confirm the shared checklist updates.
10. Assign a legacy vaccine to a category, set its confirmed planned count, and add multiple doses through manual/OCR entry using the existing-record picker. Delete one dose, then test deleting a separate test vaccine with pending reminders and a shared attachment.

## Pregnancy Journey and ultrasound acceptance checks

1. Switch to pregnancy and enter a due date. Check the displayed current age and that the week strip initially centers the corresponding week. Unknown/invalid age must show an explicit unknown state rather than an invented week.
2. Select week 6, upload images, enter an examination date and notes, and save. Select week 7: week 6 images must not appear there. Return to week 6 and preview the originals.
3. Edit the due date: the age updates, and saved images remain in their explicitly assigned weeks. Edit a record to move it to another week if necessary.
4. Test photo-library import, document-camera capture, PDF import, cancellation and permission denial on the iPhone. Saving is disabled while photo-library data is loading.
5. Force quit/relaunch, then export/restore an encrypted backup and verify each week's notes and original files.
6. Delete a test entry and check unrelated weeks and shared files remain. Check the album is still accessible from Mother's Book after switching back to preparation.
7. Confirm checklist items tagged for pregnancy (and shared items) appear in the pregnancy card; items tagged for preparation do not. Completing an item updates the same saved checklist.
8. Verify the layout at the intended iPhone size and with larger text. Mother/Baby copy is general stage-level guidance, as in the prototype, with NHS source links; it is not an individual scan interpretation or a clinically reviewed week-by-week content library.

## Welcome screen and entrance animation

The welcome screen is implemented in native SwiftUI with vector shapes/SF Symbols, a soft ivory/sage background, serif heading, gently moving botanical emblem and tactile stage cards. The welcome screen does not scroll: it selects a spacious, compact or minimal layout to fit the available height, keeping the start button fixed at the bottom. The name is entered directly on the welcome screen; the hero collapses while typing so the keyboard and start button remain reachable. Optional dates open in a separate editing sheet; canceling it leaves the date unchanged. Stage cards share equal widths and the height of the taller label. Smaller layouts omit decoration, and accessibility text uses a stage menu instead of two cards. Period-start and due-date drafts are independent when switching stages.

After a successful save, a soft circular reveal grows from near the start button, shows a short personalized greeting, then fades into Home while Home settles into place. The normal sequence is about two seconds. Reduce Motion uses a short static greeting and fade, without scaling, floating or blur. Saving failure leaves the editable welcome screen in place; repeated taps are blocked. Backgrounding during the transition finishes the entrance, so returning to the app cannot leave a blocking overlay.

Existing users can choose **Cài đặt → Xem lại màn chào Momi** to preview both the layout and transition without changing their saved profile or records. No deletion/reinstallation is needed. The preview's Close button exits without starting the animation.

The iPhone build succeeds. No simulator runtime is installed, so visual/timing verification on-device remains pending. Check the new screen on the intended iPhone, with the keyboard, both stage/date options, large accessibility text and Reduce Motion. Also test rapid repeated Start taps and background/foreground during the entrance.


### Daily supplement UI verification

On iPhone, add a product with a user-entered quantity/unit and three distinct daily times. Confirm Home shows one compact product card, the quantity per intake and frequency, all three reminder hours, and independent check-off controls. Edit from the pencil without pausing; confirm the future start date is explicit and the pending plan appears on the card. Open a legacy product and verify its original amount is displayed as reference, saving requires an explicit numeric quantity, and canceling leaves the original record unchanged. Verify fractional amounts, duplicate-time validation, disabled notifications, denied notification permission, pause/resume and large text. Reminder delivery on a locked physical iPhone still requires device verification.


### Deleting a supplement

Swipe left on a row in **Vitamin & bổ sung → Tất cả sản phẩm** to reveal Delete, or open the product/detail editor and choose **Xóa sản phẩm**. Both paths ask for confirmation; a full swipe does not delete automatically. Successful deletion removes the product and its snoozes, refreshes pending notifications and cleans up unshared attachments. Self-contained intake history remains visible in the existing history screen. Verify swipe, cancel, confirmed deletion and back navigation on iPhone.
