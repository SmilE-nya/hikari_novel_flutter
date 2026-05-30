# Tablet Adaptation — 平板3列网格 + 自定义列数

## TL;DR
> **Summary**: 为所有网格页面添加可配置的列数限制（默认3列），并为浏览历史和用户书架页添加列表/网格切换功能，所有网格列数统一由设置控制。
> **Deliverables**: 7 个 grid 页面约束列数 + 2 个列表页添加 grid 模式 + 设置页 UI + 存储/状态层
> **Effort**: Medium (10-14 tasks)
> **Parallel**: YES — 3 waves
> **Critical Path**: Data layer (W1) → Settings UI + Translations (W2) → Page updates (W3-W4)

## Context
### Original Request
用户要求让平板也显示3列网格布局，经过沟通后确认：用户可自选列数（默认3列），浏览历史与用户书架支持列表/网格切换，网格列数统一。

### Codebase Analysis
- **响应式网格库**: `responsive_grid_list` 已引入，7 个页面使用 `ResponsiveGridList(minItemWidth: 100)`
- **设置系统**: `LocalStorageService` (Hive) + `SettingController` (GetX) + `Obx` 响应
- **翻译系统**: `app_translations.dart` (zh_CN + zh_TW)，`.tr` 访问
- **UI 组件**: `NormalTile`, `SwitchTile`, `RadioListDialog` 已在设置页使用

### Metis Review
N/A (Metis timed out, self-reviewed)

## Work Objectives
### Core Objective
为所有包含小说封面的页面提供可配置的网格列数控制

### Deliverables
1. `LocalStorageService` 新增 3 个持久化 key
2. `SettingController` 新增 3 个 Rx 字段
3. `app_translations.dart` 新增 6 条翻译
4. 设置页新增列数选择 + 布局切换 UI
5. 7 个 grid 页面添加 `maxItemsPerRow` 约束
6. 浏览历史页支持列表/网格切换
7. 用户书架页支持列表/网格切换

### Definition of Done
- 运行 `flutter build apk --release` 成功
- 设置页显示「网格列数」选择项（可选手动输入 1-6）
- 浏览历史页设置项切换列表/网格模式
- 用户书架页设置项切换列表/网格模式
- 所有网格页面的列数跟随「网格列数」设置变化
- `maxItemsPerRow` 生效，平板 3 列时卡片合理放大

### Must Have
- 列数设置持久化（关闭 app 后保留）
- 设置修改即时生效（无需重启 app）

### Must NOT Have
- 不修改阅读器页面布局
- 不修改侧边栏/导航结构
- 不重构现有 ResponsiveGridList 之外的网格方案

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: tests-after (app has no existing test infra)
- QA policy: Every task has agent-executed scenarios via `flutter build`
- Evidence: .sisyphus/evidence/task-{N}-{slug}.txt

## Execution Strategy
### Parallel Execution Waves

Wave 1: Foundation — data layer (LocalStorageService + SettingController)
Wave 2: Settings UI — translations + setting page widgets
Wave 3: Pages — grid update + list/grid conversions (can parallelize within wave)

### Dependency Matrix
| Task | Depends On |
|------|-----------|
| T1 (LocalStorageService) | - |
| T2 (SettingController) | T1 |
| T3 (Translations) | - |
| T4 (Settings UI) | T2, T3 |
| T5 (Grid pages) | T2 |
| T6 (Browsing history) | T2 |
| T7 (User bookshelf) | T2 |

### Agent Dispatch Summary
Wave 1: 2 tasks — data layer
Wave 2: 2 tasks — UI layer
Wave 3: 3 tasks — page adaptation

## TODOs

- [ ] 1. Add grid layout settings to LocalStorageService

  **What to do**:
  1. Open `lib/service/local_storage_service.dart`
  2. Add 3 new constants in the `static const String` block:
     - `kGridColumnCount = "gridColumnCount"`
     - `kBrowsingHistoryLayout = "browsingHistoryLayout"`
     - `kUserBookshelfLayout = "userBookshelfLayout"`
  3. Add getter/setter pairs for each:

     ```dart
     int getGridColumnCount() => _setting.get(kGridColumnCount, defaultValue: 3);
     void setGridColumnCount(int value) => _setting.put(kGridColumnCount, value);

     int getBrowsingHistoryLayout() => _setting.get(kBrowsingHistoryLayout, defaultValue: 0); // 0=list, 1=grid
     void setBrowsingHistoryLayout(int value) => _setting.put(kBrowsingHistoryLayout, value);

     int getUserBookshelfLayout() => _setting.get(kUserBookshelfLayout, defaultValue: 0);
     void setUserBookshelfLayout(int value) => _setting.put(kUserBookshelfLayout, value);
     ```

  **Must NOT do**: Don't modify existing keys or methods. Don't change the Box used (should be `_setting` box).

  **Recommended Agent Profile**:
  - Category: `quick` - Simple boilerplate additions to existing pattern
  - Skills: [] - No special skills needed

  **Parallelization**: Wave 1 | Blocks: T2 | Blocked By: none

  **References**:
  - Pattern: `lib/service/local_storage_service.dart:82-84` — existing `setIsAutoCheckUpdate` / `getIsAutoCheckUpdate` pattern
  - Type: `int` getter/setter (like `getReaderParaIndent` at line 239)

  **Acceptance Criteria**:
  - [ ] `GetIt` / `Get.find<LocalStorageService>().getGridColumnCount()` returns 3 before any set
  - [ ] `getGridColumnCount()` returns stored value after `setGridColumnCount(4)`

  **QA Scenarios**:
  ```
  Scenario: Default value
    Tool: interactive_bash
    Steps: Read file, verify default values match expected (3 for column count, 0 for layout modes)
    Expected: compile-clean code with correct defaults

  Scenario: Read-after-write
    Tool: interactive_bash
    Steps: Verify setter stores correct type and getter retrieves it
    Expected: value round-trips correctly
  ```

  **Commit**: YES | Message: `feat(storage): add grid layout settings keys` | Files: [`lib/service/local_storage_service.dart`]

- [ ] 2. Add grid layout fields to SettingController

  **What to do**:
  1. Open `lib/pages/setting/controller.dart`
  2. Add 3 Rx fields after existing fields (line 17):
     ```dart
     RxInt gridColumnCount = LocalStorageService.instance.getGridColumnCount().obs;
     RxInt browsingHistoryLayout = LocalStorageService.instance.getBrowsingHistoryLayout().obs;
     RxInt userBookshelfLayout = LocalStorageService.instance.getUserBookshelfLayout().obs;
     ```
  3. Add 3 change methods (after `changeThemeMode` at line 66):
     ```dart
     void changeGridColumnCount(int value) {
       gridColumnCount.value = value;
       LocalStorageService.instance.setGridColumnCount(value);
     }

     void changeBrowsingHistoryLayout(int value) {
       browsingHistoryLayout.value = value;
       LocalStorageService.instance.setBrowsingHistoryLayout(value);
     }

     void changeUserBookshelfLayout(int value) {
       userBookshelfLayout.value = value;
       LocalStorageService.instance.setUserBookshelfLayout(value);
     }
     ```

  **Must NOT do**: Don't remove existing fields. Don't call `Get.forceAppUpdate()` unless needed.

  **Recommended Agent Profile**:
  - Category: `quick` - Simple additions following existing pattern
  - Skills: [] - No special skills needed

  **Parallelization**: Wave 1 | Blocks: T4, T5, T6, T7 | Blocked By: T1

  **References**:
  - Pattern: `lib/pages/setting/controller.dart:11-17` — existing Rx fields
  - Pattern: `lib/pages/setting/controller.dart:19-27` — existing change methods (e.g., `changeIsRelativeTime`)

  **Acceptance Criteria**:
  - [ ] `Get.find<SettingController>().gridColumnCount.value` is reactive (Obx updates when changed)

  **QA Scenarios**:
  ```
  Scenario: Reactive update
    Tool: interactive_bash
    Steps: Read file, verify all new fields use `.obs`, all change methods call LocalStorageService setter
    Expected: Pattern matches existing implementation (e.g., isRelativeTime)
  ```

  **Commit**: YES | Message: `feat(settings): add grid layout fields to controller` | Files: [`lib/pages/setting/controller.dart`]

- [ ] 3. Add translations for grid layout settings

  **What to do**:
  1. Open `lib/common/app_translations.dart`
  2. Add to `zh_CN` map (before closing brace at line 296):
     ```
     "grid_columns": "网格列数",
     "browsing_history_layout": "浏览历史布局",
     "user_bookshelf_layout": "用户书架布局",
     "list_mode": "列表模式",
     "grid_mode": "网格模式",
     "columns_count": "列数",
     ```
  3. Add to `zh_TW` map (before closing brace at line 588):
     ```
     "grid_columns": "網格列數",
     "browsing_history_layout": "瀏覽記錄佈局",
     "user_bookshelf_layout": "用戶書架佈局",
     "list_mode": "列表模式",
     "grid_mode": "網格模式",
     "columns_count": "列數",
     ```
  4. Verify no duplicate keys exist

  **Must NOT do**: Don't remove existing translations. Don't add duplicate keys.

  **Recommended Agent Profile**:
  - Category: `quick` - Simple dictionary entries
  - Skills: [] - No special skills needed

  **Parallelization**: Wave 2 | Blocks: T4 | Blocked By: none

  **References**:
  - File: `lib/common/app_translations.dart` — full translations structure
  - Pattern: lines 120-121 — existing settings translations like "node", "auto_check_update"

  **Acceptance Criteria**:
  - [ ] `.tr` works: `"grid_columns".tr` returns correct Chinese text

  **QA Scenarios**:
  ```
  Scenario: Translation lookup
    Tool: interactive_bash
    Steps: Read file, confirm new keys exist in both zh_CN and zh_TW maps
    Expected: 6 keys added to each locale
  ```

  **Commit**: YES | Message: `feat(i18n): add grid layout translations` | Files: [`lib/common/app_translations.dart`]

- [ ] 4. Add grid layout settings UI to SettingPage

  **What to do**:
  1. Open `lib/pages/setting/view.dart`
  2. After the auto_check_update SwitchTile (line 127, before closing `child` Column), add 3 new tiles:

     **Grid column count selector**:
     ```dart
     Obx(() {
       final sub = "${controller.gridColumnCount.value} ${"columns_count".tr}";
       return NormalTile(
         title: "grid_columns".tr,
         subtitle: sub,
         leading: const Icon(Icons.grid_view_outlined),
         onTap: () =>
             Get.dialog(
               RadioListDialog<int>(
                 value: controller.gridColumnCount.value,
                 values: List.generate(6, (i) => (i + 1, "${i + 1} ${"columns_count".tr}")),
                 title: "grid_columns".tr,
               ),
             ).then((value) {
               if (value != null) controller.changeGridColumnCount(value);
             }),
       );
     }),
     ```

     **Browsing history layout toggle**:
     ```dart
     Obx(() {
       final sub = controller.browsingHistoryLayout.value == 0 ? "list_mode".tr : "grid_mode".tr;
       return NormalTile(
         title: "browsing_history_layout".tr,
         subtitle: sub,
         leading: const Icon(Icons.history),
         onTap: () =>
             Get.dialog(
               RadioListDialog<int>(
                 value: controller.browsingHistoryLayout.value,
                 values: [(0, "list_mode".tr), (1, "grid_mode".tr)],
                 title: "browsing_history_layout".tr,
               ),
             ).then((value) {
               if (value != null) controller.changeBrowsingHistoryLayout(value);
             }),
       );
     }),
     ```

     **User bookshelf layout toggle**:
     ```dart
     Obx(() {
       final sub = controller.userBookshelfLayout.value == 0 ? "list_mode".tr : "grid_mode".tr;
       return NormalTile(
         title: "user_bookshelf_layout".tr,
         subtitle: sub,
         leading: const Icon(Icons.book_outlined),
         onTap: () =>
             Get.dialog(
               RadioListDialog<int>(
                 value: controller.userBookshelfLayout.value,
                 values: [(0, "list_mode".tr), (1, "grid_mode".tr)],
                 title: "user_bookshelf_layout".tr,
               ),
             ).then((value) {
               if (value != null) controller.changeUserBookshelfLayout(value);
             }),
       );
     }),
     ```
  3. Make sure `import` for `RadioListDialog` is already present (it's used in existing code via `custom_tile.dart`)

  **Must NOT do**: Don't break existing setting items. Don't add imports that already exist.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - UI work matching existing setting page patterns
  - Skills: [] - No special skills needed

  **Parallelization**: Wave 2 | Blocks: none | Blocked By: T2, T3

  **References**:
  - Pattern: `lib/pages/setting/view.dart:91-106` — existing `NormalTile` usage (like "node" selector with RadioListDialog)
  - Widget: `NormalTile` at `lib/widgets/custom_tile.dart:5`
  - Widget: `RadioListDialog` at `lib/widgets/custom_tile.dart:95`

  **Acceptance Criteria**:
  - [ ] 3 new setting items visible on settings page
  - [ ] Column count dialog shows options 1-6
  - [ ] Selecting a value updates the UI immediately

  **QA Scenarios**:
  ```
  Scenario: Build succeeds
    Tool: interactive_bash
    Steps: Run `flutter build apk --release` (or just analyze: `dart analyze lib/pages/setting/view.dart`)
    Expected: No compilation errors
  ```

  **Commit**: YES | Message: `feat(settings): add grid layout UI to settings page` | Files: [`lib/pages/setting/view.dart`]

- [ ] 5. Update all 7 grid pages to use maxItemsPerRow from settings

  **What to do**:
  For each of the 7 files, add `maxItemsPerRow` to the `ResponsiveGridList` and import SettingController:
  - `lib/pages/category/view.dart`
  - `lib/pages/completion/view.dart`
  - `lib/pages/search/view.dart`
  - `lib/pages/ranking/view.dart`
  - `lib/pages/bookshelf/widgets/bookshelf_content_view.dart`
  - `lib/pages/bookshelf/widgets/bookshelf_search_view.dart`
  - `lib/pages/recommend/widgets/recommend_block_view.dart`

  For each file:
  1. Add import: `import 'package:hikari_novel_flutter/pages/setting/controller.dart';`
  2. In the build method, add before the `return`: `final settingController = Get.find<SettingController>();`  
  3. Change `ResponsiveGridList(minItemWidth: 100, ...)` to `ResponsiveGridList(minItemWidth: 100, maxItemsPerRow: settingController.gridColumnCount.value, ...)`

  **Important**: For pages that are `StatelessWidget` (all 7 are), use `Get.find<SettingController>()` inside build. This is already a pattern used in the codebase.

  **For `recommend_block_view.dart`**: It's inside a `ListView` with `shrinkWrap: true`. The `maxItemsPerRow` will work correctly here too since `ResponsiveGridList` uses `LayoutBuilder`.

  **Must NOT do**: Don't refactor the widgets to StatefulWidget. Don't remove `minItemWidth: 100`. Don't modify the import structure beyond adding the one import.

  **Recommended Agent Profile**:
  - Category: `quick` - Mechanical changes across 7 files (same pattern)
  - Skills: [] - No special skills needed

  **Parallelization**: Wave 3 | Blocks: none | Blocked By: T2

  **References**:
  - File: `lib/pages/category/view.dart:56-59` — existing ResponsiveGridList pattern
  - API: `maxItemsPerRow` parameter of `ResponsiveGridList` (from `responsive_grid_list` package)

  **Acceptance Criteria**:
  - [ ] All 7 files updated with `maxItemsPerRow: settingController.gridColumnCount.value`
  - [ ] `Get.find<SettingController>()` import added to all 7 files

  **QA Scenarios**:
  ```
  Scenario: All files compile
    Tool: interactive_bash
    Steps: Run `dart analyze lib/pages/category/view.dart lib/pages/completion/view.dart lib/pages/search/view.dart lib/pages/ranking/view.dart lib/pages/bookshelf/widgets/bookshelf_content_view.dart lib/pages/bookshelf/widgets/bookshelf_search_view.dart lib/pages/recommend/widgets/recommend_block_view.dart`
    Expected: No errors
  ```

  **Commit**: YES | Message: `feat(grid): add maxItemsPerRow from settings to all grid pages` | Files: [all 7 files]

- [ ] 6. Convert BrowsingHistoryPage to support list/grid toggle

  **What to do**:
  1. Open `lib/pages/browsing_history/view.dart`
  2. Add imports:
     ```dart
     import 'package:responsive_grid_list/responsive_grid_list.dart';
     import 'package:hikari_novel_flutter/pages/setting/controller.dart';
     import 'package:hikari_novel_flutter/widgets/novel_cover_card.dart';
     import 'package:hikari_novel_flutter/models/novel_cover.dart';
     ```
  3. Replace the current ListView (lines 29-38) with an `Obx` widget that switches between list and grid:

     ```dart
     child: Obx(() {
       final settingController = Get.find<SettingController>();
       if (settingController.browsingHistoryLayout.value == 0) {
         // List mode (current layout)
         return ListView(
           children: controller.list.map((item) {
             return BrowsingHistoryCard(
               vh: item,
               onTap: () => AppSubRouter.toNovelDetail(aid: item.aid),
               onDelete: () => DBService.instance.deleteBrowsingHistory(item.aid),
             );
           }).toList(),
         );
       } else {
         // Grid mode
         return Padding(
           padding: const EdgeInsets.all(8),
           child: ResponsiveGridList(
             minItemWidth: 100,
             horizontalGridSpacing: 4,
             verticalGridSpacing: 4,
             maxItemsPerRow: settingController.gridColumnCount.value,
             children: controller.list.map((item) {
               return NovelCoverCard(
                 novelCover: NovelCover(item.title, item.img, item.aid),
               );
             }).toList(),
           ),
         );
       }
     }),
     ```

  **Must NOT do**: Don't delete the BrowsingHistoryCard widget (still needed for list mode). Don't remove the import for `browsing_history_card.dart`.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - UI with conditional layout
  - Skills: [] - No special skills needed

  **Parallelization**: Wave 3 | Blocks: none | Blocked By: T2

  **References**:
  - Pattern: `lib/pages/bookshelf/widgets/bookshelf_search_view.dart:62-69` — existing usage of ResponsiveGridList + NovelCoverCard with title/img/aid constructor
  - Model: `NovelCover` at `lib/models/novel_cover.dart` — constructor: `NovelCover(title, img, aid)`

  **Acceptance Criteria**:
  - [ ] Browse history shows list mode by default
  - [ ] Toggling setting to grid mode shows grid of cover cards

  **QA Scenarios**:
  ```
  Scenario: Both modes compile
    Tool: interactive_bash
    Steps: Run `dart analyze lib/pages/browsing_history/view.dart`
    Expected: No errors
  ```

  **Commit**: YES | Message: `feat(browsing-history): add grid mode toggle` | Files: [`lib/pages/browsing_history/view.dart`]

- [ ] 7. Convert UserBookshelfPage to support list/grid toggle

  **What to do**:
  1. Open `lib/pages/user_bookshelf/view.dart`
  2. Add imports:
     ```dart
     import 'package:responsive_grid_list/responsive_grid_list.dart';
     import 'package:hikari_novel_flutter/pages/setting/controller.dart';
     import 'package:hikari_novel_flutter/widgets/novel_cover_card.dart';
     ```
  3. Replace the `_buildPage` method (lines 37-43) with:

     ```dart
     Widget _buildPage() {
       if (controller.list.value == null) return LoadingPage();
       if (controller.list.value!.isEmpty) return EmptyPage();
       final settingController = Get.find<SettingController>();
       if (settingController.userBookshelfLayout.value == 0) {
         // List mode (current layout)
         return ListView.builder(
           itemCount: controller.list.value!.length,
           itemBuilder: (context, index) => UserNovelCard(novelCover: controller.list.value![index]),
         );
       } else {
         // Grid mode
         return Padding(
           padding: const EdgeInsets.all(8),
           child: ResponsiveGridList(
             minItemWidth: 100,
             horizontalGridSpacing: 4,
             verticalGridSpacing: 4,
             maxItemsPerRow: settingController.gridColumnCount.value,
             children: controller.list.value!.map((item) {
               return NovelCoverCard(novelCover: item);
             }).toList(),
           ),
         );
       }
     }
     ```

  **Must NOT do**: Don't delete the UserNovelCard widget (still needed for list mode).

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - UI with conditional layout
  - Skills: [] - No special skills needed

  **Parallelization**: Wave 3 | Blocks: none | Blocked By: T2

  **References**:
  - Pattern: `lib/pages/user_bookshelf/view.dart:37-43` — existing _buildPage method
  - Pattern: `lib/pages/category/view.dart:56-63` — existing ResponsiveGridList + NovelCoverCard usage

  **Acceptance Criteria**:
  - [ ] User bookshelf shows list mode by default
  - [ ] Toggling setting to grid mode shows grid of cover cards

  **QA Scenarios**:
  ```
  Scenario: Both modes compile
    Tool: interactive_bash
    Steps: Run `dart analyze lib/pages/user_bookshelf/view.dart`
    Expected: No errors
  ```

  **Commit**: YES | Message: `feat(user-bookshelf): add grid mode toggle` | Files: [`lib/pages/user_bookshelf/view.dart`]

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
- [ ] F1. Plan Compliance Audit — oracle
- [ ] F2. Code Quality Review — unspecified-high
- [ ] F3. Build Verification — Run `flutter build apk --release`
- [ ] F4. Scope Fidelity Check — deep

## Commit Strategy
7 commits in order:
1. `feat(storage): add grid layout settings keys`
2. `feat(settings): add grid layout fields to controller`
3. `feat(i18n): add grid layout translations`
4. `feat(settings): add grid layout UI to settings page`
5. `feat(grid): add maxItemsPerRow from settings to all grid pages`
6. `feat(browsing-history): add grid mode toggle`
7. `feat(user-bookshelf): add grid mode toggle`

## Success Criteria
- 设置页可调整网格列数（1-6），默认 3
- 设置页可切换浏览历史布局（列表/网格）
- 设置页可切换用户书架布局（列表/网格）
- 所有网格页面的列数统一跟随设置
- 浏览历史的 grid 模式使用 NovelCoverCard
- 用户书架的 grid 模式使用 NovelCoverCard
- 设置持久化，重启后保持
- 设置修改即时生效
