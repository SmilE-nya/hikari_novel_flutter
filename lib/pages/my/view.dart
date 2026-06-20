import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/pages/my/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';

class MyPage extends StatelessWidget {
  MyPage({super.key});

  final controller = Get.put(MyController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            const SizedBox(height: 10),
            _buildUserInfoCard(context),
            const SizedBox(height: 20),
            ListTile(
              title: Text("browsing_history".tr),
              leading: const Icon(Icons.history),
              onTap: AppSubRouter.toBrowsingHistory,
            ),
            ListTile(
              title: Text("setting".tr),
              leading: const Icon(Icons.settings_outlined),
              onTap: AppSubRouter.toSetting,
            ),
            ListTile(
              title: Text("about".tr),
              leading: const Icon(Icons.info_outline),
              onTap: AppSubRouter.toAbout,
            ),
            ListTile(
              title: Text("logout".tr),
              leading: const Icon(Icons.logout),
              onTap: controller.logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    return Card.outlined(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardBorderRadius),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => AppSubRouter.toUserInfo(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            controller.userInfo.value?.username ?? "",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
