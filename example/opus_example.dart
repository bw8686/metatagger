import 'dart:io';

import 'package:metatagger/metatagger.dart';

Future<void> main() async {
  final source = File('example/example.opus');
  final output = File('example/example_opus_with_metadata.opus');
  if (!await source.exists()) {
    print('Opus example file not found: ${source.path}');
    return;
  }

  await source.copy(output.path);
  final tagger = MetaTagger();
  await tagger.writeCommonTags(output.path, {
    CommonTags.title: 'Opus Example',
    CommonTags.artist: 'MetaTagger',
    CommonTags.album: 'Metadata Examples',
    CommonTags.year: '2026',
  });

  final bytes = await output.readAsBytes();
  if (bytes.length >= 4 &&
      bytes[0] == 0x4F &&
      bytes[1] == 0x67 &&
      bytes[2] == 0x67 &&
      bytes[3] == 0x53) {
    final image = await File('example/example.jpg').readAsBytes();
    await tagger.writeTag(
      output.path,
      MetadataTag.binary(CommonTags.albumArt, image),
    );
  } else {
    print(
      'WebM-contained Opus detected; embedded artwork is not supported by WebM.',
    );
  }

  final tags = await tagger.readCommonTags(output.path);
  print('Wrote and read Opus metadata:');
  print('  Title: ${tags[CommonTags.title]}');
  print('  Artist: ${tags[CommonTags.artist]}');
  print(
    '  Album art bytes: ${(tags[CommonTags.albumArt] as List<int>).length}',
  );
}
