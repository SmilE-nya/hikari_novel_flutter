import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/common/extension.dart';
import 'package:hikari_novel_flutter/models/chapter_cache_task.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/novel_detail.dart';
import 'package:hikari_novel_flutter/models/reader_direction.dart';
import 'package:hikari_novel_flutter/network/parser.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/pages/cache_queue/controller.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/database/database.dart';
import '../../models/cat_chapter.dart';
import '../../models/dual_page_mode.dart';
import '../../models/page_state.dart';
import '../../models/resource.dart';
import '../../network/api.dart';
import '../../service/db_service.dart';
import '../../service/local_storage_service.dart';

class NovelDetailController extends GetxController with GetSingleTickerProviderStateMixin {
  final String aid;

  NovelDetailController({required this.aid});

  Rx<PageState> pageState = PageState.loading.obs;
  String errorMsg = "";
  Rxn<NovelDetail> novelDetail = Rxn();

  /// 从首章插图获取的高清封面 URL
  RxString highResCoverUrl = RxString('');

  RxSet<String> cachedChapter = RxSet();

  RxBool isInBookshelf = false.obs;

  RxBool isChapterOrderReversed = false.obs;

  RxBool isSelectionMode = false.obs;

  bool _isFabVisible = true;
  late final AnimationController _fabAnimationCtr;
  late final Animation<Offset> animation;

  final bookshelfController = Get.find<BookshelfController>();
  final cacheQueueController = Get.findOrPut(() => CacheQueueController());

  late final Directory _supportDir;

  @override
  void onInit() {
    super.onInit();
    _fabAnimationCtr = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))..forward();
    animation = _fabAnimationCtr.drive(Tween<Offset>(begin: const Offset(0.0, 2.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeInOut)));
  }

  @override
  void onReady() async {
    super.onReady();
    _supportDir = await getApplicationSupportDirectory();
    getNovelDetail();
  }

  @override
  void onClose() {
    _fabAnimationCtr.dispose();
    super.onClose();
  }

  void showFab() {
    if (!_isFabVisible) {
      _isFabVisible = true;
      _fabAnimationCtr.forward();
    }
  }

  void hideFab() {
    if (_isFabVisible) {
      _isFabVisible = false;
      _fabAnimationCtr.reverse();
    }
  }

  void enterSelectionMode() => isSelectionMode.value = true;

  void exitSelectionMode() {
    isSelectionMode.value = false;
    deselect();
  }

  //切换某个章节的选中状态（假设 chapter.isSelected 是 RxBool）
  void toggleChapterSelection(int volumeIndex, int chapterIndex) {
    final chapter = novelDetail.value!.catalogue[volumeIndex].chapters[chapterIndex];
    chapter.isSelected.toggle();
    _syncVolumeSelection(volumeIndex);
  }

  //切换某卷（全部选中或全部取消）
  void toggleVolumeSelection(int volumeIndex) {
    final volume = novelDetail.value!.catalogue[volumeIndex];
    final allSelected = volume.chapters.every((c) => c.isSelected.value);
    for (final c in volume.chapters) {
      c.isSelected.value = !allSelected;
    }
    volume.isSelected.value = !allSelected;
  }

  //根据章节选中数同步卷状态
  void _syncVolumeSelection(int volumeIndex) {
    final volume = novelDetail.value!.catalogue[volumeIndex];
    final total = volume.chapters.length;
    final selected = volume.chapters.where((c) => c.isSelected.value).length;
    if (selected == 0) {
      volume.isSelected.value = false;
    } else if (selected == total) {
      volume.isSelected.value = true;
    } else {
      //部分选中：你可以用单独字段或在 UI 用 selected数判断
      volume.isSelected.value = false;
    }
  }

  //获取选中的章节列表
  List<CatChapter> getSelectedChapters() {
    final out = <CatChapter>[];
    final detail = novelDetail.value;
    if (detail == null) return out;
    for (final vol in detail.catalogue) {
      for (final ch in vol.chapters) {
        if (ch.isSelected.value) out.add(ch);
      }
    }
    return out;
  }

  int getSelectedCount() => getSelectedChapters().length;

  void deselect() {
    final detail = novelDetail.value;
    if (detail == null) return;
    for (final vol in detail.catalogue) {
      vol.isSelected.value = false;
      for (final ch in vol.chapters) {
        ch.isSelected.value = false;
      }
    }
  }

  void selectAll() {
    final detail = novelDetail.value;
    if (detail == null) return;
    for (final vol in detail.catalogue) {
      vol.isSelected.value = true;
      for (final ch in vol.chapters) {
        ch.isSelected.value = true;
      }
    }
  }

  Future<void> startCache() async {
    for (var chap in getSelectedChapters()) {
      await cacheQueueController.addTask(
        ChapterCacheTask(
          uuid: "${aid}_${chap.cid}",
          aid: aid,
          cid: chap.cid,
          title: chap.title,
          onCompleted: (cid) {
            cachedChapter.add(cid);
          },
        ),
      );
    }
  }

  Future<void> deleteCache() async {
    final asd = await getApplicationSupportDirectory();
    final dir = Directory("${asd.path}/cached_chapter");

    if (!await dir.exists()) {
      return;
    }

    await for (var entity in dir.list()) {
      if (entity is File) {
        final fileName = entity.uri.pathSegments.last;

        if (fileName.contains("_")) {
          final prefix = fileName.split("_").first;
          final last = fileName.split("_").last;

          final number = int.tryParse(prefix);
          if (number != null && number == int.parse(aid)) {
            try {
              await entity.delete();
            } catch (e) {
              null;
            }
          }
          cachedChapter.remove(last);
        }
      }
    }
  }

  void checkIsChapterCached(String cid) async {
    if (await File("${_supportDir.path}/cached_chapter/${aid}_$cid.txt").exists()) {
      cachedChapter.add(cid);
    } else {
      cachedChapter.remove(cid);
    }
  }

  Future<void> getNovelDetail() async {
    late NovelDetail data;

    final nd = await Api.getNovelDetail(aid: aid);

    switch (nd) {
      case Success():
        data = Parser.getNovelDetail(nd.data);
        final cat = await Api.getCatalogue(aid: aid);
        switch (cat) {
          case Success():
            {
              data.catalogue.addAll(Parser.getCatalogue(cat.data));
              novelDetail.value = data;

              DBService.instance.upsertBrowsingHistory(BrowsingHistoryEntityData(aid: aid, title: data.title, img: data.imgUrl, time: DateTime.now()));

              final bs = await DBService.instance.getAllBookshelf();
              isInBookshelf.value = bs.any((e) => e.aid == aid);

              pageState.value = PageState.success;
              _fetchHighResCover(); // 异步获取高清封面，不阻塞页面
              await DBService.instance.upsertNovelDetail(NovelDetailEntityData(aid: aid, json: novelDetail.value!.toString())); //缓存小说详情
            }
          case Error():
            {
              //检测本地是否有缓存
              if (await _getNovelDetailByLocal()) return;
              errorMsg = cat.error.toString();
              pageState.value = PageState.error;
            }
        }
      case Error():
        {
          //检测本地是否有缓存
          if (await _getNovelDetailByLocal()) return;
          errorMsg = nd.error.toString();
          pageState.value = PageState.error;
        }
    }
  }

  /// 异步获取首章插图作为高清封面 URL
  Future<void> _fetchHighResCover() async {
    final detail = novelDetail.value;
    if (detail == null || detail.catalogue.isEmpty) return;
    final firstVol = detail.catalogue.first;
    if (firstVol.chapters.isEmpty) return;
    final firstCid = firstVol.chapters.first.cid;
    final result = await Api.getNovelContent(aid: aid, cid: firstCid);
    switch (result) {
      case Success():
        final url = Parser.getFirstIllustration(result.data);
        if (url != null && url.isNotEmpty) {
          highResCoverUrl.value = url;
        }
      case Error():
        break;
    }
  }

  Future<bool> _getNovelDetailByLocal() async {
    final local = (await DBService.instance.getNovelDetail(aid))?.json;

    if (local == null) {
      return false;
    } else {
      novelDetail.value = NovelDetail.fromString(local);
      pageState.value = PageState.success;
      return true;
    }
  }

  bool _isAdding = false; //防抖
  void addToBookshelf() async {
    if (_isAdding) return;
    _isAdding = true;
    final result = await Api.addNovel(aid: aid);
    switch (result) {
      case Success():
        {
          if (Parser.isError(result.data)) {
            Get.dialog(
              AlertDialog(
                icon: const Icon(Icons.warning_amber_outlined),
                title: Text("warning".tr),
                content: Text("add_to_bookshelf_failed_tip".tr),
                actions: [TextButton(onPressed: Get.back, child: Text("confirm".tr))],
              ),
            );
            isInBookshelf.value = false;
          } else {
            await bookshelfController.refreshDefaultBookshelf();
            isInBookshelf.value = true;
          }
        }
      case Error():
        {
          showErrorDialog(result.error.toString(), [TextButton(onPressed: Get.back, child: Text("confirm".tr))]);
        }
    }
    _isAdding = false;
  }

  bool _isRemoving = false; //防抖
  void removeFromBookshelf() async {
    if (_isRemoving) return;
    _isRemoving = true;
    final bs = await DBService.instance.getAllBookshelf();
    final delId = bs.firstWhere((i) => i.aid == aid).bid;
    final result = await Api.removeNovel(delid: delId);
    switch (result) {
      case Success():
        {
          isInBookshelf.value = false;
        }
      case Error():
        {
          showErrorDialog(result.error.toString(), [TextButton(onPressed: Get.back, child: Text("confirm".tr))]);
        }
    }
    _isRemoving = false;
  }

  void recommendThisNovel() async {
    final result = await Api.novelVote(aid: aid);
    final string = switch (result) {
      Success() => Parser.novelVote(result.data),
      Error() => result.error.toString(),
    };
    showSnackBar(message: string, context: Get.context!);
  }

  Future<void> openWithBrowser() async {
    if (!await launchUrl(Uri.parse("${Api.wenku8Node.node}/book/$aid.htm"))) {
      showSnackBar(message: "unable_to_open_external_browser".tr, context: Get.context!);
    }
  }

  ///检测阅读记录是否适用于当前设置（是否双页，阅读方向）
  bool isValidReadHistory(ReadHistoryEntityData? data) {
    if (data == null) {
      return false;
    } else {
      bool isDualPage = switch (LocalStorageService.instance.getReaderDualPageMode()) {
        DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
        DualPageMode.enabled => true,
        DualPageMode.disabled => false,
      };
      bool isSameReaderMode = switch (LocalStorageService.instance.getReaderDirection()) {
        ReaderDirection.leftToRight => data.readerMode == kPageReadMode,
        ReaderDirection.rightToLeft => data.readerMode == kPageReadMode,
        ReaderDirection.upToDown => data.readerMode == kScrollReadMode,
      };
      return data.isDualPage == isDualPage && isSameReaderMode;
    }
  }

  String getReadHistoryProgressByCid(ReadHistoryEntityData? result) {
    if (result == null) {
      return "unread".tr;
    }

    bool isDualPage = switch (LocalStorageService.instance.getReaderDualPageMode()) {
      DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
      DualPageMode.enabled => true,
      DualPageMode.disabled => false,
    };

    final currDirection = LocalStorageService.instance.getReaderDirection();
    if (result.isDualPage == isDualPage) {
      if ((result.readerMode == kScrollReadMode && currDirection == ReaderDirection.upToDown) ||
          (result.readerMode == kPageReadMode && (currDirection == ReaderDirection.leftToRight || currDirection == ReaderDirection.rightToLeft))) {
        return "${result.progress}%";
      }
    }
    return "unable_to_use_read_history_tip".tr;
  }

  String getReadHistoryProgressByVolume(List<ReadHistoryEntityData> list, int totalNum) {
    int readCompletedNum = 0;
    int readPartiallyNum = 0;

    if (list.isEmpty) {
      return "unread".tr;
    }

    bool isDualPage = switch (LocalStorageService.instance.getReaderDualPageMode()) {
      DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
      DualPageMode.enabled => true,
      DualPageMode.disabled => false,
    };
    final currDirection = LocalStorageService.instance.getReaderDirection();
    for (ReadHistoryEntityData d in list) {
      if (d.isDualPage == isDualPage) {
        if ((d.readerMode == kScrollReadMode && currDirection == ReaderDirection.upToDown) ||
            (d.readerMode == kPageReadMode && (currDirection == ReaderDirection.leftToRight || currDirection == ReaderDirection.rightToLeft))) {
          if (d.progress == 100) {
            readCompletedNum++;
          } else {
            readPartiallyNum++;
          }
        }
      }
    }

    if (readCompletedNum == totalNum) {
      return "all_reading_completed".tr;
    } else if (readPartiallyNum > 0 || (readCompletedNum > 0 && readCompletedNum < totalNum)) {
      return "partially_read".tr;
    } else {
      return "unread".tr;
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  Future<List<_CachedChapter>> _getCachedChapters() async {
    final detail = novelDetail.value;
    if (detail == null) return [];

    final List<_CachedChapter> result = [];
    for (final vol in detail.catalogue) {
      for (final ch in vol.chapters) {
        if (!cachedChapter.contains(ch.cid)) continue;
        final file = File("${_supportDir.path}/cached_chapter/${aid}_${ch.cid}.txt");
        if (await file.exists()) {
          final content = await file.readAsString();
          result.add(_CachedChapter(title: ch.title, content: content));
        }
      }
    }
    return result;
  }

  Future<void> showExportDialog() async {
    final chapters = await _getCachedChapters();
    if (chapters.isEmpty) {
      showSnackBar(message: "no_cached_chapters".tr, context: Get.context!);
      return;
    }
    Get.dialog(
      AlertDialog(
        title: Text("export_format".tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text("export_txt".tr),
              leading: const Icon(Icons.description_outlined),
              onTap: () {
                Get.back();
                _exportAsTxt(chapters);
              },
            ),
            ListTile(
              title: Text("export_epub".tr),
              leading: const Icon(Icons.menu_book_outlined),
              onTap: () {
                Get.back();
                _exportAsEpub(chapters);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsTxt(List<_CachedChapter> chapters) async {
    final detail = novelDetail.value;
    if (detail == null) return;

    final exportDir = _getExportDir();
    final fileName = '${_sanitizeFileName(detail.title)}.txt';
    final file = File('${exportDir.path}/$fileName');

    try {
      final buffer = StringBuffer();
      buffer.writeln(detail.title);
      buffer.writeln('');
      for (final ch in chapters) {
        buffer.writeln(ch.title);
        buffer.writeln('');
        buffer.writeln(ch.content);
        buffer.writeln('');
      }
      await file.writeAsString(buffer.toString(), encoding: utf8);
      showSnackBar(message: "${"export_success".tr}: $fileName", context: Get.context!);
    } catch (e) {
      showSnackBar(message: "export_failed".tr, context: Get.context!);
    }
  }

  Future<void> _exportAsEpub(List<_CachedChapter> chapters) async {
    final detail = novelDetail.value;
    if (detail == null) return;

    final exportDir = _getExportDir();
    final fileName = '${_sanitizeFileName(detail.title)}.epub';
    final file = File('${exportDir.path}/$fileName');

    try {
      final archive = Archive();
      // mimetype — MUST be first, MUST be stored (no compression)
      final mt = ArchiveFile('mimetype', 20, utf8.encode('application/epub+zip'));
      archive.addFile(mt);
      // META-INF/container.xml
      final containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile('META-INF/container.xml', containerXml.length, utf8.encode(containerXml)));

      // Build chapter XHTML
      final StringBuffer manifest = StringBuffer();
      final StringBuffer spine = StringBuffer();
      final StringBuffer navItems = StringBuffer();

      for (int i = 0; i < chapters.length; i++) {
        final ch = chapters[i];
        final id = 'chapter_${i + 1}';
        final href = '$id.xhtml';
        final htmlContent = _escapeXml(ch.content).replaceAll('\n', '<br/>');
        final xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>${_escapeXml(ch.title)}</title>
<link rel="stylesheet" type="text/css" href="styles.css"/></head>
<body>
<h1>${_escapeXml(ch.title)}</h1>
<p>$htmlContent</p>
</body>
</html>''';
        archive.addFile(ArchiveFile('OEBPS/$href', xhtml.length, utf8.encode(xhtml)));
        manifest.writeln('    <item id="$id" href="$href" media-type="application/xhtml+xml"/>');
        spine.writeln('    <itemref idref="$id"/>');
        navItems.writeln('    <li><a href="$href">${_escapeXml(ch.title)}</a></li>');
      }

      // styles.css
      final styles = '''body { font-family: serif; line-height: 1.8; padding: 1em; }
h1 { text-align: center; font-size: 1.4em; margin-bottom: 1em; }
p { text-indent: 2em; margin: 0.5em 0; }''';
      archive.addFile(ArchiveFile('OEBPS/styles.css', styles.length, utf8.encode(styles)));

      // nav.xhtml
      final navXhtml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>${_escapeXml(detail.title)}</title></head>
<body>
<nav epub:type="toc">
<h1>${_escapeXml(detail.title)}</h1>
<ol>
$navItems
</ol>
</nav>
</body>
</html>''';
      archive.addFile(ArchiveFile('OEBPS/nav.xhtml', navXhtml.length, utf8.encode(navXhtml)));

      // content.opf
      final opf = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="book-id" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">urn:uuid:${DateTime.now().millisecondsSinceEpoch}</dc:identifier>
    <dc:title>${_escapeXml(detail.title)}</dc:title>
    <dc:language>zh-CN</dc:language>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="styles" href="styles.css" media-type="text/css"/>
$manifest
  </manifest>
  <spine>
$spine
  </spine>
</package>''';
      archive.addFile(ArchiveFile('OEBPS/content.opf', opf.length, utf8.encode(opf)));

      // Encode ZIP
      final encoded = ZipEncoder().encode(archive);
      await file.writeAsBytes(encoded);
      showSnackBar(message: "${"export_success".tr}: $fileName", context: Get.context!);
    } catch (e) {
      showSnackBar(message: "export_failed".tr, context: Get.context!);
    }
  }

  Directory _getExportDir() {
    final savedPath = LocalStorageService.instance.getExportPath();
    if (savedPath != null && Directory(savedPath).existsSync()) {
      return Directory(savedPath);
    }
    // Fallback: app documents directory
    final docDir = Directory(_supportDir.path);
    final exportDir = Directory('${docDir.path}/exports');
    if (!exportDir.existsSync()) exportDir.createSync(recursive: true);
    return exportDir;
  }

  String _escapeXml(String s) {
    return s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  }

  void deleteAllReadHistory() async => DBService.instance.deleteAllReadHistory();

  Future<void> markAsUnRead() async {
    for (var chapter in getSelectedChapters()) {
      await DBService.instance.deleteReadHistoryByCid(chapter.cid);
    }
  }

  Future<void> markAsRead() async {
    // 1为滚动模式，2为翻页模式，翻页模式的左右方向不影响阅读记录的使用
    final readerMode = LocalStorageService.instance.getReaderDirection() == ReaderDirection.upToDown ? kScrollReadMode : kPageReadMode;
    bool isDualPage = switch (LocalStorageService.instance.getReaderDualPageMode()) {
      DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
      DualPageMode.enabled => true,
      DualPageMode.disabled => false,
    };

    for (var chapter in getSelectedChapters()) {
      final data = await DBService.instance.getReadHistoryByCid(chapter.cid);

      if (data == null) {
        DBService.instance.upsertReadHistoryDirectly(
          ReadHistoryEntityData(cid: chapter.cid, aid: aid, readerMode: readerMode, isDualPage: isDualPage, location: 0, progress: 100, isLatest: false),
        );
      } else {
        DBService.instance.upsertReadHistoryDirectly(
          ReadHistoryEntityData(
            cid: data.cid,
            aid: data.aid,
            readerMode: data.readerMode,
            isDualPage: data.isDualPage,
            location: data.location,
            progress: 100,
            isLatest: data.isLatest,
          ),
        );
      }
    }
  }
}

class _CachedChapter {
  final String title;
  final String content;
  _CachedChapter({required this.title, required this.content});
}
