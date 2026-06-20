# Hikari Novel — Agent Guide

## Project

Hikari Novel: Flutter third-party light novel client for [wenku8](https://www.wenku8.net).
- **SDK**: ^3.10.7, channel stable
- **State mgmt**: GetX (GetxController, GetxService, obs/Rx, Get.put/find)
- **Networking**: Dio + cookie_jar + Cloudflare interceptor (403/challenge)
- **DB**: Drift (SQLite, 5 tables) for structured data; Hive CE for KV settings
- **HTML**: All wenku8 data is GBK/Big5 → parsed with `html` package (no JSON API)
- **Platforms**: Android (6.0+), Windows (10+), macOS/iOS (untested). No web, no Linux.

## Key architecture

```
lib/
├── main.dart                    # Entry: InAppLocalhostServer, init services, runApp
├── base/                        # BaseListPageController + BaseSelectListPageController
├── common/
│   ├── constants.dart           # App-wide constants
│   ├── util.dart                # Locale, update check
│   ├── extension.dart           # Get.findOrPut, screen info, GBK/Big5 URL encoding
│   ├── app_translations.dart    # zh_CN / zh_TW GetX translations
│   ├── database/                # Drift schema (5 tables), migration v1→v4
│   ├── log.dart                 # Logger wrapper (log levels: t/d/i/w/e/f)
│   ├── migration.dart           # DB migrations
│   ├── html_debug_logger.dart   # Dev-mode HTML dump tool
│   └── common_widgets.dart      # Shared widgets (bookshelf action bar, etc.)
├── models/                      # Data classes (json_serializable, sealed Resource<T>)
│   └── common/                  # Wenku8Node enum, CharsetsType, Language enums
├── network/
│   ├── request.dart             # Dio singleton, cookie init, Cloudflare interceptor
│   ├── api.dart                 # All wenku8 API endpoints (GBK/Big5 URL encoding)
│   ├── parser.dart              # HTML → model parsers (~690 lines)
│   ├── chapter_downloader.dart  # Chapter caching with CancelToken
│   └── image_url_helper.dart    # Image URL normalization + fallback
├── pages/                       # 23 page modules (controller.dart + view.dart)
│   ├── main/                    # Shell page with nested sub-navigator (id=1)
│   ├── home/                    # Recommend / Category / Ranking / Completion tabs
│   └── reader/                  # Scroll + page modes, dual-page, TTS, custom font
├── router/
│   ├── route_path.dart          # Static route constants
│   ├── app_pages.dart           # Main routes + sub-route switch
│   └── app_sub_router.dart      # Navigate inside nested navigator (id=1)
├── service/
│   ├── local_storage_service.dart  # Hive-backed KV (settings, reader prefs, login)
│   ├── db_service.dart            # Drift query facade
│   ├── dev_mode_service.dart      # Dev tools toggle
│   └── tts_service.dart           # TTS engine (flutter_tts, system intents)
└── widgets/                    # Reusable widgets (state_page, custom_tile, etc.)
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
- **All wenku8 API responses are GBK or Big5 encoded HTML**, not JSON. Parser expects decoded HTML strings.
- `Request.get()` → `Uint8List` → decode with `GbkDecoder`/`Big5Decoder` → `Success(decodedHtml)`.
- `dio` configured with `responseType: ResponseType.bytes`, `followRedirects: false` (manual 302 handling via `_checkRedirects`).
- Cloudflare interceptor returns custom `DioException` subclasses: `Cloudflare403Exception` (status 403) and `CloudflareChallengeException` (`cf-mitigated: challenge` header).
- **Two possible wenku8 nodes**: `www.wenku8.net` (default) and `www.wenku8.cc` — user configurable via settings. `Wenku8Node` enum controls which node is used. All API URLs use `Api.wenku8Node.node`.
- Cookie-based auth: cookies saved to/loaded from Hive via `LocalStorageService`. `initCookie()` parses cookie string from Hive and stores in both wenku8 domains' cookie jars.
- `Api.charsetsType` derives from user's `Language` setting: `gbk` for Simplified Chinese, `big5Hkscs` for Traditional Chinese.
- Image URLs: `ImageUrlHelper.normalize()` handles protocol-relative (`//`) and root-relative (`/`) URLs. `fallback()` provides alternate domain for `pic.777743.xyz` → `img.wenku8.com`. Note: `pic.wenku8.com` is dead (404), always use `img.wenku8.com`.
- Book/comment/reply POST requests use `postForm()` with `Content-Type: application/x-www-form-urlencoded`. When body contains URL-encoded content, use `String` not `Map` (Dio double-encodes Maps).
- `chapter_downloader.dart`: Downloads use `CancelToken` per task. Supports progress callbacks. Files saved to `{appSupportDir}/cached_chapter/{aid}_{cid}.txt`.

### Database
- **Drift codegen**: After changing `entity.dart` or `database.dart`, run `dart run build_runner build`.
- Schema version is 4 with 3 migration steps (`fromOneToTwo`, `fromTwoToThree`, `fromThreeToFour`). If schema changes, bump version and add migration.
- 5 tables: `BookshelfEntity`, `BrowsingHistoryEntity`, `SearchHistoryEntity`, `ReadHistoryEntity`, `NovelDetailEntity`.
- `NovelDetailEntity` stores the full novel detail as a JSON string in a single column.
- `ReadHistoryEntity` tracks per-chapter position, reader mode, dual-page state. `isLatest` flag marks last-read chapter per book. `upsertReadHistory` resets all `isLatest` for the same `aid` before inserting.

### Routing
- **Two-level navigation**: `AppRoutes.mainRoutePages` for top-level routes; `AppRoutes.subRoutePages` (returns raw `Route`) for content pages served through the nested navigator `id=1`.
- `AppSubRouter._toContentPage()` uses `Get.offAndToNamed` (if same route) vs `Get.toNamed` (if different) to avoid stacking the same page.
- 20 route constants in `RoutePath`. At top level: main, home, login, photo, reader, welcome, readerSetting. Sub-routes: 13 content pages.
- Arguments passed via `settings.arguments` — typed casts happen in `subRoutePages`.
- `CustomGetPage` wrapper: disables parallax, disables pop gesture, uses linear curve.

### State management (GetX)
- Services registered in `main.dart` via `Get.put()` → accessed with `Get.find<T>()` or `Get.findOrPut<T>()`.
- Pages use `controller.dart` + `view.dart` pattern. Controllers extend `GetxController`.
- Paginated lists extend `BaseListPageController<T>`: handles loading/refresh/load-more via `getPage(loadMore)`. Subclasses override `getData(int index)` (calls API) and `getParser(String html)` (parses list items).
- `BaseSelectListPageController` variant exists for multi-select operations.
- `PageState` enum drives UI via `StatePage` widget (loading, success, error, empty, etc.).
- `Resource<T>` is a sealed class: `Success<T>(T data)` / `Error(error)` — used as API result wrapper.

### Reader
- Two modes: scroll (`kScrollReadMode=1`) and page (`kPageReadMode=2`).
- Dual-page mode: auto/manual/disabled. Auto triggers on tablets ≥600dp in landscape (`isTabletLikeScreen`/`shouldAutoUseDualPage` in extension).
- Reading direction: up-to-down, left-to-right, right-to-left.
- TTS: flutter_tts, voice/engine/rate/pitch/volume saved to Hive.
- Custom fonts via file picker → TTF metadata parsing.
- Background images, custom colors (day/night) for reader.
- Page turning animation toggle.
- `Content` model has two fields: `text` (processed paragraphs with indentation) and `images` (extracted `<img>` src list). Parser removes `ul#contentdp` elements, strips trailing/leading whitespace, joins paragraphs on blank lines, and inserts 3-space indent on first line of each paragraph.

### Codegen triggers
| Command | When |
|---------|------|
| `build_runner build` | After editing Drift tables, json_serializable models (`@JsonSerializable`), or Hive adapters |
| `flutter_native_splash:create` | After changing splash config in `pubspec.yaml` |
| `flutter_launcher_icons` | After changing icon config in `pubspec.yaml` |

Models needing codegen: `cat_chapter.dart`, `cat_volume.dart`, `novel_detail.dart`, `user_info.dart` (json_serializable). Drift generates `database.g.dart`.

### Translations
- `AppTranslations` keys are in `zh_CN` and `zh_TW` maps (~315 keys each).
- All user-facing strings use `.tr` (GetX translation).
- Add new keys to BOTH locale maps.

### Export
- Cached chapters can be exported as .txt or .epub.
- Export path user-configurable via `file_picker`.
- Uses `archive` package for epub generation.

### Testing
- Only one placeholder widget test exists (broken — expects counter app, not Hikari Novel).
- No integration tests. No unit tests for controllers/services/parsers.
- Drift's `@DriftDatabase` and Dio make unit testing non-trivial (need to mock or inject).

### CI/CD
- GitHub Actions on tag push `v*` or manual workflow dispatch.
- **Android only** (split APKs + universal + AAB). Windows build removed from CI.
- Android keystore: decoded from base64 secret `KEYSTORE_BASE64`.
- Flutter version pinned to `3.38.7` in CI.
- CI generates debug keystore when `KEYSTORE_BASE64` is absent.

### Branch workflow
- `main` = releases
- `develop` = PR target for feature work
- No conventional commits enforced; no PR template

### Dev mode
- `DevModeService` toggle (enables "开发者设置" page in settings).
- **Trigger**: Tap version label 5 times on the About page → toast + auto-navigate to dev tools.
- `HtmlDebugLogger` (when dev mode enabled): logs HTML responses to `{documentsDir}/html_debug.txt` and full HTML dumps to `{documentsDir}/html_dumps/`. All methods are no-ops when dev mode is off.

### Platform specifics
- **Windows**: Requires WebView2 runtime. `main.dart` asserts `WebViewEnvironment.getAvailableVersion()` on startup.
- **Android**: `InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode)` for webview debugging.
- **iOS/macOS**: Untested. No platform-specific code beyond generic Flutter SDK.
- `InAppLocalhostServer` runs at startup to serve local assets (document root: `assets/`).

### Language & encoding
- Three `Language` values: `simplifiedChinese`, `traditionalChinese`, `followSystem`.
- `followSystem` → `zh_CN` → GBK, `zh_TW` → Big5; defaults to GBK for other locales.
- Search queries and comment/reply content are URL-encoded per charset using `enough_convert` library (GbkEncoder/Big5Encoder → byte-wise `%XX`).
