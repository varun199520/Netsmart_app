# CLAUDE.md — NetSmart mobile app

This file provides guidance to Claude Code when working in this repository.

## What this is

The NetSmart iOS/Android app for the Stanford Health Care network team: a Flutter
client for the NetSmart platform (`https://netsmart-prd.stanfordmed.org`). It
replaces an older intern-built app (DeviceTracker search only, no auth, pointed
at a retired server) and **ships as an update to the same App Store listing**.

Owner: Ahmad Rezazadeh (solo developer). Built 2026-10-03 on the NetSmart server
(Linux, no Xcode), handed off to the Mac for simulator/device testing, signing
and release.

Two repos, both on branch `feature/mobile_app`:

| Repo | What | Where |
|---|---|---|
| `arezazadeh/klevernet_app` (this one) | Flutter app | Mac + server `/netsmart/klevernet_app` |
| `network_tool` | Django backend incl. the `mobile_api/` app the phone talks to | server `/netsmart/network_tool` only |

**This Mac cannot change or restart the server.** Backend bugs found here get
written up (endpoint, request, response, expected vs actual) and fixed on the
server side. Never ask for a container restart casually — the server has live
users and Ahmad does restarts himself.

## Current status (2026-10-03)

- All features built. `flutter analyze` clean, `flutter test` 9/9 (demo-mode
  widget flows). **Never compiled for iOS yet** — `ios/Runner/AppDelegate.swift`
  (push bridge) was written blind; first Xcode build may need small Swift fixes.
- Backend `mobile_api` built, 23/23 server tests, migrations applied; Ahmad is
  doing the reloads and granting `can_use_mobile_app`.
- Not done: APNs `.p8` key on the server, Android push (FCM), App Store release.

## Features

Bottom tabs (`lib/screens/home_shell.dart`, `IndexedStack`; tabs appear per
capability from `/me`):

- **Tracker** — endpoint search by MAC/IP/hostname, switch search; endpoint
  card; switch detail (endpoints with paging/filter, ports with
  free/recent/in-use/uplink chips, "Refresh from switch"); recents + favorites.
- **Port actions** (bottom sheet from any port) — read live config, bounce,
  configure (access VLAN, voice VLAN, description, enable/disable), ISE removal.
  Every write is a server-side job with RBAC + audit; the app shows a job screen
  that polls until done.
- **Assistant** — the NetSmart chatbot over WebSocket: streaming markdown, tool
  chips, model picker, general/troubleshoot mode, stop, and steering (sending
  while a reply streams).
- **DHCP** — reservation search across all DHCP servers (shows in-sync /
  missing-on-N), create reservation (next free IP in a subnet, or a specific IP).
- **More** — profile + capabilities, my recent actions (jobs), job
  notifications toggle, signed-in devices (remote sign-out), version, sign out.
- **NetSmart sidebar (drawer)** — hamburger on every tab / left-edge swipe.
  Mirrors the web sidebar *per user*: the server renders the real
  `rb_nav_content` block of `templates/reimagined_base.html` and parses it
  (`GET nav`), so permissions and new web links carry over automatically.
  Items open a bottom tab, a native screen (`lib/screens/tools/`, registry in
  `tool_router.dart`), an in-app browser sheet (external links on other hosts,
  `openOffsite`), or the web page in-app. **Partner sites**
  (`AppConfig.partnerHosts`, currently NetSmart DCM
  `netsmart-dcm.stanfordmed.org`) are external links that still open in
  `WebToolScreen(url:)`: no ticket (it only works on the prd host, and DCM is
  a separate instance with its own DB), the site's own Microsoft sign-in once
  (the web view remembers it), and its web sidebar stays visible. NetSmart web pages
  open in-app (`WebToolScreen`, WKWebView) **already signed in** via a one-time ticket —
  the user never logs in twice. Native so far: Subnet Calculator (on-device),
  Subnet Lookup, DHCP IP/MAC Lookup, DNS Lookup, DC Fabric VLANs, Ping from
  Switch + Available Switchports (jobs), Nurse Call Switches, Site Locations,
  Change Requests, Team Calendar. To make another web tool native: add its
  template tag to `NATIVE_TAGS` (server `mobile_api/services/nav.py`), an
  endpoint gated by `views_tools._gated`, then a screen + `nativeTools` entry.
- **Demo mode** — "Explore a demo with sample data" on the sign-in screen.
  Fully offline fake data (`DemoApi`, RFC 5737 addresses, switch
  `DEMO-ACC-SW01`); an orange banner shows on every screen. **Required for App
  Review**, since reviewers can't reach the Stanford network.

Look and feel **must match NetSmart's dark web UI**: `NS` palette in
`lib/theme.dart` (GitHub-dark: bg `#0D1117`, surface `#161B22`, border
`#30363D`, accent `#58A6FF`) for the app, `Nexus` palette for the chat screen
(matches the web chatbot). Don't introduce light-mode or off-palette colors.

## One-time Mac setup

1. Xcode (latest) → open once, accept license, install an iOS Simulator runtime
   (Xcode → Settings → Components).
   `sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild -runFirstLaunch`
2. Flutter **3.47.x / Dart ≥ 3.13.5** (pubspec requires `sdk: ^3.13.5`):
   `brew install --cask flutter` (or the SDK zip), then `flutter doctor` until
   the Xcode + CocoaPods lines are green. CocoaPods: `brew install cocoapods`.
3. `git clone git@github.com:arezazadeh/klevernet_app.git && cd klevernet_app && git checkout feature/mobile_app`
4. `flutter pub get && (cd ios && pod install)`
5. `open ios/Runner.xcworkspace` (the **workspace**, not the .xcodeproj) →
   Runner target → Signing & Capabilities: Team **5A9ULTV2QN**, "Automatically
   manage signing" on, bundle id stays **`com.example.netsmart.5A9ULTV2QN`**
   (it's the existing App Store listing — never change it). Add the **Push
   Notifications** capability if it isn't listed (the entitlements file already
   has `aps-environment`; the capability makes Xcode put it in the profile).

## Running

The Mac/phone must be **on the Stanford network or VPN** for real sign-in —
the server refuses other source IPs (`MOBILE_ALLOWED_NETWORKS`). Demo mode works
anywhere.

- Simulator: `open -a Simulator`, then `flutter run` (or pick the simulator in
  Xcode and Run). The simulator uses the Mac's network/VPN.
- Physical iPhone: USB-connect, trust the Mac, enable **Settings → Privacy &
  Security → Developer Mode** (iOS 16+), then `flutter run -d <device>` (see
  `flutter devices`). Installing a dev build **replaces the App Store NetSmart
  app** on that phone (same bundle id) — expected.
- A different server: `flutter run --dart-define=NETSMART_URL=https://<host>`.
- Release-mode feel (faster, no debug banner): `flutter run --release` (device only).

## Sign-in flow (how it actually works)

`ASWebAuthenticationSession` (via `flutter_web_auth_2`) opens
`<server>/mobile/auth/authorize/?client_id=netsmart-mobile&redirect_uri=org.stanfordmed.netsmart://auth&code_challenge=…&state=…`
→ the normal NetSmart web login → server checks network + `can_use_mobile_app`
→ redirects to `org.stanfordmed.netsmart://auth?code=…&state=…` (or
`error=access_denied`) → app POSTs `/api/mobile/v1/auth/token`
(`grant_type=authorization_code`, PKCE verifier, device name/platform/app
version) → access token (15 min) + rotating refresh token, stored in the
Keychain (`flutter_secure_storage`). Refresh is automatic on 401; a second 401
signs the user out locally.

If sign-in says "access denied", the user lacks `can_use_mobile_app` (granted
on NetSmart `/node_manager/settings/users/`). If it says the network isn't
allowed, the device isn't on Stanford network/VPN (or the server sees a
different IP than expected — report the IP).

## Code map (`lib/`)

| File | Role |
|---|---|
| `config.dart` | base URL (`NETSMART_URL` dart-define), client id, redirect scheme |
| `theme.dart` | `NS` + `Nexus` palettes, `ThemeData` |
| `app_state.dart` | `ChangeNotifier`: status (loading/signedOut/offline/updateRequired/ready), `me`, `caps`, api selection (live vs demo), push toggle, `compareVersions` |
| `main.dart` | `NetSmartApp`; `MaterialApp.builder` wraps every route with the demo banner |
| `services/api.dart` | `NetsmartApi` interface, `ChatConnection`, `ApiException`, `Json` helpers (`str`, `jsonMap`, `jsonList`) |
| `services/live_api.dart` | HTTP + WebSocket implementation |
| `services/demo_api.dart` | offline fake implementation (jobs finish after ~3.5 s wall clock) |
| `services/auth.dart` | PKCE login, token storage/refresh, logout |
| `services/push.dart` | method channel `org.stanfordmed.netsmart/push` → APNs token |
| `services/prefs.dart` | recents, favorites, chat model, etc. (SharedPreferences) |
| `widgets/common.dart` | `SectionCard`, `KV`, `Pill`, `Loading`, `ErrorView`, `CenterMessage`, `confirm`, `showSnack`, `ago` |
| `screens/` | sign_in, home_shell, search, endpoint, switch, port_sheet (+ `ConfigurePortScreen`), job (+ `openJob`), dhcp, dhcp_reserve, chat_list, chat, more (+ `JobsScreen`, `DeviceSessionsScreen`) |
| `widgets/nav_drawer.dart` | the sidebar drawer (`NavDrawer`, `NavScope`, `NavMenuButton`, boxicon→Material map) |
| `screens/web_tool_screen.dart` | signed-in web page (ticket POST, hides web sidebar/top bar, login-page retry) |
| `screens/tools/` | native web tools + `tool_router.dart` (`openNavItem`, `nativeTools`) |
| `services/web_session.dart` | clears web view cookies on sign-out |
| `services/ipv4.dart` | subnet math for the calculator |
| `ios/Runner/AppDelegate.swift` | `PushBridge` plugin: requests permission, returns hex APNs token |

## Backend contract (`/api/mobile/v1/`, Bearer access token)

- `GET meta` (no auth: min_app_version, push availability) · `GET me`
- `POST auth/token` (code / refresh grants) · `POST auth/logout` ·
  `GET auth/sessions` · `DELETE auth/sessions/<uuid>`
- `GET search?q=` · `GET switches?q=` · `GET switches/<id>` (incl.
  `actions{read,bounce,configure,ise_removal}`, `dhcp`) ·
  `GET switches/<id>/endpoints?page&page_size&sort&filter` ·
  `GET switches/<id>/ports` · `GET switches/<id>/vlans` ·
  `POST switches/<id>/refresh` → `GET switches/<id>/refresh/<job>`
- `POST jobs {kind, switch_id, port, ...}` → 202 job;
  kinds `port_read | bounce | port_config | ise_removal | dhcp_reserve`;
  `GET jobs` · `GET jobs/<id>` (status `queued|running|succeeded|failed`, `done`, `result`, `message`).
  `port_config` params: `vlan`, `add_voice`, `description` (null = keep), `enabled`.
  `dhcp_reserve`: `mac, name, comment, fqdn` + `ip` or `subnet`, optional `switch_id`.
- `GET dhcp/reservations?q=` → `{results[{ip,mac,name,comment,network,servers,missing}], errors}` ·
  `GET dhcp/switches/<id>/subnets`
- `GET/POST chat/sessions` · `DELETE chat/sessions/<id>` ·
  `GET chat/sessions/<id>/history` · `GET chat/models` · `GET chat/diagrams/<id>`
- `POST push/register {enabled, token?}`
- `GET nav` → `{sections[{title, accent, groups[{label, icon, items[{title, path|url, native?, external?}]}]}]}`
- `POST auth/web-session {path}` → `{path:"/mobile/auth/web/", ticket, expires_in:60}`; the web
  view POSTs `ticket=` to `/mobile/auth/web/` → Django session + 302 to `path`. Single use,
  bound to the device session; revoking the device session deletes those web sessions.
- `GET tools/dc-vlans?ip|vlan|switch` · `tools/changes[?refresh=1]` · `tools/changes/<sys_id>` ·
  `tools/calendar?from&to` · `tools/nurse-call` · `tools/sites[?q]` · `tools/sites/<id>` ·
  `tools/dns?q` · `tools/ip-info?q` · `tools/subnet?net` · `tools/ping` (VRFs). Each is gated by
  "tool is on the user's web sidebar" **and** the web page's own view check.
- Job kinds `ping {ip, vrf}` (switch = last ARP sighting) and `port_usage {switch_id}`.
- WebSocket `wss://<host>/ws/mobile/chat/` (Bearer header). Client frames: turn
  `{query, chat_session_uuid, model_name, agent_mode, data_source:"network_agent"}`,
  `{"type":"cancel"}`, `{"type":"steer","id","text"}`. Server frames: `token`,
  `tool_start`, `tool_end`, `model`, `error`, `steer_queued`, `steer_applied`,
  `steer_missed`, `done{session_name?, history_id?}`, `cancelled`, `auth_error`.
  Unapplied steers are re-sent as one new turn after `done` (same as the web UI).

Server-side source of truth: `network_tool/mobile_api/` (`urls.py`, `views.py`,
`views_auth.py`, `jobs.py`, `ws.py`, `push.py`, `security.py`).

## Testing checklist (first session on the Mac)

1. `flutter analyze` and `flutter test` pass (they did on Linux).
2. iOS build compiles — fix any Swift errors in `AppDelegate.swift` first.
3. Simulator, demo mode: every tab, switch → ports → bounce/configure → job
   screen, DHCP search 192.0.2.40 + new reservation form, chat streams + stop +
   steer, More tab, exit demo. Check layout on small (iPhone SE) and large
   (Pro Max) simulators, and with large Dynamic Type.
4. Simulator on VPN, real sign-in: SSO round-trip returns to the app; kill and
   relaunch stays signed in; search a real MAC/IP; open a real switch.
5. Device: same as 4, plus a low-risk write (read live config, then bounce an
   unused port you own) and confirm it appears in the NetSmart audit log; chat
   on cellular+VPN; background/foreground mid-stream.
6. Push (once the server has the APNs key): see gotcha below.

## Gotchas

- **APNs sandbox vs production.** Builds installed from Xcode/`flutter run` get
  *sandbox* tokens; TestFlight/App Store builds get *production* tokens. The
  server picks one host globally via `MOBILE_APNS_USE_SANDBOX` (default False =
  production). While testing from Xcode, Ahmad must set it True on the server;
  flip back before TestFlight. (Proper fix, not done yet: app sends its APNs
  environment with the token and the server picks per token.)
- Server push needs `MOBILE_APNS_KEY_FILE` / `MOBILE_APNS_KEY_ID` (an APNs Auth
  Key `.p8` from developer.apple.com → Keys, team 5A9ULTV2QN). Until then the
  notifications toggle can't actually deliver.
- If Keychain writes fail on the simulator (`-34018`), add the Keychain Sharing
  capability.
- `IndexedStack` keeps all tabs mounted: two `FloatingActionButton`s need
  `heroTag: null` or navigation throws "multiple heroes".
- Widget tests: demo jobs advance on wall-clock time — use
  `tester.runAsync(() => Future.delayed(...))` before pumping; offstage tabs
  aren't matched by finders; lazy `ListView` items below the fold need
  `scrollUntilVisible`.
- `MOBILE_MIN_APP_VERSION` (server, default 2.0.0) forces an "update required"
  screen for older versions — bump `version:` in `pubspec.yaml` on every release.
- Android: builds (`org.stanfordmed.netsmart`) but push (FCM) is not wired —
  needs `google-services.json` + a server FCM service account.

## Release (App Store, same listing)

1. Bump `version: X.Y.Z+N` in `pubspec.yaml` (listing is currently 1.0.3 → this
   is 2.0.0).
2. `flutter build ipa` (or Xcode → Product → Archive) → upload via Xcode
   Organizer / Transporter → TestFlight first.
3. App Store Connect: update screenshots (dark UI), description, **App Privacy**
   (the app now signs users in and stores their identity), and export
   compliance (HTTPS only).
4. **App Review notes:** "This app is for Stanford Health Care network staff and
   requires the internal network. Tap 'Explore a demo with sample data' on the
   first screen to review all features with sample data."

## Rules

- Keep the dark NetSmart look; match existing widgets before adding new ones.
- Stanford-facing text (UI strings, store listing, review notes) must not
  mention unrelated vendors/environments.
- Run `flutter analyze` + `flutter test` before every commit; add a demo-mode
  widget test for each new flow (`DemoApi` must support any new API method).
- Every new API method goes in `NetsmartApi` **and** both `LiveApi` and `DemoApi`.
- Commit often on `feature/mobile_app` — uncommitted work has been lost before.
