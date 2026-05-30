# Draft: Koodo Reader Color Presets

## Requirements (confirmed)
- 把 Hikari Novel 阅读器的默认配色换成 Koodo Reader 的固定色，不再跟随 Material3 动态取色
- 加入 Koodo 全部 4 套预设配色（白/暗/羊皮纸/绿），阅读器设置中可一键切换
- 4 套预设：白（#FFFFFF bg / #000000 text）、暗（#2C2F31 bg / #FFFFFF text）、羊皮纸（#E9D8BC bg / #594429 text）、绿（#C5E7CF bg / #36503E text）

## Technical Decisions
- Koodo 预设色值定义为 `kKoodoPresets` 常量（`lib/common/constants.dart`）
- 默认亮/暗模式分别对应 preset 0（白）和 preset 1（暗）
- `view.dart` 中 `textStyle` 和 `reader_background.dart` 中 fallback 颜色从 `Theme.surface`/`Theme.onSurface` 改为 Koodo 预设
- `ReaderController` 新增 `applyReaderPresetTheme(int index)` 方法
- 阅读器设置 → 主题 Tab 添加 4 个预设卡片，点击即切换
- 字号/边距等其它设置不受影响

## Research Findings
- Koodo 配色来源：`koodo-reader-dev/src/constants/themeList.tsx`：`backgroundList` + `textList`
- Hikari Novel 当前默认色：`view.dart:41` 用 `Theme.of(context).colorScheme.onSurface`，`reader_background.dart:24` 用 `Theme.of(context).colorScheme.surface`

## Open Questions
- (无)

## Scope Boundaries
- INCLUDE: 4 套预设色值常量、默认 fallback 颜色变更、预设切换 UI、切换方法
- EXCLUDE: 不修改现有自定义颜色选择器逻辑、不修改自定义背景图片、不修改非阅读器页面的主题色
