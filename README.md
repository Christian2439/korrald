# Korrald — Switchboard Evaluation

**Standalone evaluation milestone — Bar 6 LLC Confidential**

---

## What This Delivers

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | Firebase Cloud Function — vendor switchboard, 429 backoff, Firestore config | ✅ |
| 2 | Flutter screen — triggers search, displays result, generates on-device PDF | ✅ |
| 3 | SHA-256 document fingerprint embedded in every PDF | ✅ |
| 4 | Clean, commented, handoff-ready code | ✅ |

---

## Project Structure

```
korrald/
├── functions/                        # Firebase Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── index.ts                  # Callable function entry point (scoutSearch)
│   │   ├── switchboard.ts            # Vendor routing, 429 backoff, failover logic
│   │   └── models/
│   │       └── vendor_config.ts      # VendorConfig interface (Firestore shape)
│   ├── package.json
│   └── tsconfig.json
│
├── lib/
│   ├── main.dart                     # App entry point — Firebase init
│   ├── firebase_options.dart         # ⚠️  Fill in your Firebase credentials
│   ├── models/
│   │   └── scan_result.dart          # ScanResult data class
│   ├── services/
│   │   ├── switchboard_service.dart  # Cloud Function caller
│   │   └── pdf_service.dart          # On-device PDF generation
│   └── screens/
│       └── scout_screen.dart         # Main evaluation UI
│
├── firebase.json                     # Firebase project config + emulator ports
├── .firebaserc                       # ⚠️  Replace with your Firebase project ID
└── pubspec.yaml
```

---

## Setup

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | ≥ 3.12 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | ≥ 3.12 | included with Flutter |
| Node.js | 20 LTS | [nodejs.org](https://nodejs.org) |
| Firebase CLI | latest | `npm install -g firebase-tools` |
| FlutterFire CLI | latest | `dart pub global activate flutterfire_cli` |

You also need a **Firebase project** with **Firestore** and **Cloud Functions** enabled (Blaze plan required for Cloud Functions).

---

### Step 1 — Clone the repo

```bash
git clone https://github.com/YOUR_ORG/korrald.git
cd korrald
```

---

### Step 2 — Configure Firebase (Flutter)

**Option A — FlutterFire CLI (recommended):**

```bash
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This regenerates `lib/firebase_options.dart` with your real credentials automatically.

**Option B — Manual:**

Open `lib/firebase_options.dart` and replace every `YOUR_*` placeholder with values from:  
Firebase Console → Project Settings → Your Apps → SDK setup and configuration.

---

### Step 3 — Add Android Firebase config

1. In Firebase Console → Project Settings → Android app → download `google-services.json`
2. Place it at `android/app/google-services.json`

> The `google-services.json` is excluded from version control via `.gitignore`. Never commit it.

---

### Step 4 — Add iOS Firebase config

1. In Firebase Console → Project Settings → iOS app → download `GoogleService-Info.plist`
2. Open Xcode: `open ios/Runner.xcworkspace`
3. Drag `GoogleService-Info.plist` into the `Runner` target in Xcode

---

### Step 5 — Install Flutter dependencies

```bash
flutter pub get
```

---

### Step 6 — Deploy the Cloud Function

```bash
cd functions
npm install
npm run build
cd ..
firebase login        # if not already logged in
firebase use YOUR_FIREBASE_PROJECT_ID
firebase deploy --only functions
```

---

### Step 7 — Seed Firestore vendor config

In Firebase Console → Firestore Database → create collection `switchboard_config`.

**Document `vendor_a`:**
```
name                → "PremiumSearchVendor"
priority            → 1
tier                → "premium"
enabled             → true
mockShouldReturn429 → false
mockShouldFail      → false
mockAsyncScan       → false
mockDelayMs         → 400
```

**Document `vendor_b`:**
```
name                → "StandardSearchVendor"
priority            → 2
tier                → "standard"
enabled             → true
mockShouldReturn429 → false
mockShouldFail      → false
mockAsyncScan       → false
mockDelayMs         → 700
```

---

### Step 8 — Run the app

```bash
flutter run
```

---

## Architecture

### Cloud Function Switchboard

```
Flutter Client
    │  httpsCallable('scoutSearch', { query })
    ▼
scoutSearch (Firebase Cloud Function)
    │
    ├── Validates input
    │
    └── runSwitchboard(request)
          │
          ├── Loads switchboard_config from Firestore
          │   (enabled=true, sorted by priority ASC)
          │
          └── For each vendor (priority order):
                ├── callVendor(vendor, request)
                │
                ├── On 429 → exponential backoff → retry
                │     Attempt 1 → wait 2 s
                │     Attempt 2 → wait 4 s
                │     Attempt 3 → wait 8 s → failover
                │
                ├── On other error → failover immediately
                │
                ├── On ASYNC signal → return "Scan in progress"
                │
                └── On success → return SearchResult JSON

              If all vendors fail → return "Scan in progress"
```

### Flutter Service Layer

```
ScoutScreen
    ├── SwitchboardService
    │     └── FirebaseFunctions.httpsCallable('scoutSearch')
    └── PdfService
          ├── pdf package    — on-device rendering
          ├── crypto package — SHA-256 document fingerprint
          └── path_provider  — app-private local storage (never uploaded)
```

---

## Testing Scenarios

Change Firestore flags on `vendor_a` to test each scenario without redeploying:

| Scenario | `vendor_a` config change |
|----------|--------------------------|
| Normal match | All mock flags `false` |
| 429 backoff on vendor_a → failover to vendor_b | `mockShouldReturn429: true` |
| Hard failure on vendor_a → failover | `mockShouldFail: true` |
| Async scan signal | `mockAsyncScan: true` |
| All vendors fail | Both vendors `mockShouldFail: true` |
| Disable vendor_a | `enabled: false` |

---

## Local Emulator (optional)

```bash
firebase emulators:start --only functions,firestore
```

Emulator UI: http://localhost:4000

To point Flutter at the local emulator, add this **before** `runApp` in `main.dart`:

```dart
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
```

---

## PDF Generation — On-Device Only

PDFs are generated 100% on-device using the Dart `pdf` package, saved to  
`getApplicationDocumentsDirectory()`. They are **never uploaded** to any server.

| Property | Value |
|----------|-------|
| Storage | App-private directory |
| Filename | `korrald_evidence_<unix_ms>.pdf` |
| Fingerprint | SHA-256 of `url\|confidence\|timestamp\|vendorUsed` |
| Sync | Not synced — device-local only |

---

## Switchboard Config Reference

Each document in `switchboard_config`:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name in logs and PDF |
| `priority` | number | Routing order (1 = highest) |
| `tier` | string | `"premium"` or `"standard"` |
| `enabled` | boolean | Exclude from routing without deleting |
| `mockShouldReturn429` | boolean | Simulate 429 for backoff testing |
| `mockShouldFail` | boolean | Simulate error for failover testing |
| `mockAsyncScan` | boolean | Simulate async scan response |
| `mockDelayMs` | number | Simulated API latency (ms) |

Adding a new vendor = adding a Firestore document. **No code redeploy needed.**

---

## Security Notes

- `google-services.json` and `GoogleService-Info.plist` excluded via `.gitignore`
- `.firebaserc` contains project alias only — no secrets
- SHA-256 fingerprinting runs on-device — hash never transmitted
- Cloud Function validates all inputs before processing
- PDFs stored in app-private directory; system prevents cross-app access

---

## Deliverable Checklist

- [x] Firebase Cloud Function with vendor switchboard
- [x] 429 exponential backoff (2s → 4s → 8s, max 3 retries)
- [x] Firestore-driven vendor config (add/remove without redeploy)
- [x] Vendor failover on non-429 errors
- [x] Returns JSON result or `"Scan in progress"` string
- [x] Flutter "Start Scout Search" button + loading state
- [x] Result card — confidence, URL, privacy-blurred thumbnail
- [x] "Generate Evidence PDF" button
- [x] On-device PDF — `pdf` + `path_provider`
- [x] SHA-256 document fingerprint in every PDF
- [x] Local file path shown on success
- [x] Clean, commented, handoff-ready code

---

*Korrald · Bar 6 LLC Confidential · Evaluation Build · June 2026*

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
