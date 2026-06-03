import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/network/parser.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';

/// 延迟加载高清封面组件。
///
/// 先展示低清封面，同时异步从首章正文提取插图 URL。
/// 获取到后自动切换为高清图（fallback 保持低清）。
class LazyCoverImage extends StatefulWidget {
  final String lowResUrl;
  final String aid;
  final BoxFit fit;
  final Map<String, String>? headers;

  const LazyCoverImage({
    super.key,
    required this.lowResUrl,
    required this.aid,
    this.fit = BoxFit.cover,
    this.headers,
  });

  @override
  State<LazyCoverImage> createState() => _LazyCoverImageState();
}

class _LazyCoverImageState extends State<LazyCoverImage> {
  String? _highResUrl;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _loadHighRes();
  }

  Future<void> _loadHighRes() async {
    if (_fetching) return;
    _fetching = true;

    try {
      // 1. 查内存（该 State 存活期间不会重新 fetch）
      if (_highResUrl != null) return;

      // 2. 查持久化缓存
      final cached = LocalStorageService.instance.getHighResCoverUrl(
        widget.aid,
      );
      if (cached != null && cached.isNotEmpty) {
        if (mounted) setState(() => _highResUrl = cached);
        return;
      }

      // 3. 获取目录找第一章节
      final catResult = await Api.getCatalogue(aid: widget.aid);
      if (catResult is! Success) return;
      final volumes = Parser.getCatalogue(catResult.data);
      if (volumes.isEmpty || volumes.first.chapters.isEmpty) return;
      final firstCid = volumes.first.chapters.first.cid;

      // 4. 获取第一章内容
      final contentResult = await Api.getNovelContent(
        aid: widget.aid,
        cid: firstCid,
      );
      if (contentResult is! Success) return;
      final url = Parser.getFirstIllustration(contentResult.data);
      if (url == null || url.isEmpty) return;

      // 5. 缓存并更新 UI
      LocalStorageService.instance.setHighResCoverUrl(widget.aid, url);
      if (mounted) setState(() => _highResUrl = url);
    } catch (_) {
      // 静默失败，保持低清封面
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _highResUrl ?? widget.lowResUrl,
      httpHeaders: widget.headers,
      imageBuilder: (context, imageProvider) => Image(
        image: imageProvider,
        fit: widget.fit,
        filterQuality: FilterQuality.high,
      ),
      progressIndicatorBuilder: (context, url, downloadProgress) => Center(
        child: CircularProgressIndicator(value: downloadProgress.progress),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.error_outline),
    );
  }
}
