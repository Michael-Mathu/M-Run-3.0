# Mwendo Installation, Setup & Deployment Guide

---

## 1. Prerequisites & Version Requirements

| Dependency | Minimum Version | Verified Version | Purpose |
| :--- | :--- | :--- | :--- |
| **Flutter SDK** | `3.22.0` | `3.47.9` (Stable, Nov 2026) | Mobile application runtime |
| **Dart SDK** | `3.12.2` | `3.13.7` | Core language framework |
| **Go SDK** | `1.26.0` | `1.26.4` | Backend microservice runtime |
| **Rust / Cargo** | `1.75.0` | `1.80.0` | Native binary FIT parser FFI |
| **Docker Engine** | `24.0.0` | `27.0.0` | Container orchestration |
| **Docker Compose** | `2.20.0` | `2.28.0` | Multi-container setup |
| **PostgreSQL / PostGIS**| `16-3.4` | `postgis/postgis:16-3.4`| Spatial geospatial database |
| **Redis** | `7.0` | `redis:7-alpine` | In-memory leaderboard caching |
| **Android NDK** | `26.1.10909125`| `28.2.13676358` (required by Flutter 3.47) | App build + Rust Android ABI compiling |

---

## 2. Step-by-Step Local Setup

### 2.1 Clone Repository
```bash
git clone https://github.com/Michael-Mathu/M-Run-2.0.git
cd M-Run-2.0
```

### 2.2 Install Dependencies across Submodules
Execute the top-level make target to install dependencies across the app and all internal packages:
```bash
make setup-app
```

### 2.3 Compile Rust FFI Dynamic Library
For host execution and unit tests:
```bash
cd packages/mwendo_fit_parser/rust
cargo build --release
```

For Android NDK multi-ABI packaging:
```bash
# Requires cargo-ndk: cargo install cargo-ndk
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o ../../../app/android/app/src/main/jniLibs build --release
```

### 2.4 Run Drift Database Code Generation
```bash
cd app
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2.5 Start PostGIS & Redis via Docker
```bash
docker compose up -d
```
Verify container health:
```bash
docker compose ps
```
The database executes schema migrations automatically from `backend/internal/db/migrations/0001_init.sql`.

---

## 3. Running the System

### 3.1 Run the Flutter Mobile Application
```bash
cd app

# Default configuration (defaults to http://10.0.2.2:8080 on Android emulator)
flutter run

# Custom backend API endpoint override:
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

#### Android emulator on Windows (verified 2026-11-09)
Verified with Flutter 3.47.9 (installed at `C:\Users\Michael\flutter`), Android Studio's SDK in `%LOCALAPPDATA%\Android\Sdk`, JDK 21 (Eclipse Adoptium), and the `Medium_Phone_API_37.0` virtual device.

1. **NDK:** Flutter 3.47 builds with **NDK 28.2.13676358**. If Gradle fails with "sdkmanager did not install NDK 28.2…", install it from PowerShell (the semicolon must be quoted, so run it from PowerShell, not Git Bash):
   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --install '"ndk;28.2.13676358"'
   ```
   Or use Android Studio → SDK Manager → SDK Tools → NDK (Side by side).
2. **Start the emulator:** in Android Studio → Device Manager → ▶ on the phone, or:
   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone_API_37.0
   ```
3. **Run the app:** `cd app` then `flutter run` (picks the running emulator). Use `r` to hot-reload and `R` to hot-restart after editing code. The first Gradle build downloads its dependencies and can take a long time; later builds are much faster.
4. **GPS on the emulator:** open the emulator's `⋯` (Extended controls) → **Location**. Set a point, or load a GPX/KML route and press Play to simulate a run. Emulator fixes are idealised (good accuracy, always with speed), so they don't exercise the noise filtering; use a real phone to judge tracking accuracy.

### 3.2 Run the Go Backend Standalone
```bash
cd backend
export PORT=8080
export DATABASE_URL="postgres://mwendo:mwendo@localhost:5432/mwendo?sslmode=disable"
export REDIS_URL="redis://localhost:6379/0"
export JWT_SECRET="production-secure-32-byte-secret-key"
export CORS_ORIGIN="*"
go run ./cmd/api
```

> **Scaling beyond one instance:** if `REDIS_URL` is unset, the leaderboard falls back to an in-memory map that lives entirely inside one process. That's fine for local dev or a single-instance deployment, but running more than one API instance behind a load balancer *without* Redis means each instance shows a different, diverging leaderboard — there is no shared state between them. Set `REDIS_URL` before scaling horizontally.

---

## 4. Build & Compilation Pipelines

### 4.1 Android Production APK / App Bundle
```bash
cd app
# Release APK
flutter build apk --release --split-per-abi

# Google Play Android App Bundle (AAB)
flutter build appbundle --release
```

### 4.2 iOS Production Archive
```bash
cd app
flutter build ipa --release
```

### 4.3 Containerized Multi-Stage Docker Build
```bash
cd backend
docker build -t mwendo-api:latest .
```

---

## 5. CI/CD Workflows

### 5.1 Continuous Integration (`.github/workflows/test.yml`)
* **Flutter Test Job**: Pulls Flutter `3.44.4`, downloads dependencies, runs `flutter analyze` (zero-warning gate), then `flutter test` across all unit/widget tests.
* **Go Test Job**: Pulls Go `1.26`, checks `gofmt` formatting, runs `go vet`, then `go test -race ./...`.
* **Rust FIT Parser Job**: Builds and lints (`cargo clippy -D warnings`) the native FIT-parser crate in `packages/mwendo_fit_parser/rust`.

### 5.2 Release Packaging (`.github/workflows/release.yml`)
* Triggered automatically on git tags matching `v*`.
* **Currently compiles a debug-only APK** (`flutter build apk --debug`) using Zulu OpenJDK 21 — unsigned, unoptimized, and debuggable. This is tracked as `docs/BUILD_PLAN.md` `OPS-2`; publishing a real signed release build needs a provisioned signing keystore before it can change.
* Automatically attaches the generated `.apk` binary to GitHub Releases.
