import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

import '../../../models/page_state.dart';
import '../../../network/request.dart';
import '../../../router/app_sub_router.dart';
import '../../../widgets/keep_alive_wrapper.dart';
import '../../../widgets/novel_cover_card.dart';
import '../../../widgets/state_page.dart';
import '../../setting/controller.dart';

class BookshelfContentView extends StatelessWidget {
  final String classId;
  final BookshelfContentController controller;

  BookshelfContentView({super.key, required this.classId})
    : controller = Get.put(BookshelfContentController(classId: classId), tag: "BookshelfContentController $classId");

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Stack(
        children: [
          Obx(
            () => Offstage(
              offstage: controller.pageState.value != PageState.success,
              child: Obx(() {
                final settingController = Get.find<SettingController>();
                final list = controller.bookshelf.value?.list;
                if (list == null || list.isEmpty) return const EmptyPage();
                if (settingController.userBookshelfLayout.value == 0) {
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return ListTile(
                        leading: Card(
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            width: 50,
                            height: 70,
                            child: CachedNetworkImage(
                              imageUrl: item.img,
                              httpHeaders: Request.userAgent,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                              errorWidget: (_, _, _) => const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        selected: item.isSelected.value,
                        onTap: () {
                          if (controller.isSelectionMode) {
                            controller.toggleCoverSelection(item.aid);
                          } else {
                            AppSubRouter.toNovelDetail(aid: item.aid);
                          }
                        },
                        onLongPress: () {
                          if (!controller.isSelectionMode) {
                            controller.enterSelectionMode();
                            controller.toggleCoverSelection(item.aid);
                          }
                        },
                      );
                    },
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: ResponsiveGridList(
                      minItemWidth: 100,
                      horizontalGridSpacing: 4,
                      verticalGridSpacing: 4,
                      maxItemsPerRow: settingController.gridColumnCount.value,
                      children: list.map((item) {
                        return BookshelfCoverCard(
                          bookshelfNovelInfo: item,
                          onTap: () {
                            if (controller.isSelectionMode) {
                              controller.toggleCoverSelection(item.aid);
                            } else {
                              AppSubRouter.toNovelDetail(aid: item.aid);
                            }
                          },
                          onLongPress: () {
                            if (!controller.isSelectionMode) {
                              controller.enterSelectionMode();
                              controller.toggleCoverSelection(item.aid);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  );
                }
              }),
            ),
          ),
          Obx(() => Offstage(offstage: controller.pageState.value != PageState.loading, child: const LoadingPage())),
          Obx(() => Offstage(offstage: controller.pageState.value != PageState.empty, child: const EmptyPage())),
        ],
      ),
    );
  }
}
