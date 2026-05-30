import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/common/language.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/pages/reader/controller.dart';
import 'package:hikari_novel_flutter/pages/setting/controller.dart';
import 'package:hikari_novel_flutter/widgets/custom_tile.dart';
import 'package:jiffy/jiffy.dart';

import '../../service/local_storage_service.dart';

class SettingPage extends StatelessWidget {
  SettingPage({super.key});

  final controller = Get.find<SettingController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("setting".tr), titleSpacing: 0),
      body: Column(
        children: [
          Obx(() {
            final sub = switch (controller.language.value) {
              Language.followSystem => "follow_system".tr,
              Language.simplifiedChinese => "简体中文",
              Language.traditionalChinese => "繁體中文",
            };
            return NormalTile(
              title: "language".tr,
              subtitle: sub,
              leading: const Icon(Icons.language),
              onTap: () =>
                  Get.dialog(
                    RadioListDialog(
                      value: controller.language.value,
                      values: [(Language.followSystem, "follow_system".tr), (Language.simplifiedChinese, "简体中文"), (Language.traditionalChinese, "繁體中文")],
                      title: "language".tr,
                    ),
                  ).then((value) async {
                    if (value != null) controller.changeLanguage(value);
                  }),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text("theme_mode".tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(4, (i) {
                final bg = kKoodoPresets[i][0];
                final text = kKoodoPresets[i][1];
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      controller.changeReaderThemePreset(i);
                      if (Get.isRegistered<ReaderController>()) {
                        Get.find<ReaderController>().applyReaderPresetTheme(i);
                      }
                    },
                    child: Obx(() {
                      final selected = controller.readerThemePresetIndex.value == i;
                      return Container(
                        margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        height: 80,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            ["reader_theme_white", "reader_theme_dark", "reader_theme_sepia", "reader_theme_green"][i].tr,
                            style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
          Offstage(
            offstage: !Platform.isAndroid,
            child: Obx(
              () => SwitchTile(
                title: "dynamic_color_mode".tr,
                leading: const Icon(Icons.colorize),
                onChanged: (value) => controller.changeIsDynamicColor(value),
                value: controller.isDynamicColor.value,
              ),
            ),
          ),
          Offstage(
            offstage: controller.isDynamicColor.value && Platform.isAndroid,
            child: Obx(
              () => NormalTile(
                title: "theme_color".tr,
                leading: const Icon(Icons.format_color_fill_outlined),
                trailing: ColorIndicator(width: 28, height: 28, borderRadius: 100, color: controller.customColor.value),
                onTap: () => _buildColorPickerDialog(context),
              ),
            ),
          ),
          Obx(() {
            return NormalTile(
              title: "node".tr,
              subtitle: controller.wenku8Node.value.node,
              leading: const Icon(Icons.lan_outlined),
              onTap: () =>
                  Get.dialog(
                    RadioListDialog(
                      value: controller.wenku8Node.value,
                      values: [(Wenku8Node.wwwWenku8Net, Wenku8Node.wwwWenku8Net.node), (Wenku8Node.wwwWenku8Cc, Wenku8Node.wwwWenku8Cc.node)],
                      title: "node".tr,
                    ),
                  ).then((value) async {
                    if (value != null) controller.changeWenku8Node(value);
                  }),
            );
          }),
          Obx(
            () => SwitchTile(
              title: "relative_time".tr,
              subtitle: "relative_time_tip".trParams({
                "relativeTime": Jiffy.parse(DateTime.parse("2026-01-25 16:27:00").toString()).fromNow().toString(),
                "normalTime": "2026-01-25 16:27:00",
              }),
              leading: const Icon(Icons.access_time_outlined),
              onChanged: (v) => controller.changeIsRelativeTime(v),
              value: controller.isRelativeTime.value,
            ),
          ),
          Obx(
            () => SwitchTile(
              title: "auto_check_update".tr,
              leading: const Icon(Icons.update),
              onChanged: (v) => controller.changeIsAutoCheckUpdate(v),
              value: controller.isAutoCheckUpdate.value,
            ),
          ),
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
        ],
      ),
    );
  }

  void _buildColorPickerDialog(BuildContext context) async {
    final initColor = LocalStorageService.instance.getCustomColor();
    final newColor = await showColorPickerDialog(
      context,
      initColor,
      showMaterialName: true,
      showColorName: true,
      showColorCode: true,
      materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(context).textTheme.bodySmall,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: false,
      },
      pickerTypeLabels: <ColorPickerType, String>{ColorPickerType.primary: "theme_color".tr, ColorPickerType.wheel: "custom".tr},
      enableShadesSelection: false,
      actionButtons: ColorPickerActionButtons(dialogOkButtonLabel: "save".tr, dialogCancelButtonLabel: "cancel".tr),
      copyPasteBehavior: ColorPickerCopyPasteBehavior().copyWith(copyFormat: ColorPickerCopyFormat.hexRRGGBB),
    );
    if (newColor == initColor) return;
    controller.changeCustomColor(newColor);
  }
}
