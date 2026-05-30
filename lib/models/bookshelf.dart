import 'package:get/get.dart';

class Bookshelf {
  final List<BookshelfNovelInfo> list;
  final String classId;

  Bookshelf({required this.list, required this.classId});
}

class BookshelfNovelInfo {
  final String bid;
  final String aid;
  final String url;
  final String title;
  final String img;

  final RxString introduce;
  final RxBool isSelected;

  BookshelfNovelInfo({required this.bid, required this.aid, required this.url, required this.title, required this.img, String? introduce, bool initSelected = false})
    : introduce = (introduce ?? '').obs,
      isSelected = initSelected.obs;
}
