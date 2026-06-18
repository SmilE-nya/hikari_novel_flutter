# Hikari Novel — Agent Guide

## Project

Hikari Novel: Flutter third-party light novel client for wenku8.
- **SDK**: ^3.10.7, channel stable
- **State mgmt**: GetX (GetxController, GetxService, obs/Rx, Get.put/find)
- **Networking**: Dio + cookie_jar + Cloudflare interceptor (403/challenge)
- **DB**: Drift (SQLite) for structured data, Hive CE for KV settings
- **HTML**: All wenku8 data is GBK/Big5 → parsed with `html` package (no JSON API)
- **Platforms**: Android (6.0+), Windows (10+), macOS/iOS (untested). No web, no Linux.

## Key architecture

```
lib/
├── main.dart                  # Entry: init services, cookie, runApp
├── base/                      # BaseListPageController (paginated list pattern)
├── common/
│   ├── constants.dart         # App-wide constants
│   ├── util.dart              # Locale, update check
│   ├── extension.dart         # Get.findOrPut, screen info, GBK/Big5 URL encoding
│   ├── app_translations.dart  # zh_CN / zh_TW GetX translations
│   ├── database/              # Drift schema (5 tables), migration v1→v4
│   ├── log.dart               # Logger wrapper (log levels: t/d/i/w/e/f)
│   └── migration.dart         # DB migrations
├── models/                    # Data classes (json_serializable, sealed Resource<T>)
├── network/
│   ├── request.dart           # Dio singleton, cookie init, Cloudflare interceptor
│   ├── api.dart               # All wenku8 API endpoints (GBK/Big5 URL encoding)
│   ├── parser.dart            # HTML → model parsers (662 lines)
│   ├── chapter_downloader.dart # Chapter caching with CancelToken
│   └── image_url_helper.dart  # Image URL normalization + fallback
├── pages/                     # 23 page modules (controller.dart + view.dart)
│   ├── main/                  # Shell page with nested sub-navigator (id=1)
│   ├── home/                  # Recommend / Category / Ranking / Completion tabs
│   ├── reader/                # Scroll + page modes, dual-page, TTS, custom font
│   └── ... 
├── router/
│   ├── route_path.dart        # Static route constants
│   ├── app_pages.dart         # Main routes + sub-route switch
│   └── app_sub_router.dart    # Navigate inside nested navigator (id=1)
├── service/
│   ├── local_storage_service.dart # Hive-backed KV (settings, reader prefs, login)
│   ├── db_service.dart         # Drift query facade
│   ├── dev_mode_service.dart   # Dev tools toggle
│   └── tts_service.dart        # TTS engine (flutter_tts, system intents)
└── widgets/                   # Reusable widgets (state_page, custom_tile, etc.)
```

## Essential commands

```bash
flutter pub get                       # install deps
dart run build_runner build           # codegen (drift, json_serializable, hive_ce)
flutter analyze                       # lint (flutter_lints)
flutter test                          # minimal tests
dart run flutter_native_splash:create # splash screen
dart run flutter_launcher_icons       # app icons
flutter build apk --release           # universal APK
flutter build apk --release --split-per-abi  # per-ABI APKs
flutter build appbundle --release     # AAB
flutter build windows --release       # Windows portable
```

## Critical gotchas

### Network
- **All wenku8 API responses are GBK or Big5 encoded HTML**, not JSON. The parser expects decoded HTML strings.
- `Request.get()` → `Uint8List` → decode with `GbkDecoder`/`Big5Decoder` → `Success(decodedHtml)`.
- `dio` configured with `responseType: ResponseType.bytes`, `followRedirects: false` (manual 302 handling).
- Cloudflare 403/Challenge exceptions are caught by `CloudflareInterceptor` and return custom `DioException` subclasses.
- Cookie-based auth: cookies saved to/loaded from Hive via `LocalStorageService`.
- `Api.charsetsType` depends on user's language setting → determines GBK vs Big5 encoding.
- Image URLs go through `ImageUrlHelper.normalize()` + `fallback()` (domain mirroring handling).

### Database
- **Drift codegen**: After changing `entity.dart` or `database.dart`, run `dart run build_runner build`.
- Schema version is 4 with 4 migration steps in `MigrationStrategy`. If schema changes, bump version and add migration.
- `NovelDetailEntity` stores the full novel detail as a JSON string in a single column.
- `ReadHistoryEntity` tracks per-chapter position, reader mode, dual-page state.

### Routing
- **Two-level navigation**: `AppRoutes.mainRoutePages` for top-level routes, `AppSubRouter` (nested navigator `id=1`) for content pages within the main shell.
- `AppSubRouter._toContentPage()` uses `Get.offAndToNamed` vs `Get.toNamed` based on route dedup → avoids stacking same page.
- Route paths are static constants in `RoutePath`. Arguments passed via `settings.arguments`.

### State management (GetX)
- Services registered in `main.dart` via `Get.put()` → accessed with `Get.find<T>()` or `Get.findOrPut<T>()`.
- Pages use `controller.dart` + `view.dart` pattern. Controllers extend `GetxController`.
- Paginated lists extend `BaseListPageController<T>` → handles loading/refresh/load-more lifecycle via `getPage(loadMore)`.
- `PageState` enum drives UI via `StatePage` widget.

### Reader
- Two modes: scroll (`kScrollReadMode=1`) and page (`kPageReadMode=2`).
- Dual-page mode: auto/manual/disabled. Auto triggers on tablets ≥600dp in landscape.
- Reading direction: up-to-down, left-to-right, right-to-left.
- TTS: flutter_tts, voice/engine/rate/pitch/volume saved to Hive.
- Custom fonts via file picker → TTF metadata parsing.
- Background images, custom colors (day/night) for reader.
- Page turning animation toggle.

### Codegen triggers
| Command | When |
|---------|------|
| `build_runner build` | After editing Drift tables, json_serializable models, or Hive adapters |
| `flutter_native_splash:create` | After changing splash config in `pubspec.yaml` |
| `flutter_launcher_icons` | After changing icon config in `pubspec.yaml` |

### Translations
- `AppTranslations` keys are in `zh_CN` and `zh_TW` maps.
- All user-facing strings use `.tr` (GetX translation).
- Add new keys to BOTH locale maps.

### Export
- Cached chapters can be exported as .txt or .epub.
- Export path user-configurable via `file_picker`.
- Uses `archive` package for epub generation.

### Testing
- Only one placeholder widget test exists.
- No integration tests. No unit tests for controllers/services/parsers.
- Drift's `@DriftDatabase` and Dio make unit testing non-trivial (need to mock or inject).

### CI/CD
- GitHub Actions on tag push `v*` or manual workflow dispatch.
- Builds: Android (split APKs + universal + AAB) + Windows (zip).
- Android keystore: decoded from base64 secret `KEYSTORE_BASE64`.
- Flutter version pinned to `3.38.7` in CI.

### Branch workflow
- `main` = releases
- `develop` = PR target for feature work
- No conventional commits enforced; no PR template

### Dev mode
- `DevModeService` toggle (enables dev tools page in settings).
- Access via long-press or setting toggle (check source for exact trigger).
