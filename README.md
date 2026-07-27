# LeadMantraCRM — Call Log Fetch

WhatsApp-First CRM companion app. Watches the device's call log and turns incoming/outgoing
calls into CRM leads, with a confirmation popup per new number.

## How lead capture works

### 1. Call detection
- `android/app/src/main/kotlin/.../MainActivity.kt` registers a `ContentObserver` on
  Android's `CallLog.Calls.CONTENT_URI`. Any change to the system call log (i.e. a call
  finishes and gets logged) sends an event over the `com.leadmantracrm.app/call_log_events`
  EventChannel to Dart.
- No foreground service, no `WorkManager` — the observer only fires while the app process
  is alive. If Android kills the process in the background, nothing is missed permanently;
  it's picked up by the catch-up sync described below.

### 2. Sync (`lib/services/lead_sync_service.dart`)
- On event: debounce 2s, then run `syncNow()`.
- On app open (`dashboard_screen.dart` → `_init()`): `LeadSyncService.start()` then an
  explicit `syncNow()` call, to catch up on anything missed while the app was closed.
- `syncNow()` queries `CallLog.query(dateTimeFrom: _syncStartedAt)` — **`_syncStartedAt` is
  set once on first install/login and never reset**, so every sync re-scans the full
  history since install, relying on persisted markers (below) to skip what's already done.
- Only `incoming`/`outgoing` calls are considered leads (missed calls are not).
- Calls are grouped by normalized phone number — **one popup per unique number**, even if
  that number called multiple times (all its call IDs get marked together).

### 3. Confirmation popup (`lib/widgets/lead_confirm_dialog.dart`)
Before showing the popup, `syncNow()`:
1. Checks `navigatorKey.currentContext` — if null (app backgrounded/no UI), the dialog is
   **not shown** and **nothing is marked handled**, so this number is retried on the next
   sync/app open.
2. Runs `hasInternetConnection()` (`lib/core/connectivity_util.dart`, a DNS lookup probe) —
   if offline, shows a red snackbar and passes `hasInternet: false` into the dialog.

In the dialog:
- **Skip** — always enabled, works offline. Permanently blocks that number from ever
  prompting again (added to `_handledNumbers`). Recorded in the Skipped Leads list.
- **Send Lead** — only enabled once the "Confirm and send as lead" checkbox is ticked
  *and* internet is available. While the dialog is open, connectivity is re-checked every
  2 seconds, so the button enables itself automatically if Wi-Fi/data comes back — no need
  to close and reopen the popup.

### 4. Marking handled — only on confirmed success
- `Skip` → marked handled immediately (permanent block, by design).
- `Send Lead` → the API call (`ApiService.captureLead`) happens **first**. The number/call
  IDs are only marked handled, and the lead added to the Leads list, if the API returns a
  successful result. A failure (no internet mid-call, timeout, non-200 response) leaves the
  number **unmarked**, so it's retried on the next sync instead of being silently dropped.

## Screens

| Screen | Purpose |
|---|---|
| `dashboard_screen.dart` | Today's Overview stats (Total, Leads Captured, **Skipped**, Connected), Lead Pipeline, Recent Activity. |
| `leads_screen.dart` | Full list of leads successfully sent to the CRM (`LeadSyncService.capturedLeads`). |
| `skipped_leads_screen.dart` | Full list of numbers you chose to Skip, with name/phone/time (`LeadSyncService.skippedLeads`). Opened by tapping the **Skipped** stat card. |
| `call_log_screen.dart` | Pure display of the device call log with date-range/type filters. **No lead logic runs here** — no popups, no silent lead capture, viewing/filtering never touches `LeadSyncService` or the API. |

## Local persistence (`SharedPreferences`)

| Key | Meaning |
|---|---|
| `lead_sync_started_at` | Set once on first install; the start of the window `syncNow()` scans. Never reset except by reinstall/clear-data. |
| `lead_uploaded_ids` | Per-call IDs (`timestamp_number_calltype`) already processed — prevents re-prompting a duplicate log entry. |
| `lead_handled_numbers` | Normalized phone numbers that were confirmed **or** skipped — blocked from ever prompting again. |
| `lead_captured_leads` | Details of leads successfully sent to the CRM (for the Leads screen). |
| `lead_skipped_leads` | Details of numbers you skipped (for the Skipped Leads screen). |

## Known limitations

- **Skip is permanent.** There is currently no "unskip" — once skipped, a number never
  prompts again unless app data is cleared.
- **Reinstall/new device resets the window.** Any calls before that point that were never
  handled are unreachable afterward.
- **No background execution guarantee.** Relies on the OS keeping the process alive plus a
  catch-up sync on next open; if the device also prunes old call-log entries before you
  reopen the app, those calls are gone at the OS level, outside the app's control.
- **Permanent API failures loop silently.** A non-recoverable error (e.g. bad number
  format) leaves a number retried on every sync with no visible error beyond a debug log.
- **Connectivity probe can false-negative** on networks that block the DNS lookup host
  even when the real API is reachable, which disables Send Lead unnecessarily.
