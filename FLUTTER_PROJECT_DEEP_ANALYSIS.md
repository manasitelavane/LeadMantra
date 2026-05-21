# LeadMantraCRM — Complete Flutter Project Deep Analysis

---

## Table of Contents

1. [Folder Structure](#folder-structure)
2. [Architecture Pattern](#architecture-pattern)
3. [Overall Data Flow](#overall-data-flow)
4. [pubspec.yaml](#pubspecyaml)
5. [main.dart](#maindart)
6. [app/app.dart](#appappdart)
7. [core/api_endpoints.dart](#coreapi_endpointsdart)
8. [core/app_config.dart](#coreapp_configdart)
9. [core/navigator_key.dart](#corenavigator_keydart)
10. [core/theme.dart](#corethemedart)
11. [models/stored_call_entry.dart](#modelsstored_call_entrydart)
12. [services/auth_service.dart](#servicesauth_servicedart)
13. [services/api_service.dart](#servicesapi_servicedart)
14. [services/lead_sync_service.dart](#serviceslead_sync_servicedart)
15. [screens/login_screen.dart](#screenslogin_screendart)
16. [screens/dashboard_screen.dart](#screensdashboard_screendart)
17. [screens/call_log_screen.dart](#screenscall_log_screendart)
18. [screens/delete_account_screen.dart](#screensdelete_account_screendart)
19. [widgets/call_log_tile.dart](#widgetscall_log_tiledart)
20. [widgets/lead_confirm_dialog.dart](#widgetslead_confirm_dialogdart)
21. [MainActivity.kt](#mainactivitykt)
22. [AndroidManifest.xml](#androidmanifestxml)
23. [build.gradle.kts](#buildgradlekts)
24. [State Management Analysis](#state-management-analysis)
25. [API & Networking Analysis](#api--networking-analysis)
26. [Architecture Review](#architecture-review)
27. [Performance Review](#performance-review)
28. [Code Quality Review](#code-quality-review)

---

# Folder Structure

```
call_log_fetch/
├── android/
│   └── app/
│       ├── build.gradle.kts          ← Android build config
│       └── src/main/
│           ├── AndroidManifest.xml   ← App permissions & components
│           └── kotlin/com/leadmantracrm/app/
│               └── MainActivity.kt  ← Native Android bridge
├── assets/
│   └── images/
│       ├── logo_1 1.png             ← Hero/splash logo
│       ├── logo_2 1.png             ← AppBar logo
│       └── logo_3 1.png             ← Launcher icon
├── lib/
│   ├── main.dart                    ← App entry point
│   ├── app/
│   │   └── app.dart                 ← Root widget + routing + splash
│   ├── core/
│   │   ├── api_endpoints.dart       ← All API URLs in one place
│   │   ├── app_config.dart          ← Debug flags + snackbar utility
│   │   ├── navigator_key.dart       ← Global navigation key
│   │   └── theme.dart               ← App colors + ThemeData
│   ├── models/
│   │   └── stored_call_entry.dart   ← Data model for a call log entry
│   ├── screens/
│   │   ├── login_screen.dart        ← Login UI
│   │   ├── dashboard_screen.dart    ← Main dashboard UI
│   │   ├── call_log_screen.dart     ← Full call log viewer
│   │   ├── delete_account_screen.dart ← Account deletion UI
│   │   └── privacy_policy_screen.dart ← Privacy policy + consent
│   ├── services/
│   │   ├── auth_service.dart        ← Login / logout / token management
│   │   ├── api_service.dart         ← HTTP calls to backend
│   │   └── lead_sync_service.dart   ← Call monitoring + lead capture logic
│   ├── utils/
│   │   └── call_log_utils.dart      ← Duration, timestamp, label formatters
│   └── widgets/
│       ├── call_log_tile.dart       ← Single call row UI
│       ├── lead_confirm_dialog.dart ← Lead confirmation popup
│       ├── action_view.dart         ← Empty/error/permission state UI
│       └── loading_view.dart        ← Loading spinner UI
└── pubspec.yaml                     ← Dependencies + assets
```

### Why is it separated this way?

Each folder has a single, clear responsibility:

- **core/** — Things that are shared everywhere and have no business logic. Colors, URLs, keys. If any screen or service needs a URL, it comes from here. Nobody hardcodes a URL directly.
- **models/** — Pure data. No UI. No network. Just the shape of what a call entry looks like.
- **services/** — Business logic and network calls. No UI. Services don't know what a widget is. They are singletons that any screen can call.
- **screens/** — Full pages. Each screen owns its own UI and calls services. Screens do not call other screens' internal methods.
- **widgets/** — Reusable pieces of UI that are too small to be screens but too complex to write inline. Used by multiple screens.
- **utils/** — Pure functions. Take an input, return a formatted output. No state, no network, no UI.

This separation is called **Separation of Concerns**. A senior developer follows this so that: (1) any file can be found in 3 seconds; (2) changing one layer does not break another; (3) each file can be tested independently.

---

# Architecture Pattern

This project follows a **lightweight layered architecture**:

```
┌────────────────────────────────────────┐
│              SCREENS (UI Layer)         │
│  login  dashboard  calllog  delete      │
└──────────────┬─────────────────────────┘
               │ calls
┌──────────────▼─────────────────────────┐
│            SERVICES (Logic Layer)       │
│  AuthService  ApiService  LeadSync      │
└──────────────┬─────────────────────────┘
               │ uses
┌──────────────▼─────────────────────────┐
│             CORE (Config Layer)         │
│  endpoints  theme  navigatorKey  config │
└────────────────────────────────────────┘
               │ uses
┌──────────────▼─────────────────────────┐
│            MODELS (Data Layer)          │
│          StoredCallEntry                │
└────────────────────────────────────────┘
```

It is NOT full Clean Architecture (no repository pattern, no use-case layer, no domain layer). For an app of this size — one API, one model, three screens — that would be over-engineering. The pattern chosen here is appropriate: simple, readable, and maintainable.

State management is **setState only** — no BLoC, no Provider, no Riverpod. This is correct for this app size. Adding BLoC here would be premature complexity.

---

# Overall Data Flow

```
App opens
  → main.dart: WidgetsFlutterBinding.ensureInitialized(), runApp(MyApp)
  → app.dart: MaterialApp with navigatorKey, routes, home=_Splash
  → _Splash: AuthService.loadSession()
      if token exists and is < 3 days old → DashboardScreen
      else → LoginScreen

LoginScreen
  → user enters email + password
  → AuthService.login() → POST /mobile/login
  → token saved to SharedPreferences
  → Navigator → DashboardScreen

DashboardScreen
  → LeadSyncService.start()
      loads _syncStartedAt from prefs (first ever start time)
      loads _uploadedIds from prefs
      registers EventChannel listener
  → _loadStats(): CallLog.query(today) → display stats
  → LeadSyncService.syncNow(): find calls since _syncStartedAt, show dialog, upload

Call happens on phone
  → Android ContentObserver fires
  → EventChannel sends "changed" to Flutter
  → 5-second debounce timer
  → LeadSyncService.syncNow()
  → LeadConfirmDialog shown
  → user confirms → ApiService.captureLead() → POST /call-lead/capture
```

---

# pubspec.yaml

## Purpose
Declares the app identity, version, SDK constraints, third-party packages, and asset paths. It is the project's manifest — the first file any developer reads to understand what the project depends on.

## Key Dependencies Explained

### `call_log: ^6.0.1`
Reads the Android call log. Provides `CallLog.get()` and `CallLog.query()` which return `Iterable<CallLogEntry>`. Each entry contains: number, name, duration (seconds), callType (incoming/outgoing/missed), timestamp, simDisplayName, phoneAccountId. This package communicates with Android's `READ_CALL_LOG` permission-protected content provider internally. Without this, the app cannot read any call data.

### `permission_handler: ^11.0.0`
Manages Android runtime permissions. On Android 6.0+, dangerous permissions (like reading call logs) must be explicitly requested at runtime — declaring them in AndroidManifest alone is not enough. This package provides `Permission.phone.request()` and `Permission.phone.status`.

### `http: ^1.2.0`
Makes HTTP requests. The entire REST API communication — login, capture lead, delete account — uses this package. It provides `http.post()`, `http.get()` etc. and returns `http.Response` with `statusCode` and `body`.

### `shared_preferences: ^2.3.0`
Persists key-value data to the device's internal storage. Used for: (1) storing the auth token and user JSON; (2) storing the token save timestamp; (3) storing which calls have already been uploaded (`lead_uploaded_ids`); (4) storing the first-ever service start time (`lead_sync_started_at`). Data survives app restarts and updates. It does NOT survive uninstall.

### `flutter_launcher_icons: ^0.14.0`
A dev tool that generates the app launcher icon from a source image. Run once with `flutter pub run flutter_launcher_icons`. It replaces the default Flutter icon with `logo_3 1.png`.

### `flutter_native_splash: ^2.4.0`
Generates the Android splash screen (the screen shown before Flutter initializes). Configured in pubspec to use the logo images. Run once with `flutter pub run flutter_native_splash:create`.

---

# main.dart

## Purpose
The absolute entry point of the Flutter application. Every Flutter app starts here.

## Why This File Exists
Dart requires a `main()` function as the program entry point. Flutter's `runApp()` takes the root widget and starts the rendering engine.

## Line-by-Line Explanation

```dart
WidgetsFlutterBinding.ensureInitialized();
```
This line is critically important and often misunderstood. Flutter's widget system and the underlying platform channels (used by SharedPreferences, etc.) are not ready until this is called. If you call `SharedPreferences.getInstance()` or `AuthService.loadSession()` before this line, the app will crash on some devices. `ensureInitialized()` is idempotent — calling it multiple times is safe.

```dart
runApp(const MyApp());
```
Passes the root widget to Flutter's rendering engine. From this moment, Flutter owns the screen. `const` is used because `MyApp` has no runtime-varying constructor arguments — this is a compile-time constant optimization.

## What Comes Next
After `runApp`, Flutter calls `MyApp.build()`, which returns a `MaterialApp`. The `MaterialApp` is the root of the widget tree for all subsequent screens.

---

# app/app.dart

## Purpose
Configures the entire application: theme, navigation key, route table, and the startup decision (login or dashboard).

## Class: `MyApp`

### Type: StatelessWidget
`MyApp` is stateless because it only describes the app's configuration — it never changes after construction. A stateful widget here would be wasteful since no rebuilds are ever needed at this level.

### `navigatorKey: navigatorKey`
This wires the global `NavigatorState` to `MaterialApp`. The significance: services like `AuthService` and `LeadSyncService` need to navigate or show snackbars without having a `BuildContext`. They access the context via `navigatorKey.currentContext`. Without this line, those services would have no way to show UI.

### Route Table
```dart
routes: {
  '/login':     (_) => const LoginScreen(),
  '/dashboard': (_) => const DashboardScreen(),
},
```
Named routes allow navigation from anywhere using strings: `Navigator.pushNamed(context, '/login')`. More importantly, `AuthService.handleExpiredSession()` calls `navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false)` — this only works because the routes are registered here. If routes weren't defined, named navigation would silently fail.

### `home: const _Splash()`
The `home` widget is shown first. It is NOT the login screen directly — it is a transparent splash that performs async work (loading the saved session) before deciding where to go.

---

## Class: `_Splash`

### Why It Exists
There is a timing problem: `AuthService.loadSession()` is async (reads from SharedPreferences). The app cannot know whether to show Login or Dashboard until that async call completes. The splash widget bridges this gap — it shows a loading spinner while waiting, then navigates.

### Type: StatefulWidget
Must be stateful because it triggers an async operation in `initState` and navigates away, which requires the widget to be mounted at the time of navigation.

### `_resolve()` method — Step by step:

```dart
await AuthService.instance.loadSession();
```
Waits for the stored token to be loaded from SharedPreferences into memory. This reads from disk — it is genuinely async and can take a few milliseconds on first call.

```dart
if (!mounted) return;
```
After an `await`, the widget may have been removed from the tree (e.g., hot reload, or the user pressed back). `mounted` checks if the widget is still in the tree. Without this guard, calling `Navigator.pushReplacement` on a disposed widget throws an exception.

```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => AuthService.instance.isLoggedIn
        ? const DashboardScreen()
        : const LoginScreen(),
  ),
);
```
`pushReplacement` removes the splash from the stack and replaces it with the chosen screen. The `isLoggedIn` check reads the in-memory `_token` that was just loaded. If the token is present AND not older than 3 days (checked inside `loadSession`), the user goes to Dashboard. Otherwise, Login.

### Performance Note
The splash screen that the user sees (white screen with spinner) is shown only for milliseconds on most devices because SharedPreferences reads are fast. The flutter_native_splash package handles the very first visual before Flutter initializes — that is a separate mechanism from this `_Splash` widget.

---

# core/api_endpoints.dart

## Purpose
A single source of truth for all backend URLs. No URL is ever hardcoded in a service or screen.

## Why This File Exists
Imagine the base URL changes from `leadmantracrm.com` to `api.leadmantracrm.com`. Without this file, you would need to search every service file and change URLs one by one — high risk of missing one. With this file, you change `baseUrl` in one place and every API call in the app automatically uses the new URL.

## Design Decision: Private Constructor
```dart
ApiEndpoints._();
```
The underscore makes the constructor private. This prevents anyone from doing `final e = ApiEndpoints()`. The class is not meant to be instantiated — it is a namespace for constants. A senior developer always does this for utility/constant classes.

## Constants
All constants are `static const String` — they exist at compile time, are shared across all instances (though no instances are created), and never change at runtime. The Dart compiler inlines these constants, meaning zero runtime cost.

---

# core/app_config.dart

## Purpose
Two things: (1) a feature flag to toggle debug API snackbars; (2) the implementation of showing those snackbars.

## `kShowApiSnackbar`
```dart
const bool kShowApiSnackbar = true;
```
The `k` prefix is a Dart convention for constants (from Google's style guide). Set to `true` during development — every API call shows a snackbar. Set to `false` before Play Store release. The `const` means the Dart compiler can eliminate dead code — when `false`, `if (!kShowApiSnackbar) return;` makes the compiler skip the entire snackbar logic in release builds.

## `showApiSnackbar()` — Step by step

```dart
if (!kShowApiSnackbar) return;
```
Early exit if disabled. Nothing else runs.

```dart
final ctx = navigatorKey.currentContext;
if (ctx == null) return;
```
Gets the current BuildContext from the global key. Can be null if the app is not showing any screen yet (e.g., during startup). Null check prevents crash.

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
```
This is an important pattern. You cannot show a SnackBar in the middle of a build pass — Flutter will throw "setState called during build". `addPostFrameCallback` defers the snackbar to after the current frame completes. This is the correct way to trigger UI from async/service code.

```dart
ScaffoldMessenger.of(ctx).clearSnackBars();
ScaffoldMessenger.of(ctx).showSnackBar(...);
```
`clearSnackBars()` removes any currently visible snackbar before showing the new one. Without this, API calls that happen rapidly would queue up snackbars and they would stack visually.

---

# core/navigator_key.dart

## Purpose
Provides a single, globally-accessible `GlobalKey<NavigatorState>` that allows any code — even code that has no `BuildContext` — to perform navigation and access the current context.

## Why This File Exists
Normal Flutter navigation requires a `BuildContext`: `Navigator.of(context).push(...)`. Services like `AuthService` and `LeadSyncService` run outside the widget tree — they have no `context`. The `navigatorKey` solves this by giving access to the navigator from anywhere.

## How It Works
`GlobalKey<NavigatorState>` is registered in `MaterialApp(navigatorKey: navigatorKey)`. From that moment, `navigatorKey.currentState` is the active `NavigatorState`, and `navigatorKey.currentContext` is the BuildContext of the root navigator. Both can be accessed from any Dart file that imports this file.

## Real-World Usage in This Project
1. `AuthService.handleExpiredSession()` calls `navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false)` — redirects to login from a service with no context.
2. `showApiSnackbar()` uses `navigatorKey.currentContext` — shows a snackbar from a utility function with no context.
3. `LeadSyncService._showConfirmDialog()` uses `navigatorKey.currentContext` — shows a dialog from a background service.

---

# core/theme.dart

## Purpose
Defines the entire visual language of the app — colors, typography defaults, component themes — in one file.

## Color Palette
```dart
static const Color primary        = Color(0xFF1A237E); // Deep navy blue
static const Color primaryVariant = Color(0xFF283593); // Slightly lighter navy
static const Color accent         = Color(0xFFF57C00); // Orange
static const Color accentLight    = Color(0xFFFFF3E0); // Very light orange tint
static const Color appBarBg       = Colors.white;
static const Color appBarFg       = Color(0xFF1A237E); // Navy text on white bar
```
These are `static const` — they are compile-time constants shared by the entire app. Any widget can access `AppTheme.primary` without importing anything beyond this file.

## `AppTheme.light()` — ThemeData construction

### `useMaterial3: true`
Opts into Material Design 3, the latest design system from Google (2022+). This changes the appearance of buttons, chips, dialogs, and input fields.

### AppBar Theme
```dart
appBarTheme: const AppBarTheme(
  backgroundColor: appBarBg,   // White
  elevation: 0,                // No shadow
  scrolledUnderElevation: 0,   // No shadow when content scrolls under it
  centerTitle: true,
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ),
)
```
`scrolledUnderElevation: 0` prevents the common "app bar gets a shadow when you scroll" behavior that many apps accidentally leave on. `systemOverlayStyle` with `Brightness.dark` makes the status bar icons (battery, wifi, time) black — appropriate for a white app bar.

### Card Theme
`elevation: 0` and `margin: EdgeInsets.zero` means cards have no shadow and no default margin. Individual cards in the app add their own shadows via `boxShadow` on `Container` — this gives more control than the theme default.

---

# models/stored_call_entry.dart

## Purpose
The data model that represents a single phone call. This is the common language between the call_log package, the UI, and serialization.

## Why This File Exists
The `call_log` package returns `CallLogEntry` objects. But `CallLogEntry` is a third-party class — the project cannot add methods to it, cannot serialize it to JSON, and cannot customize its field names. `StoredCallEntry` is the project's own class that wraps and normalizes the data.

## Fields Explained

| Field | Type | Purpose |
|---|---|---|
| `id` | `int?` | Database ID if stored server-side |
| `deviceId` | `String?` | Which device this came from |
| `callId` | `String` | Unique ID: `"timestamp_number_calltype"` |
| `name` | `String?` | Contact name, null if unknown |
| `number` | `String?` | Phone number |
| `callType` | `String` | `"incoming"`, `"outgoing"`, `"missed"` |
| `timestamp` | `int` | Unix milliseconds when call happened |
| `duration` | `int` | Call duration in seconds |
| `syncedAt` | `int` | When this entry was created in the app |
| `phoneAccountId` | `String?` | Raw SIM account identifier |
| `simDisplayName` | `String?` | Human-readable SIM name ("SIM 1") |

## `callId` Design
```dart
callId: '${ts}_${num}_$type'
```
This is a composite key that uniquely identifies a call. The combination of timestamp + phone number + call type is unique for any real call. This ID is used by `LeadSyncService` to track which calls have been uploaded (`_uploadedIds`).

## Factory Constructor `fromCallLogEntry`
Converts a third-party `CallLogEntry` into a `StoredCallEntry`. Handles nulls defensively: `e.timestamp ?? DateTime.now().millisecondsSinceEpoch` ensures the field is never null even if the platform returns null.

## Factory Constructor `fromJson`
Used for deserializing JSON (e.g., from an API response or local storage). Uses safe casting: `(json['timestamp'] as num?)?.toInt() ?? 0` handles both `int` and `double` JSON numbers, which is a common source of crashes when the server returns `1234567890.0` instead of `1234567890`.

## `toJson()`
Used to serialize the entry for storage or API transmission. Returns a plain `Map<String, dynamic>`.

---

# services/auth_service.dart

## Purpose
The single source of truth for everything authentication-related: login, logout, session persistence, token age checking, and handling expired tokens.

## Why a Singleton?
```dart
AuthService._();
static final AuthService instance = AuthService._();
```
The Dart singleton pattern with a private constructor. There is only ever ONE `AuthService` in the entire app. Every screen and service that needs the token calls `AuthService.instance.token` — they all read from the same in-memory `_token` field. If each screen created its own `AuthService`, they would each have separate state — tokens would not be shared. The singleton guarantees consistency.

## State Fields
```dart
String?   _token;   // The Bearer token for API calls
AuthUser? _user;    // The logged-in user's details
```
Both are private (underscore prefix). They can only be modified through `AuthService`'s own methods. Screens read them through the getters `token` and `user`. This is **encapsulation** — the token cannot be accidentally overwritten from a screen.

## `isLoggedIn`
```dart
bool get isLoggedIn => _token != null;
```
A computed getter — not a stored field. Its value is derived from `_token` every time it is read. This means it is always accurate: the moment `_token` is set to null (on logout), `isLoggedIn` immediately returns false everywhere in the app.

## `loadSession()` — Step by step

```dart
final savedAt = prefs.getInt(_kSavedAt) ?? 0;
```
Reads the Unix timestamp (milliseconds) of when the token was last saved. If never saved, defaults to 0 (epoch, year 1970), which guarantees the age check will clear it.

```dart
final ageDays = DateTime.now()
    .difference(DateTime.fromMillisecondsSinceEpoch(savedAt))
    .inDays;
if (ageDays >= _kMaxAgeDays) { // 3 days
  await prefs.remove(_kToken);
  ...
  return;
}
```
The backend token expires every 3-4 days. Rather than waiting for a 401 to discover the token is expired (which causes a jarring mid-session redirect), we proactively check the age at startup. If the stored token is 3+ days old, we throw it away and the splash screen routes to Login. The user is redirected at the natural startup moment, not in the middle of using the app.

```dart
_token = savedToken.trim();
```
`.trim()` removes any invisible whitespace characters (spaces, newlines, carriage returns) that may have been captured when parsing the JSON API response. A token with a trailing newline would be "present" but would cause `401 Missing or malformed Authorization header` because the HTTP header value would be `Bearer abc123\n` instead of `Bearer abc123`.

## `login()` — Step by step

```dart
final loginSuccess = res.statusCode == 200 && json['success'] == true;
```
Both conditions must be true. A `200 OK` with `{"success": false}` in the body (which some APIs return for business-logic failures) would correctly not be treated as success.

```dart
_token = (json['token'] as String?)?.trim();
await prefs.setString(_kToken, _token!);
await prefs.setInt(_kSavedAt, DateTime.now().millisecondsSinceEpoch);
```
Token is trimmed immediately on receipt. Save timestamp is recorded so `loadSession` can check age on next startup.

## `handleExpiredSession({bool redirect = true})`

```dart
Future<void> handleExpiredSession({bool redirect = true}) async {
```
The `redirect` parameter defaults to `true` for backwards compatibility. Called with `redirect: false` from `ApiService.captureLead` (background sync) so the user is NOT kicked to login mid-session when a call capture fails. Called with `redirect: true` (default) for any user-triggered action.

The `WidgetsBinding.instance.addPostFrameCallback` ensures the snackbar is shown after the current frame — needed because this method may be called from inside an async API callback which itself may be called from within a build cycle.

## `deleteAccount()` — Step by step

```dart
final userId = _user?.id;
if (userId == null || _token == null) return const AuthResult.fail('Not logged in.');
```
Guards against being called when not logged in. The `?.` operator safely handles null user.

```dart
body: jsonEncode({'user_id': userId}),
```
Sends the user ID in the request body because the backend needs to know which account to delete. The Bearer token alone identifies the session, but the body explicitly confirms the account.

```dart
if (deleteSuccess) {
  await logout();  // Clears token and user from memory AND SharedPreferences
  return const AuthResult.ok();
}
```
Logout happens AFTER the API confirms deletion. If logout happened first and the API call then failed, the user would be logged out with no account deleted — a confusing state.

---

# services/api_service.dart

## Purpose
A thin HTTP wrapper specifically for the `captureLead` API endpoint.

## Why a Separate Class?
All network concerns — building headers, encoding the body, handling status codes, timeouts — live here. If the lead capture API URL changes or the request format changes, only this file needs modification. Screens and services that call `captureLead` are shielded from these details.

## `captureLead()` — Step by step

```dart
final http.Client _client;
ApiService({http.Client? client}) : _client = client ?? http.Client();
```
The `_client` field and constructor injection exist for testability. In production, `http.Client()` is used. In tests, a mock client can be injected. This is the **Dependency Injection** pattern.

```dart
headers: {
  'Content-Type':  'application/json',
  'Authorization': 'Bearer ${AuthService.instance.token ?? ''}',
},
```
`Content-Type: application/json` tells the server the body is JSON. `Authorization: Bearer <token>` is the standard JWT Bearer token authentication scheme. The `?? ''` handles null token (though `syncNow` checks `isLoggedIn` before calling this, so the token should never actually be null here).

```dart
.timeout(_timeout)
```
A 30-second timeout. Without this, a request to an unreachable server would hang forever, blocking the sync loop indefinitely. After 30 seconds, a `TimeoutException` is thrown and caught by the outer `catch`.

```dart
if (res.statusCode == 401) {
  AuthService.instance.handleExpiredSession(redirect: false);
  return null;
}
```
401 from a background sync → silent logout, user stays on dashboard. The `redirect: false` is the key difference. The user sees a snackbar "Session expired. Tap menu to log in again." but is not forcefully navigated away.

```dart
showApiSnackbar('POST /call-lead/capture', res.statusCode,
    success: res.statusCode == 200);
```
Shows the debug snackbar for every response. The endpoint name is a friendly label for the developer, not the full URL. `success: res.statusCode == 200` makes the snackbar green on 200 and red on anything else.

---

# services/lead_sync_service.dart

## Purpose
The core business logic of the app. Monitors the Android call log for changes, shows confirmation dialogs to the user, and sends qualifying calls to the backend as leads.

## Why a Singleton?
```dart
LeadSyncService._();
static final LeadSyncService instance = LeadSyncService._();
```
The singleton must persist across screen navigations. When the user navigates from Dashboard to CallLogScreen and back, the EventChannel listener and the `_syncStartedAt` timestamp must not be reset. A new instance each time would lose all state.

## Key State Fields

```dart
Set<String> _uploadedIds = {};
```
In-memory set of call IDs that have been "handled" (either uploaded or skipped by user). Persisted to SharedPreferences so it survives app restarts.

```dart
DateTime? _syncStartedAt;
```
The timestamp of the very first time `start()` was ever called (first install). Persisted to SharedPreferences. Calls before this moment are never captured — they are the user's historical call history and not new leads.

## `start()` — Step by step

```dart
final savedMs = prefs.getInt(_kSyncStartedAt);
if (savedMs == null) {
  _syncStartedAt = DateTime.now();
  await prefs.setInt(_kSyncStartedAt, _syncStartedAt!.millisecondsSinceEpoch);
} else {
  _syncStartedAt = DateTime.fromMillisecondsSinceEpoch(savedMs);
}
```
First-ever call: records `DateTime.now()` as the cutoff point. All subsequent calls: loads the saved timestamp. `??=` is NOT used here because we need to both check and persist — the explicit `if` makes this clearer.

```dart
final saved = prefs.getStringList(_kUploadedIds) ?? [];
_uploadedIds = saved.toSet();
```
Restores the set of handled calls. Converting list to Set gives O(1) lookup performance — `_uploadedIds.contains(id)` is instant regardless of how many entries there are.

```dart
_sub ??= _kEventChannel.receiveBroadcastStream().listen(...)
```
`??=` assigns only if `_sub` is currently null. This prevents double-registration if `start()` is called multiple times (e.g., user navigates to settings and back). A second listener registration would mean every call triggers the sync twice.

## EventChannel + Debounce Pattern

```dart
_sub ??= _kEventChannel.receiveBroadcastStream().listen(
  (_) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), syncNow);
  },
```
When Android's ContentObserver detects a change in the call log, it fires immediately. But a single phone call can cause multiple ContentObserver events (ringing starts, ringing stops, call answered, call ended — each updates the call log). Without debouncing, `syncNow()` would be called multiple times for one call, and the dialog would appear multiple times.

The debounce pattern: cancel any pending timer, start a fresh 5-second timer. Only after 5 seconds of silence does `syncNow()` actually run. By that time, the call is fully recorded in the call log.

## `stop()` — What it does and does NOT do

```dart
void stop() {
  _debounce?.cancel();
  _sub?.cancel();
  _sub = null;
  // DO NOT clear _syncStartedAt or _uploadedIds
}
```
`stop()` pauses listening. It does NOT clear the persisted state. This is intentional: when the app reopens and `start()` is called again, the saved `_syncStartedAt` ensures we pick up exactly where we left off — no calls are missed, and no calls are duplicated.

## `syncNow()` — Full walkthrough

**Guard clauses:**
```dart
if (_syncing) return;           // Prevent concurrent runs
if (!AuthService.instance.isLoggedIn) return;  // No token = don't try
if (!Platform.isAndroid) return;   // Call log is Android-only
if (_syncStartedAt == null) return; // start() was not called yet
```
These four checks prevent any bad state. `_syncing` is the most important — without it, two overlapping sync runs would submit the same call twice (before the `_uploadedIds` is updated).

**Querying the call log:**
```dart
final deviceEntries = await CallLog.query(
  dateTimeFrom: _syncStartedAt,
);
```
`CallLog.query` is more efficient than `CallLog.get` because it asks Android to filter at the database level. Only calls from `_syncStartedAt` onwards are returned. The result size is small (calls made since first install), not the entire lifetime of the phone.

**Filtering:**
```dart
final newEntries = deviceEntries
    .where((e) =>
        e.callType == CallType.incoming ||
        e.callType == CallType.outgoing)
    .where((e) => !_uploadedIds.contains(_callId(e)))
    .toList();
```
Two filters chained: (1) only incoming and outgoing call types — missed calls are excluded because a missed call means the person hung up before anyone answered, which is a weaker lead signal; (2) not already in `_uploadedIds` — prevents re-prompting for calls already handled.

**The loop:**
```dart
for (final entry in newEntries) {
  if (!AuthService.instance.isLoggedIn) break;
```
Check at the START of each iteration. If a previous API call triggered `handleExpiredSession`, `isLoggedIn` is now false. Breaking here prevents sending more API calls with a null/invalid token.

```dart
final confirmed = await _showConfirmDialog(name, phone);
_uploadedIds.add(id);  // Always mark handled AFTER dialog
anyHandled = true;
```
The dialog runs and awaits the user's decision. Regardless of whether confirmed or skipped, the ID is added to `_uploadedIds` immediately after. This is critical: if the same call fires `syncNow()` again (e.g., another EventChannel event before `_saveUploadedIds` completes), it won't be prompted twice.

```dart
if (!confirmed) { continue; }
if (!AuthService.instance.isLoggedIn) break;
await _api.captureLead(...);
```
Second `isLoggedIn` check before the API call handles the race condition where the session expired while the dialog was open (user was deciding for 5 minutes).

## `_showConfirmDialog()`

```dart
Future<bool> _showConfirmDialog(String name, String phone) async {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) {
    print('[SYNC] No context — dialog skipped...');
    return false;
  }
  final result = await showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    ...
  );
  return result ?? false;
}
```
`barrierDismissible: false` prevents the user from dismissing the dialog by tapping outside. This forces an explicit decision (Skip or Send). If the context is null (app backgrounded), the method returns false without showing anything — the call is NOT marked as handled (the `_uploadedIds.add(id)` happens in the caller after this returns), so it WILL be prompted next time the app is open.

Wait — actually, looking at the code: `_uploadedIds.add(id)` happens AFTER `_showConfirmDialog` returns. If context is null and `_showConfirmDialog` returns false, then back in the loop `_uploadedIds.add(id)` still runs. This means context-null cases ARE marked as handled. The call will NOT be re-prompted. This is a design choice: if the app was backgrounded before the dialog could show, the call is silently skipped.

## `_callId()`
```dart
String _callId(CallLogEntry e) =>
    '${e.timestamp}_${e.number}_${e.callType?.name}';
```
Creates a deterministic unique string for any call. Same call always produces same ID. Used as the key in `_uploadedIds`.

---

# screens/login_screen.dart

## Purpose
The authentication UI. Collects email and password, validates them, and calls `AuthService.login()`.

## Type: StatefulWidget
Must be stateful because it manages: `_isLoading` (button state), `_obscurePassword` (eye icon toggle), and the `TextEditingController` and `FocusNode` instances.

## Lifecycle and Disposal

```dart
@override
void dispose() {
  _emailFocus.dispose();
  _passwordFocus.dispose();
  _emailController.dispose();
  _passwordController.dispose();
  super.dispose();
}
```
Every `TextEditingController` and `FocusNode` must be disposed when the widget is removed. Forgetting this is one of the most common Flutter memory leaks. These objects register listeners internally, and without disposal, they keep the widget alive in memory even after navigation.

## `_onLogin()` — Step by step

```dart
if (!_formKey.currentState!.validate()) return;
```
Triggers all `validator` functions in the Form. Each TextFormField runs its validator — email format check, password minimum length. Returns false if any validator returns an error string. The `!` is safe because `_formKey` is always attached to the Form widget.

```dart
setState(() => _isLoading = true);
```
Rebuilds the widget, which changes the login button from a normal button to a loading spinner. The user gets immediate visual feedback.

```dart
final result = await AuthService.instance.login(...)
if (!mounted) return;
setState(() => _isLoading = false);
```
After the async API call, check `mounted` before any setState or Navigator call. Then always reset `_isLoading` regardless of result — even if login failed, the button should return to normal.

```dart
if (result.success) {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
}
```
`pushReplacement` removes LoginScreen from the stack. The user cannot press back to return to Login after successful authentication.

## Password Visibility Toggle

```dart
suffixIcon: IconButton(
  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
),
```
Toggling `_obscurePassword` and calling `setState` triggers a rebuild of only the password `TextFormField`. The eye icon switches and the text visibility toggles. This is a standard UX pattern for password fields.

## `_inputDecoration()` Helper

Returns `InputDecoration` with five border states: default, enabled, focused, error, focusedError. Each has a custom `borderRadius` and `borderSide`. This is defined as a method rather than repeated inline to avoid code duplication — both the email and password fields use it with different `hint` and `icon`.

## `_FieldLabel` Widget
A private stateless widget that renders a field label (`Email`, `Password`) with consistent styling. Though small, extracting it avoids repeating the same `TextStyle` definition twice.

---

# screens/dashboard_screen.dart

## Purpose
The main screen after login. Shows today's call statistics, lead pipeline, recent activity, and a navigation menu.

## Type: StatefulWidget
Must be stateful because it manages: `_loading` (spinner vs content), `_allCalls` (the list that drives all stats). These change when `_loadStats()` completes.

## `initState` Pattern

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _init());
}
```
`addPostFrameCallback` defers `_init()` to after the first frame renders. This is needed because `_init()` may call `Navigator.push` (for consent screen). Calling `Navigator.push` during `initState` — before the widget is laid out — throws an error. The post-frame callback guarantees the widget is fully built and mounted.

## `dispose()`

```dart
@override
void dispose() {
  LeadSyncService.instance.stop();
  super.dispose();
}
```
When the user navigates away from the dashboard (to Login via logout, or back from a route that removes Dashboard), `stop()` pauses the EventChannel listener. This prevents memory leaks and prevents the sync from trying to show dialogs when no screen is visible.

## `_init()` — Flow

```dart
Future<void> _init() async {
  final consented = await _hasConsented();
  if (!consented) {
    final agreed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen(isConsent: true)),
    );
    if (agreed != true) return;
    await _saveConsent();
  }
  await LeadSyncService.instance.start();
  await _loadStats();
  LeadSyncService.instance.syncNow();
}
```
Order matters: (1) consent must be obtained before any data collection; (2) `LeadSyncService.start()` must run before `_loadStats()` because `start()` loads persisted state needed for sync; (3) `syncNow()` runs after `_loadStats()` so the dashboard is already rendered when confirmation dialogs appear — not blank screen with a dialog on top.

## `_hasConsented()` / `_saveConsent()`

Uses `path_provider` to get the application documents directory and checks for the existence of a `.consent` file. A file-based approach rather than SharedPreferences — both work equally well, but a file is slightly more visible to developers inspecting device storage.

## `_loadStats()` — Step by step

```dart
final now = DateTime.now();
final todayStart = DateTime(now.year, now.month, now.day);
final raw = await CallLog.query(dateTimeFrom: todayStart);
```
Queries only today's calls (from midnight today). This is for DISPLAY only — showing today's statistics. It does not trigger any lead capture. `todayStart` is midnight of today: `DateTime(year, month, day)` with no time components defaults to 00:00:00.

```dart
final entries = raw
    .map((e) => StoredCallEntry.fromCallLogEntry(e, ''))
    .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
```
The `..sort` is the cascade operator — sort in-place on the same list that was just created. Sorted newest-first (`b.compareTo(a)`, not `a.compareTo(b)`).

## Computed Stats Getters

```dart
int get _totalToday     => _allCalls.length;
int get _missedToday    => _allCalls.where((e) => e.callType == 'missed').length;
int get _incomingToday  => _allCalls.where((e) => e.callType == 'incoming').length;
int get _connectedToday => _allCalls.where(
    (e) => e.callType == 'incoming' && e.duration > 0).length;
```
These are **computed getters**, not stored fields. Every time they are accessed (during build), they scan `_allCalls` with a `.where()`. Since `_allCalls` is today's calls only (typically < 100 entries), the linear scan is negligible. The benefit: they are always accurate — no synchronization needed between a stored count and the actual list.

```dart
int get _pipelineNew       => _missedToday;
int get _pipelineContacted => _allCalls.where(
    (e) => e.callType == 'incoming' || e.callType == 'outgoing').length;
int get _pipelineConverted => _allCalls.where(
    (e) => e.callType == 'incoming' && e.duration > 60).length;
```
Pipeline logic: "New" leads are missed calls (someone called, you didn't answer — potential new lead). "Contacted" is all incoming + outgoing (two-way communication). "Converted" is incoming calls longer than 60 seconds (enough time to have a real conversation).

## `_StatsGrid` — Layout Decision

```dart
GridView.count(
  crossAxisCount:   2,
  crossAxisSpacing: 10,
  mainAxisSpacing:  10,
  childAspectRatio: 1.4,
  shrinkWrap:       true,
  physics:          const NeverScrollableScrollPhysics(),
```
`GridView.count` is used instead of `Row + Column` because it guarantees all 4 cards have identical dimensions. A `Row` with `Expanded` children gives equal widths but heights depend on content — one card with longer text would be taller. `childAspectRatio: 1.4` means width:height = 1.4:1 (slightly wider than tall). `shrinkWrap: true` + `NeverScrollableScrollPhysics` makes the grid non-scrolling — it sits inside an outer `ListView`. `shrinkWrap` without `NeverScrollableScrollPhysics` causes jank because two scrollable widgets fight each other.

## `_StatCard` with `ClipRect`

```dart
child: ClipRect(
  child: Column(...)
)
```
`ClipRect` clips any overflow that would escape the card boundaries. Even if the text is very long or the font is large, it cannot overflow visually. This is a defensive UI pattern.

## Menu Population

```dart
if (AuthService.instance.isLoggedIn) ...[
  _menuItem('logout', Icons.logout_rounded, 'Logout', Colors.red.shade400),
] else ...[
  _menuItem('login',  Icons.login_rounded,  'Login',  null),
],
```
The spread operator `...[]` inside a list literal allows conditional menu items. When the session expires silently (no redirect), `isLoggedIn` becomes false and the menu automatically shows "Login" instead of "Logout" — no rebuild needed because `PopupMenuButton` builds fresh each time it opens.

---

# screens/call_log_screen.dart

## Purpose
A full call log viewer with date filtering, SIM filtering, and its own background sync.

## `_ScreenState` Enum

```dart
enum _ScreenState {
  loading,
  permissionDenied,
  permissionPermanentlyDenied,
  unsupportedPlatform,
  error,
  empty,
  loaded,
}
```
Enumerating every possible UI state explicitly is a senior developer practice. A boolean `_isLoading` only handles one dimension. With 7 states, each state maps to a different UI (spinner, permission request, settings button, error card, empty card, or the actual list). The `_buildBody` switch expression handles each case cleanly.

## `WidgetsBindingObserver` Mixin

```dart
class _CallLogScreenState extends State<CallLogScreen>
    with WidgetsBindingObserver {
```
The `WidgetsBindingObserver` mixin allows the state to receive lifecycle events:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state != AppLifecycleState.resumed) return;
  if (_state == _ScreenState.loaded || _state == _ScreenState.empty) {
    _syncInBackground();
  }
}
```
When the user switches back to the app (e.g., ends a call and opens the app), `AppLifecycleState.resumed` fires. The call log is then synced in the background to show any new calls. This covers the case where the user is viewing the call log screen when a call ends — the list updates automatically.

## `_seenEntries` Map

```dart
final Map<String, StoredCallEntry> _seenEntries = {};
```
A map from `callId` to entry. Used to deduplicate across multiple `CallLog.get()` calls. On initial load AND on background sync, entries are added with `putIfAbsent` — if an entry already exists, it is not replaced. The final display list is built from `_seenEntries.values`.

## Permission Handling — Three Tiers

1. `isDenied` / `isRestricted` → request at runtime (`Permission.phone.request()`). If granted, proceed.
2. `isPermanentlyDenied` → cannot request again. Show a button that opens the system app settings.
3. `PlatformException` with "permission" in the message → treat as permanently denied.

This three-tier handling covers the real-world complexity of Android permissions: users who denied, users who denied with "Don't ask again", and devices with manufacturer-level restrictions.

## `_filteredEntries` Getter

```dart
List<StoredCallEntry> get _filteredEntries {
  final rangeEnd = DateTime(
      _dateRange.end.year, _dateRange.end.month, _dateRange.end.day + 1);
  return _entries.where((e) {
    final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
    if (dt.isBefore(_dateRange.start) || !dt.isBefore(rangeEnd)) return false;
    if (_selectedSimId != null && e.simDisplayName != _selectedSimId) return false;
    return true;
  }).toList();
}
```
`_dateRange.end.day + 1` is critical: the date range end is "end of that day", not the start. If the user picks May 21 as the end date, calls on May 21 should be included. Adding 1 to the day gives midnight of May 22, and `!dt.isBefore(rangeEnd)` correctly excludes May 22 and beyond.

## `AnimatedSwitcher` + `KeyedSubtree`

```dart
body: AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: KeyedSubtree(
    key: ValueKey(_state),
    child: _buildBody(filtered),
  ),
),
```
When `_state` changes (e.g., loading → loaded), `AnimatedSwitcher` cross-fades between the old and new body. `KeyedSubtree` with `ValueKey(_state)` tells Flutter that each state is a different child — without the key, Flutter might try to morph the old widget into the new one instead of fading. This adds polish to state transitions.

---

# screens/delete_account_screen.dart

## Purpose
A high-stakes UI that allows users to permanently delete their account. Designed with multiple friction points to prevent accidental deletion.

## Friction Points (UX Safety Mechanism)
1. **Warning card** — Red visual with explicit "cannot be undone" language.
2. **LIST of what gets deleted** — Makes consequences concrete, not abstract.
3. **Type "DELETE" to enable button** — Classic confirmation UX pattern. The button is visually disabled (opacity 0.45) until the text field contains exactly "DELETE".
4. **Second confirmation dialog** — `_showConfirmDialog()` shows an AlertDialog AFTER the button is clicked, requiring one more tap.

## `_canDelete` Getter

```dart
bool get _canDelete =>
    _confirmController.text.trim().toUpperCase() == 'DELETE';
```
`toUpperCase()` makes it case-insensitive (user can type "delete", "Delete", "DELETE"). `trim()` removes accidental spaces.

```dart
onChanged: (_) => setState(() {}),
```
Every keystroke triggers `setState` with no state change — just to force a rebuild so `_canDelete` is re-evaluated and the button appearance updates.

## `AnimatedOpacity` on Button

```dart
AnimatedOpacity(
  opacity:  _canDelete ? 1.0 : 0.45,
  duration: const Duration(milliseconds: 200),
  child: ...
)
```
The opacity animates smoothly between 0.45 and 1.0 as the user types. This provides visual feedback — the button "lights up" when DELETE is typed correctly.

## `_deleteAccount()` — Step by step

```dart
setState(() => _isDeleting = true);
final result = await AuthService.instance.deleteAccount();
if (!mounted) return;
setState(() => _isDeleting = false);
```
Standard async pattern: show loading state, await, check mounted, hide loading state.

```dart
if (result.success) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
```
`pushAndRemoveUntil` with `(_) => false` removes EVERY route from the navigation stack and pushes LoginScreen. The user cannot navigate back to Dashboard or DeleteAccount screen. The stack is completely cleared — appropriate after account deletion.

---

# widgets/call_log_tile.dart

## Purpose
Renders a single row in the call log list. Used in both DashboardScreen (Recent Activity) and CallLogScreen.

## Type: StatelessWidget
Has no state — it displays data from `StoredCallEntry` and nothing ever changes about the tile itself. Being stateless means Flutter can rebuild this widget cheaply.

## The `(icon, color)` Destructuring

```dart
final (icon, color) = callTypeStyle(entry.callType);
```
Dart 3 record destructuring. `callTypeStyle()` returns a `(IconData, Color)` record. Destructured directly into `icon` and `color` in one line. This is modern Dart syntax.

## Display Name Logic

```dart
final hasName = entry.name != null && entry.name!.isNotEmpty;
final displayName = hasName ? entry.name! : (entry.number ?? 'Unknown');
final subtitle = hasName ? (entry.number ?? '') : '';
```
If a contact name is known: title = name, subtitle = number. If not: title = number (no contact), subtitle = empty. This makes the tile look clean whether or not the caller is in the contacts.

## `isThreeLine`

```dart
isThreeLine: subtitle.isNotEmpty,
```
`ListTile.isThreeLine` tells Flutter to reserve space for three lines of text. When `subtitle` is empty (no contact name known), only two lines are needed and `isThreeLine: false` makes the tile more compact.

---

# widgets/lead_confirm_dialog.dart

## Purpose
A modal dialog that appears when a qualifying call is detected. Forces the user to actively confirm before a lead is sent to the backend.

## Type: StatefulWidget
Must be stateful because `_checked` (the checkbox state) changes when the user taps, and the Send Lead button's enabled state depends on `_checked`.

## `barrierDismissible: false`
Set in the caller (`_showConfirmDialog`). The dialog cannot be dismissed by tapping outside. The user MUST tap either Skip or Send Lead. This prevents accidental dismissal — critical because a dismissed dialog behaves the same as Skip, and the call is then marked as handled (never prompted again).

## `onPressed: _checked ? () => Navigator.pop(context, true) : null`
When `_checked` is false, `onPressed` is null, which makes ElevatedButton render in a disabled state. This is the Flutter-idiomatic way to disable a button — not using a flag, but literally passing null to `onPressed`. When `_checked` is true, tapping the button pops the dialog with `true` as the return value, which `_showConfirmDialog` receives and returns to `syncNow`.

## Full-width tap target for checkbox row

```dart
InkWell(
  onTap: () => setState(() => _checked = !_checked),
  borderRadius: BorderRadius.circular(8),
  child: Row(
    children: [
      Checkbox(...),
      const Text('Confirm and send as lead'),
    ],
  ),
),
```
Wrapping the entire row in `InkWell` makes both the checkbox AND the label text tappable. Without this, only the tiny checkbox square responds to taps — a poor mobile UX, especially on small screens. The `InkWell` `onTap` toggles `_checked` directly.

---

# MainActivity.kt

## Purpose
The native Android entry point. Sets up the bridge between Android's call log change notifications and Flutter's Dart code via an EventChannel.

## Why This File Exists
Android's call log is a system-level content provider that can only be observed natively via `ContentObserver`. Flutter cannot directly observe Android content providers. The bridge — EventChannel — allows the native side to push events to the Dart side.

## `ContentObserver`

```dart
callLogObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
    override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)
        eventSink?.success("changed")
    }
}
contentResolver.registerContentObserver(
    CallLog.Calls.CONTENT_URI,
    true,     // ← notifyForDescendants: observe all rows, not just the URI itself
    callLogObserver!!
)
```
`ContentObserver` is an Android class that gets called whenever a content URI changes. `CallLog.Calls.CONTENT_URI` is `content://call_log/calls`. The second argument `true` (notifyForDescendants) means changes to specific rows (not just the table level) also fire the callback.

When a call ends, Android writes a new row to the call log. This triggers `onChange`, which calls `eventSink?.success("changed")`. The `"changed"` string is arbitrary — only the fact that an event arrived matters, not its content.

## EventChannel StreamHandler

```dart
EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
    .setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
            eventSink = sink
            registerObserver()
        }
        override fun onCancel(arguments: Any?) {
            unregisterObserver()
            eventSink = null
        }
    })
```
`onListen` fires when Dart calls `_kEventChannel.receiveBroadcastStream().listen(...)`. `onCancel` fires when Dart cancels the subscription (`_sub?.cancel()`). This pairing ensures the ContentObserver is only registered when Dart is actually listening, and is properly unregistered when Dart stops listening — no resource leaks.

## `onDestroy()`

```dart
override fun onDestroy() {
    unregisterObserver()
    super.onDestroy()
}
```
Final safety net. If the activity is destroyed (app killed by system), the ContentObserver is unregistered. Without this, if `onCancel` was somehow not called, the observer would remain registered pointing to a dead reference.

## Channel Name Convention
`"com.leadmantracrm.app/call_log_events"` — the convention is `<package_name>/<channel_name>`. This matches exactly what `LeadSyncService` and `CallLogScreen` use. If these strings don't match, the EventChannel silently receives no events — a bug that is very difficult to diagnose.

---

# AndroidManifest.xml

## Purpose
Declares the app's identity, components (Activity), and permissions to the Android operating system.

## Critical Permissions

```xml
<uses-permission android:name="android.permission.INTERNET" />
```
Without this, all HTTP calls fail silently with a connection error. Required for any network access.

```xml
<uses-permission android:name="android.permission.READ_CALL_LOG" />
```
Android 9.0 (API 28) separated READ_CALL_LOG from READ_CONTACTS. On Android 9+, this is its own runtime permission that must be granted explicitly. The app cannot read the call log without this. It must also be requested at runtime via `permission_handler`.

```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
```
Allows the call_log package to resolve contact names from phone numbers. Without this, all call entries show only the phone number, never the contact name.

## Activity Declaration

```xml
android:launchMode="singleTop"
```
`singleTop` means if the app is already running and launched again (e.g., from a notification), Android reuses the existing `MainActivity` instance instead of creating a new one. Without this, multiple `MainActivity` instances could stack up, each registering its own ContentObserver, and events would fire multiple times.

---

# build.gradle.kts

## Purpose
Configures how the Android portion of the app is compiled. Written in Kotlin DSL (`.kts` extension) rather than Groovy.

## Key Settings

```kotlin
compileSdk = 36
```
The SDK version used to compile the app. Must be >= `targetSdk`. Set to 36 because `shared_preferences_android` (the Android implementation of shared_preferences) requires compileSdk 36 to compile without warnings. This does NOT mean the app only runs on Android 36 — `minSdk` controls the minimum supported version.

```kotlin
namespace = "com.leadmantracrm.app"
applicationId = "com.leadmantracrm.app"
```
`namespace` is used for generating `R` class references in Kotlin/Java. `applicationId` is the unique identifier on the Play Store and on the device — no two installed apps can have the same `applicationId`. Both must match to avoid build errors.

```kotlin
isCoreLibraryDesugaringEnabled = true
```
Enables **Java 8+ API desugaring** for older Android versions. APIs like `java.time.LocalDate` are natively available on Android 8.0+ (API 26), but desugaring backports them to older devices. Required by some Flutter plugins.

```kotlin
kotlinOptions {
    jvmTarget = "17"
}
```
Kotlin code is compiled to JVM bytecode targeting Java 17. Necessary because modern Android tooling and Kotlin features require at minimum Java 11, and 17 is the current LTS.

---

# State Management Analysis

## Pattern: Local setState

This project uses Flutter's built-in `setState` exclusively. No external state management library (BLoC, Provider, Riverpod, GetX) is used.

### Why This Is Correct for This App

The app has three meaningful pieces of UI state:
1. `DashboardScreen._loading` and `_allCalls` — local to Dashboard
2. `CallLogScreen._state`, `_entries`, `_isSyncing` — local to CallLogScreen
3. `LoginScreen._isLoading`, `_obscurePassword` — local to Login

None of this state is shared between screens. When a screen closes, its state is discarded. SharedPreferences handles persistence. Services handle cross-cutting concerns.

A BLoC or Provider would add: abstract classes, events, states, blocs/notifiers, `BlocBuilder`/`Consumer` widgets, dependency injection setup. For three local state variables per screen, this overhead is pure complexity with no benefit.

### How State Flows

```
User action (tap, app resume, call detected)
    ↓
Async method runs (API call, CallLog.query)
    ↓
setState(() { _someField = newValue; })
    ↓
Flutter marks widget as dirty
    ↓
Next frame: build() runs again
    ↓
Widget tree rebuilt with new values
    ↓
Flutter diffs old tree vs new tree
    ↓
Only changed widgets are re-rendered
```

### Computed Getters as Derived State

The stat getters (`_totalToday`, `_missedToday`, etc.) are a pattern worth noting. Rather than storing separate count fields and keeping them in sync with `_allCalls`, they are computed on demand from `_allCalls`. This means there is only ONE source of truth: `_allCalls`. You cannot have a bug where `_missedToday` is 3 but `_allCalls.where(missed)` gives 2.

---

# API & Networking Analysis

## Request Lifecycle

```
Screen calls service method (e.g., AuthService.login())
    ↓
Service builds headers + body
    ↓
http.Client.post() called with URI, headers, body
    ↓
HTTP/HTTPS connection established (timeout: 30s)
    ↓
Response received (status code + body)
    ↓
Response parsed (jsonDecode)
    ↓
Status-code-based branching:
    200 → success path
    401 → session expired path
    other → error path
    ↓
Result returned to caller OR side effect triggered (snackbar, logout)
```

## Error Handling Strategy

Three layers:
1. **Timeout** — 30 seconds. Prevents infinite waits on slow/dead connections.
2. **Status code check** — 200/401/other handled explicitly.
3. **try/catch** — Catches network errors (no internet, DNS failure, socket errors) as generic exceptions, logged and result returned as null.

## Authentication Flow

Token is a **Bearer JWT** sent in every request header:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```
- Token obtained from `/mobile/login` response.
- Token stored in SharedPreferences with a save timestamp.
- Token validated for age (< 3 days) on every app startup.
- Token cleared on logout, deleteAccount, or 401 response.

## No Retry Mechanism
There is no automatic retry for failed requests. If a request fails due to network error, it returns null. For `captureLead`, the ID is still added to `_uploadedIds` after a failed upload (currently — see Code Quality Notes). For login, the user must manually try again.

---

# Architecture Review

## Separation of Concerns — Score: Good

| Layer | Knows about UI? | Knows about Network? | Knows about Disk? |
|---|---|---|---|
| Screens | Yes | No (calls services) | No |
| Services | No (uses navigatorKey) | Yes | Yes (SharedPreferences) |
| Models | No | No | No |
| Core | No | No | No |

Services use `navigatorKey` for navigation — this is a minor violation of pure separation. A cleaner approach would be a callback/stream that screens listen to. However, for this app size, the tradeoff is acceptable: it avoids significant complexity.

## Singleton Services

`AuthService.instance` and `LeadSyncService.instance` are singletons. This means their state lives for the entire app lifetime — they never get garbage collected. This is intentional: the token must always be accessible, and the sync state must survive screen navigation.

The risk: if a singleton holds references to BuildContext (which is tied to a widget's lifetime), it causes memory leaks. This project handles this correctly by never storing BuildContext in services — it accesses context at call time via `navigatorKey.currentContext`.

---

# Performance Review

## Widget Rebuild Optimization

The `_StatsGrid` and `_StatCard` widgets are rebuilt every time `_loadStats()` completes (via setState). Since they are stateless with final fields, Flutter efficiently diffs them — only the number values actually change, and Flutter only redraws those text nodes.

The `GridView` with `shrinkWrap: true` inside a `ListView` is technically a performance concern — `shrinkWrap` disables lazy loading. However, since there are exactly 4 stat cards, all of which must be rendered simultaneously, lazy loading would provide no benefit here. The cost is negligible.

## `CallLog.query` vs `CallLog.get`

`CallLog.query(dateTimeFrom: ...)` passes the date filter to Android's SQLite layer — Android returns only matching rows. `CallLog.get()` returns every call in history. For devices with thousands of calls (years of history), this is the difference between a 5ms query and a 500ms query. The project correctly uses `query` everywhere.

## ListView.builder in CallLogScreen

```dart
ListView.builder(
  itemCount: filtered.length,
  itemBuilder: (_, i) => CallLogTile(entry: filtered[i]),
)
```
`ListView.builder` is lazy — it only builds `CallLogTile` widgets for visible rows. On a list of 1000 calls, only ~10 tiles are built at any time. Using `ListView(children: [...])` with all tiles pre-built would use 100x more memory.

## `Set<String>` for `_uploadedIds`

Set lookup is O(1) — checking `_uploadedIds.contains(id)` for 10,000 entries takes the same time as for 10. A `List.contains()` is O(n) — it scans the entire list. As the app is used over months and thousands of calls are tracked, the Set choice prevents noticeable slowdown.

---

# Code Quality Review

## Good Practices

**Defensive null handling** — `entry.timestamp ?? DateTime.now().millisecondsSinceEpoch`, `e.name?.isNotEmpty == true`. The `?? ` and `?.` operators prevent null pointer exceptions from platform data that could theoretically be null.

**`const` constructors everywhere** — `const DashboardScreen()`, `const LoginScreen()`, `const Text('Never Miss a Lead Again')`. `const` widgets are created once and reused by Flutter's widget cache. This reduces garbage collection pressure.

**Private constructors on utility classes** — `ApiEndpoints._()`, `AuthService._()`. Prevents misuse.

**Explicit state enum** in CallLogScreen — 7 states enumerated, each handled in a switch expression. No hidden `if-else` chains.

**Token trimming** — `_token = (json['token'] as String?)?.trim()`. Small detail, prevents a class of bugs.

## Potential Issues

**`_uploadedIds.add(id)` runs even on null-context dialog skip** — In `syncNow()`, when `_showConfirmDialog` returns false due to null context, the call is still marked as handled. Calls that occurred while the app was backgrounded (no context) are silently skipped forever, never shown to the user. This is a known design tradeoff documented in the service.

**`CallLogScreen._syncInBackground()` has its own `_uploadedCallIds`** — This is a separate, in-memory-only set from `LeadSyncService._uploadedIds`. When CallLogScreen is open, a call could be captured by BOTH the screen's sync AND `LeadSyncService`. This is a coupling issue — two independent capture mechanisms running simultaneously. The `ApiService.captureLead()` call in `_syncInBackground()` has no confirmation dialog, bypassing the user consent flow.

**No pagination** — `_entries` in CallLogScreen holds the entire call history in memory. On a device with 5 years of calls, this could be thousands of entries. `ListView.builder` renders lazily, but the full list is loaded into RAM.

**Token age hard-coded to 3 days** — `static const _kMaxAgeDays = 3`. If the backend changes its expiry policy (e.g., to 7 days), this constant must be manually updated. A better approach would be for the login API to return an expiry time and store it.

## Naming Conventions

- Private fields: `_token`, `_syncing`, `_allCalls` (underscore prefix ✓)
- Constants: `kShowApiSnackbar`, `_kToken`, `_kSavedAt` (k prefix ✓)
- Methods: camelCase ✓
- Classes: PascalCase ✓
- Private widget classes: `_StatCard`, `_PipelineCard`, `_GreetingCard` (underscore PascalCase, private to file ✓)

---

# Teaching Mode — Senior Architect Thinking

## Why Singletons Here and Not DI?

A fresh developer might ask: "why not use a dependency injection framework like get_it?" The answer: inject complexity only when you have a problem complexity solves. The problems DI solves are: (1) swapping implementations (test vs production); (2) managing lifecycles of objects with different scopes (request, session, singleton). This app has one implementation per service, and all services are app-lifetime singletons. DI adds 50+ lines of setup code to solve a problem that doesn't exist here.

## Why No BLoC/Riverpod?

These patterns solve the problem of state that is: (1) shared across many widgets; (2) needs to be observed reactively; (3) needs to survive widget rebuilds independently. None of the state in this app has these properties. Forcing BLoC onto simple screen-local state like `_isLoading` in a login form is like using a sledgehammer to tap a nail.

## The ContentObserver → EventChannel Pattern

This is an important architecture decision for any Flutter app that needs to observe native platform changes (GPS, sensors, call logs, clipboard). The pattern is always:
1. Native side: register an observer/listener
2. Native side: when event fires, call `eventSink?.success(data)`
3. Flutter side: `EventChannel.receiveBroadcastStream().listen(handler)`
4. Flutter side: process event in handler

The debounce is always needed because native events can fire multiple times for one logical operation.

## The `mounted` Check After Every `await`

Every async method that calls `setState` or `Navigator` must check `if (!mounted) return` after every `await`. This is not optional. It is the #1 source of Flutter crashes: "setState called after dispose". After an `await`, your widget may have been removed from the tree (user navigated away). The `mounted` flag tells you if you're still safe to update UI.

## Token Management Tradeoffs

The 3-day proactive expiry check (`_kMaxAgeDays = 3`) is a pragmatic solution to a problem that ideally would be solved by a token refresh endpoint. The backend issues JWTs that expire every 3-4 days, but there is no `POST /refresh-token` endpoint. The options were:
1. Let the app use expired tokens until a 401 response comes back (bad UX — mid-session logout).
2. Force login on every app open (terrible UX).
3. Track token age and proactively re-login at startup (current approach — acceptable UX).

Option 3 redirects to Login at the most natural moment (app startup), not in the middle of using the app.
