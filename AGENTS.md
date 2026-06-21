# Hikari Novel — Agent Guide

## Project

Flutter third-party light novel client for [wenku8](https://www.wenku8.net).
- **SDK**: `^3.10.7`, channel stable. CI pins Flutter `3.38.7`.
- **State mgmt**: GetX (`GetxController`, `GetxService`, `obs`/`Rx`, `Get.put`/`find`/`findOrPut`)
- **Networking**: Dio bytes-mode + cookie_jar + Cloudflare interceptor
- **DB**: Drift (SQLite, 5 tables, schema v4) for structured data; Hive CE for KV settings
- **HTML**: All wenku8 data is GBK/Big5 → parsed with `html` package (no JSON API)
- **Platforms**: Android 6.0+, Windows 10+. macOS/iOS untested. No web, no Linux.

## Architecture

```
lib/
├── main.dart                    # Entry: InAppLocalhostServer, init services, runApp
├── base/
│   ├── base_list_page_controller.dart       # Paginated list controller
│   └── base_select_list_page_controller.dart # Multi-select variant
├── common/
│   ├── constants.dart           # kAppName, kScrollReadMode(1), kPageReadMode(2), etc.
│   ├── util.dart                # Locale, checkUpdate() version normalization
│   ├── extension.dart           # Get.findOrPut, ScreenInfo, GBK/Big5 URL encoding
│   ├── app_translations.dart    # zh_CN / zh_TW GetX translations (~315 keys each)
│   ├── database/                # Drift entities, database.g.dart, migration v1→v4
│   ├── log.dart                 # Logger wrapper (t/d/i/w/e/f levels)
│   ├── migration.dart           # DB + Hive migrations
│   ├── html_debug_logger.dart   # Dev-mode HTML dump tool
│   └── common_widgets.dart      # Shared widgets
├── models/                      # Data classes; some need codegen
│   ├── resource.dart            # sealed class Resource<T> { Success, Error }
│   ├── custom_exception.dart    # Cloudflare403Exception, CloudflareChallengeException
│   ├── page_state.dart          # PageState enum (loading, success, empty, error, etc.)
│   └── common/                  # Wenku8Node, CharsetsType, Language enums
├── network/
│   ├── request.dart             # Dio singleton, Cloudflare interceptor, cookie init
│   ├── api.dart                 # All wenku8 endpoints (GBK/Big5 URL encoding)
│   ├── parser.dart              # HTML → model parsers (~690 lines)
│   ├── chapter_downloader.dart  # Chapter caching with CancelToken
│   └── image_url_helper.dart    # normalize() + fallback() for image URLs
├── pages/                       # Each module: controller.dart + view.dart
│   ├── main/                    # Shell with nested sub-navigator (id=1)
│   ├── home/                    # Recommend / Category / Ranking / Completion tabs
│   └── reader/                  # Scroll + page modes, dual-page, TTS, custom font
├── router/
│   ├── route_path.dart          # Static route constants
│   ├── app_pages.dart           # AppRoutes.mainRoutePages + subRoutePages
│   └── app_sub_router.dart      # Navigation helper for nested navigator (id=1)
├── service/
│   ├── local_storage_service.dart  # Hive CE-backed KV (settings, reader prefs, login)
│   ├── db_service.dart            # Drift query facade
│   ├── dev_mode_service.dart      # Dev tools toggle (tap version 5× on About)
│   └── tts_service.dart           # flutter_tts, system intents
└── widgets/                    # Reusable widgets (state_page, custom_tile, etc.)
```

## Essential commands

```bash
flutter pub get                           # install deps
dart run build_runner build               # codegen: drift, json_serializable, hive_ce
flutter analyze                           # lint (flutter_lints, no custom rules)
flutter test                              # only 1 placeholder widget test (broken)
flutter build apk --release               # universal APK
flutter build apk --release --split-per-abi  # per-ABI APKs
flutter build appbundle --release         # AAB
flutter build windows --release           # Windows portable
```

Codegen commands (non-build_runner):
```bash
dart run flutter_native_splash:create     # after changing splash config
dart run flutter_launcher_icons           # after changing icon config
```

## Codegen overview

| Generator | Trigger | Output files |
|-----------|---------|-------------|
| `build_runner build` | Edit Drift entity | `common/database/database.g.dart` |
| `build_runner build` | Edit `@JsonSerializable` model | `models/novel_detail.g.dart`, `cat_chapter.g.dart`, `cat_volume.g.dart` |
| `build_runner build` | Edit `@HiveType` model | `models/user_info.g.dart`, `hive_registrar.g.dart` |
| `flutter_native_splash:create` | Change splash config in pubspec | native splash resources |
| `flutter_launcher_icons` | Change icon config in pubspec | native icon resources |

`user_info.dart` is the only Hive CE adapter (`@HiveType(typeId: 0, adapterName: "UserInfoAdapter")`).

## Critical gotchas

### Network
- **All wenku8 API responses are GBK or Big5 encoded HTML**, never JSON. `Request.get()` returns `Uint8List` → decode with `GbkDecoder`/`Big5Decoder` → `Success(decodedHtml)`.
- Dio configured with `responseType: ResponseType.bytes`, `followRedirects: false` (manual 302 handling via `_checkRedirects`). `validateStatus` accepts all status codes.
- Cloudflare interceptor returns `Cloudflare403Exception` (status 403) or `CloudflareChallengeException` (`cf-mitigated: challenge` header).
- **Two wenku8 nodes**: `www.wenku8.net` (default) and `www.wenku8.cc`. `Wenku8Node` enum controls node. All API URLs use `Api.wenku8Node.node`.
- Cookie auth: cookies stored in Hive via `LocalStorageService`. `initCookie()` saves cookies to BOTH wenku8 domains' cookie jars. `deleteCookie()` calls `_dioCookieJar.deleteAll()`.
- `Api.charsetsType` derives from `Language` setting: `gbk` for Simplified Chinese (default), `big5Hkscs` for Traditional Chinese. `Language.followSystem` checks `Get.deviceLocale`.
- Image URLs: `ImageUrlHelper.normalize()` handles protocol-relative (`//`) and root-relative (`/`) URLs. `fallback()` maps `pic.777743.xyz` → `img.wenku8.com`. **`pic.wenku8.com` is dead (404)** — always use `img.wenku8.com`.
- POST (book/comment/reply): uses `postForm()` with `Content-Type: application/x-www-form-urlencoded`. When body is already URL-encoded, pass `String` not `Map` (Dio double-encodes Maps).
- `chapter_downloader.dart`: downloads with `CancelToken` per task, progress callbacks. Files saved to `{appSupportDir}/cached_chapter/{aid}_{cid}.txt`.
- URL encoding for search/comment: uses `enough_convert` (`GbkEncoder`/`Big5Encoder`) → byte-wise `%XX` via extension `gbkUrlEncodingIfNotAscii()` / `big5UrlEncodingIfNotAscii()`. Only non-ASCII bytes are percent-encoded.

### Database
- Drift codegen: after changing `entity.dart` or `database.dart`, run `dart run build_runner build`.
- Schema version 4 with 3 migration steps (`fromOneToTwo`, `fromTwoToThree`, `fromThreeToFour`). Bump version + add migration when schema changes.
- 5 tables: `BookshelfEntity`, `BrowsingHistoryEntity`, `SearchHistoryEntity`, `ReadHistoryEntity`, `NovelDetailEntity`.
- `NovelDetailEntity` stores full novel detail as JSON string in a single column.
- `ReadHistoryEntity`: tracks per-chapter position, reader mode, dual-page state. `isLatest` flag marks last-read chapter per book. `upsertReadHistory` resets all `isLatest` for same `aid` before inserting.

### Routing
- **Two-level navigation**: `AppRoutes.mainRoutePages` (list of `CustomGetPage`) for top-level routes; `AppRoutes.subRoutePages` (function returning `Route<dynamic>?`) for content pages served through nested navigator `id=1`.
- `CustomGetPage` wrapper: disables parallax, disables pop gesture, uses `Curves.linear`, `Transition.native`. Accepts optional `fullscreen` bool (passed as `fullscreenDialog`).
- `AppSubRouter._toContentPage()`: uses `Get.offAndToNamed` (if target === current route) vs `Get.toNamed` (if different) to avoid stacking the same page.
- Arguments passed via `settings.arguments` — typed casts happen inside `subRoutePages`. Sub-routes use `GetPageRoute` (not `CustomGetPage`).
- 18 route constants in `RoutePath`. Top-level: main, home, login, photo, reader, welcome, readerSetting. Sub-routes: logo, novelDetail, comment, reply, userBookshelf, browsingHistory, userInfo, about, setting, search, cacheQueue, devTools.

### State management (GetX)
- Services registered in `main.dart` via `Get.put()` → accessed with `Get.find<T>()` or extension `Get.findOrPut<T>()`.
- Pages: `controller.dart` + `view.dart` pattern. Controllers extend `GetxController`.
- Paginated lists extend `BaseListPageController<T>`: handles loading/refresh/load-more via `getPage(loadMore)`. Subclasses override `getData(int index)` (calls API) and `getParser(String html)` (parses list items into `List<T>`).
- `BaseSelectListPageController` variant for multi-select (e.g., batch cache deletion).
- `PageState` enum drives UI via `StatePage` widget: loading, success, empty, error, pleaseSelect, jumpToOtherPage, inFiveSecond, bookshelfContent, bookshelfSearch, placeholder.
- `Resource<T>` sealed class: `Success<T>(T data)` / `Error(dynamic error)` — used as API result wrapper throughout.

### Reader
- Two modes: scroll (`kScrollReadMode=1`) and page (`kPageReadMode=2`).
- Dual-page: auto/manual/disabled. Auto triggers on tablets ≥600dp in landscape (`isTabletLikeScreen`/`shouldAutoUseDualPage` in `ScreenInfo` extension).
- Reading direction: `ReaderDirection` enum (up-to-down, left-to-right, right-to-left).
- TTS: `flutter_tts`. Voice/engine/rate/pitch/volume saved to Hive via `TtsService`.
- Custom fonts via file picker → TTF metadata parsing (`ttf_metadata` package).
- Background images, custom colors (day/night) for reader, page turning animation toggle.
- `Content` model: `text` (processed paragraphs with 3-space indent on first line) + `images` (extracted `<img>` src list). Parser removes `ul#contentdp`, strips whitespace, joins paragraphs on blank lines.

### Export
- Cached chapters exportable as `.txt` or `.epub`. Uses `archive` package for epub generation.
- Export path user-configurable via `file_picker` (locked at `10.3.10` — 11.x uses static API requiring separate refactor).

### Translations
- `AppTranslations` keys in `zh_CN` and `zh_TW` maps (~315 keys each). All user-facing strings use `.tr` (GetX translation).
- Add new keys to BOTH locale maps. Fallback locale `zh_CN`.

### Update check
- `checkUpdate()` in `lib/common/util.dart`. Update URL: `api.github.com/repos/SmilE-nya/hikari_novel_flutter/releases/latest`.
- Version normalization: strips `v` prefix AND `+build` number from both local (`PackageInfo`) and remote versions before comparison. Prevents false "new version available" dialog for same version with different build number.

### CI/CD
- GitHub Actions on tag push `v*` or `workflow_dispatch`. **Android only** — split APKs + universal APK + AAB. Windows build removed from CI.
- Flutter 3.38.7, Java 17 (zulu), `actions/checkout@v5`, `setup-java@v5`, `subosito/flutter-action@v2`, `upload-artifact@v6`, `download-artifact@v7`, `softprops/action-gh-release@v3`.
- CI auto-rewrites `pubspec.yaml` version from git tag: strips `v` prefix, appends `+0` if no build number present.
- Android keystore decoded from base64 secret `KEYSTORE_BASE64`. Falls back to debug keystore when absent (no signing for PR/forks).

### Branch workflow
- `main` = releases. `develop` = PR target for feature work. No conventional commits, no PR template.

### Dev mode
- `DevModeService` toggle. Trigger: tap version label 5 times on About page → toast + auto-navigate to dev tools.
- `HtmlDebugLogger` (dev mode only): logs HTML responses to `{documentsDir}/html_debug.txt` and dumps to `{documentsDir}/html_dumps/`. All methods are no-ops when dev mode is off.

### Platform specifics
- **Windows**: Requires WebView2 runtime. `main.dart` asserts `WebViewEnvironment.getAvailableVersion()` on startup. Font: `Microsoft YaHei`.
- **Android**: `InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode)`. Edge-to-edge system UI mode set in `_init()`.
- **iOS/macOS**: Untested. No platform-specific code beyond generic Flutter SDK.
- `InAppLocalhostServer` runs at startup, document root: `assets/`.
- Dynamic color: `dynamic_color` package with `DynamicColorBuilder`. Falls back to `ColorScheme.fromSeed` with user-configured brand color.
