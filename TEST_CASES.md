# Call Log Fetch — Test Cases

Legend: ✅ Implemented &nbsp;|&nbsp; ❌ Not Implemented

---

## 1. Permissions

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 1.1 | App requests phone permission on first launch | ✅ | `Permission.phone.request()` via `permission_handler` |
| 1.2 | User taps **Deny** once → "Grant Permission" button shown | ✅ | `_ScreenState.permissionDenied` |
| 1.3 | User taps **Deny + Don't ask again** → "Open App Settings" button shown | ✅ | `_ScreenState.permissionPermanentlyDenied` |
| 1.4 | User returns from App Settings → app re-fetches automatically | ✅ | `AppLifecycleState.resumed` triggers reload |
| 1.5 | Android 9+ `READ_CALL_LOG` denied → `SecurityException` caught → redirected to Settings screen | ✅ | `PlatformException` message parsed for `securityexception` / `read_call_log` |
| 1.6 | Permission granted mid-session then revoked by system → handled gracefully | ❌ | Would need a periodic permission re-check or `ContentObserver` |
| 1.7 | `isRestricted` status (parental controls) treated same as denied | ✅ | `status.isRestricted` check included |

---

## 2. Call Log Loading

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 2.1 | Call logs fetch on app launch | ✅ | Called in `initState` |
| 2.2 | Loading spinner shown while fetching | ✅ | `_ScreenState.loading` → `_LoadingView` |
| 2.3 | `PlatformException` caught and error message displayed | ✅ | Separate catch block |
| 2.4 | `MissingPluginException` caught and friendly message displayed | ✅ | Separate catch block |
| 2.5 | Any other generic exception caught and displayed | ✅ | Catch-all `catch (e)` block |
| 2.6 | Empty call log shows empty state screen | ✅ | `_ScreenState.empty` |
| 2.7 | Non-Android platform (iOS / Web / Desktop) shows "Android Only" screen | ✅ | `Platform.isAndroid` check |
| 2.8 | `mounted` checked before every `setState` after async operations | ✅ | All async paths include `if (!mounted) return` |
| 2.9 | Widget disposed during a fetch — no setState called on dead widget | ✅ | `mounted` guards throughout |
| 2.10 | Pagination / lazy loading for devices with very large call history | ❌ | All entries loaded at once via `CallLog.get()` |
| 2.11 | Loading timeout — show error if fetch hangs | ❌ | No timeout on `CallLog.get()` |

---

## 3. UI / Display

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 3.1 | Incoming call → green ↙ icon | ✅ | `CallType.incoming` |
| 3.2 | Outgoing call → blue ↗ icon | ✅ | `CallType.outgoing` |
| 3.3 | Missed call → red ↙ missed icon | ✅ | `CallType.missed` |
| 3.4 | Rejected call → orange call-end icon | ✅ | `CallType.rejected` |
| 3.5 | Blocked call → grey block icon | ✅ | `CallType.blocked` |
| 3.6 | Voicemail → purple voicemail icon | ✅ | `CallType.voiceMail` |
| 3.7 | WiFi incoming / outgoing → wifi-calling icon | ✅ | `CallType.wifiIncoming / wifiOutgoing` |
| 3.8 | Unknown / unrecognised call type → default grey call icon | ✅ | `_` wildcard in switch |
| 3.9 | Contact name shown when available | ✅ | `entry.name` non-empty check |
| 3.10 | Phone number shown as title when no contact name | ✅ | Fallback to `entry.number` |
| 3.11 | "Unknown" shown when both name and number are null | ✅ | Final fallback string |
| 3.12 | Duration `0` or `null` → empty (not "0s") | ✅ | `seconds <= 0` guard in `_formatDuration` |
| 3.13 | Duration `< 60s` → shown as `45s` | ✅ | |
| 3.14 | Duration `>= 60s` → shown as `3m 20s` | ✅ | |
| 3.15 | Duration `>= 1h` → shown as `1h 5m` | ✅ | |
| 3.16 | Call time shown in `HH:MM` format | ✅ | `_formatTimestamp` |
| 3.17 | Long names truncated with ellipsis | ✅ | `maxLines: 1, overflow: TextOverflow.ellipsis` |
| 3.18 | Animated transition between screen states | ✅ | `AnimatedSwitcher` with 300 ms duration |
| 3.19 | Dark mode support | ❌ | No dark `ThemeData` defined |
| 3.20 | Landscape orientation layout | ❌ | No orientation-specific layout |
| 3.21 | Accessibility / large text scaling | ❌ | No `TextScaler` constraints set |

---

## 4. Date Range Filter

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 4.1 | Defaults to **today** on app launch | ✅ | `_dateRange` initialised to today–today |
| 4.2 | Date bar tap opens range picker | ✅ | `InkWell.onTap` → `_pickDate` |
| 4.3 | Calendar icon in AppBar opens range picker | ✅ | `IconButton` → `_pickDate` |
| 4.4 | Single date selected → bar shows "Today" / "Yesterday" / formatted date | ✅ | `_formatRangeLabel` |
| 4.5 | Range selected → bar shows `15 May 2025  →  18 May 2025` | ✅ | `_formatRangeLabel` |
| 4.6 | List filters instantly on range change — no re-fetch needed | ✅ | In-memory filter via `_filteredEntries` getter |
| 4.7 | "No calls for [range]" shown when filtered list is empty | ✅ | Inline empty view inside loaded state |
| 4.8 | Call count badge in date bar updates with selection | ✅ | `filtered.length` displayed |
| 4.9 | Future dates not selectable | ✅ | `lastDate: now` in `showDateRangePicker` |
| 4.10 | Up to 5 years in the past selectable | ✅ | `firstDate: DateTime(now.year - 5)` |
| 4.11 | Picker cancellation handled (no crash, range unchanged) | ✅ | `if (picked != null)` guard |
| 4.12 | "Reset to Today" quick button | ❌ | No shortcut to reset range |
| 4.13 | Quick range chips: Last 7 days / Last 30 days / This month | ❌ | Not implemented |

---

## 5. Pull-to-Refresh & Manual Refresh

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 5.1 | Pull-down gesture re-fetches call logs | ✅ | `RefreshIndicator` wraps the list |
| 5.2 | Refresh icon (↺) in AppBar re-fetches | ✅ | `IconButton` → `_loadCallLogs` |
| 5.3 | Refresh icon only visible when logs are loaded or empty | ✅ | Conditional on `isLoaded \|\| empty` state |
| 5.4 | Loading state prevents duplicate concurrent fetches | ✅ | `setState(loading)` at top of `_loadCallLogs` |

---

## 6. Auto-Refresh / Lifecycle

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 6.1 | App re-fetches when returned from background | ✅ | `didChangeAppLifecycleState` |
| 6.2 | Deleted call disappears after user returns to app | ✅ | Resume triggers full reload |
| 6.3 | New call appears after user returns to app | ✅ | Resume triggers full reload |
| 6.4 | `WidgetsBindingObserver` removed on `dispose` | ✅ | `dispose` calls `removeObserver` |
| 6.5 | Resume re-fetch skipped when already loading / in error / permission state | ✅ | Guard: `_state == loaded \|\| empty` |
| 6.6 | Real-time update while app is in foreground (e.g. call ends) | ❌ | Needs native `ContentObserver` via `EventChannel` |

---

## 7. Excel Export

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 7.1 | Download button only visible when logs are loaded | ✅ | Conditional on `isLoaded` |
| 7.2 | Download button replaced by spinner while exporting | ✅ | `_isExporting` flag |
| 7.3 | Snackbar shown when selected range has no logs | ✅ | Empty guard before export |
| 7.4 | Excel workbook created with sheet named "Call Logs" | ✅ | Default sheet cleaned up |
| 7.5 | Header row bold | ✅ | `CellStyle(bold: true)` |
| 7.6 | All 7 columns present: #, Name, Number, Type, Date, Time, Duration | ✅ | |
| 7.7 | Unknown contacts exported as "Unknown" | ✅ | |
| 7.8 | File named with date tag: `call_log_18_05_2025.xlsx` | ✅ | `_rangeFileTag` |
| 7.9 | Range file named: `call_log_15_05_2025_to_18_05_2025.xlsx` | ✅ | `_rangeFileTag` |
| 7.10 | Android Share Sheet opens to save / share the file | ✅ | `Share.shareXFiles` |
| 7.11 | Export error displayed in snackbar | ✅ | `catch (e)` in `_exportToExcel` |
| 7.12 | `_isExporting` reset in `finally` even when export fails | ✅ | `finally` block |
| 7.13 | Null bytes / empty file detected and rejected with error | ✅ | `bytes == null \|\| bytes.isEmpty` check |
| 7.14 | Column auto-width sizing in Excel | ❌ | `excel` package requires manual column width |
| 7.15 | Summary / total row at bottom of sheet | ❌ | Not implemented |
| 7.16 | Direct save to Downloads folder (skip share sheet) | ❌ | Would need `MediaStore` API |
| 7.17 | Export progress indicator for large datasets | ❌ | Spinner only; no row-by-row progress |

---

## 8. Edge Cases

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 8.1 | Entry with null `timestamp` excluded from filtered list | ✅ | `if (e.timestamp == null) return false` |
| 8.2 | Entry with null `number` displays gracefully | ✅ | `entry.number ?? ''` fallbacks |
| 8.3 | Entry with null `name` displays gracefully | ✅ | `entry.name?.isNotEmpty` guard |
| 8.4 | Entry with null `duration` shows no duration text | ✅ | `_formatDuration(null)` returns `''` |
| 8.5 | Entry with null `callType` shows default icon | ✅ | `_` wildcard in switch |
| 8.6 | Very long phone number display | ❌ | No max-length truncation on number |
| 8.7 | International number formatting (+1, +44, etc.) | ❌ | Numbers displayed as-is from device |
| 8.8 | Duplicate entries (same number + timestamp) displayed without crashing | ✅ | No de-duplication logic — both shown |

---

## 9. Platform & Build

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 9.1 | Android 5.0 – 8.1 (API 21–27) — full permission flow works | ✅ | `minSdk = 21`, phone permission covers call log |
| 9.2 | Android 9+ (API 28+) — SecurityException routed to Settings screen | ✅ | `PlatformException` detection |
| 9.3 | iOS — "Android Only" screen shown | ✅ | `Platform.isAndroid` check |
| 9.4 | Web / Desktop — "Android Only" screen shown | ✅ | `Platform.isAndroid` check |
| 9.5 | AGP 8.x namespace conflict resolved for `call_log` plugin | ✅ | `plugins.withId` hook in root `build.gradle.kts` |
| 9.6 | Tablet / large screen layout | ❌ | No adaptive layout for wide screens |

---

## Summary

| Category | Total | ✅ Implemented | ❌ Not Implemented |
|----------|-------|----------------|-------------------|
| Permissions | 7 | 6 | 1 |
| Call Log Loading | 11 | 9 | 2 |
| UI / Display | 21 | 18 | 3 |
| Date Range Filter | 13 | 11 | 2 |
| Pull-to-Refresh | 4 | 4 | 0 |
| Auto-Refresh / Lifecycle | 6 | 5 | 1 |
| Excel Export | 17 | 13 | 4 |
| Edge Cases | 8 | 6 | 2 |
| Platform & Build | 6 | 5 | 1 |
| **Total** | **93** | **77** | **16** |

---

## 10. Which Calls Are SEEN (Displayed in List)

> These test cases verify exactly which call log entries appear on screen under different conditions.

### 10.1 — By Call Type

| # | Call Type | Expected in List | Status | Actual Label / Icon |
|---|-----------|-----------------|--------|---------------------|
| 10.1.1 | Incoming | ✅ Shown | ✅ | "Incoming" · Green ↙ icon |
| 10.1.2 | Outgoing | ✅ Shown | ✅ | "Outgoing" · Blue ↗ icon |
| 10.1.3 | Missed | ✅ Shown | ✅ | "Missed" · Red ↙ missed icon |
| 10.1.4 | Rejected | ✅ Shown | ✅ | "Rejected" · Orange call-end icon |
| 10.1.5 | Blocked | ✅ Shown | ✅ | "Blocked" · Grey block icon |
| 10.1.6 | Voicemail | ✅ Shown | ✅ | "Voicemail" · Purple voicemail icon |
| 10.1.7 | WiFi Incoming | ✅ Shown | ✅ | "WiFi Incoming" · Green wifi icon |
| 10.1.8 | WiFi Outgoing | ✅ Shown | ✅ | "WiFi Outgoing" · Blue wifi icon |
| 10.1.9 | Unknown / unrecognised type | ✅ Shown | ✅ | "Unknown" · Grey call icon |
| 10.1.10 | `null` call type | ✅ Shown | ✅ | Falls to `_` wildcard — grey call icon |

> **All call types are shown.** There is no call-type filter; the list shows everything returned by `CallLog.get()`.

---

### 10.2 — By Date Range Boundary

> Filter logic in code:
> ```dart
> final rangeEnd = DateTime(end.year, end.month, end.day + 1); // midnight next day
> !dt.isBefore(rangeStart) && dt.isBefore(rangeEnd)
> ```
> Dart normalises overflow days automatically (e.g. March 32 → April 1).

| # | Call Timestamp | Range Selected | Expected | Status |
|---|----------------|----------------|----------|--------|
| 10.2.1 | `00:00:00.000` on **start date** | Same day | ✅ Shown | ✅ |
| 10.2.2 | `00:00:01` on **start date** | Same day | ✅ Shown | ✅ |
| 10.2.3 | `23:59:59.999` on **end date** | Same day | ✅ Shown | ✅ |
| 10.2.4 | `00:00:00.000` on **day after end date** | Any | ❌ Not shown | ✅ |
| 10.2.5 | `23:59:59.999` on **day before start date** | Any | ❌ Not shown | ✅ |
| 10.2.6 | Call on **31 Dec** (year boundary) as end date | Dec 31 | ✅ Shown | ✅ (Dart normalises day+1 to Jan 1) |
| 10.2.7 | Call on **last day of month** (e.g. Mar 31) as end date | Mar 31 | ✅ Shown | ✅ (day+1 → Apr 1) |
| 10.2.8 | Call within a **multi-day range** (start ≠ end) | e.g. May 1–May 5 | ✅ Shown | ✅ |
| 10.2.9 | Call **outside** a multi-day range | e.g. Apr 30 when range is May 1–5 | ❌ Not shown | ✅ |
| 10.2.10 | Call with **null timestamp** | Any | ❌ Not shown | ✅ (explicit null check) |

---

### 10.3 — By Contact / Number Data

| # | Scenario | What Is Shown as Title | Status |
|---|----------|----------------------|--------|
| 10.3.1 | Contact name available | Contact name (bold) | ✅ |
| 10.3.2 | No contact name, number available | Phone number (bold) | ✅ |
| 10.3.3 | No contact name, no number (`null`) | "Unknown" (bold) | ✅ |
| 10.3.4 | Contact name available + number shown as subtitle | Name (title) · Number (subtitle) | ✅ |
| 10.3.5 | No contact name — number shown only as title, no subtitle | Number as title, no subtitle row | ✅ |
| 10.3.6 | Same number called multiple times | Each call shown as a separate row | ✅ |
| 10.3.7 | Private / hidden number (`null` number, `null` name) | "Unknown" | ✅ |

---

### 10.4 — Calls NOT Seen (Exclusion Rules)

| # | Reason for Exclusion | Status |
|---|----------------------|--------|
| 10.4.1 | Call outside selected date range | ✅ Correctly excluded |
| 10.4.2 | Call with `null` timestamp | ✅ Correctly excluded |
| 10.4.3 | Call log not loaded yet (loading state) | ✅ List not shown — spinner displayed |
| 10.4.4 | Permission not granted | ✅ List not shown — permission screen displayed |
| 10.4.5 | Call type is a **future enum value** not in switch | ✅ Shows with grey default icon (not hidden) |
| 10.4.6 | Server-side / custom filtering by call type | ❌ Not implemented — no type filter in app |
| 10.4.7 | Calls older than 5 years (date picker limit) | ❌ Still shown in list; limit only applies to picker |

---

## 11. Which Calls Are STORED (Exported to Excel)

> These test cases verify which entries go into the `.xlsx` file and what data is written per row.

### 11.1 — Which Calls Are Exported

| # | Scenario | Exported? | Status |
|---|----------|-----------|--------|
| 11.1.1 | Call **within** selected date range | ✅ Yes | ✅ |
| 11.1.2 | Call **outside** selected date range | ❌ No | ✅ |
| 11.1.3 | Call with `null` timestamp | ❌ No | ✅ (excluded by `_filteredEntries`) |
| 11.1.4 | **All call types** (incoming, outgoing, missed…) | ✅ Yes — no type filter | ✅ |
| 11.1.5 | Export triggered when **0 calls** in range | ❌ No — snackbar shown instead | ✅ |
| 11.1.6 | **Exact same calls** that are visible in list | ✅ Yes — uses same `_filteredEntries` | ✅ |
| 11.1.7 | Calls **not currently visible** (different date range) | ❌ No | ✅ |

---

### 11.2 — What Data Is Stored Per Row

| # | Column | Source Field | Stored Value When Null / Empty | Status |
|---|--------|-------------|-------------------------------|--------|
| 11.2.1 | `#` (row number) | Counter starting at 1 | — | ✅ |
| 11.2.2 | `Name` | `entry.name` | `"Unknown"` | ✅ |
| 11.2.3 | `Number` | `entry.number` | `""` (empty) | ✅ |
| 11.2.4 | `Call Type` | `entry.callType` | `"Unknown"` | ✅ |
| 11.2.5 | `Date` | `entry.timestamp` | `""` (empty) | ✅ |
| 11.2.6 | `Time` | `entry.timestamp` | `""` (empty) | ✅ |
| 11.2.7 | `Duration` | `entry.duration` | `""` (empty, not "0s") | ✅ |

---

### 11.3 — Data Format in Excel

| # | Field | Format | Example | Status |
|---|-------|--------|---------|--------|
| 11.3.1 | Date | `DD/MM/YYYY` | `18/05/2025` | ✅ |
| 11.3.2 | Time | `HH:MM` (24-hour) | `14:32` | ✅ |
| 11.3.3 | Duration < 60s | `Xs` | `45s` | ✅ |
| 11.3.4 | Duration 60s – 3599s | `Xm Ys` | `3m 20s` | ✅ |
| 11.3.5 | Duration ≥ 3600s | `Xh Ym` | `1h 5m` | ✅ |
| 11.3.6 | Duration = 0 or null | `""` (blank cell) | | ✅ |
| 11.3.7 | Call Type label | Human-readable string | `Incoming`, `Missed` | ✅ |
| 11.3.8 | Header row | Bold | Row 1 of sheet | ✅ |
| 11.3.9 | Sheet name | `Call Logs` | | ✅ |
| 11.3.10 | Row order | Same as list order (most recent first) | | ✅ |
| 11.3.11 | Column widths auto-sized | — | — | ❌ Not implemented |
| 11.3.12 | Summary / total row at bottom | — | — | ❌ Not implemented |

---

### 11.4 — File Naming

| # | Date Range Selected | File Name | Status |
|---|---------------------|-----------|--------|
| 11.4.1 | Single day (e.g. 18 May 2025) | `call_log_18_05_2025.xlsx` | ✅ |
| 11.4.2 | Range (e.g. 15 May – 18 May 2025) | `call_log_15_05_2025_to_18_05_2025.xlsx` | ✅ |
| 11.4.3 | Single day = today | `call_log_18_05_2025.xlsx` (not `call_log_today.xlsx`) | ✅ |

---

## Updated Summary

| Category | Total | ✅ Implemented | ❌ Not Implemented |
|----------|-------|----------------|-------------------|
| Permissions | 7 | 6 | 1 |
| Call Log Loading | 11 | 9 | 2 |
| UI / Display | 21 | 18 | 3 |
| Date Range Filter | 13 | 11 | 2 |
| Pull-to-Refresh | 4 | 4 | 0 |
| Auto-Refresh / Lifecycle | 6 | 5 | 1 |
| Excel Export | 17 | 13 | 4 |
| Edge Cases | 8 | 6 | 2 |
| Platform & Build | 6 | 5 | 1 |
| **Call Visibility (SEEN)** | **21** | **18** | **3** |
| **Call Storage (STORED)** | **19** | **17** | **2** |
| **Total** | **133** | **112** | **21** |
