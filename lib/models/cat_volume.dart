import 'dart:convert';

import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/cat_chapter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cat_volume.g.dart';

@JsonSerializable(explicitToJson: true)
class CatVolume {
  final String title;
  final List<CatChapter> chapters;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final RxBool isSelected;

  CatVolume({
    required this.title,
    required this.chapters,
    bool initSelected = false,
  }) : isSelected = initSelected.obs;

  static CatVolume get empty => CatVolume(title: "", chapters: []);

  factory CatVolume.fromJson(Map<String, dynamic> json) =>
      _$CatVolumeFromJson(json);

  Map<String, dynamic> toJson() => _$CatVolumeToJson(this);

  @override
  String toString() => jsonEncode(toJson());

  factory CatVolume.fromString(String json) =>
      CatVolume.fromJson(jsonDecode(json));
}
