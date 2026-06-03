import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

import '../../../common/constants.dart';
import '../../../models/page_state.dart';
import '../../../network/request.dart';
import '../../../router/app_sub_router.dart';
import '../../../widgets/keep_alive_wrapper.dart';
import '../../../widgets/lazy_cover_image.dart';
import '../../../widgets/novel_cover_card.dart';
import '../../../widgets/state_page.dart';
import '../../setting/controller.dart';

class BookshelfContentView extends StatelessWidget {
  final String classId;
  final BookshelfContentController controller;

  BookshelfContentView({super.key, required this.classId})
    : controller = Get.put(
        BookshelfContentController(classId: classId),
        tag: "BookshelfContentController $classId",
      );

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
                      return InkWell(
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
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                          child: Row(
                            children: [
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    kCardBorderRadius,
                                  ),
                                ),
                                elevation: 0,
                                clipBehavior: Clip.antiAlias,
                                child: SizedBox(
                                  height: 100,
                                  child: AspectRatio(
                                    aspectRatio: 9 / 13,
                                    child: LazyCoverImage(
                                      lowResUrl: item.img,
                                      aid: item.aid,
                                      headers: Request.userAgent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Obx(
                                        () => Text(
                                          item.introduce.value.isNotEmpty
                                              ? item.introduce.value
                                              : '暂无简介',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
          Obx(
            () => Offstage(
              offstage: controller.pageState.value != PageState.loading,
              child: const LoadingPage(),
            ),
          ),
          Obx(
            () => Offstage(
              offstage: controller.pageState.value != PageState.empty,
              child: const EmptyPage(),
            ),
          ),
        ],
      ),
    );
  }
}
