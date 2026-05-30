import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller.dart';

class ReaderBackground extends StatelessWidget {
  final Widget child;

  final ReaderController controller = Get.find();

  ReaderBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Decoration decoration;

      final bgImage = controller.currentBgImagePath.value;
      if (bgImage != null && bgImage.isNotEmpty) {
        decoration = BoxDecoration(image: DecorationImage(image: FileImage(File(bgImage)), fit: BoxFit.cover));
      } else {
        decoration = BoxDecoration(color: controller.currentBgColor.value ?? Theme.of(context).colorScheme.surface);
      }

      return Container(decoration: decoration, child: child);
    });
  }
}
