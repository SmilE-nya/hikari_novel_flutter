# Koodo Reader Color Presets for Hikari Novel

## TL;DR
> **Summary**: Replace Hikari Novel reader's default colors (Material3 dynamic theming) with Koodo Reader's 4 fixed color presets: White, Dark, Sepia, Green. Add one-click theme switching in reader settings.
> **Deliverables**: 4 preset themes defined, default fallback colors changed, preset picker UI in settings, controller method for applying presets
> **Effort**: Quick
> **Parallel**: YES - 2 waves
> **Critical Path**: Constants → Controller → Settings UI → View fallbacks

## Context
### Original Request
User finds Hikari Novel's reader colors ugly because they use Material3 dynamic theming (wallpaper-derived). Wants Koodo Reader's clean fixed color presets: white/dark/sepia/green.

### Interview Summary
- Koodo 4 presets: White (#FFFFFF bg / #000000 text), Dark (#2C2F31 bg / #FFFFFF text), Sepia (#E9D8BC bg / #594429 text), Green (#C5E7CF bg / #36503E text)
- Default light mode → White, default dark mode → Dark
- All 4 pickable from reader settings → Theme tab
- No changes to custom color picker, bg image, or non-reader pages

### Metis Review (gaps addressed)
- N/A - trivial scope

## Work Objectives
### Core Objective
Replace reader default colors with Koodo presets, add preset switching UI

### Deliverables
- `kKoodoPresets` constant in constants.dart
- `applyReaderPresetTheme(int index)` in ReaderController
- Fallback color update in view.dart + reader_background.dart
- 4 preset theme cards in reader_setting.dart → Theme tab
- Translations for preset names (zh_CN + zh_TW)

### Definition of Done (verifiable conditions with commands)
- `dart analyze lib/common/constants.dart lib/pages/reader/controller.dart lib/pages/reader/view.dart lib/pages/reader/widgets/reader_background.dart lib/pages/reader/widgets/reader_setting.dart lib/common/app_translations.dart` → no errors
- `flutter build apk --release` → success
- In running app: reader shows white bg / black text (light mode) or dark bg / white text (dark mode) by default
- Reader settings → Theme → 4 preset cards visible and clickable

### Must Have
- 4 color presets
- Preset switching in settings
- Proper fallback handling (load from localStorage → preset → default)

### Must NOT Have
- Don't break existing custom color picker
- Don't affect non-reader pages
- Don't modify bg image logic

## Verification Strategy
- Test decision: No tests needed, manual visual verification
- QA policy: Agent verifies analyze + build pass

## Execution Strategy
### Parallel Execution Waves

Wave 1: Constants + Translations + Controller method
Wave 2: Settings UI + View fallback colors

### Dependency Matrix
- Task 1 (constants): no dependencies
- Task 2 (translations): no dependencies
- Task 3 (controller): depends on 1
- Task 4 (view fallbacks): depends on 1
- Task 5 (settings UI): depends on 2, 3

## TODOs

- [ ] 1. Define Koodo color presets constant

  **What to do**: Add `kKoodoPresets` to `lib/common/constants.dart`:
  ```dart
  const List<List<Color>> kKoodoPresets = [
    [Color(0xFFFFFFFF), Color(0xFF000000)],  // White
    [Color(0xFF2C2F31), Color(0xFFFFFFFF)],  // Dark
    [Color(0xFFE9D8BC), Color(0xFF594429)],  // Sepia
    [Color(0xFFC5E7CF), Color(0xFF36503E)],  // Green
  ];
  ```
  Import `package:flutter/material.dart` already exists in the file.

  **Recommended Agent Profile**:
  - Category: quick - Reason: trivial one-line constant addition
  - Skills: [] - no special skills needed

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [3, 4] | Blocked By: []

  **Acceptance Criteria**:
  - [ ] `dart analyze lib/common/constants.dart` shows no errors

  **QA Scenarios**:
  ```
  Scenario: Compile check
    Tool: Bash
    Steps: run `dart analyze lib/common/constants.dart`
    Expected: No issues found
    Evidence: .sisyphus/evidence/task-1-analyze.txt
  ```

  **Commit**: YES | Message: `feat: add Koodo color presets constant` | Files: [lib/common/constants.dart]

---

- [ ] 2. Add translations for preset theme names

  **What to do**: Add 4 translation keys to `app_translations.dart`:
  - In `zh_CN` map (around line 200): `"reader_theme_white": "白"`, `"reader_theme_dark": "暗"`, `"reader_theme_sepia": "羊皮纸"`, `"reader_theme_green": "绿"`
  - In `zh_TW` map (around line 498): same but `"reader_theme_sepia": "羊皮紙"`, `"reader_theme_green": "綠"`
  - Also add `"reader_theme_presets": "预设主题"` for the section title

  **Recommended Agent Profile**:
  - Category: quick - Reason: simple translation key additions
  - Skills: [] - no special skills needed

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [5] | Blocked By: []

  **Acceptance Criteria**:
  - [ ] `dart analyze lib/common/app_translations.dart` shows no errors

  **QA Scenarios**:
  ```
  Scenario: Compile check
    Tool: Bash
    Steps: run `dart analyze lib/common/app_translations.dart`
    Expected: No issues found
    Evidence: .sisyphus/evidence/task-2-analyze.txt
  ```

  **Commit**: YES | Message: `feat: add Koodo preset theme translations` | Files: [lib/common/app_translations.dart]

---

- [ ] 3. Add applyReaderPresetTheme method to ReaderController

  **What to do**: Add method to `lib/pages/reader/controller.dart`, after `getBgImage()` (line 567):
  ```dart
  void applyReaderPresetTheme(int index) {
    final preset = kKoodoPresets[index];
    final bg = preset[0];
    final text = preset[1];
    if (Get.context!.isDarkMode) {
      changeReaderNightBgColor(bg);
      changeReaderNightTextColor(text);
    } else {
      changeReaderDayBgColor(bg);
      changeReaderDayTextColor(text);
    }
  }
  ```
  Also add import: `import '../../common/constants.dart';` (check if already imported — line 9 shows it IS already imported).

  **Recommended Agent Profile**:
  - Category: quick - Reason: single method addition
  - Skills: [] - no special skills needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: [5] | Blocked By: [1]

  **Acceptance Criteria**:
  - [ ] `dart analyze lib/pages/reader/controller.dart` shows no errors

  **QA Scenarios**:
  ```
  Scenario: Compile check
    Tool: Bash
    Steps: run `dart analyze lib/pages/reader/controller.dart`
    Expected: No issues found
    Evidence: .sisyphus/evidence/task-3-analyze.txt
  ```

  **Commit**: YES | Message: `feat: add applyReaderPresetTheme to ReaderController` | Files: [lib/pages/reader/controller.dart]

---

- [ ] 4. Change default fallback colors in view.dart and reader_background.dart

  **What to do**:

  In `lib/pages/reader/view.dart`:
  - Line 41: Change `color: controller.currentTextColor.value ?? Theme.of(Get.context!).colorScheme.onSurface` to `color: controller.currentTextColor.value ?? (Get.context!.isDarkMode ? kKoodoPresets[1][1] : kKoodoPresets[0][1])`
  - Line 268: Change `controller.currentBgColor.value ?? Theme.of(context).colorScheme.surface` to `controller.currentBgColor.value ?? (context.isDarkMode ? kKoodoPresets[1][0] : kKoodoPresets[0][0])`
  - Line 270: Change the same for the `Color.lerp` fallback

  In `lib/pages/reader/widgets/reader_background.dart`:
  - Line 24: Change `controller.currentBgColor.value ?? Theme.of(context).colorScheme.surface` to `controller.currentBgColor.value ?? (Theme.of(context).brightness == Brightness.dark ? kKoodoPresets[1][0] : kKoodoPresets[0][0])`

  Make sure `import '../../common/constants.dart';` exists in both files. In view.dart, check imports — it imports `../../common/constants.dart` at line 17. In reader_background.dart, it currently doesn't import constants — add `import '../../common/constants.dart';` at the top.

  **Recommended Agent Profile**:
  - Category: quick - Reason: 4 targeted find-and-replace edits
  - Skills: [] - no special skills needed

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: [] | Blocked By: [1]

  **Acceptance Criteria**:
  - [ ] `dart analyze lib/pages/reader/view.dart lib/pages/reader/widgets/reader_background.dart` shows no errors
  - [ ] Reader shows white bg / black text in light mode, dark bg / white text in dark mode (by default)

  **QA Scenarios**:
  ```
  Scenario: Compile check
    Tool: Bash
    Steps: run `dart analyze lib/pages/reader/view.dart lib/pages/reader/widgets/reader_background.dart`
    Expected: No issues found
    Evidence: .sisyphus/evidence/task-4-analyze.txt
  ```

  **Commit**: YES | Message: `fix: use Koodo default colors as reader fallback` | Files: [lib/pages/reader/view.dart, lib/pages/reader/widgets/reader_background.dart]

---

- [ ] 5. Add preset theme picker UI in reader settings

  **What to do**:

  In `lib/pages/reader/widgets/reader_setting.dart`:
  1. In the `_buildTheme` method, at the beginning (after the `ListView` children opening), add a section:
  ```dart
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text("reader_theme_presets".tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
  ),
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: List.generate(4, (i) {
        final bg = kKoodoPresets[i][0];
        final text = kKoodoPresets[i][1];
        return Expanded(
          child: GestureDetector(
            onTap: () => controller.applyReaderPresetTheme(i),
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
              height: 80,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  ["reader_theme_white", "reader_theme_dark", "reader_theme_sepia", "reader_theme_green"][i].tr,
                  style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }),
    ),
  ),
  const Divider(height: 24),
  ```

  2. Add import for constants if not present: `import '../../../common/constants.dart';`

  **Recommended Agent Profile**:
  - Category: visual-engineering - Reason: adding UI widgets with styling
  - Skills: [] - no special skills needed

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: [] | Blocked By: [2, 3]

  **Acceptance Criteria**:
  - [ ] `dart analyze lib/pages/reader/widgets/reader_setting.dart` shows no errors
  - [ ] Reader settings → Theme tab shows 4 colored preset cards at top
  - [ ] Tapping a card changes reader bg/text colors immediately

  **QA Scenarios**:
  ```
  Scenario: Compile check
    Tool: Bash
    Steps: run `dart analyze lib/pages/reader/widgets/reader_setting.dart`
    Expected: No issues found
    Evidence: .sisyphus/evidence/task-5-analyze.txt
  ```

  **Commit**: YES | Message: `feat: add Koodo preset theme picker in reader settings` | Files: [lib/pages/reader/widgets/reader_setting.dart]

---

## Final Verification Wave

- [ ] F1. Plan Compliance Audit — oracle
- [ ] F2. Code Quality Review — unspecified-high
- [ ] F3. Real Manual QA — unspecified-high
- [ ] F4. Scope Fidelity Check — deep

## Commit Strategy
All commits in a single batch: 5 commits, each self-contained.

## Success Criteria
- `flutter build apk --release` succeeds
- No dart analyze errors in any touched file
- Default reader colors are Koodo presets (not Material3 dynamic colors)
- 4 preset theme cards visible and functional in reader settings → Theme
