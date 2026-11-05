import 'dart:io';

import 'package:metatagger/metatagger.dart';

Future<void> main() async {
  final source = File('example/example.aac');
  final output = File('example/example_aac_with_metadata.aac');
  if (!await source.exists()) {
    print('AAC example file not found: ${source.path}');
    return;
  }

  await source.copy(output.path);
  final tagger = MetaTagger();
  await tagger.writeCommonTags(output.path, {
    CommonTags.title: 'AAC Example',
    CommonTags.artist: 'MetaTagger',
    CommonTags.album: 'Metadata Examples',
    CommonTags.year: '2026',
  });

  final image = await File('example/example.jpg').readAsBytes();
  await tagger.writeTag(
    output.path,
    MetadataTag.binary(CommonTags.albumArt, image),
  );

  final tags = await tagger.readCommonTags(output.path);
  print('Wrote and read AAC metadata:');
  print('  Title: ${tags[CommonTags.title]}');
  print('  Artist: ${tags[CommonTags.artist]}');
  print(
    '  Album art bytes: ${(tags[CommonTags.albumArt] as List<int>).length}',
  );
}
