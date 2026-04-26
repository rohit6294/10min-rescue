# 10MinRescue — Complete Project Reference

> A single-file deep dive into every piece of the 10MinRescue platform — architecture, data model, user flows, code layout, deployment, and current limitations. Drop this entire file into any AI assistant and ask it questions about the system.

---

## 1. What this project is

**10MinRescue** is a verified emergency ambulance dispatch platform targeting India (initial market: **Kolkata, with Behala as the pilot zone**). The product promise is **sub-10-minute ambulance arrival** through a hyperlocal pre-positioned ambulance network rather than reactive hospital callouts.

### Core value proposition
- One-tap emergency request from a website / WhatsApp link
- Real-time GPS tracking of the dispatched ambulance
- Live ETA + verified driver info
- Coordinated handoff to a destination hospital so the trauma team is ready
- 24/7, transparent pricing, no surge during emergencies

### Target users
| Role | How they enter the system |
|---|---|
| **Patient / caller** | https://min-rescue.web.app or WhatsApp `+91 78660 67136` |
| **Driver** | Flutter Android app (`com.tenminrescue.ten_min_res`) |
| **Hospital staff** | Web portal at `/hospital/login.html` |
| **Owner (admin)** | Web portal at `/admin/login.html` |

---

## 2. Tech stack

| Layer | Technology | Why |
|---|---|---|
| Mobile (driver) | **Flutter 3.41.7** + Dart 3.10 | Single codebase, native perf for maps & GPS |
| State mgmt | **flutter_riverpod 2.5** | Lightweight, reactive |
| Routing | **go_router 14.8** | Declarative + deep-link-friendly |
| Maps in app | **flutter_map (Leaflet)** + OpenStreetMap | Free, no API key needed |
| Local notifs | **flutter_local_notifications 17.2** | High-priority heads-up alerts in-app (FCM-free) |
| Backend | **Firebase (Spark / free plan)** | Auth + Firestore + Hosting on free tier |
| Auth | Firebase Auth (email/password) | Per-tab session persistence to avoid cross-portal interference |
| Database | Cloud Firestore | Real-time streams |
| Web portal | Vanilla HTML + JS + Firebase JS SDK 10.14 | Zero build pipeline; deploys instantly |
| Maps on web | **Leaflet + OpenStreetMap + Nominatim** | Free everything |
| Hosting | Firebase Hosting | Free, fast CDN |
| Cloud Functions | TypeScript (scaffolded only — **NOT deployed; needs Blaze plan**) | Future server-side dispatch |

**Important:** The project is on the Firebase **Spark (free) plan**. Cloud Functions cannot be deployed without upgrading to Blaze (pay-as-you-go, has free tier). All real-time features work via Firestore streams instead of FCM push messages.

---

## 3. Live deployment

| What | Where |
|---|---|
| Public website | https://min-rescue.web.app |
| Patient SOS form | https://min-rescue.web.app/location.html |
| Admin portal | https://min-rescue.web.app/admin/login.html |
| Hospital portal | https://min-rescue.web.app/hospital/login.html |
| Firebase Console | https://console.firebase.google.com/project/min-rescue |
| Firebase project ID | `min-rescue` |
| GitHub repo | https://github.com/rohit6294/10min-rescue |
| Android package | `com.tenminrescue.ten_min_res` |
| WhatsApp number | `+91 78660 67136` |

---

## 4. Repository layout

```
10/
├── android/                          Android-specific Flutter project
│   ├── app/
│   │   ├── google-services.json      Firebase Android config
│   │   ├── build.gradle.kts          App-level Gradle (uses desugaring)
│   │   └── src/main/AndroidManifest.xml  Permissions + FCM channel meta
│   └── build.gradle.kts              Root Gradle (build dir → C:\flutter-build)
├── functions/                        Cloud Functions (scaffolded, not deployed)
│   ├── src/
│   │   ├── index.ts                  Function exports
│   │   ├── findNearbyDrivers.ts      Geohash-based dispatch
│   │   ├── findNearbyHospitals.ts    Hospital geohash search
│   │   ├── onDriverAccept.ts
│   │   ├── onDriverTimeout.ts        Radius-expansion on timeout
│   │   ├── onHospitalAccept.ts
│   │   ├── onHospitalTimeout.ts
│   │   ├── onSosCreated.ts           FCM dispatch (commented out — Blaze)
│   │   └── updateDriverLocation.ts
│   └── package.json
├── lib/                              Flutter Dart source
│   ├── main.dart                     App entry; FCM/local-notif init
│   ├── app.dart                      MaterialApp + router
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart       Navy / red / green palette
│   │   │   └── firestore_paths.dart  Path helpers
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── driver_model.dart
│   │   │   ├── hospital_model.dart
│   │   │   ├── rescue_request_model.dart   (mobile-app-originated requests)
│   │   │   └── sos_request_model.dart      (web-originated requests)
│   │   ├── router/
│   │   │   └── app_router.dart       go_router config
│   │   └── services/
│   │       ├── auth_service.dart     Firebase Auth wrapper
│   │       ├── firestore_service.dart  All Firestore CRUD (~270 LOC)
│   │       ├── location_service.dart   Geolocator helpers + Haversine
│   │       └── fcm_service.dart      Local SOS-alert helper (NOT FCM despite the name)
│   ├── features/
│   │   ├── auth/screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── role_selection_screen.dart
│   │   ├── driver/screens/
│   │   │   ├── driver_home_screen.dart      Online toggle + SOS alert cards
│   │   │   ├── document_upload_screen.dart  5-doc verification
│   │   │   ├── incoming_request_screen.dart 30s accept countdown
│   │   │   ├── navigate_to_patient_screen.dart
│   │   │   ├── patient_picked_up_screen.dart
│   │   │   ├── navigate_to_hospital_screen.dart
│   │   │   ├── ride_complete_screen.dart
│   │   │   └── sos_active_screen.dart       Map + Pickup btn + Hospital UI
│   │   └── hospital/screens/
│   │       ├── hospital_home_screen.dart    (NOT wired in router currently)
│   │       ├── incoming_ambulance_screen.dart
│   │       ├── track_ambulance_screen.dart
│   │       ├── intake_checklist_screen.dart
│   │       └── patient_received_screen.dart
│   └── shared/widgets/
│       └── loading_overlay.dart
├── public/                           Firebase Hosting payload
│   ├── index.html                    SEO-optimised landing page
│   ├── location.html                 Patient SOS form + live tracking
│   ├── admin/
│   │   ├── login.html
│   │   └── dashboard.html            Drivers / Hospitals / SOS / Rescues
│   ├── hospital/
│   │   ├── login.html
│   │   └── dashboard.html            Live alerts + accept flow
│   ├── robots.txt
│   └── sitemap.xml
├── test/                             Flutter widget tests (unused)
├── firebase.json                     Hosting + Firestore + Functions config
├── firestore.rules                   Security rules (~110 LOC)
├── firestore.indexes.json            Composite indexes
├── pubspec.yaml                      Flutter deps
└── PROJECT_OVERVIEW.md               THIS FILE
```

---

## 5. Firestore data model

### Collections

#### `admins/{uid}`
First admin must be created **manually via Firebase Console** (bootstrap). One doc per admin.
```jsonc
{
  "role": "admin",
  "email": "owner@example.com",
  "createdAt": Timestamp
}
```

#### `users/{uid}`
Auth-side user metadata. Created on registration for both drivers and hospitals.
```jsonc
{
  "uid": "abc123",
  "email": "driver@example.com",
  "displayName": "Rahul Sharma",
  "phone": "+91 9000000000",
  "role": "driver" | "hospital",
  "createdAt": Timestamp
}
```

#### `drivers/{uid}`
Created by `registerDriver()` in `auth_service.dart`. Document ID matches the Auth UID.
```jsonc
{
  "uid": "abc123",
  "name": "Rahul Sharma",
  "phone": "9000000000",
  "vehicleNumber": "WB01AB1234",
  "licenseNumber": "DL-9999",
  "verificationStatus": "pending" | "verified" | "rejected",
  "rejectionReason": "",
  "isOnline": false,
  "isAvailable": true,
  "fcmToken": "",          // unused on Spark plan
  "platform": "android",
  "geohash": "",
  "location": GeoPoint,    // current GPS
  "lastLocationUpdate": Timestamp,
  "currentRequestId": null,
  "documents": {           // base64-encoded JPEGs (snake_case keys!)
    "aadhaar_front": "/9j/4AAQS...",
    "aadhaar_back":  "...",
    "license_front": "...",
    "license_back":  "...",
    "vehicle_photo": "..."
  },
  "docsSubmittedAt": Timestamp,
  "verifiedAt": Timestamp,
  "verifiedBy": "<admin-uid>"
}
```

#### `hospitals/{uid}`
Created by admin via "Add Hospital" modal (uses a SECONDARY Firebase Auth instance to avoid logging the admin out).
```jsonc
{
  "uid": "xyz789",
  "name": "BM Birla Heart Centre",
  "email": "birla@example.com",
  "phone": "9876543210",
  "address": "1/1 National Library Ave, Alipore",
  "specializations": ["ICU", "Cardiac", "Trauma"],
  "isActive": true,
  "location": { "latitude": 22.5448, "longitude": 88.3426, "geohash": "" },
  "createdAt": Timestamp
}
```

#### `sos_requests/{id}`
Created by **anyone** (unauthenticated public via `location.html`). Driven by status field.
```jsonc
{
  "latitude": 21.866,
  "longitude": 88.187,
  "accuracy": 12.5,
  "mapsLink": "https://maps.google.com/?q=...",
  "phone": "+919900000000",
  "patientName": "Rohit Gupta",
  "emergencyType": "Cardiac / Heart",
  "status": "pending" | "assigned" | "patient_picked_up" | "resolved",
  "source": "web",
  "createdAt": Timestamp,

  // Set when driver accepts
  "driverId": "<uid>",
  "driverName": "Rahul",
  "driverPhone": "9000000000",
  "vehicleNumber": "WB01AB1234",
  "driverLat": 22.55,
  "driverLng": 88.32,
  "driverLocationUpdatedAt": Timestamp,
  "assignedAt": Timestamp,

  // Set when hospital accepts
  "assignedHospitalId": "<uid>",
  "hospitalName": "BM Birla Heart Centre",
  "hospitalPhone": "9876543210",
  "hospitalAddress": "...",
  "hospitalLat": 22.54,
  "hospitalLng": 88.34,
  "hospitalAcceptedAt": Timestamp,

  // Set when driver clicks "Picked Up Patient"
  "patientPickedUpAt": Timestamp,

  // Set when driver clicks Mission Complete
  "resolvedAt": Timestamp
}
```

#### `rescue_requests/{requestId}`
Used by an alternative full-featured flow (mobile-originated). Different state machine — see `rescue_request_model.dart`. Currently NOT exercised by the public web SOS flow (which uses `sos_requests`).

#### `location_updates/{driverId}`
Real-time driver GPS pings. Drivers write own; drivers/hospitals/admins can read.

---

## 6. Firestore security rules (summary)

File: `firestore.rules`. Key decisions:

- **All role checks use `exists(...)` not `get().data.role`** — prevents a missing user doc from blowing up rule evaluation.
- **`admins/{uid}`** — read by self only; write by existing admins only.
- **`users/{uid}`** — read by self or admin; create by self only.
- **`drivers/{uid}`** — full access by self; read by hospitals & admin; write by admin.
- **`hospitals/{uid}`** — full access by self; read by drivers & admin; write by admin.
- **`sos_requests/{id}`**:
  - `create` allowed for **anyone** (status must be `pending`, lat/lng must be numbers).
  - `get` (single doc by ID) allowed for **anyone** — public lets the customer track their own SOS at `/location.html`.
  - `list` restricted to authenticated drivers/hospitals/admin.
  - `update` allowed for drivers (any field) or hospitals (only the hospital-assignment fields).
- **`rescue_requests/{id}`** — drivers update specific keys, hospitals update specific keys, admin full.
- **`location_updates/{driverId}`** — driver writes own; drivers/hospitals/admin read.

---

## 7. SOS state machine (the core flow)

```
                                  ┌────────────────────────────────────┐
                                  │ Customer fills location.html form  │
                                  └──────────────┬─────────────────────┘
                                                 │
                                                 ▼
                                       SOS doc created
                                       status = "pending"
                                                 │
                                                 │  watchPendingSosRequests()
                                                 ▼
                          ┌─────────────────────────────────────────────┐
                          │ Online + verified driver sees pulsing alert │
                          │ card on driver_home_screen + heads-up notif │
                          └──────────────┬──────────────────────────────┘
                                         │ tap Accept
                                         ▼
                            acceptSosRequest()
                            • status = "assigned"
                            • copies driverName/Phone/vehicleNumber/Lat/Lng
                            • sets driver isAvailable = false
                                         │
                                         ▼
                          ┌──────────────────────────────────────┐
                          │ Driver routed to /driver/sos/<id>    │
                          │ Map shows patient + driver position  │
                          │ "Navigate to Patient" button         │
                          │ Driver GPS pushed to SOS every 6s    │
                          └─────────┬────────────┬───────────────┘
                                    │            │
                                    │            │  hospital portal sees SOS
                                    │            ▼
                                    │  Any active hospital taps Accept
                                    │  Hospital info written to SOS doc
                                    │  status STAYS "assigned"
                                    │            │
                                    └────────────┘
                                         │
                                         ▼
                              Driver physically reaches patient
                              Driver taps "✅ Patient Picked Up"
                                         │
                                         ▼
                            markPatientPickedUp()
                            • status = "patient_picked_up"
                            • patientPickedUpAt = serverTimestamp()
                                         │
                                         ▼
                          ┌──────────────────────────────────────┐
                          │ Hospital card NOW revealed in driver │
                          │ app + "Navigate to Hospital" button  │
                          │ Customer page badge → "On board"     │
                          └──────────────┬───────────────────────┘
                                         │
                                         ▼
                               Driver physically reaches hospital
                               Driver taps "Mission Complete"
                                         │
                                         ▼
                            completeSosRequest()
                            • status = "resolved"
                            • resolvedAt = serverTimestamp()
                            • driver isAvailable = true
                                         │
                                         ▼
                          ┌──────────────────────────────────────┐
                          │ All three views show success state    │
                          │ Driver returns to home screen        │
                          └──────────────────────────────────────┘
```

### Status meanings at a glance

| status | UI on customer page | UI in driver app | UI on hospital portal |
|---|---|---|---|
| `pending` | "Searching for ambulance…" | SOS card on home screen | (Not visible — only driver sees) |
| `assigned` | "Driver on the way" + map + ETA | Active screen with patient info | Incoming Patient alert card (red, pulsing) |
| `patient_picked_up` | "On board · heading to hospital" | Hospital card revealed; Mission Complete button enabled | Active ambulance row in table |
| `resolved` | "Mission complete" success | Returns to home | Moves to History |

---

## 8. Web portals — pages & responsibilities

### Public landing page (`public/index.html`)
- SEO-optimised: meta tags, Open Graph, JSON-LD `EmergencyService` schema, FAQ schema, geo-tags for Kolkata.
- Polished design: navy + red theme, animated CTAs, responsive.
- Two CTAs: **Emergency SOS** (→ location.html) and **Chat on WhatsApp** (deep link).

### Patient SOS form (`public/location.html`)
- Step 1 — Form: name + 10-digit phone + emergency type dropdown.
- Step 2 — GPS capture: requests browser geolocation.
- Step 3 — **Live tracking** (the new flow):
  - Subscribes to the SOS doc via `onSnapshot`.
  - **Leaflet map** with patient pin, driver pin (live), hospital pin.
  - **Live distance & ETA** chips.
  - **Elapsed time** chip ticking every second.
  - **Driver card** with call button (revealed on `assigned`).
  - **Hospital card** (revealed when hospital accepts).
  - **4-step status timeline** with per-step durations ("Driver coming · 2m 14s").
- Step 4 — Resolved success state.

### Admin portal (`public/admin/dashboard.html`)
- Sidebar tabs: **Overview · Drivers · Hospitals · SOS Requests · Rescues**.
- **Overview**: pending-driver / verified / hospitals / open-SOS counters; recent SOS table.
- **Drivers**: searchable table, badge-count for pending; click View → modal with all 5 documents (clickable for full-screen lightbox); Approve / Reject buttons.
- **Hospitals**: list + Add Hospital with **Leaflet map picker**:
  - Tap on map → marker drops, lat/lng auto-fill.
  - Search box (Nominatim API) → search address by name.
  - Drag marker → adjust.
  - Reverse-geocoding auto-fills address.
- **SOS Requests**: live table, click to see Maps link, cancel-pending button.
- **Rescues**: history table.
- **Mobile responsive**: hamburger drawer, scrollable tables, full-screen modals.
- Uses **secondary Firebase Auth instance** (`initializeApp(firebaseConfig, "secondary")` + `inMemoryPersistence`) for hospital creation so the admin's session never gets clobbered.
- Per-tab session: `setPersistence(auth, browserSessionPersistence)` so admin and hospital tabs don't fight.

### Hospital portal (`public/hospital/dashboard.html`)
- Top bar: hospital name + Active/Inactive toggle.
- Stats cards: Pending alerts / En-route / Completed today / Total.
- **Live red pulsing alert card** for incoming patients (driver-accepted SOS where `assignedHospitalId` is null).
- Accept flow writes hospital info into the SOS doc (no status change).
- Active ambulances table with **Track** button (Google Maps).
- Recent History table.
- Mobile responsive: stacked layout, horizontal-scroll tables.

### Admin login & Hospital login
- Both pages auto-redirect to dashboard if already signed in as the right role.
- Auto sign-out + redirect if signed in as some other role.
- Both use `browserSessionPersistence`.

---

## 9. Mobile app — driver flow

```
Splash screen
    │
    ▼
Login / Register screens (email + password)
    │
    ▼
Document Upload screen (5 photos: Aadhaar F+B, License F+B, Vehicle)
    │ submit
    ▼
Verification Pending screen
    │
    │  (admin approves in dashboard)
    ▼
Driver Home screen
  • Online / Offline toggle
  • Streams pending SOS + rescue requests
  • Pulsing _SosAlertCard with patient name / phone / emergency type / distance
  • Tap Accept → /driver/sos/<id>
    │
    ▼
SOS Active screen
  • Full-screen Leaflet map (patient pin + driver pin + route polyline)
  • Distance + ETA chips
  • Patient call button (tel: URI)
  • "Navigate to Patient" → Google Maps deep link
  • [status=assigned] "✅ Patient Picked Up — Show Hospital" button
  • [status=patient_picked_up + hospital accepted] hospital card revealed:
      - hospital name, address, phone (Call button)
      - "Navigate to Hospital" → Google Maps to hospital coords
  • [status=patient_picked_up] "✅ Mission Complete" button enabled
    │ tap mission complete
    ▼
Returns to Driver Home
```

The driver's GPS is pushed to the SOS doc every 6 seconds (debounced) so the customer's tracking page can render a live position.

### Local notifications
- `flutter_local_notifications` + a high-importance Android channel (`sos_emergency`).
- Fires when a new SOS appears in the Firestore stream.
- Title format: `🚨 EMERGENCY SOS · <emergencyType>`.
- Body: `<patientName> · <phone> · <distKm> km away`.
- Tap → routes to `/driver/sos/<id>`.
- Configured with `fullScreenIntent` so it wakes the screen.
- **Limitation**: only fires while the app process is alive (foreground or recent background). Hard-killed app misses alerts. **Real FCM push requires upgrading to Blaze** and enabling `onSosCreated` Cloud Function.

---

## 10. Authentication

| Account type | How created | Where they log in |
|---|---|---|
| **Admin** | **Manually in Firebase Console** (one-time bootstrap):  1) Auth → Add User → email + password. 2) Copy UID. 3) Firestore → start collection `admins` → doc with that UID, field `role: "admin"`. | `/admin/login.html` |
| **Driver** | Self-registers via Flutter app's Register screen (email + password + name + phone + vehicle + license). | Flutter app login screen |
| **Hospital** | Created by admin from "+ Add Hospital" form (email + password set there). | `/hospital/login.html` |
| **Customer** | NO account — only enters phone number on the SOS form. | n/a |

### Security gotchas solved during development
- **Cross-tab logout**: Firebase Auth used IndexedDB by default → admin tab + hospital tab interfered. Fixed with `browserSessionPersistence` (per-tab).
- **Token-refresh blip**: `onAuthStateChanged` could briefly emit `null` during refresh → kicked user to login. Fixed with `booted` flag — only redirect on FIRST null.
- **Secondary auth for hospital creation**: `createUserWithEmailAndPassword` signs in the new user → kicks out admin mid-write. Fixed with secondary `initializeApp(config, "secondary")` + `inMemoryPersistence`.
- **Orphan-user recovery**: If a previous hospital create attempt left an Auth user but no Firestore doc, the next attempt detects `auth/email-already-in-use`, signs in to that orphan with the supplied password, and writes the missing docs.

---

## 11. WhatsApp + AutoResponder integration

There is no official WhatsApp Business API integration (it costs ₹₹). Instead:

1. **Public landing page** has a "Chat on WhatsApp" button → `https://wa.me/917866067136?text=I%20need%20an%20ambulance%20urgently`.
2. The owner runs **WhatsApp Business** app on a dedicated phone with that number.
3. **AutoResponder for WA** Android app auto-replies to every incoming message with:
   ```
   🚑 Tap to share your location: https://min-rescue.web.app/location.html
   ```
4. Customer taps link → fills the form → location captured → SOS created.

**Limitation**: AutoResponder's `%from_tel%` variable only works when the sender is a saved contact (free tier). For emergencies (strangers), the customer enters their number on the form anyway, so this is fine.

---

## 12. SEO

`public/index.html` includes:
- Geo meta tags (`geo.region=IN-WB`, `geo.placename=Kolkata, Behala`, `geo.position=22.5004;88.3157`).
- Keywords: `ambulance near me, emergency ambulance Kolkata, ambulance Behala, 24/7 ambulance, ICU ambulance Kolkata, oxygen ambulance, fast ambulance, …`.
- Open Graph + Twitter cards.
- **JSON-LD `EmergencyService`** schema with phone, address, hours, areaServed (Kolkata, Behala, Tollygunge, Joka, Thakurpukur, Alipore), services list (Emergency Transport, ICU, Oxygen, Cardiac).
- **JSON-LD `FAQPage`** schema with 4 Q&As → triggers Google rich snippets.
- `sitemap.xml` listing `/` and `/location.html`.
- `robots.txt` blocking `/admin/` + `/hospital/` from indexing.

---

## 13. Build & deploy

### Web (instant — Spark plan)
```bash
cd "/c/Users/rahul/OneDrive/Desktop/10 min rescue/10"
firebase deploy --only hosting
firebase deploy --only firestore:rules
```

### Mobile APK
```bash
# Env vars (already set permanently via setx)
export JAVA_HOME="/c/jdk-17/jdk-17.0.18+8"
export ANDROID_HOME="/c/Android"
export PATH="/c/flutter/bin:/c/jdk-17/jdk-17.0.18+8/bin:/c/Android/cmdline-tools/latest/bin:/c/Android/platform-tools:$PATH"

cd "/c/Users/rahul/OneDrive/Desktop/10 min rescue/10"
flutter pub get
flutter build apk --release
# APK is at: C:/flutter-build/ten_min_rescue/app/outputs/flutter-apk/app-release.apk
adb install -r "/c/flutter-build/ten_min_rescue/app/outputs/flutter-apk/app-release.apk"
```

The Gradle output dir is **redirected to `C:\flutter-build\ten_min_rescue`** (outside OneDrive) because OneDrive's "files-on-demand" was randomly turning compiled `.so` files into cloud placeholders mid-build, breaking `mergeReleaseNativeLibs`.

### Cloud Functions (Blaze plan required — currently disabled)
```bash
cd functions
npm run build
firebase deploy --only functions
```
The exported `onSosCreated` function is currently commented out in `functions/src/index.ts`. Uncomment after Blaze upgrade.

---

## 14. Firebase config used everywhere

```js
{
  apiKey: "AIzaSyCmDYyhvCc03CXVi8gwQarZJgpbHIx5tKA",
  authDomain: "min-rescue.firebaseapp.com",
  projectId: "min-rescue",
  storageBucket: "min-rescue.firebasestorage.app"
}
```
The API key is **safe to commit publicly** — it's not a secret, only a project identifier. Firebase security rules are the actual access boundary.

---

## 15. Known limitations / TODO

| # | Limitation | Reason | Fix |
|---|---|---|---|
| 1 | No real push when phone is locked + app killed | Spark plan blocks Cloud Functions | Upgrade to Blaze; uncomment `onSosCreated` export; rebuild APK |
| 2 | Hospital portal not wired into mobile app router | `app_router.dart` only has driver routes | Add `/hospital/*` routes if mobile hospital app is desired |
| 3 | One-shot admin bootstrap | First admin must be created manually in Firebase Console | Build a one-time `/admin/setup.html` page |
| 4 | No payment integration | Out of scope for v1 | Razorpay / UPI later |
| 5 | No multi-driver simultaneous SOS handling | A driver can have only one active SOS | Add a queue / scheduling layer |
| 6 | Hospital decline = local-only (UI hides it) | Simple MVP | Add `declinedHospitalIds[]` array on SOS doc |
| 7 | Driver document photos as base64 in Firestore | Storage avoidance to stay on Spark | Move to Firebase Storage when on Blaze |
| 8 | Customer can submit duplicate SOS by re-loading | No rate limiting | Add a cooldown or phone-based dedup |
| 9 | English-only UI | MVP | i18n: Hindi + Bengali |
| 10 | No driver review / rating | Out of scope | Post-trip rating system |
| 11 | No emergency dispatch from mobile-originated rescue_requests | Web SOS uses the simpler `sos_requests` flow | Unify into one collection |
| 12 | Hospitals invited via password sharing | No email-link signup | Build "set your password" link flow |
| 13 | Admin "Decline driver" doesn't notify the driver | Just sets status=rejected | Push or email notify |

---

## 16. Where to add the next feature

| If you want to add… | Edit these files |
|---|---|
| A new field on the SOS doc | `lib/core/models/sos_request_model.dart` (Flutter) + `public/location.html` write block + `public/admin/dashboard.html` SOS render + maybe `firestore.rules` |
| A new admin tab | `public/admin/dashboard.html` — duplicate a `<section class="page">`, add a sidebar `<button class="tab">`, add render fn, subscribe to whatever collection |
| A new driver screen | New file under `lib/features/driver/screens/`; register in `lib/core/router/app_router.dart`; navigate via `context.go(...)` |
| A new emergency type | `public/location.html` — add `<option>` to the `<select id="emergency">` |
| Push notifications (real FCM) | Upgrade to Blaze; uncomment `onSosCreated` export in `functions/src/index.ts`; deploy `firebase deploy --only functions`; update Flutter `fcm_service.dart` to use the actual `firebase_messaging` package and re-add `firebase_messaging` to `pubspec.yaml` |
| A custom domain | Firebase Console → Hosting → Add custom domain → follow DNS instructions |

---

## 17. Quick-reference commands

```bash
# Project root
cd "C:/Users/rahul/OneDrive/Desktop/10 min rescue/10"

# Run Flutter app on connected USB device
flutter run

# Hot-rebuild + reinstall release APK on Vivo V2338
flutter build apk --release && adb install -r "C:/flutter-build/ten_min_rescue/app/outputs/flutter-apk/app-release.apk"

# Push to GitHub
git add . && git commit -m "<msg>" && git push

# Deploy web + rules
firebase deploy --only hosting,firestore:rules

# Watch live SOS in admin dashboard
# open https://min-rescue.web.app/admin/dashboard.html

# Tail Cloud Functions logs (when on Blaze)
firebase functions:log
```

---

## 18. Conventions

- **Colors** (from `lib/core/constants/app_colors.dart`):
  - `--navy` `#0B1D3A` background
  - `--red` `#FF3B3B` emergency
  - `--green` `#22C55E` success / hospital
  - `--blue` `#2563EB` info / navigation
  - `--amber` `#F59E0B` warning / pickup
- **Document key style**: snake_case in Firestore (`aadhaar_front`, `vehicle_photo`).
- **Phone format**: stored as `+91XXXXXXXXXX` (10 digits with country code).
- **Coordinates**: Firestore stores as `latitude` + `longitude` numbers (NOT Firestore `GeoPoint` for SOS docs — easier to query/index).
- **Timestamps**: always `serverTimestamp()` for created/updated; client clocks not trusted.
- **Status values** (SOS): `pending`, `assigned`, `patient_picked_up`, `resolved`.
- **Status values** (rescue_requests): `pending_driver`, `driver_assigned`, `patient_picked_up`, `pending_hospital`, `hospital_assigned`, `in_transit`, `completed`, `cancelled`.

---

## 19. Hard-won lessons (debugging notes)

- **OneDrive + Gradle native libs = corrupt builds**. Always redirect Gradle output outside OneDrive folders.
- **`flutter_local_notifications` requires `coreLibraryDesugaringEnabled = true`** in app/build.gradle.kts + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")` dep.
- **Older `geolocator_android` 4.6.x** uses `flutter.compileSdkVersion` which doesn't resolve in transitive sub-projects → patch to hardcoded `compileSdk 34`.
- **`Color.withValues(alpha:)`** requires Flutter 3.27+ (use `withOpacity()` on older versions).
- **Cross-tab Firebase Auth** broadcasts session across tabs by default → use `browserSessionPersistence` to isolate.
- **`createUserWithEmailAndPassword`** signs in the new user immediately, kicking the admin out → always use a secondary app instance for user creation in admin tools.
- **`onAuthStateChanged`** can briefly emit `null` during token refresh → guard with a `booted` flag.
- **Firestore rule `get(...).data.role`** crashes the entire rule chain if the doc doesn't exist → always use `exists(...)` checks.
- **GitHub 100MB file limit** is hard — even after `git rm --cached` you must amend & force-push to remove a file from the most recent commit's history.

---

## 20. Glossary

| Term | Meaning |
|---|---|
| SOS | Emergency request created from `location.html` (the simpler public flow) |
| Rescue request | Mobile-originated request via `rescue_requests` collection (richer state machine, used by driver-app push patterns) |
| Pickup | Driver physically getting the patient into the ambulance — gates hospital info reveal |
| Verified driver | One whose `verificationStatus == "verified"` (admin-approved after document review) |
| Active hospital | One with `isActive == true` — can receive incoming-patient alerts |
| Geohash | String encoding of lat/lng for efficient proximity queries (used by Cloud Functions) |
| Spark plan | Firebase free tier (no Cloud Functions / Cloud Tasks) |
| Blaze plan | Firebase pay-as-you-go (free quotas first, then per-use) |
| AutoResponder | Android app on the WhatsApp dispatch phone that auto-sends a link reply |

---

## 21. How to ask an AI for help with this project

Paste this entire file into the AI's prompt and follow up with a request like:

- *"Walk me through what happens, file by file, when a customer submits an SOS from location.html until the driver sees the alert."*
- *"Show me how to add a 'Cancel SOS' button on location.html that updates the doc to status=cancelled."*
- *"How do I migrate from `sos_requests` to `rescue_requests` so we use one collection?"*
- *"Generate the Cloud Function code for `onSosCreated` that sends FCM to all online verified drivers within 5 km of the SOS."*
- *"Add a real-time hospital occupancy field so drivers can pick a hospital with an ICU bed available."*

The AI will have enough context from this single file to give you accurate, file-aware answers.

---

_Last regenerated: 2026-04-26_
