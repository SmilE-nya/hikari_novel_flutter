
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/common/language.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';

import '../../service/local_storage_service.dart';


class SettingController extends GetxController {
  RxBool isAutoCheckUpdate = LocalStorageService.instance.getIsAutoCheckUpdate().obs;
  Rx<Language> language = Rx(LocalStorageService.instance.getLanguage());
  RxBool isRelativeTime = LocalStorageService.instance.getIsRelativeTime().obs;
  Rx<Wenku8Node> wenku8Node = Rx(LocalStorageService.instance.getWenku8Node());
  RxInt readerThemePresetIndex = LocalStorageService.instance.getReaderThemePreset().obs;
  RxBool isDynamicColor = LocalStorageService.instance.getIsDynamicColor().obs;
  Rx<Color> customColor = Rx(LocalStorageService.instance.getCustomColor());
  RxInt gridColumnCount = LocalStorageService.instance.getGridColumnCount().obs;
  RxInt browsingHistoryLayout = LocalStorageService.instance.getBrowsingHistoryLayout().obs;
  RxInt userBookshelfLayout = LocalStorageService.instance.getUserBookshelfLayout().obs;

  ThemeMode get derivedThemeMode => switch (readerThemePresetIndex.value) {
    1 => ThemeMode.dark,
    _ => ThemeMode.light,
  };

  void changeIsAutoCheckUpdate(bool enabled) {
    isAutoCheckUpdate.value = enabled;
    LocalStorageService.instance.setIsAutoCheckUpdate(enabled);
  }

  void changeIsRelativeTime(bool enabled) {
    isRelativeTime.value = enabled;
    LocalStorageService.instance.setIsRelativeTime(enabled);
  }

  void changeLanguage(Language l) async {
    switch (l) {
      case Language.simplifiedChinese: Get.updateLocale(Locale("zh","CN"));
      case Language.traditionalChinese: Get.updateLocale(Locale("zh","TW"));
      case Language.followSystem: {
        if (Get.deviceLocale! != Locale("zh","CN") && Get.deviceLocale! != Locale("zh","CN")) {
          Get.updateLocale(Locale("zh","CN"));
        } else {
          Get.updateLocale(Get.deviceLocale!);
        }
      }
    }
    language.value = l;
    LocalStorageService.instance.setLanguage(l);
  }

  void changeWenku8Node(Wenku8Node n) {
    wenku8Node.value = n;
    LocalStorageService.instance.setWenku8Node(n);
  }

  void changeCustomColor(Color color) {
    customColor.value = color;
    LocalStorageService.instance.setCustomColor(color);
    Get.forceAppUpdate();
  }

  void changeIsDynamicColor(bool enabled) {
    isDynamicColor.value = enabled;
    LocalStorageService.instance.setIsDynamicColor(enabled);
    Get.forceAppUpdate();
  }

  void changeReaderThemePreset(int index) {
    readerThemePresetIndex.value = index;
    LocalStorageService.instance.setReaderThemePreset(index);
    Get.forceAppUpdate();
  }

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
}
